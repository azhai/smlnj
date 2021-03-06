(*
 * This file was automatically generated by MDGen (v2.0)
 * from the machine description file "sparc/sparc.md".
 *)


functor SparcDelaySlots(structure I : SparcINSTR
                        structure P : INSN_PROPERTIES
                           where I = I
                       ) : DELAY_SLOT_PROPERTIES =
struct
   structure I = I
   datatype delay_slot = D_NONE | D_ERROR | D_ALWAYS | D_TAKEN | D_FALLTHRU 
   
   fun error msg = MLRiscErrorMsg.error("SparcDelaySlots",msg)
   val delaySlotSize = 4
   fun delaySlot {instr, backward} = let
          fun delaySlot instr = 
              (
               case instr of
               I.Bicc{b, a, label, nop} => {nop=nop, n=a andalso 
               (
                case b of
                I.BA => false
              | _ => true
               ), nOn=D_NONE, nOff=D_ALWAYS}
             | I.FBfcc{b, a, label, nop} => {nop=nop, n=a, nOn=D_NONE, nOff=D_ALWAYS}
             | I.JMP{r, i, labs, nop} => {nop=nop, n=false, nOn=D_NONE, nOff=D_ALWAYS}
             | I.JMPL{r, i, d, defs, uses, nop, mem} => {nop=nop, n=false, nOn=D_NONE, nOff=D_ALWAYS}
             | I.CALL{defs, uses, label, nop, mem} => {nop=nop, n=false, nOn=D_NONE, nOff=D_ALWAYS}
             | I.FCMP{cmp, r1, r2, nop} => {nop=nop, n=false, nOn=D_NONE, nOff=D_ALWAYS}
             | I.RET{leaf, nop} => {nop=nop, n=false, nOn=D_NONE, nOff=D_ALWAYS}
             | _ => {nop=true, n=false, nOn=D_ERROR, nOff=D_NONE}
              )
       in delaySlot instr
       end

   fun enableDelaySlot _ = error "enableDelaySlot"
   fun conflict _ = error "conflict"
   fun delaySlotCandidate {jmp, delaySlot} = let
          fun delaySlotCandidate delaySlot = 
              (
               case delaySlot of
               I.Bicc{b, a, label, nop} => false
             | I.FBfcc{b, a, label, nop} => false
             | I.JMP{r, i, labs, nop} => false
             | I.JMPL{r, i, d, defs, uses, nop, mem} => false
             | I.CALL{defs, uses, label, nop, mem} => false
             | I.Ticc{t, cc, r, i} => false
             | I.FCMP{cmp, r1, r2, nop} => false
             | I.RET{leaf, nop} => false
             | _ => true
              )
       in delaySlotCandidate delaySlot
       end

   fun setTarget _ = error "setTarget"
end

