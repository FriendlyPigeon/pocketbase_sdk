import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { Result$Error, Result$Ok } from "./gleam.mjs";

export function read_file(path) {
  try {
    return Result$Ok(readFileSync(path, "utf-8"));
  } catch (error) {
    return Result$Error(error_message(error));
  }
}

export function write_file(path, contents) {
  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, contents, "utf-8");
    return Result$Ok(undefined);
  } catch (error) {
    return Result$Error(error_message(error));
  }
}

export function cli_args() {
  if (typeof process === "object" && Array.isArray(process.argv)) {
    return process.argv.slice(2).join("\n");
  }

  return "";
}

function error_message(error) {
  if (error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
}
