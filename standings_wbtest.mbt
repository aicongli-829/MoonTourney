///|
test "league points, goals and ranks follow match results" {
  let t = create_tournament(
    "League",
    RoundRobin,
    preset("football"),
    entrants(3),
  )
  let mut played = t
  for f in t.fixtures {
    match (f.home, f.away) {
      (Seed(a), Seed(b)) =>
        played = record_result(
          played,
          score_result(
            f.id,
            if a < b {
              2
            } else {
              0
            },
            if a < b {
              0
            } else {
              2
            },
          ),
        )
      _ => ()
    }
  }
  let table = standings(played)
  assert_eq(table.map(r => r.participant.id), [1, 2, 3])
  assert_eq(table.map(r => r.points), [6, 3, 0])
  assert_eq(table.map(r => r.scored), [4, 2, 0])
  assert_eq(table.map(r => r.conceded), [0, 2, 4])
  assert_eq(table.map(r => r.played), [2, 2, 2])
}

///|
test "ratio comparisons are exact at zero and large cross products" {
  assert_eq(compare_ratio(3, 0, 5, 0), 0)
  assert_eq(compare_ratio(3, 0, 5, 2), 1)
  assert_eq(compare_ratio(0, 0, 0, 1), 0)
  assert_eq(compare_ratio(0, 0, 1, 1), -1)
  assert_eq(compare_ratio(2, 3, 4, 6), 0)
  assert_eq(compare_ratio(2000000000, 1000000000, 1000000000, 1000000000), 1)
}

///|
test "equal ranks use seed only for stable display unless explicitly configured" {
  let t = create_tournament(
    "League",
    RoundRobin,
    preset("football"),
    entrants(4),
  )
  assert_eq(standings(t).map(r => r.rank), [1, 1, 1, 1])
  let seeded = { ..t, rules: with_seed_tie_break(t.rules, true), }
  assert_eq(standings(seeded).map(r => r.rank), [1, 2, 3, 4])
}

///|
test "head-to-head mini table has transitive equality for a three-team cycle" {
  let t = create_tournament(
    "Cycle",
    RoundRobin,
    rules_from_json({
      "id": "football",
      "tieBreaks": ["points", "head-to-head"],
    }),
    entrants(3),
  )
  let mut played = t
  for f in t.fixtures {
    match (f.home, f.away) {
      (Seed(a), Seed(b)) => {
        let winner = if same_pair(a, b, 1, 2) {
          1
        } else if same_pair(a, b, 2, 3) {
          2
        } else {
          3
        }
        played = record_result(
          played,
          score_result(
            f.id,
            if a == winner {
              1
            } else {
              0
            },
            if b == winner {
              1
            } else {
              0
            },
          ),
        )
      }
      _ => ()
    }
  }
  assert_eq(standings(played).map(r => r.rank), [1, 1, 1])
  assert_eq(standings(played).map(r => r.head_to_head), [3, 3, 3])
}

///|
test "Swiss draws yield opponent-based Buchholz and Sonneborn-Berger" {
  let t = create_tournament("Club", Swiss, preset("chess"), entrants(4))
  let mut played = t
  for f in t.fixtures {
    played = record_result(played, score_result(f.id, 1, 1))
  }
  let next = next_swiss_round(played)
  for f in next.fixtures {
    if f.round == 2 {
      played = { ..played, fixtures: next.fixtures, }
      played = record_result(played, score_result(f.id, 1, 1))
    }
  }
  for row in standings(played) {
    assert_eq(row.points, 2)
    assert_eq(row.buchholz, 4)
    assert_eq(row.buchholz_cut_one, 2)
    assert_eq(row.sonneborn_berger, 4)
    assert_eq(row.draws, 2)
  }
}

///|
test "forfeited opponents do not inflate played-opponent tie-breaks" {
  let t = create_tournament("Club", Swiss, preset("chess"), entrants(2))
  let played = record_result(t, forfeit_result(t.rules, t.fixtures[0].id, 1))
  for row in standings(played) {
    assert_eq(row.buchholz, 0)
    assert_eq(row.sonneborn_berger, 0)
  }
}

///|
test "volleyball table counts rally totals separately from sets" {
  let t = create_tournament(
    "Volley",
    RoundRobin,
    preset("volleyball"),
    entrants(2),
  )
  let r = set_result(t.fixtures[0].id, [
    { home: 25, away: 20, },
    { home: 25, away: 19, },
    { home: 25, away: 18, },
  ])
  let table = standings(record_result(t, r))
  assert_eq(table[0].sets_won, 3)
  assert_eq(table[0].sets_lost, 0)
  assert_eq(table[0].scored, 75)
  assert_eq(table[0].conceded, 57)
  assert_eq(table[0].points, 3)
}
