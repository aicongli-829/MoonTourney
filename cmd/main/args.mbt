///|
/// Parsed CLI options (mirrors tokei's surface).
pub(all) struct Opts {
  paths : Array[String]
  mut format : @output.Format
  types : Array[String] // --type include filter (language keys)
  types_not : Array[String] // --type-not exclude filter
  excludes : Array[String]
  mut sort_key : String
  mut reverse : Bool
  mut hidden : Bool
  mut no_ignore : Bool
  mut no_ignore_dot : Bool
  mut no_ignore_vcs : Bool
  mut list_files : Bool // --files
  mut out_file : String? // --output-file extension; upstream -o selects format
  mut list_langs : Bool // -l
  mut show_version : Bool
  mut show_help : Bool
}

///|
const VERSION = "0.1.0"

///|
fn usage() -> String {
  (
    $|mooncake/tokei \{VERSION} — count code, comments and blanks across 300+ languages.
    $|A pure-MoonBit port of tokei (https://github.com/XAMPPRocky/tokei).
    $|
    $|USAGE:
    $|    tokei [FLAGS] [OPTIONS] [path]...
    $|
    $|ARGS:
    $|    <path>...                Files or directories to count (default: current directory)
    $|
    $|FLAGS:
    $|    -h, --help               Print this help message
    $|    -V, --version            Print version information
    $|    -l, --languages          Print supported languages and their extensions
    $|    -f, --files              Print individual file statistics
    $|        --hidden             Count hidden files
    $|        --no-ignore          Do not respect ignore files
    $|        --no-ignore-dot      Do not respect .ignore or .tokeignore
    $|        --no-ignore-vcs      Do not respect .gitignore
    $|        --no-progress        Compatibility flag (accepted, ignored)
    $|
    $|OPTIONS:
    $|    -o, --output <FORMAT>    Output format: table, json, csv, yaml (default: table)
    $|        --output-file <FILE> Write output to FILE instead of stdout
    $|    -t, --type <LANGS>       Only count the given languages (comma separated)
    $|    -T, --type-not <LANGS>   Count everything except the given languages
    $|    -e, --exclude <PATTERN>  Ignore files/directories matching PATTERN (repeatable)
    $|    -s, --sort <ORDER>       Sort by files, lines, blanks, code, comments or language
    $|    -r, --reverse            Reverse the sort order
    $|
    $|EXAMPLES:
    $|    tokei .                         # count current directory
    $|    tokei -o json --output-file stats.json .  # JSON report to file
    $|    tokei -t rust,python -s code .  # only Rust and Python, sorted by code
    $|
    $|Language definitions ported from tokei languages.json (Apache-2.0 / MIT).
  )
}

///|
fn starts_at(s : String, pos : Int32, needle : String) -> Bool {
  let n = s.length()
  let m = needle.length()
  if pos < 0 || pos + m > n {
    return false
  }
  let mut i = 0
  while i < m {
    if s.at(pos + i).to_int() != needle.at(i).to_int() {
      return false
    }
    i += 1
  }
  true
}

///|
fn fail(msg : String) -> Unit {
  println("error: " + msg)
  println("")
  println(usage())
  abort("")
}

///|
pub fn parse_args(argv : Array[String]) -> Opts {
  let opts = {
    paths: [],
    format: Table,
    types: [],
    types_not: [],
    excludes: [],
    sort_key: "language",
    reverse: false,
    hidden: false,
    no_ignore: false,
    no_ignore_dot: false,
    no_ignore_vcs: false,
    list_files: false,
    out_file: None,
    list_langs: false,
    show_version: false,
    show_help: false,
  }
  let n = argv.length()
  let mut i = 0
  while i < n {
    let arg = argv[i]
    if arg == "--" {
      let mut j = i + 1
      while j < n {
        opts.paths.push(argv[j])
        j += 1
      }
      break
    } else if arg == "-h" || arg == "--help" {
      opts.show_help = true
    } else if arg == "-V" || arg == "--version" {
      opts.show_version = true
    } else if arg == "-l" || arg == "--languages" {
      opts.list_langs = true
    } else if arg == "-r" || arg == "--reverse" {
      opts.reverse = true
    } else if arg == "--hidden" {
      opts.hidden = true
    } else if arg == "--no-ignore" {
      opts.no_ignore = true
    } else if arg == "--no-ignore-dot" {
      opts.no_ignore_dot = true
    } else if arg == "--no-ignore-vcs" {
      opts.no_ignore_vcs = true
    } else if arg == "--no-progress" {
      // accepted for compatibility; warnings are never printed
    } else if arg == "-f" || arg == "--files" {
      opts.list_files = true
    } else if arg == "-o" || arg == "--output" || arg == "--format" {
      i += 1
      if i >= n {
        fail("the argument '--output <FORMAT>' requires a value")
      }
      match argv[i] {
        "table" => opts.format = Table
        "json" => opts.format = Json
        "csv" => opts.format = Csv
        "yaml" => opts.format = Yaml
        _ => fail("unrecognized format '" + argv[i] + "'")
      }
    } else if arg == "--output-file" {
      i += 1
      if i >= n {
        fail("the argument '--output-file <FILE>' requires a value")
      }
      opts.out_file = Some(argv[i])
    } else if arg == "-t" || arg == "--type" {
      i += 1
      if i >= n {
        fail("the argument '--type <LANGS>' requires a value")
      }
      for t in split_commas(argv[i]) {
        opts.types.push(t)
      }
    } else if arg == "-T" || arg == "--type-not" {
      i += 1
      if i >= n {
        fail("the argument '--type-not <LANGS>' requires a value")
      }
      for t in split_commas(argv[i]) {
        opts.types_not.push(t)
      }
    } else if arg == "-e" || arg == "--exclude" {
      i += 1
      if i >= n {
        fail("the argument '--exclude <PATTERN>' requires a value")
      }
      opts.excludes.push(argv[i])
    } else if arg == "-s" || arg == "--sort" {
      i += 1
      if i >= n {
        fail("the argument '--sort <ORDER>' requires a value")
      }
      let k = argv[i]
      if k != "files" &&
        k != "lines" &&
        k != "blanks" &&
        k != "code" &&
        k != "comments" &&
        k != "language" {
        fail("invalid sort order '" + k + "'")
      }
      opts.sort_key = k
    } else if arg.length() > 1 && starts_at(arg, 0, "-") {
      fail("unrecognized option '" + arg + "'")
    } else {
      opts.paths.push(arg)
    }
    i += 1
  }
  opts
}

///|
fn split_commas(s : String) -> Array[String] {
  let out : Array[String] = []
  let n = s.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    if s.at(i).to_int() == 0x2C {
      let v = s[start:i].to_owned()
      if v.length() > 0 {
        out.push(v)
      }
      start = i + 1
    }
    i += 1
  }
  if start < n {
    let v = s[start:].to_owned()
    if v.length() > 0 {
      out.push(v)
    }
  }
  out
}
