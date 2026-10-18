///|
/// IDs survive reseeding; seed is a separate competition attribute.
pub(all) struct Participant {
  id : Int32
  name : String
  seed : Int32
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
  Seed(Int32)
  Winner(String)
  Loser(String)
  Empty
} derive(Eq, Debug)

///|
/// An unplayed semifinal is pending, not an empty bye.
pub(all) enum ResolvedSlot {
  Ready(Int32)
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
  round : Int32
  home : Slot
  away : Slot
} derive(Eq, Debug)

///|
pub(all) struct Score {
  home : Int32
  away : Int32
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
  decider : Int32?
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
  best_of : Int32
  target : Int32
  final_target : Int32
  win_by : Int32
  cap : Int32
  win_points : Int32
  draw_points : Int32
  loss_points : Int32
  forfeit_score : Int32
  point_scale : Int32
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
  group_count : Int32
  qualifiers : Int32
  swiss_rounds : Int32
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
  rank : Int32
  played : Int32
  wins : Int32
  draws : Int32
  losses : Int32
  points : Int32
  scored : Int32
  conceded : Int32
  sets_won : Int32
  sets_lost : Int32
  head_to_head : Int32
  buchholz : Int32
  buchholz_cut_one : Int32
  sonneborn_berger : Int32
  byes : Int32
} derive(Eq, Debug)

///|
pub(all) struct Allocation {
  fixture_id : String
  court : Int32
  start : Int32
  duration : Int32
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
  home_wins : Int32
  away_wins : Int32
  complete : Bool
  winner_side : Int32?
  next_game : Int32
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
