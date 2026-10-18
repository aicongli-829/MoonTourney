///|
priv struct PairSearch {
  mut nodes : Int
  mut best_cost : Int
  mut best : Array[(Int, Int)]
  mut limited : Bool
}

///|
fn previously_paired(t : Tournament, a : Int, b : Int) -> Bool {
  for fixture in t.fixtures {
    match (resolve_slot(t, fixture.home), resolve_slot(t, fixture.away)) {
      (Ready(c), Ready(d)) => if same_pair(a, b, c, d) { return true }
      _ => ()
    }
  }
  false
}

///|
fn side_balance(t : Tournament, id : Int) -> Int {
  let mut balance = 0
  for fixture in t.fixtures {
    if fixture.stage != "swiss" {
      continue
    }
    match (resolve_slot(t, fixture.home), resolve_slot(t, fixture.away)) {
      (Ready(a), Ready(b)) => {
        if a == id {
          balance = balance + 1
        }
        if b == id {
          balance = balance - 1
        }
      }
      _ => ()
    }
  }
  balance
}

///|
fn pair_cost(t : Tournament, rows : Array[Standing], a : Int, b : Int) -> Int {
  let first = rows[a]
  let second = rows[b]
  let x = side_balance(t, first.participant.id)
  let y = side_balance(t, second.participant.id)
  let orient_one = abs_int(x + 1) + abs_int(y - 1)
  let orient_two = abs_int(x - 1) + abs_int(y + 1)
  abs_int(first.points - second.points) * 100 + min_int(orient_one, orient_two)
}

///|
/// Bounded branch-and-bound searches beyond a greedy pairing dead end.
fn search_pairs(
  t : Tournament,
  rows : Array[Standing],
  remaining : Array[Int],
  pairs : Array[(Int, Int)],
  cost : Int,
  search : PairSearch,
) -> Unit {
  if search.nodes >= 50000 {
    search.limited = true
    return
  }
  search.nodes = search.nodes + 1
  if cost >= search.best_cost {
    return
  }
  if remaining.length() == 0 {
    search.best_cost = cost
    search.best = pairs.copy()
    return
  }
  let a = remaining[0]
  let candidates = remaining.filter(b => {
    b != a &&
    !previously_paired(t, rows[a].participant.id, rows[b].participant.id)
  })
  candidates.sort_by((b, c) => {
    let difference = compare_int(
      pair_cost(t, rows, a, b),
      pair_cost(t, rows, a, c),
    )
    if difference != 0 {
      difference
    } else {
      compare_int(rows[b].participant.seed, rows[c].participant.seed)
    }
  })
  for b in candidates {
    let next = remaining.filter(item => item != a && item != b)
    pairs.push((a, b))
    search_pairs(t, rows, next, pairs, cost + pair_cost(t, rows, a, b), search)
    ignore(pairs.pop())
    if search.limited {
      return
    }
  }
}

///|
/// Club Swiss: no rematches, score proximity, balanced sides, one full-point bye.
/// This deliberately does not claim FIDE Dutch or rated-tournament compliance.
pub fn next_swiss_round(t : Tournament) -> Tournament raise FixtureError {
  require(
    t.format == Swiss || t.format == SwissPlayoff,
    "This action requires a Swiss tournament.",
  )
  require(
    !t.fixtures.any(f => f.stage == "knockout"),
    "The Swiss stage has already advanced to playoffs.",
  )
  require(
    t.participants.length() <= 64,
    "Swiss fields are limited to 64 entrants.",
  )
  let mut round = 1
  for fixture in t.fixtures {
    if fixture.stage != "swiss" {
      continue
    }
    let state = fixture_state(t, fixture)
    require(
      state == Finished || state == Automatic,
      "Complete the current Swiss round first.",
    )
    round = max_int(round, fixture.round + 1)
  }
  require(round <= 64, "At most 64 Swiss rounds are supported.")
  if t.format == SwissPlayoff {
    require(
      round <= t.swiss_rounds,
      "All configured Swiss rounds are already paired; start the playoffs.",
    )
  }
  let rows = standings(t).filter(row => row.participant.active)
  require(rows.length() >= 2, "At least two active entrants are needed.")
  let candidates : Array[Int] = Array::makei(rows.length(), i => i)
  let mut bye : Int? = None
  if candidates.length() % 2 == 1 {
    // Try bye candidates from lowest score upward; a different bye may unblock pairing.
    for i = rows.length() - 1; i >= 0; i = i - 1 {
      if rows[i].byes == 0 {
        bye = Some(i)
        break
      }
    }
    if bye == None {
      raise PairingError("Every active entrant already received a pairing bye.")
    }
  }
  let bye_options = if bye == None {
    [None]
  } else {
    let options : Array[Int?] = []
    for i = rows.length() - 1; i >= 0; i = i - 1 {
      if rows[i].byes == 0 {
        options.push(Some(i))
      }
    }
    options
  }
  let mut selected : Array[(Int, Int)] = []
  let mut allocated_bye = bye
  let mut found = false
  for option in bye_options {
    let remaining = candidates.filter(i => Some(i) != option)
    let search : PairSearch = {
      nodes: 0,
      best_cost: 1000000000,
      best: [],
      limited: false,
    }
    search_pairs(t, rows, remaining, [], 0, search)
    if search.best.length() == remaining.length() / 2 {
      selected = search.best
      allocated_bye = option
      found = true
      break
    }
    if search.limited {
      raise PairingError(
        "Pairing search reached its limit; no valid pairing found within 50000 nodes.",
      )
    }
  }
  if !found {
    raise PairingError(
      "No pairing avoids repeated opponents. End the event or change the field.",
    )
  }
  let fixtures = t.fixtures.copy()
  for i, (a, b) in selected {
    let first = rows[a].participant.id
    let second = rows[b].participant.id
    let home_first = side_balance(t, first) <= side_balance(t, second)
    fixtures.push({
      id: "swiss-" + round.to_string() + "-" + (i + 1).to_string(),
      stage: "swiss",
      round,
      home: Seed(if home_first { first } else { second }),
      away: Seed(if home_first { second } else { first }),
    })
  }
  match allocated_bye {
    Some(index) =>
      fixtures.push({
        id: "swiss-" + round.to_string() + "-bye",
        stage: "swiss",
        round,
        home: Seed(rows[index].participant.id),
        away: Empty,
      })
    None => ()
  }
  { ..t, fixtures, }
}
