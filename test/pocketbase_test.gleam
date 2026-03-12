import gleam/http
import gleam/option.{None}

import pocketbase

const base_url = "localhost"

pub fn new_pocketbase_test() {
  let pb =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)

  assert pb.base_url == base_url
  assert pb.scheme == http.Http
  assert pb.port == 8090
  assert pb.auth_store == None
}
