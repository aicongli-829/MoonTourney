///|
/// Entry point: TokeiMBT — a tokei port in MoonBit.
fn main {
  let argv = @env.args()
  let opts = parse_args(argv)
  if opts.show_help {
    println(usage())
    return
  }
  if opts.show_version {
    println("TokeiMBT " + VERSION)
    return
  }
  if opts.list_langs {
    println(@lang.language_list())
    return
  }
  let roots : Array[String] = if opts.paths.length() > 0 {
    opts.paths
  } else {
    ["."]
  }
  // 1. discover files
  let wopt = @walk.WalkOptions::new()
  wopt.hidden = opts.hidden
  wopt.respect_ignore = !opts.no_ignore
  wopt.respect_dot_ignore = !opts.no_ignore_dot
  wopt.respect_vcs_ignore = !opts.no_ignore_vcs
  let all_files : Array[@walk.Found] = []
  for root in roots {
    if @fs.path_exists(root) {
      for f in @walk.collect(root, wopt) {
        all_files.push(f)
      }
    } else {
      println("[tokei error]: No such file or directory: " + root)
    }
  }
  // 2. user excludes
  let files = @walk.apply_excludes(all_files, opts.excludes)
  // 3. type filters
  let filtered : Array[@walk.Found] = []
  for f in files {
    if type_allowed(opts, f.lang.key) {
      filtered.push(f)
    }
  }
  // 4. count
  let counts : Map[String, @counter.Counts] = Map([])
  let file_counts : Array[(String, String, @counter.Counts)] = []
  for f in filtered {
    match (Ok(@fs.read_file_to_bytes(f.path)) catch { e => Err(e) }) {
      Ok(bytes) =>
        if !is_binary(bytes) {
          let src = @counter.utf8_decode(bytes)
          let c = @counter.count_source(f.lang, src)
          file_counts.push((f.path, f.lang.key, c))
          let key = f.lang.key
          match counts.get(key) {
            Some(acc) => acc.add(c)
            None => counts.set(key, c.copy())
          }
        }
      Err(@fs.IOError(msg)) =>
        println("[tokei warning]: could not read " + f.rel + ": " + msg)
    }
  }
  // 5. report & output
  let rep = @report.build(counts, opts.sort_key, opts.reverse)
  match opts.format {
    Table =>
      if opts.list_files {
        emit(opts, @output.render_files(rep, file_counts))
      } else {
        emit(opts, @output.render_table(rep))
      }
    Json => emit(opts, @output.render_json(rep, file_counts))
    Csv => emit(opts, @output.render_csv(rep))
    Yaml => emit(opts, @output.render_yaml(rep, file_counts))
  }
}

///|
fn type_allowed(opts : Opts, key : String) -> Bool {
  if opts.types.length() > 0 {
    let mut ok = false
    for t in opts.types {
      if @lang.key_eq(t, key) {
        ok = true
        break
      }
    }
    if !ok {
      return false
    }
  }
  if opts.types_not.length() > 0 {
    for t in opts.types_not {
      if @lang.key_eq(t, key) {
        return false
      }
    }
  }
  true
}

///|
fn emit(opts : Opts, text : String) -> Unit {
  match opts.out_file {
    Some(path) =>
      match (Ok(@fs.write_string_to_file(path, text)) catch { e => Err(e) }) {
        Ok(_) => ()
        Err(@fs.IOError(msg)) =>
          println("[tokei error]: cannot write to " + path + ": " + msg)
      }
    None => println(text)
  }
}

///|
fn is_binary(bytes : Bytes) -> Bool {
  let limit = if bytes.length() < 8192 { bytes.length() } else { 8192 }
  let mut i = 0
  while i < limit {
    if bytes[i] == 0 {
      return true
    }
    i += 1
  }
  false
}
