open Printf
open Util

type t =
  { raw            : Swagger_j.schema
  ; reference_base : string
  ; reference_root : Mod.t
  }

let create ~reference_base ~reference_root raw =
  { raw; reference_base; reference_root }

let reference t =
  t.raw.ref

let rec kind_to_string t =
  let reference_base = t.reference_base in
  let reference_root = t.reference_root in
  match t.raw.ref with
  | Some r -> Mod.reference_type ~reference_base ~reference_root r
  | None ->
      match some t.raw.kind with
      | `String  -> "string"
      | `Number  -> "float"
      | `Integer -> "int"
      | `Boolean -> "bool"
      | `Object  ->
          let open Swagger_j in
          (match t.raw.additional_properties with
          | Some props -> sprintf "(string * %s) list" (kind_to_string (create ~reference_base ~reference_root props))
          | None -> failwith "Schema.kind_to_string: object without additional_properties")
      | `Array   ->
          let open Swagger_j in
          match t.raw.items with
          | Some s -> kind_to_string (create ~reference_base ~reference_root s) ^ " list"
          | None -> failwith "Schema.kind_to_string: array type must have an 'items' field"

let to_string t =
  let reference_base = t.reference_base in
  let reference_root = t.reference_root in
  match t.raw.ref with
  | Some r -> Mod.reference_type ~reference_base ~reference_root r
  | None -> kind_to_string t
