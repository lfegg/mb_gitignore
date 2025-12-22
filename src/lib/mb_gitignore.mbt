///|
priv enum CharClassItem {
  Single(Char)
  Range(Char, Char)
}

///|
priv enum Token {
  Lit(Char)
  Star
  DoubleStar
  QMark
  Class(negated~ : Bool, items~ : Array[CharClassItem])
}

///|
struct Rule {
  negated : Bool
  directory_only : Bool
  anchored : Bool
  has_slash : Bool
  tokens : Array[Token]
  raw : String
}

///|
pub struct GitIgnore {
  base : String
  rules : Array[Rule]
}

///|
fn to_chars(s : String) -> Array[Char] {
  s.iter().collect()
}

///|
fn from_chars(chars : Array[Char]) -> String {
  String::from_iter(chars.iter())
}

///|
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
  // strip trailing slashes
  while buf.length() > 0 && buf[buf.length() - 1] == '/' {
    ignore(buf.pop())
  }
  // strip leading "./" (repeat) and leading slashes
  let mut start = 0
  while start + 1 < buf.length() && buf[start] == '.' && buf[start + 1] == '/' {
    start = start + 2
  }
  while start < buf.length() && buf[start] == '/' {
    start = start + 1
  }
  if start == 0 {
    return from_chars(buf)
  }
  let out = []
  for i = start; i < buf.length(); i = i + 1 {
    out.push(buf[i])
  }
  from_chars(out)
}

///|
fn basename(path : String) -> String {
  let mut last = ""
  for part in path.split("/") {
    last = part.to_string()
  }
  last
}

///|
fn strip_cr(line : String) -> String {
  line.trim_end(chars="\r").to_string()
}

///|
fn strip_trailing_spaces_unless_escaped(chars : Array[Char]) -> Array[Char] {
  if chars.length() == 0 {
    return chars
  }
  let mut end = chars.length() - 1
  while true {
    if chars[end] != ' ' && chars[end] != '\t' {
      break
    }
    let mut bs = 0
    let mut i = end - 1
    while i >= 0 && chars[i] == '\\' {
      bs = bs + 1
      if i == 0 {
        break
      }
      i = i - 1
    }
    if bs % 2 == 1 {
      break
    }
    if end == 0 {
      return []
    }
    end = end - 1
  }
  let out = []
  for i = 0; i <= end; i = i + 1 {
    out.push(chars[i])
  }
  out
}

///|
fn is_escaped_at(chars : Array[Char], idx : Int) -> Bool {
  if idx <= 0 {
    return false
  }
  let mut bs = 0
  let mut i = idx - 1
  while i >= 0 && chars[i] == '\\' {
    bs = bs + 1
    if i == 0 {
      break
    }
    i = i - 1
  }
  bs % 2 == 1
}

///|
fn parse_char_class(chars : Array[Char], start : Int) -> (Token, Int) {
  // chars[start] == '['
  let mut first = start + 1
  if first < chars.length() && (chars[first] == '!' || chars[first] == '^') {
    first = first + 1
  }
  let mut i = first + 1
  let mut close = -1
  while i < chars.length() {
    if chars[i] == ']' && !is_escaped_at(chars, i) {
      close = i
      break
    }
    i = i + 1
  }
  if close == -1 {
    return (Lit('['), start + 1)
  }
  let mut neg = false
  let mut j = start + 1
  if j < close && (chars[j] == '!' || chars[j] == '^') {
    neg = true
    j = j + 1
  }
  let items = []
  let mut prev : Char? = None
  while j < close {
    let mut ch = chars[j]
    if ch == '\\' && j + 1 < close {
      ch = chars[j + 1]
      j = j + 2
    } else {
      j = j + 1
    }
    if ch == '-' && prev is Some(p) && j < close {
      // range
      let mut endch = chars[j]
      if endch == '\\' && j + 1 < close {
        endch = chars[j + 1]
        j = j + 2
      } else {
        j = j + 1
      }
      ignore(items.pop())
      let a = p.to_int()
      let b = endch.to_int()
      if a <= b {
        items.push(Range(p, endch))
      } else {
        items.push(Range(endch, p))
      }
      prev = Some(endch)
    } else {
      items.push(Single(ch))
      prev = Some(ch)
    }
  }
  (Class(negated=neg, items~), close + 1)
}

///|
fn tokenize(pattern : Array[Char]) -> Array[Token] {
  let tokens = []
  let mut i = 0
  while i < pattern.length() {
    match pattern[i] {
      '\\' =>
        if i + 1 < pattern.length() {
          tokens.push(Lit(pattern[i + 1]))
          i = i + 2
        } else {
          tokens.push(Lit('\\'))
          i = i + 1
        }
      '*' =>
        if i + 1 < pattern.length() && pattern[i + 1] == '*' {
          tokens.push(DoubleStar)
          i = i + 2
        } else {
          tokens.push(Star)
          i = i + 1
        }
      '?' => {
        tokens.push(QMark)
        i = i + 1
      }
      '[' => {
        let (tok, next) = parse_char_class(pattern, i)
        tokens.push(tok)
        i = next
      }
      ch => {
        tokens.push(Lit(ch))
        i = i + 1
      }
    }
  }
  tokens
}

///|
fn class_contains(items : Array[CharClassItem], ch : Char) -> Bool {
  let c = ch.to_int()
  for item in items.iter() {
    match item {
      Single(x) => if x == ch { return true }
      Range(a, b) => {
        let lo = a.to_int()
        let hi = b.to_int()
        if lo <= c && c <= hi {
          return true
        }
      }
    }
  }
  false
}

///|
fn wildmatch(tokens : Array[Token], text : Array[Char]) -> Bool {
  let tlen = tokens.length()
  let slen = text.length()
  let stride = slen + 1
  let memo = Array::make((tlen + 1) * (slen + 1), -1)
  fn go(ti : Int, si : Int) -> Bool {
    let idx = ti * stride + si
    if memo[idx] != -1 {
      return memo[idx] == 1
    }
    let res = if ti == tlen {
      si == slen
    } else {
      match tokens[ti] {
        Lit(c) => si < slen && text[si] == c && go(ti + 1, si + 1)
        QMark => si < slen && text[si] != '/' && go(ti + 1, si + 1)
        Star =>
          go(ti + 1, si) || (si < slen && text[si] != '/' && go(ti, si + 1))
        DoubleStar => {
          let skip_slash = if ti + 1 < tlen {
            match tokens[ti + 1] {
              Lit('/') => go(ti + 2, si)
              _ => false
            }
          } else {
            false
          }
          skip_slash || go(ti + 1, si) || (si < slen && go(ti, si + 1))
        }
        Class(negated~, items~) =>
          if si >= slen || text[si] == '/' {
            false
          } else {
            let hit = class_contains(items, text[si])
            let ok = if negated { !hit } else { hit }
            ok && go(ti + 1, si + 1)
          }
      }
    }
    memo[idx] = if res { 1 } else { 0 }
    res
  }

  go(0, 0)
}

///|
fn parse_rule_line(line : String) -> Rule? {
  let line = strip_cr(line)
  let chars0 = to_chars(line)
  let chars = strip_trailing_spaces_unless_escaped(chars0)
  if chars.length() == 0 {
    return None
  }
  if chars[0] == '#' {
    return None
  }
  let mut idx = 0
  let mut negated = false
  if chars[0] == '!' {
    negated = true
    idx = 1
  }
  let mut directory_only = false
  let mut end = chars.length()
  if end > idx && chars[end - 1] == '/' && !is_escaped_at(chars, end - 1) {
    directory_only = true
    end = end - 1
  }
  if end <= idx {
    return None
  }
  let mut anchored = false
  if chars[idx] == '/' {
    anchored = true
    idx = idx + 1
  }
  if end <= idx {
    return None
  }
  let mut has_slash = false
  for i = idx; i < end; i = i + 1 {
    if chars[i] == '/' {
      has_slash = true
      break
    }
  }
  let pat = []
  for i = idx; i < end; i = i + 1 {
    pat.push(chars[i])
  }
  let tokens = tokenize(pat)
  let raw = from_chars(chars)
  Some({ negated, directory_only, anchored, has_slash, tokens, raw })
}

///|
pub fn GitIgnore::new(base? : String = "") -> GitIgnore {
  { base: normalize_path(base), rules: [] }
}

///|
pub fn GitIgnore::parse(content : String, base? : String = "") -> GitIgnore {
  let gi = GitIgnore::new(base~)
  for line in content.split("\n").map(StringView::to_string) {
    if parse_rule_line(line) is Some(rule) {
      gi.rules.push(rule)
    }
  }
  gi
}

///|
fn GitIgnore::rel_path(self : GitIgnore, path : String) -> String? {
  let base = self.base
  let path = normalize_path(path)
  if base == "" {
    return Some(path)
  }
  if path == base {
    return Some("")
  }
  let prefix = base + "/"
  if path.has_prefix(prefix) {
    Some(path.strip_prefix(prefix).unwrap().to_string())
  } else {
    None
  }
}

///|
fn Rule::matches(self : Rule, rel_path : String, is_dir : Bool) -> Bool {
  if self.directory_only && !is_dir {
    return false
  }
  if self.has_slash {
    return wildmatch(self.tokens, to_chars(rel_path))
  }
  if self.anchored {
    if rel_path.contains_char('/') {
      return false
    }
    return wildmatch(self.tokens, to_chars(rel_path))
  }
  wildmatch(self.tokens, to_chars(basename(rel_path)))
}

///|
fn GitIgnore::is_ignored_rel(
  self : GitIgnore,
  rel_path : String,
  is_dir : Bool,
) -> Bool {
  let mut ignored = false
  for rule in self.rules.iter() {
    if rule.matches(rel_path, is_dir) {
      ignored = !rule.negated
    }
  }
  ignored
}

///|
fn GitIgnore::why_rel(
  self : GitIgnore,
  rel_path : String,
  is_dir : Bool,
) -> String? {
  let mut last : String? = None
  for rule in self.rules.iter() {
    if rule.matches(rel_path, is_dir) {
      last = Some(rule.raw)
    }
  }
  last
}

///|
pub fn GitIgnore::is_ignored(
  self : GitIgnore,
  path : String,
  is_dir? : Bool = false,
) -> Bool {
  let rel = self.rel_path(path)
  if rel is None {
    return false
  }
  let rel = rel.unwrap()
  if rel == "" {
    return self.is_ignored_rel(rel, is_dir)
  }
  let parts = rel.split("/").map(StringView::to_string).collect()
  let limit = if is_dir { parts.length() } else { parts.length() - 1 }
  if limit > 0 {
    let mut prefix = parts[0]
    if self.is_ignored_rel(prefix, true) {
      return true
    }
    for i in 1..<limit {
      prefix = prefix + "/" + parts[i]
      if self.is_ignored_rel(prefix, true) {
        return true
      }
    }
  }
  self.is_ignored_rel(rel, is_dir)
}

///|
pub fn GitIgnore::why(
  self : GitIgnore,
  path : String,
  is_dir? : Bool = false,
) -> String? {
  let rel = self.rel_path(path)
  if rel is None {
    return None
  }
  let rel = rel.unwrap()
  if rel == "" {
    return self.why_rel(rel, is_dir)
  }
  let parts = rel.split("/").map(StringView::to_string).collect()
  let limit = if is_dir { parts.length() } else { parts.length() - 1 }
  if limit > 0 {
    let mut prefix = parts[0]
    if self.is_ignored_rel(prefix, true) {
      return self.why_rel(prefix, true)
    }
    for i in 1..<limit {
      prefix = prefix + "/" + parts[i]
      if self.is_ignored_rel(prefix, true) {
        return self.why_rel(prefix, true)
      }
    }
  }
  self.why_rel(rel, is_dir)
}
