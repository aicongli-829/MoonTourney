///|
priv struct Ui {
  mut history : @core.History?
  mut tab : String
  mut editor : String
  mut page : Int
  mut schedule_csv : String
  mut schedule_slots : Map[String, String]
  mut export_content : String
  mut export_name : String
  mut export_mime : String
  mut seasons : @core.SeasonSeries?
  mut active_season : String
}

///|
let ui : Ui = {
  history: None,
  tab: "fixtures",
  editor: "",
  page: 0,
  schedule_csv: "",
  schedule_slots: Map([]),
  export_content: "",
  export_name: "",
  export_mime: "text/plain;charset=utf-8",
  seasons: None,
  active_season: "",
}

///|
fn get(doc : Json, key : String) -> Json {
  match doc {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn label(doc : Json, key : String, fallback? : String = "") -> String {
  match get(doc, key) {
    String(s) => s
    Number(n, ..) => n.to_int().to_string()
    _ => fallback
  }
}

///|
fn items(doc : Json, key : String) -> Array[Json] {
  match get(doc, key) {
    Array(rows) => rows
    _ => []
  }
}

///|
fn escape(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
fn notice(message : String) -> Unit {
  text("notice", message)
  hidden("notice", message == "")
  text("dialog-notice", message)
  hidden("dialog-notice", message == "")
  text("export-notice", message)
  hidden("export-notice", message == "")
}

///|
fn current() -> @core.Tournament? {
  match ui.history {
    Some(history) => Some(history.current)
    None => None
  }
}

///|
fn persist_seasons() -> Bool {
  let mut stored = true
  match ui.seasons {
    Some(series) =>
      if !save_season_storage(@core.season_series_to_json(series).stringify()) {
        stored = false
      }
    None => ()
  }
  if !save_active_season_storage(ui.active_season) {
    stored = false
  }
  if !stored {
    notice(
      "Season collection is in memory only. Export its JSON backup before closing the page.",
    )
  }
  stored
}

///|
fn persist_current(t : @core.Tournament) -> Unit {
  if !save_storage(@core.tournament_to_json(t).stringify()) {
    notice(
      "Saved in memory. Browser storage is unavailable; export a JSON backup.",
    )
  }
  if ui.active_season != "" {
    match ui.seasons {
      Some(series) => {
        let updated = @core.update_season(series, ui.active_season, t) catch {
          error => {
            notice(@core.error_message(error))
            return
          }
        }
        ui.seasons = Some(updated)
        ignore(persist_seasons())
      }
      None => ()
    }
  }
}

///|
fn render_seasons() -> Unit {
  let series = match ui.seasons {
    Some(series) => series
    None => {
      text(
        "season-status", "Create an event, then save it as Spring, Summer or any season name.",
      )
      html("season-list", "")
      html("season-history", "")
      disabled("clone-season", true)
      disabled("update-roster", true)
      disabled("export-seasons", true)
      disabled("export-season-summary", true)
      disabled("export-season-history", true)
      disabled("rename-series", true)
      disabled("add-season", current() == None)
      return
    }
  }
  set_value("series-title", series.title)
  let view = @core.season_series_view_to_json(series)
  let rows = items(view, "seasons")
  let list = StringBuilder()
  for row in rows {
    let key = label(row, "key")
    let champion = label(row, "champion", fallback="In progress")
    list.write_string(
      "<div class=\"season-entry\"><div><strong>" +
      escape(label(row, "label")) +
      (if key == ui.active_season { " · current" } else { "" }) +
      "</strong><small>" +
      escape(label(row, "sport")) +
      " / " +
      escape(label(row, "format")) +
      " · " +
      escape(label(row, "finished")) +
      "/" +
      escape(label(row, "fixtures")) +
      " finished · Winner: " +
      escape(champion) +
      "</small></div><div class=\"season-entry-actions\"><button class=\"small\" data-action=\"open-season\" data-id=\"" +
      escape(key) +
      "\">Open</button><button class=\"small danger\" data-action=\"remove-season\" data-id=\"" +
      escape(key) +
      "\">Remove</button></div></div>",
    )
  }
  html("season-list", list.to_string())
  let history = StringBuilder()
  for row in items(view, "history") {
    history.write_string(
      "<tr><td>" +
      escape(label(row, "name")) +
      "</td><td>" +
      escape(label(row, "appearances")) +
      "</td><td>" +
      escape(label(row, "titles")) +
      "</td></tr>",
    )
  }
  html("season-history", history.to_string())
  let active_label = rows
    .filter(row => label(row, "key") == ui.active_season)
    .map(row => label(row, "label"))
  text(
    "season-status",
    if active_label.length() > 0 {
      "Editing " + active_label[0] + ". Result changes save into this season."
    } else {
      series.seasons.length().to_string() +
      " saved seasons. Current event is separate."
    },
  )
  disabled("add-season", current() == None || ui.active_season != "")
  disabled("clone-season", ui.active_season == "")
  let roster_locked = match current() {
    Some(t) => t.results.length() > 0
    None => true
  }
  disabled("update-roster", ui.active_season == "" || roster_locked)
  disabled("export-seasons", false)
  disabled("export-season-summary", false)
  disabled("export-season-history", false)
  disabled("rename-series", false)
}

///|
fn add_current_season() -> Unit {
  let t = match current() {
    Some(t) => t
    None => {
      notice("Create a competition before saving a season.")
      return
    }
  }
  if ui.active_season != "" {
    notice(
      "This season already saves automatically. Enter a new label and select Start next season.",
    )
    return
  }
  let series = match ui.seasons {
    Some(series) => series
    None => {
      let created = @core.new_season_series(value("series-title")) catch {
        error => {
          notice(@core.error_message(error))
          return
        }
      }
      created
    }
  }
  let key = @core.next_season_key(series) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  let added = @core.add_season(series, key, value("season-label"), t) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  ui.seasons = Some(added)
  ui.active_season = key
  let stored = persist_seasons()
  set_value("season-label", "")
  if stored {
    notice(
      "Season saved with generated fixtures. Enter real scores from the fixtures or timetable; changes save automatically.",
    )
  }
  render_seasons()
}

///|
fn clone_current_season() -> Unit {
  let series = match ui.seasons {
    Some(series) => series
    None => return
  }
  if ui.active_season == "" {
    notice("Open a saved season before starting the next one.")
    return
  }
  let key = @core.next_season_key(series) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  let label = value("season-label").trim().to_owned()
  let cloned = @core.clone_season(
    series,
    ui.active_season,
    key,
    label,
    label + " · " + series.title,
  ) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  ui.seasons = Some(cloned)
  ui.active_season = key
  let stored = persist_seasons()
  set_value("season-label", "")
  save(cloned.seasons[cloned.seasons.length() - 1].tournament, fresh=true)
  if stored {
    notice(
      "New season created with the prior format, rules and entrants; scores are empty.",
    )
  }
}

///|
fn update_current_roster() -> Unit {
  let t = match current() {
    Some(t) => t
    None => return
  }
  if ui.active_season == "" {
    notice("Open a saved season before changing its entrant list.")
    return
  }
  let names = value("entrants")
    .split("\n")
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
    .to_array()
  let rebuilt = @core.replace_roster(t, names) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  save(rebuilt)
  notice(
    "Entrants and fixtures rebuilt for this season. Undo restores the prior list.",
  )
}

///|
fn open_saved_season(key : String) -> Unit {
  let series = match ui.seasons {
    Some(series) => series
    None => return
  }
  if ui.active_season == "" &&
    current() != None &&
    !confirm_change(
      "Open this season? Export the current standalone event first if you need it.",
    ) {
    return
  }
  for season in series.seasons {
    if season.key == key {
      ui.active_season = key
      let stored = persist_seasons()
      save(season.tournament, fresh=true)
      if stored {
        notice("Opened " + season.label + ".")
      }
      return
    }
  }
  notice("This season no longer exists.")
}

///|
fn remove_saved_season(key : String) -> Unit {
  let series = match ui.seasons {
    Some(series) => series
    None => return
  }
  if !confirm_change(
      "Remove this season from the collection? Export the collection first if you need a backup.",
    ) {
    return
  }
  let changed = @core.remove_season(series, key) catch {
    error => {
      notice(@core.error_message(error))
      return
    }
  }
  ui.seasons = Some(changed)
  if ui.active_season == key {
    ui.active_season = ""
  }
  if persist_seasons() {
    notice(
      "Season removed from the collection. The open event remains available separately.",
    )
  }
  render_seasons()
}

///|
fn export_seasons(kind : String) -> Unit {
  let series = match ui.seasons {
    Some(series) => series
    None => return
  }
  let filename = if kind == "json" {
    "moontourney-seasons.json"
  } else {
    "moontourney-" + kind + ".csv"
  }
  let content = match kind {
    "json" => @core.season_series_to_json(series).stringify()
    "seasons" => @core.season_series_csv(series)
    "history" =>
      @core.season_history_csv(series) catch {
        error => {
          notice(@core.error_message(error))
          return
        }
      }
    _ => return
  }
  preview_export(
    filename,
    content,
    if kind == "json" {
      "application/json;charset=utf-8"
    } else {
      "text/csv;charset=utf-8"
    },
  )
}

///|
fn preview_export(name : String, content : String, mime : String) -> Unit {
  ui.export_name = name
  ui.export_content = content
  ui.export_mime = mime
  text("export-title", name)
  set_value("export-content", content)
  notice("")
  open_export()
}

///|
fn save(t : @core.Tournament, fresh? : Bool = false) -> Unit {
  ui.history = Some(
    if fresh || ui.history == None {
      @core.new_history(t)
    } else {
      @core.commit_history(ui.history.unwrap(), t)
    },
  )
  ui.schedule_csv = ""
  ui.schedule_slots = Map([])
  if fresh {
    set_value("title", t.title)
    set_value("sport", t.rules.id)
    set_value("format", @core.format_name(t.format))
    set_value(
      "entrants",
      @core.seeded_participants(t.participants).map(p => p.name).join("\n"),
    )
    set_value(
      "group-count",
      (if t.group_count == 0 { 2 } else { t.group_count }).to_string(),
    )
    set_value(
      "qualifiers",
      (if t.qualifiers == 0 { 2 } else { t.qualifiers }).to_string(),
    )
    set_value(
      "playoff-qualifiers",
      (if t.qualifiers == 0 { 4 } else { t.qualifiers }).to_string(),
    )
    set_value(
      "league-qualifiers",
      (if t.qualifiers == 0 { 4 } else { t.qualifiers }).to_string(),
    )
    set_value(
      "swiss-rounds",
      (if t.swiss_rounds == 0 { 3 } else { t.swiss_rounds }).to_string(),
    )
    set_value(
      "third-place",
      if t.fixtures.any(f => f.stage == "third-place") {
        "yes"
      } else {
        "no"
      },
    )
    preset_changed()
    format_changed()
    set_value("best-of", t.rules.best_of.to_string())
    set_value("win-points", t.rules.win_points.to_string())
    set_value("draw-points", t.rules.draw_points.to_string())
    set_value("loss-points", t.rules.loss_points.to_string())
    set_value(
      "tie-breaks",
      t.rules.tie_breaks.map(@core.tie_break_name).join(", "),
    )
    set_value(
      "seed-tie",
      if t.rules.tie_breaks.contains(@core.SeedOrder) {
        "yes"
      } else {
        "no"
      },
    )
    text("preset-note", t.rules.scope)
  }
  persist_current(t)
  render()
}

///|
fn call(request : Json, change? : Bool = true, fresh? : Bool = false) -> Json? {
  let envelope = @json.parse(@core.dispatch_json(request.stringify())) catch {
    _ => {
      notice("The engine response could not be read.")
      return None
    }
  }
  if get(envelope, "ok") != (true : Json) {
    notice(label(envelope, "error", fallback="Operation failed."))
    return None
  }
  let data = get(envelope, "data")
  if change && get(data, "tournament") != Json::null() {
    let tournament = @core.tournament_from_json(get(data, "tournament")) catch {
      error => {
        notice(@core.error_message(error))
        return None
      }
    }
    notice("")
    if fresh {
      ui.active_season = ""
      ignore(save_active_season_storage(""))
    }
    save(tournament, fresh~)
  }
  Some(data)
}

///|
fn integer(id : String) -> Int? {
  let n = @string.parse_int(value(id).trim().to_owned()) catch {
    _ => {
      notice("Enter a whole number for " + id + ".")
      return None
    }
  }
  Some(n)
}

///|
fn configure_rules() -> Json? {
  let best = integer("best-of")
  let win = integer("win-points")
  let draw = integer("draw-points")
  let loss = integer("loss-points")
  if best == None || win == None || draw == None || loss == None {
    return None
  }
  let criteria = value("tie-breaks")
    .split(",")
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
    .to_array()
  Some({
    "id": value("sport"),
    "bestOf": best.unwrap(),
    "winPoints": win.unwrap(),
    "drawPoints": draw.unwrap(),
    "lossPoints": loss.unwrap(),
    "tieBreaks": criteria,
  })
}

///|
fn preset_changed() -> Unit {
  let rules = @core.preset(value("sport")) catch { _ => return }
  set_value("best-of", rules.best_of.to_string())
  set_value("win-points", rules.win_points.to_string())
  set_value("draw-points", rules.draw_points.to_string())
  set_value("loss-points", rules.loss_points.to_string())
  set_value("tie-breaks", rules.tie_breaks.map(@core.tie_break_name).join(", "))
  disabled("best-of", !@core.uses_sets(rules.sport))
  text("preset-note", rules.scope)
}

///|
fn format_changed() -> Unit {
  hidden(
    "group-options",
    value("format") != "groups" && value("format") != "groups-double",
  )
  hidden("swiss-options", value("format") != "swiss-playoff")
  hidden(
    "league-options",
    value("format") != "league-playoff" &&
    value("format") != "league-double-playoff",
  )
  hidden("third-options", value("format") != "single-elimination")
}

///|
fn create_event() -> Unit {
  if current() != None &&
    !confirm_change(
      "Create a new competition? Export the current competition first if you need it.",
    ) {
    return
  }
  let rules = configure_rules()
  if rules == None {
    return
  }
  let groups = integer("group-count")
  let qualifiers = integer("qualifiers")
  let playoff_qualifiers = integer("playoff-qualifiers")
  let league_qualifiers = integer("league-qualifiers")
  let swiss_rounds = integer("swiss-rounds")
  if groups == None ||
    qualifiers == None ||
    playoff_qualifiers == None ||
    league_qualifiers == None ||
    swiss_rounds == None {
    return
  }
  let names = value("entrants")
    .split("\n")
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
    .to_array()
  ui.page = 0
  let created = call(
    {
      "action": "create",
      "title": value("title"),
      "format": value("format"),
      "rules": rules.unwrap(),
      "entrants": names,
      "groupCount": groups.unwrap(),
      "qualifiers": if value("format") == "swiss-playoff" {
        playoff_qualifiers.unwrap()
      } else if value("format") == "league-playoff" ||
        value("format") == "league-double-playoff" {
        league_qualifiers.unwrap()
      } else {
        qualifiers.unwrap()
      },
      "swissRounds": swiss_rounds.unwrap(),
      "thirdPlace": value("third-place") == "yes",
      "seedTieBreak": value("seed-tie") == "yes",
    },
    fresh=true,
  )
  if created != None && checked("auto-season") {
    if ui.seasons == None {
      set_value("series-title", value("title"))
    }
    let mut season_name = value("initial-season-label").trim().to_owned()
    if season_name == "" || season_name == "Season 1" {
      season_name = "Season " +
        (match ui.seasons {
          Some(series) => series.seasons.length() + 1
          None => 1
        }).to_string()
    }
    set_value("season-label", season_name)
    add_current_season()
  } else if created != None {
    notice(
      "Competition created. Fixtures and a suggested timetable are ready; select Score after each game.",
    )
  }
  if created != None {
    scroll_to("workspace")
  }
}

///|
fn sample(which : String) -> Unit {
  match which {
    "league" => {
      set_value("title", "Neighborhood league cup")
      set_value("sport", "open-score")
      set_value("format", "league-playoff")
      set_value("league-qualifiers", "4")
      set_value("seed-tie", "yes")
      set_value(
        "entrants", "Aurora\nBolt\nComet\nDrift\nEcho\nFlux\nGlacier\nHalo",
      )
    }
    "swiss" => {
      set_value("title", "Friday chess club")
      set_value("sport", "chess")
      set_value("format", "swiss")
      set_value("entrants", "Alex\nBlair\nCasey\nDrew\nEden\nFrankie\nGale")
    }
    "badminton" => {
      set_value("title", "Badminton night")
      set_value("sport", "badminton-21")
      set_value("format", "single-elimination")
      set_value("entrants", "Aria\nBen\nCleo\nDev\nEmi\nFinn")
    }
    "esports" => {
      set_value("title", "Weekend map cup")
      set_value("sport", "esports")
      set_value("format", "double-elimination")
      set_value(
        "entrants", "Aurora\nBolt\nComet\nDrift\nEcho\nFlux\nGlacier\nHalo",
      )
    }
    _ => {
      set_value("title", "Campus football cup")
      set_value("sport", "football")
      set_value("format", "groups")
      set_value(
        "entrants", "Aurora\nBolt\nComet\nDrift\nEcho\nFlux\nGlacier\nHalo",
      )
    }
  }
  preset_changed()
  format_changed()
  notice(
    "Example filled in. Select Generate competition & schedule when ready.",
  )
}

///|
fn choose_tab(tab : String) -> Unit {
  ui.tab = tab
  selected_tab(tab)
  for panel in ["fixtures", "standings", "schedule", "rules"] {
    hidden("panel-" + panel, panel != tab)
  }
}

///|
fn render() -> Unit {
  render_seasons()
  disabled("export-schedule", ui.schedule_csv == "")
  if ui.schedule_csv == "" {
    text("schedule-unplaced", "")
    html(
      "schedule-rows", "<tr><td colspan=\"4\" class=\"empty\">Plan a schedule for the current fixtures.</td></tr>",
    )
  }
  let t = match current() {
    Some(t) => t
    None => {
      hidden("workspace", true)
      hidden("welcome", false)
      hidden("jump-event", true)
      return
    }
  }
  hidden("workspace", false)
  hidden("welcome", true)
  hidden("jump-event", false)
  text("event-title", t.title)
  text(
    "event-meta",
    @core.sport_name(t.rules.sport) + " / " + @core.format_name(t.format),
  )
  text("count-entrants", t.participants.length().to_string())
  let completed = t.fixtures
    .filter(f => @core.fixture_state(t, f) == @core.Finished)
    .length()
  let ready = t.fixtures
    .filter(f => @core.fixture_state(t, f) == @core.Playable)
    .length()
  text("count-completed", completed.to_string())
  text("count-ready", ready.to_string())
  let playable = t.fixtures
    .filter(f => {
      @core.fixture_state(t, f) != @core.Automatic &&
      @core.fixture_state(t, f) != @core.Inactive
    })
    .length()
  text(
    "progress-label",
    completed.to_string() +
    " of " +
    playable.to_string() +
    " currently generated games completed",
  )
  set_progress(if playable == 0 { 0 } else { completed * 100 / playable })
  text(
    "champion",
    @core.champion(t)
    .map(id => @core.participant_name(t.participants, id))
    .unwrap_or("In progress"),
  )
  let stages : Array[String] = []
  for fixture in t.fixtures {
    if !stages.contains(fixture.stage) {
      stages.push(fixture.stage)
    }
  }
  let old_stage = value("stage-filter")
  html(
    "stage-filter",
    "<option value=\"\">All stages</option>" +
    stages
    .map(stage => {
      "<option value=\"" + escape(stage) + "\">" + escape(stage) + "</option>"
    })
    .join(""),
  )
  if stages.contains(old_stage) {
    set_value("stage-filter", old_stage)
  }
  plan_schedule(announce=false)
  render_fixtures(t)
  render_standings(t)
  render_rules(t)
  disabled(
    "advance-groups",
    (
      t.format != @core.Groups &&
      t.format != @core.GroupsDouble &&
      t.format != @core.SwissPlayoff &&
      t.format != @core.LeaguePlayoff &&
      t.format != @core.LeagueDoublePlayoff
    ) ||
    t.fixtures.any(f => f.stage == "knockout"),
  )
  let mut swiss_latest = 0
  for fixture in t.fixtures {
    if fixture.stage == "swiss" && fixture.round > swiss_latest {
      swiss_latest = fixture.round
    }
  }
  disabled(
    "next-round",
    (t.format != @core.Swiss && t.format != @core.SwissPlayoff) ||
    (t.format == @core.SwissPlayoff && swiss_latest >= t.swiss_rounds),
  )
  disabled("undo", ui.history.unwrap().past.length() == 0)
  disabled("redo", ui.history.unwrap().future.length() == 0)
  let participants = t.participants
    .map(p => {
      "<option value=\"" +
      p.id.to_string() +
      "\">" +
      escape(p.name) +
      (if p.active { "" } else { " (withdrawn)" }) +
      "</option>"
    })
    .join("")
  html("withdraw-id", participants)
  choose_tab(ui.tab)
}

///|
fn render_fixtures(t : @core.Tournament) -> Unit {
  let view = @core.view_to_json(t)
  let scheduled = t.fixtures
    .filter(f => ui.schedule_slots.contains(f.id))
    .length()
  text(
    "fixtures-summary",
    t.fixtures.length().to_string() +
    " fixtures generated · " +
    scheduled.to_string() +
    " given a suggested time. Select Score beside a played match to enter its real result. " +
    (if t.format == @core.Swiss || t.format == @core.SwissPlayoff {
      "Later Swiss pairings depend on earlier results."
    } else if t.format == @core.Groups ||
      t.format == @core.GroupsDouble ||
      t.format == @core.LeaguePlayoff ||
      t.format == @core.LeagueDoublePlayoff {
      "Knockout fixtures are added after qualification is settled."
    } else {
      "All rounds are listed below."
    }),
  )
  let query = value("search").to_lower()
  let stage = value("stage-filter")
  let status = value("status-filter")
  let rows = items(view, "fixtures").filter(row => {
    (stage == "" || label(row, "stage") == stage) &&
    (status == "" || label(row, "state") == status) &&
    (
      query == "" ||
      (label(row, "homeLabel") +
      " " +
      label(row, "awayLabel") +
      " " +
      label(row, "id"))
      .to_lower()
      .contains(query)
    )
  })
  if ui.page * 100 >= rows.length() {
    ui.page = 0
  }
  let out = StringBuilder()
  let mut prior_round = ""
  for i, row in rows {
    if i < ui.page * 100 || i >= (ui.page + 1) * 100 {
      continue
    }
    let id = label(row, "id")
    let round = label(row, "stage") + " / Round " + label(row, "round")
    if round != prior_round {
      out.write_string(
        "<tr class=\"round-divider\"><th colspan=\"7\">" +
        escape(round) +
        "</th></tr>",
      )
      prior_round = round
    }
    let status = label(row, "state")
    let result = get(row, "result")
    let score = if result == Json::null() {
      "—"
    } else {
      label(result, "home") + " : " + label(result, "away")
    }
    let action = if status == "ready" || status == "finished" {
      "<button class=\"small\" data-action=\"edit\" data-id=\"" +
      escape(id) +
      "\">" +
      (if status == "finished" { "Edit" } else { "Score" }) +
      "</button>"
    } else {
      ""
    }
    out.write_string(
      "<tr><td><strong>" +
      escape(id) +
      "</strong><small>" +
      escape(label(row, "stage")) +
      " · R" +
      label(row, "round") +
      "</small></td><td class=\"when\">" +
      escape(ui.schedule_slots.get(id).unwrap_or("Not placed")) +
      "</td><td>" +
      escape(label(row, "homeLabel")) +
      "</td><td class=\"score\">" +
      score +
      "</td><td>" +
      escape(label(row, "awayLabel")) +
      "</td><td><span class=\"pill " +
      status +
      "\">" +
      status +
      "</span></td><td>" +
      action +
      "</td></tr>",
    )
  }
  html(
    "fixture-rows",
    if rows.length() == 0 {
      "<tr><td colspan=\"7\" class=\"empty\">No fixtures match these filters.</td></tr>"
    } else {
      out.to_string()
    },
  )
  text(
    "page-info",
    rows.length().to_string() + " fixtures · page " + (ui.page + 1).to_string(),
  )
  disabled("previous-page", ui.page == 0)
  disabled("next-page", (ui.page + 1) * 100 >= rows.length())
  render_bracket(items(view, "fixtures"))
}

///|
fn render_bracket(rows : Array[Json]) -> Unit {
  let rows = rows.filter(row => {
    ["winners", "losers", "grand-final", "reset", "third-place", "knockout"].contains(
      label(row, "stage"),
    )
  })
  hidden("bracket-section", rows.length() == 0)
  let columns : Array[String] = []
  for row in rows {
    let key = label(row, "stage") + " / R" + label(row, "round")
    if !columns.contains(key) {
      columns.push(key)
    }
  }
  let out = StringBuilder()
  for column in columns {
    out.write_string(
      "<section class=\"bracket-column\"><h3>" + escape(column) + "</h3>",
    )
    for row in rows {
      if label(row, "stage") + " / R" + label(row, "round") != column {
        continue
      }
      let result = get(row, "result")
      let score = if result == Json::null() {
        label(row, "state")
      } else {
        label(result, "home") + " : " + label(result, "away")
      }
      out.write_string(
        "<article class=\"match-card\"><small>" +
        escape(label(row, "id")) +
        "</small><strong>" +
        escape(label(row, "homeLabel")) +
        "</strong><span>" +
        escape(label(row, "awayLabel")) +
        "</span><b>" +
        escape(score) +
        "</b></article>",
      )
    }
    out.write_string("</section>")
  }
  html("bracket-board", out.to_string())
}

///|
fn render_standings(t : @core.Tournament) -> Unit {
  text(
    "standings-note",
    if t.format == @core.SingleElimination ||
      t.format == @core.DoubleElimination {
      "This table summarizes recorded match statistics. The bracket determines advancement and the champion; these table ranks are not final podium positions."
    } else if t.format == @core.LeaguePlayoff ||
      t.format == @core.LeagueDoublePlayoff {
      "The league table determines playoff seeding. Finish every league game, then select Start knockout. Playoff results do not change league ranks."
    } else {
      "Ranking follows the configured criteria. Group tables exclude knockout results."
    },
  )
  let tables = items(@core.view_to_json(t), "tables")
  let out = StringBuilder()
  for table in tables {
    out.write_string(
      "<section class=\"table-block\"><h3>" +
      escape(label(table, "stage", fallback="Competition table")) +
      "</h3><div class=\"table-wrap\"><table><thead><tr><th>Rank</th><th>Entrant</th><th>P</th><th>W</th><th>D</th><th>L</th><th>Pts</th><th>For</th><th>Against</th><th>Byes</th></tr></thead><tbody>",
    )
    for row in items(table, "rows") {
      let reasons = items(row, "reasons")
        .map(item => {
          match item {
            String(s) => s
            _ => ""
          }
        })
        .join(" · ")
      out.write_string(
        "<tr title=\"" +
        escape(reasons) +
        "\"><td>" +
        label(row, "rank") +
        "</td><td><strong>" +
        escape(label(row, "name")) +
        "</strong></td>",
      )
      for
        key in [
          "played", "wins", "draws", "losses", "pointsLabel", "scored", "conceded",
          "byes",
        ] {
        out.write_string("<td>" + label(row, key) + "</td>")
      }
      out.write_string("</tr>")
    }
    out.write_string(
      "</tbody></table></div><p class=\"hint\">Equal ranks remain tied unless an explicit final criterion separates them. Hover a row for ranking values.</p></section>",
    )
  }
  html("standings-tables", out.to_string())
}

///|
fn render_rules(t : @core.Tournament) -> Unit {
  let r = t.rules
  text("rules-title", r.label)
  text("rules-scope", r.scope)
  text("rules-order", r.tie_breaks.map(@core.tie_break_name).join(" → "))
  let out = StringBuilder()
  for
    (label, value) in [
      ("Best of", r.best_of.to_string()),
      ("Game target", r.target.to_string()),
      ("Deciding-game target", r.final_target.to_string()),
      ("Win by", r.win_by.to_string()),
      ("Hard cap", if r.cap == 0 { "None" } else { r.cap.to_string() }),
      (
        "Win / Draw / Loss",
        @core.display_points(r.win_points, r.point_scale) +
        " / " +
        @core.display_points(r.draw_points, r.point_scale) +
        " / " +
        @core.display_points(r.loss_points, r.point_scale),
      ),
    ] {
    out.write_string("<div><dt>" + label + "</dt><dd>" + value + "</dd></div>")
  }
  html("rules-values", out.to_string())
  html(
    "rules-source",
    if r.source == "" {
      "Organizer-defined rules."
    } else {
      "<a href=\"" +
      escape(r.source) +
      "\" target=\"_blank\" rel=\"noopener noreferrer\">Read the rule source ↗</a>"
    },
  )
}

///|
fn edit_result(id : String) -> Unit {
  let t = match current() {
    Some(t) => t
    None => return
  }
  let views = items(@core.view_to_json(t), "fixtures")
  for row in views {
    if label(row, "id") != id {
      continue
    }
    ui.editor = id
    notice("")
    text(
      "result-help",
      if t.rules.sport == @core.Chess {
        "Chess: enter 1-0 for a home win, 0-1 for an away win, or 1-1 for a draw."
      } else if @core.uses_sets(t.rules.sport) {
        "Enter each completed set in playing order. Opening-set target: " +
        t.rules.target.to_string() +
        "; deciding-set target: " +
        t.rules.final_target.to_string() +
        "."
      } else if t.rules.sport == @core.Basketball {
        "Enter the final score including overtime; a tie is not a completed basketball game."
      } else if t.rules.sport == @core.OpenScore {
        "Enter the final score. League draws are allowed; a tied knockout needs an explicit tiebreak winner."
      } else {
        "Enter the final goal score. A tied knockout needs a separate shootout winner."
      },
    )
    text(
      "result-title",
      label(row, "homeLabel") + " vs " + label(row, "awayLabel"),
    )
    text("result-fixture", id + " · " + t.rules.label)
    let result = get(row, "result")
    set_value("home-score", label(result, "home", fallback="0"))
    set_value("away-score", label(result, "away", fallback="0"))
    set_value("decider", label(result, "decider"))
    let games = items(result, "sets")
      .map(game => label(game, "home") + "-" + label(game, "away"))
      .join(", ")
    set_value("set-scores", games)
    hidden("score-inputs", @core.uses_sets(t.rules.sport))
    hidden("set-inputs", !@core.uses_sets(t.rules.sport))
    let stage = label(row, "stage")
    let decisive = stage == "knockout" ||
      stage == "winners" ||
      stage == "losers" ||
      stage == "third-place" ||
      stage == "grand-final" ||
      stage == "reset"
    hidden(
      "decider-input",
      !decisive ||
      (t.rules.sport != @core.Football && t.rules.sport != @core.OpenScore),
    )
    disabled("clear-result", result == Json::null())
    open_dialog()
    return
  }
}

///|
fn save_result() -> Unit {
  let t = match current() {
    Some(t) => t
    None => return
  }
  let mut result : Json = Json::null()
  if @core.uses_sets(t.rules.sport) {
    let games : Array[Json] = []
    for raw in value("set-scores").split(",") {
      let pair = raw.trim().split("-").to_array()
      if pair.length() != 2 {
        notice("Enter set scores like 21-18, 19-21, 21-15.")
        return
      }
      let a = @string.parse_int(pair[0].trim().to_owned()) catch {
        _ => {
          notice("Invalid set score.")
          return
        }
      }
      let b = @string.parse_int(pair[1].trim().to_owned()) catch {
        _ => {
          notice("Invalid set score.")
          return
        }
      }
      games.push({ "home": a, "away": b })
    }
    result = { "fixtureId": ui.editor, "sets": games }
  } else {
    let a = integer("home-score")
    let b = integer("away-score")
    if a == None || b == None {
      return
    }
    let decider : Json = if value("decider") == "" {
      Json::null()
    } else {
      let side = integer("decider")
      if side == None {
        return
      }
      side.unwrap().to_json()
    }
    result = {
      "fixtureId": ui.editor,
      "home": a.unwrap(),
      "away": b.unwrap(),
      "decider": decider,
    }
  }
  if call({
      "action": "record",
      "tournament": @core.tournament_to_json(t),
      "result": result,
    }) !=
    None {
    close_dialog()
    advance_completed_stage()
  }
}

///|
fn advance_completed_stage() -> Unit {
  let t = match current() {
    Some(t) => t
    None => return
  }
  if t.format == @core.SwissPlayoff {
    if t.fixtures.any(f => f.stage == "knockout") {
      return
    }
    let mut latest = 0
    for fixture in t.fixtures {
      if fixture.stage == "swiss" && fixture.round > latest {
        latest = fixture.round
      }
    }
    if latest == 0 ||
      t.fixtures.any(f => {
        f.stage == "swiss" &&
        f.round == latest &&
        @core.fixture_state(t, f) != @core.Finished &&
        @core.fixture_state(t, f) != @core.Automatic
      }) {
      return
    }
    ignore(
      call({
        "action": if latest >= t.swiss_rounds {
          "advance"
        } else {
          "next-round"
        },
        "tournament": @core.tournament_to_json(t),
      }),
    )
    return
  }
  let groups = t.format == @core.Groups || t.format == @core.GroupsDouble
  if !groups &&
    t.format != @core.LeaguePlayoff &&
    t.format != @core.LeagueDoublePlayoff {
    return
  }
  if t.fixtures.any(f => f.stage == "knockout") ||
    t.fixtures.any(f => {
      (if groups { f.stage.has_prefix("group-") } else { f.stage == "league" }) &&
      @core.fixture_state(t, f) != @core.Finished &&
      @core.fixture_state(t, f) != @core.Automatic
    }) {
    return
  }
  ignore(
    call({ "action": "advance", "tournament": @core.tournament_to_json(t) }),
  )
}

///|
fn action(name : String, id : String) -> Unit {
  if name == "open-season" {
    open_saved_season(id)
    return
  }
  if name == "remove-season" {
    remove_saved_season(id)
    return
  }
  if name == "tab" {
    choose_tab(id)
    return
  }
  if name == "sample" {
    sample(id)
    return
  }
  if name == "edit" {
    edit_result(id)
    return
  }
  let t = match current() {
    Some(t) => t
    None => return
  }
  match name {
    "advance" | "next-round" =>
      ignore(
        call({
          "action": if name == "advance" {
            "advance"
          } else {
            "next-round"
          },
          "tournament": @core.tournament_to_json(t),
        }),
      )
    "clear" =>
      if call({
          "action": "clear",
          "tournament": @core.tournament_to_json(t),
          "fixtureId": ui.editor,
        }) !=
        None {
        close_dialog()
        advance_completed_stage()
      }
    "forfeit" => {
      let side = @string.parse_int(id) catch { _ => return }
      if call({
          "action": "record",
          "tournament": @core.tournament_to_json(t),
          "result": {
            "fixtureId": ui.editor,
            "kind": "forfeit",
            "winnerSide": side,
          },
        }) !=
        None {
        close_dialog()
      }
    }
    "export" => {
      let data = call(
        {
          "action": "export",
          "tournament": @core.tournament_to_json(t),
          "kind": id,
        },
        change=false,
      )
      match data {
        Some(data) =>
          preview_export(
            "moontourney-" +
            id +
            (if id == "json" {
              ".json"
            } else if id == "report" {
              ".md"
            } else {
              ".csv"
            }),
            label(data, "content"),
            if id == "json" {
              "application/json;charset=utf-8"
            } else if id == "report" {
              "text/markdown;charset=utf-8"
            } else {
              "text/csv;charset=utf-8"
            },
          )
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn time_offset(id : String) -> Int? {
  let parts = value(id).split(":").to_array()
  if parts.length() != 2 {
    notice("Enter a valid time for " + id + ".")
    return None
  }
  let hours = @string.parse_int(parts[0].to_owned()) catch {
    _ => {
      notice("Invalid time.")
      return None
    }
  }
  let minutes = @string.parse_int(parts[1].to_owned()) catch {
    _ => {
      notice("Invalid time.")
      return None
    }
  }
  if hours < 0 || hours > 23 || minutes < 0 || minutes > 59 {
    notice("Enter a valid time.")
    return None
  }
  Some(hours * 60 + minutes)
}

///|
fn schedule_stamp(start : Int) -> String {
  let h = start / 60 % 24
  let m = start % 60
  "Day " +
  (start / 1440 + 1).to_string() +
  " · " +
  (if h < 10 { "0" } else { "" }) +
  h.to_string() +
  ":" +
  (if m < 10 { "0" } else { "" }) +
  m.to_string()
}

///|
fn plan_schedule(announce? : Bool = true) -> Unit {
  let t = match current() {
    Some(t) => t
    None => return
  }
  let courts = integer("courts")
  let duration = integer("duration")
  let rest = integer("rest")
  let start = time_offset("start-time")
  let end = time_offset("finish-time")
  let days = integer("planning-days")
  if courts == None ||
    duration == None ||
    rest == None ||
    start == None ||
    end == None ||
    days == None {
    return
  }
  if days.unwrap() < 1 || days.unwrap() > 365 {
    notice("Use 1 to 365 planning days.")
    return
  }
  if end.unwrap() <= start.unwrap() ||
    duration.unwrap() > end.unwrap() - start.unwrap() {
    notice("The game duration must fit between each day's start and finish.")
    return
  }
  ui.schedule_slots = Map([])
  let data = call(
    {
      "action": "schedule",
      "tournament": @core.tournament_to_json(t),
      "courts": courts.unwrap(),
      "duration": duration.unwrap(),
      "rest": rest.unwrap(),
      "start": start.unwrap(),
      "horizon": (days.unwrap() - 1) * 1440 + end.unwrap(),
      "dayStart": start.unwrap(),
      "dayEnd": end.unwrap(),
    },
    change=false,
  )
  match data {
    Some(data) => {
      let out = StringBuilder()
      let by_id : Map[String, Json] = Map([])
      for row in items(@core.view_to_json(t), "fixtures") {
        by_id[label(row, "id")] = row
      }
      let allocations = items(data, "allocations")
      for i, item in allocations {
        let id = label(item, "fixtureId")
        let time = @string.parse_int(label(item, "start")) catch { _ => 0 }
        let stamp = schedule_stamp(time)
        ui.schedule_slots[id] = stamp + " / Court " + label(item, "court")
        if i >= 500 {
          continue
        }
        let row = by_id.get(id).unwrap_or(Json::null())
        let status = label(row, "state")
        let result = get(row, "result")
        let score = if result == Json::null() {
          "—"
        } else {
          label(result, "home") + " : " + label(result, "away")
        }
        let action = if status == "ready" || status == "finished" {
          " <button class=\"small\" data-action=\"edit\" data-id=\"" +
          escape(id) +
          "\">" +
          (if status == "finished" { "Edit" } else { "Score" }) +
          "</button>"
        } else {
          ""
        }
        out.write_string(
          "<tr><td><strong>" +
          escape(id) +
          "</strong><small>" +
          escape(label(row, "stage")) +
          " · Round " +
          label(row, "round") +
          "</small></td><td>" +
          escape(label(row, "homeLabel")) +
          " vs " +
          escape(label(row, "awayLabel")) +
          "</td><td>Court " +
          label(item, "court") +
          "</td><td>" +
          stamp +
          "</td><td class=\"score\">" +
          score +
          action +
          "</td></tr>",
        )
      }
      html(
        "schedule-rows",
        if allocations.length() == 0 {
          "<tr><td colspan=\"5\" class=\"empty\">No games fit this planning window.</td></tr>"
        } else {
          out.to_string()
        },
      )
      ui.schedule_csv = label(data, "csv")
      disabled("export-schedule", allocations.length() == 0)
      text(
        "schedule-summary",
        allocations.length().to_string() +
        " games assigned across " +
        days.unwrap().to_string() +
        " available days. " +
        (if allocations.length() > 500 {
          "Showing the first 500 here; CSV includes every assigned game."
        } else {
          "Select Score after a game is played."
        }),
      )
      let unplaced = items(data, "unscheduled").map(item => {
        match item {
          String(s) => s
          _ => ""
        }
      })
      text(
        "schedule-unplaced",
        if unplaced.length() == 0 {
          "All games fit within the planning window."
        } else {
          unplaced.length().to_string() +
          " games do not fit: " +
          unplaced.join(", ") +
          ". Add courts or planning days. The CSV contains the placed games only."
        },
      )
      if announce {
        notice(
          if unplaced.length() == 0 {
            "Suggested timetable updated with participant rest and daily playing hours."
          } else {
            "Partial timetable: " +
            unplaced.length().to_string() +
            " games remain unplaced. Add courts or planning days."
          },
        )
      }
    }
    None => ()
  }
}

///|
fn restore_history(back : Bool) -> Unit {
  match ui.history {
    Some(history) => {
      let restored = if back {
        @core.undo(history)
      } else {
        @core.redo(history)
      }
      ui.history = Some(restored)
      ui.schedule_csv = ""
      persist_current(restored.current)
      notice(if back { "Last change undone." } else { "Change restored." })
      render()
    }
    None => ()
  }
}

///|
fn main {
  delegate("app", action)
  delegate("result-dialog", action)
  bind("add-season", "click", add_current_season)
  bind("clone-season", "click", clone_current_season)
  bind("update-roster", "click", update_current_roster)
  bind("rename-series", "click", () => {
    let series = match ui.seasons {
      Some(series) => series
      None => return
    }
    let renamed = @core.rename_season_series(series, value("series-title")) catch {
      error => {
        notice(@core.error_message(error))
        return
      }
    }
    ui.seasons = Some(renamed)
    if persist_seasons() {
      notice("Series title updated.")
    }
    render_seasons()
  })
  bind("export-seasons", "click", () => export_seasons("json"))
  bind("export-season-summary", "click", () => export_seasons("seasons"))
  bind("export-season-history", "click", () => export_seasons("history"))
  bind("setup-form", "submit", create_event)
  bind("sport", "change", preset_changed)
  bind("format", "change", format_changed)
  bind("search", "input", () => {
    ui.page = 0
    match current() {
      Some(t) => render_fixtures(t)
      None => ()
    }
  })
  for id in ["stage-filter", "status-filter"] {
    bind(id, "change", () => {
      ui.page = 0
      match current() {
        Some(t) => render_fixtures(t)
        None => ()
      }
    })
  }
  bind("previous-page", "click", () => {
    ui.page = ui.page - 1
    match current() {
      Some(t) => render_fixtures(t)
      None => ()
    }
  })
  bind("next-page", "click", () => {
    ui.page = ui.page + 1
    match current() {
      Some(t) => render_fixtures(t)
      None => ()
    }
  })
  bind("result-form", "submit", save_result)
  bind("cancel-result", "click", close_dialog)
  bind("undo", "click", () => restore_history(true))
  bind("redo", "click", () => restore_history(false))
  bind("plan-schedule", "click", () => {
    plan_schedule()
    match current() {
      Some(t) => render_fixtures(t)
      None => ()
    }
  })
  bind("export-schedule", "click", () => {
    preview_export(
      "moontourney-schedule.csv",
      ui.schedule_csv,
      "text/csv;charset=utf-8",
    )
  })
  bind("cancel-export", "click", close_export)
  bind("download-export", "click", () => {
    download(ui.export_name, ui.export_content, ui.export_mime)
    notice(
      "Download requested. If your browser does not support downloads, copy the text or select it in the preview.",
    )
  })
  bind("copy-export", "click", () => {
    copy_text(ui.export_content, ok => {
      notice(
        if ok {
          "Copied to clipboard."
        } else {
          "Clipboard is unavailable. Select the preview text and copy it manually."
        },
      )
    })
  })
  bind("print", "click", print_page)
  bind("withdraw", "click", () => {
    let t = match current() {
      Some(t) => t
      None => return
    }
    let id = integer("withdraw-id")
    if id == None {
      return
    }
    ignore(
      call({
        "action": "withdraw",
        "tournament": @core.tournament_to_json(t),
        "participantId": id.unwrap(),
        "active": false,
      }),
    )
  })
  bind("import-file", "change", () => {
    load_file((ok, source) => {
      if !ok {
        notice(source)
        return
      }
      let document = @json.parse(source) catch {
        _ => {
          notice("Import file is not valid JSON.")
          return
        }
      }
      if get(document, "seasonSeriesVersion") != Json::null() {
        let series = @core.season_series_from_json(document) catch {
          error => {
            notice(@core.error_message(error))
            return
          }
        }
        if ui.seasons != None &&
          !confirm_change(
            "Replace the saved season collection with this import? Export the current collection first if you need it.",
          ) {
          return
        }
        ui.seasons = Some(series)
        ui.active_season = ""
        if persist_seasons() {
          notice(
            "Season collection imported. Select Open beside a season to work on it.",
          )
        }
        render_seasons()
      } else {
        ignore(
          call({ "action": "inspect", "tournament": document }, fresh=true),
        )
      }
    })
  })
  preset_changed()
  format_changed()
  let saved_seasons = get_season_storage()
  if saved_seasons != "" {
    let document = @json.parse(saved_seasons) catch { _ => Json::null() }
    if document != Json::null() {
      let series : @core.SeasonSeries? = Some(
        @core.season_series_from_json(document),
      ) catch {
        _ => None
      }
      match series {
        Some(collection) => {
          ui.seasons = Some(collection)
          let active = get_active_season_storage()
          if collection.seasons.any(season => season.key == active) {
            ui.active_season = active
          }
        }
        None =>
          notice(
            "Saved season collection could not be restored; import a JSON backup.",
          )
      }
    }
  }
  if ui.active_season != "" {
    match ui.seasons {
      Some(series) =>
        for season in series.seasons {
          if season.key == ui.active_season {
            save(season.tournament, fresh=true)
            return
          }
        }
      None => ()
    }
  }
  let stored = get_storage()
  if stored != "" {
    let document = @json.parse(stored) catch { _ => Json::null() }
    if document != Json::null() {
      ignore(call({ "action": "inspect", "tournament": document }, fresh=true))
    }
  }
  render()
}
