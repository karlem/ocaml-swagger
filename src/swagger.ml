open Printf


let prelude = {|

module rec Type_info : sig
  module type S =  sig
    type t

    val path : unit -> string
    val get_field_type : string -> Field_type.t
  end
  type t = (module S)
end = Type_info
and Field_type : sig
  type t = [
    | `String
    | `Float
    | `Int
    | `Bool
    | `Object
    | `Reference of Type_info.t
    | `List of t
  ]
end = Field_type

|}

let codegen ~path_base
    ~definition_base
    ~reference_base
    ~reference_root
    ?(output = stdout)
    ~input =
  let ic = open_in input in
  let s = really_input_string ic (in_channel_length ic) in
  let swagger = Swagger_j.swagger_of_string s in
  Gen.of_swagger
    ~path_base
    ~definition_base
    ~reference_base
    ~reference_root
    swagger
  |> Gen.to_string
  |> fprintf output "%s\n%s\n%!" prelude
