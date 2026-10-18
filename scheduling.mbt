///|
fn possible_entrants(t : Tournament, slot : Slot, depth : Int) -> Array[Int] {
  if depth > t.fixtures.length() {
    return []
  }
  match resolve_slot(t, slot) {
    Ready(id) => [id]
    Vacant => []
    Pending =>
      match slot {
        Winner(id) | Loser(id) => {
          let fixture = match find_fixture(t.fixtures, id) {
            Some(f) => f
            None => return []
          }
          let ids = possible_entrants(t, fixture.home, depth + 1)
          for item in possible_entrants(t, fixture.away, depth + 1) {
            if !ids.contains(item) {
              ids.push(item)
            }
          }
          ids
        }
        _ => []
      }
  }
}

///|
/// Conservative scheduling reserves rest for every possible future entrant.
/// Times are offsets in minutes, so no local time-zone assumptions enter the core.
pub fn schedule(
  t : Tournament,
  courts : Int,
  duration : Int,
  rest? : Int = 10,
  start? : Int = 0,
  horizon? : Int = 1000000,
  day_start? : Int = 0,
  day_end? : Int = 1440,
) -> Schedule raise FixtureError {
  validate_fixtures(t)
  require(courts >= 1 && courts <= 32, "Use between 1 and 32 courts.")
  require(
    duration >= 1 && duration <= 360,
    "Duration must be 1 to 360 minutes.",
  )
  require(rest >= 0 && rest <= 1440, "Rest must be 0 to 1440 minutes.")
  require(start >= 0 && start <= 10000000, "Invalid start offset.")
  require(
    horizon >= start && horizon <= 10000000,
    "Invalid scheduling horizon.",
  )
  require(
    day_start >= 0 &&
    day_start < day_end &&
    day_end <= 1440 &&
    duration <= day_end - day_start,
    "Game duration must fit inside the daily playing window.",
  )
  let available = Array::make(courts, start)
  let ends : Map[String, Int] = Map([])
  let last_played : Map[Int, Int] = Map([])
  let allocations : Array[Allocation] = []
  let unscheduled : Array[String] = []
  for fixture in t.fixtures {
    let state = fixture_state(t, fixture)
    if state == Inactive {
      continue
    }
    let mut earliest = start
    let mut blocked = false
    for slot in [fixture.home, fixture.away] {
      match slot_dependency(slot) {
        Some(id) =>
          match ends.get(id) {
            Some(end) => earliest = max_int(earliest, end)
            None => blocked = true
          }
        None => ()
      }
    }
    if state == Automatic {
      ends[fixture.id] = earliest
      continue
    }
    let ids = possible_entrants(t, fixture.home, 0)
    for id in possible_entrants(t, fixture.away, 0) {
      if !ids.contains(id) {
        ids.push(id)
      }
    }
    for id in ids {
      match last_played.get(id) {
        Some(end) => earliest = max_int(earliest, end + rest)
        None => ()
      }
    }
    let mut court = 0
    let mut time = align_playing_window(
      max_int(earliest, available[0]),
      duration,
      day_start,
      day_end,
    )
    for i in 1..<courts {
      let candidate = align_playing_window(
        max_int(earliest, available[i]),
        duration,
        day_start,
        day_end,
      )
      if candidate < time {
        court = i
        time = candidate
      }
    }
    if blocked || time + duration > horizon {
      unscheduled.push(fixture.id)
      continue
    }
    allocations.push({
      fixture_id: fixture.id,
      court: court + 1,
      start: time,
      duration,
    })
    available[court] = time + duration
    ends[fixture.id] = time + duration
    for id in ids {
      last_played[id] = time + duration
    }
  }
  { allocations, unscheduled, }
}

///|
fn align_playing_window(
  time : Int,
  duration : Int,
  day_start : Int,
  day_end : Int,
) -> Int {
  let day = time / 1440
  let clock = time % 1440
  if clock < day_start {
    day * 1440 + day_start
  } else if clock + duration > day_end {
    (day + 1) * 1440 + day_start
  } else {
    time
  }
}

///|
/// Verify a user-imported schedule independently of the planner.
pub fn validate_schedule(
  t : Tournament,
  allocations : Array[Allocation],
  rest : Int,
) -> Array[String] {
  let errors : Array[String] = []
  if rest < 0 || rest > 1440 {
    return ["Invalid rest interval."]
  }
  if allocations.length() > 20000 {
    return ["Too many allocations."]
  }
  let known : Map[String, Allocation] = Map([])
  for allocation in allocations {
    if known.contains(allocation.fixture_id) {
      errors.push("Duplicate allocation: " + allocation.fixture_id)
    }
    known[allocation.fixture_id] = allocation
    if find_fixture(t.fixtures, allocation.fixture_id) == None {
      errors.push("Unknown fixture: " + allocation.fixture_id)
    }
    if allocation.start < 0 ||
      allocation.start > 10000000 ||
      allocation.duration <= 0 ||
      allocation.duration > 360 ||
      allocation.court <= 0 ||
      allocation.court > 32 {
      errors.push("Invalid allocation values: " + allocation.fixture_id)
    }
  }
  if errors.any(e => e.has_prefix("Invalid allocation values")) {
    return errors
  }
  for i, a in allocations {
    let fa = find_fixture(t.fixtures, a.fixture_id)
    if fa == None {
      continue
    }
    for slot in [fa.unwrap().home, fa.unwrap().away] {
      match slot_dependency(slot) {
        Some(id) =>
          match known.get(id) {
            Some(parent) =>
              if a.start < parent.start + parent.duration {
                errors.push("Dependency order: " + a.fixture_id)
              }
            None =>
              match find_fixture(t.fixtures, id) {
                Some(parent) =>
                  if fixture_state(t, parent) != Automatic {
                    errors.push("Unscheduled dependency: " + a.fixture_id)
                  }
                None => ()
              }
          }
        None => ()
      }
    }
    let a_ids = possible_entrants(t, fa.unwrap().home, 0)
    for id in possible_entrants(t, fa.unwrap().away, 0) {
      if !a_ids.contains(id) {
        a_ids.push(id)
      }
    }
    for j = i + 1; j < allocations.length(); j = j + 1 {
      let b = allocations[j]
      let fb = find_fixture(t.fixtures, b.fixture_id)
      if fb == None {
        continue
      }
      let overlap = a.start < b.start + b.duration &&
        b.start < a.start + a.duration
      if overlap && a.court == b.court {
        errors.push("Court collision: " + a.fixture_id + " / " + b.fixture_id)
      }
      let b_ids = possible_entrants(t, fb.unwrap().home, 0)
      for id in possible_entrants(t, fb.unwrap().away, 0) {
        if !b_ids.contains(id) {
          b_ids.push(id)
        }
      }
      if a_ids.any(id => b_ids.contains(id)) {
        let gap = if a.start <= b.start {
          b.start - a.start - a.duration
        } else {
          a.start - b.start - b.duration
        }
        if gap < rest {
          errors.push(
            "Participant rest collision: " + a.fixture_id + " / " + b.fixture_id,
          )
        }
      }
    }
  }
  errors
}
