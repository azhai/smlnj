(*
 * WARNING: This file was automatically generated by MDLGen (v3.0)
 * from the machine description file "ppc/ppc.mdl".
 * DO NOT EDIT this file directly
 *)


signature PPCINSTR =
sig
   structure C : PPCCELLS
   structure T : MLTREE
   structure LabelExp : LABELEXP
   structure Constant: CONSTANT
   structure Region : REGION
      sharing LabelExp.T = T
      sharing Constant = T.Constant
      sharing Region = T.Region
   type gpr = int
   type fpr = int
   type ccr = int
   type crf = int
   datatype spr =
     XER
   | LR
   | CTR
   datatype operand =
     RegOp of C.cell
   | ImmedOp of int
   | LabelOp of T.labexp
   type addressing_mode = (C.cell * operand)
   datatype ea =
     Direct of C.cell
   | FDirect of C.cell
   | Displace of {base:C.cell, disp:operand}
   datatype load =
     LBZ
   | LBZE
   | LHZ
   | LHZE
   | LHA
   | LHAE
   | LWZ
   | LWZE
   | LDE
   datatype store =
     STB
   | STBE
   | STH
   | STHE
   | STW
   | STWE
   | STDE
   datatype fload =
     LFS
   | LFSE
   | LFD
   | LFDE
   datatype fstore =
     STFS
   | STFSE
   | STFD
   | STFDE
   datatype cmp =
     CMP
   | CMPL
   datatype fcmp =
     FCMPO
   | FCMPU
   datatype unary =
     NEG
   | EXTSB
   | EXTSH
   | EXTSW
   | CNTLZW
   | CNTLZD
   datatype funary =
     FMR
   | FNEG
   | FABS
   | FNABS
   | FSQRT
   | FSQRTS
   | FRSP
   | FCTIW
   | FCTIWZ
   | FCTID
   | FCTIDZ
   | FCFID
   datatype farith =
     FADD
   | FSUB
   | FMUL
   | FDIV
   | FADDS
   | FSUBS
   | FMULS
   | FDIVS
   datatype farith3 =
     FMADD
   | FMADDS
   | FMSUB
   | FMSUBS
   | FNMADD
   | FNMADDS
   | FNMSUB
   | FNMSUBS
   | FSEL
   datatype bo =
     TRUE
   | FALSE
   | ALWAYS
   | COUNTER of {eqZero:bool, cond:bool option}
   datatype arith =
     ADD
   | SUBF
   | MULLW
   | MULLD
   | MULHW
   | MULHWU
   | DIVW
   | DIVD
   | DIVWU
   | DIVDU
   | AND
   | OR
   | XOR
   | NAND
   | NOR
   | EQV
   | ANDC
   | ORC
   | SLW
   | SLD
   | SRW
   | SRD
   | SRAW
   | SRAD
   datatype arithi =
     ADDI
   | ADDIS
   | SUBFIC
   | MULLI
   | ANDI_Rc
   | ANDIS_Rc
   | ORI
   | ORIS
   | XORI
   | XORIS
   | SRAWI
   | SRADI
   datatype rotate =
     RLWNM
   | RLDCL
   | RLDCR
   datatype rotatei =
     RLWINM
   | RLWIMI
   | RLDICL
   | RLDICR
   | RLDIC
   | RLDIMI
   datatype ccarith =
     CRAND
   | CROR
   | CRXOR
   | CRNAND
   | CRNOR
   | CREQV
   | CRANDC
   | CRORC
   datatype bit =
     LT
   | GT
   | EQ
   | SO
   | FL
   | FG
   | FE
   | FU
   | FX
   | FEX
   | VX
   | OX
   datatype xerbit =
     SO64
   | OV64
   | CA64
   | SO32
   | OV32
   | CA32
   type cr_bit = (C.cell * bit)
   datatype instruction =
     L of {ld:load, rt:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | LF of {ld:fload, ft:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | ST of {st:store, rs:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | STF of {st:fstore, fs:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | UNARY of {oper:unary, rt:C.cell, ra:C.cell, Rc:bool, OE:bool}
   | ARITH of {oper:arith, rt:C.cell, ra:C.cell, rb:C.cell, Rc:bool, OE:bool}
   | ARITHI of {oper:arithi, rt:C.cell, ra:C.cell, im:operand}
   | ROTATE of {oper:rotate, ra:C.cell, rs:C.cell, sh:C.cell, mb:int, me:int option}
   | ROTATEI of {oper:rotatei, ra:C.cell, rs:C.cell, sh:operand, mb:int, me:int option}
   | COMPARE of {cmp:cmp, l:bool, bf:C.cell, ra:C.cell, rb:operand}
   | FCOMPARE of {cmp:fcmp, bf:C.cell, fa:C.cell, fb:C.cell}
   | FUNARY of {oper:funary, ft:C.cell, fb:C.cell, Rc:bool}
   | FARITH of {oper:farith, ft:C.cell, fa:C.cell, fb:C.cell, Rc:bool}
   | FARITH3 of {oper:farith3, ft:C.cell, fa:C.cell, fb:C.cell, fc:C.cell, 
        Rc:bool}
   | CCARITH of {oper:ccarith, bt:cr_bit, ba:cr_bit, bb:cr_bit}
   | MCRF of {bf:C.cell, bfa:C.cell}
   | MTSPR of {rs:C.cell, spr:C.cell}
   | MFSPR of {rt:C.cell, spr:C.cell}
   | TW of {to:int, ra:C.cell, si:operand}
   | TD of {to:int, ra:C.cell, si:operand}
   | BC of {bo:bo, bf:C.cell, bit:bit, addr:operand, LK:bool, fall:operand}
   | BCLR of {bo:bo, bf:C.cell, bit:bit, LK:bool, labels:Label.label list}
   | B of {addr:operand, LK:bool}
   | CALL of {def:C.cellset, use:C.cellset, cutsTo:Label.label list, mem:Region.region}
   | COPY of {dst:C.cell list, src:C.cell list, impl:instruction list option ref, 
        tmp:ea option}
   | FCOPY of {dst:C.cell list, src:C.cell list, impl:instruction list option ref, 
        tmp:ea option}
   | ANNOTATION of {i:instruction, a:Annotations.annotation}
   | SOURCE of {}
   | SINK of {}
   | PHI of {}
end

functor PPCInstr(LabelExp : LABELEXP
                ) : PPCINSTR =
struct
   structure C = PPCCells
   structure LabelExp = LabelExp
   structure T = LabelExp.T
   structure Region = T.Region
   structure Constant = T.Constant
   type gpr = int
   type fpr = int
   type ccr = int
   type crf = int
   datatype spr =
     XER
   | LR
   | CTR
   datatype operand =
     RegOp of C.cell
   | ImmedOp of int
   | LabelOp of T.labexp
   type addressing_mode = (C.cell * operand)
   datatype ea =
     Direct of C.cell
   | FDirect of C.cell
   | Displace of {base:C.cell, disp:operand}
   datatype load =
     LBZ
   | LBZE
   | LHZ
   | LHZE
   | LHA
   | LHAE
   | LWZ
   | LWZE
   | LDE
   datatype store =
     STB
   | STBE
   | STH
   | STHE
   | STW
   | STWE
   | STDE
   datatype fload =
     LFS
   | LFSE
   | LFD
   | LFDE
   datatype fstore =
     STFS
   | STFSE
   | STFD
   | STFDE
   datatype cmp =
     CMP
   | CMPL
   datatype fcmp =
     FCMPO
   | FCMPU
   datatype unary =
     NEG
   | EXTSB
   | EXTSH
   | EXTSW
   | CNTLZW
   | CNTLZD
   datatype funary =
     FMR
   | FNEG
   | FABS
   | FNABS
   | FSQRT
   | FSQRTS
   | FRSP
   | FCTIW
   | FCTIWZ
   | FCTID
   | FCTIDZ
   | FCFID
   datatype farith =
     FADD
   | FSUB
   | FMUL
   | FDIV
   | FADDS
   | FSUBS
   | FMULS
   | FDIVS
   datatype farith3 =
     FMADD
   | FMADDS
   | FMSUB
   | FMSUBS
   | FNMADD
   | FNMADDS
   | FNMSUB
   | FNMSUBS
   | FSEL
   datatype bo =
     TRUE
   | FALSE
   | ALWAYS
   | COUNTER of {eqZero:bool, cond:bool option}
   datatype arith =
     ADD
   | SUBF
   | MULLW
   | MULLD
   | MULHW
   | MULHWU
   | DIVW
   | DIVD
   | DIVWU
   | DIVDU
   | AND
   | OR
   | XOR
   | NAND
   | NOR
   | EQV
   | ANDC
   | ORC
   | SLW
   | SLD
   | SRW
   | SRD
   | SRAW
   | SRAD
   datatype arithi =
     ADDI
   | ADDIS
   | SUBFIC
   | MULLI
   | ANDI_Rc
   | ANDIS_Rc
   | ORI
   | ORIS
   | XORI
   | XORIS
   | SRAWI
   | SRADI
   datatype rotate =
     RLWNM
   | RLDCL
   | RLDCR
   datatype rotatei =
     RLWINM
   | RLWIMI
   | RLDICL
   | RLDICR
   | RLDIC
   | RLDIMI
   datatype ccarith =
     CRAND
   | CROR
   | CRXOR
   | CRNAND
   | CRNOR
   | CREQV
   | CRANDC
   | CRORC
   datatype bit =
     LT
   | GT
   | EQ
   | SO
   | FL
   | FG
   | FE
   | FU
   | FX
   | FEX
   | VX
   | OX
   datatype xerbit =
     SO64
   | OV64
   | CA64
   | SO32
   | OV32
   | CA32
   type cr_bit = (C.cell * bit)
   datatype instruction =
     L of {ld:load, rt:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | LF of {ld:fload, ft:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | ST of {st:store, rs:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | STF of {st:fstore, fs:C.cell, ra:C.cell, d:operand, mem:Region.region}
   | UNARY of {oper:unary, rt:C.cell, ra:C.cell, Rc:bool, OE:bool}
   | ARITH of {oper:arith, rt:C.cell, ra:C.cell, rb:C.cell, Rc:bool, OE:bool}
   | ARITHI of {oper:arithi, rt:C.cell, ra:C.cell, im:operand}
   | ROTATE of {oper:rotate, ra:C.cell, rs:C.cell, sh:C.cell, mb:int, me:int option}
   | ROTATEI of {oper:rotatei, ra:C.cell, rs:C.cell, sh:operand, mb:int, me:int option}
   | COMPARE of {cmp:cmp, l:bool, bf:C.cell, ra:C.cell, rb:operand}
   | FCOMPARE of {cmp:fcmp, bf:C.cell, fa:C.cell, fb:C.cell}
   | FUNARY of {oper:funary, ft:C.cell, fb:C.cell, Rc:bool}
   | FARITH of {oper:farith, ft:C.cell, fa:C.cell, fb:C.cell, Rc:bool}
   | FARITH3 of {oper:farith3, ft:C.cell, fa:C.cell, fb:C.cell, fc:C.cell, 
        Rc:bool}
   | CCARITH of {oper:ccarith, bt:cr_bit, ba:cr_bit, bb:cr_bit}
   | MCRF of {bf:C.cell, bfa:C.cell}
   | MTSPR of {rs:C.cell, spr:C.cell}
   | MFSPR of {rt:C.cell, spr:C.cell}
   | TW of {to:int, ra:C.cell, si:operand}
   | TD of {to:int, ra:C.cell, si:operand}
   | BC of {bo:bo, bf:C.cell, bit:bit, addr:operand, LK:bool, fall:operand}
   | BCLR of {bo:bo, bf:C.cell, bit:bit, LK:bool, labels:Label.label list}
   | B of {addr:operand, LK:bool}
   | CALL of {def:C.cellset, use:C.cellset, cutsTo:Label.label list, mem:Region.region}
   | COPY of {dst:C.cell list, src:C.cell list, impl:instruction list option ref, 
        tmp:ea option}
   | FCOPY of {dst:C.cell list, src:C.cell list, impl:instruction list option ref, 
        tmp:ea option}
   | ANNOTATION of {i:instruction, a:Annotations.annotation}
   | SOURCE of {}
   | SINK of {}
   | PHI of {}
end

