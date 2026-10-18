///|
/// Standard balanced seed placement: 1 vs 8, 4 vs 5, 2 vs 7, 3 vs 6.
pub fn bracket_seed_order(size : Int32) -> Array[Int32] raise FixtureError {
  require(
    size >= 2 && size <= 128 && next_power_two(size) == size,
    "Bracket size must be a power of two up to 128.",
  )
  let mut seeds = [1, 2]
  while seeds.length() < size {
    let total = seeds.length() * 2 + 1
    let expanded : Array[Int32] = []
    for seed in seeds {
      expanded.push(seed)
      expanded.push(total - seed)
    }
    seeds = expanded
  }
  seeds
}

///|
pub fn single_elimination(
  participants : Array[Participant],
  third_place~ : Bool = false,
) -> Array[Fixture] raise FixtureError {
  validate_participants(participants)
  let ordered = seeded_participants(participants)
  let size = next_power_two(ordered.length())
  let slots = bracket_seed_order(size).map(seed => {
    if seed <= ordered.length() {
      Seed(ordered[seed - 1].id)
    } else {
      Empty
    }
  })
  let fixtures : Array[Fixture] = []
  let mut previous = slots
  let mut round = 1
  let mut semifinals : Array[String] = []
  while previous.length() > 1 {
    let next : Array[Slot] = []
    let current : Array[String] = []
    for i in 0..<(previous.length() / 2) {
      let id = "w-" + round.to_string() + "-" + (i + 1).to_string()
      fixtures.push({
        id,
        stage: "winners",
        round,
        home: previous[i * 2],
        away: previous[i * 2 + 1],
      })
      next.push(Winner(id))
      current.push(id)
    }
    if current.length() == 2 {
      semifinals = current
    }
    previous = next
    round = round + 1
  }
  if third_place && semifinals.length() == 2 {
    fixtures.push({
      id: "third-place",
      stage: "third-place",
      round: round - 1,
      home: Loser(semifinals[0]),
      away: Loser(semifinals[1]),
    })
  }
  fixtures
}

///|
/// Two losses eliminate an entrant. The grand-final reset is conditionally active.
pub fn double_elimination(
  participants : Array[Participant],
) -> Array[Fixture] raise FixtureError {
  let winners = single_elimination(participants)
  let rounds : Array[Array[String]] = []
  for fixture in winners {
    while rounds.length() < fixture.round {
      rounds.push([])
    }
    rounds[fixture.round - 1].push(fixture.id)
  }
  let fixtures = winners.copy()
  let mut survivors : Array[Slot] = rounds[0].map(id => Loser(id))
  let mut lower_round = 1
  for wr in 1..<rounds.length() {
    let paired : Array[Slot] = []
    for i in 0..<(survivors.length() / 2) {
      let id = "l-" + lower_round.to_string() + "-" + (i + 1).to_string()
      fixtures.push({
        id,
        stage: "losers",
        round: lower_round,
        home: survivors[i * 2],
        away: survivors[i * 2 + 1],
      })
      paired.push(Winner(id))
    }
    lower_round = lower_round + 1
    let merged : Array[Slot] = []
    for i in 0..<paired.length() {
      let id = "l-" + lower_round.to_string() + "-" + (i + 1).to_string()
      // Cross incoming lanes to reduce immediate same-opponent meetings.
      let incoming = rounds[wr][rounds[wr].length() - 1 - i]
      fixtures.push({
        id,
        stage: "losers",
        round: lower_round,
        home: paired[i],
        away: Loser(incoming),
      })
      merged.push(Winner(id))
    }
    survivors = merged
    lower_round = lower_round + 1
  }
  let upper_final = rounds[rounds.length() - 1][0]
  let lower_final = if rounds.length() == 1 {
    Loser(upper_final)
  } else {
    survivors[0]
  }
  fixtures.push({
    id: "grand-final",
    stage: "grand-final",
    round: lower_round,
    home: Winner(upper_final),
    away: lower_final,
  })
  fixtures.push({
    id: "grand-reset",
    stage: "reset",
    round: lower_round + 1,
    home: Winner("grand-final"),
    away: Loser("grand-final"),
  })
  fixtures
}

///|
pub fn resolve_slot(tournament : Tournament, slot : Slot) -> ResolvedSlot {
  resolve_slot_at(tournament, slot, 0)
}

///|
fn resolve_slot_at(t : Tournament, slot : Slot, depth : Int32) -> ResolvedSlot {
  if depth > t.fixtures.length() + 1 {
    return Pending
  }
  match slot {
    Seed(id) => Ready(id)
    Empty => Vacant
    Winner(id) | Loser(id) => {
      let fixture = match find_fixture(t.fixtures, id) {
        Some(f) => f
        None => return Pending
      }
      let home = resolve_slot_at(t, fixture.home, depth + 1)
      let away = resolve_slot_at(t, fixture.away, depth + 1)
      let winning = match slot {
        Winner(_) => true
        _ => false
      }
      match (home, away) {
        (Pending, _) | (_, Pending) => Pending
        (Vacant, Vacant) => Vacant
        (Ready(_), Vacant) => if winning { home } else { Vacant }
        (Vacant, Ready(_)) => if winning { away } else { Vacant }
        (Ready(_), Ready(_)) =>
          match t.results.get(id) {
            Some(result) =>
              match winner_side(result) {
                Some(side) => if (side == 1) == winning { home } else { away }
                None => Pending
              }
            None => Pending
          }
      }
    }
  }
}

///|
pub fn fixture_state(t : Tournament, fixture : Fixture) -> FixtureState {
  if fixture.stage == "reset" {
    match t.results.get("grand-final") {
      Some(result) => if winner_side(result) != Some(2) { return Inactive }
      None => return Waiting
    }
  }
  match (resolve_slot(t, fixture.home), resolve_slot(t, fixture.away)) {
    (Pending, _) | (_, Pending) => Waiting
    (Vacant, _) | (_, Vacant) => Automatic
    (Ready(_), Ready(_)) =>
      if t.results.contains(fixture.id) {
        Finished
      } else {
        Playable
      }
  }
}

///|
pub fn champion(t : Tournament) -> Int32? {
  if t.format != SingleElimination &&
    t.format != DoubleElimination &&
    t.format != Groups &&
    t.format != GroupsDouble &&
    t.format != SwissPlayoff &&
    t.format != LeaguePlayoff &&
    t.format != LeagueDoublePlayoff {
    return None
  }
  let mut final_id = ""
  if t.format == DoubleElimination {
    let reset = find_fixture(t.fixtures, "grand-reset")
    if reset != None && fixture_state(t, reset.unwrap()) != Inactive {
      final_id = "grand-reset"
    } else {
      final_id = "grand-final"
    }
  } else {
    for fixture in t.fixtures {
      if fixture.stage == "winners" || fixture.stage == "knockout" {
        final_id = fixture.id
      }
    }
  }
  match resolve_slot(t, Winner(final_id)) {
    Ready(id) => Some(id)
    _ => None
  }
}

///|
fn slot_dependency(slot : Slot) -> String? {
  match slot {
    Winner(id) | Loser(id) => Some(id)
    _ => None
  }
}

///|
/// Graphs must be topological, bounded, and refer only to known entrants.
pub fn validate_fixtures(t : Tournament) -> Unit raise FixtureError {
  require(t.fixtures.length() <= 20000, "Too many fixtures.")
  let ids : Map[String, Bool] = Map([])
  let entrants : Map[Int32, Bool] = Map([])
  for participant in t.participants {
    entrants[participant.id] = true
  }
  for fixture in t.fixtures {
    require(
      fixture.id.length() > 0 && fixture.id.length() <= 80,
      "Invalid fixture ID.",
    )
    require(
      fixture.stage.length() > 0 && fixture.stage.length() <= 80,
      "Invalid stage label.",
    )
    require(fixture.round > 0 && fixture.round <= 256, "Invalid fixture round.")
    require(!ids.contains(fixture.id), "Duplicate fixture ID.")
    for slot in [fixture.home, fixture.away] {
      match slot {
        Seed(id) =>
          require(
            entrants.contains(id),
            "Fixture refers to an unknown entrant.",
          )
        Winner(id) | Loser(id) =>
          if !ids.contains(id) {
            raise DependencyError(
              "Fixture dependency must precede " + fixture.id + ": " + id,
            )
          }
        Empty => ()
      }
    }
    match (fixture.home, fixture.away) {
      (Seed(a), Seed(b)) => require(a != b, "An entrant cannot play itself.")
      _ => ()
    }
    ids[fixture.id] = true
  }
}
