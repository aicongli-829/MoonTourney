///|
test "indexed language detection preserves direct matches" {
  assert_eq(by_filename("main.mbt").unwrap().key, "MoonBit")
  assert_eq(by_filename("src.rs").unwrap().key, "Rust")
  assert_eq(by_filename("unknown.zzz") is None, true)
}
