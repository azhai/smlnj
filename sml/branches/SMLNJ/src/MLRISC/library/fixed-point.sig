signature FIXED_POINT =
sig
   eqtype fixed_point

   val fixed_point  : int * int -> fixed_point

   val zero     : fixed_point
   val one      : fixed_point

   val <        : fixed_point * fixed_point -> bool
   val >        : fixed_point * fixed_point -> bool
   val >=       : fixed_point * fixed_point -> bool
   val <=       : fixed_point * fixed_point -> bool
   val !=       : fixed_point * fixed_point -> bool
   val ==       : fixed_point * fixed_point -> bool
   val compare  : fixed_point * fixed_point -> order

   val +        : fixed_point * fixed_point -> fixed_point
   val -        : fixed_point * fixed_point -> fixed_point
   val *        : fixed_point * fixed_point -> fixed_point
   val /        : fixed_point * fixed_point -> fixed_point
   val scale    : fixed_point * int -> fixed_point
   val div      : fixed_point * int -> fixed_point
   val min      : fixed_point * fixed_point -> fixed_point
   val max      : fixed_point * fixed_point -> fixed_point

   val toString : fixed_point -> string
   val toReal   : fixed_point -> real
   val toWord   : fixed_point -> word
   val fromReal : real -> fixed_point
   val fromInt  : int -> fixed_point
end

(*
 * $Log: fixed-point.sig,v $
 * Revision 1.1.1.1  1998/11/16 21:48:55  george
 *   Version 110.10
 *
 *)
