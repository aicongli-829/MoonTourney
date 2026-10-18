///|
test "declared format cannot hide a forged graph" {
  let t = create_tournament(
    "League",
    RoundRobin,
    preset("football"),
    entrants(4),
  )
  let missing = { ..t, fixtures: [t.fixtures[0]], }
  assert_true(rejects(() => validate_tournament(missing)))
  assert_true(
    rejects(() => validate_tournament({ ..t, format: DoubleElimination, })),
  )
  assert_true(rejects(() => validate_tournament({ ..t, group_count: 2, })))
  assert_true(rejects(() => validate_tournament({ ..t, fixtures: [], })))
}

///|
test "imported Swiss structure rejects repeated pairings and duplicate round appearances" {
  let t = complete_ready(
    create_tournament("Club", Swiss, preset("chess"), entrants(4)),
  )
  let duplicate = { ..t.fixtures[0], id: "extra", round: 2, }
  let fixtures = t.fixtures.copy()
  fixtures.push(duplicate)
  assert_true(rejects(() => validate_tournament({ ..t, fixtures, })))
  let same_round = t.fixtures.copy()
  same_round.push({ ..t.fixtures[0], id: "extra", })
  assert_true(
    rejects(() => validate_tournament({ ..t, fixtures: same_round, })),
  )
  let gap = t.fixtures.map(f => { ..f, round: 3, })
  assert_true(rejects(() => validate_tournament({ ..t, fixtures: gap, })))
}

///|
test "group snapshot cannot substitute an unqualified knockout entrant" {
  let t = advance_groups(
    complete_ready(
      create_tournament(
        "Groups",
        Groups,
        with_seed_tie_break(preset("football"), true),
        entrants(8),
      ),
    ),
  )
  let qualified : Array[Int] = []
  for f in t.fixtures {
    if f.stage == "knockout" && f.round == 1 {
      for slot in [f.home, f.away] {
        match slot {
          Seed(id) => qualified.push(id)
          _ => ()
        }
      }
    }
  }
  let substitute = t.participants.filter(p => !qualified.contains(p.id))[0].id
  let fixtures = t.fixtures.map(f => {
    if f.stage == "knockout" && f.round == 1 {
      { ..f, home: Seed(substitute), }
    } else {
      f
    }
  })
  assert_true(rejects(() => validate_tournament({ ..t, fixtures, })))
}

///|
test "group CSV preserves stage tables after knockout results" {
  let grouped = complete_ready(
    create_tournament(
      "Groups",
      Groups,
      with_seed_tie_break(preset("football"), true),
      entrants(8),
    ),
  )
  let before = standings_csv(grouped)
  let done = complete_ready(advance_groups(grouped))
  assert_eq(standings_csv(done), before)
  assert_true(before.contains("\"group-1\""))
  assert_true(before.contains("\"group-2\""))
}

///|
test "custom volleyball points do not silently apply standard narrow-match split" {
  let rules = rules_from_json({
    "id": "volleyball",
    "winPoints": 2,
    "lossPoints": 0,
  })
  let sweep = set_result("v", [
    { home: 25, away: 20, },
    { home: 25, away: 20, },
    { home: 25, away: 20, },
  ])
  validate_result(rules, sweep)
  assert_eq(match_points(rules, sweep), { home: 2, away: 0, })
  assert_true(rejects(() => ignore(forfeit_result(rules, "v", 3))))
  assert_true(rejects(() => validate_game({ home: 1, away: 0, }, 0, 0, 0)))
}

///|
test "record copies caller-owned set arrays" {
  let t = create_tournament(
    "Badminton",
    SingleElimination,
    preset("badminton-21"),
    entrants(2),
  )
  let result = set_result("w-1-1", [
    { home: 21, away: 18, },
    { home: 21, away: 19, },
  ])
  let recorded = record_result(t, result)
  result.sets[0] = { home: 1, away: 0, }
  assert_eq(recorded.results["w-1-1"].sets[0], { home: 21, away: 18, })
  validate_tournament(recorded)
}

///|
test "largest supported fields build bounded plans" {
  let league = create_tournament(
    "League",
    DoubleRoundRobin,
    preset("football"),
    entrants(128),
  )
  assert_eq(league.fixtures.length(), 16256)
  validate_tournament(league)
  let bracket = create_tournament(
    "Cup",
    DoubleElimination,
    preset("football"),
    entrants(128),
  )
  validate_tournament(bracket)
  let club = create_tournament("Club", Swiss, preset("chess"), entrants(64))
  assert_eq(club.fixtures.length(), 32)
  validate_tournament(club)
  assert_true(
    rejects(() => {
      ignore(create_tournament("Club", Swiss, preset("chess"), entrants(65)))
    }),
  )
}

///|
test "schedule verification bounds arithmetic before adding imported offsets" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(2),
  )
  let allocation : Allocation = {
    fixture_id: "w-1-1",
    start: 2147483647,
    duration: 2147483647,
    court: 1,
  }
  assert_true(
    validate_schedule(t, [allocation], 10).any(e => {
      e.has_prefix("Invalid allocation")
    }),
  )
  assert_eq(validate_schedule(t, [], -1), ["Invalid rest interval."])
}
