///|
/// Statistics loaded from a prior Tokei JSON report.
pub(all) struct Snapshot {
  counts : Map[String, @counter.Counts]
  files : Array[(String, String, @counter.Counts)]
}

///|
fn field(value : Json, key : String) -> Json? {
  match value {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn integer_field(value : Json, key : String) -> Int32? {
  match field(value, key) {
    Some(Number(n, ..)) if n >= 0.0 && n <= 2147483647.0 => Some(n.to_int())
    _ => None
  }
}

///|
fn string_field(value : Json, key : String) -> String? {
  match field(value, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn language_key(label : String) -> String {
  for lang in @lang.all_languages() {
    if lang.name == label || lang.key == label {
      return lang.key
    }
  }
  label
}

///|
fn parse_stats(value : Json) -> @counter.Counts? {
  let code = integer_field(value, "code")
  let comments = integer_field(value, "comments")
  let blanks = integer_field(value, "blanks")
  match (code, comments, blanks) {
    (Some(code), Some(comments), Some(blanks)) => {
      let counts = @counter.Counts::new()
      counts.files = 1
      counts.code = code
      counts.comments = comments
      counts.blanks = blanks
      counts.lines = code + comments + blanks
      match field(value, "blobs") {
        Some(Object(blobs)) =>
          for blob in blobs {
            match parse_stats(blob.1) {
              Some(child) => counts.blobs.set(language_key(blob.0), child)
              None => return None
            }
          }
        Some(_) => return None
        None => ()
      }
      Some(counts)
    }
    _ => None
  }
}

///|
/// Read the JSON shape emitted by official Tokei or this port. The Total
/// entry is derived again after merging, so it is deliberately not imported.
pub fn parse(source : String) -> Snapshot? {
  let document = @json.parse(source) catch { _ => return None }
  let items = match document {
    Object(items) => items
    _ => return None
  }
  let snapshot : Snapshot = { counts: Map([]), files: [], }
  for item in items {
    if item.0 == "Total" {
      continue
    }
    let key = language_key(item.0)
    let code = integer_field(item.1, "code")
    let comments = integer_field(item.1, "comments")
    let blanks = integer_field(item.1, "blanks")
    let reports = field(item.1, "reports")
    match (code, comments, blanks, reports) {
      (Some(code), Some(comments), Some(blanks), Some(Array(reports))) => {
        let counts = @counter.Counts::new()
        counts.code = code
        counts.comments = comments
        counts.blanks = blanks
        counts.lines = code + comments + blanks
        counts.files = reports.length()
        for report in reports {
          let name = string_field(report, "name")
          let stats = field(report, "stats")
          match (name, stats) {
            (Some(name), Some(stats)) =>
              match parse_stats(stats) {
                Some(file_counts) => {
                  snapshot.files.push((name, key, file_counts))
                  for blob in file_counts.blobs {
                    match counts.blobs.get(blob.0) {
                      Some(existing) => existing.add(blob.1)
                      None => counts.blobs.set(blob.0, blob.1.copy())
                    }
                  }
                }
                None => return None
              }
            _ => return None
          }
        }
        snapshot.counts.set(key, counts)
      }
      _ => return None
    }
  }
  Some(snapshot)
}
