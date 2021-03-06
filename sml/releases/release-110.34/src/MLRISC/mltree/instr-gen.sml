(*
 * Generate a linear sequence of instructions
 *)
functor InstrGen
   (structure I      : INSTRUCTIONS
    structure Stream : INSTRUCTION_STREAM
   ) : INSTR_GEN =
struct
   structure C = I.C
   structure I = I
   structure S = Stream

   (* Pretty stupid, eh? *)
   fun newStream(instrs) =
   let fun emit i = instrs := i :: !instrs 
       fun can'tUse _ = MLRiscErrorMsg.error("InstrGen","unimplemented")
   in  Stream.STREAM
       { beginCluster   = can'tUse,
         endCluster     = can'tUse,
         emit           = emit,
         pseudoOp       = can'tUse,
         defineLabel    = can'tUse,
         entryLabel     = can'tUse,
         comment        = can'tUse,
         annotation     = can'tUse,
         getAnnotations = can'tUse,
         exitBlock      = can'tUse
       }
   end 

end
