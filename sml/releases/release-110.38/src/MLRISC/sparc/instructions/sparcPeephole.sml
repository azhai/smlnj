(* WARNING: this is generated by running 'nowhere sparcPeephole.peep'.
 * Do not edit this file directly.
 * Version 1.2
 *)

(*#line 10.1 "sparcPeephole.peep"*)
functor SparcPeephole(
(*#line 11.5 "sparcPeephole.peep"*)
                      structure Instr : SPARCINSTR

(*#line 12.5 "sparcPeephole.peep"*)
                      structure Eval : MLTREE_EVAL

(*#line 13.7 "sparcPeephole.peep"*)
                      sharing Eval.T = Instr.T
                     ): PEEPHOLE =
struct

(*#line 16.4 "sparcPeephole.peep"*)
   structure I = Instr

(*#line 17.4 "sparcPeephole.peep"*)
   structure CB = CellsBasis

(*#line 20.4 "sparcPeephole.peep"*)
   fun peephole instrs = 
       let 
(*#line 21.8 "sparcPeephole.peep"*)
           fun isZero (I.LAB le) = (Eval.valueOf le) = 0
             | isZero (I.REG r) = (CB.registerNum r) = 0
             | isZero (I.IMMED i) = i = 0
             | isZero _ = false

(*#line 26.8 "sparcPeephole.peep"*)
           fun removable p_0 = 
               let val v_9 = p_0
                   fun state_5 () = false
                   fun state_2 (v_0, v_1, v_2) = 
                       let val d = v_0
                           and i = v_1
                           and r = v_2
                       in (CB.sameColor (r, d)) andalso (isZero i)
                       end
               in 
                  let val v_8 = v_9
                  in 
                     (case v_8 of
                       I.ANNOTATION v_5 => 
                       let val {a=v_7, i=v_6, ...} = v_5
                       in 
                          let val a = v_7
                              and i = v_6
                          in removable i
                          end
                       end
                     | I.INSTR v_5 => 
                       (case v_5 of
                         I.ARITH v_4 => 
                         let val {a=v_3, d=v_0, i=v_1, r=v_2, ...} = v_4
                         in 
                            (case v_3 of
                              I.ADD => state_2 (v_0, v_1, v_2)
                            | I.SUB => state_2 (v_0, v_1, v_2)
                            | _ => state_5 ()
                            )
                         end
                       | _ => state_5 ()
                       )
                     | _ => state_5 ()
                     )
                  end
               end

(*#line 31.8 "sparcPeephole.peep"*)
           fun loop (current, instrs) = 
               let val v_3 = current
               in 
                  (case v_3 of
                    op :: v_2 => 
                    let val (v_1, v_0) = v_2
                    in 
                       let val i = v_1
                           and rest = v_0
                       in (if (removable i)
                             then (loop (rest, instrs))
                             else 
                             let val i = v_1
                                 and rest = v_0
                             in loop (rest, i :: instrs)
                             end)
                       end
                    end
                  | nil => instrs
                  )
               end
       in loop (instrs, [])
       end
end

