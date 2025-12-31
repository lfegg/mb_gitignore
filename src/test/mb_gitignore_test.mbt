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

///|
test "chain-layer-overrides" {
  let root =
    #|*.log
    #|
  let sub =
    #|!keep.log
    #|
  let chain = @gitignore.GitIgnoreChain::new()
  chain.parse_and_push(root)
  chain.parse_and_push(sub, base="a")
  inspect(chain.is_ignored("x.log"), content="true")
  inspect(chain.is_ignored("a/x.log"), content="true")
  inspect(chain.is_ignored("a/keep.log"), content="false")
  inspect(chain.why("a/keep.log").unwrap(), content="!keep.log")
}

///|
test "chain-anchored-is-per-base" {
  let root =
    #|/foo
    #|
  let sub =
    #|/foo
    #|
  let chain = @gitignore.GitIgnoreChain::new()
  chain.parse_and_push(root)
  chain.parse_and_push(sub, base="a")
  inspect(chain.is_ignored("foo"), content="true")
  inspect(chain.is_ignored("a/foo"), content="true")
  inspect(chain.is_ignored("x/foo"), content="false")
  inspect(chain.is_ignored("a/b/foo"), content="false")
}

///|
test "chain-unignore-requires-parent-dir-across-layers" {
  let root =
    #|foo/
    #|
  let sub =
    #|!bar.txt
    #|
  let chain = @gitignore.GitIgnoreChain::new()
  chain.parse_and_push(root)
  chain.parse_and_push(sub, base="foo")
  // Parent dir foo is ignored by root, so child cannot be unignored by deeper rules.
  inspect(chain.is_ignored("foo/bar.txt"), content="true")
  inspect(chain.why("foo/bar.txt").unwrap(), content="foo/")
}

///|
test "chain-unignore-parent-then-file" {
  let root =
    #|foo/
    #|!foo/
    #|
  let sub =
    #|!bar.txt
    #|
  let chain = @gitignore.GitIgnoreChain::new()
  chain.parse_and_push(root)
  chain.parse_and_push(sub, base="foo")
  inspect(chain.is_ignored("foo/bar.txt"), content="false")
  inspect(chain.why("foo/bar.txt").unwrap(), content="!bar.txt")
}
