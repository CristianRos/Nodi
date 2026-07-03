import gleam/list
import gleam/option.{None, Some}
import gleam/string
import justin
import nodi/internal/gleam
import nodi/internal/template.{type Node, type Template, SlotReference, Text} as _

pub fn emit_imports(has_optional has_optional: Bool) {
  case has_optional {
    True -> "import gleam/option.{type Option, Some, None}"
    False -> ""
  }
}

pub fn emit_template_type(
  template_type template_type: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> String {
  "pub type "
  <> template_type
  <> "("
  <> { optional_slots |> string.join(", ") }
  <> ") {\n"
  <> template_type
  <> "("
  <> {
    let req =
      required_slots
      |> list.map(fn(slot) { slot <> ": String" })
      |> string.join(", ")

    let opt =
      optional_slots
      |> list.map(fn(slot) { slot <> ": Option(String)" })
      |> string.join(", ")

    [req, opt] |> list.filter(fn(slots) { slots != "" }) |> string.join(", ")
  }
  <> ")\n"
  <> "}"
}

pub fn emit_optional_slot_types(
  optional_slots optional_slots: List(String),
) -> String {
  optional_slots
  |> list.map(fn(slot) {
    // NOTE(Cris): This should work as if we were validating value to string type
    // but we take the shortcut for convenience and we know these should already
    // have been validated as ValueIdentifier, so mutation should be straightforward
    let slot_type = slot |> justin.pascal_case
    "pub type No" <> slot_type <> "\n" <> "pub type Has" <> slot_type
  })
  |> string.join("\n")
}

pub fn emit_template_constructor_fn(
  template_name template_name: String,
  template_type template_type: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) {
  let has_required = !list.is_empty(required_slots)
  let has_optional = !list.is_empty(optional_slots)
  let has_slots = has_required || has_optional

  let optional_types =
    optional_slots
    |> list.map(fn(slot) { slot |> justin.pascal_case })

  "pub fn "
  <> template_name
  <> "("
  <> {
    let req =
      required_slots
      |> list.map(fn(slot) { slot <> ": String" })
      |> string.join(", ")

    let opt =
      optional_slots
      |> list.map(fn(slot) { slot <> ": Option(String)" })
      |> string.join(", ")

    [req, opt] |> list.filter(fn(slots) { slots != "" }) |> string.join(", ")
  }
  <> ") -> "
  <> {
    case has_optional {
      True ->
        template_type
        <> "("
        <> {
          {
            optional_types
            |> list.map(fn(t) { "No" <> t })
          }
          |> string.join(", ")
        }
        <> ")"
      False -> template_type
    }
  }
  <> " {\n"
  <> case has_slots {
    False -> template_type
    True ->
      template_type
      <> "("
      <> {
        let req =
          required_slots
          |> list.map(fn(slot) { slot <> ":" })
          |> string.join(", ")

        let opt =
          optional_slots
          |> list.map(fn(slot) { slot <> ": None" })
          |> string.join(", ")

        [req, opt]
        |> list.filter(fn(slots) { slots != "" })
        |> string.join(", ")
      }
      <> ")"
  }
  <> "\n}"
}

pub fn emit_optional_builder_fns(
  template_name template_name: String,
  template_type template_type: String,
  optional_slots optional_slots: List(String),
) -> String {
  optional_slots
  |> list.map(fn(slot) {
    let slot_type = slot |> justin.pascal_case

    "pub fn with_"
    <> slot
    <> "(\n"
    <> template_name
    <> ": "
    <> template_type
    <> "("
    <> {
      optional_slots
      |> list.map(fn(args) {
        case args == slot {
          True -> "No" <> slot_type
          False -> args
        }
      })
      |> string.join(", ")
    }
    <> "),\n"
    <> slot
    <> ": String,\n"
    <> ") -> "
    <> template_type
    <> "("
    <> {
      optional_slots
      |> list.map(fn(args) {
        case args == slot {
          True -> "Has" <> slot_type
          False -> args
        }
      })
      |> string.join(", ")
    }
    <> ") {\n"
    <> template_type
    <> "(.."
    <> template_name
    <> ", "
    <> slot
    <> ": Some("
    <> slot
    <> "))\n"
    <> "}"
  })
  |> string.join("\n")
}

pub fn emit_body(
  body body: List(Node),
  template_name template_name: String,
  optional_slots optional_slots: List(String),
) -> String {
  body
  |> list.map(fn(node) {
    case node {
      Text(text) ->
        "\""
        <> {
          text
          |> string.replace("\\", "\\\\")
          |> string.replace("\"", "\\\"")
        }
        <> "\""
      SlotReference(name) -> {
        let name = gleam.value_identifier_to_string(name)
        case optional_slots |> list.contains(name) {
          True -> name
          False -> template_name <> "." <> name
        }
      }
    }
  })
  |> string.join(" <> ")
}

pub fn emit_template_to_string(
  template_name template_name: String,
  template_type template_type: String,
  optional_slots optional_slots: List(String),
  body body: List(Node),
) {
  "pub fn to_string("
  <> template_name
  <> ": "
  <> template_type
  <> "("
  <> { optional_slots |> string.join(", ") }
  <> ")) -> String {\n"
  <> {
    optional_slots
    |> list.map(fn(slot) {
      "let "
      <> slot
      <> " = case "
      <> template_name
      <> "."
      <> slot
      <> " {\n"
      <> "Some(slot) -> slot\n"
      <> "None -> \"\"\n"
      <> "}"
    })
    |> string.join("\n")
  }
  <> "\n"
  <> {
    body
    |> emit_body(template_name:, optional_slots:)
  }
  <> "\n}"
}

pub fn emit_constant(
  template_name template_name: String,
  body body: List(Node),
) {
  "pub const "
  <> template_name
  <> ": String = "
  <> emit_body(body:, template_name: "", optional_slots: [])
}

pub fn emit_file(template: Template) {
  let template_name = gleam.value_identifier_to_string(template.name)
  let template_type =
    gleam.value_to_type_identifier(template.name)
    |> gleam.type_identifier_to_string
  let required_slots = case template.metadata {
    Some(meta) ->
      case meta.required {
        Some(required) ->
          required.slots
          |> list.map(fn(slot) { slot.name |> gleam.value_identifier_to_string })
        None -> []
      }
    None -> []
  }
  let optional_slots = case template.metadata {
    Some(meta) ->
      case meta.optional {
        Some(optional) ->
          optional.slots
          |> list.map(fn(slot) { slot.name |> gleam.value_identifier_to_string })
        None -> []
      }
    None -> []
  }
  let body = template.body
  let has_slots =
    !list.is_empty(required_slots) || !list.is_empty(optional_slots)

  case has_slots {
    False -> emit_constant(template_name:, body:)
    True ->
      emit_imports(!list.is_empty(optional_slots))
      <> "\n"
      <> emit_template_type(template_type:, required_slots:, optional_slots:)
      <> "\n"
      <> emit_optional_slot_types(optional_slots:)
      <> "\n"
      <> emit_template_constructor_fn(
        template_name:,
        template_type:,
        required_slots:,
        optional_slots:,
      )
      <> "\n"
      <> emit_optional_builder_fns(
        template_name:,
        template_type:,
        optional_slots:,
      )
      <> "\n"
      <> emit_template_to_string(
        template_name:,
        template_type:,
        optional_slots:,
        body:,
      )
  }
}
