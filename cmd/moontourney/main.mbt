///|
fn lookup(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn text_lookup(value : Json, key : String) -> String {
  match lookup(value, key) {
    String(s) => s
    _ => ""
  }
}

///|
fn load(path : String) -> Json? {
  let envelope = @json.parse(read_file(path)) catch {
    _ => {
      fail("Invalid file response.")
      return None
    }
  }
  if lookup(envelope, "ok") != (true : Json) {
    fail(text_lookup(envelope, "error"))
    return None
  }
  let doc = @json.parse(text_lookup(envelope, "content")) catch {
    _ => {
      fail("Invalid JSON in " + path)
      return None
    }
  }
  Some(doc)
}

///|
fn output(content : String, path : String?) -> Unit {
  match path {
    None => println(content)
    Some(path) => {
      let envelope = @json.parse(write_file(path, content + "\n")) catch {
        _ => {
          fail("Invalid write response.")
          return
        }
      }
      if lookup(envelope, "ok") == (true : Json) {
        println("Saved " + path)
      } else {
        fail(text_lookup(envelope, "error"))
      }
    }
  }
}

///|
fn help() -> Unit {
  println("MoonTourney 0.1 — portable competition desk")
  println("Usage: node dist/moontourney.mjs <command> [arguments]")
  println("  presets                              List scoring profiles")
  println("  create <config.json> [new.json]       Generate a competition")
  println("  inspect <event.json>                  Explain fixtures and tables")
  println("  record <event.json> <result.json> [new.json]")
  println("  clear <event.json> <fixture-id> [new.json]")
  println(
    "  roster <event.json> <names.json> [new.json]  Rebuild an unscored field",
  )
  println(
    "  advance <event.json> [new.json]        Start group, league or Swiss knockout",
  )
  println(
    "  next-round <event.json> [new.json]     Pair the next Club Swiss round",
  )
  println("  withdraw <event.json> <entrant-id> [new.json]")
  println("  schedule <event.json> <settings.json> [new.csv]")
  println(
    "  export <event.json> <kind> [new.file]  json / fixtures-csv / standings-csv / report",
  )
  println(
    "  request <request.json> [new.json]     Full JSON API, including series",
  )
  println(
    "  season-new <title> [new.json]         Create an empty season archive",
  )
  println("  season-add <series.json> <event.json> <label> [new.json]")
  println(
    "  season-list <series.json>             Show seasons and participant history",
  )
  println("  season-extract <series.json> <key> [event.json]")
  println("  season-clone <series.json> <source-key> <label> [new.json]")
  println("  season-update <series.json> <key> <event.json> [new.json]")
  println("  season-remove <series.json> <key> [new.json]")
  println("  season-rename <series.json> <title> [new.json]")
  println(
    "  season-export <series.json> <json|seasons-csv|history-csv> [new.file]",
  )
  println(
    "All outputs use stdout unless a new file path is given. Existing files are never overwritten.",
  )
}

///|
fn run(args : Array[String]) -> Unit {
  if args.length() == 0 || args[0] == "help" || args[0] == "--help" {
    help()
    return
  }
  let command = args[0]
  let mut request : Json = Json::null()
  let mut path : String? = None
  let mut mode = "view"
  if command == "presets" {
    if args.length() != 1 {
      fail("presets accepts no arguments.")
      return
    }
    request = { "action": "presets" }
  } else if command == "season-new" {
    if args.length() < 2 || args.length() > 3 {
      fail("Expected a series title and optional new output path.")
      return
    }
    request = { "action": "season-new", "title": args[1] }
    mode = "collection"
    if args.length() == 3 {
      path = Some(args[2])
    }
  } else if command.has_prefix("season-") {
    let required = match command {
      "season-list" => 2
      "season-add" | "season-clone" | "season-update" => 4
      "season-extract" | "season-remove" | "season-rename" | "season-export" =>
        3
      _ => {
        fail("Unknown season command: " + command)
        return
      }
    }
    if args.length() < required ||
      args.length() > required + (if command == "season-list" { 0 } else { 1 }) {
      fail("Wrong number of season arguments. Run help for usage.")
      return
    }
    let collection = match load(args[1]) {
      Some(doc) => doc
      None => return
    }
    let fields : Map[String, Json] = Map([])
    fields["action"] = (if command == "season-list" {
      "season-inspect"
    } else {
      command
    }).to_json()
    fields["collection"] = collection
    if args.length() > required {
      path = Some(args[required])
    }
    match command {
      "season-add" => {
        let event = match load(args[2]) {
          Some(doc) => doc
          None => return
        }
        fields["tournament"] = event
        fields["label"] = args[3].to_json()
        mode = "collection"
      }
      "season-clone" => {
        fields["sourceKey"] = args[2].to_json()
        fields["label"] = args[3].to_json()
        mode = "collection"
      }
      "season-update" => {
        let event = match load(args[3]) {
          Some(doc) => doc
          None => return
        }
        fields["key"] = args[2].to_json()
        fields["tournament"] = event
        mode = "collection"
      }
      "season-extract" => {
        fields["key"] = args[2].to_json()
        mode = "event"
      }
      "season-remove" => {
        fields["key"] = args[2].to_json()
        mode = "collection"
      }
      "season-rename" => {
        fields["title"] = args[2].to_json()
        mode = "collection"
      }
      "season-export" => {
        fields["kind"] = args[2].to_json()
        mode = "content"
      }
      _ => ()
    }
    request = Json::object(fields)
  } else if command == "request" || command == "create" {
    if args.length() < 2 || args.length() > 3 {
      fail("Expected an input JSON and optional new output path.")
      return
    }
    let doc = match load(args[1]) {
      Some(doc) => doc
      None => return
    }
    if args.length() == 3 {
      path = Some(args[2])
    }
    if command == "request" {
      request = doc
      mode = "envelope"
    } else {
      match doc {
        Object(fields) => {
          let changed = fields.copy()
          changed["action"] = "create"
          request = Json::object(changed)
        }
        _ => {
          fail("Configuration must be an object.")
          return
        }
      }
      mode = "event"
    }
  } else {
    let needs_parameter = [
      "record", "clear", "roster", "withdraw", "schedule", "export",
    ].contains(command)
    let mutating = [
      "record", "clear", "roster", "withdraw", "advance", "next-round",
    ].contains(command)
    if !needs_parameter &&
      !["inspect", "advance", "next-round"].contains(command) {
      fail("Unknown command: " + command)
      help()
      return
    }
    let required = if needs_parameter { 3 } else { 2 }
    if args.length() < required ||
      args.length() > required + (if command == "inspect" { 0 } else { 1 }) {
      fail("Wrong number of arguments. Run help for usage.")
      return
    }
    let event = match load(args[1]) {
      Some(doc) => doc
      None => return
    }
    let fields : Map[String, Json] = Map([])
    fields["action"] = command.to_json()
    fields["tournament"] = event
    if args.length() > required {
      path = Some(args[required])
    }
    if mutating {
      mode = "event"
    }
    match command {
      "record" => {
        let result = match load(args[2]) {
          Some(doc) => doc
          None => return
        }
        fields["result"] = result
      }
      "clear" => fields["fixtureId"] = args[2].to_json()
      "roster" => {
        let names = match load(args[2]) {
          Some(doc) => doc
          None => return
        }
        fields["names"] = names
      }
      "withdraw" => {
        let id = @string.parse_int(args[2]) catch {
          _ => {
            fail("Entrant ID must be an integer.")
            return
          }
        }
        fields["participantId"] = id.to_json()
      }
      "schedule" => {
        let settings = match load(args[2]) {
          Some(doc) => doc
          None => return
        }
        for
          key in [
            "courts", "duration", "rest", "start", "horizon", "dayStart", "dayEnd",
          ] {
          if lookup(settings, key) != Json::null() {
            fields[key] = lookup(settings, key)
          }
        }
        mode = "csv"
      }
      "export" => {
        fields["kind"] = args[2].to_json()
        mode = "content"
      }
      _ => ()
    }
    request = Json::object(fields)
  }
  let envelope = @json.parse(@core.dispatch_json(request.stringify())) catch {
    _ => {
      fail("Invalid engine response.")
      return
    }
  }
  if lookup(envelope, "ok") != (true : Json) {
    fail(text_lookup(envelope, "error"))
    return
  }
  let data = lookup(envelope, "data")
  let content = match mode {
    "envelope" => envelope.stringify()
    "event" => lookup(data, "tournament").stringify()
    "collection" => lookup(data, "collection").stringify()
    "content" => text_lookup(data, "content")
    "csv" => {
      match lookup(data, "unscheduled") {
        Array(rows) =>
          if rows.length() > 0 {
            fail(
              "Some fixtures do not fit the scheduling horizon; use request for partial output.",
            )
            return
          }
        _ => ()
      }
      text_lookup(data, "csv")
    }
    _ => data.stringify()
  }
  output(content, path)
}

///|
fn main {
  let raw = @env.args()
  let args : Array[String] = []
  for i, arg in raw {
    if i >= 2 {
      args.push(arg)
    }
  }
  run(args)
}
