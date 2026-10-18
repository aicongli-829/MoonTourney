///|
test "JSON round trips completed tournaments with custom rules in every format" {
  for
    format in [
      RoundRobin,
      DoubleRoundRobin,
      SingleElimination,
      DoubleElimination,
      Groups,
      Swiss,
    ] {
    let rules = with_seed_tie_break(preset("football"), true)
    let t = complete_ready(
      create_tournament("Save & restore", format, rules, entrants(8)),
    )
    let decoded = tournament_from_json(
      @json.parse(tournament_to_json(t).stringify()),
    )
    assert_eq(decoded, t)
    assert_eq(view_to_json(decoded), view_to_json(t))
  }
}

///|
test "JSON round trips set-based matches and canonical forfeits" {
  for r in rule_presets() {
    let t = create_tournament("Sport", SingleElimination, r, entrants(2))
    let played = record_result(t, forfeit_result(r, t.fixtures[0].id, 2))
    assert_eq(tournament_from_json(tournament_to_json(played)), played)
  }
}

///|
test "API rejects invalid parser, fractions, unknown presets and malformed entrant types" {
  for
    source in [
      "not json", "[]", "{\"action\":\"create\",\"entrants\":[\"A\",3]}", "{\"action\":\"create\",\"rules\":\"missing\",\"entrants\":[\"A\",\"B\"]}",
      "{\"action\":\"create\",\"rules\":\"football\",\"entrants\":[\"A\",\"B\"],\"groupCount\":2.5}",
    ] {
    let envelope = @json.parse(dispatch_json(source))
    assert_eq(field(envelope, "ok"), (false : Json))
    assert_true(text_value(field(envelope, "error"), "error").length() > 0)
  }
}

///|
test "API create, record, clear and inspect exercise complete JSON boundary" {
  let created = @json.parse(
    dispatch_json(
      (
        {
          "action": "create",
          "format": "single-elimination",
          "rules": "football",
          "entrants": ["A", "B", "C", "D"],
        } : Json).stringify(),
    ),
  )
  assert_eq(field(created, "ok"), (true : Json))
  let initial = field(field(created, "data"), "tournament")
  let recorded = @json.parse(
    dispatch_json(
      (
        {
          "action": "record",
          "tournament": initial,
          "result": { "fixtureId": "w-1-1", "home": 2, "away": 1 },
        } : Json).stringify(),
    ),
  )
  assert_eq(field(recorded, "ok"), (true : Json))
  let event = field(field(recorded, "data"), "tournament")
  assert_eq(tournament_from_json(event).results.length(), 1)
  let cleared = @json.parse(
    dispatch_json(
      ({ "action": "clear", "tournament": event, "fixtureId": "w-1-1" } : Json).stringify(),
    ),
  )
  assert_eq(
    tournament_from_json(field(field(cleared, "data"), "tournament")).results.length(),
    0,
  )
  assert_eq(tournament_from_json(initial).results.length(), 0)
}

///|
test "import validates schema, participant identity and dependency references" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  let encoded = tournament_to_json(t)
  let fields = match encoded {
    Object(fields) => fields.copy()
    _ => Map([])
  }
  fields["schemaVersion"] = number_json(9)
  assert_true(rejects(() => ignore(tournament_from_json(Json::object(fields)))))
  let duplicate = t.participants.copy()
  duplicate[1] = { ..duplicate[1], id: duplicate[0].id, }
  assert_true(
    rejects(() => {
      ignore(
        tournament_from_json(
          tournament_to_json({ ..t, participants: duplicate, }),
        ),
      )
    }),
  )
  let broken = t.fixtures.copy()
  broken[0] = { ..broken[0], home: Seed(999), }
  assert_true(
    rejects(() => {
      ignore(
        tournament_from_json(tournament_to_json({ ..t, fixtures: broken, })),
      )
    }),
  )
}

///|
test "import rejects duplicate results and results for unresolved games" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  let impossible = t.results.copy()
  impossible["w-2-1"] = score_result("w-2-1", 1, 0)
  assert_true(
    rejects(() => {
      ignore(
        tournament_from_json(tournament_to_json({ ..t, results: impossible, })),
      )
    }),
  )
  let fields = match tournament_to_json(t) {
    Object(fields) => fields.copy()
    _ => Map([])
  }
  let result = result_to_json(score_result("w-1-1", 1, 0))
  fields["results"] = Json([result, result])
  assert_true(rejects(() => ignore(tournament_from_json(Json::object(fields)))))
}

///|
test "undo and redo retain isolated previous snapshots and clear redo branch" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  let a = record_result(t, score_result("w-1-1", 1, 0))
  let b = record_result(a, score_result("w-1-2", 1, 0))
  let history = commit_history(commit_history(new_history(t), a), b)
  assert_eq(undo(history).current, a)
  assert_eq(redo(undo(history)).current, b)
  assert_eq(undo(undo(history)).current, t)
  let branch = commit_history(
    undo(history),
    record_result(a, score_result("w-1-2", 0, 1)),
  )
  assert_eq(branch.future.length(), 0)
  assert_eq(history.current, b)
  assert_eq(t.results.length(), 0)
  assert_eq(a.results.length(), 1)
}

///|
test "history bound retains 100 steps and no-op commits do not grow it" {
  let t = create_tournament(
    "League",
    RoundRobin,
    preset("football"),
    entrants(2),
  )
  let mut history = new_history(t)
  for i in 0..<130 {
    history = commit_history(history, {
      ..t,
      title: "Revision " + i.to_string(),
    })
  }
  assert_eq(history.past.length(), 100)
  assert_eq(commit_history(history, history.current), history)
  assert_eq(redo(history), history)
  assert_eq(undo(new_history(t)).current, t)
}

///|
test "CSV guards formulas and quotes, report escapes table separators" {
  assert_eq(csv_cell("=1+1"), "\"'=1+1\"")
  assert_eq(csv_cell("\t=1+1"), "\"'\t=1+1\"")
  assert_eq(csv_cell("  @SUM(A1)"), "\"'  @SUM(A1)\"")
  assert_eq(csv_cell("A,\"B\""), "\"A,\"\"B\"\"\"")
  let p = participants_from_names(["=HYPERLINK(\"x\")", "A | B"])
  let t = create_tournament("Cup", RoundRobin, preset("football"), p)
  assert_true(fixtures_csv(t).contains("'=HYPERLINK"))
  assert_true(tournament_report(t).contains("A \\| B"))
  assert_true(standings_csv(t).contains("points"))
}

///|
test "invalid JSON action and forfeit winner return errors rather than panic" {
  let t = tournament_to_json(
    create_tournament("Cup", SingleElimination, preset("football"), entrants(2)),
  )
  for action in ["unknown", "advance", "next-round"] {
    let envelope = @json.parse(
      dispatch_json(({ "action": action, "tournament": t } : Json).stringify()),
    )
    assert_eq(field(envelope, "ok"), (false : Json))
  }
  let envelope = @json.parse(
    dispatch_json(
      (
        {
          "action": "record",
          "tournament": t,
          "result": { "fixtureId": "w-1-1", "kind": "forfeit", "winnerSide": 0 },
        } : Json).stringify(),
    ),
  )
  assert_eq(field(envelope, "ok"), (false : Json))
}
