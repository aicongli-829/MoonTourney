///|
fn blank_standing(participant : Participant) -> Standing {
  {
    participant,
    rank: 0,
    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    points: 0,
    scored: 0,
    conceded: 0,
    sets_won: 0,
    sets_lost: 0,
    head_to_head: 0,
    buchholz: 0,
    buchholz_cut_one: 0,
    sonneborn_berger: 0,
    byes: 0,
  }
}

///|
fn update_standing(
  row : Standing,
  result : MatchResult,
  rules : Rules,
  home : Bool,
) -> Standing {
  let side = if home { 1 } else { 2 }
  let winner = winner_side(result)
  let points = match_points(rules, result)
  let mut scored = if home { result.score.home } else { result.score.away }
  let mut conceded = if home { result.score.away } else { result.score.home }
  let mut sets_won = 0
  let mut sets_lost = 0
  if uses_sets(rules.sport) {
    sets_won = scored
    sets_lost = conceded
    scored = 0
    conceded = 0
    for game in result.sets {
      scored = scored + (if home { game.home } else { game.away })
      conceded = conceded + (if home { game.away } else { game.home })
    }
  }
  {
    ..row,
    played: row.played + 1,
    wins: row.wins + (if winner == Some(side) { 1 } else { 0 }),
    draws: row.draws + (if winner == None { 1 } else { 0 }),
    losses: row.losses +
    (if winner != None && winner != Some(side) { 1 } else { 0 }),
    points: row.points + (if home { points.home } else { points.away }),
    scored: row.scored + scored,
    conceded: row.conceded + conceded,
    sets_won: row.sets_won + sets_won,
    sets_lost: row.sets_lost + sets_lost,
  }
}

///|
/// Compare ratios without floats or division-by-zero. 0/0 is neutral, x/0 infinity.
pub fn compare_ratio(a : Int, b : Int, c : Int, d : Int) -> Int {
  let a_infinite = a > 0 && b == 0
  let c_infinite = c > 0 && d == 0
  if a_infinite && c_infinite {
    return 0
  }
  if a_infinite {
    return 1
  }
  if c_infinite {
    return -1
  }
  let left = a.to_int64() * (if d == 0 { 1 } else { d }).to_int64()
  let right = c.to_int64() * (if b == 0 { 1 } else { b }).to_int64()
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_standings(
  a : Standing,
  b : Standing,
  criteria : Array[TieBreak],
) -> Int {
  for criterion in criteria {
    let comparison = match criterion {
      Points => compare_int(a.points, b.points)
      Wins => compare_int(a.wins, b.wins)
      Difference => compare_int(a.scored - a.conceded, b.scored - b.conceded)
      Scored => compare_int(a.scored, b.scored)
      HeadToHead => compare_int(a.head_to_head, b.head_to_head)
      SetRatio =>
        compare_ratio(a.sets_won, a.sets_lost, b.sets_won, b.sets_lost)
      ScoreRatio => compare_ratio(a.scored, a.conceded, b.scored, b.conceded)
      Buchholz => compare_int(a.buchholz, b.buchholz)
      BuchholzCutOne => compare_int(a.buchholz_cut_one, b.buchholz_cut_one)
      SonnebornBerger => compare_int(a.sonneborn_berger, b.sonneborn_berger)
      SeedOrder => compare_int(b.participant.seed, a.participant.seed)
    }
    if comparison != 0 {
      return -comparison
    }
  }
  0
}

///|
/// Stage filtering prevents knockout matches contaminating group standings.
pub fn standings(t : Tournament, stage? : String = "") -> Array[Standing] {
  let table : Map[Int, Standing] = Map([])
  let included : Map[Int, Bool] = Map([])
  for p in t.participants {
    table[p.id] = blank_standing(p)
  }
  for fixture in t.fixtures {
    if stage != "" && fixture.stage != stage {
      continue
    }
    let home = resolve_slot(t, fixture.home)
    let away = resolve_slot(t, fixture.away)
    match home {
      Ready(id) => included[id] = true
      _ => ()
    }
    match away {
      Ready(id) => included[id] = true
      _ => ()
    }
    match (home, away) {
      (Ready(a), Ready(b)) =>
        match t.results.get(fixture.id) {
          Some(result) => {
            table[a] = update_standing(table[a], result, t.rules, true)
            table[b] = update_standing(table[b], result, t.rules, false)
          }
          None => ()
        }
      (Ready(id), Vacant) | (Vacant, Ready(id)) =>
        if fixture.stage == "swiss" {
          let row = table[id]
          table[id] = {
            ..row,
            points: row.points + t.rules.win_points,
            byes: row.byes + 1,
          }
        }
      _ => ()
    }
  }
  // Opponent metrics use final table points; byes supply points but no opponent.
  let opponents : Map[Int, Array[Int]] = Map([])
  for p in t.participants {
    opponents[p.id] = []
  }
  for fixture in t.fixtures {
    if stage != "" && fixture.stage != stage {
      continue
    }
    match
      (
        resolve_slot(t, fixture.home),
        resolve_slot(t, fixture.away),
        t.results.get(fixture.id),
      ) {
      (Ready(a), Ready(b), Some(result)) => {
        let ar = table[a]
        let br = table[b]
        let points = match_points(t.rules, result)
        let same_group = ar.points == br.points &&
          (t.rules.sport != Volleyball || ar.wins == br.wins)
        if same_group {
          table[a] = { ..ar, head_to_head: ar.head_to_head + points.home, }
          table[b] = { ..br, head_to_head: br.head_to_head + points.away, }
        }
        if result.kind == Played {
          opponents[a].push(br.points)
          opponents[b].push(ar.points)
          let av = table[a]
          let bv = table[b]
          table[a] = {
            ..av,
            buchholz: av.buchholz + br.points,
            sonneborn_berger: av.sonneborn_berger + br.points * points.home,
          }
          table[b] = {
            ..bv,
            buchholz: bv.buchholz + ar.points,
            sonneborn_berger: bv.sonneborn_berger + ar.points * points.away,
          }
        }
      }
      _ => ()
    }
  }
  let rows : Array[Standing] = []
  for p in t.participants {
    if stage != "" && !included.contains(p.id) {
      continue
    }
    let row = table[p.id]
    let values = opponents[p.id]
    let cut = if values.length() == 0 {
      0
    } else {
      let mut lowest = values[0]
      for value in values {
        lowest = min_int(lowest, value)
      }
      row.buchholz - lowest
    }
    rows.push({ ..row, buchholz_cut_one: cut, })
  }
  rows.sort_by((a, b) => {
    let comparison = compare_standings(a, b, t.rules.tie_breaks)
    if comparison == 0 {
      compare_int(a.participant.seed, b.participant.seed)
    } else {
      comparison
    }
  })
  let ranked : Array[Standing] = []
  for i, row in rows {
    let rank = if i > 0 &&
      compare_standings(rows[i - 1], row, t.rules.tie_breaks) == 0 {
      ranked[i - 1].rank
    } else {
      i + 1
    }
    ranked.push({ ..row, rank, })
  }
  ranked
}

///|
pub fn ranking_reasons(rules : Rules, row : Standing) -> Array[String] {
  rules.tie_breaks.map(criterion => {
    let value = match criterion {
      Points => display_points(row.points, rules.point_scale)
      Wins => row.wins.to_string()
      Difference => (row.scored - row.conceded).to_string()
      Scored => row.scored.to_string()
      HeadToHead => display_points(row.head_to_head, rules.point_scale)
      SetRatio => row.sets_won.to_string() + "/" + row.sets_lost.to_string()
      ScoreRatio => row.scored.to_string() + "/" + row.conceded.to_string()
      Buchholz => display_points(row.buchholz, rules.point_scale)
      BuchholzCutOne => display_points(row.buchholz_cut_one, rules.point_scale)
      SonnebornBerger =>
        row.sonneborn_berger.to_string() +
        "/" +
        (rules.point_scale * rules.point_scale).to_string()
      SeedOrder => row.participant.seed.to_string()
    }
    tie_break_name(criterion) + ": " + value
  })
}
