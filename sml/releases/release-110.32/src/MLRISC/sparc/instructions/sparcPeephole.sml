(* WARNING: this is generated by running 'nowhere sparcPeephole.peep'.
 * Do not edit this file directly.
 *)

(*#line 7.1 "sparcPeephole.peep"*)
functor SparcPeephole(SparcInstr : SPARCINSTR): PEEPHOLE =
struct

(*#line 9.4 "sparcPeephole.peep"*)
   structure I = SparcInstr

(*#line 10.4 "sparcPeephole.peep"*)
   structure C = I.C

(*#line 13.4 "sparcPeephole.peep"*)
   fun peephole instrs = 
       let 
(*#line 14.8 "sparcPeephole.peep"*)
           fun isZero (I.LAB le) = (I.LabelExp.valueOf le) = 0
             | isZero (I.REG r) = (C.registerNum r) = 0
             | isZero (I.IMMED i) = i = 0
             | isZero _ = false

(*#line 19.8 "sparcPeephole.peep"*)
           fun removable (I.ARITH{a=(I.ADD | I.SUB), r, i, d}) = (C.sameColor (r, d)) andalso (isZero i)
             | removable (I.ANNOTATION{i, a}) = removable i
             | removable _ = false

(*#line 24.8 "sparcPeephole.peep"*)
           fun loop (current, instrs) = 
               let val v_3 = current
               in 
                  (case v_3 of
                    nil => instrs
                  | op :: v_2 => 
                    let val (v_0, v_1) = v_2
                    in 
                       let val i = v_0
                           and rest = v_1
                       in (if (removable i)
                             then (loop (rest, instrs))
                             else 
                             let val i = v_0
                                 and rest = v_1
                             in loop (rest, i :: instrs)
                             end)
                       end
                    end
                  )
               end
       in loop (instrs, [])
       end
end

