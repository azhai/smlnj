(*
 * This module defines special handling of various types in MLRISC
 *
 *)

signature MLRISC_TYPES =
sig

   structure Ast : MDL_AST
   structure RTL : MLTREE_RTL

   (* Does this type has special meaning in an instruction representation? 
    * If so, we warn the user if the argument is somehow not mentioned
    * in the RTL.
    *) 
   val isSpecialRepType : Ast.ty -> bool

   (* 
    * Given a type for an rtl argument, 
    * return actual representation type in MLRISC
    *)
   val representationOf : Ast.id * Ast.id * Ast.loc * Ast.ty -> int * Ast.id

   (* 
    * Given an rtl argument and the actual representation type,
    * insert coercion if possible.
    *)
   val insertRepCoercion : RTL.exp * Ast.ty -> unit

   (*
    * Code generation magic
    *)
   val isConst : RTL.T.rep -> bool (* does it represent a constant? *)   

   val ofCellKind : RTL.exp * Ast.storagedecl -> bool


end
