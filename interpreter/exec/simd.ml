open Char

type shape = I8x16 | I16x8 | I32x4 | I64x2 | F32x4 | F64x2

let lanes shape =
  match shape with
  | I8x16 -> 16
  | I16x8 -> 8
  | I32x4 -> 4
  | I64x2 -> 2
  | F32x4 -> 4
  | F64x2 -> 2

let f32x4_indices = [0; 4; 8; 12]
let f64x2_indices = [0; 8]

module type RepType =
sig
  type t

  val make : int -> char -> t
  (* ^ bits_make ? *)
  val to_string : t -> string
  val bytewidth : int
  val of_strings : shape -> string list -> t

  val to_i32x4 : t -> I32.t list

  val to_f32x4 : t -> F32.t list
  val of_f32x4 : F32.t list -> t

  val to_f64x2 : t -> F64.t list
  val of_f64x2 : F64.t list -> t
end

(* This signature defines the types and operations SIMD floats can expose. *)
module type Float =
sig
  type t
  type lane

  val abs : t -> t
  val min : t -> t -> t
  val max : t -> t -> t
  val extract_lane : int -> t -> lane
end

module type S =
sig
  type t
  type bits
  val default : t (* FIXME good name for default value? *)
  val to_string : t -> string
  val of_bits : bits -> t
  val to_bits : t -> bits
  val of_strings : shape -> string list -> t

  val i32x4_extract_lane : int -> t -> I32.t

  (* We need type t = t to ensure that all submodule types are S.t,
   * then callers don't have to change *)
  module F32x4 : Float with type t = t and type lane = F32.t
  module F64x2 : Float with type t = t and type lane = F64.t
end

module Make (Rep : RepType) : S with type bits = Rep.t =
struct
  type t = Rep.t
  type bits = Rep.t

  let default = Rep.make Rep.bytewidth (chr 0)
  let to_string = Rep.to_string (* FIXME very very wrong *)
  let of_bits x = x
  let to_bits x = x
  let of_strings = Rep.of_strings

  let to_i32x4 = Rep.to_i32x4

  let i32x4_extract_lane i x = List.nth (to_i32x4 x) i

  module MakeFloat (Float : Float.S) (Convert : sig
      val to_shape : Rep.t -> Float.t list
      val of_shape : Float.t list -> Rep.t
    end) : Float with type t = Rep.t and type lane = Float.t =
  struct
    type t = Rep.t
    type lane = Float.t
    let unop f x = Convert.of_shape (List.map f (Convert.to_shape x))
    let binop f x y = Convert.of_shape (List.map2 f (Convert.to_shape x) (Convert.to_shape y))
    let abs = unop Float.abs
    let min = binop Float.min
    let max = binop Float.max
    let extract_lane i s = List.nth (Convert.to_shape s) i
  end

  module F32x4 = MakeFloat (F32) (struct
      let to_shape = Rep.to_f32x4
      let of_shape = Rep.of_f32x4
    end)

  module F64x2 = MakeFloat (F64) (struct
      let to_shape = Rep.to_f64x2
      let of_shape = Rep.of_f64x2
    end)

end
