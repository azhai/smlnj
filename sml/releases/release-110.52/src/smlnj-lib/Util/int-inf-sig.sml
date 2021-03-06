(* int-inf-sig.sml
 *
 * COPYRIGHT (c) 1995 by AT&T Bell Laboratories.  See COPYRIGHT file for details.
 *
 * This package is derived from Andrzej Filinski's bignum package.  It is versy
 * close to the definition of the optional IntInf structure in the SML'97 basis.
 *)

signature INT_INF =
  sig
    include INTEGER

    val divmod  : (int * int) -> (int * int)
    val quotrem : (int * int) -> (int * int)
    val pow : (int * Int.int) -> int
    val log2 : int -> Int.int
    val orb  : int * int -> int
    val xorb : int * int -> int
    val andb : int * int -> int
    val notb : int -> int
    val <<   : int * Word.word -> int
    val ~>>  : int * Word.word -> int

  (* these are not in the BASIS signature, but they are useful since IntInf.int
   * is not a builtin type yet.
   *)
    val == : (int * int) -> bool
    val != : (int * int) -> bool

  end (* signature INT_INF *)

