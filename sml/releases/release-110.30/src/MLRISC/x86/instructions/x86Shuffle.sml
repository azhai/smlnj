functor X86Shuffle(I : X86INSTR) : X86SHUFFLE =
struct
  structure I = I
  structure Shuffle = Shuffle(I)

  type t = {regmap:int->int, tmp:I.ea option, dst:int list, src:int list}

  exception foo
  val shuffle =
    Shuffle.shuffle
        {mvInstr=fn{dst, src} => [I.MOVE{mvOp=I.MOVL, src=src, dst=dst}],
	 ea=I.Direct}

  (* Note, this only works with double precision floating point *) 
  val shufflefp' = 
    Shuffle.shuffle
        {mvInstr=fn{dst, src} => [I.FLDL src, I.FSTPL dst],
	 ea = I.FDirect}

  (* 
   * This version makes use of the x86 floating point stack for hardware
   * renaming! 
   *)
  fun shufflefp{regmap, tmp, src, dst} = 
  let val n =  length src
  in  if n <= 7 then 
         let fun gen(s::ss, d::ds, pushes, pops) = 
                 let val s = regmap s and d = regmap d
                 in  if s = d then gen(ss, ds, pushes, pops)
                     else gen(ss, ds, I.FLDL(I.FDirect s)::pushes, 
                                      I.FSTPL(I.FDirect d)::pops)
                 end
               | gen(_, _, pushes, pops) = List.revAppend(pushes, pops)
         in  gen(src, dst, [], []) end
      else shufflefp'{regmap=regmap, tmp=tmp, src=src, dst=dst}
  end

end

