///|
/// Supported output formats.
pub(all) enum Format {
  Table
  Json
  Csv
  Yaml
}

///|
fn pad_right(s : String, width : Int32) -> String {
  let n = s.length()
  if n >= width {
    s
  } else {
    let buf = StringBuilder()
    buf.write_string(s)
    let mut i = n
    while i < width {
      buf.write_char(' ')
      i += 1
    }
    buf.to_string()
  }
}

///|
fn pad_left(s : String, width : Int32) -> String {
  let n = s.length()
  if n >= width {
    s
  } else {
    let buf = StringBuilder()
    let mut i = n
    while i < width {
      buf.write_char(' ')
      i += 1
    }
    buf.write_string(s)
    buf.to_string()
  }
}

///|
fn repeat(ch : Char, n : Int32) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < n {
    buf.write_char(ch)
    i += 1
  }
  buf.to_string()
}

///|
const LINE_WIDTH = 79

///|
/// Render the tokei-style table:
/// ===============================================================================
///  Language            Files        Lines         Code     Comments       Blanks
/// ===============================================================================
///  C++                     5         2250         1650          300          300
/// -------------------------------------------------------------------------------
///  Total                   5         2250         1650          300          300
/// ===============================================================================
pub fn render_table(r : @report.Report) -> String {
  render_table_with_options(r, LINE_WIDTH, "plain")
}

///|
/// Match upstream's 79-column minimum; wider tables expand the language cell.
pub fn render_table_with_options(
  r : @report.Report,
  columns : Int32,
  num_format : String,
) -> String {
  render_table_with_files(r, [], columns, num_format, false)
}

///|
/// Show child-language counts beneath each container language, as Tokei does.
pub fn render_table_with_files(
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
  columns : Int32,
  num_format : String,
  compact : Bool,
) -> String {
  let buf = StringBuilder()
  let table_width = if columns > LINE_WIDTH { columns } else { LINE_WIDTH }
  let name_width = table_width - 60
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  buf.write_string(pad_right(" Language", name_width))
  buf.write_string(pad_left("Files", 7))
  buf.write_string(pad_left("Lines", 13))
  buf.write_string(pad_left("Code", 13))
  buf.write_string(pad_left("Comments", 13))
  buf.write_string(pad_left("Blanks", 13))
  buf.write_char('\n')
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  for s in r.langs {
    write_table_row_width(
      buf,
      s.name,
      s.files,
      s.lines,
      s.code,
      s.comments,
      s.blanks,
      name_width,
      num_format,
    )
    if !compact {
      write_child_table_rows(buf, s, files, name_width, num_format)
    }
  }
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  let t = r.total
  write_table_row_width(
    buf,
    t.name,
    t.files,
    t.lines,
    t.code,
    t.comments,
    t.blanks,
    name_width,
    num_format,
  )
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  buf.to_string()
}

///|
fn write_child_table_rows(
  buf : StringBuilder,
  parent : @report.LangStat,
  files : Array[(String, String, @counter.Counts)],
  name_width : Int32,
  num_format : String,
) -> Unit {
  let children : Map[String, @counter.Counts] = Map([])
  for entry in files {
    if entry.1 == parent.key {
      for child in entry.2.blobs {
        match children.get(child.0) {
          Some(existing) => existing.add(child.1)
          None => children.set(child.0, child.1.copy())
        }
      }
    }
  }
  if children.is_empty() {
    return
  }
  let keys : Array[String] = []
  for child in children {
    keys.push(child.0)
  }
  keys.sort_by(fn(a, b) { child_name(a).lexical_compare(child_name(b)) })
  let sum = @counter.Counts::new()
  sum.lines = parent.lines
  sum.code = parent.code
  sum.comments = parent.comments
  sum.blanks = parent.blanks
  for key in keys {
    match children.get(key) {
      Some(child) => {
        write_table_row_width(
          buf,
          "|- " + child_name(key),
          child.files,
          child.lines,
          child.code,
          child.comments,
          child.blanks,
          name_width,
          num_format,
        )
        sum.add(child)
      }
      None => ()
    }
  }
  buf.write_string(pad_right(" (Total)", name_width))
  buf.write_string(repeat(' ', 7))
  buf.write_string(pad_left(format_number(sum.lines, num_format), 13))
  buf.write_string(pad_left(format_number(sum.code, num_format), 13))
  buf.write_string(pad_left(format_number(sum.comments, num_format), 13))
  buf.write_string(pad_left(format_number(sum.blanks, num_format), 13))
  buf.write_char('\n')
}

///|
fn write_table_row_width(
  buf : StringBuilder,
  name : String,
  files : Int32,
  lines : Int32,
  code : Int32,
  comments : Int32,
  blanks : Int32,
  width : Int32,
  num_format : String,
) -> Unit {
  buf.write_string(pad_right(" " + name, width))
  buf.write_string(pad_left(format_number(files, num_format), 7))
  buf.write_string(pad_left(format_number(lines, num_format), 13))
  buf.write_string(pad_left(format_number(code, num_format), 13))
  buf.write_string(pad_left(format_number(comments, num_format), 13))
  buf.write_string(pad_left(format_number(blanks, num_format), 13))
  buf.write_char('\n')
}

///|
fn format_number(value : Int32, style : String) -> String {
  let separator = match style {
    "commas" => ","
    "dots" => "."
    "underscores" => "_"
    _ => return value.to_string()
  }
  let digits = value.to_string()
  let out = StringBuilder()
  for i = 0; i < digits.length(); i = i + 1 {
    if i > 0 && (digits.length() - i) % 3 == 0 {
      out.write_string(separator)
    }
    out.write_char(Int32::unsafe_to_char(digits.at(i).to_int()))
  }
  out.to_string()
}

///|
/// JSON follows Tokei's serialized Language / Report / CodeStats model.
/// Derived file and line totals belong in the table, not in this format.
pub fn render_json(
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
) -> String {
  let buf = StringBuilder()
  buf.write_char('{')
  let mut first = true
  for s in r.langs {
    write_json_obj(buf, s.name, s, files, !first)
    first = false
  }
  if !first {
    buf.write_char(',')
  }
  write_json_total(buf, r, files)
  buf.write_char('}')
  buf.to_string()
}

///|
fn write_json_obj(
  buf : StringBuilder,
  name : String,
  s : @report.LangStat,
  files : Array[(String, String, @counter.Counts)],
  comma_before : Bool,
) -> Unit {
  if comma_before {
    buf.write_char(',')
  }
  buf.write_string(json_escape(name))
  buf.write_string(":{\"blanks\":")
  buf.write_string(s.blanks.to_string())
  buf.write_string(",\"comments\":")
  buf.write_string(s.comments.to_string())
  buf.write_string(",\"code\":")
  buf.write_string(s.code.to_string())
  buf.write_string(",\"reports\":[")
  write_json_reports(buf, s.key, files)
  buf.write_string("],\"children\":{")
  write_json_child_reports(buf, s.key, files)
  buf.write_string("},\"inaccurate\":false")
  buf.write_string("}")
}

///|
fn child_keys(
  key : String,
  files : Array[(String, String, @counter.Counts)],
) -> Array[String] {
  let keys : Array[String] = []
  for entry in files {
    if entry.1 == key {
      for kv in entry.2.blobs {
        if !keys.contains(kv.0) {
          keys.push(kv.0)
        }
      }
    }
  }
  keys.sort()
  keys
}

///|
fn child_name(key : String) -> String {
  match @lang.by_key(key) {
    Some(lang) => lang.name
    None => key
  }
}

///|
fn write_json_stats(buf : StringBuilder, counts : @counter.Counts) -> Unit {
  buf.write_string("{\"blanks\":")
  buf.write_string(counts.blanks.to_string())
  buf.write_string(",\"code\":")
  buf.write_string(counts.code.to_string())
  buf.write_string(",\"comments\":")
  buf.write_string(counts.comments.to_string())
  buf.write_string(",\"blobs\":{")
  let keys : Array[String] = []
  for kv in counts.blobs {
    keys.push(kv.0)
  }
  keys.sort()
  for i, key in keys {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string(json_escape(child_name(key)))
    buf.write_char(':')
    match counts.blobs.get(key) {
      Some(child) => write_json_stats(buf, child)
      None => ()
    }
  }
  buf.write_string("}}")
}

///|
fn write_json_report(
  buf : StringBuilder,
  path : String,
  counts : @counter.Counts,
) -> Unit {
  buf.write_string("{\"stats\":")
  write_json_stats(buf, counts)
  buf.write_string(",\"name\":")
  buf.write_string(json_escape(path))
  buf.write_char('}')
}

///|
fn write_json_child_reports(
  buf : StringBuilder,
  key : String,
  files : Array[(String, String, @counter.Counts)],
) -> Unit {
  let keys = child_keys(key, files)
  for i, child_key in keys {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string(json_escape(child_name(child_key)))
    buf.write_string(": [")
    let mut first = true
    for entry in files {
      if entry.1 == key {
        match entry.2.blobs.get(child_key) {
          Some(child) => {
            if !first {
              buf.write_char(',')
            }
            first = false
            write_json_report(buf, entry.0, child)
          }
          None => ()
        }
      }
    }
    buf.write_char(']')
  }
}

///|
fn write_json_reports(
  buf : StringBuilder,
  key : String,
  files : Array[(String, String, @counter.Counts)],
) -> Unit {
  let mut first = true
  for entry in files {
    if entry.1 == key {
      if !first {
        buf.write_char(',')
      }
      first = false
      write_json_report(buf, entry.0, entry.2)
    }
  }
}

///|
fn write_json_total(
  buf : StringBuilder,
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
) -> Unit {
  buf.write_string("\"Total\":{\"blanks\":")
  buf.write_string(r.total.blanks.to_string())
  buf.write_string(",\"code\":")
  buf.write_string(r.total.code.to_string())
  buf.write_string(",\"comments\":")
  buf.write_string(r.total.comments.to_string())
  buf.write_string(",\"reports\":[],\"children\":{")
  let mut first = true
  for s in r.langs {
    if !first {
      buf.write_char(',')
    }
    first = false
    buf.write_string(json_escape(s.key))
    buf.write_string(": [")
    write_json_reports(buf, s.key, files)
    buf.write_char(']')
  }
  buf.write_string("},\"inaccurate\":false")
  buf.write_string("}")
}

///|
fn json_escape(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s.at(i).to_int()
    if c == 0x22 {
      buf.write_string("\\\"")
    } else if c == 0x5C {
      buf.write_string("\\\\")
    } else if c == 0x0A {
      buf.write_string("\\n")
    } else if c == 0x0D {
      buf.write_string("\\r")
    } else if c == 0x09 {
      buf.write_string("\\t")
    } else {
      buf.write_char(Int32::unsafe_to_char(c))
    }
    i += 1
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// CSV output:
/// Language,Files,Lines,Code,Comments,Blanks
pub fn render_csv(r : @report.Report) -> String {
  let buf = StringBuilder()
  buf.write_string("Language,Files,Lines,Code,Comments,Blanks\n")
  for s in r.langs {
    write_csv_row(buf, s)
  }
  write_csv_row(buf, r.total)
  buf.to_string()
}

///|
fn write_csv_row(buf : StringBuilder, s : @report.LangStat) -> Unit {
  buf.write_string(json_escape(s.name))
  buf.write_string(",")
  buf.write_string(s.files.to_string())
  buf.write_string(",")
  buf.write_string(s.lines.to_string())
  buf.write_string(",")
  buf.write_string(s.code.to_string())
  buf.write_string(",")
  buf.write_string(s.comments.to_string())
  buf.write_string(",")
  buf.write_string(s.blanks.to_string())
  buf.write_char('\n')
}

///|
/// YAML uses the same language/report/stat fields as JSON.
pub fn render_yaml(
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
) -> String {
  let buf = StringBuilder()
  buf.write_string("---\n")
  for s in r.langs {
    write_yaml_obj(buf, s.name, s, files)
  }
  write_yaml_total(buf, r, files)
  buf.to_string()
}

///|
fn write_yaml_obj(
  buf : StringBuilder,
  name : String,
  s : @report.LangStat,
  files : Array[(String, String, @counter.Counts)],
) -> Unit {
  buf.write_string(json_escape(name))
  buf.write_string(":\n")
  buf.write_string("  blanks: ")
  buf.write_string(s.blanks.to_string())
  let keys = child_keys(s.key, files)
  if keys.length() == 0 {
    buf.write_string("\n  children: {}\n")
  } else {
    buf.write_string("\n  children:\n")
    for child_key in keys {
      buf.write_string("    " + json_escape(child_name(child_key)) + ":\n")
      for entry in files {
        if entry.1 == s.key {
          match entry.2.blobs.get(child_key) {
            Some(child) =>
              write_yaml_report(buf, (entry.0, child_key, child), 6)
            None => ()
          }
        }
      }
    }
  }
  buf.write_string("  code: ")
  buf.write_string(s.code.to_string())
  buf.write_string("\n")
  buf.write_string("  comments: ")
  buf.write_string(s.comments.to_string())
  buf.write_string("\n  inaccurate: false\n")
  let mut any_reports = false
  for entry in files {
    if entry.1 == s.key {
      if !any_reports {
        buf.write_string("  reports:\n")
        any_reports = true
      }
      write_yaml_report(buf, entry, 4)
    }
  }
  if !any_reports {
    buf.write_string("  reports: []\n")
  }
}

///|
fn write_yaml_report(
  buf : StringBuilder,
  entry : (String, String, @counter.Counts),
  indent : Int32,
) -> Unit {
  let p = repeat(' ', indent)
  buf.write_string(p + "- name: " + json_escape(entry.0) + "\n")
  buf.write_string(p + "  stats:\n")
  write_yaml_stats(buf, entry.2, indent + 4)
}

///|
fn write_yaml_stats(
  buf : StringBuilder,
  counts : @counter.Counts,
  indent : Int32,
) -> Unit {
  let p = repeat(' ', indent)
  buf.write_string(p + "blanks: " + counts.blanks.to_string() + "\n")
  let keys : Array[String] = []
  for kv in counts.blobs {
    keys.push(kv.0)
  }
  keys.sort()
  if keys.length() == 0 {
    buf.write_string(p + "blobs: {}\n")
  } else {
    buf.write_string(p + "blobs:\n")
    for key in keys {
      buf.write_string(p + "  " + json_escape(child_name(key)) + ":\n")
      match counts.blobs.get(key) {
        Some(child) => write_yaml_stats(buf, child, indent + 4)
        None => ()
      }
    }
  }
  buf.write_string(p + "code: " + counts.code.to_string() + "\n")
  buf.write_string(p + "comments: " + counts.comments.to_string() + "\n")
}

///|
fn write_yaml_total(
  buf : StringBuilder,
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
) -> Unit {
  buf.write_string("Total:\n  blanks: ")
  buf.write_string(r.total.blanks.to_string())
  if r.langs.length() == 0 {
    buf.write_string("\n  children: {}\n")
  } else {
    buf.write_string("\n  children:\n")
    for s in r.langs {
      buf.write_string("    " + json_escape(s.key) + ":\n")
      for entry in files {
        if entry.1 == s.key {
          write_yaml_report(buf, entry, 6)
        }
      }
    }
  }
  buf.write_string("  code: " + r.total.code.to_string() + "\n")
  buf.write_string("  comments: " + r.total.comments.to_string() + "\n")
  buf.write_string("  inaccurate: false\n  reports: []\n")
}

///|
/// Per-file statistics grouped under their language totals (--files mode).
pub fn render_files(
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
) -> String {
  render_files_with_options(r, files, LINE_WIDTH, "plain", false)
}

///|
pub fn render_files_with_options(
  r : @report.Report,
  files : Array[(String, String, @counter.Counts)],
  columns : Int32,
  num_format : String,
  compact : Bool,
) -> String {
  let buf = StringBuilder()
  let table_width = if columns > LINE_WIDTH { columns } else { LINE_WIDTH }
  let name_width = table_width - 60
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  buf.write_string(pad_right(" Language", name_width))
  buf.write_string(pad_left("Files", 7))
  buf.write_string(pad_left("Lines", 13))
  buf.write_string(pad_left("Code", 13))
  buf.write_string(pad_left("Comments", 13))
  buf.write_string(pad_left("Blanks", 13))
  buf.write_char('\n')
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  for index, lang in r.langs {
    write_table_row_width(
      buf,
      lang.name,
      lang.files,
      lang.lines,
      lang.code,
      lang.comments,
      lang.blanks,
      name_width,
      num_format,
    )
    if !compact {
      write_child_table_rows(buf, lang, files, name_width, num_format)
    }
    buf.write_string(repeat('-', table_width))
    buf.write_char('\n')
    for entry in files {
      if entry.1 == lang.key {
        write_file_table_row(buf, entry.0, entry.2, name_width + 7, num_format)
      }
    }
    if index + 1 < r.langs.length() {
      buf.write_string(repeat('-', table_width))
      buf.write_char('\n')
    }
  }
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  let t = r.total
  write_table_row_width(
    buf,
    t.name,
    t.files,
    t.lines,
    t.code,
    t.comments,
    t.blanks,
    name_width,
    num_format,
  )
  buf.write_string(repeat('=', table_width))
  buf.write_char('\n')
  buf.to_string()
}

///|
fn write_file_table_row(
  buf : StringBuilder,
  path : String,
  counts : @counter.Counts,
  width : Int32,
  num_format : String,
) -> Unit {
  let label = if path.length() + 1 <= width {
    " " + path
  } else {
    " |" + path[path.length() - (width - 2):].to_owned()
  }
  buf.write_string(pad_right(label, width))
  buf.write_string(pad_left(format_number(counts.lines, num_format), 13))
  buf.write_string(pad_left(format_number(counts.code, num_format), 13))
  buf.write_string(pad_left(format_number(counts.comments, num_format), 13))
  buf.write_string(pad_left(format_number(counts.blanks, num_format), 13))
  buf.write_char('\n')
}
