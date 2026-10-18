///|
/// Presets specify a scoring subset and an explicit club-table policy.
pub fn rule_presets() -> Array[Rules] {
  [
    {
      id: "open-score",
      label: "Open score · configurable points",
      sport: OpenScore,
      best_of: 1,
      target: 0,
      final_target: 0,
      win_by: 0,
      cap: 0,
      win_points: 3,
      draw_points: 1,
      loss_points: 0,
      forfeit_score: 1,
      point_scale: 1,
      tie_breaks: [Points, Difference, Scored],
      source: "",
      scope: "Organizer-defined nonnegative scores. Draws are allowed in league stages; tied knockouts need an explicit winner. Set the points and ranking order for your event. This is not a sport federation standard.",
    },
    {
      id: "football",
      label: "Football · 3 / 1 / 0",
      sport: Football,
      best_of: 1,
      target: 0,
      final_target: 0,
      win_by: 0,
      cap: 0,
      win_points: 3,
      draw_points: 1,
      loss_points: 0,
      forfeit_score: 3,
      point_scale: 1,
      tie_breaks: [Points, Difference, Scored],
      source: "https://www.premierleague.com/en/premier-league-explained",
      scope: "Club 3/1/0 table, goal difference, goals scored; forfeit 3-0 is an organizer policy. Unresolved ties remain tied.",
    },
    {
      id: "basketball",
      label: "Basketball · FIBA scoring subset",
      sport: Basketball,
      best_of: 1,
      target: 0,
      final_target: 0,
      win_by: 0,
      cap: 0,
      win_points: 2,
      draw_points: 0,
      loss_points: 1,
      forfeit_score: 20,
      point_scale: 1,
      tie_breaks: [Points, HeadToHead, Difference, Scored],
      source: "https://assets.fiba.basketball/image/upload/documents-corporate-fiba-official-rules-2024-v10a.pdf",
      scope: "FIBA 2024 win 2/loss 1/forfeit loss 0 and 20-0 subset. Mini-table ranking is a club approximation, not full Appendix D.",
    },
    {
      id: "volleyball",
      label: "Volleyball · best of 5",
      sport: Volleyball,
      best_of: 5,
      target: 25,
      final_target: 15,
      win_by: 2,
      cap: 0,
      win_points: 3,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 25,
      point_scale: 1,
      tie_breaks: [Wins, Points, SetRatio, ScoreRatio, HeadToHead],
      source: "https://www.fivb.com/document-category/official-volleyball-rules/",
      scope: "2025-2028 scoring subset: 25-point sets, deciding set 15, win by 2. League points 3/0 or 2/1; full event fallbacks excluded.",
    },
    {
      id: "beach-volleyball",
      label: "Beach volleyball · best of 3",
      sport: BeachVolleyball,
      best_of: 3,
      target: 21,
      final_target: 15,
      win_by: 2,
      cap: 0,
      win_points: 2,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 21,
      point_scale: 1,
      tie_breaks: [Wins, SetRatio, ScoreRatio],
      source: "https://www.fivb.com/beach-volleyball/the-game/official-rules-of-the-games/",
      scope: "21-point sets and 15-point deciding set; table points 2/0 are a club policy.",
    },
    {
      id: "badminton-21",
      label: "Badminton · 3 × 21 (cap 30)",
      sport: Badminton,
      best_of: 3,
      target: 21,
      final_target: 21,
      win_by: 2,
      cap: 30,
      win_points: 2,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 21,
      point_scale: 1,
      tie_breaks: [Points, HeadToHead, SetRatio, ScoreRatio],
      source: "https://corporate.bwfbadminton.com/statutes/",
      scope: "3 × 21 rally scoring, win by 2, cap 30. Table points/tie-break order are club policies.",
    },
    {
      id: "badminton-15",
      label: "Badminton · 3 × 15 (cap 21)",
      sport: Badminton,
      best_of: 3,
      target: 15,
      final_target: 15,
      win_by: 2,
      cap: 21,
      win_points: 2,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 15,
      point_scale: 1,
      tie_breaks: [Points, HeadToHead, SetRatio, ScoreRatio],
      source: "https://system.bwfbadminton.com/documents/folder_1_81/Regulations/Laws/Part%20II%20-%20Section%201B%20-%20Appendix%203%20-%20Other%20Scoring%20Systems.pdf",
      scope: "BWF published alternative 3 × 15, cap 21. Worldwide adoption announced for 4 January 2027; local adoption may differ.",
    },
    {
      id: "table-tennis",
      label: "Table tennis · best of 5",
      sport: TableTennis,
      best_of: 5,
      target: 11,
      final_target: 11,
      win_by: 2,
      cap: 0,
      win_points: 2,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 11,
      point_scale: 1,
      tie_breaks: [Points, HeadToHead, SetRatio, ScoreRatio],
      source: "https://www.ittf.com/statutes/",
      scope: "ITTF game scoring subset: 11 points, win by 2, any odd best-of. Table ranking is a club policy.",
    },
    {
      id: "chess",
      label: "Chess · 1 / ½ / 0",
      sport: Chess,
      best_of: 1,
      target: 0,
      final_target: 0,
      win_by: 0,
      cap: 0,
      win_points: 2,
      draw_points: 1,
      loss_points: 0,
      forfeit_score: 1,
      point_scale: 2,
      tie_breaks: [Points, Buchholz, SonnebornBerger],
      source: "https://handbook.fide.com/",
      scope: "1/½/0 stored as 2/1/0. Buchholz/SB use played opponents only; FIDE virtual-opponent corrections excluded.",
    },
    {
      id: "esports",
      label: "Esports · best of 3 maps",
      sport: Esports,
      best_of: 3,
      target: 1,
      final_target: 1,
      win_by: 1,
      cap: 1,
      win_points: 3,
      draw_points: 0,
      loss_points: 0,
      forfeit_score: 1,
      point_scale: 1,
      tie_breaks: [Points, HeadToHead, Difference, Scored],
      source: "",
      scope: "Organizer-defined map series: each map 1-0 or 0-1. Not a universal esports standard.",
    },
  ]
}

///|
pub fn preset(id : String) -> Rules raise FixtureError {
  for rules in rule_presets() {
    if rules.id == id {
      return rules
    }
  }
  raise InvalidInput("Unknown rules preset: " + id)
}

///|
pub fn validate_rules(rules : Rules) -> Unit raise FixtureError {
  require(
    rules.best_of >= 1 && rules.best_of <= 15 && rules.best_of % 2 == 1,
    "Best-of must be odd, between 1 and 15.",
  )
  require(rules.target >= 0 && rules.target <= 1000, "Invalid game target.")
  require(
    rules.final_target >= 0 && rules.final_target <= 1000,
    "Invalid deciding-game target.",
  )
  require(rules.win_by >= 0 && rules.win_by <= 10, "Invalid winning margin.")
  require(
    rules.cap == 0 ||
    (
      rules.cap >= rules.target &&
      rules.cap >= rules.final_target &&
      rules.cap <= 10000
    ),
    "Cap must be zero or at least both targets.",
  )
  require(
    rules.point_scale == 1 || rules.point_scale == 2,
    "Point scale must be 1 or 2.",
  )
  require(
    rules.win_points >= 0 && rules.win_points <= 100,
    "Invalid win points.",
  )
  require(
    rules.draw_points >= 0 && rules.draw_points <= 100,
    "Invalid draw points.",
  )
  require(
    rules.loss_points >= 0 && rules.loss_points <= 100,
    "Invalid loss points.",
  )
  require(
    rules.forfeit_score > 0 && rules.forfeit_score <= 1000,
    "Invalid forfeit score.",
  )
  require(
    rules.tie_breaks.length() >= 1 && rules.tie_breaks.length() <= 12,
    "At least one ranking criterion is required.",
  )
  let seen : Map[String, Bool] = Map([])
  for criterion in rules.tie_breaks {
    let key = tie_break_name(criterion)
    require(!seen.contains(key), "Duplicate ranking criterion.")
    seen[key] = true
  }
  if uses_sets(rules.sport) {
    require(
      rules.target > 0 && rules.final_target > 0 && rules.win_by > 0,
      "Set-based sports need positive targets and winning margins.",
    )
  } else {
    require(
      rules.best_of == 1,
      "Use the series API for multiple score-based games.",
    )
  }
}

///|
pub fn with_best_of(rules : Rules, best_of : Int32) -> Rules raise FixtureError {
  let changed = { ..rules, best_of, }
  validate_rules(changed)
  rules_from_json(rules_to_json(changed))
}

///|
pub fn with_seed_tie_break(
  rules : Rules,
  enabled : Bool,
) -> Rules raise FixtureError {
  let criteria = rules.tie_breaks.filter(item => item != SeedOrder)
  if enabled {
    criteria.push(SeedOrder)
  }
  rules_from_json(rules_to_json({ ..rules, tie_breaks: criteria, }))
}

///|
pub fn uses_sets(sport : Sport) -> Bool {
  match sport {
    Volleyball | BeachVolleyball | Badminton | TableTennis | Esports => true
    _ => false
  }
}

///|
pub fn tie_break_name(criterion : TieBreak) -> String {
  match criterion {
    Points => "points"
    Wins => "wins"
    Difference => "difference"
    Scored => "scored"
    HeadToHead => "head-to-head"
    SetRatio => "set-ratio"
    ScoreRatio => "score-ratio"
    Buchholz => "buchholz"
    BuchholzCutOne => "buchholz-cut-one"
    SonnebornBerger => "sonneborn-berger"
    SeedOrder => "seed"
  }
}

///|
pub fn parse_tie_break(text : String) -> TieBreak raise FixtureError {
  match text {
    "points" => Points
    "wins" => Wins
    "difference" => Difference
    "scored" => Scored
    "head-to-head" => HeadToHead
    "set-ratio" => SetRatio
    "score-ratio" => ScoreRatio
    "buchholz" => Buchholz
    "buchholz-cut-one" => BuchholzCutOne
    "sonneborn-berger" => SonnebornBerger
    "seed" => SeedOrder
    _ => raise InvalidInput("Unknown ranking criterion: " + text)
  }
}
