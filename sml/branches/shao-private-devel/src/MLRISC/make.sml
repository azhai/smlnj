(*
 * Regenerates all the machine description generated files.
 * This works for only 110.32+
 *)
fun set f = #set(CM.Anchor.anchor f) (SOME("cm"))
val _ = app set
[ "Control.cm",
  "Lib.cm"
];
fun b() = CM.make "Tools/MDL/sources.cm"; 
val _ = b(); 
fun c f = MDLGen.gen(f^"/"^f^".mdl");
val _ = app c
[ "x86",
  "sparc",
  "alpha",
  "hppa",
  "ppc",
  "mips"
];
