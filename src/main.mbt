///|
fn main {
  fn usage() -> Unit {
    println(
      "Usage: moon run src -- <PATH> [--dir|--file] [--gitignore <FILE>] [--exclude <FILE> ...] [--no-info-exclude|--info-exclude <FILE>]",
    )
    println("Note: <PATH> is treated as repo-relative by default.")
  }

  fn normalize_path(path : String) -> String {
    let buf = []
    let mut prev_slash = false
    for ch in path.iter() {
      let ch = if ch == '\\' { '/' } else { ch }
      if ch == '/' {
        if !prev_slash {
          buf.push('/')
          prev_slash = true
        }
      } else {
        buf.push(ch)
        prev_slash = false
      }
    }
    while buf.length() > 0 && buf[buf.length() - 1] == '/' {
      ignore(buf.pop())
    }
    let mut start = 0
    while start + 1 < buf.length() && buf[start] == '.' && buf[start + 1] == '/' {
      start = start + 2
    }
    while start < buf.length() && buf[start] == '/' {
      start = start + 1
    }
    let out = []
    for i = start; i < buf.length(); i = i + 1 {
      out.push(buf[i])
    }
    String::from_iter(out.iter())
  }

  fn read_file_opt(path : String) -> String? {
    Some(@fs.read_file_to_string(path)) catch {
      (_ : @fs.IOError) => None
    }
  }

  let args = @sys.get_cli_args()
  if args.length() < 2 {
    usage()
    @sys.exit(2)
  }
  let mut gitignore_path = ".gitignore"
  let mut gitignore_specified = false
  let excludes : Array[String] = []
  let mut use_info_exclude = true
  let mut info_exclude_path = ".git/info/exclude"
  let mut is_dir_opt : Bool? = None
  let mut target_path : String? = None
  let mut i = 1
  while i < args.length() {
    let a = args[i]
    match a {
      "-h" | "--help" => {
        usage()
        @sys.exit(0)
      }
      "-g" | "--gitignore" =>
        if i + 1 >= args.length() {
          println("error: missing value for --gitignore")
          usage()
          @sys.exit(2)
        } else {
          gitignore_path = args[i + 1]
          gitignore_specified = true
          i = i + 2
          continue
        }
      "--exclude" =>
        if i + 1 >= args.length() {
          println("error: missing value for --exclude")
          usage()
          @sys.exit(2)
        } else {
          excludes.push(args[i + 1])
          i = i + 2
          continue
        }
      "--no-info-exclude" => {
        use_info_exclude = false
        i = i + 1
      }
      "--info-exclude" =>
        if i + 1 >= args.length() {
          println("error: missing value for --info-exclude")
          usage()
          @sys.exit(2)
        } else {
          info_exclude_path = args[i + 1]
          use_info_exclude = true
          i = i + 2
          continue
        }
      "--dir" => {
        is_dir_opt = Some(true)
        i = i + 1
      }
      "--file" => {
        is_dir_opt = Some(false)
        i = i + 1
      }
      _ =>
        if target_path is None {
          target_path = Some(a)
          i = i + 1
        } else {
          println(("error: unexpected extra argument", a))
          usage()
          @sys.exit(2)
        }
    }
  }
  if target_path is None {
    println("error: missing <PATH>")
    usage()
    @sys.exit(2)
  }
  let target_path = target_path.unwrap()
  let is_dir = if is_dir_opt is Some(b) {
    b
  } else {
    @fs.is_dir(target_path) catch {
      (_ : @fs.IOError) => false
    }
  }
  if gitignore_specified {
    let content_opt : String? = Some(@fs.read_file_to_string(gitignore_path)) catch {
      (e : @fs.IOError) => {
        println(("error: failed to read gitignore file", gitignore_path, e))
        None
      }
    }
    if content_opt is None {
      @sys.exit(2)
    }
    let gi = @gitignore.GitIgnore::parse(content_opt.unwrap())
    let ignored = gi.is_ignored(target_path, is_dir~)
    let reason = gi.why(target_path, is_dir~)
    println((target_path, ignored, reason))
    @sys.exit(if ignored { 0 } else { 1 })
  }
  let chain = @gitignore.GitIgnoreChain::new()

  // Extra excludes (user-specified), applied first.
  for p in excludes.iter() {
    if read_file_opt(p) is Some(content) {
      chain.parse_and_push(content)
    }
  }

  // .git/info/exclude, applied before per-dir .gitignore.
  if use_info_exclude {
    if read_file_opt(info_exclude_path) is Some(content) {
      chain.parse_and_push(content)
    }
  }
  if read_file_opt(".gitignore") is Some(root) {
    chain.parse_and_push(root)
  }
  let rel = normalize_path(target_path)
  if rel != "" {
    let parts : Array[String] = rel
      .split("/")
      .map(StringView::to_string)
      .collect()
    let limit = if is_dir { parts.length() } else { parts.length() - 1 }
    if limit > 0 {
      let mut prefix = ""
      for i = 0; i < limit; i = i + 1 {
        prefix = if prefix == "" { parts[i] } else { prefix + "/" + parts[i] }
        if chain.is_ignored(prefix, is_dir=true) {
          break
        }
        let gitignore_in_dir = prefix + "/.gitignore"
        if read_file_opt(gitignore_in_dir) is Some(content) {
          chain.parse_and_push(content, base=prefix)
        }
      }
    }
  }
  let ignored = chain.is_ignored(target_path, is_dir~)
  let reason = chain.why(target_path, is_dir~)
  println((target_path, ignored, reason))
  @sys.exit(if ignored { 0 } else { 1 })
}
