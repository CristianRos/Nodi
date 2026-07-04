import glam/doc.{type Document}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import justin
import nodi/internal/gleam
import nodi/internal/template.{type Node, type Template, SlotReference, Text} as _

pub fn emit_imports(has_optional has_optional: Bool) -> Document {
  case has_optional {
    True -> doc.from_string("import gleam/option.{type Option, Some, None}")
    False -> doc.empty
  }
}

pub fn emit_template_type(
  template_type template_type: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> Document {
  // Build type parameters: (Opt1, Opt2) if there are optional slots
  let type_params = case optional_slots {
    [] -> doc.empty
    slots ->
      doc.concat([
        doc.from_string("("),
        doc.join(slots |> list.map(doc.from_string), with: doc.break(", ", ",")),
        doc.from_string(")"),
      ])
      |> doc.group
  }

  // Build the record fields: wibble: String, wobble: Option(String)
  let fields = {
    let req =
      required_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ": String") })
    let opt =
      optional_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ": Option(String)") })

    list.append(req, opt)
  }

  doc.concat([
    doc.from_string("pub type " <> template_type),
    type_params,
    doc.from_string(" {"),
    doc.line,
    doc.nest(
      doc.concat([
        doc.from_string(template_type <> "("),
        doc.nest(doc.join(fields, with: doc.break(", ", ",")), by: 2),
        doc.from_string(")"),
      ])
        |> doc.group,
      by: 2,
    ),
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.group
}

pub fn emit_optional_slot_types(
  optional_slots optional_slots: List(String),
) -> Document {
  optional_slots
  |> list.map(fn(slot) {
    // NOTE(Cris): This should work as if we were validating value to string type
    // but we take the shortcut for convenience and we know these should already
    // have been validated as ValueIdentifier, so mutation should be straightforward
    let slot_type = slot |> justin.pascal_case

    doc.concat([
      doc.from_string("pub type No" <> slot_type),
      doc.line,
      doc.from_string("pub type Has" <> slot_type),
    ])
    |> doc.group
  })
  |> doc.join(with: doc.line)
  |> doc.group
}

pub fn emit_template_constructor_fn(
  template_name template_name: String,
  template_type template_type: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> Document {
  let has_required = !list.is_empty(required_slots)
  let has_optional = !list.is_empty(optional_slots)
  let has_slots = has_required || has_optional

  let optional_types =
    optional_slots
    |> list.map(fn(slot) { slot |> justin.pascal_case })

  let fields = {
    let req =
      required_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ": String") })
    let opt =
      optional_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ": Option(String)") })

    list.append(req, opt)
  }

  let return_fields = {
    let req =
      required_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ":") })

    let opt =
      optional_slots
      |> list.map(fn(slot) { doc.from_string(slot <> ": None") })

    list.append(req, opt)
  }

  let constructor = case has_optional {
    False -> doc.from_string(template_type)
    True ->
      doc.concat([
        doc.from_string(template_type <> "("),
        optional_types
          |> list.map(fn(opt) { doc.from_string("No" <> opt) })
          |> doc.join(with: doc.break(", ", ",")),
        doc.from_string(")"),
      ])
      |> doc.group
  }

  let return = case has_slots {
    False -> doc.from_string(template_type)
    True ->
      doc.concat([
        doc.from_string(template_type),
        doc.line,
        doc.join(return_fields, with: doc.break(", ", ",")),
      ])
      |> doc.group
  }

  doc.concat([
    doc.from_string("pub fn " <> template_name <> "("),
    doc.join(fields, with: doc.break(", ", ",")),
    doc.from_string(") {"),
    doc.line,
    constructor,
    doc.from_string(" {"),
    doc.line,
    return,
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.group
}

pub fn emit_optional_builder_fns(
  template_name template_name: String,
  template_type template_type: String,
  optional_slots optional_slots: List(String),
) -> Document {
  optional_slots
  |> list.map(fn(slot) {
    let slot_type = slot |> justin.pascal_case

    let type_args =
      optional_slots
      |> list.map(fn(arg) {
        case arg == slot {
          False -> doc.from_string(arg)
          True -> doc.from_string("No" <> slot_type)
        }
      })

    let return_args =
      optional_slots
      |> list.map(fn(arg) {
        case arg == slot {
          False -> doc.from_string(arg)
          True -> doc.from_string("Has" <> slot_type)
        }
      })

    doc.concat([
      doc.from_string("pub fn with_" <> slot <> "("),
      doc.from_string(template_name <> ": " <> template_type <> "("),
      doc.join(type_args, with: doc.break(", ", ",")),
      doc.from_string("),"),
      doc.line,
      doc.from_string(slot <> ": String"),
      doc.line,
      doc.from_string(") -> " <> template_type <> "("),
      doc.join(return_args, with: doc.break(", ", ",")),
      doc.from_string(") {"),
      doc.line,
      doc.nest(
        doc.concat([
          doc.from_string(template_type <> "(.." <> template_name <> ", "),
          doc.from_string(slot <> ": Some(" <> slot <> "))"),
        ])
          |> doc.group,
        by: 2,
      ),
      doc.line,
      doc.from_string("}"),
    ])
    |> doc.group
  })
  |> doc.join(with: doc.line)
}

pub fn emit_body(
  body body: List(Node),
  template_name template_name: String,
  optional_slots optional_slots: List(String),
) -> Document {
  case body {
    [] -> doc.from_string("\"\"")
    _ ->
      body
      |> list.map(fn(node) {
        case node {
          Text(text) -> {
            let escaped =
              text
              |> string.replace("\\", "\\\\")
              |> string.replace("\"", "\\\"")
            doc.from_string("\"" <> escaped <> "\"")
          }
          SlotReference(name) -> {
            let name = gleam.value_identifier_to_string(name)
            case optional_slots |> list.contains(name) {
              True -> doc.from_string(name)
              False -> doc.from_string(template_name <> "." <> name)
            }
          }
        }
      })
      |> list.intersperse(doc.break(" <> ", " <> "))
      |> doc.concat
      |> doc.group
  }
}

pub fn emit_template_to_string_fn(
  template_name template_name: String,
  template_type template_type: String,
  optional_slots optional_slots: List(String),
  body body: List(Node),
) -> Document {
  let type_args = optional_slots |> list.map(doc.from_string)
  let opt_slots_body =
    optional_slots
    |> list.map(fn(slot) {
      doc.concat([
        doc.from_string(
          "let " <> slot <> " = case " <> template_name <> "." <> slot <> "{",
        ),
        doc.line,
        doc.nest(
          doc.concat([
            doc.from_string("Some(slot) -> slot"),
            doc.line,
            doc.from_string("None -> \"\""),
          ]),
          by: 2,
        ),
        doc.line,
        doc.from_string("}"),
      ])
      |> doc.group
    })

  doc.concat([
    doc.from_string(
      "pub fn to_string(" <> template_name <> ": " <> template_type <> "(",
    ),
    doc.join(type_args, with: doc.break(", ", ",")),
    doc.from_string(")) -> String {"),
    doc.line,
    doc.join(opt_slots_body, with: doc.line),
    emit_body(body:, template_name:, optional_slots:),
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.group
}

pub fn emit_constant(
  template_name template_name: String,
  body body: List(Node),
) -> Document {
  doc.concat([
    doc.from_string("pub const " <> template_name <> ": String = "),
    emit_body(body:, template_name: "", optional_slots: []),
  ])
  |> doc.group
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
      doc.concat([
        emit_imports(!list.is_empty(optional_slots)),
        doc.line,
        emit_template_type(template_type:, required_slots:, optional_slots:),
        doc.line,
        emit_optional_slot_types(optional_slots:),
        doc.line,
        emit_template_constructor_fn(
          template_name:,
          template_type:,
          required_slots:,
          optional_slots:,
        ),
        doc.line,
        emit_optional_builder_fns(
          template_name:,
          template_type:,
          optional_slots:,
        ),
        doc.line,
        emit_template_to_string_fn(
          template_name:,
          template_type:,
          optional_slots:,
          body:,
        ),
      ])
      |> doc.group
  }
}
