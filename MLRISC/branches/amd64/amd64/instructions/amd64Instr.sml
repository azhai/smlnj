(*
 * WARNING: This file was automatically generated by MDLGen (v3.1)
 * from the machine description file "amd64/amd64.mdl".
 * DO NOT EDIT this file directly
 *)


signature AMD64INSTR =
sig
   structure C : AMD64CELLS
   structure CB : CELLS_BASIS = CellsBasis
   structure T : MLTREE
   structure Constant: CONSTANT
   structure Region : REGION
      sharing Constant = T.Constant
      sharing Region = T.Region
   datatype operand =
     Immed of Int32.int
   | Immed64 of Int64.int
   | ImmedLabel of T.labexp
   | Relative of int
   | LabelEA of T.labexp
   | Direct of int * (CellsBasis.cell)
   | FDirect of CellsBasis.cell
   | Displace of {base:CellsBasis.cell, disp:operand, mem:Region.region}
   | Indexed of {base:(CellsBasis.cell) option, index:CellsBasis.cell, scale:int, 
        disp:operand, mem:Region.region}
   type addressing_mode = operand
   type ea = operand
   datatype cond =
     EQ
   | NE
   | LT
   | LE
   | GT
   | GE
   | B
   | BE
   | A
   | AE
   | C
   | NC
   | P
   | NP
   | O
   | NO
   datatype binaryOp =
     ADD_Q
   | SUB_Q
   | AND_Q
   | OR_Q
   | XOR_Q
   | SHL_Q
   | SAR_Q
   | SHR_Q
   | MUL_Q
   | IMUL_Q
   | ADC_Q
   | SBB_Q
   | ADD_L
   | SUB_L
   | AND_L
   | OR_L
   | XOR_L
   | SHL_L
   | SAR_L
   | SHR_L
   | MUL_L
   | IMUL_L
   | ADC_L
   | SBB_L
   | ADD_W
   | SUB_W
   | AND_W
   | OR_W
   | XOR_W
   | SHL_W
   | SAR_W
   | SHR_W
   | MUL_W
   | IMUL_W
   | ADD_B
   | SUB_B
   | AND_B
   | OR_B
   | XOR_B
   | SHL_B
   | SAR_B
   | SHR_B
   | MUL_B
   | IMUL_B
   | BT_Q
   | BT_L
   | BT_W
   | BTC_Q
   | BTC_L
   | BTC_W
   | BTR_Q
   | BTR_L
   | BTR_W
   | BTS_Q
   | BTS_L
   | BTS_W
   | ROL_W
   | ROR_W
   | ROL_L
   | ROR_L
   | XCHG_B
   | XCHG_W
   | XCHG_L
   | LOCK_ADC_W
   | LOCK_ADC_L
   | LOCK_ADD_W
   | LOCK_ADD_L
   | LOCK_AND_W
   | LOCK_AND_L
   | LOCK_BTS_W
   | LOCK_BTS_L
   | LOCK_BTR_W
   | LOCK_BTR_L
   | LOCK_BTC_W
   | LOCK_BTC_L
   | LOCK_OR_W
   | LOCK_OR_L
   | LOCK_SBB_W
   | LOCK_SBB_L
   | LOCK_SUB_W
   | LOCK_SUB_L
   | LOCK_XOR_W
   | LOCK_XOR_L
   | LOCK_XADD_B
   | LOCK_XADD_W
   | LOCK_XADD_L
   datatype multDivOp =
     IMULL1
   | MULL1
   | IDIVL1
   | DIVL1
   | IMULQ1
   | MULQ1
   | IDIVQ1
   | DIVQ1
   datatype unaryOp =
     DEC_Q
   | INC_Q
   | NEG_Q
   | NOT_Q
   | DEC_L
   | INC_L
   | NEG_L
   | NOT_L
   | DEC_W
   | INC_W
   | NEG_W
   | NOT_W
   | DEC_B
   | INC_B
   | NEG_B
   | NOT_B
   | LOCK_DEC_Q
   | LOCK_INC_Q
   | LOCK_NEG_Q
   | LOCK_NOT_Q
   datatype shiftOp =
     SHLD_L
   | SHRD_L
   datatype bitOp =
     BT_Q
   | BT_L
   | BT_W
   | LOCK_BT_L
   | LOCK_BT_W
   datatype move =
     MOV_Q
   | MOV_L
   | MOV_B
   | MOV_W
   | MOVABS_Q
   | MOVSW_Q
   | MOVZW_Q
   | MOVSW_L
   | MOVZW_L
   | MOVSB_Q
   | MOVZB_Q
   | MOVSB_L
   | MOVZB_L
   | MOVSL_Q
   | CVTSD2SI
   | CVTSS2SI
   | CVTSD2SIQ
   | CVTSS2SIQ
   datatype fbin_op =
     ADDS_S
   | ADDS_D
   | SUBS_S
   | SUBS_D
   | MULS_S
   | MULS_D
   | DIVS_S
   | DIVS_D
   | XORP_S
   | XORP_D
   | ANDP_S
   | ANDP_D
   | ORP_S
   | ORP_D
   datatype fcom_op =
     COMIS_S
   | COMIS_D
   | UCOMIS_S
   | UCOMIS_D
   datatype fmove_op =
     MOVS_S
   | MOVS_D
   | CVTSS2SD
   | CVTSD2SS
   | CVTSI2SS
   | CVTSI2SSQ
   | CVTSI2SD
   | CVTSI2SDQ
   datatype fsize =
     FP32
   | FP64
   datatype isize =
     I8
   | I16
   | I32
   | I64
   datatype instr =
     NOP
   | JMP of operand * Label.label list
   | JCC of {cond:cond, opnd:operand}
   | CAL_L of {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
        cutsTo:Label.label list, mem:Region.region, pops:Int32.int}
   | CALL_Q of {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
        cutsTo:Label.label list, mem:Region.region, pops:Int32.int}
   | ENTER of {src1:operand, src2:operand}
   | LEAVE
   | RET of operand option
   | MOVE of {mvOp:move, src:operand, dst:operand}
   | LEA_L of {r32:CellsBasis.cell, addr:operand}
   | LEA_Q of {r64:CellsBasis.cell, addr:operand}
   | CMP_Q of {lsrc:operand, rsrc:operand}
   | CMP_L of {lsrc:operand, rsrc:operand}
   | CMP_W of {lsrc:operand, rsrc:operand}
   | CMP_B of {lsrc:operand, rsrc:operand}
   | TEST_Q of {lsrc:operand, rsrc:operand}
   | TEST_L of {lsrc:operand, rsrc:operand}
   | TEST_W of {lsrc:operand, rsrc:operand}
   | TEST_B of {lsrc:operand, rsrc:operand}
   | BITOP of {bitOp:bitOp, lsrc:operand, rsrc:operand}
   | BINARY of {binOp:binaryOp, src:operand, dst:operand}
   | SHIFT of {shiftOp:shiftOp, src:operand, dst:operand, count:operand}
   | MULTDIV of {multDivOp:multDivOp, src:operand}
   | MUL3 of {dst:CellsBasis.cell, src2:Int32.int, src1:operand}
   | MULQ3 of {dst:CellsBasis.cell, src2:Int32.int, src1:operand}
   | UNARY of {unOp:unaryOp, opnd:operand}
   | SET of {cond:cond, opnd:operand}
   | CMOV of {cond:cond, src:operand, dst:CellsBasis.cell}
   | PUSH_Q of operand
   | PUSH_L of operand
   | PUSH_W of operand
   | PUSH_B of operand
   | PUSHFD
   | POPFD
   | POP of operand
   | CD_Q
   | CLTD
   | CQTO
   | INTO
   | FMOVE of {fmvOp:fmove_op, dst:operand, src:operand}
   | FBINOP of {binOp:fbin_op, dst:CellsBasis.cell, src:operand}
   | FCOM of {comOp:fcom_op, dst:CellsBasis.cell, src:operand}
   | FSQRTS of {dst:operand, src:operand}
   | FSQRTD of {dst:operand, src:operand}
   | SAHF
   | LFENCE
   | MFENCE
   | SFENCE
   | PAUSE
   | XCHG of {lock:bool, sz:isize, src:operand, dst:operand}
   | CMPXCHG of {lock:bool, sz:isize, src:operand, dst:operand}
   | XADD of {lock:bool, sz:isize, src:operand, dst:operand}
   | RDTSC
   | RDTSCP
   | LAHF
   | SOURCE of {}
   | SINK of {}
   | PHI of {}
   and instruction =
     LIVE of {regs: C.cellset, spilled: C.cellset}
   | KILL of {regs: C.cellset, spilled: C.cellset}
   | COPY of {k: CellsBasis.cellkind, 
              sz: int,          (* in bits *)
              dst: CellsBasis.cell list,
              src: CellsBasis.cell list,
              tmp: ea option (* NONE if |dst| = {src| = 1 *)}
   | ANNOTATION of {i:instruction, a:Annotations.annotation}
   | INSTR of instr
   val nop : instruction
   val jmp : operand * Label.label list -> instruction
   val jcc : {cond:cond, opnd:operand} -> instruction
   val cal_l : {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
      cutsTo:Label.label list, mem:Region.region, pops:Int32.int} -> instruction
   val call_q : {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
      cutsTo:Label.label list, mem:Region.region, pops:Int32.int} -> instruction
   val enter : {src1:operand, src2:operand} -> instruction
   val leave : instruction
   val ret : operand option -> instruction
   val move : {mvOp:move, src:operand, dst:operand} -> instruction
   val lea_l : {r32:CellsBasis.cell, addr:operand} -> instruction
   val lea_q : {r64:CellsBasis.cell, addr:operand} -> instruction
   val cmp_q : {lsrc:operand, rsrc:operand} -> instruction
   val cmp_l : {lsrc:operand, rsrc:operand} -> instruction
   val cmp_w : {lsrc:operand, rsrc:operand} -> instruction
   val cmp_b : {lsrc:operand, rsrc:operand} -> instruction
   val test_q : {lsrc:operand, rsrc:operand} -> instruction
   val test_l : {lsrc:operand, rsrc:operand} -> instruction
   val test_w : {lsrc:operand, rsrc:operand} -> instruction
   val test_b : {lsrc:operand, rsrc:operand} -> instruction
   val bitop : {bitOp:bitOp, lsrc:operand, rsrc:operand} -> instruction
   val binary : {binOp:binaryOp, src:operand, dst:operand} -> instruction
   val shift : {shiftOp:shiftOp, src:operand, dst:operand, count:operand} -> instruction
   val multdiv : {multDivOp:multDivOp, src:operand} -> instruction
   val mul3 : {dst:CellsBasis.cell, src2:Int32.int, src1:operand} -> instruction
   val mulq3 : {dst:CellsBasis.cell, src2:Int32.int, src1:operand} -> instruction
   val unary : {unOp:unaryOp, opnd:operand} -> instruction
   val set : {cond:cond, opnd:operand} -> instruction
   val cmov : {cond:cond, src:operand, dst:CellsBasis.cell} -> instruction
   val push_q : operand -> instruction
   val push_l : operand -> instruction
   val push_w : operand -> instruction
   val push_b : operand -> instruction
   val pushfd : instruction
   val popfd : instruction
   val pop : operand -> instruction
   val cd_q : instruction
   val cltd : instruction
   val cqto : instruction
   val into : instruction
   val fmove : {fmvOp:fmove_op, dst:operand, src:operand} -> instruction
   val fbinop : {binOp:fbin_op, dst:CellsBasis.cell, src:operand} -> instruction
   val fcom : {comOp:fcom_op, dst:CellsBasis.cell, src:operand} -> instruction
   val fsqrts : {dst:operand, src:operand} -> instruction
   val fsqrtd : {dst:operand, src:operand} -> instruction
   val sahf : instruction
   val lfence : instruction
   val mfence : instruction
   val sfence : instruction
   val pause : instruction
   val xchg : {lock:bool, sz:isize, src:operand, dst:operand} -> instruction
   val cmpxchg : {lock:bool, sz:isize, src:operand, dst:operand} -> instruction
   val xadd : {lock:bool, sz:isize, src:operand, dst:operand} -> instruction
   val rdtsc : instruction
   val rdtscp : instruction
   val lahf : instruction
   val source : {} -> instruction
   val sink : {} -> instruction
   val phi : {} -> instruction
end

functor AMD64Instr(T: MLTREE
                  ) : AMD64INSTR =
struct
   structure C = AMD64Cells
   structure CB = CellsBasis
   structure T = T
   structure Region = T.Region
   structure Constant = T.Constant
   datatype operand =
     Immed of Int32.int
   | Immed64 of Int64.int
   | ImmedLabel of T.labexp
   | Relative of int
   | LabelEA of T.labexp
   | Direct of int * (CellsBasis.cell)
   | FDirect of CellsBasis.cell
   | Displace of {base:CellsBasis.cell, disp:operand, mem:Region.region}
   | Indexed of {base:(CellsBasis.cell) option, index:CellsBasis.cell, scale:int, 
        disp:operand, mem:Region.region}
   type addressing_mode = operand
   type ea = operand
   datatype cond =
     EQ
   | NE
   | LT
   | LE
   | GT
   | GE
   | B
   | BE
   | A
   | AE
   | C
   | NC
   | P
   | NP
   | O
   | NO
   datatype binaryOp =
     ADD_Q
   | SUB_Q
   | AND_Q
   | OR_Q
   | XOR_Q
   | SHL_Q
   | SAR_Q
   | SHR_Q
   | MUL_Q
   | IMUL_Q
   | ADC_Q
   | SBB_Q
   | ADD_L
   | SUB_L
   | AND_L
   | OR_L
   | XOR_L
   | SHL_L
   | SAR_L
   | SHR_L
   | MUL_L
   | IMUL_L
   | ADC_L
   | SBB_L
   | ADD_W
   | SUB_W
   | AND_W
   | OR_W
   | XOR_W
   | SHL_W
   | SAR_W
   | SHR_W
   | MUL_W
   | IMUL_W
   | ADD_B
   | SUB_B
   | AND_B
   | OR_B
   | XOR_B
   | SHL_B
   | SAR_B
   | SHR_B
   | MUL_B
   | IMUL_B
   | BT_Q
   | BT_L
   | BT_W
   | BTC_Q
   | BTC_L
   | BTC_W
   | BTR_Q
   | BTR_L
   | BTR_W
   | BTS_Q
   | BTS_L
   | BTS_W
   | ROL_W
   | ROR_W
   | ROL_L
   | ROR_L
   | XCHG_B
   | XCHG_W
   | XCHG_L
   | LOCK_ADC_W
   | LOCK_ADC_L
   | LOCK_ADD_W
   | LOCK_ADD_L
   | LOCK_AND_W
   | LOCK_AND_L
   | LOCK_BTS_W
   | LOCK_BTS_L
   | LOCK_BTR_W
   | LOCK_BTR_L
   | LOCK_BTC_W
   | LOCK_BTC_L
   | LOCK_OR_W
   | LOCK_OR_L
   | LOCK_SBB_W
   | LOCK_SBB_L
   | LOCK_SUB_W
   | LOCK_SUB_L
   | LOCK_XOR_W
   | LOCK_XOR_L
   | LOCK_XADD_B
   | LOCK_XADD_W
   | LOCK_XADD_L
   datatype multDivOp =
     IMULL1
   | MULL1
   | IDIVL1
   | DIVL1
   | IMULQ1
   | MULQ1
   | IDIVQ1
   | DIVQ1
   datatype unaryOp =
     DEC_Q
   | INC_Q
   | NEG_Q
   | NOT_Q
   | DEC_L
   | INC_L
   | NEG_L
   | NOT_L
   | DEC_W
   | INC_W
   | NEG_W
   | NOT_W
   | DEC_B
   | INC_B
   | NEG_B
   | NOT_B
   | LOCK_DEC_Q
   | LOCK_INC_Q
   | LOCK_NEG_Q
   | LOCK_NOT_Q
   datatype shiftOp =
     SHLD_L
   | SHRD_L
   datatype bitOp =
     BT_Q
   | BT_L
   | BT_W
   | LOCK_BT_L
   | LOCK_BT_W
   datatype move =
     MOV_Q
   | MOV_L
   | MOV_B
   | MOV_W
   | MOVABS_Q
   | MOVSW_Q
   | MOVZW_Q
   | MOVSW_L
   | MOVZW_L
   | MOVSB_Q
   | MOVZB_Q
   | MOVSB_L
   | MOVZB_L
   | MOVSL_Q
   | CVTSD2SI
   | CVTSS2SI
   | CVTSD2SIQ
   | CVTSS2SIQ
   datatype fbin_op =
     ADDS_S
   | ADDS_D
   | SUBS_S
   | SUBS_D
   | MULS_S
   | MULS_D
   | DIVS_S
   | DIVS_D
   | XORP_S
   | XORP_D
   | ANDP_S
   | ANDP_D
   | ORP_S
   | ORP_D
   datatype fcom_op =
     COMIS_S
   | COMIS_D
   | UCOMIS_S
   | UCOMIS_D
   datatype fmove_op =
     MOVS_S
   | MOVS_D
   | CVTSS2SD
   | CVTSD2SS
   | CVTSI2SS
   | CVTSI2SSQ
   | CVTSI2SD
   | CVTSI2SDQ
   datatype fsize =
     FP32
   | FP64
   datatype isize =
     I8
   | I16
   | I32
   | I64
   datatype instr =
     NOP
   | JMP of operand * Label.label list
   | JCC of {cond:cond, opnd:operand}
   | CAL_L of {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
        cutsTo:Label.label list, mem:Region.region, pops:Int32.int}
   | CALL_Q of {opnd:operand, defs:C.cellset, uses:C.cellset, return:C.cellset, 
        cutsTo:Label.label list, mem:Region.region, pops:Int32.int}
   | ENTER of {src1:operand, src2:operand}
   | LEAVE
   | RET of operand option
   | MOVE of {mvOp:move, src:operand, dst:operand}
   | LEA_L of {r32:CellsBasis.cell, addr:operand}
   | LEA_Q of {r64:CellsBasis.cell, addr:operand}
   | CMP_Q of {lsrc:operand, rsrc:operand}
   | CMP_L of {lsrc:operand, rsrc:operand}
   | CMP_W of {lsrc:operand, rsrc:operand}
   | CMP_B of {lsrc:operand, rsrc:operand}
   | TEST_Q of {lsrc:operand, rsrc:operand}
   | TEST_L of {lsrc:operand, rsrc:operand}
   | TEST_W of {lsrc:operand, rsrc:operand}
   | TEST_B of {lsrc:operand, rsrc:operand}
   | BITOP of {bitOp:bitOp, lsrc:operand, rsrc:operand}
   | BINARY of {binOp:binaryOp, src:operand, dst:operand}
   | SHIFT of {shiftOp:shiftOp, src:operand, dst:operand, count:operand}
   | MULTDIV of {multDivOp:multDivOp, src:operand}
   | MUL3 of {dst:CellsBasis.cell, src2:Int32.int, src1:operand}
   | MULQ3 of {dst:CellsBasis.cell, src2:Int32.int, src1:operand}
   | UNARY of {unOp:unaryOp, opnd:operand}
   | SET of {cond:cond, opnd:operand}
   | CMOV of {cond:cond, src:operand, dst:CellsBasis.cell}
   | PUSH_Q of operand
   | PUSH_L of operand
   | PUSH_W of operand
   | PUSH_B of operand
   | PUSHFD
   | POPFD
   | POP of operand
   | CD_Q
   | CLTD
   | CQTO
   | INTO
   | FMOVE of {fmvOp:fmove_op, dst:operand, src:operand}
   | FBINOP of {binOp:fbin_op, dst:CellsBasis.cell, src:operand}
   | FCOM of {comOp:fcom_op, dst:CellsBasis.cell, src:operand}
   | FSQRTS of {dst:operand, src:operand}
   | FSQRTD of {dst:operand, src:operand}
   | SAHF
   | LFENCE
   | MFENCE
   | SFENCE
   | PAUSE
   | XCHG of {lock:bool, sz:isize, src:operand, dst:operand}
   | CMPXCHG of {lock:bool, sz:isize, src:operand, dst:operand}
   | XADD of {lock:bool, sz:isize, src:operand, dst:operand}
   | RDTSC
   | RDTSCP
   | LAHF
   | SOURCE of {}
   | SINK of {}
   | PHI of {}
   and instruction =
     LIVE of {regs: C.cellset, spilled: C.cellset}
   | KILL of {regs: C.cellset, spilled: C.cellset}
   | COPY of {k: CellsBasis.cellkind, 
              sz: int,          (* in bits *)
              dst: CellsBasis.cell list,
              src: CellsBasis.cell list,
              tmp: ea option (* NONE if |dst| = {src| = 1 *)}
   | ANNOTATION of {i:instruction, a:Annotations.annotation}
   | INSTR of instr
   val nop = INSTR NOP
   and jmp = INSTR o JMP
   and jcc = INSTR o JCC
   and cal_l = INSTR o CAL_L
   and call_q = INSTR o CALL_Q
   and enter = INSTR o ENTER
   and leave = INSTR LEAVE
   and ret = INSTR o RET
   and move = INSTR o MOVE
   and lea_l = INSTR o LEA_L
   and lea_q = INSTR o LEA_Q
   and cmp_q = INSTR o CMP_Q
   and cmp_l = INSTR o CMP_L
   and cmp_w = INSTR o CMP_W
   and cmp_b = INSTR o CMP_B
   and test_q = INSTR o TEST_Q
   and test_l = INSTR o TEST_L
   and test_w = INSTR o TEST_W
   and test_b = INSTR o TEST_B
   and bitop = INSTR o BITOP
   and binary = INSTR o BINARY
   and shift = INSTR o SHIFT
   and multdiv = INSTR o MULTDIV
   and mul3 = INSTR o MUL3
   and mulq3 = INSTR o MULQ3
   and unary = INSTR o UNARY
   and set = INSTR o SET
   and cmov = INSTR o CMOV
   and push_q = INSTR o PUSH_Q
   and push_l = INSTR o PUSH_L
   and push_w = INSTR o PUSH_W
   and push_b = INSTR o PUSH_B
   and pushfd = INSTR PUSHFD
   and popfd = INSTR POPFD
   and pop = INSTR o POP
   and cd_q = INSTR CD_Q
   and cltd = INSTR CLTD
   and cqto = INSTR CQTO
   and into = INSTR INTO
   and fmove = INSTR o FMOVE
   and fbinop = INSTR o FBINOP
   and fcom = INSTR o FCOM
   and fsqrts = INSTR o FSQRTS
   and fsqrtd = INSTR o FSQRTD
   and sahf = INSTR SAHF
   and lfence = INSTR LFENCE
   and mfence = INSTR MFENCE
   and sfence = INSTR SFENCE
   and pause = INSTR PAUSE
   and xchg = INSTR o XCHG
   and cmpxchg = INSTR o CMPXCHG
   and xadd = INSTR o XADD
   and rdtsc = INSTR RDTSC
   and rdtscp = INSTR RDTSCP
   and lahf = INSTR LAHF
   and source = INSTR o SOURCE
   and sink = INSTR o SINK
   and phi = INSTR o PHI
end

