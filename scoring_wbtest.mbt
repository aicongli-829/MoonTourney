///|
test "badminton cap and extension require a terminal score" {
  for
    (home, away) in [(21, 0), (21, 19), (22, 20), (29, 27), (30, 28), (30, 29)] {
    validate_game({ home, away, }, 21, 2, 30)
    validate_game({ home: away, away: home, }, 21, 2, 30)
  }
  for
    (home, away) in [
      (20, 18),
      (21, 20),
      (22, 19),
      (29, 29),
      (30, 27),
      (31, 29),
      (-1, 21),
    ] {
    assert_true(rejects(() => validate_game({ home, away, }, 21, 2, 30)))
  }
  let r = preset("badminton-15")
  validate_game({ home: 21, away: 20, }, r.target, r.win_by, r.cap)
  assert_true(
    rejects(() => {
      validate_game({ home: 22, away: 20, }, r.target, r.win_by, r.cap)
    }),
  )
}

///|
test "table tennis has no hard cap and requires clear two points" {
  for
    score in [
      { home: 11, away: 0, },
      { home: 12, away: 10, },
      { home: 43, away: 41, },
    ] {
    validate_game(score, 11, 2, 0)
  }
  for
    score in [
      { home: 11, away: 10, },
      { home: 12, away: 9, },
      { home: 9, away: 9, },
    ] {
    assert_true(rejects(() => validate_game(score, 11, 2, 0)))
  }
  assert_true(rejects(() => ignore(with_best_of(preset("table-tennis"), 4))))
  assert_eq(with_best_of(preset("table-tennis"), 7).best_of, 7)
}

///|
test "volleyball deciding set uses 15 and narrow match allocates 2 and 1 points" {
  let r = preset("volleyball")
  let games : Array[Score] = [
    { home: 25, away: 20, },
    { home: 20, away: 25, },
    { home: 25, away: 23, },
    { home: 23, away: 25, },
    { home: 15, away: 13, },
  ]
  let result = set_result("v", games)
  validate_result(r, result)
  assert_eq(result.score, { home: 3, away: 2, })
  assert_eq(match_points(r, result), { home: 2, away: 1, })
  let bad_games = games.copy()
  bad_games[4] = { home: 25, away: 13, }
  assert_true(rejects(() => validate_result(r, set_result("v", bad_games))))
  let sweep = set_result("v", [
    { home: 25, away: 20, },
    { home: 25, away: 19, },
    { home: 25, away: 18, },
  ])
  validate_result(r, sweep)
  assert_eq(match_points(r, sweep), { home: 3, away: 0, })
}

///|
test "beach volleyball deciding set differs from opening sets" {
  let r = preset("beach-volleyball")
  validate_result(
    r,
    set_result("beach", [
      { home: 21, away: 19, },
      { home: 18, away: 21, },
      { home: 17, away: 15, },
    ]),
  )
  assert_true(
    rejects(() => {
      validate_result(
        r,
        set_result("beach", [{ home: 15, away: 13, }, { home: 15, away: 13, }]),
      )
    }),
  )
}

///|
test "set series rejects incomplete matches, aggregate mismatch and games after victory" {
  let r = preset("badminton-21")
  let games : Array[Score] = [{ home: 21, away: 18, }, { home: 21, away: 19, }]
  let valid = set_result("b", games)
  validate_result(r, valid)
  assert_true(rejects(() => validate_result(r, set_result("b", [games[0]]))))
  assert_true(
    rejects(() => validate_result(r, { ..valid, score: { home: 1, away: 1, }, })),
  )
  assert_true(
    rejects(() => {
      validate_result(r, set_result("b", [games[0], games[1], games[0]]))
    }),
  )
  assert_true(rejects(() => validate_result(r, { ..valid, decider: Some(1), })))
}

///|
test "basketball must have a winner and forfeit uses FIBA subset" {
  let r = preset("basketball")
  validate_result(r, score_result("basket", 103, 99))
  assert_true(rejects(() => validate_result(r, score_result("basket", 80, 80))))
  let forfeited = forfeit_result(r, "basket", 2)
  validate_result(r, forfeited)
  assert_eq(forfeited.score, { home: 0, away: 20, })
  assert_eq(match_points(r, forfeited), { home: 0, away: 2, })
  assert_eq(match_points(r, score_result("basket", 80, 79)), {
    home: 2,
    away: 1,
  })
}

///|
test "football drawn knockout requires a shootout winner" {
  let r = preset("football")
  validate_result(r, score_result("f", 2, 2))
  assert_true(
    rejects(() => validate_result(r, score_result("f", 2, 2), decisive=true)),
  )
  validate_result(r, score_result("f", 2, 2, decider=Some(2)), decisive=true)
  assert_eq(winner_side(score_result("f", 2, 2, decider=Some(2))), Some(2))
  assert_true(
    rejects(() => validate_result(r, score_result("f", 2, 1, decider=Some(1)))),
  )
  assert_true(
    rejects(() => validate_result(r, score_result("f", 1, 1, decider=Some(3)))),
  )
}

///|
test "chess uses exact half-point units and explicit draw input" {
  let r = preset("chess")
  for (a, b) in [(1, 0), (0, 1), (1, 1)] {
    validate_result(r, score_result("c", a, b))
  }
  for (a, b) in [(0, 0), (2, 0), (1, 2)] {
    assert_true(rejects(() => validate_result(r, score_result("c", a, b))))
  }
  assert_eq(match_points(r, score_result("c", 1, 1)), { home: 1, away: 1, })
  assert_eq(display_points(1, 2), "0.5")
  assert_eq(display_points(5, 2), "2.5")
  assert_eq(display_points(6, 2), "3")
}

///|
test "esports maps are decisive binary wins with customizable series length" {
  let r = with_best_of(preset("esports"), 5)
  let result = set_result("maps", [
    { home: 1, away: 0, },
    { home: 0, away: 1, },
    { home: 1, away: 0, },
    { home: 1, away: 0, },
  ])
  validate_result(r, result)
  assert_true(rejects(() => validate_game({ home: 2, away: 0, }, 1, 1, 1)))
  assert_true(rejects(() => validate_game({ home: 1, away: 1, }, 1, 1, 1)))
}

///|
test "canonical forfeits validate across every sport and both sides" {
  for r in rule_presets() {
    validate_rules(r)
    for side in [1, 2] {
      let result = forfeit_result(r, "walkover", side)
      validate_result(r, result, decisive=true)
      assert_eq(winner_side(result), Some(side))
      assert_eq(
        if side == 1 {
          match_points(r, result).away
        } else {
          match_points(r, result).home
        },
        0,
      )
      assert_true(
        rejects(() => {
          validate_result(r, { ..result, score: { home: 7, away: 7, }, })
        }),
      )
    }
  }
}

///|
test "multi-match series can be incomplete or clinched, never continued after clinch" {
  let r = preset("basketball")
  let a = score_result("game-1", 101, 98)
  let b = score_result("game-2", 95, 102)
  let c = score_result("game-3", 110, 100)
  let open = summarize_series(r, [a, b], 3)
  assert_eq(open.complete, false)
  assert_eq(open.next_game, 3)
  let done = summarize_series(r, [a, b, c], 3)
  assert_eq(done.winner_side, Some(1))
  assert_eq(done.next_game, 0)
  assert_true(rejects(() => ignore(summarize_series(r, [a, a], 3))))
  assert_true(rejects(() => ignore(summarize_series(r, [a, c, b], 3))))
  assert_true(rejects(() => ignore(summarize_series(r, [], 4))))
}

///|
test "open score accepts draws in a table but requires a knockout winner" {
  let rules = preset("open-score")
  let draw = score_result("game", 2, 2)
  validate_result(rules, draw)
  assert_eq(match_points(rules, draw).home, 1)
  assert_true(rejects(() => validate_result(rules, draw, decisive=true)))
  let decided = score_result("game", 2, 2, decider=Some(2))
  validate_result(rules, decided, decisive=true)
  assert_eq(winner_side(decided), Some(2))
  assert_true(rejects(() => validate_result(rules, decided)))
  assert_true(
    rejects(() => {
      validate_result(
        rules,
        score_result("game", 2, 1, decider=Some(1)),
        decisive=true,
      )
    }),
  )
}

///|
test "rule overrides survive serialization and disclose organizer policies" {
  let custom = with_seed_tie_break(
    with_best_of(preset("table-tennis"), 7),
    true,
  )
  assert_eq(rules_from_json(rules_to_json(custom)), custom)
  assert_true(custom.label.contains("best of 7"))
  assert_true(custom.scope.contains("organizer policies"))
  assert_true(custom.tie_breaks.contains(SeedOrder))
  assert_false(
    with_seed_tie_break(custom, false).tie_breaks.contains(SeedOrder),
  )
  assert_true(
    rejects(() => validate_rules({ ..custom, tie_breaks: [Points, Points], })),
  )
  assert_true(rejects(() => validate_rules({ ..custom, cap: 5, })))
  assert_true(rejects(() => ignore(preset("unknown"))))
}
