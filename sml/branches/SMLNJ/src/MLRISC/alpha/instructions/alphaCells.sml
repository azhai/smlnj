(*
 * This file was automatically generated by MDGen
 * from the machine description file "alpha/alpha.md".
 *)


signature ALPHACELLS =
sig
   datatype mycellkind =
     UNKNOWN
   | MEM
   | CTRL
   | CC
   | FP
   | GP
   withtype cellset = (int list * int list)
   include CELLS_BASIS where type cellkind = mycellkind
   val showCC : cell -> string
   val showFP : cell -> string
   val showGP : cell -> string
   val addGP : (cell * cellset) -> cellset
   val addFP : (cell * cellset) -> cellset
   val fasmTmp : cell
   val stackptrR : cell
   val asmTmpR : cell
   val zeroReg : cellkind -> cell option
   val toString : cellkind -> cell -> string
   val addCell : cellkind -> cell * cellset -> cellset
   val rmvCell : cellkind -> cell * cellset -> cellset
   val addReg : cell * cellset -> cellset
   val rmvReg : cell * cellset -> cellset
   val addFreg : cell * cellset -> cellset
   val rmvFreg : cell * cellset -> cellset
   val getCell : cellkind -> cellset -> cell list
   val updateCell : cellkind -> cellset * cell list -> cellset
   val empty : cellset
   val cellsetToString : cellset -> string
   val cellsetToString' : (cell -> cell) -> cellset -> string
   val cellsetToCells : cellset -> cell list
end

structure AlphaCells : ALPHACELLS =
struct
   datatype mycellkind =
     UNKNOWN
   | MEM
   | CTRL
   | CC
   | FP
   | GP
   withtype cellset = (int list * int list)
   exception AlphaCells
   structure SL = SortedList
   fun error msg = MLRiscErrorMsg.error("AlphaCells",msg)
   val cellkindToString = (fn CC => "CC"
                            | FP => "FP"
                            | GP => "GP"
                            | MEM => "MEM"
                            | CTRL => "CTRL"
                            | UNKNOWN => "UNKNOWN"
                          )
   structure MyCellsBasis = CellsBasisFn
      (type cellkind = mycellkind
       exception Cells = AlphaCells
       val unknown = UNKNOWN
       val cellkindToString = cellkindToString
       val INT = GP
       val FLOAT = FP
       val firstPseudo = 256
       val kinds = [CC, FP, GP, MEM, CTRL]
       val physical = [{from=64, to=0, kind=CC}, {from=32, to=63, kind=FP}, {from=0, to=31, kind=GP}]
      )

   open MyCellsBasis
   val offsetCC = 64
  and offsetFP = 32
  and offsetGP = 0
  and cellnames = ["CC", "FP", "GP"]
  and cellsetnames = ["GP", "FP"]
   val fasmTmp = (30 + offsetFP)
   val stackptrR = (30 + offsetGP)
   val asmTmpR = (28 + offsetGP)

   fun showCC r = let
          val r = (if (r <= 0)
                then (r - 64)
                else r)
       in ((fn _ => "cc"
           ) r)
       end

   and showFP r = let
          val r = (if (r <= 63)
                then (r - 32)
                else r)
       in ((fn f => ("$f" ^ (Int.toString f))
           ) r)
       end

   and showGP r = ((fn 30 => "$sp"
                     | r => ("$" ^ (Int.toString r))
                   ) r)
   and toString CC = showCC
     | toString FP = showFP
     | toString GP = showGP
     | toString MEM = (fn r => ("m" ^ (Int.toString r))
                      )
     | toString CTRL = (fn r => ("ctrl" ^ (Int.toString r))
                       )
     | toString UNKNOWN = (fn r => ("unknown" ^ (Int.toString r))
                          )
   val empty = ([], [])

   fun addCell GP = addGP
     | addCell FP = addFP
     | addCell CC = addGP
     | addCell _ = (error "addCell")
   and rmvCell GP = rmvGP
     | rmvCell FP = rmvFP
     | rmvCell CC = rmvGP
     | rmvCell _ = (error "rmvCell")
   and getCell GP = getCellGP
     | getCell FP = getCellFP
     | getCell _ = (error "getCell")
   and updateCell GP = updateCellGP
     | updateCell FP = updateCellFP
     | updateCell _ = (error "updateCell")
   and addGP (r, (setGP, setFP)) = ((SL.enter (r, setGP)), setFP)
   and addFP (r, (setGP, setFP)) = (setGP, (SL.enter (r, setFP)))
   and rmvGP (r, (setGP, setFP)) = ((SL.rmv (r, setGP)), setFP)
   and rmvFP (r, (setGP, setFP)) = (setGP, (SL.rmv (r, setFP)))
   and getCellGP (setGP, setFP) = setGP
   and getCellFP (setGP, setFP) = setFP
   and updateCellGP ((setGP, setFP), r) = (r, setFP)
   and updateCellFP ((setGP, setFP), r) = (setGP, r)
   and cellsetToString (setGP, setFP) = (printTuple (cellsetnames, [((printSet showGP) setGP), ((printSet showFP) setFP)]))
   and cellsetToString' regmap = (fn (setGP, setFP) => (printTuple (cellsetnames, [((printSet showGP) ((map regmap) setGP)), ((printSet showFP) ((map regmap) setFP))]))
                                 )
   and cellsetToCells (setGP, setFP) = (setGP @ setFP)
   val addReg = addGP
   val addFreg = addFP
   val rmvReg = rmvFP
   val rmvFreg = rmvFP

   fun zeroReg GP = (SOME (31 + offsetGP))
     | zeroReg FP = (SOME (31 + offsetFP))
     | zeroReg _ = NONE
end

