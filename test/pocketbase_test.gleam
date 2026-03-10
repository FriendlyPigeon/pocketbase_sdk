import gleeunit

import gleam/option.{None}
import pocketbase

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_pocketbase_test() {
  let base_url = "https://example.com"
  let pb = pocketbase.new(base_url)

  assert pb.base_url == base_url
  assert pb.token == None
}
