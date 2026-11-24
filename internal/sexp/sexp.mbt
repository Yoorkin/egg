///|
/// The position is a zero-based offset in Unicode code points.
priv suberror ParseError {
  InvalidSyntax(position~ : Int32, String)
}

///|
pub struct Symbol {
  text : String
  quoted : Bool
}

///|
priv struct Parser {
  chars : Array[Char]
  mut position : Int32
}

///|
fn Parser::peek(self : Parser) -> Char? {
  self.chars.get(self.position)
}

///|
fn Parser::skip_space(self : Parser) -> Unit {
  while self.peek() is Some(ch) && ch.is_whitespace() {
    self.position += 1
  }
}

///|
fn is_bare_char(ch : Char) -> Bool {
  !ch.is_whitespace() && ch != '(' && ch != ')' && ch != '"'
}

///|
fn Parser::symbol(self : Parser) -> Symbol raise ParseError {
  let position = self.position
  let text = StringBuilder()
  if self.peek() is Some('"') {
    self.position += 1
    while self.peek() is Some(ch) {
      self.position += 1
      match ch {
        '"' => {
          if self.peek() is Some(next) && (is_bare_char(next) || next == '"') {
            raise InvalidSyntax(
              position=self.position,
              "expected a symbol separator",
            )
          }
          return { text: text.to_string(), quoted: true, }
        }
        '\\' => {
          let escaped = match self.peek() {
            Some('n') => '\n'
            Some('r') => '\r'
            Some('t') => '\t'
            Some('"') => '"'
            Some('\\') => '\\'
            _ => raise InvalidSyntax(position=self.position, "invalid escape")
          }
          text.write_char(escaped)
          self.position += 1
        }
        _ => text.write_char(ch)
      }
    }
    raise InvalidSyntax(position~, "unterminated quoted symbol")
  }
  while self.peek() is Some(ch) && is_bare_char(ch) {
    text.write_char(ch)
    self.position += 1
  }
  if self.position == position {
    raise InvalidSyntax(position~, "expected an operator or atom")
  }
  if self.peek() is Some('"') {
    raise InvalidSyntax(position=self.position, "expected a symbol separator")
  }
  { text: text.to_string(), quoted: false, }
}

///|
fn[T] Parser::term(
  self : Parser,
  build : (Symbol, ArrayView[T]) -> T,
) -> T raise ParseError {
  self.skip_space()
  if self.peek() is Some('(') {
    let position = self.position
    self.position += 1
    self.skip_space()
    let op = self.symbol()
    let children = []
    self.skip_space()
    while self.peek() is Some(ch) && ch != ')' {
      children.push(self.term(build))
      self.skip_space()
    }
    guard self.peek() is Some(')') else {
      raise InvalidSyntax(position~, "unclosed expression")
    }
    self.position += 1
    build(op, children)
  } else {
    build(self.symbol(), [])
  }
}

///|
fn[T] parse_one(
  input : String,
  build : (Symbol, ArrayView[T]) -> T,
) -> T raise ParseError {
  let parser = { chars: [ for ch in input => ch ], position: 0, }
  let term = parser.term(build)
  parser.skip_space()
  if parser.peek() is Some(_) {
    raise InvalidSyntax(position=parser.position, "unexpected trailing input")
  }
  term
}

///|
pub fn[T] parse(
  input : String,
  build : (Symbol, ArrayView[T]) -> T,
) -> Result[T, (Int32, String)] {
  try parse_one(input, build) catch {
    InvalidSyntax(position~, message) => Err((position, message))
  } noraise {
    value => Ok(value)
  }
}

///|
pub fn write_symbol(out : StringBuilder, symbol : String) -> Unit {
  let mut quote = symbol.is_empty()
  for ch in symbol {
    if !is_bare_char(ch) {
      quote = true
      break
    }
  }
  if !quote {
    out.write_string(symbol)
    return
  }
  out.write_char('"')
  for ch in symbol {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.write_char('"')
}
