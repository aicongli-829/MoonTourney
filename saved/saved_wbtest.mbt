///|
test "official JSON reports can be loaded with child-language counts" {
  let source = "{\"Jupyter Notebooks\":{\"blanks\":0,\"comments\":0,\"code\":0,\"reports\":[{\"name\":\"a.ipynb\",\"stats\":{\"blanks\":0,\"comments\":0,\"code\":0,\"blobs\":{\"Python\":{\"blanks\":1,\"comments\":1,\"code\":2,\"blobs\":{}}}}}],\"children\":{},\"inaccurate\":false},\"Total\":{\"blanks\":0,\"comments\":0,\"code\":0,\"reports\":[],\"children\":{},\"inaccurate\":false}}"
  match parse(source) {
    Some(snapshot) => {
      assert_eq(snapshot.files.length(), 1)
      assert_eq(snapshot.files[0].1, "Jupyter")
      match snapshot.counts.get("Jupyter") {
        Some(parent) => {
          assert_eq(parent.files, 1)
          match parent.blobs.get("Python") {
            Some(child) => {
              assert_eq(child.lines, 4)
              assert_eq(child.code, 2)
            }
            None => abort("missing Python child")
          }
        }
        None => abort("missing Jupyter report")
      }
    }
    None => abort("official JSON should parse")
  }
  assert_eq(parse("not json") is None, true)
}
