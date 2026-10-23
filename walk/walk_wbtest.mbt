///|
test "walk honors three ignore sources independently" {
  let root = "walk/fixtures/ignore"
  let vcs_file = root + "/vcs.rs"
  // Git ignores this fixture by design, so create it only for the test.
  match
    (Ok(@fs.write_string_to_file(vcs_file, "fn vcs() {}\n")) catch {
      e => Err(e)
    }) {
    Ok(_) => ()
    Err(_) => abort("could not create ignore fixture")
  }
  let defaults = WalkOptions::new()
  let all_ignored = collect(root, defaults).length()
  defaults.respect_vcs_ignore = false
  let vcs_visible = collect(root, defaults).length()
  defaults.respect_dot_ignore = false
  let all_visible = collect(root, defaults).length()
  match (Ok(@fs.remove_file(vcs_file)) catch { e => Err(e) }) {
    Ok(_) => ()
    Err(_) => abort("could not remove ignore fixture")
  }
  assert_eq(all_ignored, 1)
  assert_eq(vcs_visible, 2)
  assert_eq(all_visible, 4)
}
