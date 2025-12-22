///|
test "comments-and-empty" {
  let content =
    #|# comment
    #|
    #|  
    #|*.log
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("a.log"), content="true")
  inspect(gi.is_ignored("a.txt"), content="false")
}

///|
test "negation" {
  let content =
    #|*.log
    #|!important.log
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("a.log"), content="true")
  inspect(gi.is_ignored("important.log"), content="false")
}

///|
test "anchored-and-slashed" {
  let content =
    #|/foo
    #|a/b
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("foo"), content="true")
  inspect(gi.is_ignored("x/foo"), content="false")
  inspect(gi.is_ignored("foo/bar"), content="true")
  inspect(gi.is_ignored("a/b"), content="true")
  inspect(gi.is_ignored("x/a/b"), content="false")
}

///|
test "double-star" {
  let content =
    #|**/foo
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("foo"), content="true")
  inspect(gi.is_ignored("a/foo"), content="true")
  inspect(gi.is_ignored("a/b/foo"), content="true")
  inspect(gi.is_ignored("a/food"), content="false")
}

///|
test "char-class" {
  let content =
    #|[a-c].txt
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("a.txt"), content="true")
  inspect(gi.is_ignored("b.txt"), content="true")
  inspect(gi.is_ignored("d.txt"), content="false")
}

///|
test "escaped-leading" {
  let content =
    #|\#not-comment
    #|\!not-negation
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("#not-comment"), content="true")
  inspect(gi.is_ignored("!not-negation"), content="true")
}

///|
test "directory-only" {
  let content =
    #|build/
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("build", is_dir=true), content="true")
  inspect(gi.is_ignored("build", is_dir=false), content="false")
  inspect(gi.is_ignored("build/out.txt"), content="true")
}

///|
test "why" {
  let content =
    #|*.log
    #|!important.log
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.why("a.log").unwrap(), content="*.log")
  inspect(gi.why("important.log").unwrap(), content="!important.log")
}

///|
test "unignore-requires-parent-dir" {
  let content =
    #|foo/
    #|!foo/bar.txt
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("foo/bar.txt"), content="true")
}

///|
test "unignore-parent-dir-then-file" {
  let content =
    #|foo/
    #|!foo/
    #|!foo/bar.txt
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("foo/bar.txt"), content="false")
}

///|
test "char-class-leading-close-bracket" {
  let content =
    #|[]].txt
    #|
  let gi = @gitignore.GitIgnore::parse(content)
  inspect(gi.is_ignored("].txt"), content="true")
  inspect(gi.is_ignored("a.txt"), content="false")
}
