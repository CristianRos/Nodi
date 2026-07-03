import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/string
import nodi/internal/error.{
  type Error, DuplicateKeyword, DuplicateSlotName, EmptyDeclaration,
  InvalidKeywordName, InvalidSlotName, InvalidSlotRef, InvalidTemplateName,
  MissingDeclarationEquals, SeparatorWithNoMetadata, UndeclaredSlotRef,
  UnterminatedSlotRef, UnusedDeclaration,
}
import nodi/internal/gleam.{type ValueIdentifier}

pub type Keyword {
  Required
  Optional
}

pub fn keyword(name: String) -> Result(Keyword, Error) {
  case name {
    "req" -> Ok(Required)
    "opt" -> Ok(Optional)
    _ -> Error(InvalidKeywordName(name))
  }
}

pub fn keyword_to_string(keyword: Keyword) -> String {
  case keyword {
    Required -> "Required"
    Optional -> "Optional"
  }
}

pub type Slot {
  Slot(name: ValueIdentifier)
}

pub type Declaration {
  Declaration(keyword: Keyword, slots: List(Slot))
}

pub fn declaration(declaration: String) -> Result(Declaration, Error) {
  use #(raw_keyword, raw_slots) <- result.try(
    string.split_once(declaration, on: "=")
    |> result.replace_error(MissingDeclarationEquals(string.trim(declaration))),
  )
  use keyword <- result.try(keyword(raw_keyword))
  use slots <- result.try(case raw_slots {
    "" -> Error(EmptyDeclaration(keyword_to_string(keyword)))
    _ ->
      raw_slots
      |> string.split(",")
      |> list.try_map(fn(raw) {
        let slot = string.trim(raw)
        case gleam.value_identifier(from: slot) {
          Ok(valid) -> Ok(Slot(valid))
          Error(reason) ->
            Error(InvalidSlotName(keyword_to_string(keyword), slot, reason))
        }
      })
  })

  Ok(Declaration(keyword, slots))
}

pub type Metadata {
  Metadata(required: Option(Declaration), optional: Option(Declaration))
}

pub fn metadata(metadata: String) -> Result(Metadata, Error) {
  let raw_declarations =
    metadata
    |> string.replace("\r\n", "\n")
    |> string.split(on: "\n")
    |> list.filter(fn(line) { string.trim(line) != "" })

  use declarations <- result.try(list.try_map(raw_declarations, declaration))

  // Checks for duplicate keywords
  use _ <- result.try(
    declarations
    |> list.try_fold(set.new(), fn(keyword_set, declaration) {
      let keyword = keyword_to_string(declaration.keyword)
      case keyword_set |> set.contains(keyword) {
        True -> Error(DuplicateKeyword(keyword))
        False -> Ok(set.insert(keyword_set, keyword))
      }
    })
    |> result.replace(Nil),
  )
  // Checks for duplicate slots
  use _ <- result.try(
    declarations
    |> list.fold(list.new(), fn(slot_list, declaration) {
      slot_list
      |> list.append(declaration.slots)
    })
    |> list.map(fn(slot) { gleam.value_identifier_to_string(slot.name) })
    |> list.try_fold(set.new(), fn(slot_set, slot) {
      case slot_set |> set.contains(slot) {
        True -> Error(DuplicateSlotName(slot))
        False -> Ok(set.insert(slot_set, slot))
      }
    })
    |> result.replace(Nil),
  )

  let #(required, optional) =
    declarations
    |> list.fold(#(None, None), fn(tuple, declaration) {
      case declaration.keyword {
        Required -> #(Some(declaration), tuple.1)
        Optional -> #(tuple.0, Some(declaration))
      }
    })

  Ok(Metadata(required, optional))
}

pub type Node {
  Text(String)
  SlotReference(ValueIdentifier)
}

pub fn body(remaining: String) -> Result(List(Node), Error) {
  case string.split_once(remaining, on: "<%") {
    Error(_) -> {
      case remaining {
        "" -> Ok([])
        _ -> Ok([Text(remaining)])
      }
    }
    Ok(#(before, after)) -> {
      use #(raw_name, rest) <- result.try(
        string.split_once(after, on: "%>")
        |> result.replace_error(UnterminatedSlotRef),
      )

      use name <- result.try(
        string.trim(raw_name)
        |> gleam.value_identifier
        |> result.map_error(InvalidSlotRef(string.trim(raw_name), _)),
      )

      use nodes <- result.try(body(rest))

      let text_node = case before {
        "" -> []
        _ -> [Text(before)]
      }

      Ok(list.flatten([text_node, [SlotReference(name)], nodes]))
    }
  }
}

pub type Template {
  Template(name: ValueIdentifier, metadata: Option(Metadata), body: List(Node))
}

pub fn template(
  raw_name raw_name: String,
  nodi_file nodi_file: String,
) -> Result(Template, Error) {
  use name <- result.try(
    gleam.value_identifier(raw_name)
    |> result.map_error(InvalidTemplateName(raw_name, _)),
  )

  use #(metadata, body) <- result.try(
    case string.split_once(nodi_file, on: "---") {
      Ok(#(raw_metadata, raw_body)) -> {
        use _ <- result.try(case string.trim(raw_metadata) {
          "" -> Error(SeparatorWithNoMetadata)
          _ -> Ok(Nil)
        })
        use metadata <- result.try(metadata(raw_metadata))
        use body <- result.try(body(raw_body))
        Ok(#(Some(metadata), body))
      }
      Error(_) -> {
        use body <- result.try(body(nodi_file))
        Ok(#(None, body))
      }
    },
  )

  // Checks slot references are valid or error
  use _ <- result.try({
    let declared = case metadata {
      None -> set.new()
      Some(metadata) ->
        [metadata.required, metadata.optional]
        // List(Option(Declaration)) -> List(Declaration)
        |> list.filter_map(option.to_result(_, Nil))
        // List(Declaration) -> List(Slot)
        |> list.flat_map(fn(declaration) { declaration.slots })
        // List(Slot) -> List(String)
        |> list.map(fn(slot) { gleam.value_identifier_to_string(slot.name) })
        // List(String) -> Set(String)
        |> set.from_list
    }

    let referenced =
      body
      |> list.filter_map(fn(node) {
        case node {
          Text(_) -> Error(Nil)
          SlotReference(name) -> Ok(gleam.value_identifier_to_string(name))
        }
      })
      |> set.from_list

    // Checks for declared slots that aren't referenced in the body
    use _ <- result.try(
      case set.difference(from: declared, minus: referenced) |> set.to_list {
        [] -> Ok(Nil)
        [unused, ..] -> Error(UnusedDeclaration(unused))
      },
    )

    // Checks for slot references that exist in the body but aren't declared in the metadata
    use _ <- result.try(
      case set.difference(from: referenced, minus: declared) |> set.to_list {
        [] -> Ok(Nil)
        [undeclared, ..] -> Error(UndeclaredSlotRef(undeclared))
      },
    )

    Ok(Nil)
  })

  Ok(Template(name, metadata, body))
}
