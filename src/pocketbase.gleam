import gleam/option.{type Option, None}

pub type PocketBase {
  PocketBase(base_url: String, token: Option(String))
}

pub fn new(base_url: String) -> PocketBase {
  PocketBase(base_url, None)
}
