(* COPYRIGHT (c) 1997, 1998 YALE FLINT PROJECT *)
(* chkflint.sml *)

(* FLINT Type Checker *)

signature CHKFLINT = sig 

(** which set of the typing rules to use while doing the typecheck *)
type typsys (* currently very crude *)

val checkTop : FLINT.fundec * typsys -> bool
val checkExp : FLINT.lexp * typsys -> bool

end (* signature CHKFLINT *)

structure ChkFlint : CHKFLINT = 
struct

(** which set of the typing rules to use while doing the typecheck *)
type typsys = bool (* currently very crude *)

local structure LT = LtyExtern
      structure LV = LambdaVar
      structure DA = Access 
      structure DI = DebIndex
      structure PP = PPFlint
      structure PO = PrimOp
      open FLINT

fun bug s = ErrorMsg.impossible ("ChkFlint: "^s)
val say = Control.Print.say
val anyerror = ref false

(****************************************************************************
 *                         BASIC UTILITY FUNCTIONS                          *
 ****************************************************************************)

fun foldl2 (f,a,xs,ys,g) = let
  val rec loop =
   fn (a, nil, nil) => a
    | (a, x::xs, y::ys) => loop (f (x,y,a), xs, ys)
    | (a, xs', _) => g (a, xs', length xs, length ys)
  in loop (a,xs,ys) end

fun simplify (le,0) = RET [STRING "<...>"]
  | simplify (le,n) = 
      let fun h le = simplify (le, n-1)
          fun h1 (fk,v,args,le) = (fk, v, args, h le)
          fun h2 (v,tvs,le) = (v, tvs, h le)
       in case le 
           of LET (vs,e1,e2) => LET (vs, h e1, h e2)
            | FIX (fdecs,b) => FIX (map h1 fdecs, h b)
            | TFN (tdec,e) => TFN (h2 tdec, h e)
            | SWITCH (v,l,dc,opp) => 
                let fun g (c,x) = (c, h x)
                    val f = fn SOME y => SOME (h y) | NONE => NONE
                 in SWITCH (v, l, map g dc, f opp)
                end
	    | CON (dc,tcs,vs,lv,le) => CON (dc, tcs, vs, lv, h le)
	    | RECORD (rk,vs,lv,le) => RECORD (rk, vs, lv, h le)
	    | SELECT (v,n,lv,le) => SELECT (v, n, lv, h le)
            | HANDLE (e,v) => HANDLE (h e, v)
	    | PRIMOP (po,vs,lv,le) => PRIMOP (po, vs, lv, h le)
            | _ => le
      end (* end of simplify *)

(** utility functions for printing *)
val tkPrint = say o LT.tk_print
val tcPrint = say o LT.tc_print
val ltPrint = say o LT.lt_print
fun lePrint le = PP.printLexp (simplify (le, 3))
val svPrint = PP.printSval

fun error (le,g) = (
    anyerror := true;
    say "\n************************************************************\
        \\n**** FLINT type checking failed: ";
    g () before (say "\n** term:\n"; lePrint le))

fun errMsg (le,s,r) = error (le, fn () => (say s; r))

fun catchExn f (le,g) =
  f () handle ex => error
    (le, fn () => g () before say ("\n** exception " ^ exnName ex ^ " raised"))

(*** a hack for type checkng ***)
fun laterPhase postReify = postReify

fun check phase envs lexp = let
  val ltEquiv = LT.lt_eqv_x (* should be LT.lt_eqv *)
  val ltTAppChk =
    if !Control.CG.checkKinds then LT.lt_inst_chk_gen()
    else fn (lt,ts,_) => LT.lt_inst(lt,ts)

  fun constVoid _ = LT.ltc_void
  val (ltString,ltExn,ltEtag,ltVector,ltWrap,ltBool) =
    if laterPhase phase then
      (LT.ltc_string, LT.ltc_void, constVoid, constVoid, constVoid, 
       LT.ltc_void)
    else
      (LT.ltc_string, LT.ltc_exn, LT.ltc_etag, LT.ltc_tyc o LT.tcc_vector, 
       LT.ltc_tyc o LT.tcc_box, LT.ltc_bool)

  fun prMsgLt (s,lt) = (say s; ltPrint lt)

  fun prList f s t = let
    val rec loop =
     fn [] => say "<empty list>\n"
      | [x] => (f x; say "\n")
      | x::xs => (f x; say "\n* and\n"; loop xs)
    in say s; loop t end

  fun print2Lts (s,s',lt,lt') = (prList ltPrint s lt; prList ltPrint s' lt')

  fun ltMatch (le,s) (t,t') =
    if ltEquiv (t,t') then ()
    else error
      (le, fn () =>
	      (prMsgLt (s ^ ": Lty conflict\n** types:\n", t);
	       prMsgLt ("\n** and\n", t')))

  fun ltsMatch (le,s) (ts,ts') =
    foldl2 (fn (t,t',_) => ltMatch (le,s) (t,t'),
	    (), ts, ts',
	    fn (_,_,n,n') => error
	       (le,
		fn () => print2Lts
	          (concat [s, ": type list mismatch (", Int.toString n, " vs ",
			   Int.toString n', ")\n** expected types:\n"],
		   "** actual types:\n",
		   ts, ts')))

  local
    fun ltFnAppGen opr (le,s,msg) (t,ts) =
      catchExn
        (fn () => let val (xs,ys) = opr (LT.ltd_fkfun t)
                   in ltsMatch (le,s) (xs,ts); ys
                  end)
	(le, fn () => (prMsgLt (s ^ msg ^ "\n** type:\n", t); []))
  in
  fun ltFnApp (le,s) =
      ltFnAppGen (fn x => x) (le,s,": Applying term of non-arrow type")
  fun ltFnAppR (le,s) =
      ltFnAppGen (fn (x,y) => (y,x)) (le,s,": Rev-app term of non-arrow type")
  end

  fun ltTyApp (le,s) (lt,ts,kenv) =
    catchExn
      (fn () => ltTAppChk (lt,ts,kenv))
      (le,
       fn () =>
	  (prMsgLt (s ^ ": Kind conflict\n** function Lty:\n", lt);
	   prList tcPrint "\n** argument Tycs:\n" ts;
	   []))

  fun ltArrow (le,s) (isfct,alts,rlts) = 
    (case isfct 
      of NONE => LT.ltc_fct (alts,rlts)
       | SOME raw => 
           (catchExn
             (fn () => LT.ltc_arrow (raw,alts,rlts))
             (le,
              fn () =>
              (print2Lts
   	        (s ^ ": deeply polymorphic non-functor\n** parameter types:\n",
  	         "** result types:\n",
	         alts, rlts);
	      LT.ltc_void))))

(* typeInEnv : LT.tkindEnv * LT.ltyEnv * DI.depth -> lexp -> lty list *)
  fun typeInEnv (kenv,venv,d) = let
    fun extEnv (lv,lt,ve) = LT.ltInsert (ve,lv,lt,d)
    fun bogusBind (lv,ve) = extEnv (lv,LT.ltc_void,ve)
    fun typeIn venv' = typeInEnv (kenv,venv',d)
    fun typeWith (v,t) = typeIn (LT.ltInsert (venv,v,t,d))
    fun mismatch (le,s) (a,r,n,n') = errMsg
	(le,
	 concat [s, ": binding/result list mismatch\n** expected ",
		 Int.toString n, " elements, got ", Int.toString n'],
	 foldl bogusBind a r)

    fun typeof le = let
      fun typeofVar lv = LT.ltLookup (venv,lv,d)
	  handle ltUnbound =>
	      errMsg (le, "Unbound Lvar " ^ LV.lvarName lv, LT.ltc_void)
      val typeofVal =
       fn VAR lv => typeofVar lv
	| (INT _ | WORD _) => LT.ltc_int
	| (INT32 _ | WORD32 _) => LT.ltc_int32
	| REAL _ => LT.ltc_real
	| STRING _ => LT.ltc_string
      fun typeofFn ve (_,_,vts,eb) = let
	fun split ((lv,t), (ve,ts)) = (LT.ltInsert (ve,lv,t,d), t::ts)
	val (ve',ts) = foldr split (ve,[]) vts
	in (ts, typeIn ve' eb)
	end

      fun chkSnglInst (fp as (le,s)) (lt,ts) =
	if null ts then lt
	else case ltTyApp fp (lt,ts,kenv)
	   of [] => LT.ltc_unit
	    | [lt] => lt
	    | lts => errMsg
		(le,
		 concat [s, ": inst yields ", Int.toString (length lts),
			 " results instead of 1"],
		 LT.ltc_void)
      fun typeWithBindingToSingleRsltOfInstAndApp (s,lt,ts,vs,lv) e = let
	val fp = (le,s)
	val lt = case ltFnApp fp (chkSnglInst fp (lt,ts), map typeofVal vs)
	   of [lt] => lt
            | _ => errMsg
               (le, 
                concat [s, ": primop/dcon must return single result type "],
                LT.ltc_void)
(*
	    | [] => LT.ltc_unit
	    | lts => LT.ltc_tuple lts
	            (*** until PRIMOPs start returning multiple results... ***)
*)
	in typeWith (lv,lt) e
	end

      fun matchAndTypeWith (s,v,lt,lt',lv,e) =
	(ltMatch (le,s) (typeofVal v, lt); typeWith (lv, lt') e)
      in case le
       of RET vs => map typeofVal vs
	| LET (lvs,e,e') =>
	  typeIn (foldl2 (extEnv, venv, lvs, typeof e, mismatch (le,"LET"))) e'
	| FIX ([],e) =>
	  (say "\n**** Warning: empty declaration list in FIX\n"; typeof e)
	| FIX ((fd as ((FK_FUN{isrec=NONE,...} | FK_FCT), 
                       _, _, _)) :: fds', e) => let
	    val (fk, lv, _, _) = fd
            val isfct = case fk of FK_FCT => NONE
                                 | FK_FUN{fixed, ...} => SOME fixed
	    val (alts,rlts) = typeofFn venv fd
	    val lt = ltArrow (le,"non-rec FIX") (isfct,alts,rlts)
	    val ve = extEnv (lv,lt,venv)
	    val venv' =
	      if null fds' then ve
	      else errMsg
		(le,
		 "multiple bindings in FIX, not all recursive",
		 foldl (fn ((_,lv,_,_), ve) => bogusBind (lv,ve)) ve fds')
	    in typeIn venv' e
	    end
	| FIX (fds,e) => let
            val isfct = false
	    fun extEnv ((FK_FCT, _, _, _), _) =
                  bug "unexpected case in extEnv"
              | extEnv ((FK_FUN {isrec,fixed,...}, lv, vts, _) : fundec, ve) =
	      case (isrec, isfct)
	       of (SOME lts, false) => let
		    val lt = ltArrow (le,"FIX") (SOME fixed, 
                                                 map #2 vts, lts)
		    in LT.ltInsert (ve,lv,lt,d)
		    end
		| _ => let
		    val msg =
		      if isfct then "recursive functor "
		      else "a non-recursive function "
		    in errMsg (le, "in FIX: " ^ msg ^ LV.lvarName lv, ve)
		    end
	    val venv' = foldl extEnv venv fds
	    fun chkDcl ((FK_FUN {isrec = NONE, ...}, _, _, _) : fundec) = ()
	      | chkDcl (fd as (FK_FUN {isrec = SOME lts, ...}, _, _, _)) = let
		in ltsMatch (le,"FIX") (lts, #2 (typeofFn venv' fd))
		end
              | chkDcl _ = ()
	    in
	      app chkDcl fds;
	      typeIn venv' e
	    end
	| APP (v,vs) => ltFnApp (le,"APP") (typeofVal v, map typeofVal vs)
	| TFN ((lv,tks,e), e') => let
	    val ks = map #2 tks
	    val lts = typeInEnv (LT.tkInsert (kenv,ks), venv, DI.next d) e
	    in typeWith (lv, LT.ltc_poly (ks,lts)) e'
	    end
	| TAPP (v,ts) => ltTyApp (le,"TAPP") (typeofVal v, ts, kenv)
	| SWITCH (_,_,[],_) => errMsg (le,"empty SWITCH",[])
	| SWITCH (v, _, ce::ces, lo) => let
	    val selLty = typeofVal v
	    fun g lt = (ltMatch (le,"SWITCH branch 1") (lt,selLty); venv)
	    fun brLts (c,e) = let
	      val venv' = case c
		 of DATAcon ((_,_,lt), ts, v) => let
		      val fp = (le,"SWITCH DECON")
		      val ct = chkSnglInst fp (lt,ts)
		      val nts = ltFnAppR fp (ct, [selLty])
		      in foldl2 (extEnv, venv, [v], nts, mismatch fp)
		      end
		  | (INTcon _ | WORDcon _) => g LT.ltc_int
		  | (INT32con _ | WORD32con _) => g LT.ltc_int32
		  | REALcon _ => g LT.ltc_real
		  | STRINGcon _ => g ltString
		  | VLENcon _ => g LT.ltc_int (* ? *)
	      in typeIn venv' e
	      end
	    val ts = brLts ce
	    fun chkBranch (ce,n) =
	      (ltsMatch (le, "SWITCH branch " ^ Int.toString n) (ts, brLts ce);
	       n+1)
	    in
	      foldl chkBranch 2 ces;
	      case lo
	       of SOME e => ltsMatch (le,"SWITCH else") (ts, typeof e)
		| NONE => ();
	      ts
	    end
	| CON ((_,_,lt), ts, u, lv, e) =>
	  typeWithBindingToSingleRsltOfInstAndApp ("CON",lt,ts,[u],lv) e
	| RECORD (rk,vs,lv,e) => let
	    val lt = case rk
	       of RK_VECTOR t => let
		    val lt = LT.ltc_tyc t
		    val match = ltMatch (le,"VECTOR")
		    in
		      app (fn v => match (lt, typeofVal v)) vs;
		      ltVector t
		    end
		| RK_TUPLE _ => 
		  if null vs then LT.ltc_unit
		  else let
		    fun chkMono v = let val t = typeofVal v
			in
			  if LT.ltp_fct t orelse LT.ltp_poly t then
			    error (le, fn () =>
			        prMsgLt
				  ("RECORD: poly type in mono record:\n",t))
			  else ();
			  t
			end
		    in LT.ltc_tuple (map chkMono vs)
		    end
		| RK_STRUCT => LT.ltc_str (map typeofVal vs)
	    in typeWith (lv,lt) e
	    end
	| SELECT (v,n,lv,e) => let
	    val lt = catchExn
		(fn () => LT.lt_select (typeofVal v, n))
		(le,
		 fn () =>
		    (say "SELECT from wrong type or out of range"; LT.ltc_void))
	    in typeWith (lv,lt) e
	    end
	| RAISE (v,lts) => (ltMatch (le,"RAISE") (typeofVal v, ltExn); lts)
	| HANDLE (e,v) => let val lts = typeof e
	    in ltFnAppR (le,"HANDLE") (typeofVal v, lts); lts
	    end
	| BRANCH ((_,_,lt,ts), vs, e1, e2) => 
            let val fp = (le, "BRANCH")
                val lt = 
	          case ltFnApp fp (chkSnglInst fp (lt,ts), map typeofVal vs)
	           of [lt] => lt
                    | _ => errMsg
                            (le, 
                             "BRANCK : primop must return single result ",
                             LT.ltc_void)
                val _ = ltMatch fp (lt, ltBool)
                val lts1 = typeof e1
                val lts2 = typeof e2
             in ltsMatch fp (lts1, lts2);
                lts1
            end
        | PRIMOP ((_,PO.WCAST,lt,[]), [u], lv, e) => 
            (*** a hack: checked only after reifY is done ***)
            if laterPhase phase then
              (case LT.ltd_fct lt
                of ([argt], [rt]) => 
                      (ltMatch (le, "WCAST") (typeofVal u, argt); 
                       typeWith (lv, rt) e)
                 | _ => bug "unexpected WCAST in typecheck")
            else bug "unexpected WCAST in typecheck"
	| PRIMOP ((_,_,lt,ts), vs, lv, e) => 
	  typeWithBindingToSingleRsltOfInstAndApp ("PRIMOP",lt,ts,vs,lv) e
(*
	| GENOP (dict, (_,lt,ts), vs, lv, e) =>
	  (* verify dict ? *)
	  typeWithBindingToSingleRsltOfInstAndApp ("GENOP",lt,ts,vs,lv) e
	| ETAG (t,v,lv,e) =>
	  matchAndTypeWith ("ETAG", v, ltString, ltEtag (LT.ltc_tyc t), lv, e)
	| WRAP (t,v,lv,e) =>
	  matchAndTypeWith ("WRAP", v, LT.ltc_tyc t, ltWrap t, lv, e)
	| UNWRAP (t,v,lv,e) =>
	  matchAndTypeWith ("UNWRAP", v, ltWrap t, LT.ltc_tyc t, lv, e)
*)
      end
    in typeof end

in
  anyerror := false;
  ignore (typeInEnv envs lexp);
  !anyerror
end

in (* loplevel local *)

(****************************************************************************
 *  MAIN FUNCTION --- val checkTop : FLINT.fundec * typsys -> bool          *
 ****************************************************************************)
fun checkTop ((fkind, v, args, lexp) : fundec, phase) = let
  val ve =
    foldl (fn ((v,t), ve) => LT.ltInsert (ve,v,t,DI.top)) LT.initLtyEnv args
  val err = check phase (LT.initTkEnv, ve, DI.top) lexp
  val err = case fkind
     of FK_FCT => err
      | _ => (say "**** Not a functor at top level\n"; true)
  in err end

val checkTop =
  Stats.doPhase (Stats.makePhase "Compiler 051 FLINTCheck") checkTop

(****************************************************************************
 *  MAIN FUNCTION --- val checkExp : FLINT.lexp * typsys -> bool            *
 *  (currently unused?)                                                     *
 ****************************************************************************)
fun checkExp (le,phase) = check phase (LT.initTkEnv, LT.initLtyEnv, DI.top) le

end (* toplevel local *)
end (* structure ChkFlint *)
