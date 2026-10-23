///|
/// Counting result for a set of files of one language.
pub(all) struct Counts {
  mut files : Int32
  mut lines : Int32
  mut code : Int32
  mut comments : Int32
  mut blanks : Int32
  blobs : Map[String, Counts]
}

///|
pub fn Counts::add(self : Counts, other : Counts) -> Unit {
  self.files += other.files
  self.lines += other.lines
  self.code += other.code
  self.comments += other.comments
  self.blanks += other.blanks
  for kv in other.blobs {
    match self.blobs.get(kv.0) {
      Some(existing) => existing.add(kv.1)
      None => self.blobs.set(kv.0, kv.1.copy())
    }
  }
}

///|
/// Aggregation must not mutate a per-file report that shares this value.
pub fn Counts::copy(self : Counts) -> Counts {
  let blobs : Map[String, Counts] = Map([])
  for kv in self.blobs {
    blobs.set(kv.0, kv.1.copy())
  }
  {
    files: self.files,
    lines: self.lines,
    code: self.code,
    comments: self.comments,
    blanks: self.blanks,
    blobs,
  }
}

///|
pub fn Counts::new() -> Counts {
  { files: 0, lines: 0, code: 0, comments: 0, blanks: 0, blobs: Map([]), }
}

///|
priv enum Tok {
  LineTok // line comment starter (includes doc comments)
  BlockTok(String, String) // block comment (start, end)
  StrTok(Int32) // index into the merged string token table
}

///|
priv enum St {
  Normal
  InBlock(Int32, String, String) // depth, current start marker, end marker
  InStr(Int32) // index into merged string token table
}

///|
priv struct StrTokDef {
  start : String
  end : String
  escapable : Bool
}

///|
priv struct Matcher {
  line_toks : Array[String] // sorted by length desc
  block_toks : Array[(String, String)] // sorted by start length desc
  str_toks : Array[StrTokDef] // sorted by start length desc
}

///|
fn build_matcher(lang : @lang.LangDef) -> Matcher {
  let line_toks : Array[String] = []
  for t in lang.line_comments {
    line_toks.push(normalize_token(t))
  }
  // `important_syntax` marks language-specific constructs such as HTML
  // <script>/<style> for embedded-language parsing. It is not a comment
  // delimiter and must not turn those lines into comments.
  line_toks.sort_by(fn(a, b) { b.length().compare(a.length()) })
  let block_toks : Array[(String, String)] = []
  for p in lang.block_comments {
    block_toks.push((normalize_token(p.0), normalize_token(p.1)))
  }
  block_toks.sort_by(fn(a, b) { b.0.length().compare(a.0.length()) })
  let str_toks : Array[StrTokDef] = []
  for p in lang.quotes {
    str_toks.push({
      start: normalize_token(p.0),
      end: normalize_token(p.1),
      escapable: true,
    })
  }
  for p in lang.verbatim_quotes {
    str_toks.push({
      start: normalize_token(p.0),
      end: normalize_token(p.1),
      escapable: false,
    })
  }
  for p in lang.doc_quotes {
    str_toks.push({
      start: normalize_token(p.0),
      end: normalize_token(p.1),
      escapable: true,
    })
  }
  str_toks.sort_by(fn(a, b) { b.start.length().compare(a.start.length()) })
  { line_toks, block_toks, str_toks, }
}

///|
/// Tokei's language JSON spells a quote as \" inside delimiter values.
/// Decode that grammar escape while leaving actual backslashes alone.
fn normalize_token(token : String) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < token.length() {
    if i + 1 < token.length() &&
      token.at(i).to_int() == 0x5C &&
      token.at(i + 1).to_int() == 0x22 {
      out.write_char('"')
      i += 2
    } else {
      out.write_char(Int32::unsafe_to_char(token.at(i).to_int()))
      i += 1
    }
  }
  out.to_string()
}

///|
/// ASCII whitespace (BOM is handled separately).
fn is_space(c : Int32) -> Bool {
  c == 0x20 || c == 0x09 || c == 0x0D || c == 0x0B || c == 0x0C
}

///|
/// Tokei trims trailing whitespace before searching for syntax markers.
fn trim_line_end(line : String) -> String {
  let mut end = line.length()
  while end > 0 && is_space(line.at(end - 1).to_int()) {
    end -= 1
  }
  if end == line.length() {
    line
  } else {
    line[:end].to_owned()
  }
}

///|
fn starts_at(s : String, pos : Int32, needle : String) -> Bool {
  let n = needle.length()
  if pos + n > s.length() {
    return false
  }
  let mut i = 0
  while i < n {
    if s.at(pos + i).to_int() != needle.at(i).to_int() {
      return false
    }
    i += 1
  }
  true
}

///|
/// Split source text into lines (\n separated; trailing \r removed;
/// a trailing newline does not produce an extra empty line).
fn split_lines(src : String) -> Array[String] {
  let out : Array[String] = []
  let n = src.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    if src.at(i).to_int() == 0x0A {
      let mut end = i
      if end > start && src.at(end - 1).to_int() == 0x0D {
        end -= 1
      }
      out.push(src[start:end].to_owned())
      i += 1
      start = i
    } else {
      i += 1
    }
  }
  if start < n {
    let mut end = n
    if end > start && src.at(end - 1).to_int() == 0x0D {
      end -= 1
    }
    out.push(src[start:end].to_owned())
  }
  out
}

///|
/// Strip a UTF-8 BOM that may appear as the first char.
fn strip_bom(src : String) -> String {
  if src.length() > 0 && src.at(0).to_int() == 0xFEFF {
    src[1:].to_owned()
  } else {
    src
  }
}

///|
/// Try to match any Normal-state token at position `i`. Longest match wins
/// (this resolves "///" over "//", "/*" over ... consistently because the
/// token tables are pre-sorted by length desc and scanned in order).
fn match_at(m : Matcher, line : String, i : Int32) -> Tok? {
  let mut best : Tok? = None
  let mut length = 0
  for t in m.line_toks {
    if t.length() > length && starts_at(line, i, t) {
      best = Some(LineTok)
      length = t.length()
    }
  }
  for p in m.block_toks {
    if p.0.length() > length && starts_at(line, i, p.0) {
      best = Some(BlockTok(p.0, p.1))
      length = p.0.length()
    }
  }
  let mut idx = 0
  for p in m.str_toks {
    if p.start.length() > length && starts_at(line, i, p.start) {
      best = Some(StrTok(idx))
      length = p.start.length()
    }
    idx += 1
  }
  best
}

///|
/// Classify one line given the incoming state.
/// Kind: 0 = blank, 1 = comment, 2 = code. Returns (kind, next state).
///
/// Semantics (aligned with tokei):
/// - a line with any code token counts as code, even if it also has comments
/// - a line entirely inside a block comment counts as comment
/// - a blank line inside a block comment counts as comment
/// - string literal continuation lines count as code
/// - a fully blank line in Normal state counts as blank
fn scan_line(
  m : Matcher,
  lang : @lang.LangDef,
  line : String,
  st_in : St,
) -> (Int32, St) {
  let n = line.length()
  let mut i = 0
  let mut saw_code = false
  let mut saw_comment = false
  let mut st = st_in
  // A line continuing inside a block comment is a comment line;
  // a line continuing inside a string literal is a code line (tokei semantics).
  match st_in {
    InBlock(_, _, _) => saw_comment = true
    InStr(_) => saw_code = true
    Normal => ()
  }
  while i < n {
    match st {
      Normal =>
        match match_at(m, line, i) {
          Some(LineTok(_)) => {
            saw_comment = true
            break
          }
          Some(BlockTok(start, end)) => {
            saw_comment = true
            i += start.length()
            st = InBlock(1, start, end)
          }
          Some(StrTok(idx)) => {
            saw_code = true
            i += m.str_toks[idx].start.length()
            st = InStr(idx)
          }
          None => {
            if !is_space(line.at(i).to_int()) {
              saw_code = true
            }
            i += 1
          }
        }
      InBlock(depth, start, end) =>
        if lang.nested && starts_at(line, i, start) {
          i += start.length()
          st = InBlock(depth + 1, start, end)
        } else if starts_at(line, i, end) {
          i += end.length()
          if depth - 1 == 0 {
            st = Normal
          } else {
            st = InBlock(depth - 1, start, end)
          }
        } else {
          i += 1
        }
      InStr(idx) => {
        let tok = m.str_toks[idx]
        if tok.escapable && line.at(i).to_int() == 0x5C {
          i += 2
        } else if starts_at(line, i, tok.end) {
          i += tok.end.length()
          st = Normal
        } else {
          i += 1
        }
      }
    }
  }
  let kind = if saw_code { 2 } else if saw_comment { 1 } else { 0 }
  (kind, st)
}

///|
/// Count lines of a full source text for `lang`.
pub fn count_source(lang : @lang.LangDef, source : String) -> Counts {
  if lang.key == "Jupyter" {
    return count_notebook(source)
  }
  let counts = Counts::new()
  counts.files = 1
  let src = strip_bom(source)
  let lines = split_lines(src)
  if lang.literate {
    counts.lines = lines.length()
    for line in lines {
      let mut blank = true
      let mut i = 0
      while i < line.length() {
        if !is_space(line.at(i).to_int()) {
          blank = false
          break
        }
        i += 1
      }
      if blank {
        counts.blanks += 1
      } else {
        counts.comments += 1
      }
    }
    return counts
  }
  let m = build_matcher(lang)
  let mut st : St = Normal
  counts.lines = lines.length()
  let mut first = true
  for line in lines {
    if first {
      first = false
      // Shebang first line counts as a comment (tokei semantics).
      if starts_at(line, 0, "#!") && lang.shebangs.length() > 0 {
        counts.comments += 1
        continue
      }
    }
    let (kind, next) = scan_line(m, lang, trim_line_end(line), st)
    match kind {
      0 => counts.blanks += 1
      1 => counts.comments += 1
      _ => counts.code += 1
    }
    st = next
  }
  counts
}

///|
fn notebook_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn notebook_text(value : Json) -> String {
  match value {
    String(s) => s
    Array(parts) => {
      let out = StringBuilder()
      for part in parts {
        match part {
          String(s) => out.write_string(s)
          _ => ()
        }
      }
      out.to_string()
    }
    _ => ""
  }
}

///|
fn notebook_language(document : Json) -> @lang.LangDef? {
  let metadata = notebook_field(document, "metadata")
  let info = notebook_field(metadata, "language_info")
  let kernel = notebook_field(metadata, "kernelspec")
  match (info, kernel) {
    (Object(_), Object(_)) => ()
    _ => return None
  }
  let mut hint = notebook_text(notebook_field(kernel, "language"))
  if hint.length() == 0 {
    hint = notebook_text(notebook_field(info, "name"))
  }
  for lang in @lang.all_languages() {
    if @lang.key_eq(lang.key, hint) || @lang.key_eq(lang.name, hint) {
      if lang.key != "Jupyter" {
        return Some(lang)
      }
    }
  }
  None
}

///|
/// Jupyter notebooks keep their own top-level statistics at zero and report
/// code/markdown cells as child language blobs, like upstream Tokei.
fn count_notebook(source : String) -> Counts {
  let counts = Counts::new()
  counts.files = 1
  let document = @json.parse(source) catch { _ => return counts }
  let code_lang = notebook_language(document)
  if code_lang is None {
    return counts
  }
  let markdown_lang = @lang.by_key("Markdown")
  match notebook_field(document, "cells") {
    Array(cells) =>
      for cell in cells {
        let kind = notebook_text(notebook_field(cell, "cell_type"))
        let child_lang = match kind {
          "code" => code_lang
          "markdown" => markdown_lang
          _ => None
        }
        match child_lang {
          Some(lang) => {
            let body = notebook_text(notebook_field(cell, "source"))
            let child = count_source(lang, body)
            match counts.blobs.get(lang.key) {
              Some(existing) => existing.add(child)
              None => counts.blobs.set(lang.key, child)
            }
          }
          None => ()
        }
      }
    _ => ()
  }
  counts
}

///|
/// Count lines from raw bytes: detects binary files (NUL byte in the first
/// 8 KiB, like tokei) and returns None for them.
pub fn count_bytes(lang : @lang.LangDef, bytes : Bytes) -> Counts? {
  let probe = if bytes.length() < 8192 { bytes.length() } else { 8192 }
  let mut i = 0
  while i < probe {
    if bytes[i] == 0 {
      return None
    }
    i += 1
  }
  Some(count_source(lang, utf8_decode(bytes)))
}

///|
/// Decode UTF-8 bytes to a MoonBit String (UTF-16), lossy:
/// invalid sequences become U+FFFD, like most modern tools.
pub fn utf8_decode(bytes : Bytes) -> String {
  let buf = StringBuilder()
  let n = bytes.length()
  let mut i = 0
  fn push_cp(cp : Int32) -> Unit {
    if cp >= 0x10000 {
      // surrogate pair
      let v = cp - 0x10000
      buf.write_char(Int32::unsafe_to_char(0xD800 + (v >> 10)))
      buf.write_char(Int32::unsafe_to_char(0xDC00 + (v & 0x3FF)))
    } else {
      buf.write_char(Int32::unsafe_to_char(cp))
    }
  }

  while i < n {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      push_cp(b0)
      i += 1
    } else if b0 >> 5 == 0x6 && i + 1 < n {
      let b1 = bytes[i + 1].to_int()
      if b1 >> 6 == 0x2 {
        push_cp(((b0 & 0x1F) << 6) | (b1 & 0x3F))
        i += 2
      } else {
        buf.write_char(Int32::unsafe_to_char(0xFFFD))
        i += 1
      }
    } else if b0 >> 4 == 0xE && i + 2 < n {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      if b1 >> 6 == 0x2 && b2 >> 6 == 0x2 {
        push_cp(((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F))
        i += 3
      } else {
        buf.write_char(Int32::unsafe_to_char(0xFFFD))
        i += 1
      }
    } else if b0 >> 3 == 0x1E && i + 3 < n {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      if b1 >> 6 == 0x2 && b2 >> 6 == 0x2 && b3 >> 6 == 0x2 {
        push_cp(
          ((b0 & 0x07) << 18) |
          ((b1 & 0x3F) << 12) |
          ((b2 & 0x3F) << 6) |
          (b3 & 0x3F),
        )
        i += 4
      } else {
        buf.write_char(Int32::unsafe_to_char(0xFFFD))
        i += 1
      }
    } else {
      buf.write_char(Int32::unsafe_to_char(0xFFFD))
      i += 1
    }
  }
  buf.to_string()
}
