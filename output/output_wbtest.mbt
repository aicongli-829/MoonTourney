///|
test "JSON serializes upstream language and file report fields" {
  let c : @counter.Counts = {
    files: 1,
    lines: 3,
    code: 1,
    comments: 1,
    blanks: 1,
    blobs: Map([]),
  }
  let counts : Map[String, @counter.Counts] = Map([])
  counts.set("Rust", c)
  let report = @report.build(counts, "language", false)
  let files = [("src/main.rs", "Rust", c)]
  let json = render_json(report, files)
  assert_eq(json.contains("\"Rust\":{\"blanks\":1"), true)
  assert_eq(json.contains("\"name\":\"src/main.rs\""), true)
  assert_eq(json.contains("\"Total\":{\"blanks\":1"), true)
  assert_eq(json.contains("\"children\":{\"Rust\": ["), true)
}

///|
test "file table keeps long paths and totals together" {
  let c : @counter.Counts = {
    files: 1,
    lines: 2,
    code: 1,
    comments: 1,
    blanks: 0,
    blobs: Map([]),
  }
  let counts : Map[String, @counter.Counts] = Map([])
  counts.set("Rust", c)
  let report = @report.build(counts, "language", false)
  let path = "very/long/path/to/a/source/file.rs"
  let table = render_files(report, [(path, "Rust", c)])
  assert_eq(table.contains(path), true)
  assert_eq(table.contains("Total"), true)
}

///|
test "YAML serializes file reports rather than derived totals" {
  let c : @counter.Counts = {
    files: 1,
    lines: 1,
    code: 1,
    comments: 0,
    blanks: 0,
    blobs: Map([]),
  }
  let counts : Map[String, @counter.Counts] = Map([])
  counts.set("Rust", c)
  let report = @report.build(counts, "language", false)
  let yaml = render_yaml(report, [("src/main.rs", "Rust", c)])
  assert_eq(yaml.contains("---\n"), true)
  assert_eq(yaml.contains("  reports:\n"), true)
  assert_eq(yaml.contains("    - name: \"src/main.rs\""), true)
  assert_eq(yaml.contains("  children: {}\n"), true)
  assert_eq(yaml.contains("Total:\n"), true)
  assert_eq(yaml.contains("    \"Rust\":\n"), true)
}

///|
test "notebook children appear in JSON and YAML reports" {
  let c = @counter.Counts::new()
  c.files = 1
  let child = @counter.Counts::new()
  child.files = 1
  child.code = 2
  c.blobs.set("Python", child)
  let counts : Map[String, @counter.Counts] = Map([])
  counts.set("Jupyter", c.copy())
  let report = @report.build(counts, "language", false)
  let files = [("sample.ipynb", "Jupyter", c)]
  let json = render_json(report, files)
  assert_eq(json.contains("\"children\":{\"Python\": ["), true)
  assert_eq(json.contains("\"blobs\":{\"Python\":{\"blanks\":0"), true)
  assert_eq(json.contains("\"children\":{\"Jupyter\": ["), true)
  let yaml = render_yaml(report, files)
  assert_eq(yaml.contains("  children:\n    \"Python\":\n"), true)
  assert_eq(yaml.contains("        blobs:\n          \"Python\":\n"), true)
}
