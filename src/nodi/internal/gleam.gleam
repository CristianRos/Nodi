import gleam/string
import nodi/internal/error.{
  type ValueIdentifierError, ValueContainsInvalidGrapheme, ValueIsEmpty,
}

// Gleam identifiers types and validation come from Giaccomo Cavalieri's
// implementation of Squirrel.
// https://github.com/giacomocavalieri/squirrel

/// A Gleam identifier, that is a String that starts with a lowercase letter,
/// is in snake_case, and can only contain lowercase letters, numbers and
/// underscores.
/// 
/// This can only be built using the `gleam.value_identifier` function that
/// ensures that a string is a valid Gleam identifier.
/// 
pub type ValueIdentifier {
  ValueIdentifier(String)
}

/// Validates if the given string is a valid Gleam value identifier (that is not
/// a discard identifier, that is starting with an '_').
///
/// > 💡 A valid identifier can be described by the following regex:
/// > `[a-z][a-z0-9_]*`.
///
pub fn value_identifier(
  from name: String,
) -> Result(ValueIdentifier, ValueIdentifierError) {
  // A valid identifier needs to start with a lowercase letter.
  // We do not accept _discard identifier as valid.
  case string.pop_grapheme(name) {
    Error(_) -> Error(ValueIsEmpty)
    Ok(#(char, rest)) ->
      case is_lowercase_letter(char) {
        True -> to_value_identifier_rest(name, rest, 1)
        False -> Error(ValueContainsInvalidGrapheme(0, char))
      }
  }
}

fn to_value_identifier_rest(
  name: String,
  rest: String,
  position: Int,
) -> Result(ValueIdentifier, ValueIdentifierError) {
  // Only valid values are '_', lowercase letters and digits, 
  case string.pop_grapheme(rest) {
    Error(_) -> Ok(ValueIdentifier(name))
    Ok(#(char, rest)) -> {
      let is_valid_char =
        char == "_" || is_lowercase_letter(char) || is_digit(char)
      case is_valid_char {
        True -> to_value_identifier_rest(name, rest, position + 1)
        False -> Error(ValueContainsInvalidGrapheme(position, char))
      }
    }
  }
}

pub fn value_identifier_to_string(identifier: ValueIdentifier) -> String {
  let ValueIdentifier(name) = identifier
  name
}

fn is_lowercase_letter(char: String) -> Bool {
  case char {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" -> True
    "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" -> True
    "w" | "x" | "y" | "z" -> True
    _ -> False
  }
}

fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}
