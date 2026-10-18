///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn object_required(value : Json, label : String) -> Unit raise FixtureError {
  match value {
    Object(_) => ()
    _ => raise InvalidInput(label + " must be a JSON object.")
  }
}

///|
fn text_value(value : Json, label : String) -> String raise FixtureError {
  match value {
    String(text) => text
    _ => raise InvalidInput(label + " must be a string.")
  }
}

///|
fn text_field(
  value : Json,
  key : String,
  fallback : String,
) -> String raise FixtureError {
  match field(value, key) {
    Null => fallback
    other => text_value(other, key)
  }
}

///|
fn int_value(value : Json, label : String) -> Int32 raise FixtureError {
  match value {
    Number(number, ..) => {
      if number < -10000000.0 ||
        number > 10000000.0 ||
        number != number.to_int().to_double() {
        raise InvalidInput(label + " must be a bounded integer.")
      }
      number.to_int()
    }
    _ => raise InvalidInput(label + " must be an integer.")
  }
}

///|
fn int_field(
  value : Json,
  key : String,
  fallback : Int32,
) -> Int32 raise FixtureError {
  match field(value, key) {
    Null => fallback
    other => int_value(other, key)
  }
}

///|
fn bool_field(
  value : Json,
  key : String,
  fallback : Bool,
) -> Bool raise FixtureError {
  match field(value, key) {
    Null => fallback
    true => true
    false => false
    _ => raise InvalidInput(key + " must be a boolean.")
  }
}

///|
fn array_value(value : Json, label : String) -> Array[Json] raise FixtureError {
  match value {
    Array(items) => items
    _ => raise InvalidInput(label + " must be an array.")
  }
}

///|
fn number_json(value : Int32) -> Json {
  Json(value)
}

///|
pub fn rules_to_json(rules : Rules) -> Json {
  {
    "id": rules.id,
    "label": rules.label,
    "sport": sport_name(rules.sport),
    "bestOf": rules.best_of,
    "target": rules.target,
    "finalTarget": rules.final_target,
    "winBy": rules.win_by,
    "cap": rules.cap,
    "winPoints": rules.win_points,
    "drawPoints": rules.draw_points,
    "lossPoints": rules.loss_points,
    "forfeitScore": rules.forfeit_score,
    "pointScale": rules.point_scale,
    "tieBreaks": rules.tie_breaks.map(tie_break_name),
    "source": rules.source,
    "scope": rules.scope,
  }
}

///|
pub fn rules_from_json(value : Json) -> Rules raise FixtureError {
  let base = match value {
    String(id) => return preset(id)
    Object(_) => preset(text_field(value, "id", "football"))
    _ =>
      raise InvalidInput("Rules must be a preset ID or a configuration object.")
  }
  let criteria = match field(value, "tieBreaks") {
    Null => base.tie_breaks.copy()
    other =>
      array_value(other, "tieBreaks").map(item => {
        parse_tie_break(text_value(item, "tieBreak"))
      })
  }
  let candidate : Rules = {
    ..base,
    best_of: int_field(value, "bestOf", base.best_of),
    target: int_field(value, "target", base.target),
    final_target: int_field(value, "finalTarget", base.final_target),
    win_by: int_field(value, "winBy", base.win_by),
    cap: int_field(value, "cap", base.cap),
    win_points: int_field(value, "winPoints", base.win_points),
    draw_points: int_field(value, "drawPoints", base.draw_points),
    loss_points: int_field(value, "lossPoints", base.loss_points),
    forfeit_score: int_field(value, "forfeitScore", base.forfeit_score),
    point_scale: int_field(value, "pointScale", base.point_scale),
    tie_breaks: criteria,
  }
  validate_rules(candidate)
  if candidate == base {
    candidate
  } else {
    {
      ..candidate,
      label: sport_name(base.sport) +
      (if uses_sets(base.sport) {
        " · custom best of " + candidate.best_of.to_string()
      } else {
        " · custom scoring / ranking"
      }),
      scope: base.scope + " Configured overrides are organizer policies.",
    }
  }
}

///|
pub fn participant_to_json(p : Participant) -> Json {
  { "id": p.id, "name": p.name, "seed": p.seed, "active": p.active }
}

///|
fn participant_from_json(value : Json) -> Participant raise FixtureError {
  object_required(value, "participant")
  {
    id: int_value(field(value, "id"), "id"),
    name: text_value(field(value, "name"), "name"),
    seed: int_value(field(value, "seed"), "seed"),
    active: bool_field(value, "active", true),
  }
}

///|
pub fn slot_to_json(slot : Slot) -> Json {
  match slot {
    Seed(id) => { "kind": "entrant", "id": id }
    Winner(id) => { "kind": "winner", "fixture": id }
    Loser(id) => { "kind": "loser", "fixture": id }
    Empty => { "kind": "bye" }
  }
}

///|
fn slot_from_json(value : Json) -> Slot raise FixtureError {
  object_required(value, "slot")
  match text_field(value, "kind", "") {
    "entrant" => Seed(int_value(field(value, "id"), "slot ID"))
    "winner" => Winner(text_value(field(value, "fixture"), "fixture reference"))
    "loser" => Loser(text_value(field(value, "fixture"), "fixture reference"))
    "bye" => Empty
    _ => raise InvalidInput("Unknown slot kind.")
  }
}

///|
pub fn fixture_to_json(fixture : Fixture) -> Json {
  {
    "id": fixture.id,
    "stage": fixture.stage,
    "round": fixture.round,
    "home": slot_to_json(fixture.home),
    "away": slot_to_json(fixture.away),
  }
}

///|
fn fixture_from_json(value : Json) -> Fixture raise FixtureError {
  object_required(value, "fixture")
  {
    id: text_value(field(value, "id"), "fixture ID"),
    stage: text_value(field(value, "stage"), "stage"),
    round: int_value(field(value, "round"), "round"),
    home: slot_from_json(field(value, "home")),
    away: slot_from_json(field(value, "away")),
  }
}

///|
pub fn result_to_json(result : MatchResult) -> Json {
  {
    "fixtureId": result.fixture_id,
    "home": result.score.home,
    "away": result.score.away,
    "sets": result.sets.map(game => {
      ({ "home": game.home, "away": game.away } : Json)
    }),
    "decider": match result.decider {
      Some(side) => number_json(side)
      None => Json::null()
    },
    "kind": if result.kind == Forfeit {
      "forfeit"
    } else {
      "played"
    },
  }
}

///|
pub fn result_from_json(
  value : Json,
  rules : Rules,
) -> MatchResult raise FixtureError {
  object_required(value, "result")
  let id = text_value(field(value, "fixtureId"), "fixtureId")
  let kind = text_field(value, "kind", "played")
  if kind == "forfeit" && field(value, "winnerSide") != Json::null() {
    let side = int_value(field(value, "winnerSide"), "winnerSide")
    require(side == 1 || side == 2, "Forfeit winner must be side 1 or 2.")
    return forfeit_result(rules, id, side)
  }
  require(kind == "played" || kind == "forfeit", "Unknown result kind.")
  let sets = match field(value, "sets") {
    Null => []
    other => {
      let games = array_value(other, "sets")
      require(games.length() <= 15, "Too many sets.")
      games.map(game => {
        object_required(game, "set")
        (
          {
            home: int_value(field(game, "home"), "set home score"),
            away: int_value(field(game, "away"), "set away score"),
          } : Score)
      })
    }
  }
  let summary = set_result(id, sets)
  let score : Score = if uses_sets(rules.sport) {
    {
      home: int_field(value, "home", summary.score.home),
      away: int_field(value, "away", summary.score.away),
    }
  } else {
    {
      home: int_value(field(value, "home"), "home score"),
      away: int_value(field(value, "away"), "away score"),
    }
  }
  let decider = match field(value, "decider") {
    Null => None
    other => Some(int_value(other, "decider"))
  }
  {
    fixture_id: id,
    score,
    sets,
    decider,
    kind: if kind == "forfeit" {
      Forfeit
    } else {
      Played
    },
  }
}

///|
pub fn tournament_to_json(t : Tournament) -> Json {
  let results : Array[Json] = []
  for fixture in t.fixtures {
    match t.results.get(fixture.id) {
      Some(r) => results.push(result_to_json(r))
      None => ()
    }
  }
  {
    "schemaVersion": 1,
    "title": t.title,
    "format": format_name(t.format),
    "rules": rules_to_json(t.rules),
    "participants": t.participants.map(participant_to_json),
    "fixtures": t.fixtures.map(fixture_to_json),
    "results": results,
    "groupCount": t.group_count,
    "qualifiers": t.qualifiers,
    "swissRounds": t.swiss_rounds,
  }
}

///|
pub fn tournament_from_json(value : Json) -> Tournament raise FixtureError {
  object_required(value, "tournament")
  require(
    int_value(field(value, "schemaVersion"), "schemaVersion") == 1,
    "Unsupported schema version.",
  )
  let rules = rules_from_json(field(value, "rules"))
  let people = array_value(field(value, "participants"), "participants")
  require(people.length() <= 128, "Too many participants.")
  let games = array_value(field(value, "fixtures"), "fixtures")
  require(games.length() <= 20000, "Too many fixtures.")
  let raw_results = array_value(field(value, "results"), "results")
  require(raw_results.length() <= games.length(), "Too many results.")
  let results : Map[String, MatchResult] = Map([])
  for item in raw_results {
    let result = result_from_json(item, rules)
    require(
      !results.contains(result.fixture_id),
      "Duplicate result fixture ID.",
    )
    results[result.fixture_id] = result
  }
  let t : Tournament = {
    title: text_value(field(value, "title"), "title"),
    format: parse_format(text_value(field(value, "format"), "format")),
    rules,
    participants: people.map(participant_from_json),
    fixtures: games.map(fixture_from_json),
    results,
    group_count: int_field(value, "groupCount", 0),
    qualifiers: int_field(value, "qualifiers", 0),
    swiss_rounds: int_field(value, "swissRounds", 0),
  }
  validate_tournament(t)
  t
}

///|
fn standing_to_json(rules : Rules, row : Standing) -> Json {
  {
    "rank": row.rank,
    "id": row.participant.id,
    "name": row.participant.name,
    "played": row.played,
    "wins": row.wins,
    "draws": row.draws,
    "losses": row.losses,
    "points": row.points,
    "pointsLabel": display_points(row.points, rules.point_scale),
    "scored": row.scored,
    "conceded": row.conceded,
    "difference": row.scored - row.conceded,
    "setsWon": row.sets_won,
    "setsLost": row.sets_lost,
    "byes": row.byes,
    "reasons": ranking_reasons(rules, row),
  }
}

///|
pub fn view_to_json(t : Tournament) -> Json {
  let views = t.fixtures.map(fixture => {
    let resolved_id = (slot : Slot) => {
      match resolve_slot(t, slot) {
        Ready(id) => number_json(id)
        _ => Json::null()
      }
    }
    (
      {
        "id": fixture.id,
        "stage": fixture.stage,
        "round": fixture.round,
        "homeLabel": slot_label(t, fixture.home),
        "awayLabel": slot_label(t, fixture.away),
        "homeId": resolved_id(fixture.home),
        "awayId": resolved_id(fixture.away),
        "state": fixture_state_name(fixture_state(t, fixture)),
        "result": match t.results.get(fixture.id) {
          Some(r) => result_to_json(r)
          None => Json::null()
        },
      } : Json)
  })
  let stages = if t.format == Groups || t.format == GroupsDouble {
    Array::makei(t.group_count, i => "group-" + (i + 1).to_string())
  } else if t.format == SwissPlayoff {
    ["swiss"]
  } else if t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff {
    ["league"]
  } else {
    [""]
  }
  let tables = stages.map(stage => {
    (
      {
        "stage": stage,
        "rows": standings(t, stage~).map(row => standing_to_json(t.rules, row)),
      } : Json)
  })
  {
    "tournament": tournament_to_json(t),
    "fixtures": views,
    "tables": tables,
    "champion": match champion(t) {
      Some(id) => Json(participant_name(t.participants, id))
      None => Json::null()
    },
  }
}
