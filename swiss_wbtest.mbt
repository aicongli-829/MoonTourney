///|
test "Swiss rounds avoid rematches and distribute one bye per entrant" {
  for n in [5, 7, 8, 10] {
    let mut t = create_tournament("Club", Swiss, preset("chess"), entrants(n))
    let pairs : Map[String, Bool] = Map([])
    let byes : Map[Int32, Bool] = Map([])
    for round in 1..<=4 {
      for f in t.fixtures {
        if f.round != round {
          continue
        }
        match (f.home, f.away) {
          (Seed(a), Seed(b)) => {
            let key = min_int(a, b).to_string() +
              ":" +
              max_int(a, b).to_string()
            assert_false(pairs.contains(key))
            pairs[key] = true
          }
          (Seed(a), Empty) => {
            assert_false(byes.contains(a))
            byes[a] = true
          }
          _ => fail("Unexpected Swiss slot")
        }
      }
      t = complete_ready(t)
      validate_tournament(t)
      if round < 4 {
        t = next_swiss_round(t)
      }
    }
    if n % 2 == 1 {
      assert_eq(byes.length(), 4)
    }
    for row in standings(t) {
      assert_eq(row.played + row.byes, 4)
    }
  }
}

///|
test "Swiss cannot advance unfinished rounds or pair an exhausted field" {
  let t = create_tournament("Club", Swiss, preset("chess"), entrants(2))
  assert_true(rejects(() => ignore(next_swiss_round(t))))
  assert_true(rejects(() => ignore(next_swiss_round(complete_ready(t)))))
  assert_true(
    rejects(() => {
      ignore(
        next_swiss_round(
          create_tournament(
            "League",
            RoundRobin,
            preset("football"),
            entrants(4),
          ),
        ),
      )
    }),
  )
}

///|
test "editing an earlier Swiss result removes later pairings and results" {
  let round1 = complete_ready(
    create_tournament("Club", Swiss, preset("chess"), entrants(8)),
  )
  let round2 = complete_ready(next_swiss_round(round1))
  let changed = record_result(round2, score_result(round1.fixtures[0].id, 0, 1))
  assert_eq(changed.fixtures.length(), round1.fixtures.length())
  assert_eq(changed.results.length(), round1.results.length())
  assert_true(
    next_swiss_round(changed).fixtures.length() > changed.fixtures.length(),
  )
  assert_eq(round2.results.length(), 8)
}

///|
test "withdrawal settles ready games but excludes entrant from subsequent Swiss round" {
  let t = create_tournament("Club", Swiss, preset("chess"), entrants(8))
  let withdrawn = settle_withdrawals(set_active(t, 1, false))
  assert_eq(withdrawn.results.length(), 1)
  assert_eq(withdrawn.results.values().to_array()[0].kind, Forfeit)
  let next = next_swiss_round(complete_ready(withdrawn))
  for f in next.fixtures {
    if f.round == 2 {
      assert_true(f.home != Seed(1) && f.away != Seed(1))
    }
  }
}

///|
test "Swiss full-point bye supplies no fake played game or opponent" {
  let t = create_tournament("Club", Swiss, preset("chess"), entrants(5))
  let bye = t.fixtures.filter(f => f.away == Empty)[0]
  let id = match bye.home {
    Seed(id) => id
    _ => 0
  }
  let row = standings(t).filter(r => r.participant.id == id)[0]
  assert_eq(row.points, 2)
  assert_eq(row.played, 0)
  assert_eq(row.wins, 0)
  assert_eq(row.buchholz, 0)
  assert_eq(row.byes, 1)
}
