import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/fetch
import gleam/http.{type Method, Get, Http}
import gleam/http/request.{type Request}
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/result

import pocketbase.{type PocketBase}

pub type PbRecords {
  PbRecords(
    page: Int,
    per_page: Int,
    total_items: Int,
    total_pages: Int,
    items: List(Dict(String, Dynamic)),
  )
}

pub fn get_list(req: Request(String), page: Int, per_page: Int) {
  let paginated_req = list_request(req, page, per_page)
  echo request.get_query(paginated_req)

  use resp <- promise.try_await(fetch.send(paginated_req))
  use resp <- promise.try_await(fetch.read_json_body(resp))

  let decoder = {
    use page <- decode.field("page", decode.int)
    use per_page <- decode.field("perPage", decode.int)
    use total_items <- decode.field("totalItems", decode.int)
    use total_pages <- decode.field("totalPages", decode.int)
    use items <- decode.field(
      "items",
      decode.list(of: decode.dict(decode.string, decode.dynamic)),
    )
    decode.success(PbRecords(page, per_page, total_items, total_pages, items))
  }

  promise.resolve(
    decode.run(resp.body, decoder)
    |> result.map_error(fn(_) { fetch.InvalidJsonBody }),
  )
}

pub fn collection(pb: PocketBase, name: String) {
  collection_request(pb, name)
}

pub fn filter(req: Request(String), filter: String) {
  add_query(req, [#("filter", filter)])
}

pub fn sort(req: Request(String), sort: String) {
  add_query(req, [#("sort", sort)])
}

pub fn expand(req: Request(String), expand: String) {
  add_query(req, [#("fields", expand)])
}

fn build_base_request(pb: PocketBase, url: String, method: Method) {
  request.new()
  |> request.set_method(method)
  |> request.set_scheme(Http)
  |> request.set_host(pb.base_url)
  |> request.set_port(8090)
  |> request.set_path(url)
}

pub fn collection_request(pb: PocketBase, name: String) -> Request(String) {
  let url = "/api/collections/" <> name <> "/records"

  build_base_request(pb, url, Get)
}

pub fn list_request(
  req: Request(String),
  page: Int,
  per_page: Int,
) -> Request(String) {
  req
  |> add_query([
    #("page", int.to_string(page)),
    #("perPage", int.to_string(per_page)),
  ])
}

fn add_query(
  req: Request(body),
  extra: List(#(String, String)),
) -> Request(body) {
  case request.get_query(req) {
    Ok(existing) -> request.set_query(req, list.append(existing, extra))
    Error(_) -> request.set_query(req, extra)
  }
}
