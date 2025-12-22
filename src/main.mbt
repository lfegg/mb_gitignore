///|
fn main {
  fn usage() -> Unit {
    println("Usage: moon run src -- <PATH> [--dir|--file] [--gitignore <FILE>]")
    println("Note: <PATH> is treated as repo-relative by default.")
  }

  let args = @sys.get_cli_args()
  if args.length() < 2 {
    usage()
    @sys.exit(2)
  }
  let mut gitignore_path = ".gitignore"
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
  let is_dir = if is_dir_opt is Some(b) {
    b
  } else {
    @fs.is_dir(target_path) catch {
      (_ : @fs.IOError) => false
    }
  }
  let ignored = gi.is_ignored(target_path, is_dir~)
  let reason = gi.why(target_path, is_dir~)
  println((target_path, ignored, reason))
  @sys.exit(if ignored { 0 } else { 1 })
}
