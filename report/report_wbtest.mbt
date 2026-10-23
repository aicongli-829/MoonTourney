///|
test "default report order is alphabetical by displayed language" {
  assert_eq("JavaScript".lexical_compare("Rust") < 0, true)
  let names = ["Rust", "Go", "JavaScript"]
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  assert_eq(names[0], "Go")
  assert_eq(names[1], "JavaScript")
  assert_eq(names[2], "Rust")
  let counts : Map[String, @counter.Counts] = Map([])
  for key in ["Rust", "Go", "JavaScript"] {
    let item = @counter.Counts::new()
    item.files = 1
    item.code = 1
    counts.set(key, item)
  }
  let report = build(counts, "language", false)
  assert_eq(report.langs[0].name, "Go")
  assert_eq(report.langs[1].name, "JavaScript")
  assert_eq(report.langs[2].name, "Rust")
}

///|
test "requested code sort ranks larger counts first" {
  let counts : Map[String, @counter.Counts] = Map([])
  for entry in [("Rust", 3), ("Go", 1), ("JavaScript", 2)] {
    let item = @counter.Counts::new()
    item.files = 1
    item.code = entry.1
    counts.set(entry.0, item)
  }
  let report = build(counts, "code", false)
  assert_eq(report.langs[0].name, "Rust")
  assert_eq(report.langs[1].name, "JavaScript")
  assert_eq(report.langs[2].name, "Go")
}
