pub type DeclarationWithWhitespaces {
  DeclarationWithWhitespaces(foo: String, bar: String, baz: String)
}

pub fn new(
  foo: String,
  bar: String,
  baz: String,
) -> DeclarationWithWhitespaces {
  DeclarationWithWhitespaces(foo:, bar:, baz:)
}

pub fn to_string(
  declaration_with_whitespaces: DeclarationWithWhitespaces,
) -> String {
  "
<div>
    " <> declaration_with_whitespaces.foo <> "
    " <> declaration_with_whitespaces.bar <> "
    " <> declaration_with_whitespaces.baz <> "
</div>"
}
