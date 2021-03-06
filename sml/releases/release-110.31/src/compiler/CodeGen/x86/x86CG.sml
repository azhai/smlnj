(*
 * X86 specific backend.  This one uses the new RA8 scheme.
 *)
structure X86CG = 
  MachineGen
  ( structure I          = X86Instr
    structure C          = I.C
    structure F          = X86FlowGraph
    structure R          = X86CpsRegs
    structure CG         = Control.CG

    structure MachSpec   = X86Spec
    structure PseudoOps  = X86PseudoOps
    structure CpsRegs    = X86CpsRegs
    structure InsnProps  = X86Props
    structure Asm        = X86AsmEmitter
    structure Shuffle    = X86Shuffle

    val spill = CPSRegions.spill 
    val stack = CPSRegions.stack 
    val esp   = I.C.esp

    fun error msg = MLRiscErrorMsg.error("X86CG",msg)

    val fast_floating_point = MLRiscControl.getFlag "x86-fast-fp"

    structure MLTreeComp=
       X86(structure X86Instr=X86Instr
           structure X86MLTree=X86MLTree
           structure ExtensionComp = X86MLTreeExtComp
               (structure I = X86Instr
                structure T = X86MLTree
               )
           val tempMem = I.Displace{base=esp, disp=I.Immed 304, mem=stack}
           fun cvti2f{src,ty} = (* ty is always 32 for SML/NJ *)
               {instrs  = [I.MOVE{mvOp=I.MOVL, src=src, dst=tempMem}],
                tempMem = tempMem, 
                cleanup = []
               }
           datatype arch = Pentium | PentiumPro | PentiumII | PentiumIII
           val arch = ref Pentium (* Lowest common denominator *)
           val fast_floating_point = fast_floating_point
          )

    structure Jumps = 
       X86Jumps(structure Instr=X86Instr
                structure AsmEmitter=X86AsmEmitter
                structure Shuffle=X86Shuffle
                structure MCEmitter=X86MCEmitter)
   
    structure BackPatch = 
       BackPatch(structure Jumps=Jumps
                 structure Emitter=X86MCEmitter
                 structure Props=InsnProps
                 structure Flowgraph=X86FlowGraph
                 structure Asm=X86AsmEmitter
                 structure CodeString=CodeString)


    structure RA = 
      X86RA
      (structure I         = X86Instr
       structure InsnProps = InsnProps
       structure Asm       = X86AsmEmitter
       structure F         = X86FlowGraph
       structure SpillHeur = ChowHennessySpillHeur
       structure Spill     = RASpill
                             (structure Asm = X86AsmEmitter
                              structure InsnProps = InsnProps
                             )

       val beforeRA = X86StackSpills.init
       val fast_floating_point = fast_floating_point

       val toInt32 = Int32.fromInt
       fun cacheOffset r = I.Immed(toInt32(X86Runtime.vregStart + 
                                Word.toIntX(Word.<<(Word.fromInt(r-8),0w2))))
       fun cacheFPOffset f = I.Immed(toInt32(X86Runtime.vFpStart + 
                                Word.toIntX(Word.<<(Word.fromInt(f-40),0w3))))

       datatype raPhase = SPILL_PROPAGATION | SPILL_COLORING

       structure Int =  
       struct
          val avail     = R.availR
          val dedicated = R.dedicatedR
          val memRegs   = C.Regs C.GP {from=8,to=31,step=1}
          val phases    = [SPILL_PROPAGATION,SPILL_COLORING]

          (* We try to make unused memregs available for spilling 
           * This is necessary because of the stupid SML code generator
           * doesn't keep track of which are being used.
           *)
          fun spillInit(RAGraph.GRAPH{nodes, ...}) = 
          let val lookup = IntHashTable.lookup nodes
              fun find(r, free) =
                  if r >= 10 then (* note, %8 and %9 are reserved! *)
                     let val free = 
                             case lookup r of
                               RAGraph.NODE{uses=ref [], defs=ref [], ...} => 
                                  cacheOffset r::free
                             | _ => free
                     in  find(r-1, free) end
                  else 
                     free
              val free = find(31 (* X86Runtime.numVregs+8-1 *), [])
          in  X86StackSpills.setAvailableOffsets free
          end 
 
          val getRegLoc' = X86StackSpills.getRegLoc
 
          fun spillLoc(an, loc) = 
              I.Displace{base=esp, disp=getRegLoc' loc, mem=spill}
 
       end

       structure Float =
       struct
          val avail     = R.availF
          val dedicated = R.dedicatedF
          val memRegs   = []
          val phases    = [SPILL_PROPAGATION]

          fun spillInit(RAGraph.GRAPH{nodes, ...}) = 
              if !fast_floating_point then
              let val lookup = IntHashTable.lookup nodes
                 fun find(r, free) =
                     if r >= 32+8 then 
                        let val free = 
                                case lookup r of
                                  RAGraph.NODE{uses=ref [], defs=ref [],...} =>
                                     cacheFPOffset r::free
                                | _ => free
                        in  find(r-1, free) end
                     else 
                        free
                 val free = find(63, [])
              in X86StackSpills.setAvailableFPOffsets free
              end 
              else ()

          fun spillLoc(an, loc) =
            I.Displace{base=esp, disp=X86StackSpills.getFregLoc loc, mem=spill}

          val fastMemRegs = C.Regs C.FP {from=8, to=31, step=1}
          val fastPhases  = [SPILL_PROPAGATION,SPILL_COLORING]
      end
    ) (* X86RA *)
  ) 

