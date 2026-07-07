import gleam/list
import gleam/option.{None, Some}
import gleam/string
import justin
import nodi/internal/ast.{type Node, type Template, SlotReference, Text} as _
import nodi/internal/gleam

/// Creates a document for imports, it's not used if there is no
/// optional slots.
fn imports() -> String {
  "import gleam/option.{type Option, Some, None}"
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
) -> String {
  // Build type parameters: (Opt1, Opt2) if there are optional slots
  let type_params = case optional_slots {
    [] -> ""
    slots ->
      string.concat([
        "(",
        string.join(slots, with: ", "),
        ")",
      ])
  }

  // Build the record fields: wibble: String, wobble: Option(String)
  let fields = {
    let req =
      required_slots
      |> list.map(fn(slot) { slot <> ": String" })
    let opt =
      optional_slots
      |> list.map(fn(slot) { slot <> ": Option(String)" })

    list.append(req, opt)
  }

  string.concat([
    "pub type " <> template_type_name,
    type_params,
    " {\n",
    "\t" <> template_type_name <> "(",
    string.join(fields, with: ", "),
    ")\n",
    "}\n\n",
  ])
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
/// 
/// pub type HasWibble
/// 
/// pub type NoWobble
/// 
/// pub type HasWobble
/// ```
fn phantom_types(optional_slots optional_slots: List(String)) -> String {
  optional_slots
  |> list.map(fn(slot) {
    let slot_type = slot |> justin.pascal_case

    string.concat([
      "pub type No" <> slot_type,
      "\n\n",
      "pub type Has" <> slot_type,
    ])
  })
  |> string.join("\n\n")
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
/// pub fn new(wobble: String) -> Wibble(NoFoo, NoBar) {
///   Wibble(wobble:, foo: None, bar: None)
/// }
/// ```
fn constructor_fn(
  template_type_name template_type_name: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> String {
  let has_optional_slots = !list.is_empty(optional_slots)

  let optional_types =
    optional_slots
    |> list.map(fn(slot) { slot |> justin.pascal_case })

  let params = {
    required_slots
    |> list.map(fn(slot) { slot <> ": String" })
  }

  let return_fields = {
    let req =
      required_slots
      |> list.map(fn(slot) { slot <> ":" })

    let opt =
      optional_slots
      |> list.map(fn(slot) { slot <> ": None" })

    list.append(req, opt)
  }

  let return_type = case has_optional_slots {
    False -> template_type_name
    True ->
      string.concat([
        template_type_name <> "(",
        optional_types
          |> list.map(fn(opt) { "No" <> opt })
          |> string.join(with: ", "),
        ")",
      ])
  }

  let constructor_call =
    string.concat([
      template_type_name <> "(",
      string.join(return_fields, with: ", "),
      ")",
    ])

  string.concat([
    "pub fn new(",
    string.join(params, with: ", "),
    ") -> ",
    return_type,
    " {\n",
    "\t" <> constructor_call <> "\n",
    "}",
    "\n\n",
  ])
}

/// Creates a builder `with_*` function for each optional slot.
/// It also generates runtime builder functions
/// `with_*_when`, `with_*_maybe` and `with_*_each`
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
/// pub fn with_foo_when...
/// pub fn with_foo_maybe...
/// pub fn with_foo_each...
/// 
/// pub fn with_bar(wibble: Wibble(foo, NoBar), bar: String) -> Wibble(foo, HasBar) {
///   Wibble(..wibble, bar: Some(bar))
/// }
/// 
/// ...
/// ```
fn builder_fns(
  template_name template_name: String,
  template_type_name template_type_name: String,
  required_slots required_slots: List(String),
  optional_slots optional_slots: List(String),
) -> String {
  optional_slots
  |> list.map(fn(slot) {
    let slot_type = slot |> justin.pascal_case

    let type_args =
      optional_slots
      |> list.map(fn(arg) {
        case arg == slot {
          False -> arg
          True -> "No" <> slot_type
        }
      })

    let return_args =
      optional_slots
      |> list.map(fn(arg) {
        case arg == slot {
          False -> arg
          True -> "Has" <> slot_type
        }
      })

    let is_optional_only =
      list.length(optional_slots) == 1 && list.is_empty(required_slots)

    let template_param =
      string.concat([
        case is_optional_only {
          True -> "_"
          False -> ""
        },
        template_name <> ": " <> template_type_name <> "(",
        string.join(type_args, with: ", "),
        "), ",
      ])

    let is_optional_only_return = fn(is_some: Bool) {
      string.concat([
        case is_optional_only {
          True -> "\t" <> template_type_name <> "("
          False -> "\t" <> template_type_name <> "(.." <> template_name <> ", "
        },
        slot
          <> case is_some {
          True -> ": Some(" <> slot <> "))"
          False -> ": None)"
        },
      ])
    }

    // pub fn with_foo(wibble: Wibble(NoFoo, bar), foo: String) -> Wibble(HasFoo, bar) {
    //   Wibble(..wibble, foo: Some(foo))
    // }
    let builder =
      string.concat([
        "pub fn with_" <> slot <> "(",
        template_param,
        slot <> ": String",
        ") -> ",
        template_type_name <> "(",
        string.join(return_args, with: ", "),
        ")",
        " {\n",
        is_optional_only_return(True),
        "\n",
        "}",
      ])

    // pub fn with_foo_when(wibble: Wibble(NoFoo, bar), foo: String, when: Bool) -> Wibble(HasFoo, bar) {
    //   case when {
    //     True -> Wibble(..wibble, foo: Some(foo))
    //     False -> Wibble(..wibble, foo: None)
    //   }
    // }
    let builder_when =
      string.concat([
        "pub fn with_" <> slot <> "_when(",
        template_param,
        slot <> ": String, when: Bool) -> " <> template_type_name <> "(",
        string.join(return_args, ", ") <> ") {\n",
        "case when {\n",
        "\tTrue -> " <> is_optional_only_return(True) <> "\n",
        "\tFalse -> " <> is_optional_only_return(False) <> "\n",
        "}\n",
        "}",
      ])

    [builder, builder_when] |> string.join(with: "\n\n")
  })
  |> string.join(with: "\n\n")
  |> string.append("\n\n")
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
) -> String {
  case body_nodes {
    [] -> "\"\""
    _ ->
      body_nodes
      |> list.map(fn(node) {
        case node {
          Text(text) -> {
            let escaped =
              text
              |> string.replace("\\", "\\\\")
              |> string.replace("\"", "\\\"")
            "\"" <> escaped <> "\""
          }
          SlotReference(name) -> {
            let name = gleam.value_identifier_to_string(name)
            case optional_slots |> list.contains(name) {
              True -> name
              False -> template_name <> "." <> name
            }
          }
        }
      })
      |> list.intersperse(" <> ")
      |> string.concat
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
) -> String {
  let type_args = optional_slots
  let opt_slots_body =
    optional_slots
    |> list.map(fn(slot) {
      string.concat([
        "\t" <> "let " <> slot <> " = ",
        "case " <> template_name <> "." <> slot <> " {" <> "\n",
        "\t\t" <> "Some(slot) -> slot" <> "\n",
        "\t\t" <> "None -> \"\"",
        "\t" <> "\n",
        "\t" <> "}",
      ])
    })

  string.concat([
    "pub fn to_string(" <> template_name <> ": " <> template_type_name,
    case optional_slots {
      [] -> ""
      _ -> "(" <> string.join(type_args, with: ", ") <> ")"
    },
    ") -> String {\n",
    case optional_slots {
      [] -> ""
      _ -> string.join(opt_slots_body, with: "\n")
    },
    "\n\n",
    "\t" <> body(body_nodes:, template_name:, optional_slots:),
    "\n",
    "}",
  ])
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
) -> String {
  string.concat([
    "pub const " <> template_name <> ": String = ",
    body(body_nodes:, template_name: "", optional_slots: []),
  ])
}

/// Generates a complete Gleam source file document from a parsed Template.
///
/// If the template has no slots, generates a string constant instead.
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
pub fn gen_file(template: Template) -> String {
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
      string.concat([
        case !list.is_empty(optional_slots) {
          False -> ""
          True ->
            string.concat([
              imports(),
              "\n\n",
            ])
        },
        template_type(template_type_name:, required_slots:, optional_slots:),
        case !list.is_empty(optional_slots) {
          False -> ""
          True -> phantom_types(optional_slots:) <> "\n\n"
        },
        constructor_fn(template_type_name:, required_slots:, optional_slots:),
        case !list.is_empty(optional_slots) {
          False -> ""
          True ->
            builder_fns(
              template_name:,
              template_type_name:,
              required_slots:,
              optional_slots:,
            )
        },
        to_string_fn(
          template_name:,
          template_type_name:,
          optional_slots:,
          body_nodes:,
        ),
      ])
  }
}
