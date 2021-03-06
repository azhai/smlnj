(* labelExp.sml -- expressions involving labels
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)
signature LABELEXP = 
sig
  structure Constant : CONSTANT
  datatype labexp = 
      LABEL of Label.label
    | CONST of Constant.const
    | INT of int
    | PLUS of labexp * labexp
    | MINUS of labexp * labexp
    | MULT of labexp * labexp
    | DIV of labexp * labexp
    | LSHIFT of labexp * word
    | RSHIFT of labexp * word
    | AND of labexp * word
    | OR of labexp * word

  val valueOf : labexp -> int
  val toString : labexp -> string
  val hash    : labexp -> word
  val ==      : labexp * labexp -> bool
end

functor LabelExp(Constant : CONSTANT) = struct
  structure Constant = Constant
  datatype labexp = 
      LABEL of Label.label
    | CONST of Constant.const
    | INT of int
    | PLUS of labexp * labexp
    | MINUS of labexp * labexp
    | MULT of labexp * labexp
    | DIV of labexp * labexp
    | LSHIFT of labexp * word
    | RSHIFT of labexp * word
    | AND of labexp * word
    | OR of labexp * word

  val itow = Word.fromInt
  val wtoi = Word.toIntX

  val resolveConstants = MLRiscControl.getFlag "asm-resolve-constants"
  val _ = resolveConstants := true

  fun prInt i = if i < 0 then "-"^Int.toString(~i) else Int.toString i

  fun valueOf(LABEL lab) = Label.addrOf lab
    | valueOf(CONST c) = Constant.valueOf c
    | valueOf(INT i) = i
    | valueOf(PLUS(lexp1, lexp2)) = valueOf(lexp1) + valueOf(lexp2)
    | valueOf(MINUS(lexp1, lexp2)) = valueOf(lexp1) - valueOf(lexp2)
    | valueOf(MULT(lexp1, lexp2)) = valueOf(lexp1) * valueOf(lexp2)
    | valueOf(DIV(lexp1, lexp2)) = valueOf(lexp1) div valueOf(lexp2)
    | valueOf(LSHIFT(lexp, cnt)) = wtoi(Word.<<(wValueOf lexp, cnt))
    | valueOf(RSHIFT(lexp, cnt)) = wtoi(Word.>>(wValueOf lexp, cnt))
    | valueOf(AND(lexp, mask)) = wtoi(Word.andb(wValueOf lexp, mask))
    | valueOf(OR(lexp, mask)) = wtoi(Word.orb(wValueOf lexp, mask))

  and wValueOf lexp = itow(valueOf lexp)

  (* This module should be parameterised, in order to generate
   * target label expressions for assembly code purposes.
   *)
(* operator precedences:
   (Note: these differ from C's precedences)
                2 MULT, DIV, LSHIFT, RSHIFT
                1 AND, OR
                0 PLUS, MINUS
*)

  fun parens (str, prec, op_prec) = 
      if prec > op_prec then "(" ^ str ^ ")" else str

  and toString le = toStr(le, 0) 

  and toStr(LABEL lab, _) = Label.nameOf lab 
    | toStr(CONST c, _) = 
        if !resolveConstants then prInt(Constant.valueOf c)
        else Constant.toString c
    | toStr(INT i, _) = prInt i
    | toStr(MULT(lexp1, lexp2), _) = toStr(lexp1, 2) ^ "*" ^ toStr(lexp2,2)
    | toStr(DIV(lexp1, lexp2), _) =  toStr(lexp1, 2) ^ "/" ^ toStr(lexp2,2)
    | toStr(LSHIFT(lexp, cnt), prec) = toStr(lexp,2) ^ "<<" ^ Word.toString cnt
    | toStr(RSHIFT(lexp, cnt), prec) = toStr(lexp,2) ^ ">>" ^ Word.toString cnt
    | toStr(AND(lexp, mask), prec) = 
        parens(toStr(lexp,1) ^ "&" ^ Word.toString mask, prec, 1)
    | toStr(OR(lexp, mask), prec) = 
        parens(toStr(lexp, 1) ^ "|" ^ Word.toString mask, prec, 1)
    | toStr(PLUS(lexp1, lexp2), prec) = 
        parens(toStr(lexp1, 0) ^ "+" ^ toStr(lexp2, 0), prec, 0)
    | toStr(MINUS(lexp1, lexp2), prec) = 
        parens(toStr(lexp1, 0) ^ "-" ^ toStr(lexp2, 0), prec, 0)


  fun hash(LABEL(Label.Label{id,...})) = Word.fromInt id
    | hash(INT i) = Word.fromInt i
    | hash(CONST c) = Constant.hash c
    | hash(PLUS(a,b)) = hash a + hash b + 0w12311
    | hash(MINUS(a,b)) = 0w1232 + hash a + hash b + 0w8834
    | hash(MULT(a,b)) = 0w123123 + hash a + hash b + 0w1714
    | hash(DIV(a,b)) = hash a + hash b + 0w1999
    | hash(LSHIFT(a,c)) = hash a + c + 0w1333
    | hash(RSHIFT(a,c)) = hash a + c + 0w6788
    | hash(AND(a,m)) = hash a + m + 0w444
    | hash(OR(a,m)) = hash a + m + 0w777

  fun ==(LABEL(Label.Label{id=x,...}),LABEL(Label.Label{id=y,...})) = x = y
    | ==(INT i,INT j) = i = j
    | ==(CONST c,CONST c') = Constant.==(c,c')
    | ==(PLUS(a,b),PLUS(c,d)) = ==(a,b) andalso ==(c,d)
    | ==(MINUS(a,b),MINUS(c,d)) = ==(a,b) andalso ==(c,d)
    | ==(MULT(a,b),MULT(c,d)) = ==(a,b) andalso ==(c,d)
    | ==(DIV(a,b),DIV(c,d)) = ==(a,b) andalso ==(c,d)
    | ==(LSHIFT(a,b),LSHIFT(c,d)) = b = d andalso ==(a,c)
    | ==(RSHIFT(a,b),RSHIFT(c,d)) = b = d andalso ==(a,c)
    | ==(AND(a,b),AND(c,d)) = b = d andalso ==(a,c)
    | ==(OR(a,b),OR(c,d)) = b = d andalso ==(a,c)
    | == _ = false
end
