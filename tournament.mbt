///|
pub fn create_tournament(
  title : String,
  format : Format,
  rules : Rules,
  participants : Array[Participant],
  group_count? : Int = 2,
  qualifiers? : Int = 2,
  third_place? : Bool = false,
  swiss_rounds? : Int = 3,
) -> Tournament raise FixtureError {
  validate_participants(participants)
  validate_rules(rules)
  require(
    title.trim().length() > 0 && title.length() <= 160,
    "Use a title of 1 to 160 characters.",
  )
  require(
    participants.all(p => p.active),
    "New tournaments require active entrants.",
  )
  let fixtures = match format {
    RoundRobin => round_robin(participants)
    DoubleRoundRobin => round_robin(participants, double=true)
    LeaguePlayoff | LeagueDoublePlayoff => {
      require(
        qualifiers >= 2 &&
        qualifiers <= participants.length() &&
        next_power_two(qualifiers) == qualifiers,
        "League playoff qualifiers must be a power of two between 2 and the entrant count.",
      )
      round_robin(participants, double=format == LeagueDoublePlayoff)
    }
    SingleElimination => single_elimination(participants, third_place~)
    DoubleElimination => double_elimination(participants)
    Groups | GroupsDouble => {
      let groups = distribute_groups(participants, group_count)
      require(
        qualifiers >= 1 && groups.all(g => qualifiers <= g.length()),
        "Invalid qualifiers per group.",
      )
      group_fixtures(participants, group_count, double=format == GroupsDouble)
    }
    Swiss | SwissPlayoff => {
      require(
        participants.length() <= 64,
        "Club Swiss pairing supports at most 64 entrants.",
      )
      if format == SwissPlayoff {
        require(
          swiss_rounds >= 1 && swiss_rounds < participants.length(),
          "Swiss playoff rounds must be between 1 and entrant count minus one.",
        )
        require(
          qualifiers >= 2 &&
          qualifiers <= participants.length() &&
          next_power_two(qualifiers) == qualifiers,
          "Swiss playoff qualifiers must be a power of two between 2 and the entrant count.",
        )
      }
      []
    }
  }
  let t : Tournament = {
    title: title.trim().to_owned(),
    format,
    rules,
    participants: participants.copy(),
    fixtures,
    results: Map([]),
    group_count: if format == Groups || format == GroupsDouble {
      group_count
    } else {
      0
    },
    qualifiers: if format == Groups ||
      format == GroupsDouble ||
      format == SwissPlayoff ||
      format == LeaguePlayoff ||
      format == LeagueDoublePlayoff {
      qualifiers
    } else {
      0
    },
    swiss_rounds: if format == SwissPlayoff {
      swiss_rounds
    } else {
      0
    },
  }
  if format == Swiss || format == SwissPlayoff {
    next_swiss_round(t)
  } else {
    t
  }
}

///|
/// A new season can change its field before any score is recorded. Rebuild the
/// fixture graph so removed or reordered entrants never leave dangling slots.
pub fn replace_roster(
  t : Tournament,
  names : Array[String],
) -> Tournament raise FixtureError {
  require(
    t.results.length() == 0,
    "Cannot change entrants after recording results.",
  )
  let participants = participants_from_names(names)
  let seen : Map[String, Bool] = Map([])
  for p in participants {
    require(!seen.contains(p.name), "Entrant names must be unique.")
    seen[p.name] = true
  }
  create_tournament(
    t.title,
    t.format,
    t.rules,
    participants,
    group_count=if t.group_count == 0 { 2 } else { t.group_count },
    qualifiers=if t.qualifiers == 0 { 2 } else { t.qualifiers },
    third_place=t.fixtures.any(f => f.stage == "third-place"),
    swiss_rounds=if t.swiss_rounds == 0 { 3 } else { t.swiss_rounds },
  )
}

///|
fn elimination_fixture(fixture : Fixture) -> Bool {
  fixture.stage == "winners" ||
  fixture.stage == "losers" ||
  fixture.stage == "third-place" ||
  fixture.stage == "grand-final" ||
  fixture.stage == "reset" ||
  fixture.stage == "knockout"
}

///|
/// Clear all descendants before changing a winner; preserve independent results.
pub fn remove_result(
  t : Tournament,
  id : String,
) -> Tournament raise FixtureError {
  require(find_fixture(t.fixtures, id) != None, "Unknown fixture.")
  let removed : Map[String, Bool] = Map([])
  removed[id] = true
  let target = find_fixture(t.fixtures, id).unwrap()
  let group_changed = target.stage.has_prefix("group-")
  let swiss_changed = target.stage == "swiss"
  let league_changed = target.stage == "league" &&
    (t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff)
  let fixtures : Array[Fixture] = []
  for fixture in t.fixtures {
    let later_swiss = swiss_changed &&
      fixture.stage == "swiss" &&
      fixture.round > target.round
    let later_playoff = (group_changed || swiss_changed || league_changed) &&
      fixture.stage == "knockout"
    if later_swiss || later_playoff {
      removed[fixture.id] = true
      continue
    }
    for slot in [fixture.home, fixture.away] {
      match slot_dependency(slot) {
        Some(dependency) =>
          if removed.contains(dependency) {
            removed[fixture.id] = true
          }
        None => ()
      }
    }
    fixtures.push(fixture)
  }
  let results = t.results.copy()
  for key, _ in removed {
    results.remove(key)
  }
  { ..t, fixtures, results, }
}

///|
pub fn record_result(
  t : Tournament,
  result : MatchResult,
) -> Tournament raise FixtureError {
  let fixture = match find_fixture(t.fixtures, result.fixture_id) {
    Some(f) => f
    None => raise InvalidInput("Unknown fixture: " + result.fixture_id)
  }
  if t.results.get(result.fixture_id) == Some(result) {
    return t
  }
  let cleaned = remove_result(t, result.fixture_id)
  if fixture_state(cleaned, fixture) != Playable {
    raise InvalidResult("This fixture is not ready to receive a result.")
  }
  match
    (resolve_slot(cleaned, fixture.home), resolve_slot(cleaned, fixture.away)) {
    (Ready(a), Ready(b)) => require(a != b, "An entrant cannot play itself.")
    _ =>
      raise DependencyError(
        "Resolve both participants before recording a result.",
      )
  }
  validate_result(t.rules, result, decisive=elimination_fixture(fixture))
  let results = cleaned.results.copy()
  results[result.fixture_id] = { ..result, sets: result.sets.copy(), }
  { ..cleaned, results, }
}

///|
pub fn advance_groups(t : Tournament) -> Tournament raise FixtureError {
  require(
    t.format == Groups || t.format == GroupsDouble,
    "Only group tournaments can advance to a knockout.",
  )
  require(
    !t.fixtures.any(f => f.stage == "knockout"),
    "The knockout already exists.",
  )
  let ranked_groups : Array[Array[Standing]] = []
  for i in 0..<t.group_count {
    let stage = "group-" + (i + 1).to_string()
    for fixture in t.fixtures {
      if fixture.stage == stage &&
        fixture_state(t, fixture) != Finished &&
        fixture_state(t, fixture) != Automatic {
        raise InvalidInput("Finish every group game before advancing.")
      }
    }
    let rows = standings(t, stage~)
    require(rows.length() >= t.qualifiers, "Not enough group entrants.")
    if rows.length() > t.qualifiers &&
      rows[t.qualifiers - 1].rank == rows[t.qualifiers].rank {
      raise UnresolvedTie(
        "A qualification-cutoff tie remains in " +
        stage +
        ". Configure an explicit final tie-break.",
      )
    }
    ranked_groups.push(rows)
  }
  // Keep winners in high seeds; repair same-group opening games within a rank band.
  let qualified : Array[Participant] = []
  let membership : Map[Int, Int] = Map([])
  for position in 0..<t.qualifiers {
    for offset in 0..<t.group_count {
      let group = offset
      let p = ranked_groups[group][position].participant
      qualified.push({ ..p, seed: qualified.length() + 1, })
      membership[p.id] = group
    }
  }
  let placement = bracket_seed_order(next_power_two(qualified.length()))
  let partners : Map[Int, Int] = Map([])
  for i in 0..<(placement.length() / 2) {
    partners[placement[i * 2] - 1] = placement[i * 2 + 1] - 1
    partners[placement[i * 2 + 1] - 1] = placement[i * 2] - 1
  }
  for i in 0..<qualified.length() {
    let opponent = partners[i]
    if opponent >= qualified.length() ||
      membership[qualified[i].id] != membership[qualified[opponent].id] {
      continue
    }
    for j in 0..<qualified.length() {
      if i == j || i / t.group_count != j / t.group_count {
        continue
      }
      let other = partners[j]
      if j == opponent || other == i {
        continue
      }
      if membership[qualified[j].id] == membership[qualified[opponent].id] {
        continue
      }
      if other < qualified.length() &&
        membership[qualified[i].id] == membership[qualified[other].id] {
        continue
      }
      let a = qualified[i]
      let b = qualified[j]
      qualified[i] = { ..b, seed: i + 1, }
      qualified[j] = { ..a, seed: j + 1, }
      break
    }
  }
  append_knockout(t, qualified)
}

///|
/// Complete a bounded Club Swiss stage, then seed a conventional playoff.
pub fn advance_swiss(t : Tournament) -> Tournament raise FixtureError {
  require(t.format == SwissPlayoff, "This action requires Swiss playoffs.")
  require(
    !t.fixtures.any(f => f.stage == "knockout"),
    "The knockout already exists.",
  )
  let mut latest = 0
  for fixture in t.fixtures {
    if fixture.stage == "swiss" {
      latest = max_int(latest, fixture.round)
      let state = fixture_state(t, fixture)
      require(
        state == Finished || state == Automatic,
        "Finish every Swiss game before advancing.",
      )
    }
  }
  require(
    latest == t.swiss_rounds,
    "Complete all configured Swiss rounds first.",
  )
  let rows = standings(t, stage="swiss").filter(row => row.participant.active)
  require(rows.length() >= t.qualifiers, "Not enough active Swiss entrants.")
  for i in 1..<t.qualifiers {
    if rows[i - 1].rank == rows[i].rank {
      raise UnresolvedTie(
        "A Swiss playoff seeding tie remains. Configure an explicit final tie-break.",
      )
    }
  }
  if rows.length() > t.qualifiers &&
    rows[t.qualifiers - 1].rank == rows[t.qualifiers].rank {
    raise UnresolvedTie("A Swiss playoff qualification-cutoff tie remains.")
  }
  let qualified : Array[Participant] = []
  for i in 0..<t.qualifiers {
    qualified.push({ ..rows[i].participant, seed: i + 1, })
  }
  append_knockout(t, qualified)
}

///|
/// Promote a completed league table into a seeded playoff. Equal ranks at any
/// qualifying seed need an explicit final organizer tie-break before advancing.
pub fn advance_league(t : Tournament) -> Tournament raise FixtureError {
  require(
    t.format == LeaguePlayoff || t.format == LeagueDoublePlayoff,
    "This action requires a league playoff format.",
  )
  require(
    !t.fixtures.any(f => f.stage == "knockout"),
    "The knockout already exists.",
  )
  for fixture in t.fixtures {
    let state = fixture_state(t, fixture)
    require(
      fixture.stage == "league" && (state == Finished || state == Automatic),
      "Finish every league game before advancing.",
    )
  }
  let rows = standings(t, stage="league").filter(row => row.participant.active)
  require(rows.length() >= t.qualifiers, "Not enough active league entrants.")
  for i in 1..<t.qualifiers {
    if rows[i - 1].rank == rows[i].rank {
      raise UnresolvedTie(
        "A league playoff seeding tie remains. Configure an explicit final tie-break.",
      )
    }
  }
  if rows.length() > t.qualifiers &&
    rows[t.qualifiers - 1].rank == rows[t.qualifiers].rank {
    raise UnresolvedTie("A league playoff qualification-cutoff tie remains.")
  }
  let qualified : Array[Participant] = []
  for i in 0..<t.qualifiers {
    qualified.push({ ..rows[i].participant, seed: i + 1, })
  }
  append_knockout(t, qualified)
}

///|
fn append_knockout(
  t : Tournament,
  qualified : Array[Participant],
) -> Tournament raise FixtureError {
  let knockout = single_elimination(qualified)
  let renamed = knockout.map(f => {
    let rewrite = (slot : Slot) => {
      match slot {
        Winner(id) => Winner("ko-" + id)
        Loser(id) => Loser("ko-" + id)
        _ => slot
      }
    }
    {
      ..f,
      id: "ko-" + f.id,
      stage: "knockout",
      home: rewrite(f.home),
      away: rewrite(f.away),
    }
  })
  let fixtures = t.fixtures.copy()
  for fixture in renamed {
    fixtures.push(fixture)
  }
  { ..t, fixtures, }
}

///|
pub fn set_active(
  t : Tournament,
  id : Int,
  active : Bool,
) -> Tournament raise FixtureError {
  require(t.participants.any(p => p.id == id), "Unknown participant.")
  let participants = t.participants.map(p => {
    if p.id == id {
      { ..p, active, }
    } else {
      p
    }
  })
  { ..t, participants, }
}

///|
/// Apply forfeits to ready fixtures with exactly one withdrawn entrant.
pub fn settle_withdrawals(
  tournament : Tournament,
) -> Tournament raise FixtureError {
  let mut t = tournament
  let active : Map[Int, Bool] = Map([])
  for p in t.participants {
    active[p.id] = p.active
  }
  for fixture in tournament.fixtures {
    if fixture_state(t, fixture) != Playable {
      continue
    }
    match (resolve_slot(t, fixture.home), resolve_slot(t, fixture.away)) {
      (Ready(a), Ready(b)) =>
        if active[a] != active[b] {
          t = record_result(
            t,
            forfeit_result(t.rules, fixture.id, if active[a] { 1 } else { 2 }),
          )
        }
      _ => ()
    }
  }
  t
}

///|
pub fn validate_tournament(t : Tournament) -> Unit raise FixtureError {
  validate_participants(t.participants)
  validate_rules(t.rules)
  require(
    t.title.trim().length() > 0 && t.title.length() <= 160,
    "Invalid tournament title.",
  )
  validate_fixtures(t)
  validate_format(t)
  for fixture in t.fixtures {
    match (resolve_slot(t, fixture.home), resolve_slot(t, fixture.away)) {
      (Ready(a), Ready(b)) => require(a != b, "An entrant cannot play itself.")
      _ => ()
    }
  }
  for id, result in t.results {
    require(id == result.fixture_id, "Result key does not match fixture ID.")
    let fixture = match find_fixture(t.fixtures, id) {
      Some(f) => f
      None => raise InvalidInput("Result refers to an unknown fixture.")
    }
    if fixture_state(t, fixture) != Finished {
      raise InvalidResult(
        "Stored result has unresolved or inactive participants.",
      )
    }
    validate_result(t.rules, result, decisive=elimination_fixture(fixture))
  }
  if t.format == Groups || t.format == GroupsDouble {
    require(
      t.group_count >= 2 && t.group_count <= 16 && t.qualifiers >= 1,
      "Invalid group configuration.",
    )
  }
}

///|
pub fn new_history(t : Tournament) -> History {
  { current: t, past: [], future: [], }
}

///|
pub fn commit_history(history : History, next : Tournament) -> History {
  if next == history.current {
    return history
  }
  let past = history.past.copy()
  past.push(history.current)
  if past.length() > 100 {
    ignore(past.remove(0))
  }
  { current: next, past, future: [], }
}

///|
pub fn undo(history : History) -> History {
  if history.past.length() == 0 {
    return history
  }
  let past = history.past.copy()
  let previous = past.pop().unwrap()
  let future = history.future.copy()
  future.push(history.current)
  { current: previous, past, future, }
}

///|
pub fn redo(history : History) -> History {
  if history.future.length() == 0 {
    return history
  }
  let future = history.future.copy()
  let next = future.pop().unwrap()
  let past = history.past.copy()
  past.push(history.current)
  { current: next, past, future, }
}
