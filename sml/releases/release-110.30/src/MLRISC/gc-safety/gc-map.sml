functor GCMap(GC : GC_TYPE) : GC_MAP =
struct

   structure GC = GC
   exception GCMap
   type gcmap = GC.gctype Intmap.intmap

   val GCMAP = Annotations.new(SOME(fn _ => "gcmap")) 
                 : gcmap Annotations.property

   fun toString gcmap =
   let val lookup = Intmap.map gcmap
       fun f r = "{"^GC.toString(lookup r)^"}" handle _ => "{?}"
   in  f end

   fun pr(r,gc) = "r"^Int.toString r^":"^GC.toString gc
   fun prSet S = "{"^foldr (fn (x,"") => pr x | (x,y) => pr x^","^y) "" S^"}"

   val GCLIVEIN  = Annotations.new(SOME(fn S => "livein: "^prSet S))
   val GCLIVEOUT = Annotations.new(SOME(fn S => "liveout: "^prSet S))

end
