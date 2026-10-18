///|
/// Tournament snapshots preserve generated format structure. Custom graphs can
/// use the lower-level fixture validator without masquerading as a named format.
fn validate_format(t : Tournament) -> Unit raise FixtureError {
  require(t.fixtures.length() > 0, "A tournament must have fixtures.")
  match t.format {
    RoundRobin =>
      require(
        t.fixtures == round_robin(t.participants),
        "Round-robin fixtures do not match the entrant field.",
      )
    DoubleRoundRobin =>
      require(
        t.fixtures == round_robin(t.participants, double=true),
        "Double round-robin fixtures do not match the entrant field.",
      )
    LeaguePlayoff | LeagueDoublePlayoff => {
      require(
        t.qualifiers >= 2 &&
        t.qualifiers <= t.participants.length() &&
        next_power_two(t.qualifiers) == t.qualifiers,
        "Invalid league playoff qualifier count.",
      )
      let league_only = t.fixtures.filter(f => f.stage != "knockout")
      require(
        league_only ==
        round_robin(t.participants, double=t.format == LeagueDoublePlayoff),
        "League fixtures do not match their declared format.",
      )
      if t.fixtures.any(f => f.stage == "knockout") {
        let results = t.results.copy()
        for f in t.fixtures {
          if f.stage == "knockout" {
            results.remove(f.id)
          }
        }
        let expected = advance_league({ ..t, fixtures: league_only, results, })
        require(
          t.fixtures == expected.fixtures,
          "Playoff entrants do not match league qualification.",
        )
      }
    }
    SingleElimination => {
      let third = t.fixtures.any(f => f.stage == "third-place")
      require(
        t.fixtures == single_elimination(t.participants, third_place=third),
        "Single-elimination graph does not match its declared format.",
      )
    }
    DoubleElimination =>
      require(
        t.fixtures == double_elimination(t.participants),
        "Double-elimination graph does not match its declared format.",
      )
    Groups | GroupsDouble => {
      let groups = distribute_groups(t.participants, t.group_count)
      require(
        t.qualifiers >= 1 && groups.all(g => t.qualifiers <= g.length()),
        "Invalid group qualification count.",
      )
      let base = group_fixtures(
        t.participants,
        t.group_count,
        double=t.format == GroupsDouble,
      )
      let actual = t.fixtures.filter(f => f.stage != "knockout")
      require(
        actual == base,
        "Group fixtures do not match their declared groups.",
      )
      if t.fixtures.any(f => f.stage == "knockout") {
        let results = t.results.copy()
        for f in t.fixtures {
          if f.stage == "knockout" {
            results.remove(f.id)
          }
        }
        let expected = advance_groups({ ..t, fixtures: actual, results, })
        require(
          t.fixtures == expected.fixtures,
          "Knockout entrants do not match group qualification.",
        )
      }
    }
    Swiss => validate_swiss_structure(t)
    SwissPlayoff => {
      require(
        t.swiss_rounds >= 1 && t.swiss_rounds < t.participants.length(),
        "Invalid Swiss playoff round count.",
      )
      require(
        t.qualifiers >= 2 &&
        t.qualifiers <= t.participants.length() &&
        next_power_two(t.qualifiers) == t.qualifiers,
        "Invalid Swiss playoff qualifier count.",
      )
      let swiss_only = t.fixtures.filter(f => f.stage == "swiss")
      require(
        swiss_only.length() > 0 &&
        swiss_only.all(f => f.round <= t.swiss_rounds),
        "Swiss fixtures exceed configured rounds.",
      )
      validate_swiss_structure({ ..t, fixtures: swiss_only, })
      if t.fixtures.any(f => f.stage == "knockout") {
        require(
          t.fixtures.length() > swiss_only.length(),
          "Invalid Swiss playoff fixtures.",
        )
        let results = t.results.copy()
        for f in t.fixtures {
          if f.stage == "knockout" {
            results.remove(f.id)
          }
        }
        let expected = advance_swiss({ ..t, fixtures: swiss_only, results, })
        require(
          t.fixtures == expected.fixtures,
          "Playoff entrants do not match Swiss qualification.",
        )
      } else {
        require(
          t.fixtures == swiss_only,
          "Swiss playoff fixtures contain an unexpected stage.",
        )
      }
    }
  }
  if t.format != Groups && t.format != GroupsDouble {
    require(
      t.group_count == 0,
      "Group settings are only valid for group tournaments.",
    )
  }
  if t.format != Groups &&
    t.format != GroupsDouble &&
    t.format != SwissPlayoff &&
    t.format != LeaguePlayoff &&
    t.format != LeagueDoublePlayoff {
    require(t.qualifiers == 0, "Qualifiers require a combined format.")
  }
  if t.format != SwissPlayoff {
    require(t.swiss_rounds == 0, "Swiss round limit requires Swiss playoffs.")
  }
}

///|
fn validate_swiss_structure(t : Tournament) -> Unit raise FixtureError {
  require(
    t.participants.length() <= 64,
    "Swiss fields are limited to 64 entrants.",
  )
  let pairings : Map[String, Bool] = Map([])
  let appearances : Map[String, Bool] = Map([])
  let byes : Map[Int, Bool] = Map([])
  let bye_rounds : Map[Int, Bool] = Map([])
  let rounds : Map[Int, Bool] = Map([])
  let mut latest = 0
  for fixture in t.fixtures {
    require(
      fixture.stage == "swiss" && fixture.round <= 64,
      "Invalid Swiss stage or round.",
    )
    require(fixture.round >= latest, "Swiss fixtures must be ordered by round.")
    rounds[fixture.round] = true
    latest = fixture.round
    for slot in [fixture.home, fixture.away] {
      match slot {
        Seed(id) => {
          let key = fixture.round.to_string() + ":" + id.to_string()
          require(
            !appearances.contains(key),
            "An entrant appears twice in one Swiss round.",
          )
          appearances[key] = true
        }
        Empty => ()
        _ =>
          raise InvalidInput(
            "Swiss fixtures must contain entrants or a bye, not bracket dependencies.",
          )
      }
    }
    match (fixture.home, fixture.away) {
      (Seed(a), Seed(b)) => {
        let key = min_int(a, b).to_string() + ":" + max_int(a, b).to_string()
        require(!pairings.contains(key), "Repeated Swiss opponent pairing.")
        pairings[key] = true
      }
      (Seed(id), Empty) | (Empty, Seed(id)) => {
        require(
          !byes.contains(id),
          "An entrant received a second Swiss pairing bye.",
        )
        require(
          !bye_rounds.contains(fixture.round),
          "A Swiss round has more than one bye.",
        )
        byes[id] = true
        bye_rounds[fixture.round] = true
      }
      _ => raise InvalidInput("A Swiss fixture cannot consist of two byes.")
    }
  }
  for round in 1..<=latest {
    require(rounds.contains(round), "Swiss rounds must be consecutive.")
  }
  for fixture in t.fixtures {
    if fixture.round < latest {
      let state = fixture_state(t, fixture)
      require(
        state == Finished || state == Automatic,
        "An earlier Swiss round is incomplete.",
      )
    }
  }
}
