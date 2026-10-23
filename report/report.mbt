///|
/// Aggregated statistics for one language.
pub(all) struct LangStat {
  key : String
  name : String
  mut files : Int32
  mut lines : Int32
  mut code : Int32
  mut comments : Int32
  mut blanks : Int32
}

///|
/// Full report: per-language stats plus the total.
pub(all) struct Report {
  langs : Array[LangStat] // ordered per sort_key/reverse
  total : LangStat
}

///|
fn stat_sort_value(s : LangStat, key : String) -> Int32 {
  match key {
    "files" => s.files
    "lines" => s.lines
    "blanks" => s.blanks
    "code" => s.code
    "comments" => s.comments
    _ => s.code
  }
}

///|
/// Build the report from a map of language key -> accumulated counts.
/// Default order: by displayed language name, matching the CLI default.
pub fn build(
  lang_counts : Map[String, @counter.Counts],
  sort_key : String,
  reverse : Bool,
) -> Report {
  let total = LangStat::new_total()
  let langs : Array[LangStat] = []
  for kv in lang_counts {
    let lang = @lang.by_key(kv.0)
    let name = match lang {
      Some(l) => l.name
      None => kv.0
    }
    let c = kv.1
    let s = {
      key: kv.0,
      name,
      files: c.files,
      lines: c.lines,
      code: c.code,
      comments: c.comments,
      blanks: c.blanks,
    }
    langs.push(s)
    total.files += c.files
    total.lines += c.lines
    total.code += c.code
    total.comments += c.comments
    total.blanks += c.blanks
  }
  let sign = if reverse { -1 } else { 1 }
  if sort_key == "language" {
    langs.sort_by(fn(a, b) { sign * a.name.lexical_compare(b.name) })
  } else {
    langs.sort_by(fn(a, b) {
      let va = stat_sort_value(a, sort_key)
      let vb = stat_sort_value(b, sort_key)
      let c = sign * vb.compare(va) // desc by default
      if c == 0 {
        sign * a.name.lexical_compare(b.name)
      } else {
        c
      }
    })
  }
  { langs, total, }
}

///|
pub fn LangStat::new_total() -> LangStat {
  {
    key: "Total",
    name: "Total",
    files: 0,
    lines: 0,
    code: 0,
    comments: 0,
    blanks: 0,
  }
}
