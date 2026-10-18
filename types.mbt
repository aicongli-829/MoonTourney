///|
/// IDs survive reseeding; seed is a separate competition attribute.
pub(all) struct Participant {
  id : Int
  name : String
  seed : Int
  active : Bool
} derive(Eq, Debug)

///|
pub extend Participant with Eq::{not_equal, equal}

///|
pub extend Participant with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub(all) enum Sport {
  OpenScore
  Football
  Basketball
  Volleyball
  BeachVolleyball
  Badminton
  TableTennis
  Chess
  Esports
} derive(Eq, Debug)

///|
pub(all) enum Format {
  RoundRobin
  DoubleRoundRobin
  SingleElimination
  DoubleElimination
  Groups
  GroupsDouble
  Swiss
  SwissPlayoff
  LeaguePlayoff
  LeagueDoublePlayoff
} derive(Eq, Debug)

///|
pub(all) enum Slot {
  Seed(Int)
  Winner(String)
  Loser(String)
  Empty
} derive(Eq, Debug)

///|
/// An unplayed semifinal is pending, not an empty bye.
pub(all) enum ResolvedSlot {
  Ready(Int)
  Pending
  Vacant
} derive(Eq, Debug)

///|
pub(all) enum FixtureState {
  Waiting
  Playable
  Automatic
  Finished
  Inactive
} derive(Eq, Debug)

///|
pub(all) struct Fixture {
  id : String
  stage : String
  round : Int
  home : Slot
  away : Slot
} derive(Eq, Debug)

///|
pub(all) struct Score {
  home : Int
  away : Int
} derive(Eq, Debug)

///|
pub(all) enum ResultKind {
  Played
  Forfeit
} derive(Eq, Debug)

///|
/// Decider records side 1 or 2; shootout kicks are not regulation goals.
pub(all) struct MatchResult {
  fixture_id : String
  score : Score
  sets : Array[Score]
  decider : Int?
  kind : ResultKind
} derive(Eq, Debug)

///|
pub(all) enum TieBreak {
  Points
  Wins
  Difference
  Scored
  HeadToHead
  SetRatio
  ScoreRatio
  Buchholz
  BuchholzCutOne
  SonnebornBerger
  SeedOrder
} derive(Eq, Debug)

///|
/// Chess uses doubled points to keep every calculation exact.
pub(all) struct Rules {
  id : String
  label : String
  sport : Sport
  best_of : Int
  target : Int
  final_target : Int
  win_by : Int
  cap : Int
  win_points : Int
  draw_points : Int
  loss_points : Int
  forfeit_score : Int
  point_scale : Int
  tie_breaks : Array[TieBreak]
  source : String
  scope : String
} derive(Eq, Debug)

///|
pub(all) struct Tournament {
  title : String
  format : Format
  rules : Rules
  participants : Array[Participant]
  fixtures : Array[Fixture]
  results : Map[String, MatchResult]
  group_count : Int
  qualifiers : Int
  swiss_rounds : Int
} derive(Eq, Debug)

///|
/// Each season owns a full snapshot, so its rules and format can differ from
/// other seasons in the same collection.
pub(all) struct SeasonRecord {
  key : String
  label : String
  tournament : Tournament
} derive(Eq, Debug)

///|
pub(all) struct SeasonSeries {
  title : String
  seasons : Array[SeasonRecord]
} derive(Eq, Debug)

///|
pub(all) struct Standing {
  participant : Participant
  rank : Int
  played : Int
  wins : Int
  draws : Int
  losses : Int
  points : Int
  scored : Int
  conceded : Int
  sets_won : Int
  sets_lost : Int
  head_to_head : Int
  buchholz : Int
  buchholz_cut_one : Int
  sonneborn_berger : Int
  byes : Int
} derive(Eq, Debug)

///|
pub(all) struct Allocation {
  fixture_id : String
  court : Int
  start : Int
  duration : Int
} derive(Eq, Debug)

///|
pub(all) struct Schedule {
  allocations : Array[Allocation]
  unscheduled : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct History {
  current : Tournament
  past : Array[Tournament]
  future : Array[Tournament]
} derive(Eq, Debug)

///|
pub(all) struct SeriesSummary {
  home_wins : Int
  away_wins : Int
  complete : Bool
  winner_side : Int?
  next_game : Int
} derive(Eq, Debug)

///|
pub(all) suberror FixtureError {
  InvalidInput(String)
  InvalidResult(String)
  DependencyError(String)
  PairingError(String)
  UnresolvedTie(String)
} derive(Debug)

///|
pub extend Sport with Eq::{not_equal, equal}

///|
pub extend Sport with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Format with Eq::{not_equal, equal}

///|
pub extend Format with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Slot with Eq::{not_equal, equal}

///|
pub extend Slot with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResolvedSlot with Eq::{not_equal, equal}

///|
pub extend ResolvedSlot with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FixtureState with Eq::{not_equal, equal}

///|
pub extend FixtureState with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Fixture with Eq::{not_equal, equal}

///|
pub extend Fixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Score with Eq::{not_equal, equal}

///|
pub extend Score with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResultKind with Eq::{not_equal, equal}

///|
pub extend ResultKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MatchResult with Eq::{not_equal, equal}

///|
pub extend MatchResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TieBreak with Eq::{not_equal, equal}

///|
pub extend TieBreak with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Rules with Eq::{not_equal, equal}

///|
pub extend Rules with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Tournament with Eq::{not_equal, equal}

///|
pub extend Tournament with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SeasonRecord with Eq::{not_equal, equal}

///|
pub extend SeasonRecord with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SeasonSeries with Eq::{not_equal, equal}

///|
pub extend SeasonSeries with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Standing with Eq::{not_equal, equal}

///|
pub extend Standing with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Allocation with Eq::{not_equal, equal}

///|
pub extend Allocation with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Schedule with Eq::{not_equal, equal}

///|
pub extend Schedule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend History with Eq::{not_equal, equal}

///|
pub extend History with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SeriesSummary with Eq::{not_equal, equal}

///|
pub extend SeriesSummary with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FixtureError with @moonbitlang/core/debug.Debug::{to_repr}
