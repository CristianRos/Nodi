import birdie
import filepath
import gleam/list
import gleam/string
import gleeunit
import nodi
import nodi/internal/ast
import nodi/internal/error
import nodi/internal/gleam
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

// ---- Test utils ---------------------------------------
pub fn generate_fixture_snapshot(from path: String) -> String {
  let fixtures_base_path = "test/fixtures/"
  let path = fixtures_base_path <> path
  let raw_name = filepath.strip_extension(filepath.base_name(path))
  let assert Ok(source) = simplifile.read(from: path)

  let nodi =
    string.concat([
      ">> " <> raw_name <> ".nodi",
      "\n",
      source,
    ])

  case nodi.generate_file(path) {
    Ok(#(output_path, generated)) -> {
      let assert Ok(Nil) = nodi.write_file(to: output_path, with: generated)
      let assert Ok(formatted) = simplifile.read(output_path)

      string.concat([
        nodi,
        "\n\n",
        ">> " <> raw_name <> ".gleam",
        "\n",
        formatted,
      ])
    }
    Error(err) -> {
      string.concat([
        nodi,
        "\n\n",
        ">> Error trying to generate: " <> raw_name <> ".gleam",
        "\n",
        error.describe_error(err),
      ])
    }
  }
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
    <> case ast.declaration(name) {
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
    <> case ast.metadata(input) {
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
    <> case ast.body(input) {
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
    <> case ast.template(name, nodi) {
      Ok(t) -> "valid: " <> string.inspect(t)
      Error(err) -> "invalid: " <> string.inspect(err)
    }
  })
  |> string.join("\n")
  |> birdie.snap(title: "template constructor validation")
}

// ---- Golden integration tests ----------------------------------------

pub fn zero_slots_golden_test() {
  generate_fixture_snapshot("zero_slots.nodi")
  |> birdie.snap(title: "zero slots golden test")
}

pub fn required_only_golden_test() {
  generate_fixture_snapshot("required_only.nodi")
  |> birdie.snap(title: "required only golden test")
}

pub fn two_required_golden_test() {
  generate_fixture_snapshot("two_required.nodi")
  |> birdie.snap(title: "two required golden test")
}

pub fn optional_only_golden_test() {
  generate_fixture_snapshot("optional_only.nodi")
  |> birdie.snap(title: "optional only golden test")
}

pub fn two_optionals_golden_test() {
  generate_fixture_snapshot("two_optionals.nodi")
  |> birdie.snap(title: "two optionals golden test")
}

pub fn both_declarations_golden_test() {
  generate_fixture_snapshot("both_declarations.nodi")
  |> birdie.snap(title: "both declarations golden test")
}

pub fn declaration_with_whitespaces_golden_test() {
  generate_fixture_snapshot("declaration_with_whitespaces.nodi")
  |> birdie.snap(title: "declaration with whitespaces golden test")
}

pub fn repeated_slot_ref_golden_test() {
  generate_fixture_snapshot("repeated_slot_ref.nodi")
  |> birdie.snap(title: "repeated slot ref golden test")
}

pub fn reverse_declarations_golden_test() {
  generate_fixture_snapshot("reverse_declarations.nodi")
  |> birdie.snap(title: "reverse declarations golden test")
}

pub fn invalid_file_golden_test() {
  generate_fixture_snapshot("invalid/invalid_file.nodi")
  |> birdie.snap(title: "invalid file golden test")
}
