///|
test "court planner produces a separately validated schedule for all formats" {
  for
    format in [
      RoundRobin,
      DoubleRoundRobin,
      SingleElimination,
      DoubleElimination,
      Groups,
      Swiss,
    ] {
    let t = create_tournament("Event", format, preset("football"), entrants(8))
    for courts in [1, 2, 4] {
      let planned = schedule(t, courts, 30, rest=15, start=540)
      assert_eq(planned.unscheduled, [])
      assert_eq(validate_schedule(t, planned.allocations, 15), [])
      for allocation in planned.allocations {
        assert_true(allocation.start >= 540)
        assert_true(allocation.court >= 1 && allocation.court <= courts)
      }
    }
  }
}

///|
test "byes do not reserve courts and final starts after semifinal rest" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(3),
  )
  let plan = schedule(t, 2, 20, rest=10)
  assert_eq(plan.allocations.length(), 2)
  assert_eq(plan.allocations[0].start, 0)
  assert_eq(plan.allocations[1].start, 30)
  assert_eq(plan.allocations[1].fixture_id, "w-2-1")
  assert_eq(validate_schedule(t, plan.allocations, 10), [])
}

///|
test "short horizon exposes unscheduled games and blocks dependents" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(8),
  )
  let plan = schedule(t, 2, 30, horizon=30)
  assert_eq(plan.allocations.length(), 2)
  assert_eq(plan.unscheduled.length(), 5)
  assert_true(plan.unscheduled.contains("w-3-1"))
}

///|
test "daily playing window rolls fixtures to the next day" {
  let t = create_tournament(
    "Weekend league",
    RoundRobin,
    preset("football"),
    entrants(4),
  )
  let plan = schedule(
    t,
    1,
    60,
    rest=0,
    start=540,
    horizon=3 * 1440 + 660,
    day_start=540,
    day_end=660,
  )
  assert_eq(plan.unscheduled, [])
  assert_eq(plan.allocations.length(), 6)
  for item in plan.allocations {
    assert_true(item.start % 1440 == 540 || item.start % 1440 == 600)
  }
  assert_eq(plan.allocations[2].start, 1440 + 540)
  assert_eq(validate_schedule(t, plan.allocations, 0), [])
}

///|
test "independent schedule verification catches court, rest and dependency collisions" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  let plan = schedule(t, 2, 30, rest=10)
  let bad = plan.allocations.map(a => { ..a, start: 0, court: 1, })
  let errors = validate_schedule(t, bad, 10)
  assert_true(errors.any(e => e.has_prefix("Court collision")))
  assert_true(errors.any(e => e.has_prefix("Participant rest collision")))
  assert_true(errors.any(e => e.has_prefix("Dependency order")))
  assert_true(
    validate_schedule(t, [plan.allocations[2]], 10).any(e => {
      e.has_prefix("Unscheduled dependency")
    }),
  )
}

///|
test "planner validates capacity and time bounds" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(4),
  )
  for court in [0, -1, 33] {
    assert_true(rejects(() => ignore(schedule(t, court, 30))))
  }
  assert_true(rejects(() => ignore(schedule(t, 1, 0))))
  assert_true(rejects(() => ignore(schedule(t, 1, 361))))
  assert_true(rejects(() => ignore(schedule(t, 1, 30, rest=-1))))
  assert_true(rejects(() => ignore(schedule(t, 1, 30, start=100, horizon=50))))
}

///|
test "validator handles unknown and duplicate allocations without lookup panic" {
  let t = create_tournament(
    "Cup",
    SingleElimination,
    preset("football"),
    entrants(2),
  )
  let allocation : Allocation = {
    fixture_id: "missing",
    court: 0,
    start: -1,
    duration: 0,
  }
  let errors = validate_schedule(t, [allocation, allocation], 0)
  assert_true(errors.any(e => e.has_prefix("Unknown fixture")))
  assert_true(errors.any(e => e.has_prefix("Duplicate allocation")))
  assert_true(errors.any(e => e.has_prefix("Invalid allocation")))
}
