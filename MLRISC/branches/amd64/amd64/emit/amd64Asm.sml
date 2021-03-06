(*
 * WARNING: This file was automatically generated by MDLGen (v3.1)
 * from the machine description file "amd64/amd64.mdl".
 * DO NOT EDIT this file directly
 *)


functor AMD64AsmEmitter(structure S : INSTRUCTION_STREAM
                        structure Instr : AMD64INSTR
                           where T = S.P.T
                        structure Shuffle : AMD64SHUFFLE
                           where I = Instr
                        structure MLTreeEval : MLTREE_EVAL
                           where T = Instr.T
                       ) : INSTRUCTION_EMITTER =
struct
   structure I  = Instr
   structure C  = I.C
   structure T  = I.T
   structure S  = S
   structure P  = S.P
   structure Constant = I.Constant
   
   open AsmFlags
   
   fun error msg = MLRiscErrorMsg.error("AMD64AsmEmitter",msg)
   
   fun makeStream formatAnnotations =
   let val stream = !AsmStream.asmOutStream
       fun emit' s = TextIO.output(stream,s)
       val newline = ref true
       val tabs = ref 0
       fun tabbing 0 = ()
         | tabbing n = (emit' "\t"; tabbing(n-1))
       fun emit s = (tabbing(!tabs); tabs := 0; newline := false; emit' s)
       fun nl() = (tabs := 0; if !newline then () else (newline := true; emit' "\n"))
       fun comma() = emit ","
       fun tab() = tabs := 1
       fun indent() = tabs := 2
       fun ms n = let val s = Int.toString n
                  in  if n<0 then "-"^String.substring(s,1,size s-1)
                      else s
                  end
       fun emit_label lab = emit(P.Client.AsmPseudoOps.lexpToString(T.LABEL lab))
       fun emit_labexp le = emit(P.Client.AsmPseudoOps.lexpToString (T.LABEXP le))
       fun emit_const c = emit(Constant.toString c)
       fun emit_int i = emit(ms i)
       fun paren f = (emit "("; f(); emit ")")
       fun defineLabel lab = emit(P.Client.AsmPseudoOps.defineLabel lab^"\n")
       fun entryLabel lab = defineLabel lab
       fun comment msg = (tab(); emit("/* " ^ msg ^ " */"); nl())
       fun annotation a = comment(Annotations.toString a)
       fun getAnnotations() = error "getAnnotations"
       fun doNothing _ = ()
       fun fail _ = raise Fail "AsmEmitter"
       fun emit_region mem = comment(I.Region.toString mem)
       val emit_region = 
          if !show_region then emit_region else doNothing
       fun pseudoOp pOp = (emit(P.toString pOp); emit "\n")
       fun init size = (comment("Code Size = " ^ ms size); nl())
       val emitCellInfo = AsmFormatUtil.reginfo
                                (emit,formatAnnotations)
       fun emitCell r = (emit(CellsBasis.toString r); emitCellInfo r)
       fun emit_cellset(title,cellset) =
         (nl(); comment(title^CellsBasis.CellSet.toString cellset))
       val emit_cellset = 
         if !show_cellset then emit_cellset else doNothing
       fun emit_defs cellset = emit_cellset("defs: ",cellset)
       fun emit_uses cellset = emit_cellset("uses: ",cellset)
       val emit_cutsTo = 
         if !show_cutsTo then AsmFormatUtil.emit_cutsTo emit
         else doNothing
       fun emitter instr =
       let
   fun asm_cond (I.EQ) = "e"
     | asm_cond (I.NE) = "ne"
     | asm_cond (I.LT) = "l"
     | asm_cond (I.LE) = "le"
     | asm_cond (I.GT) = "g"
     | asm_cond (I.GE) = "ge"
     | asm_cond (I.B) = "b"
     | asm_cond (I.BE) = "be"
     | asm_cond (I.A) = "a"
     | asm_cond (I.AE) = "ae"
     | asm_cond (I.C) = "c"
     | asm_cond (I.NC) = "nc"
     | asm_cond (I.P) = "p"
     | asm_cond (I.NP) = "np"
     | asm_cond (I.O) = "o"
     | asm_cond (I.NO) = "no"
   and emit_cond x = emit (asm_cond x)
   and asm_binaryOp (I.ADD_Q) = "add_q"
     | asm_binaryOp (I.SUB_Q) = "sub_q"
     | asm_binaryOp (I.AND_Q) = "and_q"
     | asm_binaryOp (I.OR_Q) = "or_q"
     | asm_binaryOp (I.XOR_Q) = "xor_q"
     | asm_binaryOp (I.SHL_Q) = "shl_q"
     | asm_binaryOp (I.SAR_Q) = "sar_q"
     | asm_binaryOp (I.SHR_Q) = "shr_q"
     | asm_binaryOp (I.MUL_Q) = "mul_q"
     | asm_binaryOp (I.IMUL_Q) = "imul_q"
     | asm_binaryOp (I.ADC_Q) = "adc_q"
     | asm_binaryOp (I.SBB_Q) = "sbb_q"
     | asm_binaryOp (I.ADD_L) = "add_l"
     | asm_binaryOp (I.SUB_L) = "sub_l"
     | asm_binaryOp (I.AND_L) = "and_l"
     | asm_binaryOp (I.OR_L) = "or_l"
     | asm_binaryOp (I.XOR_L) = "xor_l"
     | asm_binaryOp (I.SHL_L) = "shl_l"
     | asm_binaryOp (I.SAR_L) = "sar_l"
     | asm_binaryOp (I.SHR_L) = "shr_l"
     | asm_binaryOp (I.MUL_L) = "mul_l"
     | asm_binaryOp (I.IMUL_L) = "imul_l"
     | asm_binaryOp (I.ADC_L) = "adc_l"
     | asm_binaryOp (I.SBB_L) = "sbb_l"
     | asm_binaryOp (I.ADD_W) = "add_w"
     | asm_binaryOp (I.SUB_W) = "sub_w"
     | asm_binaryOp (I.AND_W) = "and_w"
     | asm_binaryOp (I.OR_W) = "or_w"
     | asm_binaryOp (I.XOR_W) = "xor_w"
     | asm_binaryOp (I.SHL_W) = "shl_w"
     | asm_binaryOp (I.SAR_W) = "sar_w"
     | asm_binaryOp (I.SHR_W) = "shr_w"
     | asm_binaryOp (I.MUL_W) = "mul_w"
     | asm_binaryOp (I.IMUL_W) = "imul_w"
     | asm_binaryOp (I.ADD_B) = "add_b"
     | asm_binaryOp (I.SUB_B) = "sub_b"
     | asm_binaryOp (I.AND_B) = "and_b"
     | asm_binaryOp (I.OR_B) = "or_b"
     | asm_binaryOp (I.XOR_B) = "xor_b"
     | asm_binaryOp (I.SHL_B) = "shl_b"
     | asm_binaryOp (I.SAR_B) = "sar_b"
     | asm_binaryOp (I.SHR_B) = "shr_b"
     | asm_binaryOp (I.MUL_B) = "mul_b"
     | asm_binaryOp (I.IMUL_B) = "imul_b"
     | asm_binaryOp (I.BT_Q) = "bt_q"
     | asm_binaryOp (I.BT_L) = "bt_l"
     | asm_binaryOp (I.BT_W) = "bt_w"
     | asm_binaryOp (I.BTC_Q) = "btc_q"
     | asm_binaryOp (I.BTC_L) = "btc_l"
     | asm_binaryOp (I.BTC_W) = "btc_w"
     | asm_binaryOp (I.BTR_Q) = "btr_q"
     | asm_binaryOp (I.BTR_L) = "btr_l"
     | asm_binaryOp (I.BTR_W) = "btr_w"
     | asm_binaryOp (I.BTS_Q) = "bts_q"
     | asm_binaryOp (I.BTS_L) = "bts_l"
     | asm_binaryOp (I.BTS_W) = "bts_w"
     | asm_binaryOp (I.ROL_W) = "rol_w"
     | asm_binaryOp (I.ROR_W) = "ror_w"
     | asm_binaryOp (I.ROL_L) = "rol_l"
     | asm_binaryOp (I.ROR_L) = "ror_l"
     | asm_binaryOp (I.XCHG_B) = "xchg_b"
     | asm_binaryOp (I.XCHG_W) = "xchg_w"
     | asm_binaryOp (I.XCHG_L) = "xchg_l"
     | asm_binaryOp (I.LOCK_ADC_W) = "lock\n\tadcw"
     | asm_binaryOp (I.LOCK_ADC_L) = "lock\n\tadcl"
     | asm_binaryOp (I.LOCK_ADD_W) = "lock\n\taddw"
     | asm_binaryOp (I.LOCK_ADD_L) = "lock\n\taddl"
     | asm_binaryOp (I.LOCK_AND_W) = "lock\n\tandw"
     | asm_binaryOp (I.LOCK_AND_L) = "lock\n\tandl"
     | asm_binaryOp (I.LOCK_BTS_W) = "lock\n\tbtsw"
     | asm_binaryOp (I.LOCK_BTS_L) = "lock\n\tbtsl"
     | asm_binaryOp (I.LOCK_BTR_W) = "lock\n\tbtrw"
     | asm_binaryOp (I.LOCK_BTR_L) = "lock\n\tbtrl"
     | asm_binaryOp (I.LOCK_BTC_W) = "lock\n\tbtcw"
     | asm_binaryOp (I.LOCK_BTC_L) = "lock\n\tbtcl"
     | asm_binaryOp (I.LOCK_OR_W) = "lock\n\torw"
     | asm_binaryOp (I.LOCK_OR_L) = "lock\n\torl"
     | asm_binaryOp (I.LOCK_SBB_W) = "lock\n\tsbbw"
     | asm_binaryOp (I.LOCK_SBB_L) = "lock\n\tsbbl"
     | asm_binaryOp (I.LOCK_SUB_W) = "lock\n\tsubw"
     | asm_binaryOp (I.LOCK_SUB_L) = "lock\n\tsubl"
     | asm_binaryOp (I.LOCK_XOR_W) = "lock\n\txorw"
     | asm_binaryOp (I.LOCK_XOR_L) = "lock\n\txorl"
     | asm_binaryOp (I.LOCK_XADD_B) = "lock\n\txaddb"
     | asm_binaryOp (I.LOCK_XADD_W) = "lock\n\txaddw"
     | asm_binaryOp (I.LOCK_XADD_L) = "lock\n\txaddl"
   and emit_binaryOp x = emit (asm_binaryOp x)
   and asm_multDivOp (I.IMULL1) = "imull"
     | asm_multDivOp (I.MULL1) = "mull"
     | asm_multDivOp (I.IDIVL1) = "idivl"
     | asm_multDivOp (I.DIVL1) = "divl"
     | asm_multDivOp (I.IMULQ1) = "imulq"
     | asm_multDivOp (I.MULQ1) = "mulq"
     | asm_multDivOp (I.IDIVQ1) = "idivq"
     | asm_multDivOp (I.DIVQ1) = "divq"
   and emit_multDivOp x = emit (asm_multDivOp x)
   and asm_unaryOp (I.DEC_Q) = "dec_q"
     | asm_unaryOp (I.INC_Q) = "inc_q"
     | asm_unaryOp (I.NEG_Q) = "neg_q"
     | asm_unaryOp (I.NOT_Q) = "not_q"
     | asm_unaryOp (I.DEC_L) = "dec_l"
     | asm_unaryOp (I.INC_L) = "inc_l"
     | asm_unaryOp (I.NEG_L) = "neg_l"
     | asm_unaryOp (I.NOT_L) = "not_l"
     | asm_unaryOp (I.DEC_W) = "dec_w"
     | asm_unaryOp (I.INC_W) = "inc_w"
     | asm_unaryOp (I.NEG_W) = "neg_w"
     | asm_unaryOp (I.NOT_W) = "not_w"
     | asm_unaryOp (I.DEC_B) = "dec_b"
     | asm_unaryOp (I.INC_B) = "inc_b"
     | asm_unaryOp (I.NEG_B) = "neg_b"
     | asm_unaryOp (I.NOT_B) = "not_b"
     | asm_unaryOp (I.LOCK_DEC_Q) = "lock\n\tdecq"
     | asm_unaryOp (I.LOCK_INC_Q) = "lock\n\tincq"
     | asm_unaryOp (I.LOCK_NEG_Q) = "lock\n\tnegq"
     | asm_unaryOp (I.LOCK_NOT_Q) = "lock\n\tnotq"
   and emit_unaryOp x = emit (asm_unaryOp x)
   and asm_shiftOp (I.SHLD_L) = "shld_l"
     | asm_shiftOp (I.SHRD_L) = "shrd_l"
   and emit_shiftOp x = emit (asm_shiftOp x)
   and asm_bitOp (I.BT_Q) = "bt_q"
     | asm_bitOp (I.BT_L) = "bt_l"
     | asm_bitOp (I.BT_W) = "bt_w"
     | asm_bitOp (I.LOCK_BT_L) = "lock\n\tbtl"
     | asm_bitOp (I.LOCK_BT_W) = "lock\n\tbtw"
   and emit_bitOp x = emit (asm_bitOp x)
   and asm_move (I.MOV_Q) = "mov_q"
     | asm_move (I.MOV_L) = "mov_l"
     | asm_move (I.MOV_B) = "mov_b"
     | asm_move (I.MOV_W) = "mov_w"
     | asm_move (I.MOVABS_Q) = "movabs_q"
     | asm_move (I.MOVSW_Q) = "movsw_q"
     | asm_move (I.MOVZW_Q) = "movzw_q"
     | asm_move (I.MOVSW_L) = "movsw_l"
     | asm_move (I.MOVZW_L) = "movzw_l"
     | asm_move (I.MOVSB_Q) = "movsb_q"
     | asm_move (I.MOVZB_Q) = "movzb_q"
     | asm_move (I.MOVSB_L) = "movsb_l"
     | asm_move (I.MOVZB_L) = "movzb_l"
     | asm_move (I.MOVSL_Q) = "movsl_q"
     | asm_move (I.CVTSD2SI) = "cvtsd2si"
     | asm_move (I.CVTSS2SI) = "cvtss2si"
     | asm_move (I.CVTSD2SIQ) = "cvtsd2siq"
     | asm_move (I.CVTSS2SIQ) = "cvtss2siq"
   and emit_move x = emit (asm_move x)
   and asm_fbin_op (I.ADDS_S) = "adds_s"
     | asm_fbin_op (I.ADDS_D) = "adds_d"
     | asm_fbin_op (I.SUBS_S) = "subs_s"
     | asm_fbin_op (I.SUBS_D) = "subs_d"
     | asm_fbin_op (I.MULS_S) = "muls_s"
     | asm_fbin_op (I.MULS_D) = "muls_d"
     | asm_fbin_op (I.DIVS_S) = "divs_s"
     | asm_fbin_op (I.DIVS_D) = "divs_d"
     | asm_fbin_op (I.XORP_S) = "xorp_s"
     | asm_fbin_op (I.XORP_D) = "xorp_d"
     | asm_fbin_op (I.ANDP_S) = "andp_s"
     | asm_fbin_op (I.ANDP_D) = "andp_d"
     | asm_fbin_op (I.ORP_S) = "orp_s"
     | asm_fbin_op (I.ORP_D) = "orp_d"
   and emit_fbin_op x = emit (asm_fbin_op x)
   and asm_fcom_op (I.COMIS_S) = "comis_s"
     | asm_fcom_op (I.COMIS_D) = "comis_d"
     | asm_fcom_op (I.UCOMIS_S) = "ucomis_s"
     | asm_fcom_op (I.UCOMIS_D) = "ucomis_d"
   and emit_fcom_op x = emit (asm_fcom_op x)
   and asm_fmove_op (I.MOVS_S) = "movs_s"
     | asm_fmove_op (I.MOVS_D) = "movs_d"
     | asm_fmove_op (I.CVTSS2SD) = "cvtss2sd"
     | asm_fmove_op (I.CVTSD2SS) = "cvtsd2ss"
     | asm_fmove_op (I.CVTSI2SS) = "cvtsi2ss"
     | asm_fmove_op (I.CVTSI2SSQ) = "cvtsi2ssq"
     | asm_fmove_op (I.CVTSI2SD) = "cvtsi2sd"
     | asm_fmove_op (I.CVTSI2SDQ) = "cvtsi2sdq"
   and emit_fmove_op x = emit (asm_fmove_op x)
   and asm_fsize (I.FP32) = "s"
     | asm_fsize (I.FP64) = "l"
   and emit_fsize x = emit (asm_fsize x)
   and asm_isize (I.I8) = "8"
     | asm_isize (I.I16) = "16"
     | asm_isize (I.I32) = "32"
     | asm_isize (I.I64) = "64"
   and emit_isize x = emit (asm_isize x)

(*#line 534.7 "amd64/amd64.mdl"*)
   fun emitInt32 i = 
       let 
(*#line 535.11 "amd64/amd64.mdl"*)
           val s = Int32.toString i

(*#line 536.11 "amd64/amd64.mdl"*)
           val s = (if (i >= 0)
                  then s
                  else ("-" ^ (String.substring (s, 1, (size s) - 1))))
       in emit s
       end

(*#line 540.7 "amd64/amd64.mdl"*)
   fun emitInt64 i = 
       let 
(*#line 541.11 "amd64/amd64.mdl"*)
           val s = Int64.toString i

(*#line 542.11 "amd64/amd64.mdl"*)
           val s = (if (i >= 0)
                  then s
                  else ("-" ^ (String.substring (s, 1, (size s) - 1))))
       in emit s
       end

(*#line 547.7 "amd64/amd64.mdl"*)
   val {low=SToffset, ...} = C.cellRange CellsBasis.FP

(*#line 549.7 "amd64/amd64.mdl"*)
   fun emitScale 0 = emit "1"
     | emitScale 1 = emit "2"
     | emitScale 2 = emit "4"
     | emitScale 3 = emit "8"
     | emitScale _ = error "emitScale"
   and eImmed (I.Immed i) = emitInt32 i
     | eImmed (I.Immed64 i) = emitInt64 i
     | eImmed (I.ImmedLabel lexp) = emit_labexp lexp
     | eImmed _ = error "eImmed"
   and emit_operand opn = 
       (case opn of
         I.Immed i => 
         ( emit "$"; 
           emitInt32 i )
       | I.Immed64 i => 
         ( emit "$"; 
           emitInt64 i )
       | I.ImmedLabel lexp => 
         ( emit "$"; 
           emit_labexp lexp )
       | I.LabelEA le => emit_labexp le
       | I.Relative _ => error "emit_operand"
       | I.Direct(ty, r) => emit (CellsBasis.toStringWithSize (r, ty))
       | I.FDirect f => emit (CellsBasis.toString f)
       | I.Displace{base, disp, mem, ...} => 
         ( emit_disp disp; 
           emit "("; 
           emitCell base; 
           emit ")"; 
           emit_region mem )
       | I.Indexed{base, index, scale, disp, mem, ...} => 
         ( emit_disp disp; 
           emit "("; 
           
           (case base of
             NONE => ()
           | SOME base => emitCell base
           ); 
           comma (); 
           emitCell index; 
           comma (); 
           emitScale scale; 
           emit ")"; 
           emit_region mem )
       )
   and emit_operand8 (I.Direct(_, r)) = emit (CellsBasis.toStringWithSize (r, 
          8))
     | emit_operand8 opn = emit_operand opn
   and emit_cell (r, sz) = emit (CellsBasis.toStringWithSize (r, sz))
   and emit_disp (I.Immed 0) = ()
     | emit_disp (I.Immed i) = emitInt32 i
     | emit_disp (I.Immed64 0) = ()
     | emit_disp (I.Immed64 i) = emitInt64 i
     | emit_disp (I.ImmedLabel lexp) = emit_labexp lexp
     | emit_disp _ = error "emit_disp"

(*#line 597.7 "amd64/amd64.mdl"*)
   fun stupidGas (I.ImmedLabel lexp) = emit_labexp lexp
     | stupidGas opnd = 
       ( emit "*"; 
         emit_operand opnd )

(*#line 601.7 "amd64/amd64.mdl"*)
   fun isMemOpnd (I.FDirect f) = true
     | isMemOpnd (I.LabelEA _) = true
     | isMemOpnd (I.Displace _) = true
     | isMemOpnd (I.Indexed _) = true
     | isMemOpnd _ = false

(*#line 606.7 "amd64/amd64.mdl"*)
   fun chop fbinOp = 
       let 
(*#line 607.15 "amd64/amd64.mdl"*)
           val n = size fbinOp
       in 
          (case Char.toLower (String.sub (fbinOp, n - 1)) of
            (#"s" | #"l") => String.substring (fbinOp, 0, n - 1)
          | _ => fbinOp
          )
       end

(*#line 613.7 "amd64/amd64.mdl"*)
   val emit_dst = emit_operand

(*#line 614.7 "amd64/amd64.mdl"*)
   val emit_src = emit_operand

(*#line 615.7 "amd64/amd64.mdl"*)
   val emit_opnd = emit_operand

(*#line 616.7 "amd64/amd64.mdl"*)
   val emit_opnd8 = emit_operand8

(*#line 617.7 "amd64/amd64.mdl"*)
   val emit_rsrc = emit_operand

(*#line 618.7 "amd64/amd64.mdl"*)
   val emit_lsrc = emit_operand

(*#line 619.7 "amd64/amd64.mdl"*)
   val emit_addr = emit_operand

(*#line 620.7 "amd64/amd64.mdl"*)
   val emit_src1 = emit_operand

(*#line 621.7 "amd64/amd64.mdl"*)
   val emit_ea = emit_operand

(*#line 622.7 "amd64/amd64.mdl"*)
   val emit_count = emit_operand
   fun emitInstr' instr = 
       (case instr of
         I.NOP => emit "nop"
       | I.JMP(operand, list) => 
         ( emit "jmp\t"; 
           stupidGas operand )
       | I.JCC{cond, opnd} => 
         ( emit "j"; 
           emit_cond cond; 
           emit "\t"; 
           stupidGas opnd )
       | I.CAL_L{opnd, defs, uses, return, cutsTo, mem, pops} => 
         ( emit "call\t"; 
           stupidGas opnd; 
           emit_region mem; 
           emit_defs defs; 
           emit_uses uses; 
           emit_cellset ("return", return); 
           emit_cutsTo cutsTo )
       | I.CALL_Q{opnd, defs, uses, return, cutsTo, mem, pops} => 
         ( emit "call\t"; 
           stupidGas opnd; 
           emit_region mem; 
           emit_defs defs; 
           emit_uses uses; 
           emit_cellset ("return", return); 
           emit_cutsTo cutsTo )
       | I.ENTER{src1, src2} => 
         ( emit "enter\t"; 
           emit_operand src1; 
           emit ", "; 
           emit_operand src2 )
       | I.LEAVE => emit "leave"
       | I.RET option => 
         ( emit "ret"; 
           
           (case option of
             NONE => ()
           | SOME e => 
             ( emit "\t"; 
               emit_operand e )
           ))
       | I.MOVE{mvOp, src, dst} => 
         ( emit_move mvOp; 
           emit "\t"; 
           emit_src src; 
           emit ", "; 
           emit_dst dst )
       | I.LEA_L{r32, addr} => 
         ( emit "leal\t"; 
           emit_addr addr; 
           emit ", "; 
           emit_cell (r32, 32))
       | I.LEA_Q{r64, addr} => 
         ( emit "leaq\t"; 
           emit_addr addr; 
           emit ", "; 
           emit_cell (r64, 64))
       | I.CMP_Q{lsrc, rsrc} => 
         ( emit "cmpq\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.CMP_L{lsrc, rsrc} => 
         ( emit "cmpl\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.CMP_W{lsrc, rsrc} => 
         ( emit "cmpb\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.CMP_B{lsrc, rsrc} => 
         ( emit "cmpb\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.TEST_Q{lsrc, rsrc} => 
         ( emit "testq\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.TEST_L{lsrc, rsrc} => 
         ( emit "testl\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.TEST_W{lsrc, rsrc} => 
         ( emit "testw\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.TEST_B{lsrc, rsrc} => 
         ( emit "testb\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.BITOP{bitOp, lsrc, rsrc} => 
         ( emit_bitOp bitOp; 
           emit "\t"; 
           emit_rsrc rsrc; 
           emit ", "; 
           emit_lsrc lsrc )
       | I.BINARY{binOp, src, dst} => 
         (case (src, binOp) of
           (I.Direct _, 
           ( I.SAR_Q |
           I.SHR_Q |
           I.SHL_Q |
           I.SAR_L |
           I.SHR_L |
           I.SHL_L |
           I.SAR_W |
           I.SHR_W |
           I.SHL_W |
           I.SAR_B |
           I.SHR_B |
           I.SHL_B )) => 
           ( emit_binaryOp binOp; 
             emit "\t%cl, "; 
             emit_dst dst )
         | _ => 
           ( emit_binaryOp binOp; 
             emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_dst dst )
         )
       | I.SHIFT{shiftOp, src, dst, count} => 
         (case count of
           I.Direct(ty, ecx) => 
           ( emit_shiftOp shiftOp; 
             emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_dst dst )
         | _ => 
           ( emit_shiftOp shiftOp; 
             emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_count count; 
             emit ", "; 
             emit_dst dst )
         )
       | I.MULTDIV{multDivOp, src} => 
         ( emit_multDivOp multDivOp; 
           emit "\t"; 
           emit_src src )
       | I.MUL3{dst, src2, src1} => 
         ( emit "imull\t$"; 
           emitInt32 src2; 
           emit ", "; 
           emit_src1 src1; 
           emit ", "; 
           emit_cell (dst, 32))
       | I.MULQ3{dst, src2, src1} => 
         ( emit "imulq\t$"; 
           emitInt32 src2; 
           emit ", "; 
           emit_src1 src1; 
           emit ", "; 
           emit_cell (dst, 64))
       | I.UNARY{unOp, opnd} => 
         ( emit_unaryOp unOp; 
           emit "\t"; 
           emit_opnd opnd )
       | I.SET{cond, opnd} => 
         ( emit "set"; 
           emit_cond cond; 
           emit "\t"; 
           emit_opnd8 opnd )
       | I.CMOV{cond, src, dst} => 
         ( emit "cmov"; 
           emit_cond cond; 
           emit "\t"; 
           emit_src src; 
           emit ", "; 
           emitCell dst )
       | I.PUSH_Q operand => 
         ( emit "pushq\t"; 
           emit_operand operand )
       | I.PUSH_L operand => 
         ( emit "pushl\t"; 
           emit_operand operand )
       | I.PUSH_W operand => 
         ( emit "pushw\t"; 
           emit_operand operand )
       | I.PUSH_B operand => 
         ( emit "pushb\t"; 
           emit_operand operand )
       | I.PUSHFD => emit "pushfd"
       | I.POPFD => emit "popfd"
       | I.POP operand => 
         ( emit "popq\t"; 
           emit_operand operand )
       | I.CD_Q => emit "cdq"
       | I.CLTD => emit "cltd"
       | I.CQTO => emit "cqto"
       | I.INTO => emit "int $4"
       | I.FMOVE{fmvOp, dst, src} => 
         ( emit_fmove_op fmvOp; 
           emit "\t "; 
           emit_src src; 
           emit ", "; 
           emit_dst dst )
       | I.FBINOP{binOp, dst, src} => 
         ( emit_fbin_op binOp; 
           emit "\t "; 
           emit_src src; 
           emit ", "; 
           emitCell dst )
       | I.FCOM{comOp, dst, src} => 
         ( emit_fcom_op comOp; 
           emit "\t "; 
           emit_src src; 
           emit ", "; 
           emitCell dst )
       | I.FSQRTS{dst, src} => 
         ( emit "sqrtss\t "; 
           emit_src src; 
           emit ", "; 
           emit_dst dst )
       | I.FSQRTD{dst, src} => 
         ( emit "sqrtsd\t "; 
           emit_src src; 
           emit ", "; 
           emit_dst dst )
       | I.SAHF => emit "sahf"
       | I.LFENCE => emit "lfence"
       | I.MFENCE => emit "mfence"
       | I.SFENCE => emit "sfence"
       | I.PAUSE => emit "pause"
       | I.XCHG{lock, sz, src, dst} => 
         ( (if lock
              then (emit "lock\n\t")
              else ()); 
           emit "xchg"; 
           
           (case sz of
             I.I8 => emit "b"
           | I.I16 => emit "w"
           | I.I32 => emit "l"
           | I.I64 => emit "q"
           ); 
           
           ( emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_dst dst ) )
       | I.CMPXCHG{lock, sz, src, dst} => 
         ( (if lock
              then (emit "lock\n\t")
              else ()); 
           emit "cmpxchg"; 
           
           (case sz of
             I.I8 => emit "b"
           | I.I16 => emit "w"
           | I.I32 => emit "l"
           | I.I64 => emit "q"
           ); 
           
           ( emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_dst dst ) )
       | I.XADD{lock, sz, src, dst} => 
         ( (if lock
              then (emit "lock\n\t")
              else ()); 
           emit "xadd"; 
           
           (case sz of
             I.I8 => emit "b"
           | I.I16 => emit "w"
           | I.I32 => emit "l"
           | I.I64 => emit "q"
           ); 
           
           ( emit "\t"; 
             emit_src src; 
             emit ", "; 
             emit_dst dst ) )
       | I.RDTSC => emit "rdtsc"
       | I.RDTSCP => emit "rdtscp"
       | I.LAHF => emit "lahf"
       | I.SOURCE{} => emit "source"
       | I.SINK{} => emit "sink"
       | I.PHI{} => emit "phi"
       )
      in  tab(); emitInstr' instr; nl()
      end (* emitter *)
      and emitInstrIndented i = (indent(); emitInstr i; nl())
      and emitInstrs instrs =
           app (if !indent_copies then emitInstrIndented
                else emitInstr) instrs
   
      and emitInstr(I.ANNOTATION{i,a}) =
           ( comment(Annotations.toString a);
              nl();
              emitInstr i )
        | emitInstr(I.LIVE{regs, spilled})  = 
            comment("live= " ^ CellsBasis.CellSet.toString regs ^
                    "spilled= " ^ CellsBasis.CellSet.toString spilled)
        | emitInstr(I.KILL{regs, spilled})  = 
            comment("killed:: " ^ CellsBasis.CellSet.toString regs ^
                    "spilled:: " ^ CellsBasis.CellSet.toString spilled)
        | emitInstr(I.INSTR i) = emitter i
        | emitInstr(I.COPY{k=CellsBasis.GP, sz, src, dst, tmp}) =
           emitInstrs(Shuffle.shuffle{tmp=tmp, src=src, dst=dst})
        | emitInstr(I.COPY{k=CellsBasis.FP, sz, src, dst, tmp}) =
           emitInstrs(Shuffle.shufflefp{tmp=tmp, src=src, dst=dst})
        | emitInstr _ = error "emitInstr"
   
   in  S.STREAM{beginCluster=init,
                pseudoOp=pseudoOp,
                emit=emitInstr,
                endCluster=fail,
                defineLabel=defineLabel,
                entryLabel=entryLabel,
                comment=comment,
                exitBlock=doNothing,
                annotation=annotation,
                getAnnotations=getAnnotations
               }
   end
end

