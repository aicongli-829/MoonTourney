///|
/// Options controlling file discovery.
pub(all) struct WalkOptions {
  mut hidden : Bool // include hidden files/dirs (default: skip)
  mut respect_ignore : Bool // honor all supported ignore files
  mut respect_vcs_ignore : Bool // honor .gitignore
  mut respect_dot_ignore : Bool // honor .ignore and .tokeignore
}

///|
pub fn WalkOptions::new() -> WalkOptions {
  {
    hidden: false,
    respect_ignore: true,
    respect_vcs_ignore: true,
    respect_dot_ignore: true,
  }
}

///|
/// One discovered file: absolute (as-given) path, path relative to the
/// scan root, and its identified language.
pub(all) struct Found {
  path : String
  rel : String
  lang : @lang.LangDef
}

///|
fn join(a : String, b : String) -> String {
  if a.length() == 0 {
    b
  } else if b.length() == 0 {
    a
  } else if ends_with_slash(a) {
    a + b
  } else {
    a + "/" + b
  }
}

///|
fn ends_with_slash(s : String) -> Bool {
  let n = s.length()
  n > 0 && s.at(n - 1).to_int() == 0x2F
}

///|
fn is_hidden_name(name : String) -> Bool {
  name.length() > 1 && name.at(0).to_int() == 0x2E
}

///|
/// Recursively collect recognizable source files under `root`.
pub fn collect(root : String, opts : WalkOptions) -> Array[Found] {
  let out : Array[Found] = []
  let root_clean = if ends_with_slash(root) && root.length() > 1 {
    root[0:root.length() - 1].to_owned()
  } else {
    root
  }
  let root_is_file = match (Ok(@fs.is_file(root_clean)) catch { e => Err(e) }) {
    Ok(v) => v
    Err(_) => false
  }
  if root_is_file {
    let name = basename(root_clean)
    let lang = match @lang.by_filename(name) {
      Some(v) => Some(v)
      None => detect_shebang(root_clean)
    }
    match lang {
      Some(v) => out.push({ path: root_clean, rel: name, lang: v, })
      None => ()
    }
    return out
  }
  let stack = @ignore.IgnoreStack::new()
  walk_dir(root_clean, "", root_clean, opts, stack, out)
  out
}

///|
fn basename(path : String) -> String {
  let mut start = 0
  let mut i = 0
  while i < path.length() {
    let ch = path.at(i).to_int()
    if ch == 0x2F || ch == 0x5C {
      start = i + 1
    }
    i += 1
  }
  path[start:].to_owned()
}

///|
fn walk_dir(
  abs_dir : String,
  rel_dir : String,
  root : String,
  opts : WalkOptions,
  stack : @ignore.IgnoreStack,
  out : Array[Found],
) -> Unit {
  // Later rule sets take precedence. Keep the count so each directory
  // restores exactly the rule sets it contributed on return.
  let mut pushed_ignore = 0
  if opts.respect_ignore {
    for ignore_name in [".gitignore", ".ignore", ".tokeignore"] {
      let enabled = if ignore_name == ".gitignore" {
        opts.respect_vcs_ignore
      } else {
        opts.respect_dot_ignore
      }
      if enabled {
        let path = join(abs_dir, ignore_name)
        let is_f = match (Ok(@fs.is_file(path)) catch { e => Err(e) }) {
          Ok(v) => v
          Err(_) => false
        }
        if is_f {
          match (Ok(@fs.read_file_to_string(path)) catch { e => Err(e) }) {
            Ok(content) => {
              stack.push_file(rel_dir, content)
              pushed_ignore += 1
            }
            Err(_) => ()
          }
        }
      }
    }
  }
  let entries : Array[String] = match
    (Ok(@fs.read_dir(abs_dir)) catch { e => Err(e) }) {
    Ok(v) => {
      let arr : Array[String] = []
      for e in v {
        arr.push(e)
      }
      sort_strings(arr)
      arr
    }
    Err(_) => []
  }
  for name in entries {
    let is_hidden = is_hidden_name(name)
    if is_hidden && !opts.hidden {
      continue
    }
    let abs = join(abs_dir, name)
    let rel = if rel_dir.length() == 0 { name } else { rel_dir + "/" + name }
    let is_dir = match (Ok(@fs.is_dir(abs)) catch { e => Err(e) }) {
      Ok(v) => v
      Err(_) => false
    }
    if is_dir {
      // Check ignore rules for the directory itself.
      if opts.respect_ignore && stack.is_ignored(rel, true) {
        continue
      }
      walk_dir(abs, rel, root, opts, stack, out)
    } else {
      if opts.respect_ignore && stack.is_ignored(rel, false) {
        continue
      }
      match @lang.by_filename(name) {
        Some(lang) => out.push({ path: abs, rel, lang, })
        None =>
          // Unknown extension: try shebang detection for extensionless
          // or plain files (like tokei does for scripts).
          match detect_shebang(abs) {
            Some(lang) => out.push({ path: abs, rel, lang, })
            None => ()
          }
      }
    }
  }
  while pushed_ignore > 0 {
    stack.pop()
    pushed_ignore -= 1
  }
}

///|
fn sort_strings(arr : Array[String]) -> Unit {
  arr.sort_by(fn(a, b) { a.compare(b) })
}

///|
/// Read the first line of a file and match it against shebang lists.
fn detect_shebang(path : String) -> @lang.LangDef? {
  let bytes = match (Ok(@fs.read_file_to_bytes(path)) catch { e => Err(e) }) {
    Ok(b) => b
    Err(_) => return None
  }
  // Binary check on the way (avoid double reads later is fine).
  let probe = if bytes.length() < 8192 { bytes.length() } else { 8192 }
  let mut i = 0
  while i < probe {
    if bytes[i] == 0 {
      return None
    }
    i += 1
  }
  if bytes.length() < 2 || bytes[0] != 0x23 || bytes[1] != 0x21 {
    return None
  }
  // First line, up to \n, decoded as UTF-8 lossy.
  let mut end = 0
  while end < bytes.length() && bytes[end] != 0x0A {
    end += 1
  }
  let line = decode_prefix(bytes, end)
  @lang.by_shebang(line)
}

///|
fn decode_prefix(bytes : Bytes, end : Int32) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < end {
    let b0 = bytes[i].to_int()
    if b0 >= 0 && b0 < 0x80 {
      buf.write_char(Int32::unsafe_to_char(b0))
      i += 1
    } else {
      // Best-effort: skip non-ASCII in shebang lines.
      i += 1
    }
  }
  buf.to_string()
}

///|
/// Apply user exclude globs to the discovered list.
pub fn apply_excludes(
  files : Array[Found],
  excludes : Array[String],
) -> Array[Found] {
  if excludes.length() == 0 {
    return files
  }
  let out : Array[Found] = []
  for f in files {
    let mut drop = false
    for pat in excludes {
      if @ignore.exclude_match(pat, f.rel) {
        drop = true
        break
      }
    }
    if !drop {
      out.push(f)
    }
  }
  out
}
