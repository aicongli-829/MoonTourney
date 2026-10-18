///|
test "spring and summer snapshots are independent, with reproducible history" {
  let rules = with_seed_tie_break(preset("open-score"), true)
  let spring = complete_ready(
    create_tournament("Spring cup", RoundRobin, rules, entrants(4)),
  )
  let first = add_season(
    new_season_series("Club year 2026"),
    "spring",
    "Spring 2026",
    spring,
  )
  let both = clone_season(
    first, "spring", "summer", "Summer 2026", "Summer cup",
  )
  assert_eq(both.seasons.length(), 2)
  assert_eq(both.seasons[0].tournament, spring)
  assert_eq(both.seasons[1].tournament.results.length(), 0)
  assert_eq(both.seasons[1].tournament.format, RoundRobin)
  assert_eq(both.seasons[1].tournament.rules, rules)
  let summer = complete_ready(both.seasons[1].tournament, away=true)
  let finished = update_season(both, "summer", summer)
  assert_eq(finished.seasons[0].tournament, spring)
  assert_eq(finished.seasons[1].tournament, summer)
  let restored = season_series_from_json(
    @json.parse(season_series_to_json(finished).stringify()),
  )
  assert_eq(restored, finished)
  let view = season_series_view_to_json(restored)
  let seasons = array_value(field(view, "seasons"), "seasons")
  assert_eq(seasons.length(), 2)
  assert_true(field(seasons[0], "champion") != Json::null())
  assert_true(field(seasons[1], "champion") != Json::null())
  assert_true(season_series_csv(restored).contains("Spring 2026"))
  assert_true(season_history_csv(restored).contains("seasons_entered"))
}

///|
test "a season series can mix formats without adding incompatible score scales" {
  let football = create_tournament(
    "Spring football",
    LeaguePlayoff,
    preset("football"),
    entrants(4),
    qualifiers=2,
  )
  let chess = create_tournament(
    "Summer chess",
    Swiss,
    preset("chess"),
    entrants(4),
  )
  let first = add_season(
    new_season_series("Open club"),
    "spring",
    "Spring",
    football,
  )
  let mixed = add_season(first, "summer", "Summer", chess)
  let view = season_series_view_to_json(mixed)
  let summaries = array_value(field(view, "seasons"), "seasons")
  assert_eq(field(summaries[0], "sport"), ("Football" : Json))
  assert_eq(field(summaries[1], "sport"), ("Chess" : Json))
  assert_eq(field(summaries[0], "champion"), Json::null())
  assert_eq(field(summaries[1], "champion"), Json::null())
  assert_eq(remove_season(mixed, "summer"), first)
}

///|
test "season collection rejects identity collisions and malformed imports" {
  let t = create_tournament(
    "Cup",
    RoundRobin,
    preset("open-score"),
    entrants(4),
  )
  let first = add_season(new_season_series("Year"), "spring", "Spring", t)
  assert_true(rejects(() => ignore(add_season(first, "spring", "Summer", t))))
  assert_true(rejects(() => ignore(add_season(first, "summer", "Spring", t))))
  assert_true(rejects(() => ignore(update_season(first, "missing", t))))
  assert_true(rejects(() => ignore(remove_season(first, "missing"))))
  assert_true(
    rejects(() => ignore(clone_season(first, "missing", "s2", "Summer", "Cup"))),
  )
  let duplicate_names = t.participants.copy()
  duplicate_names[1] = { ..duplicate_names[1], name: duplicate_names[0].name, }
  assert_true(
    rejects(() => {
      ignore(
        add_season(first, "s2", "Summer", {
          ..t,
          participants: duplicate_names,
        }),
      )
    }),
  )
  let fields = match season_series_to_json(first) {
    Object(fields) => fields.copy()
    _ => Map([])
  }
  fields["seasonSeriesVersion"] = number_json(2)
  assert_true(
    rejects(() => ignore(season_series_from_json(Json::object(fields)))),
  )
}

///|
test "season actions round trip through the common JSON dispatcher" {
  let tournament = tournament_to_json(
    create_tournament("Spring", RoundRobin, preset("football"), entrants(4)),
  )
  let created = @json.parse(
    dispatch_json(
      ({ "action": "season-new", "title": "Community year" } : Json).stringify(),
    ),
  )
  assert_eq(field(created, "ok"), (true : Json))
  let collection = field(field(created, "data"), "collection")
  let added = @json.parse(
    dispatch_json(
      (
        {
          "action": "season-add",
          "collection": collection,
          "label": "Spring 2026",
          "tournament": tournament,
        } : Json).stringify(),
    ),
  )
  assert_eq(field(added, "ok"), (true : Json))
  let saved = field(field(added, "data"), "collection")
  let inspected = @json.parse(
    dispatch_json(
      ({ "action": "season-inspect", "collection": saved } : Json).stringify(),
    ),
  )
  assert_eq(field(inspected, "ok"), (true : Json))
  let csv = @json.parse(
    dispatch_json(
      (
        {
          "action": "season-export",
          "collection": saved,
          "kind": "seasons-csv",
        } : Json).stringify(),
    ),
  )
  assert_eq(field(csv, "ok"), (true : Json))
  assert_true(
    text_value(field(field(csv, "data"), "content"), "content").contains(
      "Spring 2026",
    ),
  )
}

///|
test "a fresh season can change entrants but a scored season cannot" {
  let initial = create_tournament(
    "Summer",
    LeaguePlayoff,
    preset("open-score"),
    entrants(8),
    qualifiers=4,
  )
  let names = ["A", "B", "C", "D", "E", "F"]
  let changed = replace_roster(initial, names)
  assert_eq(changed.participants.length(), 6)
  assert_eq(changed.fixtures.length(), 15)
  assert_eq(changed.results.length(), 0)
  validate_tournament(changed)
  assert_true(
    rejects(() => ignore(replace_roster(changed, ["A", "A", "C", "D"]))),
  )
  let played = record_result(
    changed,
    score_result(changed.fixtures[0].id, 1, 0),
  )
  assert_true(rejects(() => ignore(replace_roster(played, names))))
}
