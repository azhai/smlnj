signature X86SHUFFLE = sig
  structure I : X86INSTR

  type t = {regMap:int->int, temp:I.ea option, dst:int list, src:int list}

  val shuffle : t -> I.instruction list
  val shufflefp : t -> I.instruction list
end
