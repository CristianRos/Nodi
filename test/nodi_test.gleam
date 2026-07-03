import birdie
import gleam/list
import gleam/string
import gleeunit
import nodi/internal/gleam
import nodi/internal/template

pub fn main() -> Nil {
  gleeunit.main()
}

// ---- Gleam Identifier tests ---------------------------

pub fn value_identifier_validation_test() {
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
    "",
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
  |> birdie.snap(title: "value identifier validation")
}

pub fn type_identifier_validation_test() {
  [
    // Valid
    "PascalCase",
    "PascalCase2",
    // Invalid
    "_",
    "_Discard",
    "snake_case",
    "kebab-case",
    "Pascal_Case",
    "1Foo",
    "Foo Bar",
    "",
  ]
  |> list.map(fn(name) {
    name
    <> " -> "
    <> case gleam.type_identifier(name) {
      Ok(_) -> "valid"
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "type identifier validation")
}

// ---- Template validation tests ---------------------------

pub fn declaration_test() {
  [
    // Valid
    "req=foo",
    "req=foo,bar",
    "req=foo , bar , baz",
    "opt=wibble",
    "opt=wibble,wobble",
    // Invalid
    "req=",
    "opt=",
    "req",
    "opt",
    "xyz=foo",
    "req=_discard",
    "req=Foo",
  ]
  |> list.map(fn(name) {
    name
    <> " -> "
    <> case template.declaration(name) {
      Ok(decl) -> "valid: " <> string.inspect(decl)
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "declaration constructor validation")
}

pub fn metadata_test() {
  [
    // Valid
    "req=foo,bar",
    "opt=baz",
    "req=foo,bar\nopt=baz",
    // Invalid
    "req=foo\nreq=bar",
    "req=foo\nopt=foo",
    "req=foo,foo",
    "req=foo\nxyz=bar",
  ]
  |> list.map(fn(input) {
    string.replace(input, "\n", " ⏎ ")
    <> " -> "
    <> case template.metadata(input) {
      Ok(meta) -> "valid: " <> string.inspect(meta)
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "metadata constructor validation")
}

pub fn body_test() {
  [
    // Valid
    "just plain text, no slots here",
    "hello <% name %>!",
    "<% name %> says hello",
    "hello <% name %>",
    "<% first %><% second %>",
    "hello %> name <% foo %>",
    "",
    // Invalid
    "hello <% name",
    "hello <% 1bad %>",
    "hello %> name <%",
  ]
  |> list.map(fn(input) {
    input
    <> " -> "
    <> case template.body(input) {
      Ok(nodes) -> "valid: " <> string.inspect(nodes)
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "body constructor validation")
}

pub fn template_test() {
  [
    #("greeting", "req=foo\n---\nhello <% foo %>"),
    #("plain", "just static text, no slots, no separator"),
    #("1bad", "req=foo\n---\nhello <% foo %>"),
    #("oops", "req=foo\n---\nhello <% foo %><% bar %>"),
    #("unused", "req=foo,bar\n---\nhello <% foo %>"),
    #("separator_no_meta", "---\nhello, just text"),
  ]
  |> list.map(fn(pair) {
    let #(name, nodi) = pair
    name
    <> " | "
    <> string.replace(nodi, "\n", " ⏎ ")
    <> " -> "
    <> case template.template(name, nodi) {
      Ok(t) -> "valid: " <> string.inspect(t)
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "template constructor validation")
}
