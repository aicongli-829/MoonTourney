///|
test "upstream short flags select files and output format" {
  let opts = parse_args(["-f", "-o", "json", "src"])
  assert_eq(opts.list_files, true)
  match opts.format {
    Json => ()
    _ => abort("-o json must select JSON output")
  }
  assert_eq(opts.paths.length(), 1)
  assert_eq(opts.paths[0], "src")
}

///|
test "default ordering is language name" {
  let opts = parse_args(["."])
  assert_eq(opts.sort_key, "language")
}

///|
test "output-file extension keeps upstream output flag available" {
  let opts = parse_args(["--output", "csv", "--output-file", "stats.csv"])
  match opts.format {
    Csv => ()
    _ => abort("--output csv must select CSV output")
  }
  assert_eq(opts.out_file, Some("stats.csv"))
}

///|
test "individual ignore sources can be disabled" {
  let opts = parse_args(["--no-ignore-dot", "--no-ignore-vcs", "."])
  assert_eq(opts.no_ignore_dot, true)
  assert_eq(opts.no_ignore_vcs, true)
  assert_eq(opts.no_ignore, false)
}
