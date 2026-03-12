import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/option.{type Option, None, Some}

pub type AuthStore {
  AuthStore(token: String, record: Dynamic)
}

pub type PocketBase {
  PocketBase(
    base_url: String,
    scheme: http.Scheme,
    port: Int,
    auth_store: Option(AuthStore),
  )
}

pub fn new(base_url: String) -> PocketBase {
  PocketBase(base_url, http.Https, 443, None)
}

pub fn port(pb: PocketBase, port: Int) {
  PocketBase(..pb, port: port)
}

pub fn https(pb: PocketBase, https: Bool) {
  case https {
    True -> PocketBase(..pb, scheme: http.Https)
    False -> PocketBase(..pb, scheme: http.Http)
  }
}

pub fn auth(pb: PocketBase, token: String, record: Dynamic) {
  PocketBase(..pb, auth_store: Some(AuthStore(token, record)))
}
