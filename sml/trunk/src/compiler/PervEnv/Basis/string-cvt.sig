(* string-cvt.sig
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature STRING_CVT =
  sig

    datatype radix = BIN | OCT | DEC | HEX

    datatype realfmt
      = EXACT
      | SCI of int option
      | FIX of int option
      | GEN of int option

    type ('a, 'b) reader = 'b -> ('a * 'b) option

    val padLeft  : char -> int -> string -> string
    val padRight : char -> int -> string -> string

    val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> (string * 'a)
    val takel  : (char -> bool) -> (char, 'a) reader -> 'a -> string
    val dropl  : (char -> bool) -> (char, 'a) reader -> 'a -> 'a
    val skipWS : (char, 'a) reader -> 'a -> 'a

    type cs
    val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option

  end


(*
 * $Log: string-cvt.sig,v $
 * Revision 1.1.1.1  1998/04/08 18:40:04  george
 * Version 110.5
 *
 *)
