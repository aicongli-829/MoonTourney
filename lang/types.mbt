///|
/// Language definition, converted 1:1 from tokei's `languages.json`.
pub(all) struct LangDef {
  key : String // JSON key, e.g. "C++"
  name : String // display name, e.g. "C++"
  line_comments : Array[String]
  block_comments : Array[(String, String)] // (start, end)
  quotes : Array[(String, String)] // (start, end)
  verbatim_quotes : Array[(String, String)] // e.g. Rust r#"..."#
  doc_quotes : Array[(String, String)] // e.g. Python triple quotes
  important_syntax : Array[String] // embedded-language markers, e.g. HTML <script>
  literate : Bool // prose lines count as comments, e.g. Markdown or plain text
  nested : Bool // block comments may nest (Rust, Java block comments do not)
  shebangs : Array[String]
  extensions : Array[String] // lowercase, without the dot
  filenames : Array[String] // lowercase, e.g. "makefile"
}

///|
/// All languages, generated into data.mbt.
pub fn all_languages() -> Array[LangDef] {
  all_langs
}

///|
pub fn key_eq(a : String, b : String) -> Bool {
  let n = a.length()
  if n != b.length() {
    return false
  }
  let mut i = 0
  while i < n {
    let ca = a.at(i).to_int()
    let cb = b.at(i).to_int()
    let la = if ca >= 65 && ca <= 90 { ca + 32 } else { ca }
    let lb = if cb >= 65 && cb <= 90 { cb + 32 } else { cb }
    if la != lb {
      return false
    }
    i += 1
  }
  true
}

///|
/// Look up a language by its JSON key (exact, case-sensitive).
pub fn by_key(key : String) -> LangDef? {
  for lang in all_langs {
    if lang.key == key {
      return Some(lang)
    }
  }
  None
}

///|
/// Build indexes once instead of scanning every language for every file.
fn build_file_indexes() -> (Map[String, LangDef], Map[String, LangDef]) {
  let names : Map[String, LangDef] = Map([])
  let extensions : Map[String, LangDef] = Map([])
  for lang in all_langs {
    for name in lang.filenames {
      if names.get(name) is None {
        names.set(name, lang)
      }
    }
    for ext in lang.extensions {
      if extensions.get(ext) is None {
        extensions.set(ext, lang)
      }
    }
  }
  (names, extensions)
}

///|
let file_indexes : (Map[String, LangDef], Map[String, LangDef]) = build_file_indexes()

///|
/// Look up a language by file name: exact filename match first (lowercased),
/// then extension match. Returns the first language whose extension list
/// contains the extension, in generated (alphabetical) order like tokei.
pub fn by_filename(fname : String) -> LangDef? {
  let lower = fname.to_lower()
  match file_indexes.0.get(lower) {
    Some(lang) => return Some(lang)
    None => ()
  }
  // Extension: use the part after the last dot.
  let dot = lower.rev_find(".")
  match dot {
    Some(idx) if idx + 1 < lower.length() => {
      let ext = lower[idx + 1:].to_owned()
      file_indexes.1.get(ext)
    }
    _ => None
  }
}

///|
/// Match a file by shebang content (first line starting with "#!").
pub fn by_shebang(first_line : String) -> LangDef? {
  for lang in all_langs {
    for s in lang.shebangs {
      if first_line.contains(s) {
        return Some(lang)
      }
    }
  }
  None
}

///|
/// Human-readable list of all supported languages and extensions.
pub fn language_list() -> String {
  let buf = StringBuilder()
  buf.write_string("Languages: ")
  buf.write_string(all_langs.length().to_string())
  buf.write_string("\n")
  for lang in all_langs {
    buf.write_string("  ")
    buf.write_string(lang.key)
    if lang.extensions.length() > 0 {
      buf.write_string(" (")
      let mut first = true
      for e in lang.extensions {
        if !first {
          buf.write_string(", ")
        }
        buf.write_string(e)
        first = false
      }
      buf.write_string(")")
    }
    buf.write_string("\n")
  }
  buf.to_string()
}
