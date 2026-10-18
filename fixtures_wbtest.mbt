///|
fn entrants(n : Int) -> Array[Participant] {
  Array::makei(n, i => {
    (
      {
        id: i + 1,
        name: "Team " + (i + 1).to_string(),
        seed: i + 1,
        active: true,
      } : Participant)
  })
}

///|
fn rejects(operation : () -> Unit raise FixtureError) -> Bool {
  try {
    operation()
    false
  } catch {
    _ => true
  }
}

///|
fn complete_ready(
  tournament : Tournament,
  away? : Bool = false,
) -> Tournament raise FixtureError {
  let mut t = tournament
  for fixture in tournament.fixtures {
    if fixture_state(t, fixture) == Playable {
      let result = if uses_sets(t.rules.sport) {
        forfeit_result(t.rules, fixture.id, if away { 2 } else { 1 })
      } else {
        score_result(
          fixture.id,
          if away {
            0
          } else {
            1
          },
          if away {
            1
          } else {
            0
          },
        )
      }
      t = record_result(t, result)
    }
  }
  t
}

///|
test "round robin covers every unordered pair once, without round conflicts" {
  for n in 2..<=33 {
    let fixtures = round_robin(entrants(n))
    let pairs : Map[String, Bool] = Map([])
    let rounds : Map[String, Bool] = Map([])
    let byes : Map[Int, Int] = Map([])
    for f in fixtures {
      for slot in [f.home, f.away] {
        match slot {
          Seed(id) => {
            let key = f.round.to_string() + ":" + id.to_string()
            assert_false(rounds.contains(key))
            rounds[key] = true
          }
          _ => ()
        }
      }
      match (f.home, f.away) {
        (Seed(a), Seed(b)) => {
          assert_not_eq(a, b)
          let key = min_int(a, b).to_string() + ":" + max_int(a, b).to_string()
          assert_false(pairs.contains(key))
          pairs[key] = true
        }
        (Seed(id), Empty) | (Empty, Seed(id)) =>
          byes[id] = byes.get(id).unwrap_or(0) + 1
        _ => fail("Unexpected slot")
      }
    }
    assert_eq(pairs.length(), n * (n - 1) / 2)
    if n % 2 == 1 {
      for id in 1..<=n {
        assert_eq(byes.get(id), Some(1))
      }
    } else {
      assert_eq(byes.length(), 0)
    }
  }
}

///|
test "double round robin reverses both legs" {
  let fixtures = round_robin(entrants(7), double=true)
  let first = round_robin(entrants(7))
  assert_eq(fixtures.length(), first.length() * 2)
  for i, f in first {
    let second = fixtures[i + first.length()]
    assert_eq(second.home, f.away)
    assert_eq(second.away, f.home)
    assert_eq(second.round, f.round + 7)
  }
}

///|
test "seed placement keeps top two in opposite halves" {
  assert_eq(bracket_seed_order(8), [1, 8, 4, 5, 2, 7, 3, 6])
  for size in [2, 4, 8, 16, 32, 64, 128] {
    let order = bracket_seed_order(size)
    assert_eq(order.length(), size)
    assert_eq(order[0], 1)
    assert_eq(order[size / 2], 2)
  }
  assert_true(rejects(() => ignore(bracket_seed_order(6))))
}

///|
test "single elimination plays n minus one games despite byes" {
  for n in 2..<=32 {
    let t = complete_ready(
      create_tournament(
        "Cup",
        SingleElimination,
        preset("football"),
        entrants(n),
      ),
    )
    assert_eq(t.results.length(), n - 1)
    assert_true(champion(t) != None)
    validate_tournament(t)
  }
}

///|
test "pending opponent is not an automatic bye" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(3),
  )
  let final_game = t.fixtures[t.fixtures.length() - 1]
  assert_eq(fixture_state(t, final_game), Waiting)
  assert_eq(champion(t), None)
  assert_true(
    rejects(() => ignore(record_result(t, score_result(final_game.id, 1, 0)))),
  )
}

///|
test "third place uses the two semifinal losers" {
  let t = complete_ready(
    create_tournament(
      "Cup",
      SingleElimination,
      preset("football"),
      entrants(8),
      third_place=true,
    ),
  )
  let third = find_fixture(t.fixtures, "third-place").unwrap()
  assert_eq(fixture_state(t, third), Finished)
  assert_true(resolve_slot(t, third.home) != resolve_slot(t, third.away))
  assert_eq(t.results.length(), 8)
}

///|
test "double elimination ends with exactly two losses for every non-champion" {
  for away in [false, true] {
    for n in 2..<=24 {
      let t = complete_ready(
        create_tournament(
          "Double cup",
          DoubleElimination,
          preset("football"),
          entrants(n),
        ),
        away~,
      )
      let winner = champion(t).unwrap()
      let losses : Map[Int, Int] = Map([])
      for fixture in t.fixtures {
        match
          (
            resolve_slot(t, fixture.home),
            resolve_slot(t, fixture.away),
            t.results.get(fixture.id),
          ) {
          (Ready(a), Ready(b), Some(r)) => {
            let loser = if winner_side(r) == Some(1) { b } else { a }
            losses[loser] = losses.get(loser).unwrap_or(0) + 1
          }
          _ => ()
        }
      }
      for p in t.participants {
        if p.id != winner {
          assert_eq(losses.get(p.id), Some(2))
        } else {
          assert_true(losses.get(p.id).unwrap_or(0) <= 1)
        }
      }
      assert_eq(t.results.length(), 2 * n - (if away { 1 } else { 2 }))
      assert_eq(
        fixture_state(t, find_fixture(t.fixtures, "grand-reset").unwrap()),
        if away {
          Finished
        } else {
          Inactive
        },
      )
      validate_tournament(t)
    }
  }
}

///|
test "editing a semifinal clears final and third place, preserves other semifinal" {
  let t = complete_ready(
    create_tournament(
      "Cup",
      SingleElimination,
      preset("football"),
      entrants(4),
      third_place=true,
    ),
  )
  let changed = record_result(t, score_result("w-1-1", 0, 2))
  assert_true(changed.results.contains("w-1-2"))
  assert_false(changed.results.contains("w-2-1"))
  assert_false(changed.results.contains("third-place"))
  assert_eq(t.results.length(), 4)
  assert_eq(changed.results.length(), 2)
  assert_eq(champion(changed), None)
}

///|
test "group snake distribution balances sizes and strongest seeds" {
  let groups = distribute_groups(entrants(11), 3)
  assert_eq(groups.map(g => g.length()), [3, 4, 4])
  assert_eq(groups.map(g => g[0].seed), [1, 2, 3])
  assert_true(rejects(() => ignore(distribute_groups(entrants(3), 2))))
}

///|
test "group fixtures interleave matchdays across groups" {
  let fixtures = group_fixtures(entrants(8), 2)
  assert_eq(fixtures.length(), 12)
  assert_eq(fixtures[0].stage, "group-1")
  assert_eq(fixtures[2].stage, "group-2")
  assert_eq(fixtures[4].round, 2)
  assert_eq(fixtures[4].stage, "group-1")
}

///|
test "groups qualify only completed tables and cross groups in opening knockout" {
  for count in [2, 3, 4, 5, 6] {
    let t = create_tournament(
      "Group cup",
      Groups,
      with_seed_tie_break(preset("football"), true),
      entrants(count * 4),
      group_count=count,
      qualifiers=2,
    )
    assert_true(rejects(() => ignore(advance_groups(t))))
    let finished = complete_ready(t)
    let advanced = advance_groups(finished)
    let membership : Map[Int, Int] = Map([])
    for i, group in distribute_groups(t.participants, count) {
      for p in group {
        membership[p.id] = i
      }
    }
    for f in advanced.fixtures {
      if f.stage == "knockout" && f.round == 1 {
        match (resolve_slot(advanced, f.home), resolve_slot(advanced, f.away)) {
          (Ready(a), Ready(b)) => assert_not_eq(membership[a], membership[b])
          _ => ()
        }
      }
    }
    let done = complete_ready(advanced)
    assert_true(champion(done) != None)
    assert_eq(
      standings(done, stage="group-1"),
      standings(finished, stage="group-1"),
    )
    let edited = remove_result(done, "group-1-1-1")
    assert_false(edited.fixtures.any(f => f.stage == "knockout"))
  }
}

///|
test "home-away groups play both legs before knockout qualification" {
  let entrants = entrants(8)
  let once = create_tournament(
    "Single-leg groups",
    Groups,
    preset("football"),
    entrants,
  )
  let t = create_tournament(
    "Home-away groups",
    GroupsDouble,
    with_seed_tie_break(preset("football"), true),
    entrants,
  )
  assert_eq(t.fixtures.length(), once.fixtures.length() * 2)
  assert_true(rejects(() => ignore(advance_groups(t))))
  let finished = complete_ready(t)
  let advanced = advance_groups(finished)
  validate_tournament(advanced)
  let done = complete_ready(advanced)
  assert_true(champion(done) != None)
  let edited = record_result(done, score_result(t.fixtures[0].id, 0, 2))
  assert_false(edited.fixtures.any(f => f.stage == "knockout"))
  validate_tournament(edited)
}

///|
test "league playoffs promote standings and invalidate dependent bracket on edit" {
  for format in [LeaguePlayoff, LeagueDoublePlayoff] {
    let t = create_tournament(
      "Community league",
      format,
      with_seed_tie_break(preset("open-score"), true),
      entrants(8),
      qualifiers=4,
    )
    assert_true(rejects(() => ignore(advance_league(t))))
    assert_eq(
      t.fixtures.length(),
      if format == LeagueDoublePlayoff {
        56
      } else {
        28
      },
    )
    let league = complete_ready(t)
    let before = standings_csv(league)
    let playoff = advance_league(league)
    validate_tournament(playoff)
    assert_eq(playoff.fixtures.filter(f => f.stage == "knockout").length(), 3)
    let qualified = standings(league, stage="league")
    assert_eq(
      resolve_slot(playoff, playoff.fixtures[t.fixtures.length()].home),
      Ready(qualified[0].participant.id),
    )
    let done = complete_ready(playoff)
    assert_true(champion(done) != None)
    assert_eq(standings_csv(done), before)
    assert_eq(tournament_from_json(tournament_to_json(done)), done)
    let changed = record_result(done, score_result(t.fixtures[0].id, 0, 2))
    assert_false(changed.fixtures.any(f => f.stage == "knockout"))
    validate_tournament(changed)
  }
  assert_true(
    rejects(() => {
      ignore(
        create_tournament(
          "Invalid qualifier count",
          LeaguePlayoff,
          preset("open-score"),
          entrants(6),
          qualifiers=3,
        ),
      )
    }),
  )
}

///|
test "equal league ranks cannot silently decide playoff seeds" {
  let t = create_tournament(
    "Equal league",
    LeaguePlayoff,
    preset("open-score"),
    entrants(4),
    qualifiers=2,
  )
  let mut drawn = t
  for fixture in t.fixtures {
    drawn = record_result(drawn, score_result(fixture.id, 0, 0))
  }
  assert_true(rejects(() => ignore(advance_league(drawn))))
}

///|
test "Swiss playoffs require the planned rounds and clear stale bracket on edit" {
  let mut t = create_tournament(
    "Swiss then cup",
    SwissPlayoff,
    with_seed_tie_break(preset("football"), true),
    entrants(8),
    qualifiers=4,
    swiss_rounds=3,
  )
  assert_true(rejects(() => ignore(advance_swiss(t))))
  for round in 1..<=3 {
    t = complete_ready(t)
    validate_tournament(t)
    if round < 3 {
      t = next_swiss_round(t)
    }
  }
  assert_true(rejects(() => ignore(next_swiss_round(t))))
  let advanced = advance_swiss(t)
  validate_tournament(advanced)
  assert_eq(advanced.fixtures.filter(f => f.stage == "knockout").length(), 3)
  assert_eq(standings(advanced, stage="swiss"), standings(t, stage="swiss"))
  let done = complete_ready(advanced)
  assert_true(champion(done) != None)
  let edited = record_result(done, score_result(t.fixtures[0].id, 0, 2))
  assert_false(edited.fixtures.any(f => f.stage == "knockout"))
  assert_true(edited.fixtures.all(f => f.round == 1))
  validate_tournament(edited)
  let restored = tournament_from_json(tournament_to_json(done))
  assert_eq(champion(restored), champion(done))
}

///|
test "unresolved cutoff tie cannot silently qualify by seed" {
  let t = create_tournament(
    "Groups",
    Groups,
    preset("football"),
    entrants(8),
    qualifiers=1,
  )
  let mut drawn = t
  for f in t.fixtures {
    drawn = record_result(drawn, score_result(f.id, 0, 0))
  }
  assert_eq(standings(drawn, stage="group-1")[0].rank, 1)
  assert_eq(standings(drawn, stage="group-1")[1].rank, 1)
  assert_true(rejects(() => ignore(advance_groups(drawn))))
}

///|
test "import graph rejects cycles, duplicates and self play after resolution" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  let cycle = { ..t, fixtures: [{ ..t.fixtures[0], home: Winner("w-2-1"), }], }
  assert_true(rejects(() => validate_tournament(cycle)))
  let duplicate = { ..t, fixtures: [t.fixtures[0], t.fixtures[0]], }
  assert_true(rejects(() => validate_tournament(duplicate)))
  let finished = complete_ready(t)
  let fixtures = finished.fixtures.copy()
  fixtures[2] = { ..fixtures[2], away: fixtures[2].home, }
  assert_true(rejects(() => validate_tournament({ ..finished, fixtures, })))
}
