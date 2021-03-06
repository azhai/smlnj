(* COPYRIGHT (c) 1997 YALE FLINT PROJECT *)
(* debindex.sig *)

(* [DBM: 5/20/09]. This is no longer used in the elaborator, so the 
 * file has been moved to FLINT/trans.
 *)

signature DEB_INDEX = 
sig
  eqtype depth
  eqtype index

  val top  : depth
  val next : depth -> depth
  val prev : depth -> depth
  val eq   : depth * depth -> bool
  val relativeDepth : depth * depth -> index
  val cmp  : depth * depth -> order

  val dp_print : depth -> string
  val dp_key : depth -> int
  val dp_toint: depth -> int
  val dp_fromint: int -> depth

  val di_print : index -> string
  val di_key : index -> int
  val di_toint: index -> int
  val di_fromint: int -> index
  val di_inner : index -> index
 
  val innermost : index
  val innersnd : index

end (* signature DEB_INDEX *)


