///|
/// A collection is an archive of independent event snapshots, not one long
/// tournament. Scores from different rule profiles are never added together.
pub fn new_season_series(title : String) -> SeasonSeries raise FixtureError {
  require(
    title.trim().length() > 0 && title.length() <= 160,
    "Use a series title of 1 to 160 characters.",
  )
  { title: title.trim().to_owned(), seasons: [], }
}

///|
pub fn validate_season_series(series : SeasonSeries) -> Unit raise FixtureError {
  require(
    series.title.trim().length() > 0 &&
    series.title.length() <= 160 &&
    series.title == series.title.trim().to_owned(),
    "Invalid series title.",
  )
  require(
    series.seasons.length() <= 32,
    "A series supports at most 32 seasons.",
  )
  let keys : Map[String, Bool] = Map([])
  let labels : Map[String, Bool] = Map([])
  for season in series.seasons {
    require(
      season.key.trim().length() > 0 &&
      season.key.length() <= 60 &&
      season.key == season.key.trim().to_owned(),
      "A season key must be 1 to 60 characters without surrounding spaces.",
    )
    require(
      season.label.trim().length() > 0 &&
      season.label.length() <= 120 &&
      season.label == season.label.trim().to_owned(),
      "A season label must be 1 to 120 characters.",
    )
    require(!keys.contains(season.key), "Duplicate season key.")
    require(!labels.contains(season.label), "Duplicate season label.")
    keys[season.key] = true
    labels[season.label] = true
    validate_tournament(season.tournament)
    let names : Map[String, Bool] = Map([])
    for participant in season.tournament.participants {
      require(
        !names.contains(participant.name),
        "Entrant names must be unique within a season for series history.",
      )
      names[participant.name] = true
    }
  }
}

///|
pub fn next_season_key(series : SeasonSeries) -> String raise FixtureError {
  validate_season_series(series)
  for number in 1..<=33 {
    let key = "season-" + number.to_string()
    if !series.seasons.any(season => season.key == key) {
      return key
    }
  }
  raise InvalidInput("No season key is available.")
}

///|
pub fn rename_season_series(
  series : SeasonSeries,
  title : String,
) -> SeasonSeries raise FixtureError {
  validate_season_series(series)
  let changed = { ..series, title: title.trim().to_owned(), }
  validate_season_series(changed)
  changed
}

///|
pub fn add_season(
  series : SeasonSeries,
  key : String,
  label : String,
  tournament : Tournament,
) -> SeasonSeries raise FixtureError {
  validate_season_series(series)
  let seasons = series.seasons.copy()
  seasons.push({ key, label: label.trim().to_owned(), tournament, })
  let added = { ..series, seasons, }
  validate_season_series(added)
  added
}

///|
pub fn update_season(
  series : SeasonSeries,
  key : String,
  tournament : Tournament,
) -> SeasonSeries raise FixtureError {
  validate_season_series(series)
  require(
    series.seasons.any(season => season.key == key),
    "Unknown season key.",
  )
  let seasons = series.seasons.map(season => {
    if season.key == key {
      { ..season, tournament, }
    } else {
      season
    }
  })
  let changed = { ..series, seasons, }
  validate_season_series(changed)
  changed
}

///|
pub fn remove_season(
  series : SeasonSeries,
  key : String,
) -> SeasonSeries raise FixtureError {
  validate_season_series(series)
  require(
    series.seasons.any(season => season.key == key),
    "Unknown season key.",
  )
  { ..series, seasons: series.seasons.filter(season => season.key != key), }
}

///|
pub fn clone_season(
  series : SeasonSeries,
  source_key : String,
  key : String,
  label : String,
  title : String,
) -> SeasonSeries raise FixtureError {
  validate_season_series(series)
  let mut found : Tournament? = None
  for season in series.seasons {
    if season.key == source_key {
      found = Some(season.tournament)
    }
  }
  let source = match found {
    Some(tournament) => tournament
    None => raise InvalidInput("Unknown source season.")
  }
  let participants = source.participants.map(p => { ..p, active: true, })
  let fresh = create_tournament(
    title,
    source.format,
    source.rules,
    participants,
    group_count=if source.group_count == 0 { 2 } else { source.group_count },
    qualifiers=if source.qualifiers == 0 { 2 } else { source.qualifiers },
    third_place=source.fixtures.any(f => f.stage == "third-place"),
    swiss_rounds=if source.swiss_rounds == 0 { 3 } else { source.swiss_rounds },
  )
  add_season(series, key, label, fresh)
}

///|
pub fn season_series_to_json(series : SeasonSeries) -> Json {
  {
    "seasonSeriesVersion": 1,
    "title": series.title,
    "seasons": series.seasons.map(season => {
      (
        {
          "key": season.key,
          "label": season.label,
          "tournament": tournament_to_json(season.tournament),
        } : Json)
    }),
  }
}

///|
pub fn season_series_from_json(value : Json) -> SeasonSeries raise FixtureError {
  object_required(value, "season series")
  require(
    int_value(field(value, "seasonSeriesVersion"), "seasonSeriesVersion") == 1,
    "Unsupported season series version.",
  )
  let raw = array_value(field(value, "seasons"), "seasons")
  require(raw.length() <= 32, "A series supports at most 32 seasons.")
  let series : SeasonSeries = {
    title: text_value(field(value, "title"), "series title"),
    seasons: raw.map(item => {
      (
        {
          key: text_value(field(item, "key"), "season key"),
          label: text_value(field(item, "label"), "season label"),
          tournament: tournament_from_json(field(item, "tournament")),
        } : SeasonRecord)
    }),
  }
  validate_season_series(series)
  series
}

///|
/// Round-robin and Club Swiss can have a unique table winner without a final.
/// Combined formats need their knockout winner, even if the first stage ended.
pub fn season_winner(t : Tournament) -> Int32? {
  match champion(t) {
    Some(id) => return Some(id)
    None => ()
  }
  if t.format != RoundRobin && t.format != DoubleRoundRobin && t.format != Swiss {
    return None
  }
  for fixture in t.fixtures {
    let state = fixture_state(t, fixture)
    if state != Finished && state != Automatic {
      return None
    }
  }
  let rows = standings(t, stage=if t.format == Swiss { "swiss" } else { "" })
  if rows.length() == 0 || (rows.length() > 1 && rows[0].rank == rows[1].rank) {
    None
  } else {
    Some(rows[0].participant.id)
  }
}

///|
pub fn season_series_view_to_json(series : SeasonSeries) -> Json {
  let seasons = series.seasons.map(season => {
    let t = season.tournament
    let mut finished = 0
    for fixture in t.fixtures {
      let state = fixture_state(t, fixture)
      if state == Finished || state == Automatic {
        finished = finished + 1
      }
    }
    (
      {
        "key": season.key,
        "label": season.label,
        "title": t.title,
        "sport": sport_name(t.rules.sport),
        "format": format_name(t.format),
        "entrants": t.participants.length(),
        "finished": finished,
        "fixtures": t.fixtures.length(),
        "champion": match season_winner(t) {
          Some(id) => Json(participant_name(t.participants, id))
          None => Json::null()
        },
      } : Json)
  })
  let names : Array[String] = []
  let first_seen : Map[String, Int32] = Map([])
  let appearances : Map[String, Int32] = Map([])
  let titles : Map[String, Int32] = Map([])
  for season in series.seasons {
    let winner = season_winner(season.tournament)
    for participant in season.tournament.participants {
      let name = participant.name
      if !appearances.contains(name) {
        first_seen[name] = names.length()
        names.push(name)
      }
      appearances[name] = appearances.get(name).unwrap_or(0) + 1
      if winner == Some(participant.id) {
        titles[name] = titles.get(name).unwrap_or(0) + 1
      }
    }
  }
  names.sort_by((a, b) => {
    let title_order = compare_int(
      titles.get(b).unwrap_or(0),
      titles.get(a).unwrap_or(0),
    )
    if title_order != 0 {
      title_order
    } else {
      let appearance_order = compare_int(appearances[b], appearances[a])
      if appearance_order != 0 {
        appearance_order
      } else {
        compare_int(first_seen[a], first_seen[b])
      }
    }
  })
  {
    "collection": season_series_to_json(series),
    "seasons": seasons,
    "history": names.map(name => {
      (
        {
          "name": name,
          "appearances": appearances[name],
          "titles": titles.get(name).unwrap_or(0),
        } : Json)
    }),
  }
}

///|
pub fn season_series_csv(series : SeasonSeries) -> String {
  let out = StringBuilder()
  out.write_string(
    "season,title,sport,format,entrants,finished,fixtures,champion\n",
  )
  for season in series.seasons {
    let t = season.tournament
    let mut finished = 0
    for fixture in t.fixtures {
      let state = fixture_state(t, fixture)
      if state == Finished || state == Automatic {
        finished = finished + 1
      }
    }
    let winner = match season_winner(t) {
      Some(id) => participant_name(t.participants, id)
      None => ""
    }
    out.write_string(
      [
        csv_cell(season.label),
        csv_cell(t.title),
        csv_cell(sport_name(t.rules.sport)),
        csv_cell(format_name(t.format)),
        t.participants.length().to_string(),
        finished.to_string(),
        t.fixtures.length().to_string(),
        csv_cell(winner),
      ].join(",") +
      "\n",
    )
  }
  out.to_string()
}

///|
pub fn season_history_csv(series : SeasonSeries) -> String raise FixtureError {
  let out = StringBuilder()
  out.write_string("entrant,seasons_entered,titles\n")
  let view = season_series_view_to_json(series)
  let history = array_value(field(view, "history"), "history")
  for item in history {
    out.write_string(
      csv_cell(text_value(field(item, "name"), "entrant name")) +
      "," +
      int_value(field(item, "appearances"), "appearances").to_string() +
      "," +
      int_value(field(item, "titles"), "titles").to_string() +
      "\n",
    )
  }
  out.to_string()
}
