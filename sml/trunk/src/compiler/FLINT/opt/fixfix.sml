(* copyright 1998 YALE FLINT PROJECT *)
(* monnier@cs.yale.edu *)

(* This module does various FIX-related transformations:
 * - FIXes are split into their strongly-connected components
 * - small non-recursive functions are marked inlinable
 * - curried functions are uncurried
 *)

signature FIXFIX =
sig
    val fixfix : FLINT.prog -> FLINT.prog
end

(* Maybe later:
 * - hoisting of inner functions out of their englobing function
 *   so that the outer function becomes smaller, giving more opportunity
 *   for inlining.
 * - eta expand escaping functions
 * - loop-preheader introduction
 *)

structure FixFix :> FIXFIX =
struct

local
    structure F  = FLINT
    structure S = IntRedBlackSet
    structure M = IntRedBlackMap
    structure PP = PPFlint
    structure LT = LtyExtern
    structure LK = LtyKernel
    structure OU = OptUtils
    structure CTRL = FLINT_Control
in

val say = Control_Print.say
fun bug msg = ErrorMsg.impossible ("FixFix: "^msg)
fun buglexp (msg,le) = (say "\n"; PP.printLexp le; say " "; bug msg)
fun bugval (msg,v) = (say "\n"; PP.printSval v; say " "; bug msg)
fun assert p = if p then () else bug ("assertion failed")
fun bugsay s = say ("!*!*! Fixfix: "^s^" !*!*!\n")

val cplv = LambdaVar.dupLvar

(* to limit the amount of uncurrying *)
val maxargs = CTRL.maxargs

structure SccNode = struct
    type node = LambdaVar.lvar
    val eq = (op =)
    val lt = (op <)
end
structure SCC = SCCUtilFun (structure Node = SccNode)

datatype info = Fun of int ref
	      | Arg of int * (int * int) ref

(* fexp: int ref intmapf -> lexp) -> (int * intset * lexp)
 * The intmap contains refs to counters.  The meaning of the counters
 * is slightly overloaded:
 * - if the counter is negative, it means the lvar
 *   is a locally known function and the counter's absolute value denotes
 *   the number of calls (off by one to make sure it's always negative).
 * - else, it indicates that the lvar is a
 *   function argument and the absolute value is a (fuzzily defined) measure
 *   of the reduction in code size/speed that would result from knowing
 *   its value (might be used to decide whether or not duplicating code is
 *   desirable at a specific call site).
 * The three subparts returned are:
 * - the size of lexp
 * - the set of freevariables of lexp (plus the ones passed as arguments
 *   which are assumed to be the freevars of the continuation of lexp)
 * - a new lexp with FIXes rewritten.
 *)
fun fexp mf depth lexp = let

    val loop = fexp mf depth

    fun lookup (F.VAR lv) = M.find(mf, lv)
      | lookup _ = NONE

    fun S_rmv(x, s) = S.delete(s, x) handle NotFound => s

    fun addv (s,F.VAR lv) = S.add(s, lv)
      | addv (s,_) = s
    fun addvs (s,vs) = foldl (fn (v,s) => addv(s, v)) s vs
    fun rmvs (s,lvs) = foldl (fn (l,s) => S_rmv(l, s)) s lvs

    (* Looks for free vars in the primop descriptor.
     * This is normally unnecessary since these are special vars anyway *)
    fun fpo (fv,(NONE:F.dict option,po,lty,tycs)) = fv
      | fpo (fv,(SOME{default,table},po,lty,tycs)) =
	addvs(addv(fv, F.VAR default), map (F.VAR o #2) table)

    (* Looks for free vars in the primop descriptor.
     * This is normally unnecessary since these are exception vars anyway *)
    fun fdcon (fv,(s,Access.EXN(Access.LVAR lv),lty)) = addv(fv, F.VAR lv)
      | fdcon (fv,_) = fv

    (* recognize the curried essence of a function.
     * - hd:fkind option identifies the head of the curried function
     * - na:int gives the number of args still allowed *)
    fun curry (hd,na)
	      (le as (F.FIX([(fk as {inline=F.IH_SAFE,...},f,args,body)],
			    F.RET[F.VAR lv]))) =
	if lv = f andalso na >= length args then
	    case (hd,fk)
	     of ((* (SOME{isrec=NONE,...},{isrec=SOME _,...}) | *)
		 (SOME{cconv=F.CC_FCT,...},{cconv=F.CC_FUN _,...}) |
		 (SOME{cconv=F.CC_FUN _,...},{cconv=F.CC_FCT,...})) =>
		([], le)
	      (* | ((NONE,_) |
	            (SOME{isrec=SOME _,...},_) |
	            (SOME{isrec=NONE,...},{isrec=NONE,...})) => *)
	      (* recursive functions are only accepted for uncurrying
	       * if they are the head of the function or if the head
	       * is already recursive *)
	      | _ =>
		let val (funs,body) = curry (SOME fk, na - (length args)) body
		in ((fk,f,args)::funs,body)
		end
	else
	    (* this "never" occurs, but dead-code removal is not bullet-proof *)
	    ([], le)
      | curry _ le = ([], le)

    exception Uncurryable

    (* do the actual uncurrying *)
    fun uncurry (args as (fk,f,fargs)::_::_,body) =
	let val f' = cplv f	(* the new fun name *)

	    (* find the rtys of the uncurried function *)
	    fun getrtypes (({isrec=SOME(rtys,_),...}:F.fkind,_,_),_) = SOME rtys
	      | getrtypes ((_,_,_),rtys) =
		Option.map (fn [lty] => #2(LT.ltd_fkfun lty)
			     | _ => bug "strange isrec") rtys

	    (* create the new fkinds *)
	    val ncconv = case #cconv(#1(List.last args)) of
		F.CC_FUN(LK.FF_VAR(_,raw)) => F.CC_FUN(LK.FF_VAR(true, raw))
	      | cconv => cconv
	    val (nfk,nfk') = OU.fk_wrap(fk, foldl getrtypes NONE args)
	    val nfk' = {inline= #inline nfk', isrec= #isrec nfk',
			known= #known nfk', cconv= ncconv}

	    (* funarg renaming *)
	    fun newargs fargs = map (fn (a,t) => (cplv a,t)) fargs

	    (* create (curried) wrappers to be inlined *)
	    fun recurry ([],args) = F.APP(F.VAR f', map (F.VAR o #1) args)
	      | recurry (({inline,isrec,known,cconv},f,fargs)::rest,args) =
		let val fk = {inline=F.IH_ALWAYS, isrec=NONE,
			      known=known, cconv=cconv}
		    val nfargs = newargs fargs
		    val g = cplv f'
		in F.FIX([(fk, g, nfargs, recurry(rest, args @ nfargs))],
			 F.RET[F.VAR g])
		end

	    (* build the new f fundec *)
	    val nfargs = newargs fargs
	    val nf = (nfk, f, nfargs, recurry(tl args, nfargs))

	    (* make up the body of the uncurried function (creating
	     * dummy wrappers for the intermediate functions that are now
	     * useless).
	     * Intermediate functions that were not marked as recursive
	     * cannot appear in the body, so we don't need to build them.
	     * Note that we can't just rely on dead-code elimination to remove
	     * them because we may not be able to create them correctly with
	     * the limited type information gleaned in this phase. *)
	    fun uncurry' ([],args) = body
	      | uncurry' ((fk,f,fargs)::rest,args) =
		let val le = uncurry'(rest, args @ fargs)
		in case fk
		    of {isrec=SOME _,cconv,known,inline} =>
		       let val nfargs = newargs fargs
			   val fk = {isrec=NONE, inline=F.IH_ALWAYS,
				     known=known, cconv=cconv}
		       in F.FIX([(fk, f, nfargs,
				  recurry(rest, args @ nfargs))],
				le)
		       end
		     | _ => le
		end

	    (* the new f' fundec *)
	    val nfbody' = uncurry'(tl args, fargs)
	    val nf' = (nfk', f', foldr (op @) [] (map #3 args), nfbody')

	in (nf, nf')
	end
      | uncurry (_,body) = bug "uncurrying a non-curried function"

in case lexp
    of F.RET vs => (0, addvs(S.empty, vs), lexp)
     | F.LET (lvs,body,le) =>
       let val (s2,fvl,nle) = loop le
	   val (s1,fvb,nbody) = loop body
       in (s1 + s2, S.union(rmvs(fvl, lvs), fvb), F.LET(lvs, nbody, nle))
       end
     | F.FIX (fdecs,le) =>
       let val funs = S.addList(S.empty, map #2 fdecs) (* set of funs defined by the FIX *)

	   (* create call-counters for each fun and add them to fm *)
	   val (fs,mf) = foldl (fn ((fk,f,args,body),(fs,mf)) =>
				let val c = ref 0
				in ((fk, f, args, body, c)::fs,
				    M.insert(mf, f, Fun c))
				end)
			       ([],mf)
			       fdecs

	   (* process each fun *)
	   fun ffun (fdec as (fk as {isrec,...}:F.fkind,f,args,body,cf),
		     (s,fv,funs,m)) =
	       case curry (NONE,!maxargs)
			  (F.FIX([(fk,f,args,body)], F.RET[F.VAR f]))
		of (args as _::_::_,body) => (* curried function *)
		   let val ((fk,f,fargs,fbody),(fk',f',fargs',fbody')) =
			   uncurry(args,body)
		       (* add the wrapper function *)
		       val cs = map (fn _ => ref(0,0)) fargs
		       val nm = M.insert(m, f, ([f'], 1, fk, fargs, fbody, cf, cs))
		   (* now, retry ffun with the uncurried function *)
		   in ffun((fk', f', fargs', fbody', ref 1),
			   (s+1, fv, S.add(funs, f'), nm))
		   end
		 | _ =>	(* non-curried function *)
		   let val newdepth =
			   case isrec
			    of SOME(_,(F.LK_TAIL | F.LK_LOOP)) => depth + 1
			     | _ => depth
		       val (mf,cs) = foldr (fn ((v,t),(m,cs)) =>
					    let val c = ref(0, 0)
					    in (M.insert(m, v, Arg(newdepth, c)),
						c::cs) end)
					   (mf,[]) args
		       val (fs,ffv,body) = fexp mf newdepth body
		       val ffv = rmvs(ffv, map #1 args) (* fun's freevars *)
		       val ifv = S.intersection(ffv, funs) (* set of rec funs ref'ed *)
		   in
		       (fs + s, S.union(ffv, fv), funs,
			M.insert(m,f,(S.listItems ifv, fs, fk, args, body, cf, cs)))
		   end

	   (* process the main lexp and make it into a dummy function.
	    * The computation of the freevars is a little sloppy since `fv'
	    * includes freevars of the continuation, but the uniqueness
	    * of varnames ensures that S.inter(fv, funs) gives the correct
	    * result nonetheless. *)
	   val (s,fv,le) = fexp mf depth le
	   val lename = LambdaVar.mkLvar()
	   val m = M.insert(M.empty,
			    lename, 
			    (S.listItems(S.intersection(fv, funs)), 0,
			     {inline=F.IH_SAFE, isrec=NONE, 
			      known=true,cconv=F.CC_FCT},
			     [], le, ref 0, []))

	   (* process the functions, collecting them in map m *)
	   val (s,fv,funs,m) = foldl ffun (s, fv, funs, m) fs

	   (* find strongly connected components *)
	   val top = 
	     SCC.topOrder{root=lename, 
			  follow=(fn n => #1(Option.valOf(M.find(m,n))))}
	       handle x => (bug "top:follow"; raise x)

	   (* turns them back into flint code *)
	   fun sccSimple f (_,s,{isrec,cconv,known,inline},args,body,cf,cs) =
	       let (* small functions inlining heuristic *)
		   val ilthreshold = !CTRL.inlineThreshold + (length args)
		   val ilh =
		       if inline = F.IH_ALWAYS then inline
		       (* else if s < ilthreshold then F.IH_ALWAYS *)
		       else let val cs = map (fn ref(sp,ti) => sp + ti div 2) cs
				val s' = foldl (op+) 0 cs
		       in if s < 2*s' + ilthreshold
			  then ((* say((Collect.LVarString f)^
				" {"^(Int.toString(!cf))^
				"} = F.IH_MAYBE "^
				(Int.toString (s-ilthreshold))^
				(foldl (fn (i,s) => s^" "^
				        (Int.toString i))
				       "" cs)^"\n"); *)
				F.IH_MAYBE (s-ilthreshold, cs))
			  else inline
		       end
		   val fk = {isrec=NONE, inline=ilh, known=known, cconv=cconv}
	       in (fk, f, args, body)
	       end
	   fun sccRec f (_,s,fk as {isrec,cconv,known,inline},args,body,cf,cs) =
	       let val fk' =
		       (* let's check for unroll opportunities.
			* This heuristic is pretty bad since it doesn't
			* take the number of rec-calls into account *)
		       case (isrec,inline)
			of (SOME(_,(F.LK_LOOP|F.LK_TAIL)),F.IH_SAFE) =>
			   if s < !CTRL.unrollThreshold then
			       {inline=F.IH_UNROLL, isrec=isrec,
				cconv=cconv, known=known}
			   else fk
			 | _ => fk
	       in (fk, f, args, body)
	       end
	   fun sccconvert (SCC.SIMPLE f,le) =
	       F.FIX([sccSimple f (Option.valOf(M.find(m, f)))], le)
	     | sccconvert (SCC.RECURSIVE fs,le) =
	       F.FIX(map (fn f => sccRec f (Option.valOf(M.find(m, f)))) fs, le)
       in
	   case top
	    of (SCC.SIMPLE f)::sccs =>
	       ((if (f = lename) then () else bugsay "f != lename");
		(s, S.difference(fv, funs), foldl sccconvert le sccs))
	     | (SCC.RECURSIVE _)::_ => bug "recursive main body in SCC ?!?!?"
	     | [] => bug "SCC going crazy"
       end
     | F.APP (F.VAR f,args) =>
       (* For known functions, increase the counter and
	* make the call a bit cheaper. *)
       let val scall =
	       (case M.find(mf, f)
		 of SOME(Fun(fc as ref c)) => (fc := c + 1; 1)
		  | SOME(Arg(d, ac as ref (sp,ti))) =>
		    (ac := (4 + sp, OU.pow2(depth - d) * 30 + ti); 5)
		  | NONE => 5)
       in
	   (scall + (length args), addvs(S.singleton f, args), lexp)
       end
     | F.TFN ((tfk,f,args,body),le) =>
       let val (se,fve,le) = loop le
	   val (sb,fvb,body) = loop body
       in (sb + se, S.union(S_rmv(f, fve), fvb),
	   F.TFN((tfk, f, args, body), le))
       end
     | F.TAPP (F.VAR f,args) =>
       (* The cost of TAPP is kinda hard to estimate.  It can be very cheap,
	* and just return a function, or it might do all kinds of wrapping
	* but we have almost no information on which to base our choice.
	* We opted for cheap here, to try to inline them more (they might
	* become cheaper once inlined) *)
       (3, S.singleton f, lexp)
     | F.SWITCH (v,ac,arms,def) =>
       let fun farm (dcon as F.DATAcon(dc,_,lv),le) =
	       (* the binding might end up costly, but we count it as 1 *)
	       let val (s,fv,le) = loop le
	       in (1+s, fdcon(S_rmv(lv, fv),dc), (dcon, le))
	       end
	     | farm (dc,le) =
	       let val (s,fv,le) = loop le in (s, fv, (dc, le)) end
	   val narms = length arms
	   val (s,smax,fv,arms) =
	       foldl (fn ((s1,fv1,arm),(s2,smax,fv2,arms)) =>
		      (s1+s2, Int.max(s1,smax), S.union(fv1, fv2), arm::arms))
		     (narms, 0, S.empty, []) (map farm arms)
       in (case lookup v
	    of SOME(Arg(d,ac as ref(sp,ti))) =>
	       ac := (sp + s - smax + narms, OU.pow2(depth - d) * 2 + ti)
	     | _ => ());
	   case def
	    of NONE => (s, fv, F.SWITCH(v, ac, arms, NONE))
	     | SOME le => let val (sd,fvd,le) = loop le
	       in (s+sd, S.union(fv, fvd), F.SWITCH(v, ac, arms, SOME le))
	       end
       end
     | F.CON (dc,tycs,v,lv,le) =>
       let val (s,fv,le) = loop le
       in (2+s, fdcon(addv(S_rmv(lv, fv), v),dc), F.CON(dc, tycs, v, lv, le))
       end
     | F.RECORD (rk,vs,lv,le) =>
       let val (s,fv,le) = loop le
       in ((length vs)+s, addvs(S_rmv(lv, fv), vs), F.RECORD(rk, vs, lv, le))
       end
     | F.SELECT (v,i,lv,le) =>
       let val (s,fv,le) = loop le
       in (case lookup v
	    of SOME(Arg(d,ac as ref(sp,ti))) =>
	       ac := (sp + 1, OU.pow2(depth - d) + ti)
	     | _ => ());
	   (1+s, addv(S_rmv(lv, fv), v), F.SELECT(v,i,lv,le))
       end
     | F.RAISE (F.VAR v,ltys) =>
       (* artificially high size estimate to discourage inlining *)
       (15, S.singleton v, lexp)
     | F.HANDLE (le,v) =>
       let val (s,fv,le) = loop le
       in (2+s, addv(fv, v), F.HANDLE(le,v))
       end
     | F.BRANCH (po,vs,le1,le2) =>
       let val (s1,fv1,le1) = loop le1
	   val (s2,fv2,le2) = loop le2
       in (1+s1+s2, fpo(addvs(S.union(fv1, fv2), vs), po),
	   F.BRANCH(po, vs, le1, le2))
       end
     | F.PRIMOP (po,vs,lv,le) =>
       let val (s,fv,le) = loop le
       in (1+s, fpo(addvs(S_rmv(lv, fv), vs),po), F.PRIMOP(po,vs,lv,le))
       end

     | F.APP _ => bug "bogus F.APP"
     | F.TAPP _ => bug "bogus F.TAPP"
     | F.RAISE _ => bug "bogus F.RAISE"
end

fun fixfix ((fk,f,args,body):F.prog) =
    let val (s,fv,nbody) = fexp M.empty 0 body
	val fv = S.difference(fv, S.addList(S.empty, map #1 args))
    in
	(*  PPFlint.printLexp(F.RET(map F.VAR (S.members fv))); *)
	assert(S.isEmpty(fv));
	(fk, f, args, nbody)
    end

end
end

