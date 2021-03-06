(* Copyright 1996 by Bell Laboratories *)
(* convert.sml *)

(***************************************************************************
 *                         IMPORTANT NOTES                                 *
 *                                                                         *
 *          OFFSET and RECORD accesspath SELp should not be                *
 *                  generated by this module.                              *
 ***************************************************************************)

signature CONVERT = sig 
  val convert : FLINT.prog -> CPS.function * LtyDef.lty Intmap.intmap 
end (* signature CONVERT *)

functor Convert(MachSpec : MACH_SPEC) : CONVERT = struct

local structure DA = Access
      structure LT = LtyExtern
      structure LV = LambdaVar
      structure AP = PrimOp
      structure F  = FLINT
      open CPS 
in

fun bug s = ErrorMsg.impossible ("Convert: " ^ s)
val say = Control.Print.say
val mkv = fn _ => LV.mkLvar()
val ident = fn le => le

val ltc_cont = LT.ltc_cont
val lt_vcont = ltc_cont [LT.ltc_void]
val lt_scont = LT.ltc_arw (LT.ltc_void, LT.ltc_void)

fun processArgs vts = 
  let val (vs, lts) = ListPair.unzip vts
   in (vs, map ctype lts)
  end

(***************************************************************************
 *              CONSTANTS AND UTILITY FUNCTIONS                            *
 ***************************************************************************)
val OFFp0 = OFFp 0

fun numkind (AP.INT bits) = P.INT bits
  | numkind (AP.UINT bits) = P.UINT bits
  | numkind (AP.FLOAT bits) = P.FLOAT bits

fun cmpop(stuff,argt) = 
  (case stuff
    of {oper=AP.EQL,kind=AP.INT 31} => 
	 if LT.lt_eqv(argt,LT.ltc_tuple[LT.ltc_void,LT.ltc_void])
	 then (say "int-equality used for ptr-equality\n"; P.peql)
         else P.ieql
     | {oper=AP.NEQ,kind=AP.INT 31} => 
         if LT.lt_eqv(argt,LT.ltc_tuple[LT.ltc_void,LT.ltc_void])
	 then (say "int-equality used for ptr-equality\n"; P.pneq)
         else P.ineq
     | {oper,kind=AP.FLOAT size} => 
         let fun c AP.>    = P.fGT
	       | c AP.>=   = P.fGE
	       | c AP.<    = P.fLT
	       | c AP.<=   = P.fLE
 	       | c AP.EQL  = P.fEQ
 	       | c AP.NEQ  = P.fLG
 	       | c _ = bug "cmpop:kind=AP.FLOAT"
          in P.fcmp{oper= c oper, size=size}
         end
     | {oper, kind} => 
         let fun check (_, AP.UINT _) = ()
 	       | check (oper, _) = bug ("check" ^ oper)
 	     fun c AP.>   = P.>  
 	       | c AP.>=  = P.>= 
 	       | c AP.<   = P.< 
 	       | c AP.<=  = P.<=
 	       | c AP.LEU = (check ("leu", kind); P.<= )
 	       | c AP.LTU = (check ("ltu", kind); P.< )
 	       | c AP.GEU = (check ("geu", kind); P.>= )
 	       | c AP.GTU = (check ("gtu", kind); P.> )
 	       | c AP.EQL = P.eql
 	       | c AP.NEQ = P.neq
  	  in P.cmp{oper=c oper, kind=numkind kind} 
         end)

fun arity AP.~ = 1
  | arity AP.ABS = 1
  | arity AP.NOTB = 1
  | arity AP.+ = 2
  | arity AP.- = 2
  | arity AP.* = 2
  | arity AP./ = 2
  | arity AP.LSHIFT = 2
  | arity AP.RSHIFT = 2
  | arity AP.RSHIFTL = 2
  | arity AP.ANDB = 2
  | arity AP.ORB = 2
  | arity AP.XORB = 2
    
fun arithop AP.~ = P.~
  | arithop AP.ABS = P.abs
  | arithop AP.NOTB = P.notb
  | arithop AP.+ = P.+
  | arithop AP.- = P.-
  | arithop AP.* = P.*
  | arithop AP./ = P./
  | arithop AP.LSHIFT = P.lshift
  | arithop AP.RSHIFT = P.rshift
  | arithop AP.RSHIFTL = P.rshiftl
  | arithop AP.ANDB = P.andb
  | arithop AP.ORB = P.orb
  | arithop AP.XORB = P.xorb

(***************************************************************************
 *                        THE MAIN FUNCTION                                *
 *                   convert : F.prog -> CPS.cexp                      *   
 ***************************************************************************)
fun convert fdec = 
let 
 
local open Intmap
      exception Rename
      val m : value intmap = new(32, Rename)
      val rename = map m

   in fun ren v = rename v handle Rename => VAR v
      fun newname (v, w) = 
        (case w of VAR w' => LV.sameName (v, w')
                 | _ => ();
         add m (v, w))
  end

local open Intmap
in 

fun mkfn f = let val v = mkv() in f v end
val bogus_cont = mkv(lt_vcont)

val unboxedfloat = MachSpec.unboxedFloats
val untaggedint = MachSpec.untaggedInt
val flatfblock = (!Control.CG.flatfblock) andalso unboxedfloat

fun unwrapfloat(u,x,ce) = PURE(P.funwrap,[u],x,FLTt,ce)
fun wrapfloat(u,x,ce) = PURE(P.fwrap,[u],x,BOGt,ce)
fun unwrapint(u,x,ce) = PURE(P.iunwrap,[u],x,INTt,ce)
fun wrapint(u,x,ce) = PURE(P.iwrap,[u],x,BOGt,ce)
fun unwrapi32(u,x,ce) = PURE(P.i32unwrap,[u],x,INT32t,ce)
fun wrapi32(u,x,ce) = PURE(P.i32wrap,[u],x,BOGt,ce)

fun primwrap(INTt) = P.iwrap
  | primwrap(INT32t) = P.i32wrap
  | primwrap(FLTt) = P.fwrap
  | primwrap _ = P.wrap

fun primunwrap(INTt) = P.iunwrap
  | primunwrap(INT32t) = P.i32unwrap
  | primunwrap(FLTt) = P.funwrap
  | primunwrap _ = P.unwrap

(* check if a record contains only reals *)
fun isFloatRec lt = 
  if (LT.ltp_tyc lt) then
    (let val tc = LT.ltd_tyc lt
      in if (LT.tcp_tuple tc) then
           (let val l = LT.tcd_tuple tc
                fun h [] = flatfblock
                  | h (x::r) = 
                      if LT.tc_eqv(x, LT.tcc_real) then h r else false
             in case l of [] => false | _ => h l
            end)
         else false
     end)
  else false

fun selectFL(i,u,x,ct,ce) = SELECT(i,u,x,ct,ce)
fun selectNM(i,u,x,ct,ce) =
  (case (ct,unboxedfloat,untaggedint)
    of (FLTt,true,_) => let val v = mkv()
                         in SELECT(i,u,v,BOGt,unwrapfloat(VAR v,x,ce))
                        end
     | (INTt,_,true) => let val v = mkv()
                         in SELECT(i,u,v,BOGt,unwrapint(VAR v,x,ce))
                        end
     | (INT32t,_,_) => let val v = mkv()
                        in SELECT(i,u,v,BOGt,unwrapi32(VAR v,x,ce))
                       end
     | _ => SELECT(i,u,x,ct,ce))

fun recordFL(ul,_,w,ce) = 
  let val nul = map (fn u => (u,OFFp 0)) ul
   in RECORD(RK_FBLOCK,nul,w,ce)
  end

fun recordNM(ul,tyl,w,ce) =
  let fun g(FLTt::r,u::z,l,h) = 
             if unboxedfloat then 
               (let val v = mkv()
                 in g(r, z, (VAR v,OFFp 0)::l, fn ce => h(wrapfloat(u,v,ce)))
                end)
             else g(r, z, (u,OFFp 0)::l, h)
        | g(INTt::r,u::z,l,h) = 
             if untaggedint then 
               (let val v = mkv()
                 in g(r, z, (VAR v,OFFp 0)::l, fn ce => h(wrapint(u,v,ce)))
                end)
             else g(r, z, (u,OFFp 0)::l, h)
        | g(INT32t::r,u::z,l,h) = 
             let val v = mkv()
              in g(r, z, (VAR v,OFFp 0)::l, fn ce => h(wrapi32(u,v,ce)))
             end
        | g(_::r,u::z,l,h) = g(r, z, (u,OFFp0)::l, h)
        | g([],[],l,h) = (rev l, h)
        | g _ = bug "unexpected in recordNM in convert"

      val (nul,header) = 
        if rep_flag then g(map ctype tyl,ul,[],fn x => x)
        else (map (fn u => (u,OFFp 0)) ul, fn x => x)
   in header(RECORD(RK_RECORD,nul,w,ce))
  end

fun convpath(DA.LVAR v, k) = k(ren v)
  | convpath _ = bug "unexpected path in convpath"

(***************************************************************************
 *           preventEta : cexp * lty -> cexp * value                       *
 ***************************************************************************)
fun preventEta(c, rts) = 
  let val vl = map mkv rts
      val cl = map ctype rts
      val f = mkv() 
      val ul = map VAR vl
   in case c ul
       of APP(w as VAR w', vl') => 
            if ul=vl' andalso v<>w'
		(* The case v=w' never turns up in practice,
		   but v<>v' does turn up. *)
	    then (ident,w)
	    else (fn x => FIX([(CONT,f,vl,cl,b)],x),VAR f)
	| _ => (fn x => FIX([(CONT,f,vl,cl,b)],x),VAR f)
  end

(***************************************************************************
 *                  SWITCH OPTIMIZATIONS AND COMPILATIONS                  *
 ***************************************************************************)
(* 
 * BUG: The defintion of E_word is clearly incorrect since it can raise
 *	an overflow at code generation time. A clean solution would be 
 *	to add a WORD constructor into the CPS language -- daunting! The
 *	revolting hack solution would be to put the right int constant 
 *	that gets converted to the right set of bits for the word constant.
 *)
val do_switch = Switch.switch {
   E_int = fn i => if i < ~0x20000000 orelse i >= 0x20000000
                 then raise Switch.TooBig else INT i, 
   E_word = fn w => if w >= 0wx20000000 
                 then raise Switch.TooBig else INT (Word.toIntX w),
   E_real = fn s => REAL s,
   E_switchlimit = 4,
   E_neq = P.ineq,
   E_w32neq = P.cmp{oper=P.neq,kind=P.UINT 32},
   E_i32neq = P.cmp{oper=P.neq,kind=P.INT 32},
   E_word32 = INT32,
   E_int32 = INT32, 
   E_wneq = P.cmp{oper=P.neq, kind=P.UINT 31},
   E_pneq = P.pneq,
   E_fneq = P.fneq,
   E_less = P.ilt,
   E_branch= fn(cmp,x,y,a,b) => BRANCH(cmp,[x,y],mkv(LT.ltc_int),a,b),
   E_strneq= fn(w,str,a,b) => BRANCH(P.strneq, [INT(size str),w,STRING str],
				     mkv(LT.ltc_int), a, b),
   E_switch= fn(v,list) => SWITCH(v, mkv(LT.ltc_int), list),
   E_add= fn(x,y,c) => let val v = mkv(LT.ltc_int) in ARITH(P.iadd,[x,y],v,INTt,c(VAR v))
		     end,
   E_gettag= fn(x,c) => let val v = mkv(LT.ltc_int)
                     in PURE(P.getcon,[x],v,INTt,c(VAR v))
		    end,
   E_unwrap= fn(x,c) => let val v = mkv(LT.ltc_int)
                     in PURE(P.unwrap,[x],v,INTt,c(VAR v))
		    end,
   E_getexn= fn(x,c) => let val v = mkv(LT.ltc_void)
                     in PURE(P.getexn,[x],v,BOGt,c(VAR v))
		    end,
   E_length= fn(x,c) => let val v = mkv(LT.ltc_int)
                     in PURE(P.length,[x],v,INTt,c(VAR v))
		    end,
   E_boxed= fn(x,a,b) => BRANCH(P.boxed,[x],mkv(LT.ltc_int),a,b),
   E_path= convpath}

(***************************************************************************
 *   getargs : int * F.lexp * (value list -> cexp) -> cexp            *
 ***************************************************************************)
fun getargs(1,a,g) = convle(a, fn z => g[z])
  | getargs(n,F.RECORD l,g) = g (map convsv l)
  | getargs(n,F.VECTOR(l, _), g) = g(map convsv l)
  | getargs(0,a,g) = g(nil)
  | getargs(n,a,g) =
     let fun kont(v) = 
           let val lt = grabty(v)
               val selectCE = if (isFloatRec lt) then selectFL else selectNM
               fun f(j,wl) = 
                 if j = n then g(rev wl)
                 else (let val tt = selectLty(lt,j)
                           fun h(w) = 
                             selectCE(j,v,w,ctype(tt),f(j+1,VAR w :: wl))
                        in mkfn(h,tt)
                       end)
            in f(0,nil)
           end
      in convle(a,kont)
     end

(***************************************************************************
 *   convsv : F.value -> value                                        *
 *   convle : F.lexp * (value list -> cexp) -> cexp                   *
 ***************************************************************************)
and convsv sv = 
 (case sv
   of F.VAR v => ren v
    | F.INT i => INT i
    | F.INT32 i32 => 
        let val int32ToWord32 = Word32.fromLargeInt o Int32.toLarge
         in INT32 (int32ToWord32 i32)
        end
    | F.WORD w => INT(Word.toIntX w)
    | F.WORD32 w => INT32 w
    | F.REAL i => REAL i
    | F.STRING s =>  STRING s)

and convfd (fk, f, vts, e) = 
  let val k = mkv()
      val vl = k::(map #1 vts)
      val cl = CNTt::(map ctype o #2 vts)
      fun kont (vs) = APP(VAR k, vs)
   in (ESCAPE, f, vl, cl, convle(e, kont))
  end

and convle (le, c : value list -> cexp) = 
 case le 
  of F.RET vs => c(map convsv vs)
   | F.LET(vs, e1, e2) =>
       let fun kont(ws) = 
             let val _ = ListPair.map newname (vs,ws)
              in convle(e2, c)
             end
        in convle(e1,kont)
       end

   | F.FIX(fds, e) => F.FIX(map convfd fds, convle(e, c))
   | F.APP(f, vs) => 
       let val (hdr,F) = preventEta(c)
           val vf = convsv f
           val ul = map convsv vs
        in hdr(APP(vf,F::ul))
       end

   | F.RECORD [] => c(INT 0) 
   | F.SRECORD [] => c(INT 0) 
   | F.VECTOR ([], _) => bug "zero length vectors in convert"
   | F.RECORD l => 
       let val vl = map convsv l
           val tyl = map grabty vl
           val lt = LT.ltc_tuple tyl
           val recordCE = 
             if (isFloatRec lt) then recordFL else recordNM
           val w = mkv(lt)
        in recordCE(vl,tyl,w,c(VAR w))
       end                
   | F.SRECORD l => 
       let val vl = map convsv l
           val ts = map grabty vl
           val w = mkv(LT.ltc_str ts)
        in recordNM(vl,ts,w,c(VAR w))
       end                
   | F.VECTOR (l, _) => 
       let val vl = map convsv l
           val w = mkv(LT.ltc_void)
        in RECORD(RK_VECTOR, map (fn v => (v, OFFp0)) vl, w, c(VAR w))
       end
   | F.SELECT(i, v) => 
       let val v = convsv v
           val lt = grabty(v)
           val t = selectLty(lt,i)
           val w = mkv(t)
           val selectCE = if (isFloatRec lt) then selectFL else selectNM
        in selectCE(i, v, w, ctype t, c(VAR w))
       end
   | F.SWITCH(e,l,[a as (F.DATAcon(_,DA.CONSTANT 0,_),_),
		        b as (F.DATAcon(_,DA.CONSTANT 1,_),_)], 
                   NONE) =>
       convle(F.SWITCH(e,l,[b,a],NONE),c)
   | F.SWITCH x => genswitch(x,c)
   | F.RAISE(v,t) =>
       let val w = convsv v
           val h = mkv(lt_scont)
           val _ = mkfn(fn u => c(VAR u), t)
        in LOOKER(P.gethdlr,[],h,FUNt,APP(VAR h,[VAR bogus_cont,w]))
       end
   | F.HANDLE(a,b) =>
       let val vb = convsv b
           val (_,t) = arrowLty(grabty(vb))
           val h = mkv(lt_scont) 
           val v = mkv(LT.ltc_void)
           val k = mkv(lt_scont)
           val (header,F) = preventEta(c,t)
           fun kont1(va) = 
                  let val (ul,header1) = mkArgOut(t,va)
                    in SETTER(P.sethdlr,[VAR h],
                              header1(APP(F,ul)))
                   end
        in LOOKER(P.gethdlr,[],h,FUNt,
                header(FIX([(ESCAPE,k,[mkv(lt_vcont),v],
                             [CNTt,BOGt],
                               SETTER(P.sethdlr,[VAR h],APP(vb,[F,VAR v])))],
                              SETTER(P.sethdlr,[VAR k],convle(a,kont1)))))

       end
   | F.PRIMOP((_, AP.CALLCC, _, _), vs, v, e) =>
       let val vf = convsv f
           val (t1,t2) = arrowLty(grabty(vf))
           val h = mkv(lt_scont)
           (* t1 must be SRCONTty here *)
           val k' = mkv(t1) and x' = mkv(t2) 
           val (header,F) = preventEta(c,t2)
           val (vl,cl,_) = mkArgIn(t2,x')
           val z = mkv(lt_vcont) (* bogus cont *)
        in header(LOOKER(P.gethdlr, [], h, FUNt,
                  FIX([(ESCAPE, k', z::vl, CNTt::cl, 
                          SETTER(P.sethdlr, [VAR h],
                                      APP(F, map VAR vl)))],
                         APP(vf,[F, VAR k']))))
       end
   | F.APP(F.PRIM(AP.CAPTURE,_,_), f) =>
       let val vf = convsv f
           val (t1,t2) = arrowLty(grabty(vf))
           val k' = mkv(t1) and x' = mkv(t2)
           val (header,F) = preventEta(c,t2)
           val (vl,cl,_) = mkArgIn(t2,x')     
           val z = mkv(lt_vcont) (* bogus cont *)
                 (* this k' is one kind of eta redexes that optimizer
                  * should not reduce! The type of k' and F is different.
                  *)
        in header(FIX([(ESCAPE, k', z::vl, CNTt::cl, 
                              APP(F, map VAR vl))],
                            APP(vf,[F, VAR k'])))
       end

   | F.APP(F.PRIM(AP.ISOLATE,_,_), f) =>
       let val vf = convsv f
           val k = mkv(lt_scont)
           val z = mkv(lt_vcont)
           val x = mkv(LT.ltc_void)
           val h = mkv(lt_scont)
           val z' = mkv(lt_vcont)
           val x' = mkv(LT.ltc_void)
        in FIX([(ESCAPE, h, [z', x'], [CNTt, BOGt],
                  APP(VAR bogus_cont, [VAR x']))],
               FIX([(ESCAPE, k, [z, x], [CNTt, BOGt],
                   SETTER(P.sethdlr, [VAR h],
                          APP(vf, [VAR bogus_cont, VAR x])))],
                   c(VAR k)))
       end

(* We can't do this because the of representation type problems:
   | F.APP(F.PRIM(AP.THROW,_,_), v) => convle(v,c)
*)
   | F.APP(F.PRIM(AP.THROW,_,_), v) => 
        let val kv = convsv v
            val t = LT.ltc_arw(LT.ltc_void,LT.ltc_void)
            val f = mkv(t)
         in PURE(P.cast,[kv],f,ctype(t),c(VAR f))
        end
   | F.APP(F.PRIM(AP.CAST,lt,_), x) => 
        let val vx = convsv x
            val (_,t) = arrowLty(lt)
         in mkfn(fn u => PURE(P.cast,[vx],u,ctype(t),c(VAR u)), t)
        end
   | F.PRIMOP((_,i,lt,_), vs, v, e) => 
       let val (argt,t) = arrowLty(lt)
           val ct = ctype t

           fun arith(n,i) = 
             let fun kont(vl) = mkfn(fn w => ARITH(i,vl,w,ct,c(VAR w)),t)
              in kont vs
             end

           fun setter(n,i) = 
             let fun kont(vl) = SETTER(i,vl,c(INT 0))
              in kont vs
             end

           fun looker(n,i) =
             let fun kont(vl) = mkfn(fn w => LOOKER(i,vl,w,ct,c(VAR w)),t)
              in kont vs
             end

           fun pure(n,i) =
             let fun kont(vl) = mkfn(fn w => PURE(i,vl,w,ct,c(VAR w)),t)
              in kont vs
             end

  	   fun branch(n,i)= 
             let val (header,F) = preventEta(c,t) 
                 fun kont(vl) = header(BRANCH(i,vl,mkv(LT.ltc_int),
                                              APP(F,[INT 1]),APP(F,[INT 0])))
              in kont vs
             end

        in case i
	    of AP.BOXED => branch(1,P.boxed)
	     | AP.UNBOXED => branch(1,P.unboxed)
	     | AP.CMP stuff => branch(2,cmpop(stuff,argt))
	     | AP.PTREQL => branch(2,P.peql)
	     | AP.PTRNEQ => branch(2,P.pneq)

	     | AP.TEST(from,to) => arith(1, P.test(from, to))
	     | AP.TESTU(from,to) => arith(1, P.testu(from, to))
	     | AP.COPY(from,to) => pure(1, P.copy(from,to))
	     | AP.EXTEND(from,to) => pure(1, P.extend(from, to))
	     | AP.TRUNC(from,to) => pure(1, P.trunc(from, to))
	     | AP.ARITH{oper,kind,overflow=true} =>
		arith(arity oper,
		      P.arith{oper=arithop oper,kind=numkind kind})
	     | AP.ARITH{oper,kind,overflow=false} =>
		pure(arity oper,
		     P.pure_arith{oper=arithop oper,kind=numkind kind})

	     | AP.ROUND{floor,fromkind,tokind} =>
		arith(1,P.round{floor=floor,
				fromkind=numkind fromkind,
				tokind=numkind tokind})

             | AP.REAL{fromkind,tokind} =>
		pure(1,P.real{tokind=numkind tokind,
			      fromkind=numkind fromkind})

	     | AP.SUBSCRIPTV => pure(2,P.subscriptv)
	     | AP.MAKEREF => pure(1,P.makeref)
	     | AP.LENGTH => pure(1,P.length)
	     | AP.OBJLENGTH => pure(1,P.objlength)
	     | AP.GETTAG => pure(1, P.gettag)
	     | AP.MKSPECIAL => pure(2, P.mkspecial)
		
	     | AP.SUBSCRIPT => looker(2,P.subscript)
	     | AP.NUMSUBSCRIPT{kind,immutable=false,checked=false} => 
		   looker(2,P.numsubscript{kind=numkind kind})
	     | AP.NUMSUBSCRIPT{kind,immutable=true,checked=false} => 
		   pure(2,P.pure_numsubscript{kind=numkind kind})
	     | AP.DEREF => looker(1,P.!)
	     | AP.GETRUNVEC => looker(0, P.getrunvec)
	     | AP.GETHDLR => looker(0,P.gethdlr)
	     | AP.GETVAR  => looker(0,P.getvar)
             | AP.GETPSEUDO => looker(1,P.getpseudo)
	     | AP.GETSPECIAL => looker(1, P.getspecial)
	     | AP.DEFLVAR  => looker(0,P.deflvar)
		
	     | AP.SETHDLR => setter(1,P.sethdlr)
	     | AP.NUMUPDATE{kind,checked=false} =>
		   setter(3,P.numupdate{kind=numkind kind})
	     | AP.UNBOXEDUPDATE => setter(3,P.unboxedupdate)
	     | AP.BOXEDUPDATE => setter(3,P.boxedupdate)
	     | AP.UPDATE => setter(3,P.update)
	     | AP.SETVAR => setter(1,P.setvar)
             | AP.SETPSEUDO => setter(2,P.setpseudo)
             | AP.SETMARK => setter(1,P.setmark)
             | AP.DISPOSE => setter(1,P.free)
	     | AP.SETSPECIAL => setter(2, P.setspecial)
	     | AP.USELVAR => setter(1,P.uselvar)
	     | AP.MARKEXN => getargs(2, F.SVAL a,fn[x,m']=>
	  	  let val bty = LT.ltc_void
                      val ety = LT.ltc_tuple[bty,bty,bty]

                      val xx = mkv ety
		      val x0 = mkv bty
		      val x1 = mkv bty
		      val x2 = mkv bty

                      val y = mkv ety
                      val y' = mkv bty

		      val z = mkv(LT.ltc_tuple[bty,bty])
                      val z' = mkv bty

                   in PURE(P.unwrap,[x],xx,ctype(ety),
                        SELECT(0,VAR xx,x0,BOGt,
   		        SELECT(1,VAR xx,x1,BOGt,
		        SELECT(2,VAR xx,x2,BOGt,
		          RECORD(RK_RECORD,[(m',OFFp0),(VAR x2,OFFp0)],z,
                          PURE(P.wrap,[VAR z],z',BOGt,
  		          RECORD(RK_RECORD,[(VAR x0,OFFp0),
				            (VAR x1,OFFp0),
					    (VAR z', OFFp0)], y,
                          PURE(P.wrap,[VAR y], y', BOGt,c(VAR y')))))))))
                  end)

	     | _ => bug ("calling with bad primop \"" 
                                         ^ (AP.prPrimop i) ^ "\"")
       end
   | F.ETAG(v,_) =>
       let val u = convsv v
           val x = mkv(LT.ltc_void) 
        in PURE(P.makeref,[u],x,BOGt,c(VAR x))
       end
   | F.WRAP(t,_,sv) => 
       let val w = convsv sv
           val t = grabty(w)
           val ct = ctype t
           val x = mkv(LT.ltc_void)
        in PURE(primwrap ct,[w],x,BOGt,c(VAR x))
       end
   | F.UNWRAP(t,_,sv) => 
       let val t = LT.ltc_tyc t
           val ct = ctype t
           val w = convsv sv
           val x = mkv(t)
        in PURE(primunwrap ct,[w],x,ct,c(VAR x))
       end
   | _ => bug "convert.sml 7432894"


(***************************************************************************
 * genswitch : (F.lexp * Access.conrep list * (F.con *           *
 *                 F.lexp) list * F.lexp option) *               *
 *              (value -> cexp) -> cexp                                    *
 ***************************************************************************)
and genswitch ((sv, sign, l: (F.con * F.lexp) list, d), c) =
  let val df = mkv(ltc_cont [LT.ltc_int]) 
      val k = mkv()
      fun kont1(ul) = APP(VAR k, ul)
      val l' = map (fn(c,e)=>(c,convle(e,kont1))) l

      val body=
        do_switch{sign=sign, exp=convsv sv, cases=l',
                  default=APP(VAR df,[INT 0])}

      val body' = case d 
         of NONE => body
	  | SOME d' => FIX([(CONT,df,[mkv(LT.ltc_int)],[INTt],
                             convle(d',kont1))], body)

      val t = !save
      val v = mkv(t) 
      val _ = (addty(k, ltc_cont [t]))
      val (vl,cl,header) = mkArgIn(t,v)
   in FIX([(CONT,k,vl,cl,header(c(VAR v)))],body')
  end

(***************************************************************************
 *                TOP LEVEL HEADER                                         *
 ***************************************************************************)
val (fk, f, vts, lexp) = fdec
val k = mkv() 

val (vl, cl) = processArgs vts
val body = convle(lexp, fn vs => APP(VAR k, vs))

val bogus_knownf = mkv(lt_vcont)
val bogushead = 
     fn ce => FIX([(KNOWN,bogus_knownf,[mkv(LT.ltc_void)],[BOGt],
                    APP(VAR bogus_knownf,[STRING "bogus"]))],
                  FIX([(CONT,bogus_cont,[mkv(LT.ltc_void)],[BOGt],
                        APP(VAR bogus_knownf,[STRING "bogus"]))],ce))

in (ESCAPE, f, k::vl, CNTt::cl, bogushead(body))
end

end (* toplevel local *)
end (* functor Convert *)


