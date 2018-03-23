open Printf
open Util

type t =
  { name : string
  ; path : string list
  ; types : Type.t list
  ; values : Val.t list
  ; submodules : t StringMap.t
  ; recursive : bool
  }

let module_name s =
  let s =
    let last = String.length s - 1 in
    if s.[0] = '{' && s.[last] = '}' then "By_" ^ String.sub s 1 (last - 1)
    else s in
  s
  |> snake_case
  |> String.capitalize_ascii
  |> String.split_on_char '.'
  |> List.hd

let create ~name
           ?(recursive = false)
           ?(path = [])
           ?(types = [])
           ?(submodules = StringMap.empty)
           ?(values = []) () =
  { name = module_name name
  ; path = List.map module_name path
  ; types
  ; values
  ; submodules
  ; recursive
  }

let empty name ?(recursive = false) ?(path = []) () =
  create ~name ~recursive ~path ()

let with_values name ?(recursive = false) ?(path = []) values =
  create ~name ~recursive ~path ~values ()

let name m = m.name

let submodules m =
  m.submodules
  |> StringMap.bindings
  |> List.map snd

let add_type t m =
  { m with types = t :: m.types }

let add_val v m =
  { m with values = v :: m.values }

let add_types ts m =
  { m with types = m.types @ ts }

let add_vals vs m =
  { m with values = m.values @ vs }

let add_mod subm m =
  { m with submodules = StringMap.add subm.name subm m.submodules }

let map_submodules f m =
  { m with submodules = StringMap.map f m.submodules }

let has_submodules m =
  StringMap.is_empty m.submodules

let find_submodule name m =
  StringMap.find_opt (module_name name) m.submodules

let iter f m =
  f m;
  StringMap.iter
    (fun _name sub -> f sub)
    m.submodules

let path m =
  m.path

let qualified_name m =
  match m.path with
  | [] -> m.name
  | p -> sprintf "%s.%s" (String.concat "." m.path) m.name

let qualified_path m =
  m.path @ [m.name]

let object_module_val ?(indent = 0) () =
  let pad = String.make indent ' ' in
  pad ^ "module Object : Object.S with type value := t\n"

let object_module_impl ?(indent = 0) () =
  let pad = String.make indent ' ' in
  pad ^ "module Object = Object.Make (struct type value = t [@@deriving yojson] end)\n"

let rec sig_to_string ?(indent = 0) m =
  let pad = String.make indent ' ' in
  let submods =
    m.submodules
    |> StringMap.bindings
    |> List.fold_left
         (fun acc (name, m) ->
           let s = sig_to_string ~indent:(indent + 2) m in
           (* Definitions first to simplify references *)
           if name = "Definitions" then s ^ acc
           else acc ^ s)
         "" in
  sprintf "%smodule%s%s : sig\n%s%s%s%s%send\n"
    pad
    (if m.recursive then " rec " else " ")
    m.name
    submods
    (String.concat "\n"
      (List.map
        (fun t -> Type.Sig.to_string ~indent:(indent + 2) t.Type.signature)
        m.types))
    (String.concat ""
      (List.map
        (fun v -> Val.Sig.to_string ~indent:(indent + 2) v.Val.signature)
        m.values))
    (if List.exists (fun t -> Type.name t = "t") m.types then object_module_val ~indent:(indent + 2) () else "")
    pad

let rec impl_to_string ?(indent = 0) m =
  let pad = String.make indent ' ' in
  let submods =
    m.submodules
    |> StringMap.bindings
    |> List.fold_left
         (fun acc (name, m) ->
           let s = impl_to_string ~indent:(indent + 2) m in
           (* Definitions first to simplify references *)
           if name = "Definitions" then s ^ acc
           else acc ^ s)
         "" in
  let decl =
    if m.recursive
    then ""
    else sprintf "%smodule %s " pad m.name in

  sprintf "%s= struct\n%s%s%s%s%send\n"
    decl
    submods
    (String.concat "\n"
      (List.map
        (fun t ->
          Type.Impl.to_string ~indent:(indent + 2) t.Type.implementation)
        m.types))
    (String.concat ""
      (List.map
        (fun v -> Val.Impl.to_string ~indent:(indent + 2) v.Val.implementation)
        m.values))
    (if List.exists (fun t -> Type.name t = "t") m.types then object_module_impl ~indent:(indent + 2) () else "")
    pad

let to_string ?indent m =
  sprintf "%s %s"
    (sig_to_string ?indent m)
    (impl_to_string ?indent m)

let strip_base base path =
  let plen = String.length path in
  let blen = String.length base in
  if plen >= blen then
    let pref = String.sub path 0 blen in
    if String.lowercase_ascii base = String.lowercase_ascii pref then
      String.sub path blen (plen - blen)
    else
      path
  else
    path

let split_ref ref =
  ref
  |> String.split_on_char '.'
  |> List.filter ((<>)"")
  |> List.map module_name

let reference_module_path ~reference_base ~reference_root ref =
  let path =
    ref
    |> strip_base reference_base
    |> split_ref in
  qualified_name reference_root :: path

let reference_module ~reference_base ~reference_root ref =
  reference_module_path ~reference_base ~reference_root ref
  |> String.concat "."

let reference_type ~reference_base ~reference_root ref =
  reference_module ~reference_base ~reference_root ref ^ ".t"
