///|
/// Reject impossible terminal scores, including rallies after an earlier win.
pub fn validate_game(
  score : Score,
  target : Int,
  win_by : Int,
  cap : Int,
) -> Unit raise FixtureError {
  require(
    target >= 1 && target <= 1000 && win_by >= 1 && win_by <= 10,
    "Invalid game target or winning margin.",
  )
  require(cap == 0 || (cap >= target && cap <= 10000), "Invalid game cap.")
  if score.home < 0 ||
    score.away < 0 ||
    score.home > 10000 ||
    score.away > 10000 {
    raise InvalidResult("Game scores must be between 0 and 10000.")
  }
  let high = max_int(score.home, score.away)
  let low = min_int(score.home, score.away)
  if high == low || high < target {
    raise InvalidResult("A completed game needs a winner at the target.")
  }
  if cap > 0 && high > cap {
    raise InvalidResult("Game score exceeds the hard cap.")
  }
  if cap > 0 && high == cap {
    // Reaching the cap is valid only when the previous rally had not already won.
    if high - 1 >= target && high - 1 - low >= win_by {
      raise InvalidResult("The game should have ended before the cap.")
    }
  } else if high - low < win_by {
    raise InvalidResult("The winner needs the configured clear-point margin.")
  } else if high > target && high - 1 - low >= win_by {
    raise InvalidResult("The game continued after a winning score.")
  }
}

///|
pub fn validate_result(
  rules : Rules,
  result : MatchResult,
  decisive? : Bool = false,
) -> Unit raise FixtureError {
  validate_rules(rules)
  if result.fixture_id.length() == 0 {
    raise InvalidResult("A fixture ID is required.")
  }
  let score = result.score
  if score.home < 0 ||
    score.away < 0 ||
    score.home > 10000 ||
    score.away > 10000 {
    raise InvalidResult("Match scores must be between 0 and 10000.")
  }
  match result.decider {
    Some(side) =>
      if side != 1 && side != 2 {
        raise InvalidResult("Decider must be side 1 or 2.")
      }
    None => ()
  }
  if result.kind == Forfeit {
    let side = winner_side(result)
    if side == None {
      raise InvalidResult("A forfeit requires a winner.")
    }
    let expected = forfeit_result(rules, result.fixture_id, side.unwrap())
    if result != expected {
      raise InvalidResult("Use the preset's canonical forfeit result.")
    }
    return
  }
  if uses_sets(rules.sport) {
    if result.decider != None {
      raise InvalidResult("Set matches cannot use an extra decider.")
    }
    let needed = rules.best_of / 2 + 1
    let mut home_wins = 0
    let mut away_wins = 0
    if result.sets.length() > rules.best_of {
      raise InvalidResult("Too many sets.")
    }
    for i, game in result.sets {
      if home_wins == needed || away_wins == needed {
        raise InvalidResult("A set was recorded after the match ended.")
      }
      let target = if i == rules.best_of - 1 {
        rules.final_target
      } else {
        rules.target
      }
      validate_game(game, target, rules.win_by, rules.cap)
      if game.home > game.away {
        home_wins = home_wins + 1
      } else {
        away_wins = away_wins + 1
      }
    }
    if home_wins != needed && away_wins != needed {
      raise InvalidResult("The match is not complete.")
    }
    if score.home != home_wins || score.away != away_wins {
      raise InvalidResult("Match score must equal the set-win totals.")
    }
  } else {
    if result.sets.length() != 0 {
      raise InvalidResult("This sport uses a single score, not sets.")
    }
    if rules.sport == Chess {
      if !((score.home == 1 && score.away == 0) ||
        (score.home == 0 && score.away == 1) ||
        (score.home == 1 && score.away == 1)) {
        raise InvalidResult("Chess input is 1-0, 0-1, or 1-1 for a draw.")
      }
    }
    if score.home == score.away && rules.sport == Basketball {
      raise InvalidResult("Basketball requires a winner after overtime.")
    }
    if result.decider != None &&
      (
        (rules.sport != Football && rules.sport != OpenScore) ||
        score.home != score.away ||
        !decisive
      ) {
      raise InvalidResult(
        "Only tied football or open-score elimination games may use a decider.",
      )
    }
    if decisive && winner_side(result) == None {
      raise InvalidResult("Elimination fixtures cannot end in a draw.")
    }
  }
}

///|
pub fn winner_side(result : MatchResult) -> Int? {
  if result.score.home > result.score.away {
    Some(1)
  } else if result.score.away > result.score.home {
    Some(2)
  } else {
    result.decider
  }
}

///|
pub fn match_points(rules : Rules, result : MatchResult) -> Score {
  let side = winner_side(result)
  let narrow = rules.sport == Volleyball &&
    rules.best_of == 5 &&
    rules.win_points == 3 &&
    rules.loss_points == 0 &&
    min_int(result.score.home, result.score.away) == rules.best_of / 2 &&
    result.kind == Played
  let win = if narrow { 2 } else { rules.win_points }
  let loss = if result.kind == Forfeit {
    0
  } else if narrow {
    1
  } else {
    rules.loss_points
  }
  match side {
    Some(1) => { home: win, away: loss, }
    Some(_) => { home: loss, away: win, }
    None => { home: rules.draw_points, away: rules.draw_points, }
  }
}

///|
pub fn forfeit_result(
  rules : Rules,
  id : String,
  side : Int,
) -> MatchResult raise FixtureError {
  require(side == 1 || side == 2, "Forfeit winner must be side 1 or 2.")
  validate_rules(rules)
  let home_wins = if side == 1 {
    if uses_sets(rules.sport) {
      rules.best_of / 2 + 1
    } else {
      rules.forfeit_score
    }
  } else {
    0
  }
  let away_wins = if side == 2 {
    if uses_sets(rules.sport) {
      rules.best_of / 2 + 1
    } else {
      rules.forfeit_score
    }
  } else {
    0
  }
  let games : Array[Score] = []
  if uses_sets(rules.sport) {
    for _ in 0..<(rules.best_of / 2 + 1) {
      games.push({
        home: if side == 1 {
          rules.target
        } else {
          0
        },
        away: if side == 2 {
          rules.target
        } else {
          0
        },
      })
    }
  }
  {
    fixture_id: id,
    score: { home: home_wins, away: away_wins, },
    sets: games,
    decider: None,
    kind: Forfeit,
  }
}

///|
pub fn score_result(
  id : String,
  home : Int,
  away : Int,
  decider? : Int? = None,
) -> MatchResult {
  { fixture_id: id, score: { home, away, }, sets: [], decider, kind: Played, }
}

///|
pub fn set_result(id : String, sets : Array[Score]) -> MatchResult {
  let mut home = 0
  let mut away = 0
  for game in sets {
    if game.home > game.away {
      home = home + 1
    } else if game.away > game.home {
      away = away + 1
    }
  }
  {
    fixture_id: id,
    score: { home, away, },
    sets: sets.copy(),
    decider: None,
    kind: Played,
  }
}

///|
/// Evaluate an independent multi-match playoff series using a game's sport rules.
pub fn summarize_series(
  rules : Rules,
  games : Array[MatchResult],
  best_of : Int,
) -> SeriesSummary raise FixtureError {
  require(
    best_of >= 1 && best_of <= 15 && best_of % 2 == 1,
    "Series length must be odd, between 1 and 15.",
  )
  let required = best_of / 2 + 1
  let mut home = 0
  let mut away = 0
  let ids : Map[String, Bool] = Map([])
  for game in games {
    require(!ids.contains(game.fixture_id), "Duplicate series game ID.")
    ids[game.fixture_id] = true
    if home == required || away == required {
      raise InvalidResult("The series already ended before this game.")
    }
    validate_result(rules, game, decisive=true)
    match winner_side(game) {
      Some(1) => home = home + 1
      Some(_) => away = away + 1
      None => raise InvalidResult("A series game requires a winner.")
    }
  }
  let complete = home == required || away == required
  {
    home_wins: home,
    away_wins: away,
    complete,
    winner_side: if home == required {
      Some(1)
    } else if away == required {
      Some(2)
    } else {
      None
    },
    next_game: if complete {
      0
    } else {
      games.length() + 1
    },
  }
}
