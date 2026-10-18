///|
fn require(condition : Bool, message : String) -> Unit raise FixtureError {
  if !condition {
    raise InvalidInput(message)
  }
}

///|
fn compare_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn sport_name(sport : Sport) -> String {
  match sport {
    OpenScore => "Open score"
    Football => "Football"
    Basketball => "Basketball"
    Volleyball => "Volleyball"
    BeachVolleyball => "Beach volleyball"
    Badminton => "Badminton"
    TableTennis => "Table tennis"
    Chess => "Chess"
    Esports => "Esports"
  }
}

///|
pub fn format_name(format : Format) -> String {
  match format {
    RoundRobin => "round-robin"
    DoubleRoundRobin => "double-round-robin"
    SingleElimination => "single-elimination"
    DoubleElimination => "double-elimination"
    Groups => "groups"
    GroupsDouble => "groups-double"
    Swiss => "swiss"
    SwissPlayoff => "swiss-playoff"
    LeaguePlayoff => "league-playoff"
    LeagueDoublePlayoff => "league-double-playoff"
  }
}

///|
pub fn parse_format(text : String) -> Format raise FixtureError {
  match text {
    "round-robin" => RoundRobin
    "double-round-robin" => DoubleRoundRobin
    "single-elimination" => SingleElimination
    "double-elimination" => DoubleElimination
    "groups" => Groups
    "groups-double" => GroupsDouble
    "swiss" => Swiss
    "swiss-playoff" => SwissPlayoff
    "league-playoff" => LeaguePlayoff
    "league-double-playoff" => LeagueDoublePlayoff
    _ => raise InvalidInput("Unknown format: " + text)
  }
}

///|
pub fn validate_participants(
  participants : Array[Participant],
) -> Unit raise FixtureError {
  require(participants.length() >= 2, "At least two participants are required.")
  require(
    participants.length() <= 128,
    "At most 128 participants are supported.",
  )
  let ids : Map[Int, Bool] = Map([])
  let seeds : Map[Int, Bool] = Map([])
  for p in participants {
    require(
      p.id > 0 && p.id <= 1000000,
      "Participant IDs must be positive and bounded.",
    )
    require(
      p.seed > 0 && p.seed <= 1000000,
      "Seeds must be positive and bounded.",
    )
    require(p.name.trim().length() > 0, "Participant names cannot be empty.")
    require(p.name.length() <= 120, "Names must be at most 120 characters.")
    require(!ids.contains(p.id), "Duplicate participant ID.")
    require(!seeds.contains(p.seed), "Duplicate participant seed.")
    ids[p.id] = true
    seeds[p.seed] = true
  }
}

///|
pub fn seeded_participants(
  participants : Array[Participant],
) -> Array[Participant] {
  let ordered = participants.copy()
  ordered.sort_by((a, b) => compare_int(a.seed, b.seed))
  ordered
}

///|
pub fn participants_from_names(
  names : Array[String],
) -> Array[Participant] raise FixtureError {
  let participants = names.mapi((i, name) => {
    id: i + 1,
    name: name.trim().to_owned(),
    seed: i + 1,
    active: true,
  })
  validate_participants(participants)
  participants
}

///|
pub fn participant_name(participants : Array[Participant], id : Int) -> String {
  for p in participants {
    if p.id == id {
      return p.name
    }
  }
  "Unknown #" + id.to_string()
}

///|
fn next_power_two(value : Int) -> Int {
  let mut size = 2
  while size < value {
    size = size * 2
  }
  size
}

///|
fn find_fixture(fixtures : Array[Fixture], id : String) -> Fixture? {
  for fixture in fixtures {
    if fixture.id == id {
      return Some(fixture)
    }
  }
  None
}

///|
fn same_pair(a : Int, b : Int, c : Int, d : Int) -> Bool {
  (a == c && b == d) || (a == d && b == c)
}

///|
pub fn display_points(points : Int, scale : Int) -> String {
  if scale == 2 {
    (points / 2).to_string() + (if points % 2 == 0 { "" } else { ".5" })
  } else {
    points.to_string()
  }
}
