(* dynamic-array-sig.sml
 *
 * COPYRIGHT (c) 2009 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *
 * Signature for unbounded polymorphic arrays.
 *)

signature DYNAMIC_ARRAY =
  sig
    type 'a array

    val array : (int * 'a) -> 'a array
      (* array (sz, e) creates an unbounded array all of whose elements
       * are initialized to e.  sz (>= 0) is used as a
       * hint of the potential range of indices.  Raises Size if a
       * negative hint is given.
       *)

    val subArray : ('a array * int * int) -> 'a array
      (* subArray (a,lo,hi) creates a new array with the same default
       * as a, and whose values in the range [0,hi-lo] are equal to
       * the values in b in the range [lo, hi].
       * Raises Size if lo > hi
       *)

    val fromList : 'a list * 'a -> 'a array
      (* arrayoflist (l, v) creates an array using the list of values l
       * plus the default value v.
       *)

    val tabulate: (int * (int -> 'a) * 'a) -> 'a array
      (* tabulate (sz,fill,dflt) acts like Array.tabulate, plus 
       * stores default value dflt.  Raises Size if sz < 0.
       *)

    val default : 'a array -> 'a
      (* default returns array's default value *)

    val sub : ('a array * int) -> 'a
      (* sub (a,idx) returns value of the array at index idx.
       * If that value has not been set by update, it returns the default value.
       * Raises Subscript if idx < 0
       *)

    val update : ('a array * int * 'a) -> unit
      (* update (a,idx,v) sets the value at index idx of the array to v. 
       * Raises Subscript if idx < 0
       *)

    val bound : 'a array -> int
      (* bound returns an upper bound on the index of values that have been
       * changed.
       *)

    val truncate : ('a array * int) -> unit
      (* truncate (a,sz) makes every entry with index > sz the default value *)

    val vector : 'a array -> 'a vector
      (* return the array's contents as a vector *)

  (* standard array iterators *)
    val appi : (int * 'a -> unit) -> 'a array -> unit
    val app : ('a -> unit) -> 'a array -> unit
    val modifyi : (int * 'a -> 'a) -> 'a array -> unit
    val modify : ('a -> 'a) -> 'a array -> unit
    val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
    val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b
    val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
    val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b
    val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option
    val find : ('a -> bool) -> 'a array -> 'a option
    val exists : ('a -> bool) -> 'a array -> bool
    val all : ('a -> bool) -> 'a array -> bool
    val collate : ('a * 'a -> order) -> 'a array * 'a array -> order

(* TODO
    val copy : {di:int, dst:'a array, src:'a array} -> unit
    val copyVec : {di:int, dst:'a array, src:'a vector} -> unit
*)

  end (* DYNAMIC_ARRAY *)

