signature SUSPENSION =
sig
   type 'a susp
   val $$ : (unit -> 'a) -> 'a susp
   val !! : 'a susp -> 'a
end

structure Suspension :> SUSPENSION =
struct
   datatype 'a thunk = VALUE of 'a | CLOSURE of unit -> 'a
   type 'a susp = 'a thunk ref 

   fun $$ e = ref(CLOSURE e)
   fun !! (ref (VALUE v)) = v
     | !! (r as ref(CLOSURE e)) = 
       let val v = e()
       in  r := VALUE v; v end  
end

(* 
 * $Log: susp.sml,v $
 * Revision 1.1.1.1  1998/11/16 21:48:55  george
 *   Version 110.10
 *
 *)
