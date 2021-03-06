signature MDL_PARSER_DRIVER =
sig
   structure Ast : MDL_AST

   exception ParseError

   val parse : string * TextIO.instream -> Ast.decl list
   val parseString : string -> Ast.decl list
   val load  : string -> Ast.decl list

end

functor MDLParserDriver
    (structure AstPP : MDL_AST_PRETTY_PRINTER
     val MDLmode     : bool
     val extraCells  : AstPP.Ast.storagedecl list
    ) : MDL_PARSER_DRIVER =
struct

   structure Ast = AstPP.Ast
   structure Error = MDLError
   structure LrVals = MDLParser(structure Token = LrParser.Token
                                structure AstPP = AstPP
                               )
   structure Lex = MDLLexFun(LrVals.Tokens)
   structure Parser = JoinWithArg(structure ParserData = LrVals.ParserData
                                  structure Lex = Lex
                                  structure LrParser = LrParser
                                 )
   open PrecedenceParser


   val defaultPrec = 
       foldr (fn ((id,fixity),S) => declare(S,id,fixity)) empty
        [("+",INFIX 5),
         ("-",INFIX 5),
         ("*",INFIX 6),
         ("div",INFIX 6),
         ("mod",INFIX 6),
         ("=",INFIX 3),
         ("==",INFIX 3),
         (">",INFIX 3),
         ("<",INFIX 3),
         ("<=",INFIX 3),
         (">=",INFIX 3),
         ("<>",INFIX 3),
         ("<<",INFIX 4),
         (">>",INFIX 4),
         ("~>>",INFIX 4),
         ("&&",INFIX 5),
         ("^^",INFIX 5),
         ("^",INFIX 5),
         ("||",INFIX 4),
         (":=",INFIX 2),
         ("andalso",INFIX 1),
         ("orelse",INFIX 0),
         ("::",INFIXR 5),
         ("@",INFIXR 5)
        ]

   exception ParseError

   fun parseIt(filename,stream)=
   let val _     = Lex.UserDeclarations.init ()
       val srcMap = SourceMap.newmap{srcFile=filename}
       fun err(a,b,msg) = 
       let val loc = SourceMap.location srcMap (a,b)
       in  Error.setLoc loc; Error.error(msg) end
       fun input n = TextIO.inputN(stream,n)
       val lexArg = {srcMap=srcMap, err=err, MDLmode=MDLmode}
       val lexer = Parser.Stream.streamify(Lex.makeLexer input lexArg)
       fun parseError(msg,a,b) = err(a,b,msg)
       val (result,lexer) = 
             Parser.parse(15,lexer,parseError,
               (srcMap,Error.errorPos,import,ref defaultPrec,extraCells))
   in  if !Error.errorCount > 0 then raise ParseError else result end

   and loadIt filename =
   let val stream = TextIO.openIn filename
   in  parseIt(filename,stream) before TextIO.closeIn stream 
          handle e => (TextIO.closeIn stream; raise e)
   end handle IO.Io{function,name,cause,...} => 
       (
        Error.error(function^" failed in \""^name^"\" ("^exnName cause^")");
        raise ParseError)

   and import (loc,filename) = (Error.setLoc loc; loadIt filename)

   fun parse x = (Error.init(); parseIt x)
   fun load x = (Error.init(); loadIt x)
   fun parseString s = parse("???",TextIO.openString s)

end
