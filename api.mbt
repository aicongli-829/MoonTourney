///|
fn create_from_json(request : Json) -> Tournament raise FixtureError {
  let entrants = array_value(field(request, "entrants"), "entrants")
  require(entrants.length() <= 128, "Too many entrants.")
  let participants = participants_from_names(
    entrants.map(item => text_value(item, "entrant")),
  )
  let rules = rules_from_json(field(request, "rules"))
  let configured = with_seed_tie_break(
    rules,
    bool_field(request, "seedTieBreak", false),
  )
  create_tournament(
    text_field(request, "title", "Club competition"),
    parse_format(text_field(request, "format", "round-robin")),
    configured,
    participants,
    group_count=int_field(request, "groupCount", 2),
    qualifiers=int_field(request, "qualifiers", 2),
    third_place=bool_field(request, "thirdPlace", false),
    swiss_rounds=int_field(request, "swissRounds", 3),
  )
}

///|
fn execute_request(request : Json) -> Json raise FixtureError {
  object_required(request, "request")
  let action = text_field(request, "action", "inspect")
  if action == "presets" {
    return { "presets": rule_presets().map(rules_to_json) }
  }
  if action == "create" {
    return view_to_json(create_from_json(request))
  }
  if action == "season-new" {
    return season_series_view_to_json(
      new_season_series(text_field(request, "title", "Competition seasons")),
    )
  }
  if action.has_prefix("season-") {
    let series = season_series_from_json(field(request, "collection"))
    match action {
      "season-inspect" => return season_series_view_to_json(series)
      "season-extract" => {
        let key = text_value(field(request, "key"), "season key")
        for season in series.seasons {
          if season.key == key {
            return { "tournament": tournament_to_json(season.tournament) }
          }
        }
        raise InvalidInput("Unknown season key.")
      }
      "season-rename" =>
        return season_series_view_to_json(
          rename_season_series(
            series,
            text_value(field(request, "title"), "series title"),
          ),
        )
      "season-add" =>
        return season_series_view_to_json(
          add_season(
            series,
            text_field(request, "key", next_season_key(series)),
            text_value(field(request, "label"), "season label"),
            tournament_from_json(field(request, "tournament")),
          ),
        )
      "season-update" =>
        return season_series_view_to_json(
          update_season(
            series,
            text_value(field(request, "key"), "season key"),
            tournament_from_json(field(request, "tournament")),
          ),
        )
      "season-remove" =>
        return season_series_view_to_json(
          remove_season(series, text_value(field(request, "key"), "season key")),
        )
      "season-clone" => {
        let label = text_value(field(request, "label"), "season label")
        return season_series_view_to_json(
          clone_season(
            series,
            text_value(field(request, "sourceKey"), "source season key"),
            text_field(request, "key", next_season_key(series)),
            label,
            text_field(request, "title", label + " · " + series.title),
          ),
        )
      }
      "season-export" => {
        let kind = text_field(request, "kind", "json")
        let content = match kind {
          "json" => season_series_to_json(series).stringify()
          "seasons-csv" => season_series_csv(series)
          "history-csv" => season_history_csv(series)
          _ => raise InvalidInput("Unknown season export kind.")
        }
        return { "kind": kind, "content": content }
      }
      _ => raise InvalidInput("Unknown season action: " + action)
    }
  }
  if action == "series" {
    let rules = rules_from_json(field(request, "rules"))
    let games = array_value(field(request, "games"), "games")
    require(games.length() <= 15, "Too many series games.")
    let summary = summarize_series(
      rules,
      games.map(game => result_from_json(game, rules)),
      int_field(request, "bestOf", 3),
    )
    return {
      "homeWins": summary.home_wins,
      "awayWins": summary.away_wins,
      "complete": summary.complete,
      "nextGame": summary.next_game,
      "winnerSide": match summary.winner_side {
        Some(side) => number_json(side)
        None => Json::null()
      },
    }
  }
  let t = tournament_from_json(field(request, "tournament"))
  match action {
    "inspect" => view_to_json(t)
    "roster" => {
      let names = array_value(field(request, "names"), "names")
      require(names.length() <= 128, "Too many entrants.")
      view_to_json(
        replace_roster(t, names.map(item => text_value(item, "entrant"))),
      )
    }
    "record" =>
      view_to_json(
        record_result(t, result_from_json(field(request, "result"), t.rules)),
      )
    "clear" =>
      view_to_json(
        remove_result(t, text_value(field(request, "fixtureId"), "fixtureId")),
      )
    "advance" =>
      view_to_json(
        if t.format == SwissPlayoff {
          advance_swiss(t)
        } else if t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff {
          advance_league(t)
        } else {
          advance_groups(t)
        },
      )
    "next-round" => view_to_json(next_swiss_round(t))
    "withdraw" => {
      let id = int_value(field(request, "participantId"), "participantId")
      let active = bool_field(request, "active", false)
      view_to_json(settle_withdrawals(set_active(t, id, active)))
    }
    "schedule" => {
      let planned = schedule(
        t,
        int_field(request, "courts", 2),
        int_field(request, "duration", 30),
        rest=int_field(request, "rest", 10),
        start=int_field(request, "start", 0),
        horizon=int_field(request, "horizon", 1000000),
        day_start=int_field(request, "dayStart", 0),
        day_end=int_field(request, "dayEnd", 1440),
      )
      {
        "allocations": planned.allocations.map(item => {
          (
            {
              "fixtureId": item.fixture_id,
              "court": item.court,
              "start": item.start,
              "duration": item.duration,
            } : Json)
        }),
        "unscheduled": planned.unscheduled,
        "csv": schedule_csv(planned),
      }
    }
    "export" => {
      let kind = text_field(request, "kind", "json")
      let content = match kind {
        "json" => tournament_to_json(t).stringify()
        "fixtures-csv" => fixtures_csv(t)
        "standings-csv" =>
          standings_csv(t, stage=text_field(request, "stage", ""))
        "report" => tournament_report(t)
        _ => raise InvalidInput("Unknown export kind.")
      }
      { "content": content, "kind": kind }
    }
    _ => raise InvalidInput("Unknown action: " + action)
  }
}

///|
/// One envelope for browser, CLI and integrations; parser errors never panic.
pub fn dispatch_json(source : String) -> String {
  let result : Json = try {
    require(
      source.length() <= 4000000,
      "Request exceeds the 4-million-character limit.",
    )
    let request = @json.parse(source) catch {
      _ => raise InvalidInput("Invalid JSON request.")
    }
    { "ok": true, "data": execute_request(request) }
  } catch {
    error => { "ok": false, "error": error_message(error) }
  }
  result.stringify()
}

///|
pub fn error_message(error : FixtureError) -> String {
  match error {
    InvalidInput(message)
    | InvalidResult(message)
    | DependencyError(message)
    | PairingError(message)
    | UnresolvedTie(message) => message
  }
}
