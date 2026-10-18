///|
fn csv_cell(value : String) -> String {
  // Spreadsheet formulas can execute even inside quoted cells.
  let trimmed = value.trim().to_owned()
  let safe = if trimmed.has_prefix("=") ||
    trimmed.has_prefix("+") ||
    trimmed.has_prefix("-") ||
    trimmed.has_prefix("@") ||
    value.has_prefix("\t") ||
    value.has_prefix("\r") {
    "'" + value
  } else {
    value
  }
  "\"" + safe.replace_all(old="\"", new="\"\"") + "\""
}

///|
pub fn slot_label(t : Tournament, slot : Slot) -> String {
  match resolve_slot(t, slot) {
    Ready(id) => participant_name(t.participants, id)
    Vacant => "Bye"
    Pending =>
      match slot {
        Winner(id) => "Winner of " + id
        Loser(id) => "Loser of " + id
        _ => "Pending"
      }
  }
}

///|
pub fn fixtures_csv(t : Tournament) -> String {
  let out = StringBuilder()
  out.write_string(
    "fixture,stage,round,home,away,status,home_score,away_score\n",
  )
  for fixture in t.fixtures {
    let status = fixture_state_name(fixture_state(t, fixture))
    let result = t.results.get(fixture.id)
    let home = match result {
      Some(r) => r.score.home.to_string()
      None => ""
    }
    let away = match result {
      Some(r) => r.score.away.to_string()
      None => ""
    }
    out.write_string(
      [
        csv_cell(fixture.id),
        csv_cell(fixture.stage),
        fixture.round.to_string(),
        csv_cell(slot_label(t, fixture.home)),
        csv_cell(slot_label(t, fixture.away)),
        status,
        home,
        away,
      ].join(",") +
      "\n",
    )
  }
  out.to_string()
}

///|
pub fn standings_csv(t : Tournament, stage? : String = "") -> String {
  let out = StringBuilder()
  out.write_string(
    "stage,rank,name,played,won,drawn,lost,points,scored,conceded,sets_won,sets_lost,byes\n",
  )
  let stages = if (t.format == Groups || t.format == GroupsDouble) &&
    stage == "" {
    Array::makei(t.group_count, i => "group-" + (i + 1).to_string())
  } else if t.format == SwissPlayoff && stage == "" {
    ["swiss"]
  } else if (t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff) &&
    stage == "" {
    ["league"]
  } else {
    [stage]
  }
  for stage in stages {
    for row in standings(t, stage~) {
      out.write_string(
        [
          csv_cell(stage),
          row.rank.to_string(),
          csv_cell(row.participant.name),
          row.played.to_string(),
          row.wins.to_string(),
          row.draws.to_string(),
          row.losses.to_string(),
          display_points(row.points, t.rules.point_scale),
          row.scored.to_string(),
          row.conceded.to_string(),
          row.sets_won.to_string(),
          row.sets_lost.to_string(),
          row.byes.to_string(),
        ].join(",") +
        "\n",
      )
    }
  }
  out.to_string()
}

///|
pub fn schedule_csv(schedule : Schedule) -> String {
  let out = StringBuilder()
  out.write_string("fixture,court,start_minutes,end_minutes\n")
  for item in schedule.allocations {
    out.write_string(
      csv_cell(item.fixture_id) +
      "," +
      item.court.to_string() +
      "," +
      item.start.to_string() +
      "," +
      (item.start + item.duration).to_string() +
      "\n",
    )
  }
  out.to_string()
}

///|
pub fn fixture_state_name(state : FixtureState) -> String {
  match state {
    Waiting => "waiting"
    Playable => "ready"
    Automatic => "bye"
    Finished => "finished"
    Inactive => "inactive"
  }
}

///|
fn markdown_cell(value : String) -> String {
  value
  .replace_all(old="|", new="\\|")
  .replace_all(old="\n", new=" ")
  .replace_all(old="\r", new=" ")
}

///|
pub fn tournament_report(t : Tournament) -> String {
  let out = StringBuilder()
  out.write_string("# " + markdown_cell(t.title) + "\n\n")
  out.write_string(
    "Sport: " +
    sport_name(t.rules.sport) +
    " · Format: " +
    format_name(t.format) +
    "\n\n",
  )
  out.write_string("Rule scope: " + t.rules.scope + "\n\n")
  out.write_string(
    "| Fixture | Round | Home | Away | Result |\n|---|---:|---|---|---|\n",
  )
  for fixture in t.fixtures {
    let result = match t.results.get(fixture.id) {
      Some(r) => r.score.home.to_string() + "-" + r.score.away.to_string()
      None => fixture_state_name(fixture_state(t, fixture))
    }
    out.write_string(
      "| " +
      markdown_cell(fixture.id) +
      " | " +
      fixture.round.to_string() +
      " | " +
      markdown_cell(slot_label(t, fixture.home)) +
      " | " +
      markdown_cell(slot_label(t, fixture.away)) +
      " | " +
      result +
      " |\n",
    )
  }
  let stages = if t.format == Groups || t.format == GroupsDouble {
    Array::makei(t.group_count, i => "group-" + (i + 1).to_string())
  } else if t.format == SwissPlayoff {
    ["swiss"]
  } else if t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff {
    ["league"]
  } else {
    [""]
  }
  for stage in stages {
    out.write_string(
      "\n## Standings " +
      stage +
      "\n\n| Rank | Entrant | P | W | D | L | Points |\n|---:|---|---:|---:|---:|---:|---:|\n",
    )
    for row in standings(t, stage~) {
      out.write_string(
        "| " +
        row.rank.to_string() +
        " | " +
        markdown_cell(row.participant.name) +
        " | " +
        row.played.to_string() +
        " | " +
        row.wins.to_string() +
        " | " +
        row.draws.to_string() +
        " | " +
        row.losses.to_string() +
        " | " +
        display_points(row.points, t.rules.point_scale) +
        " |\n",
      )
    }
  }
  out.to_string()
}
