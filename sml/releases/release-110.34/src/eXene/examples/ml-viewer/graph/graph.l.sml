functor GraphLexFun(structure Tokens : Graph_TOKENS)=
   struct
    structure UserDeclarations =
      struct
type pos = int
type svalue = Tokens.svalue
type ('a,'b) token = ('a,'b) Tokens.token
type lexresult = (svalue,pos) token

type lexstate = {
       lineNum : int ref,
       stringstart : int ref,
       commentState : int option ref,
       charlist : string list ref
     }
type arg = lexstate
       
fun complain msg = print ("lexer: "^msg^"\n")
fun mkSymbol (s,i) = Tokens.SYMBOL(s,i,i+(size s))
fun addString (charlist,s:string) = charlist := s :: (!charlist)
fun makeString charlist = (concat(rev(!charlist)) before charlist := [])

local open Format in
fun eof ({lineNum,stringstart,commentState,charlist}:lexstate) = (
      case !commentState of
        SOME l => formatf "warning: non-terminated comment in line %d\n"
                    (outputc std_err) [INT l]
      | _ => ();
      Tokens.EOF(0,0)
    )
end

end (* end of user routines *)
exception LexError (* raised if illegal leaf action tried *)
structure Internal =
	struct

datatype yyfinstate = N of int
type statedata = {fin : yyfinstate list, trans: string}
(* transition & final state table *)
val tab = let
val s0 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s1 =
"\010\010\010\010\010\010\010\010\010\070\072\010\010\010\010\010\
\\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\
\\070\010\069\010\010\010\010\010\068\067\010\010\066\062\061\058\
\\054\054\054\054\054\054\054\054\054\054\053\052\010\051\010\010\
\\050\013\013\013\013\013\013\013\013\013\013\013\013\013\013\013\
\\013\013\013\013\013\013\013\013\013\013\013\049\010\048\010\013\
\\010\013\013\013\041\037\013\032\013\013\013\013\013\013\028\013\
\\013\013\013\015\013\013\013\013\013\013\013\012\010\011\010\010\
\\009"
val s3 =
"\073\073\073\073\073\073\073\073\073\073\079\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\078\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\074\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073"
val s5 =
"\080\080\080\080\080\080\080\080\080\080\083\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\081\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\080\
\\080"
val s7 =
"\084\084\084\084\084\084\084\084\084\084\085\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\084\
\\084"
val s13 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s15 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\023\016\014\014\014\014\014\000\000\000\000\000\
\\000"
val s16 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\017\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s17 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\018\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s18 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\019\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s19 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\020\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s20 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\021\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s21 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\022\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s23 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\024\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s24 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\025\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s25 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\026\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s26 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\027\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s28 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\029\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s29 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\030\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s30 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\031\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s32 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\033\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s33 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\034\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s34 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\035\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s35 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\036\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s37 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\038\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s38 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\039\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s39 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\040\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s41 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\042\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s42 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\043\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s43 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\044\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s44 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\045\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s45 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\046\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s46 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\000\
\\000\014\014\014\014\014\014\014\014\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\014\
\\000\014\014\014\014\014\014\014\047\014\014\014\014\014\014\014\
\\014\014\014\014\014\014\014\014\014\014\014\000\000\000\000\000\
\\000"
val s54 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\056\000\
\\055\055\055\055\055\055\055\055\055\055\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s56 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\057\057\057\057\057\057\057\057\057\057\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s58 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\060\000\000\000\000\059\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s62 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\065\064\000\
\\055\055\055\055\055\055\055\055\055\055\000\000\000\000\063\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s70 =
"\000\000\000\000\000\000\000\000\000\071\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\071\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s73 =
"\073\073\073\073\073\073\073\073\073\073\000\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\000\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\000\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\073\
\\073"
val s74 =
"\000\000\000\000\000\000\000\000\000\000\077\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\076\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\075\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
val s81 =
"\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\082\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
\\000"
in Vector.vector
[{fin = [], trans = s0},
{fin = [], trans = s1},
{fin = [], trans = s1},
{fin = [(N 118)], trans = s3},
{fin = [(N 118)], trans = s3},
{fin = [], trans = s5},
{fin = [], trans = s5},
{fin = [], trans = s7},
{fin = [], trans = s7},
{fin = [(N 99),(N 101)], trans = s0},
{fin = [(N 101)], trans = s0},
{fin = [(N 24),(N 101)], trans = s0},
{fin = [(N 30),(N 101)], trans = s0},
{fin = [(N 85),(N 101)], trans = s13},
{fin = [(N 85)], trans = s13},
{fin = [(N 85),(N 101)], trans = s15},
{fin = [(N 85)], trans = s16},
{fin = [(N 85)], trans = s17},
{fin = [(N 85)], trans = s18},
{fin = [(N 85)], trans = s19},
{fin = [(N 85)], trans = s20},
{fin = [(N 85)], trans = s21},
{fin = [(N 82),(N 85)], trans = s13},
{fin = [(N 85)], trans = s23},
{fin = [(N 85)], trans = s24},
{fin = [(N 85)], trans = s25},
{fin = [(N 85)], trans = s26},
{fin = [(N 59),(N 85)], trans = s13},
{fin = [(N 85),(N 101)], trans = s28},
{fin = [(N 85)], trans = s29},
{fin = [(N 85)], trans = s30},
{fin = [(N 52),(N 85)], trans = s13},
{fin = [(N 85),(N 101)], trans = s32},
{fin = [(N 85)], trans = s33},
{fin = [(N 85)], trans = s34},
{fin = [(N 85)], trans = s35},
{fin = [(N 65),(N 85)], trans = s13},
{fin = [(N 85),(N 101)], trans = s37},
{fin = [(N 85)], trans = s38},
{fin = [(N 85)], trans = s39},
{fin = [(N 47),(N 85)], trans = s13},
{fin = [(N 85),(N 101)], trans = s41},
{fin = [(N 85)], trans = s42},
{fin = [(N 85)], trans = s43},
{fin = [(N 85)], trans = s44},
{fin = [(N 85)], trans = s45},
{fin = [(N 85)], trans = s46},
{fin = [(N 73),(N 85)], trans = s13},
{fin = [(N 22),(N 101)], trans = s0},
{fin = [(N 28),(N 101)], trans = s0},
{fin = [(N 14),(N 101)], trans = s0},
{fin = [(N 18),(N 101)], trans = s0},
{fin = [(N 34),(N 101)], trans = s0},
{fin = [(N 36),(N 101)], trans = s0},
{fin = [(N 90),(N 101)], trans = s54},
{fin = [(N 90)], trans = s54},
{fin = [(N 90)], trans = s56},
{fin = [(N 97)], trans = s56},
{fin = [(N 101)], trans = s58},
{fin = [(N 12)], trans = s0},
{fin = [(N 9)], trans = s0},
{fin = [(N 16),(N 101)], trans = s56},
{fin = [(N 101)], trans = s62},
{fin = [(N 39)], trans = s0},
{fin = [], trans = s56},
{fin = [(N 42)], trans = s0},
{fin = [(N 32),(N 101)], trans = s0},
{fin = [(N 20),(N 101)], trans = s0},
{fin = [(N 26),(N 101)], trans = s0},
{fin = [(N 6),(N 101)], trans = s0},
{fin = [(N 4),(N 101)], trans = s70},
{fin = [(N 4)], trans = s70},
{fin = [(N 1)], trans = s0},
{fin = [(N 118)], trans = s73},
{fin = [(N 129)], trans = s74},
{fin = [(N 124)], trans = s0},
{fin = [(N 127)], trans = s0},
{fin = [(N 121)], trans = s0},
{fin = [(N 114)], trans = s0},
{fin = [(N 116)], trans = s0},
{fin = [(N 108)], trans = s0},
{fin = [(N 108)], trans = s81},
{fin = [(N 106)], trans = s0},
{fin = [(N 103)], trans = s0},
{fin = [(N 112)], trans = s0},
{fin = [(N 110)], trans = s0}]
end
structure StartStates =
	struct
	datatype yystartstate = STARTSTATE of int

(* start state definitions *)

val COM = STARTSTATE 5;
val EOLCOM = STARTSTATE 7;
val INITIAL = STARTSTATE 1;
val QS = STARTSTATE 3;

end
type result = UserDeclarations.lexresult
	exception LexerError (* raised if illegal leaf action tried *)
end

fun makeLexer yyinput = 
let 
	val yyb = ref "\n" 		(* buffer *)
	val yybl = ref 1		(*buffer length *)
	val yybufpos = ref 1		(* location of next character to use *)
	val yygone = ref 1		(* position in file of beginning of buffer *)
	val yydone = ref false		(* eof found yet? *)
	val yybegin = ref 1		(*Current 'start state' for lexer *)

	val YYBEGIN = fn (Internal.StartStates.STARTSTATE x) =>
		 yybegin := x

fun lex (yyarg as ({lineNum,stringstart,commentState,charlist})) =
let fun continue() : Internal.result = 
  let fun scan (s,AcceptingLeaves : Internal.yyfinstate list list,l,i0) =
	let fun action (i,nil) = raise LexError
	| action (i,nil::l) = action (i-1,l)
	| action (i,(node::acts)::l) =
		case node of
		    Internal.N yyk => 
			(let val yytext = substring(!yyb,i0,i-i0)
			     val yypos = i0+ !yygone
			open UserDeclarations Internal.StartStates
 in (yybufpos := i; case yyk of 

			(* Application actions *)

  1 => (inc lineNum; continue())
| 101 => (complain ("illegal token: "^(StringUtil.expandStr yytext));
                    	    continue())
| 103 => (inc lineNum; continue())
| 106 => (commentState := NONE; YYBEGIN INITIAL; continue())
| 108 => (continue())
| 110 => (inc lineNum; YYBEGIN INITIAL; continue())
| 112 => (continue())
| 114 => (YYBEGIN INITIAL; 
                            mkSymbol(makeString charlist,!stringstart))
| 116 => (complain "unclosed string";
			    YYBEGIN INITIAL;
                            mkSymbol(makeString charlist,!stringstart))
| 118 => (addString(charlist,yytext); continue())
| 12 => (YYBEGIN EOLCOM; 
                            continue())
| 121 => (continue())
| 124 => (addString(charlist,"\\\\"); continue())
| 127 => (addString(charlist,"\""); continue())
| 129 => (addString(charlist,"\\"); continue())
| 14 => (Tokens.AT(yypos,yypos+1))
| 16 => (Tokens.DOT(yypos,yypos+1))
| 18 => (Tokens.EQUAL(yypos,yypos+1))
| 20 => (Tokens.RPAREN(yypos,yypos+1))
| 22 => (Tokens.RBRACKET(yypos,yypos+1))
| 24 => (Tokens.RBRACE(yypos,yypos+1))
| 26 => (Tokens.LPAREN(yypos,yypos+1))
| 28 => (Tokens.LBRACKET(yypos,yypos+1))
| 30 => (Tokens.LBRACE(yypos,yypos+1))
| 32 => (Tokens.COMMA(yypos,yypos+1))
| 34 => (Tokens.SEMICOLON(yypos,yypos+1))
| 36 => (Tokens.COLON(yypos,yypos+1))
| 39 => (Tokens.EDGEOP(yypos,yypos+2))
| 4 => (continue())
| 42 => (Tokens.EDGEOP(yypos,yypos+2))
| 47 => (Tokens.EDGE(yypos,yypos+4))
| 52 => (Tokens.NODE(yypos,yypos+4))
| 59 => (Tokens.STRICT(yypos,yypos+6))
| 6 => (charlist := [];
                            stringstart := yypos;
                            YYBEGIN QS;
                            continue())
| 65 => (Tokens.GRAPH(yypos,yypos+5))
| 73 => (Tokens.DIGRAPH(yypos,yypos+7))
| 82 => (Tokens.SUBGRAPH(yypos,yypos+8))
| 85 => (mkSymbol(yytext,yypos))
| 9 => (commentState := SOME(!lineNum); 
                            YYBEGIN COM; 
                            continue())
| 90 => (mkSymbol(yytext,yypos))
| 97 => (mkSymbol(yytext,yypos))
| 99 => (complain "non-Ascii character";
                   	    continue())
| _ => raise Internal.LexerError

		) end )

	val {fin,trans} = Vector.sub(Internal.tab, s)
	val NewAcceptingLeaves = fin::AcceptingLeaves
	in if l = !yybl then
	     if trans = #trans(Vector.sub(Internal.tab,0))
	       then action(l,NewAcceptingLeaves
) else	    let val newchars= if !yydone then "" else yyinput 1024
	    in if (size newchars)=0
		  then (yydone := true;
		        if (l=i0) then UserDeclarations.eof yyarg
		                  else action(l,NewAcceptingLeaves))
		  else (if i0=l then yyb := newchars
		     else yyb := substring(!yyb,i0,l-i0)^newchars;
		     yygone := !yygone+i0;
		     yybl := size (!yyb);
		     scan (s,AcceptingLeaves,l-i0,0))
	    end
	  else let val NewChar = Char.ord(String.sub(!yyb,l))
		val NewState = if NewChar<128 then Char.ord(String.sub(trans,NewChar)) else Char.ord(String.sub(trans,128))
		in if NewState=0 then action(l,NewAcceptingLeaves)
		else scan(NewState,NewAcceptingLeaves,l+1,i0)
	end
	end
(*
	val start= if substring(!yyb,!yybufpos-1,1)="\n"
then !yybegin+1 else !yybegin
*)
	in scan(!yybegin (* start *),nil,!yybufpos,!yybufpos)
    end
in continue end
  in lex
  end
end
