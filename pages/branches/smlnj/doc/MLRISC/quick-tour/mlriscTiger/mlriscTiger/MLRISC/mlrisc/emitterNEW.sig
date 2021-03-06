(* emitterNEW.sig
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

(** emitter - emit assembly or machine code **)

(* Note:
 *	assembly code: Each of the emit functions outputs the 
 * appropriate assembly instructions to a file. The stream to
 * this file can be hardwired.
 *
 *      machine code: Each of the emit functions outputs the 
 * appropriate binary output to a bytearray created in a special
 * structure reserved for this purpose.
 *
 *)
signature EMITTER_NEW = sig
  structure I : INSTRUCTIONS
  structure F : FLOWGRAPH  
    sharing F.I = I

  val defineLabel  : Label.label -> unit
  val emitInstr : I.instruction * int Intmap.intmap -> unit
  val comment : string -> unit
  val pseudoOp : F.P.pseudo_op -> unit
  val init : int -> unit
end  




(*
 * $Log$
 * Revision 1.1  2001/10/11 09:52:26  macqueen
 * Initial revision
 *
 * Revision 1.1.1.1  1998/04/08 18:39:02  george
 * Version 110.5
 *
 *)
