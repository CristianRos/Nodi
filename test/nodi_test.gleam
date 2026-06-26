import birdie
import gleam/list
import gleam/string
import gleeunit
import nodi/internal/gleam

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn slot_declaration_validation_test() {
  [
    // Valid
    "snake_case",
    "snake_case2",
    // Invalid
    "_",
    "_discard",
    "kebab-case",
    "PascalCase",
    "1foo",
    "foo bar",
    "foo@bar",
  ]
  |> list.map(fn(name) {
    name
    <> " -> "
    <> case gleam.value_identifier(name) {
      Ok(_) -> "valid"
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "slot declaration validation")
}
