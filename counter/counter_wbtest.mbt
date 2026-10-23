///|
/// White-box tests for the counting state machine.

///|
test "C: code, comments, blanks and escaped strings" {
  let lang = @lang.by_key("C").unwrap()
  let src = "/* head\n   more */\n#include <stdio.h>\n// line\nint main() {\n    printf(\"hi \\\" x\"); /* inline */ return 0;\n}\n"
  let c = count_source(lang, src)
  assert_eq(c.files, 1)
  assert_eq(c.lines, 7)
  assert_eq(c.code, 4) // include, int main, printf, }
  assert_eq(c.comments, 3) // 2 head lines + // line
  assert_eq(c.blanks, 0)
}

///|
test "C: string with comment markers is code" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "const char* s = \"/* not a comment */\";\n")
  assert_eq(c.lines, 1)
  assert_eq(c.code, 1)
  assert_eq(c.comments, 0)
}

///|
test "Rust: nested block comments" {
  let lang = @lang.by_key("Rust").unwrap()
  let src = "/* outer /* inner */ still comment */\nfn main() {}\n"
  let c = count_source(lang, src)
  assert_eq(c.code, 1)
  assert_eq(c.comments, 1)
  assert_eq(c.blanks, 0)
}

///|
test "Python: docstring lines count as code, # as comment" {
  let lang = @lang.by_key("Python").unwrap()
  let src = "# comment\ndef f():\n    \"\"\"doc\n    span\"\"\"\n    return 1\n\n"
  let c = count_source(lang, src)
  assert_eq(c.comments, 1)
  assert_eq(c.code, 4) // def, doc two lines, return
  assert_eq(c.blanks, 1)
}

///|
test "Python: escaped quote inside string" {
  let lang = @lang.by_key("Python").unwrap()
  let c = count_source(lang, "s = \"it's \\\"ok\\\" # not comment\"\n")
  assert_eq(c.code, 1)
  assert_eq(c.comments, 0)
}

///|
test "MoonBit: doc comments and line comments" {
  let lang = @lang.by_key("MoonBit").unwrap()
  let src = "// top\n///|\nfn f() -> Unit {\n  println(\"x\") // tail\n}\n"
  let c = count_source(lang, src)
  assert_eq(c.code, 3)
  assert_eq(c.comments, 2)
  assert_eq(c.blanks, 0)
}

///|
test "blank counting" {
  let lang = @lang.by_key("Go").unwrap()
  let c = count_source(lang, "package main\n\nfunc main() {}\n")
  assert_eq(c.lines, 3)
  assert_eq(c.code, 2)
  assert_eq(c.blanks, 1)
}

///|
test "no trailing newline" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "int x;")
  assert_eq(c.lines, 1)
  assert_eq(c.code, 1)
}

///|
test "block comment closed on same line" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "/* one line */\n")
  assert_eq(c.comments, 1)
  assert_eq(c.code, 0)
}

///|
test "code before and after comment" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "int a; /* c */ int b;\n")
  assert_eq(c.code, 1)
  assert_eq(c.comments, 0)
}

///|
test "utf8 content does not break counting" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "// 中文注释\nint x; // 日本語\n")
  // One line is classified once: line 1 is a comment line, line 2 is a
  // code line even though it has a trailing comment (tokei semantics).
  assert_eq(c.comments, 1)
  assert_eq(c.code, 1)
}

///|
test "files count is one per call" {
  let lang = @lang.by_key("C").unwrap()
  let c = count_source(lang, "int x;\n")
  assert_eq(c.files, 1)
}

///|
test "HTML embedded-language marker is not a comment" {
  let lang = @lang.by_key("Html").unwrap()
  let c = count_source(lang, "<script>\n</script>\n")
  assert_eq(c.code, 2)
  assert_eq(c.comments, 0)
}

///|
test "Rust raw string keeps comment markers as code" {
  let lang = @lang.by_key("Rust").unwrap()
  let c = count_source(lang, "let s = r#\"start\n// still string\nend\"#;\n")
  assert_eq(c.code, 3)
  assert_eq(c.comments, 0)
}

///|
test "Python triple quoted string keeps hash as code" {
  let lang = @lang.by_key("Python").unwrap()
  let c = count_source(lang, "s = \"\"\"start\n# still string\nend\"\"\"\n")
  assert_eq(c.code, 3)
  assert_eq(c.comments, 0)
}

///|
test "Forth block marker needs content after its trailing space" {
  let lang = @lang.by_key("Forth").unwrap()
  let lone_marker = count_source(lang, "( \ninside\n)\n")
  assert_eq(lone_marker.code, 3)
  assert_eq(lone_marker.comments, 0)
  let comment = count_source(lang, "( hello\ninside\n)\n")
  assert_eq(comment.code, 0)
  assert_eq(comment.comments, 3)
}

///|
test "aggregate copy does not change first file report" {
  let lang = @lang.by_key("Rust").unwrap()
  let first = count_source(lang, "fn first() {}\n")
  let aggregate = first.copy()
  aggregate.add(count_source(lang, "// second\n"))
  assert_eq(first.code, 1)
  assert_eq(first.comments, 0)
  assert_eq(aggregate.code, 1)
  assert_eq(aggregate.comments, 1)
}

///|
test "plain text and Markdown count prose as comments" {
  for key in ["Text", "Markdown"] {
    let lang = @lang.by_key(key).unwrap()
    let c = count_source(lang, "A line of prose\n\nAnother line\n")
    assert_eq(c.code, 0)
    assert_eq(c.comments, 2)
    assert_eq(c.blanks, 1)
  }
}

///|
test "Jupyter counts code and Markdown as child languages" {
  let lang = @lang.by_key("Jupyter").unwrap()
  let source = "{\"metadata\":{\"kernelspec\":{\"language\":\"python\"},\"language_info\":{\"name\":\"python\"}},\"cells\":[{\"cell_type\":\"code\",\"source\":[\"# a comment\\n\",\"print(1)\\n\",\"\\n\"]},{\"cell_type\":\"markdown\",\"source\":[\"# Heading\\n\",\"Some prose\\n\"]}]}"
  let counts = count_source(lang, source)
  assert_eq(counts.code, 0)
  assert_eq(counts.comments, 0)
  assert_eq(counts.blanks, 0)
  let python = counts.blobs.get("Python").unwrap()
  assert_eq(python.code, 1)
  assert_eq(python.comments, 1)
  assert_eq(python.blanks, 1)
  let markdown = counts.blobs.get("Markdown").unwrap()
  assert_eq(markdown.code, 0)
  assert_eq(markdown.comments, 2)
}

///|
test "Jupyter metadata follows upstream kernel precedence" {
  let lang = @lang.by_key("Jupyter").unwrap()
  let cells = "\"cells\":[{\"cell_type\":\"code\",\"source\":[\"let x = 1\\n\"]},{\"cell_type\":\"markdown\",\"source\":[\"notes\\n\"]}]"
  let missing_kernel = count_source(
    lang,
    "{\"metadata\":{\"language_info\":{\"name\":\"python\"}}," + cells + "}",
  )
  assert_eq(missing_kernel.blobs.is_empty(), true)
  let different_hints = count_source(
    lang,
    "{\"metadata\":{\"kernelspec\":{\"language\":\"rust\"},\"language_info\":{\"name\":\"python\"}}," +
    cells +
    "}",
  )
  assert_eq(different_hints.blobs.get("Rust").unwrap().code, 1)
  assert_eq(different_hints.blobs.get("Python") is None, true)
}

///|
test "every imported line comment delimiter has a basic counting fixture" {
  for lang in @lang.all_languages() {
    for marker in lang.line_comments {
      let c = count_source(lang, normalize_token(marker) + " a comment\n")
      if c.comments != 1 || c.code != 0 {
        abort("line comment fixture failed: " + lang.key + " / " + marker)
      }
    }
  }
}

///|
test "every imported block comment delimiter has a basic counting fixture" {
  for lang in @lang.all_languages() {
    for pair in lang.block_comments {
      let c = count_source(
        lang,
        normalize_token(pair.0) + " a comment " + normalize_token(pair.1) + "\n",
      )
      if c.comments != 1 || c.code != 0 {
        abort("block comment fixture failed: " + lang.key + " / " + pair.0)
      }
    }
  }
}
