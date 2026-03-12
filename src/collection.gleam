import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http.{type Method, Get, Http, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list

import pocketbase.{type PocketBase}

pub type PbRecords(a) {
  PbRecords(
    page: Int,
    per_page: Int,
    total_items: Int,
    total_pages: Int,
    items: List(a),
  )
}

pub fn decode_one(
  res: Response(Dynamic),
  decoder: Decoder(a),
) -> Result(a, List(decode.DecodeError)) {
  decode.run(res.body, decoder)
}

pub fn decode_list(
  res: Response(Dynamic),
  item_decoder: Decoder(a),
) -> Result(PbRecords(a), List(decode.DecodeError)) {
  let decoder = {
    use page <- decode.field("page", decode.int)
    use per_page <- decode.field("perPage", decode.int)
    use total_items <- decode.field("totalItems", decode.int)
    use total_pages <- decode.field("totalPages", decode.int)
    use items <- decode.field("items", decode.list(item_decoder))
    decode.success(PbRecords(page, per_page, total_items, total_pages, items))
  }
  decode.run(res.body, decoder)
}

pub fn one(req: Request(String), record_id: String) {
  request.set_path(req, req.path <> "/" <> record_id)
}

pub fn create(req: Request(String), body: Dict(String, Dynamic)) {
  request.set_method(req, Post)
  |> request.set_body(body)
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

pub fn page(req: Request(String), page_number: Int) {
  add_query(req, [#("page", int.to_string(page_number))])
}

pub fn per_page(req: Request(String), number_per_page: Int) {
  add_query(req, [#("perPage", int.to_string(number_per_page))])
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

pub fn list(
  req: Request(String),
  page_number: Int,
  number_per_page: Int,
) -> Request(String) {
  req
  |> page(page_number)
  |> per_page(number_per_page)
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
