(* base.sml
 *
 * COPYRIGHT (c) 1997 Bell Labs, Lucent Technologies.
 *
 * Some common code for testing.
 *)

CM.make(); (* to compile and load the PP library *)

structure TextToken =
  struct
    type token = string
    type style = unit
    fun string t = t
    fun style t = ()
    fun size t = String.size t
  end;

structure PP = PPDebugFn(PPStreamFn(
    structure Token = TextToken
    structure Device = SimpleTextIODev));

fun withPP (name, wid) ppFn = let
      val saveStrm = !PP.debugStrm
      val _ = PP.debugStrm := TextIO.openAppend("out")
      val ppStrm =
	    PP.openStream(SimpleTextIODev.openDev{dst=TextIO.stdOut, wid=wid})
      in
	print(concat[name, ": width = ", Int.toString wid, "\n"]);
	ppFn ppStrm;
	PP.closeStream ppStrm;
	print "\n";
	TextIO.closeOut (!PP.debugStrm);
	PP.debugStrm := saveStrm
      end;

