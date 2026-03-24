import gleam/io
import gleam/list
import gleam/string
import pocketbase_sdk/codegen

const default_output_path = "src/pocketbase_sdk/generated.gleam"

pub fn main() -> Nil {
  let args = cli_args() |> parse_cli_args

  case run_with_args(args) {
    Ok(path) ->
      io.println("Generated PocketBase types and decoders at " <> path)
    Error(message) -> io.println(message)
  }
}

pub fn run_with_args(args: List(String)) -> Result(String, String) {
  case args {
    [schema_path] -> generate_and_write(schema_path, default_output_path)
    [schema_path, output_path] -> generate_and_write(schema_path, output_path)
    _ -> Error(usage())
  }
}

pub fn usage() -> String {
  "Usage: gleam run -m pocketbase_sdk -- <schema-json-path> [output-gleam-path]\n"
  <> "Example: gleam run -m pocketbase_sdk -- pb_schema.json src/pocketbase_sdk/generated.gleam\n"
  <> "Default output path: "
  <> default_output_path
}

fn generate_and_write(
  schema_path: String,
  output_path: String,
) -> Result(String, String) {
  case read_text_file(schema_path) {
    Ok(schema_text) -> {
      let module_name = module_name_from_output_path(output_path)
      let generated =
        codegen.generate_gleam_file_from_json_string(schema_text, module_name)

      case generated.contents {
        "" ->
          Error("Failed to parse PocketBase schema JSON from " <> schema_path)
        _ ->
          case write_text_file(generated.path, generated.contents) {
            Ok(_) -> Ok(generated.path)
            Error(message) -> {
              Error(
                "Failed to write generated file at "
                <> generated.path
                <> ": "
                <> message,
              )
            }
          }
      }
    }
    Error(message) -> {
      Error("Failed to read schema file " <> schema_path <> ": " <> message)
    }
  }
}

fn module_name_from_output_path(output_path: String) -> String {
  case string.ends_with(output_path, ".gleam") {
    True -> string.drop_end(output_path, 6)
    False -> output_path
  }
}

fn parse_cli_args(args_as_string: String) -> List(String) {
  args_as_string
  |> string.split(on: "\n")
  |> list.filter(fn(arg) { arg != "" })
}

@external(javascript, "../pocketbase_sdk_ffi.mjs", "read_file")
fn read_text_file(path: String) -> Result(String, String)

@external(javascript, "../pocketbase_sdk_ffi.mjs", "write_file")
fn write_text_file(path: String, contents: String) -> Result(Nil, String)

@external(javascript, "../pocketbase_sdk_ffi.mjs", "cli_args")
fn cli_args() -> String
