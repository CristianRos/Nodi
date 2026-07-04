import glam/doc.{type Document}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import justin
import nodi/internal/gleam
import nodi/internal/template.{type Node, type Template, SlotReference, Text} as _

/// Creates a document for imports, in case there is no optional slots
/// it creates an empty document. 
fn imports(has_optional_slots has_optional_slots: Bool) -> Document {
  case has_optional_slots {
    True -> doc.from_string("import gleam/option.{type Option, Some, None}")
    False -> doc.empty
  }
}

/// Creates a document for the template type
/// 
/// ```
/// // Input:
/// template_type_name: "Wibble"
/// required_slots: ["wobble"]
/// optional_slots: ["foo", "bar"]
/// 
/// // Output:
/// pub type Wibble(foo, bar) {
///   Wibble(wobble: String, foo: Option(String), bar: Option(String))
/// }
/// ```
fn template_type(
  template_type_name template_type_name: String,
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
    doc.from_string("pub type " <> template_type_name),
    type_params,
    doc.from_string(" {"),
    doc.line,
    doc.nest(
      doc.concat([
        doc.from_string(template_type_name <> "("),
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

/// Creates a document with the phantom types `NoType` and `HasType`
/// for each optional slot
/// 
/// ```
/// // Input:
/// optional_slots: ["wibble", "wobble"]
/// 
/// // Generates:
/// pub type NoWibble
/// pub type HasWibble
/// pub type NoWobble
/// pub type HasWobble
/// ```
fn phantom_types(optional_slots optional_slots: List(String)) -> Document {
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

/// Creates a document for the constructor function of the template
/// given the proper parameters
/// 
/// ```
/// // Input:
/// template_name: "wibble"
/// template_type_name: "Wibble"
/// required_slots: ["wobble"]
/// optional_slots: ["foo", "bar"]
/// 
/// // Generates:
/// pub fn wibble(wobble: String, foo: Option(String), bar: Option(String)) -> Wibble(NoFoo, NoBar) {
///   Wibble(wobble:, foo: None, bar: None)
/// }
/// ```
fn constructor_fn(
  template_name template_name: String,
  template_type_name template_type_name: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> Document {
  let has_optional_slots = !list.is_empty(optional_slots)

  let optional_types =
    optional_slots
    |> list.map(fn(slot) { slot |> justin.pascal_case })

  let params = {
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

  let return_type = case has_optional_slots {
    False -> doc.from_string(template_type_name)
    True ->
      doc.concat([
        doc.from_string(template_type_name <> "("),
        optional_types
          |> list.map(fn(opt) { doc.from_string("No" <> opt) })
          |> doc.join(with: doc.break(", ", ",")),
        doc.from_string(")"),
      ])
      |> doc.group
  }

  let constructor_call =
    doc.concat([
      doc.from_string(template_type_name <> "("),
      doc.join(return_fields, with: doc.break(", ", ",")),
      doc.from_string(")"),
    ])
    |> doc.group

  doc.concat([
    doc.from_string("pub fn " <> template_name <> "("),
    doc.join(params, with: doc.break(", ", ",")),
    doc.from_string(") -> "),
    return_type,
    doc.from_string(" {"),
    doc.line,
    doc.nest(constructor_call, by: 2),
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.group
}

/// Creates a document with a builder `with_*` function for each optional slot
/// 
/// ```
/// // Input:
/// template_name: "wibble"
/// template_type_name: "Wibble"
/// optional_slots: ["foo", "bar"]
/// 
/// // Generates:
/// pub fn with_foo(wibble: Wibble(NoFoo, bar), foo: String) -> Wibble(HasFoo, bar) {
///   Wibble(..wibble, foo: Some(foo))
/// }
/// 
/// pub fn with_bar(wibble: Wibble(foo, NoBar), bar: String) -> Wibble(foo, HasBar) {
///   Wibble(..wibble, bar: Some(bar))
/// }
/// ```
fn builder_fns(
  template_name template_name: String,
  template_type_name template_type_name: String,
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
      doc.concat([
        doc.from_string(template_name <> ": " <> template_type_name <> "("),
        doc.join(type_args, with: doc.break(", ", ",")),
        doc.from_string(")"),
        doc.break(", ", ","),
        doc.from_string(slot <> ": String"),
        doc.break("", ""),
      ])
        |> doc.group,
      doc.from_string(") -> "),
      doc.concat([
        doc.from_string(template_type_name <> "("),
        doc.join(return_args, with: doc.break(", ", ",")),
        doc.from_string(")"),
      ])
        |> doc.group,
      doc.from_string(" {"),
      doc.line,
      doc.nest(
        doc.concat([
          doc.from_string(template_type_name <> "(.." <> template_name <> ", "),
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

/// Creates a document for the template body, escaping Text nodes and
/// resolving SlotReferences to either local variables (optional slots)
/// or field accesses (required slots)
/// 
/// ```
/// // Input:
/// body_nodes: [
///   Text("<div>"),
///   SlotReference("foo"),
///   SlotReference("bar"),
///   Text("</div>"),
/// ]
/// template_name: "wibble",
/// optional_slots: ["bar"]
/// 
/// // Generates:
/// "<div>" <> wibble.foo <> bar <> "</div>"
/// ```
fn body(
  body_nodes body_nodes: List(Node),
  template_name template_name: String,
  optional_slots optional_slots: List(String),
) -> Document {
  case body_nodes {
    [] -> doc.from_string("\"\"")
    _ ->
      body_nodes
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

/// Creates a document for the `to_string` function of the template
///
/// Optional slots are unwrapped from `Option(String)` into local variables
/// at the top of the function body, defaulting to `""` when `None`.
/// Required slots are accessed directly via the template value.
///
/// ```
/// // Input:
/// template_name: "wibble"
/// template_type_name: "Wibble"
/// optional_slots: ["bar"]
/// body_nodes: [
///   Text("<div>"),
///   SlotReference("foo"),
///   SlotReference("bar"),
///   Text("</div>"),
/// ]
///
/// // Output:
/// pub fn to_string(wibble: Wibble(bar)) -> String {
///   let bar = case wibble.bar {
///     Some(slot) -> slot
///     None -> ""
///   }
///   "<div>" <> wibble.foo <> bar <> "</div>"
/// }
/// ```
fn to_string_fn(
  template_name template_name: String,
  template_type_name template_type_name: String,
  optional_slots optional_slots: List(String),
  body_nodes body_nodes: List(Node),
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
      "pub fn to_string(" <> template_name <> ": " <> template_type_name <> "(",
    ),
    doc.join(type_args, with: doc.break(", ", ",")),
    doc.from_string(")) -> String {"),
    doc.line,
    doc.join(opt_slots_body, with: doc.line),
    body(body_nodes:, template_name:, optional_slots:),
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.group
}

/// Creates a document for a static template with no slots,
/// generating a public constant instead of a type and functions.
///
/// ```
/// // Input:
/// template_name: "wibble"
/// body_nodes: [Text("<div>static content</div>")]
///
/// // Output:
/// pub const wibble: String = "<div>static content</div>"
/// ```
fn constant(
  template_name template_name: String,
  body_nodes body_nodes: List(Node),
) -> Document {
  doc.concat([
    doc.from_string("pub const " <> template_name <> ": String = "),
    body(body_nodes:, template_name: "", optional_slots: []),
  ])
  |> doc.group
}

/// Generates a complete Gleam source file document from a parsed Template.
///
/// If the template has no slots, generates a single `pub const` string constant.
/// If the template has slots, generates a full module with:
/// - imports (only when optional slots are present)
/// - a custom type with phantom type parameters for each optional slot
/// - `No*/Has*` phantom types for each optional slot
/// - a base constructor function
/// - a `with_*` builder function for each optional slot
/// - a `to_string` function that renders the template to a String
///
/// The returned `Document` should be rendered with `doc.to_string(document, 80)`
/// and written to a `.gleam` file colocated with the source `.nodi` file.
pub fn gen_file(template: Template) -> Document {
  let template_name = gleam.value_identifier_to_string(template.name)
  let template_type_name =
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
  let body_nodes = template.body
  let has_slots =
    !list.is_empty(required_slots) || !list.is_empty(optional_slots)

  case has_slots {
    False -> constant(template_name:, body_nodes:)
    True ->
      doc.concat([
        imports(!list.is_empty(optional_slots)),
        doc.line,
        template_type(template_type_name:, required_slots:, optional_slots:),
        doc.line,
        phantom_types(optional_slots:),
        doc.line,
        constructor_fn(
          template_name:,
          template_type_name:,
          required_slots:,
          optional_slots:,
        ),
        doc.line,
        builder_fns(template_name:, template_type_name:, optional_slots:),
        doc.line,
        to_string_fn(
          template_name:,
          template_type_name:,
          optional_slots:,
          body_nodes:,
        ),
      ])
      |> doc.group
  }
}
