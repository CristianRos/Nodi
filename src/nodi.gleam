import filepath
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import nodi/internal/ast
import nodi/internal/codegen
import nodi/internal/error.{
  type Error, CannotFormatFile, CannotReadFile, CannotWriteFile,
}
import shellout
import simplifile

pub fn main() -> Nil {
  generate_files()
}

pub fn generate_files() -> Nil {
  let root = get_project_root_path(from: ".")
  let files = get_nodi_file_paths(from: root)

  let results = list.map(files, generate_file)
  let #(ok_results, errors) = result.partition(results)

  case errors {
    [_, ..] -> {
      errors
      |> list.each(fn(err) { io.println_error(error.describe_error(err)) })
      shellout.exit(1)
    }
    [] -> {
      ok_results
      |> list.each(fn(pair) {
        let #(output_path, content) = pair
        case write_file(output_path, content) {
          Ok(Nil) -> Nil
          Error(err) -> io.println_error(error.describe_error(err))
        }
      })

      io.println(
        "Generated "
        <> int.to_string(list.length(ok_results))
        <> " .gleam components",
      )
    }
  }
}

@internal
pub fn generate_file(from path: String) -> Result(#(String, String), Error) {
  let raw_name = path |> filepath.strip_extension |> filepath.base_name
  use nodi_file <- result.try(
    simplifile.read(path) |> result.map_error(CannotReadFile(path, _)),
  )
  use template <- result.try(ast.template(raw_name:, nodi_file:))

  let output_path =
    filepath.join(filepath.directory_name(path), raw_name <> ".gleam")

  let content = codegen.gen_file(template)

  Ok(#(output_path, content))
}

@internal
pub fn write_file(to path: String, with content: String) -> Result(Nil, Error) {
  use _ <- result.try(
    simplifile.write(content, to: path)
    |> result.map_error(CannotWriteFile(path, _)),
  )

  case
    shellout.command(run: "gleam", with: ["format", path], in: ".", opt: [])
  {
    Ok(_) -> Ok(Nil)
    Error(#(_, message)) -> Error(CannotFormatFile(path, message))
  }
}

@internal
pub fn get_project_root_path(from path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")
  case simplifile.is_file(toml) {
    Ok(True) -> path
    Ok(False) | Error(_) -> get_project_root_path(filepath.join("..", path))
  }
}

@internal
pub fn get_nodi_file_paths(from path: String) -> List(String) {
  let files_and_folders = case simplifile.read_directory(path) {
    Ok(files_and_folders) -> files_and_folders
    Error(simplifile.Enoent) -> []
    Error(_) -> panic as { "couldn't read directory " <> path }
  }

  files_and_folders
  |> list.flat_map(fn(f) {
    let full_path = filepath.join(path, f)
    case simplifile.is_directory(full_path) {
      Ok(True) -> {
        case f {
          // Omit "build/" folder
          "build" -> []
          _ -> get_nodi_file_paths(full_path)
        }
      }
      Ok(False) ->
        case full_path |> string.ends_with(".nodi") {
          True -> [full_path]
          False -> []
        }
      Error(_) -> []
    }
  })
}
