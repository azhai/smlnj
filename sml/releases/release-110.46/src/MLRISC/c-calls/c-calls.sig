(* c-calls.sig
 *
 * COPYRIGHT (c) 2002 Bell Labs, Lucent Technologies
 *)

signature C_CALLS =
  sig

    structure T : MLTREE

    datatype c_arg 
      = ARG of T.rexp	
	  (* rexp specifies integer or pointer; if the 
           * corresponding parameter is a C struct, then 
	   * this argument is the address of the struct. 
	   *)
      | FARG of T.fexp
	  (* fexp specifies floating-point argument *)
      | ARGS of c_arg list
	  (* list of arguments corresponding to the contents of a C struct *)

  (* this constant is the offset from the SP to the low-address of the
   * parameter area (see the paramAlloc callback below).
   *)
    val paramAreaOffset : int

  (* translate a C function call with the given argument list into
   * a MLRISC statement list.  The arguments are as follows:
   *
   *	name			-- an expression that speficies the function.
   *	proto			-- the function's prototype
   *	paramAlloc		-- this callback takes the size and alignment
   *				   constraints on the parameter-passing area
   *				   in the stack.  If it returns true, then the
   *				   space for the parameters is allocated by
   *				   client; otherwise genCall allocates the space.
   *    structRet		-- this callback takes the size and alignment
   *				   of space required for returning a struct
   *				   value.  It returns the address of the
   *				   reserved space.
   *	saveRestoreDedicated	-- this callback takes a list of registers
   *				   that the call kills and should return an
   *				   instruction sequence to save/restore any
   *				   registers that the client run-time model
   *				   expects to be preserved (e.g., allocation
   *				   pointers).
   *    callComment		-- if present, the comment string is attached
   *				   the CALL instruction as a COMMENT annotation.
   *    args			-- the arguments to the call.
   *
   * The result of genCall is a mlrisc list specifying where the result
   * is and the MLRisc statements that implement the calling sequence.
   * Functions with void return type have no result, most others have
   * one result, but some conventions may flatten larger arguments into
   * multiple registers (e.g., a register pair for long long results).
   *
   * WARNING: if the client's implementation of structRet uses the stack
   * pointer to address the struct-return area, then paramAlloc should always
   * handle allocating space for the parameter area (i.e., eturn true).
   *)
    val genCall : {
	    name  : T.rexp,
            proto : CTypes.c_proto,
	    paramAlloc : {szb : int, align : int} -> bool,
            structRet : {szb : int, align : int} -> T.rexp,
	    saveRestoreDedicated :
	      T.mlrisc list -> {save: T.stm list, restore: T.stm list},
	    callComment : string option,
            args : c_arg list
	  } -> {
	    callseq : T.stm list,
	    result: T.mlrisc list
	  }

  end
