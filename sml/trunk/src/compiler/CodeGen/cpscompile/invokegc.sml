(*
 * This module is responsible for generating code to invoke the 
 * garbage collector.  This new version is derived from the functor CallGC.
 * It can handle derived pointers as roots and it can also be used as 
 * callbacks.  These extra facilities are neccessary for global optimizations  
 * in the presence of GC.  
 * 
 * -- Allen
 * 
 *)

functor InvokeGC
   (structure Cells : CELLS
    structure C : CPSREGS where T.Region=CPSRegions
    structure MS: MACH_SPEC
   ) : INVOKE_GC =
struct

   structure T  = C.T
   structure D  = MS.ObjDesc
   structure LE = T.LabelExp
   structure R  = CPSRegions
   structure S  = SortedList
   structure St = T.Stream
   structure GC = SMLGCType
   structure Cells = Cells
   structure A  = Array

   fun error msg = ErrorMsg.impossible("InvokeGC."^msg)

   type t = { maxAlloc : int,
              regfmls  : T.mlrisc list,
              regtys   : CPS.cty list,
              return   : T.stm
            }

   type stream = (T.stm,Cells.regmap,T.mlrisc list) T.stream

   val debug = Control.MLRISC.getFlag "debug-gc";

   val addrTy = C.addressWidth

   (* The following datatype is used to encapsulates 
    * all the information needed to generate code to invoke gc.
    * The important fields are:
    *    known     -- is the function a known (i.e. internal) function 
    *    optimized -- if this is on, gc code generation is delayed until
    *                 we have performed all optimizations.  This is false
    *                 for normal SML/NJ use.
    *    lab       -- a list of labels that belongs to the call gc block
    *    boxed, float, int32 -- roots partitioned by types
    *    regfmls   -- the roots
    *    ret       -- how to return from the call gc block.
    *)
   datatype gcInfo =
      GCINFO of
        {known     : bool,            (* known function ? *)
         optimized : bool,            (* optimized? *)
         lab       : Label.label ref, (* labels to invoke GC *)
         boxed     : T.rexp list,     (* locations with boxed objects *)
         int32     : T.rexp list,     (* locations with int32 objects *)
         float     : T.fexp list,     (* locations with float objects *)
         regfmls   : T.mlrisc list,   (* all live registers *)
         ret       : T.stm}           (* how to return *)
    | MODULE of
        {info: gcInfo,
         addrs: Label.label list ref} (* addrs associated with long jump *)

   (*====================================================================
    * Implementation/architecture specific stuff starts here.
    *====================================================================*)

      (* Extra space in allocation space 
       * The SML/NJ runtime system leaves around 4K of extra space
       * in the allocation space for safety.
       *)
   val skidPad = 4096
   val pty  = 32

   val sp   = Cells.stackptrR  (* stack pointer *)
   val spR  = T.REG(addrTy,sp)
   val unit = T.LI 1           (* representation of ML's unit; 
                                * this is used to initialize registers.
                                *)
       (*
        * Callee-save registers 
        * All callee save registers are used in the gc calling convention.
        *)
   val calleesaves = List.take(C.miscregs, MS.numCalleeSaves)

       (* 
        * registers that are the roots of gc.
        *)
   val gcParamRegs  = (C.stdlink::C.stdclos::C.stdcont::C.stdarg::calleesaves)

       (*
        * How to call the call the GC 
        *)
   local val use = map T.GPR gcParamRegs 
         val def = case C.exhausted of NONE => use 
                                     | SOME cc => T.CCR cc::use
   in  val gcCall =
          T.ANNOTATION(
          T.CALL{
            funct=T.LOAD(32, T.ADD(addrTy,C.stackptr,T.LI MS.startgcOffset), 
                        R.stack),
            targets=[], defs=def, uses=use, cdefs=[], cuses=[], region=R.stack},
          #create MLRiscAnnotations.COMMENT "call gc")

       val ZERO_FREQ = #create MLRiscAnnotations.EXECUTION_FREQ 0
   end

   val CALLGC = #create MLRiscAnnotations.CALLGC ()
   val NO_OPTIMIZATION = #create MLRiscAnnotations.NO_OPTIMIZATION ()

       (*
        * record descriptors
        *)
   val dtoi = LargeWord.toInt
   fun unboxedDesc words = dtoi(D.makeDesc(words, D.tag_raw64))
   fun boxedDesc words   = dtoi(D.makeDesc(words, D.tag_record))

       (* the allocation pointer must always in a register! *)
   val allocptrR = 
       case C.allocptr of
         T.REG(_,allocptrR) => allocptrR 
       | _ => error "allocptr must be a register"

       (* what type of comparison to use for GC test? *)
   val gcCmp = if C.signedGCTest then T.GT else T.GTU

   val unlikely = #create MLRiscAnnotations.BRANCH_PROB 0

   val normalTestLimit = T.CMP(pty, gcCmp, C.allocptr, C.limitptr)

   (*====================================================================
    * Private state
    *====================================================================*)
   (* gc info required for standard functions within the cluster *)
   val clusterGcBlocks = ref([]: gcInfo list)

   (* gc info required for known functions within the cluster *)
   val knownGcBlocks = ref([]: gcInfo list)

   (* gc info required for modules *)
   val moduleGcBlocks = ref ([]: gcInfo list)

   (*====================================================================
    * Auxiliary functions
    *====================================================================*)

   (*
    * Convert a list of rexps into a set of registers and memory offsets.
    * Memory offsets must be relative to the stack pointer.
    *)
   fun set bindings = 
   let fun isStackPtr sp = sp = Cells.stackptrR
       fun live(T.REG(_,r)::es, regs, mem) = live(es, r::regs, mem)
         | live(T.LOAD(_, T.REG(_, sp), _)::es, regs, mem) =
           if isStackPtr sp then live(es, regs, 0::mem)
           else error "set:LOAD32"
         | live(T.LOAD(_, T.ADD(_, T.REG(_, sp), T.LI i), _)::es, regs, mem) =
           if isStackPtr sp then live(es, regs, i::mem)
           else error "set:LOAD32"
         | live([], regs, mem) = (regs, mem)
         | live _ = error "live"
       val (regs, mem) = live(bindings, [], [])
   in  {regs=S.uniq regs, mem=S.uniq mem} end

   fun difference({regs=r1,mem=m1}, {regs=r2,mem=m2}) =
       {regs=S.difference(r1,r2), mem=S.difference(m1,m2)}
 
   fun setToString{regs,mem} =
       "{"^foldr (fn (r,s) => Cells.toString Cells.GP r^" "^s) "" regs
          ^foldr (fn (m,s) => Int.toString m^" "^s) "" mem^"}"

   fun setToMLTree{regs,mem} =
       map (fn r => T.REG(32,r)) regs @ 
       map (fn i => T.LOAD(32, T.ADD(addrTy, spR, T.LI i), R.memory)) mem
            
   (* The client communicates root pointers to the gc via the following set
    * of registers and memory locations.
    *)
   val gcrootSet = set gcParamRegs 
   val aRoot     = hd(#regs gcrootSet)
   val aRootReg  = T.REG(32,aRoot)

   (* 
    * This function generates a gc limit check.
    * It returns the label to the GC invocation block.
    *) 
   fun checkLimit(emit, maxAlloc) =
   let val lab = Label.newLabel ""
       fun gotoGC(cc) = emit(T.ANNOTATION(T.BCC([], cc, lab), unlikely))
   in  if maxAlloc < skidPad then
          (case C.exhausted of
             SOME cc => gotoGC cc
           | NONE => gotoGC(normalTestLimit)
          )
       else  
       let val shiftedAllocPtr = T.ADD(addrTy,C.allocptr,T.LI(maxAlloc-skidPad))
           val shiftedTestLimit = T.CMP(pty, gcCmp, shiftedAllocPtr, C.limitptr)
       in  case C.exhausted of
             SOME(cc as T.CC(_,r)) => 
               (emit(T.CCMV(r, shiftedTestLimit)); gotoGC(cc))
           | NONE => gotoGC(shiftedTestLimit)
           | _ => error "checkLimit"
       end;
       lab
   end

   (* 
    * This function recomputes the base pointer address.
    *)
   fun computeBasePtr(emit,defineLabel,annotation) =
   let val returnLab = Label.newLabel ""
       val baseExp = 
           T.ADD(addrTy, C.gcLink,
                 T.LABEL(LE.MINUS(LE.INT MS.constBaseRegOffset,
                                  LE.LABEL returnLab)))
   in  defineLabel returnLab;
       annotation(ZERO_FREQ); 
       emit(case C.baseptr of 
              T.REG(ty, bpt) => T.MV(ty, bpt, baseExp)
            | T.LOAD(ty, ea, mem) => T.STORE(ty, ea, baseExp, mem)
            | _ => error "computeBasePtr")
   end 

   (*====================================================================
    * Main functions
    *====================================================================*)
   fun init() =
       (clusterGcBlocks        := [];
        knownGcBlocks          := [];
        moduleGcBlocks         := []
       )

   (*
    * Partition the root set into types 
    *)
   fun split([], [], boxed, int32, float) = 
         {boxed=boxed, int32=int32, float=float}
     | split(T.GPR r::rl, CPS.INT32t::tl, b, i, f) = split(rl,tl,b,r::i,f)
     | split(T.GPR r::rl, CPS.FLTt::tl, b, i, f) = error "split: T.GPR"
     | split(T.GPR r::rl, _::tl, b, i, f) = split(rl,tl,r::b,i,f)
     | split(T.FPR r::rl, CPS.FLTt::tl, b, i, f) = split(rl,tl,b,i,r::f)
     | split _ = error "split"

   fun genGcInfo (clusterRef,known,optimized) (St.STREAM{emit,...} : stream) 
                 {maxAlloc, regfmls, regtys, return} =
   let (* partition the root set into the appropriate classes *)
       val {boxed, int32, float} = split(regfmls, regtys, [], [], [])

   in  clusterRef := 
          GCINFO{ known    = known,
                  optimized=optimized,
                  lab      = ref (checkLimit(emit,maxAlloc)),
                  boxed    = boxed,
                  int32    = int32,
                  float    = float,
                  regfmls  = regfmls,
                  ret      = return } :: (!clusterRef)
   end

   (* 
    * Check-limit for standard functions, i.e.~functions with 
    * external entries.
    *)
   val stdCheckLimit = genGcInfo (clusterGcBlocks, false, false)

   (*
    * Check-limit for known functions, i.e.~functions with entries from
    * within the same cluster.
    *)
   val knwCheckLimit = genGcInfo (knownGcBlocks, true, false)

   (*
    * Check-limit for optimized, known functions.  
    *)
   val optimizedKnwCheckLimit = genGcInfo(knownGcBlocks, true, true)

   (*
    * An array for checking cycles  
    *)
   local
      val N = (foldr Int.max 0 (#regs gcrootSet))+1
   in
      val clientRoots = A.array(N, ~1)
      val stamp       = ref 0
   end

   (*
    * This function packs boxed, int32 and float into gcroots.
    * gcroots must be non-empty.  Return a function to unpack.
    *)
   fun pack(emit, gcroots, boxed, int32, float) =
   let (* 
        * Datatype binding describes the contents a gc root.
        *)
       datatype binding =
         Reg     of Cells.cell               (* integer register *)
       | Freg    of Cells.cell               (* floating point register*)
       | Mem     of T.rexp * R.region        (* integer memory register *)
       | Record  of {boxed: bool,            (* is it a boxed record *)
                     words:int,              (* how many words *)
                     reg: Cells.cell,        (* address of this record *)
                     regTmp: Cells.cell,     (* temp used for unpacking *)
                     fields: binding list    (* its fields *)
                    }

       (* 
        * Translates rexp/fexp into bindings.
        * Note: client roots from memory (XXX) should NOT be used without
        * fixing a potential cycle problem in the parallel copies below.
        * Currently, all architectures, including the x86, do not uses
        * the LOAD(...) form.  So we are safe.
        *)
       fun bind(T.REG(32, r)) = Reg r
         | bind(T.LOAD(32, ea, mem)) = Mem(ea, mem)  (* XXX *)
         | bind(_) = error "bind"
       fun fbind(T.FREG(64, r)) = Freg r
         | fbind(_) = error "fbind"

       val st     = !stamp 
       val cyclic = st + 1
       val _      = if st > 100000 then stamp := 0 else stamp := st + 2
       val N = A.length clientRoots
       fun markClients [] = ()
         | markClients(T.REG(_, r)::rs) = 
            (if r < N then A.update(clientRoots, r, st) else ();
             markClients rs)
         | markClients(_::rs) = markClients rs
       fun markGCRoots [] = ()
         | markGCRoots(T.REG(_, r)::rs) = 
            (if A.sub(clientRoots, r) = st then
                A.update(clientRoots, r, cyclic)
             else (); 
             markGCRoots rs)
         | markGCRoots(_::rs) = markGCRoots rs

       val _ = markClients boxed
       val _ = markClients int32
       val _ = markGCRoots gcroots

       (*
        * First, we pack all unboxed roots, if any, into a record. 
        *) 
       val boxedStuff = 
           case (int32, float) of
             ([], []) => map bind boxed
           | _ =>
             (* align the allocptr if we have floating point roots *)
             (case float of
                [] => ()
              | _  => emit(T.MV(addrTy, allocptrR, 
                                T.ORB(addrTy, C.allocptr, T.LI 4)));
              (* If we have int32 or floating point stuff, package them
               * up into a raw record.  Floating point stuff have to come first.
               *)
               let val qwords=length float + (length int32 + 1) div 2
               in  Record{boxed=false, reg=Cells.newReg(), 
                          regTmp=Cells.newReg(),
                          words=qwords + qwords,
                          fields=map fbind float @ map bind int32} 
                      ::map bind boxed
               end
             )
       (*
        * Then, we check whether we have enough gc roots to store boxedStuff.
        * If so, we are safe. Otherwise, we have to pack up some of the 
        * boxed stuff into a record too.
        *) 
 
       val nBoxedStuff = length boxedStuff
       val nGcRoots    = length gcroots

       val bindings = 
           if nBoxedStuff <= nGcRoots 
           then boxedStuff (* good enough *)
           else (* package up some of the boxed stuff *)
           let val extra       = nBoxedStuff - nGcRoots + 1
               val packUp      = List.take(boxedStuff, extra)
               val don'tPackUp = List.drop(boxedStuff, extra)
           in  Record{boxed=true, words=length packUp,
                      regTmp=Cells.newReg(),
                      reg=Cells.newReg(), fields=packUp}::don'tPackUp 
           end
 
       fun copy([], _) = ()
         | copy(dst, src) = emit(T.COPY(32, dst, src))

       (* 
        * The following routine copies the client roots into the real gc roots.
        * We have to make sure that cycles have correctly handled.  So we
        * can't do a copy at a time!  But see XXX below.
        *)
       fun prolog(hp, unusedRoots, [], rds, rss) = 
           let fun init [] = ()
                 | init(T.REG(ty, rd)::roots) = 
                     (emit(T.MV(ty, rd, unit)); init roots)
                 | init(T.LOAD(ty, ea, mem)::roots) = 
                     (emit(T.STORE(ty, ea, unit, mem)); init roots)
                 | init _ = error "init"
           in  (* update the heap pointer if we have done any allocation *)
               if hp > 0 then  
                  emit(T.MV(addrTy, allocptrR, 
                            T.ADD(addrTy, C.allocptr, T.LI hp)))
               else ();
               (* emit the parallel copies *)
               copy(rds, rss);
               (*
                * Any unused gc roots have to be initialized with unit.
                * The following MUST come last. 
                *)
               init unusedRoots
           end
         | prolog(hp, T.REG(_,rd)::roots, Reg rs::bs, rds, rss) = 
             (* copy client root rs into gc root rd  *)
             prolog(hp, roots, bs, rd::rds, rs::rss)
         | prolog(hp, T.REG(_,rd)::roots, Record(r as {reg,...})::bs,rds,rss) = 
             (* make a record then copy *)
             let val hp = makeRecord(hp, r)
             in  prolog(hp, roots, bs, rd::rds, reg::rss)
             end
         (*| prolog(hp, T.LOAD(_,ea,mem)::roots, b::bs, rds, rss) = (* XXX *)
             (* The following code is unsafe because of potential cycles!
              * But luckly, it is unused XXX.
              *)
             let val (hp, e) = 
                     case b of
                       Reg r => (hp, T.REG(32, r))
                     | Mem(ea, mem) => (hp, T.LOAD(32, ea, mem))
                     | Record(r as {reg, ...}) => 
                         (makeRecord(hp, r), T.REG(32,reg))
                     | _ => error "floating point root"
             in  emit(T.STORE(32, ea, e, mem)); 
                 prolog(hp, roots, bs, rds, rss) 
             end*)
         | prolog _ = error "prolog"

            (* Make a record and put it in reg *) 
       and makeRecord(hp, {boxed, words, reg, fields, ...}) = 
           let fun disp(n) = T.ADD(addrTy, C.allocptr, T.LI n)
               fun alloci(hp, e) = emit(T.STORE(32, disp hp, e, R.memory))
               fun allocf(hp, e) = emit(T.FSTORE(64, disp hp, e, R.memory))
               fun alloc(hp, []) = ()
                 | alloc(hp, b::bs) = 
                   (case b of 
                     Reg r => (alloci(hp, T.REG(32,r)); alloc(hp+4, bs))
                   | Record{reg, ...} => 
                      (alloci(hp, T.REG(32,reg)); alloc(hp+4, bs))
                   | Mem(ea,m) => (alloci(hp, T.LOAD(32,ea,m)); alloc(hp+4,bs))
                   | Freg r => (allocf(hp, T.FREG(64,r)); alloc(hp+8, bs))
                   )
               fun evalArgs([], hp) = hp
                 | evalArgs(Record r::args, hp) = 
                    evalArgs(args, makeRecord(hp, r))
                 | evalArgs(_::args, hp) = evalArgs(args, hp)
               (* MUST evaluate nested records first *)
               val hp   = evalArgs(fields, hp)
               val desc = if boxed then boxedDesc words else unboxedDesc words
           in  emit(T.STORE(32, disp hp, T.LI desc, R.memory));
               alloc(hp+4, fields);
               emit(T.MV(addrTy, reg, disp(hp+4))); 
               hp + 4 + Word.toIntX(Word.<<(Word.fromInt words,0w2))
           end

          (* Copy the gc roots back to client roots. 
           * Again, to avoid potential cycles, we generate a single 
           * parallel copy that moves the gc roots back to the client roots.
           *)
       fun epilog([], unusedGcRoots, rds, rss) = 
             copy(rds, rss)
         | epilog(Reg rd::bs, T.REG(_,rs)::roots, rds, rss) = 
             epilog(bs, roots, rd::rds, rs::rss)
         | epilog(Record{fields,regTmp,...}::bs, T.REG(_,r)::roots, rds, rss) = 
              (* unbundle record *)
              let val _   = emit(T.COPY(32, [regTmp], [r]))
                  val (rds, rss) = unpack(regTmp, fields, rds, rss)
              in  epilog(bs, roots, rds, rss) end
         | epilog(b::bs, r::roots, rds, rss) = 
             (assign(b, r); (* XXX *)
              epilog(bs, roots, rds, rss)
             )
         | epilog _ = error "epilog"

       and assign(Reg r, e)        = emit(T.MV(32, r, e))
         | assign(Mem(ea, mem), e) = emit(T.STORE(32, ea, e, mem))
         | assign _ = error "assign"

           (* unpack fields from record *)
       and unpack(recordR, fields, rds, rss) = 
           let val record = T.REG(32, recordR)
               fun disp n = T.ADD(addrTy, record, T.LI n)
               fun sel n = T.LOAD(32, disp n, R.memory)
               fun fsel n = T.FLOAD(64, disp n, R.memory)
               val N = A.length clientRoots
               (* unpack normal fields *)
               fun unpackFields(n, [], rds, rss) = (rds, rss)
                 | unpackFields(n, Freg r::bs, rds, rss) = 
                     (emit(T.FMV(64, r, fsel n)); 
                      unpackFields(n+8, bs, rds, rss))
                 | unpackFields(n, Mem(ea, mem)::bs, rds, rss) = 
                     (emit(T.STORE(32, ea, sel n, mem));  (* XXX *)
                      unpackFields(n+4, bs, rds, rss))
                 | unpackFields(n, Record{regTmp, ...}::bs, rds, rss) = 
                     (emit(T.MV(32, regTmp, sel n));
                      unpackFields(n+4, bs, rds, rss))
                 | unpackFields(n, Reg rd::bs, rds, rss) = 
                   if rd < N andalso A.sub(clientRoots, rd) = cyclic then  
                   let val tmpR = Cells.newReg()
                   in  (* print "WARNING: CYCLE\n"; *)
                       emit(T.MV(32, tmpR, sel n));
                       unpackFields(n+4, bs, rd::rds, tmpR::rss)
                   end else
                       (emit(T.MV(32, rd, sel n));
                        unpackFields(n+4, bs, rds, rss))

               (* unpack nested record *)
               fun unpackNested(_, [], rds, rss) = (rds, rss)
                 | unpackNested(n, Record{fields, regTmp, ...}::bs, rds, rss) = 
                   let val (rds, rss) = unpack(regTmp, fields, rds, rss)
                   in  unpackNested(n+4, bs, rds, rss)
                   end
                 | unpackNested(n, Freg _::bs, rds, rss) =
                     unpackNested(n+8, bs, rds, rss)
                 | unpackNested(n, _::bs, rds, rss) =
                     unpackNested(n+4, bs, rds, rss)

               val (rds, rss)= unpackFields(0, fields, rds, rss)
           in  unpackNested(0, fields, rds, rss)
           end

       (* generate code *)
   in  prolog(0, gcroots, bindings, [], []);
       (* return the unpack function *)
       fn () => epilog(bindings, gcroots, [], [])
   end

   (*
    * The following auxiliary function generates the actual call gc code. 
    * It packages up the roots into the appropriate
    * records, call the GC routine, then unpack the roots from the record.
    *) 
   fun emitCallGC{stream=St.STREAM{emit, annotation, defineLabel, ...}, 
                  known, boxed, int32, float, ret} =
   let (* IMPORTANT NOTE:  
        * If a boxed root happens be in a gc root register, we can remove
        * this root since it will be correctly targetted. 
        *
        * boxedRoots are the boxed roots that we have to move to the appropriate
        * registers.  gcrootSet are the registers that are available
        * for communicating to the collector.
        *)
       val boxedSet   = set boxed
       val boxedRoots = difference(boxedSet,gcrootSet)  (* roots *)
       val gcrootAvail = difference(gcrootSet,boxedSet) (* gcroots available *)

       fun mark(call) =
           if !debug then
              T.ANNOTATION(call,#create MLRiscAnnotations.COMMENT 
                 ("roots="^setToString gcrootAvail^
                  " boxed="^setToString boxedRoots))
           else call
 
       (* convert them back to MLTREE *)
       val boxed   = setToMLTree boxedRoots 
       val gcroots = setToMLTree gcrootAvail

       (* If we have any remaining roots after the above trick, we have to 
        * make sure that gcroots is not empty.
        *)
       val (gcroots, boxed) = 
           case (gcroots, int32, float, boxed) of
             ([], [], [], []) => ([], []) (* it's okay *)
           | ([], _, _, _) => ([aRootReg], boxed @ [aRootReg]) 
             (* put aRootReg last to reduce register pressure 
              * during unpacking
              *)
           | _  => (gcroots, boxed)

       val unpack = pack(emit, gcroots, boxed, int32, float)
   in  annotation(CALLGC);
       annotation(NO_OPTIMIZATION); 
       annotation(ZERO_FREQ);
       emit(mark(gcCall));
       if known then computeBasePtr(emit,defineLabel,annotation) else ();
       annotation(NO_OPTIMIZATION);
       unpack();
       emit ret
   end

   (*
    * The following function is responsible for generating only the
    * callGC code.
    *)
   fun callGC stream {regfmls, regtys, ret} =
   let val {boxed, int32, float} = split(regfmls, regtys, [], [], [])
   in  emitCallGC{stream=stream, known=true, 
                  boxed=boxed, int32=int32, float=float, ret=ret}
   end

   (*
    * This function emits a comment that pretty prints the root set.
    * This is used for debugging only.
    *)
   fun rootSetToString{boxed, int32, float} = 
   let fun extract(T.REG(32, r)) = r
         | extract _ = error "extract"
       fun fextract(T.FREG(64, f)) = f
         | fextract _ = error "fextract"
       fun listify title f [] = ""
         | listify title f l  = 
             title^foldr (fn (x,"") => f x
                           | (x,y)  => f x ^", "^y) "" (S.uniq l)^" "
   in  listify "boxed=" (Cells.toString Cells.GP) (map extract boxed)^
       listify "int32=" (Cells.toString Cells.GP) (map extract int32)^
       listify "float=" (Cells.toString Cells.FP) (map fextract float)
   end

   (*
    * The following function is responsible for generating actual
    * GC calling code, with entry labels and return information.
    *)
   fun invokeGC(stream as 
                St.STREAM{emit,defineLabel,entryLabel,exitBlock,annotation,...},
                externalEntry) gcInfo = 
   let val {known, optimized, boxed, int32, float, regfmls, ret, lab} =
           case gcInfo of
             GCINFO info => info
           | MODULE{info=GCINFO info,...} => info
           | _ => error "invokeGC:gcInfo"

       val liveout = if optimized then [] else regfmls

   in  if externalEntry then entryLabel (!lab) else defineLabel (!lab);
       (* When the known block is optimized, no actual code is generated
        * until later.
        *)
       if optimized then 
            (annotation(#create MLRiscAnnotations.GCSAFEPOINT 
               (if !debug then
                 rootSetToString{boxed=boxed, int32=int32, float=float}
                else ""
               ));
             emit ret
            )
       else emitCallGC{stream=stream, known=known,
                       boxed=boxed, int32=int32, float=float, ret=ret};
       exitBlock(case C.exhausted of NONE    => liveout 
                                   | SOME cc => T.CCR cc::liveout)
   end

   (*
    * The following function checks whether two root set have the
    * same calling convention.
    *)
   fun sameCallingConvention
          (GCINFO{boxed=b1, int32=i1, float=f1, ret=T.JMP(_, ret1, _), ...},
           GCINFO{boxed=b2, int32=i2, float=f2, ret=T.JMP(_, ret2, _), ...}) =
   let fun eqEA(T.REG(_, r1), T.REG(_, r2)) = r1 = r2
         | eqEA(T.ADD(_,T.REG(_,r1),T.LI i), T.ADD(_,T.REG(_,r2),T.LI j)) =  
             r1 = r2 andalso i = j
         | eqEA _ = false
       fun eqR(T.REG(_,r1), T.REG(_,r2)) = r1 = r2
         | eqR(T.LOAD(_,ea1,_), T.LOAD(_,ea2,_)) = eqEA(ea1, ea2)
         | eqR _ = false
       fun eqF(T.FREG(_,f1), T.FREG(_,f2)) = f1 = f2
         | eqF(T.FLOAD(_,ea1,_), T.FLOAD(_,ea2,_)) = eqEA(ea1, ea2)
         | eqF _ = false

       fun all predicate = 
       let fun f(a::x,b::y) = predicate(a,b) andalso f(x,y)
             | f([],[]) = true
             | f _ = false
       in  f end

       val eqRexp = all eqR
   in  eqRexp(b1, b2) andalso eqR(ret1,ret2) andalso 
       eqRexp(i1,i2) andalso all eqF(f1,f2)
   end 
     | sameCallingConvention _ = false

   (*
    * The following function is called once at the end of compiling a cluster.
    * Generates long jumps to the end of the module unit for
    * standard functions, and directly invokes GC for known functions.
    * The actual GC invocation code is not generated yet.
    *)
   fun emitLongJumpsToGCInvocation
       (stream as St.STREAM{emit,defineLabel,exitBlock,...}) =
   let (* GC code can be shared if the calling convention is the same 
        * Use linear search to find the gc subroutine.
        *)
       fun find(info as GCINFO{lab as ref l, ...}) =
       let fun search(MODULE{info=info', addrs}::rest) =
               if sameCallingConvention(info, info') then
                  addrs := l :: (!addrs) 
               else search rest
             | search [] = (* no matching convention *)
               let val label = Label.newLabel ""
               in  lab := label;
                   moduleGcBlocks := MODULE{info=info, addrs=ref[l]} ::
                      (!moduleGcBlocks)
               end
             | search _ = error "search"
       in  search(!moduleGcBlocks) 
       end
         | find _ = error "find"

       (*
        * Generate a long jump to all external callgc routines 
        *)
       fun longJumps(MODULE{addrs=ref [],...}) = ()
         | longJumps(MODULE{info=GCINFO{lab,boxed,int32,float,...}, addrs}) =
           let val regRoots  = map T.GPR (int32 @ boxed)
               val fregRoots = map T.FPR float
               val liveOut   = regRoots @ fregRoots
               val l         = !lab
           in  app defineLabel (!addrs) before addrs := [];
               emit(T.JMP([], T.LABEL(LE.LABEL l), []));
               exitBlock liveOut
           end
         | longJumps _ = error "longJumps"

   in  app find (!clusterGcBlocks) before clusterGcBlocks := [];
       app longJumps (!moduleGcBlocks);
       app (invokeGC(stream,false)) (!knownGcBlocks) before knownGcBlocks := []
   end (* emitLongJumpsToGC *)

   (* 
    * The following function is called to generate module specific 
    * GC invocation code 
    *)
   fun emitModuleGC(stream) =
       app (invokeGC(stream,true)) (!moduleGcBlocks) before moduleGcBlocks := []

end
