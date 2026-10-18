///|
/// Circle-method rotation gives every pair one game and every odd field a bye.
pub fn round_robin(
  participants : Array[Participant],
  double~ : Bool = false,
  prefix~ : String = "rr",
  stage~ : String = "league",
) -> Array[Fixture] raise FixtureError {
  validate_participants(participants)
  let ordered = seeded_participants(participants)
  let ring = ordered.map(p => p.id)
  if ring.length() % 2 != 0 {
    ring.push(0)
  }
  let size = ring.length()
  let first : Array[Fixture] = []
  for r in 0..<(size - 1) {
    for i in 0..<(size / 2) {
      let a = ring[i]
      let b = ring[size - 1 - i]
      let swap = (i == 0 && r % 2 == 1) || (i > 0 && i % 2 == 0)
      let home = if swap { b } else { a }
      let away = if swap { a } else { b }
      first.push({
        id: prefix + "-" + (r + 1).to_string() + "-" + (i + 1).to_string(),
        stage,
        round: r + 1,
        home: if home == 0 {
          Empty
        } else {
          Seed(home)
        },
        away: if away == 0 {
          Empty
        } else {
          Seed(away)
        },
      })
    }
    let last = ring[size - 1]
    for i = size - 1; i > 1; i = i - 1 {
      ring[i] = ring[i - 1]
    }
    ring[1] = last
  }
  if !double {
    return first
  }
  let all = first.copy()
  for fixture in first {
    all.push({
      ..fixture,
      id: fixture.id + "-return",
      round: fixture.round + size - 1,
      home: fixture.away,
      away: fixture.home,
    })
  }
  all
}

///|
/// Snake distribution keeps high seeds apart without depending on ID values.
pub fn distribute_groups(
  participants : Array[Participant],
  count : Int32,
) -> Array[Array[Participant]] raise FixtureError {
  validate_participants(participants)
  require(count >= 2 && count <= 16, "Use between 2 and 16 groups.")
  require(
    participants.length() >= count * 2,
    "Each group requires at least two entrants.",
  )
  let groups : Array[Array[Participant]] = Array::makei(count, _ => [])
  for i, participant in seeded_participants(participants) {
    let batch = i / count
    let offset = i % count
    let group = if batch % 2 == 0 { offset } else { count - 1 - offset }
    groups[group].push(participant)
  }
  groups
}

///|
pub fn group_fixtures(
  participants : Array[Participant],
  count : Int32,
  double~ : Bool = false,
) -> Array[Fixture] raise FixtureError {
  let groups = distribute_groups(participants, count)
  let fixtures : Array[Fixture] = []
  let by_group : Array[Array[Fixture]] = []
  let mut final_round = 0
  for i, group in groups {
    let label = "group-" + (i + 1).to_string()
    let matches = round_robin(group, double~, prefix=label, stage=label)
    for fixture in matches {
      final_round = max_int(final_round, fixture.round)
    }
    by_group.push(matches)
  }
  for round in 1..<=final_round {
    for matches in by_group {
      for fixture in matches {
        if fixture.round == round {
          fixtures.push(fixture)
        }
      }
    }
  }
  fixtures
}
