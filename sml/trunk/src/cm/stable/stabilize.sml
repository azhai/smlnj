(*
 * Reading, generating, and writing stable libraries.
 *
 * (C) 1999 Lucent Technologies, Bell Laboratories
 *
 * Author: Matthias Blume (blume@kurims.kyoto-u.ac.jp)
 *)
local
    structure DG = DependencyGraph
    structure GG = GroupGraph
    structure EM = GenericVC.ErrorMsg
    structure PP = PrettyPrint
    structure SM = GenericVC.SourceMap
    structure GP = GeneralParams
    structure E = GenericVC.Environment
    structure Pid = GenericVC.PersStamps
    structure P = PickMod
    structure UP = UnpickMod
    structure E = GenericVC.Environment
    structure MI = GenericVC.ModuleId
in

signature STABILIZE = sig

    val libStampIsValid : GP.info
	-> (SrcPath.t * DG.sbnode list * GG.subgrouplist) * Version.t option
	-> bool

    type groupgetter = SrcPath.t * Version.t option -> GG.group option

    val loadStable :
	GP.info -> { getGroup: groupgetter, anyerrors: bool ref } ->
	groupgetter

    val stabilize :
	GP.info -> { group: GG.group, anyerrors: bool ref } -> GG.group option
end

functor StabilizeFn (structure MachDepVC : MACHDEP_VC
		     structure StabModmap : STAB_MODMAP
		     val recomp : GP.info -> GG.group ->
			 (SmlInfo.info -> MachDepVC.Binfile.bfContent) option
		     val getII : SmlInfo.info -> IInfo.info) :> STABILIZE =
struct
    type groupgetter = SrcPath.t * Version.t option -> GG.group option

    structure BF = MachDepVC.Binfile

    structure SSMap = MapFn
	(struct
	     type ord_key = SymbolSet.set
	     val compare = SymbolSet.compare
	end)

    structure SNMap = MapFn
	(struct
	     type ord_key = DG.snode
	     fun compare (DG.SNODE n, DG.SNODE n') =
		 SmlInfo.compare (#smlinfo n, #smlinfo n')
	end)

    structure PU = PickleUtil
    structure UU = UnpickleUtil

    val libstamp_nbytes = 16

    type map = { ss: PU.id SSMap.map, sn: PU.id SNMap.map, pm: P.map }

    val emptyMap = { ss = SSMap.empty, sn = SNMap.empty, pm = P.emptyMap }

    val lifter =
	{ extract = fn (m: map) => #pm m,
	  patchback = fn (m: map, pm) => { ss = #ss m, sn = #sn m, pm = pm } }

    infix 3 $

    (* type info *)
    val (BN, SN, SBN, SS, SI, FSBN, IMPEXP, SHM, G, AP,
	 PRIM, EXPORTS, PRIV, VERSION, SG) =
	(1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010,
	 1011, 1012, 1013, 1014, 1015)

    val SSs =
	{ find = fn (m: map, k) => SSMap.find (#ss m, k),
	  insert = fn ({ ss, sn, pm }, k, v) =>
	               { sn = sn, ss = SSMap.insert (ss, k, v), pm = pm } }
    val	SNs =
	{ find = fn (m: map, k) => SNMap.find (#sn m, k),
	  insert = fn ({ ss, sn, pm }, k, v) =>
	               { ss = ss, sn = SNMap.insert (sn, k, v), pm = pm } }

    fun fetch_pickle s = let
	fun bytesIn n = let
	    val bv = BinIO.inputN (s, n)
	in
	    if n = Word8Vector.length bv then bv
	    else raise UU.Format
	end

	val libstamp = bytesIn libstamp_nbytes	(* ignored *)
	val dg_sz = LargeWord.toIntX (Pack32Big.subVec (bytesIn 4, 0))
	val dg_pickle = Byte.bytesToString (bytesIn dg_sz)
    in
	{ size = dg_sz, pickle = dg_pickle }
    end

    fun mkPickleFetcher mksname () =
	SafeIO.perform { openIt = BinIO.openIn o mksname,
			 closeIt = BinIO.closeIn,
			 work = #pickle o fetch_pickle,
			 cleanup = fn _ => () }

    fun mkInverseMap sublibs = let
	(* Here we build a mapping that maps each BNODE to the
	 * position of its exporting sub-library and a representative
	 * symbol that can be used to find the BNODE within the
	 * exports of that library. *)
	fun oneB i (sy, (nth, _, _), m) =
	    case nth () of
		(_, DG.SB_BNODE (DG.BNODE n, _)) =>
		StableMap.insert (m, #bininfo n, (i, sy))
	      | _ => m
	fun oneSL (g as GG.GROUP { exports, ... }, (m, i)) =
	    (SymbolMap.foldli (oneB i) m exports, i + 1)
	  | oneSL (_, (m, i)) = (m, i + 1)
	fun oneSL' ((_, gth), a) = oneSL (gth (), a)
	val (im, _) = foldl oneSL' (StableMap.empty, 0) sublibs
	fun look i =
	    case StableMap.find (im, i) of
		SOME p => p
	      | NONE => EM.impossible "stabilize: bad inverse map"
    in
	look
    end

    (* A stamp for a library is created by "pickling" the dependency graph
     * of the library in a cursory fashion, thereby recording the ii pids
     * of external references.  The so-created pickle string is never used
     * for unpickling.  Instead, it is hashed and recorded as part of
     * the regular library file.  In paranoia mode CM checks if the recorded
     * hash is identical to the one that _would_ be created if one were
     * to re-build the library now. *)
    fun libStampOf (grouppath, export_nodes, sublibs) = let
	val inverseMap = mkInverseMap sublibs

	val pid = PickleSymPid.w_pid
	val share = PU.ah_share
	val symbol = PickleSymPid.w_symbol
	val string = PU.w_string
	val list = PU.w_list
	val int = PU.w_int

	fun abspath p = let
	    val op $ = PU.$ AP
	    val l = SrcPath.pickle (fn _ => ()) (p, grouppath)
	in
	    "p" $ [list string l]
	end

	fun sn n = let
	    val op $ = PU.$ SN
	    fun raw_sn (DG.SNODE n) =
		"a" $ [list sn (#localimports n), list fsbn (#globalimports n)]
	in
	    share SNs raw_sn n
	end

	and sbn x = let
	    val op $ = PU.$ SBN
	in
	    case x of
		DG.SB_BNODE (DG.BNODE { bininfo = i, ... }, ii) => let
		    val (i, sy) = inverseMap i
		    val { statpid, sympid, ... } = ii
		in
		    "2" $ [int i, pid statpid, pid sympid]
		end
	      | DG.SB_SNODE n => "3" $ [sn n]
	end

	and fsbn (_, n) = let val op $ = PU.$ FSBN in "f" $ [sbn n] end

	fun group () = let
	    val op $ = PU.$ G
	in "g" $ [list sbn export_nodes]
	end
    in
	P.pickle2hash (Byte.stringToBytes (PU.pickle emptyMap (group ())))
    end

    (* Comparison of old and new library stamps. *)
    fun libStampIsValid (gp: GP.info) (a as (grouppath, _, _), version) = let
	val newStamp = Byte.bytesToString (Pid.toBytes (libStampOf a))
	val policy = #fnpolicy (#param gp)
	val sname = FilenamePolicy.mkStableName policy (grouppath, version)
	fun work s = let
	    val oldStamp =
		Byte.bytesToString (BinIO.inputN (s, libstamp_nbytes))
	in
	    oldStamp = newStamp
	end
    in
	SafeIO.perform { openIt = fn () => BinIO.openIn sname,
			 closeIt = BinIO.closeIn,
			 work = work,
			 cleanup = fn _ => () }
	handle _ => false
    end

    fun loadStable gp { getGroup, anyerrors } (group, version) = let

	val errcons = #errcons (gp: GeneralParams.info)
	val grpSrcInfo = (errcons, anyerrors)
	val gdescr = SrcPath.descr group
	fun error l = EM.errorNoFile (errcons, anyerrors) SM.nullRegion
	    EM.COMPLAIN (concat ("(stable) " :: gdescr :: ": " :: l))
	    EM.nullErrorBody

	exception Format = UU.Format

	val pcmode = #pcmode (#param gp)
	val policy = #fnpolicy (#param gp)

	fun mksname () = FilenamePolicy.mkStableName policy (group, version)

	fun work s = let

	    fun getGroup' (p, vo) =
		case getGroup (p, vo) of
		    SOME g => g
		  | NONE => (error ["unable to find ", SrcPath.descr p];
			     raise Format)

	    val { size = dg_sz, pickle = dg_pickle } = fetch_pickle s
	    val offset_adjustment = dg_sz + 4 + libstamp_nbytes
	    val { getter, dropper } =
		UU.stringGetter' (SOME dg_pickle, mkPickleFetcher mksname)
	    val session = UU.mkSession getter

	    val sgListM = UU.mkMap ()
	    val ssM = UU.mkMap ()
	    val ssoM = UU.mkMap ()
	    val boolOptionM = UU.mkMap ()
	    val siM = UU.mkMap ()
	    val snM = UU.mkMap ()
	    val snListM = UU.mkMap ()
	    val sbnM = UU.mkMap ()
	    val fsbnM = UU.mkMap ()
	    val fsbnListM = UU.mkMap ()
	    val impexpM = UU.mkMap ()
	    val impexpListM = UU.mkMap ()
	    val groupM = UU.mkMap ()
	    val apM = UU.mkMap ()
	    val exportsM = UU.mkMap ()
	    val privilegesM = UU.mkMap ()
	    val poM = UU.mkMap ()
	    val stringListM = UU.mkMap ()
	    val versionM = UU.mkMap ()
	    val versionOptM = UU.mkMap ()
	    val sgM = UU.mkMap ()

	    fun list m r = UU.r_list session m r
	    val string = UU.r_string session

	    fun option m r = UU.r_option session m r
	    val int = UU.r_int session
	    val bool = UU.r_bool session
	    fun share m r = UU.share session m r
	    fun nonshare r = UU.nonshare session r
	    val bool = UU.r_bool session
	    val pid = UnpickleSymPid.r_pid (session, string)

	    val stringlist = list stringListM string

	    fun list2path sl =
		SrcPath.unpickle pcmode (sl, group)
		handle SrcPath.Format => raise Format
		     | SrcPath.BadAnchor a =>
		       (error ["configuration anchor \"", a, "\" undefined"];
			raise Format)

	    fun abspath () = let
		fun ap #"p" = list2path (stringlist ())
		  | ap _ = raise Format
	    in
		share apM ap
	    end

	    fun version () = let
		fun v #"v" =
		    (case Version.fromString (string ()) of
			 SOME v => v
		       | NONE => raise Format)
		  | v _ = raise Format
	    in
		share versionM v
	    end

	    fun sg () = let
		fun xsg #"s" =
		    let val p = abspath ()
			val vo = option versionOptM version ()
			fun gth () = getGroup' (p, vo)
		    in
			(p, Memoize.memoize gth)
		    end
		  | xsg _ = raise Format
	    in
		share sgM xsg
	    end

	    fun gr #"g" =
		let val version = option versionOptM version ()
		    val sublibs = list sgListM sg ()

		    fun getSublib i =
			(case #2 (List.nth (sublibs, i)) () of
			     GG.GROUP x => x
			   | GG.ERRORGROUP =>
			       EM.impossible "loadStable: ERRORGROUP")
			handle General.Subscript => raise Format

		    fun context NONE = raise Format
		      | context (SOME (pos, sy)) = let
			    val { exports, ... } = getSublib pos
			in
			    case SymbolMap.find (exports, sy) of
				SOME (nth, _, _) =>
				  (case nth () of
				       (_, DG.SB_BNODE (_, x)) =>
				       StabModmap.addEnv (#statenv x ())
				     | _ => raise Format)
			      | NONE => raise Format
			end

		    val { symenv, statenv, symbol, symbollist } =
			UP.mkUnpicklers
			{ session = session,
			  stringlist = stringlist }
			context

		    val lazy_symenv = UU.r_lazy session symenv
		    val lazy_statenv = UU.r_lazy session statenv

		    fun symbolset () = let
			fun s #"s" =
			    SymbolSet.addList (SymbolSet.empty, symbollist ())
			  | s _ = raise Format
		    in
			share ssM s
		    end

		    val filter = option ssoM symbolset

		    fun shm () = let
			fun s #"a" = Sharing.SHARE true
			  | s #"b" = Sharing.SHARE false
			  | s #"c" = Sharing.DONTSHARE
			  | s _ = raise Format
		    in
			nonshare s
		    end

		    val pidoption = option poM pid

		    fun si () = let
			fun s #"s" =
			    let val spec = string ()
				val locs = string ()
				val offset = int () + offset_adjustment
				val rts_pid = pidoption ()
				val sh_mode = shm ()
				val error = EM.errorNoSource grpSrcInfo locs
			    in
				BinInfo.new { group = group,
					      mkStablename = mksname,
					      error = error,
					      spec = spec,
					      offset = offset,
					      rts_pid = rts_pid,
					      sh_mode = sh_mode }
			    end
			  | s _ = raise Format
		    in
			share siM s
		    end

		    (* this is the place where what used to be an
		     * SNODE changes to a BNODE! *)
		    fun sn () = let
			fun sn' #"a" =
			    DG.BNODE { bininfo = si (),
				       localimports = snlist (),
				       globalimports = fsbnlist () }
			  | sn' _ = raise Format
		    in
			share snM sn'
		    end

		    and snlist () = list snListM sn ()

		    (* this one changes from farsbnode to plain farbnode *)
		    and sbn () = let
			fun sbn' #"2" = let
				val pos = int ()
				val sy = symbol ()
				val { exports = slexp, ... } = getSublib pos
			    in
				case SymbolMap.find (slexp, sy) of
				    SOME (nth, _, _) =>
				      (case nth () of
					   (_, DG.SB_BNODE (n, _)) => n
					 | _ => raise Format)
				  | NONE => raise Format
			    end
			  | sbn' #"3" = sn ()
			  | sbn' _ = raise Format
		    in
			share sbnM sbn'
		    end

		    and fsbn () = let
			fun f #"f" = (filter (), sbn ())
			  | f _ = raise Format
		    in
			share fsbnM f
		    end

		    and fsbnlist () = list fsbnListM fsbn ()

		    val lazy_fsbn = UU.r_lazy session fsbn

		    fun impexp () = let
			fun ie #"i" =
			    let val sy = symbol ()
				(* really reads farbnodes! *)
				val nth = lazy_fsbn ()
				val ge = lazy_statenv ()
				val sye = lazy_symenv ()
				val statpid = pid ()
				val sympid = pid ()
				val allsyms = symbolset ()
				fun ieth () = let
				    val (f, n) = nth ()
				    val ii = { statenv = ge,
					       symenv = sye,
					       statpid = statpid,
					       sympid = sympid }
				in
				    (f, DG.SB_BNODE (n, ii))
				end
				val e = Statenv2DAEnv.cvtMemo ge
				(* put a filter in front to avoid having
				 * the FCTENV being queried needlessly
				 * (avoids spurious module loadings) *)
				val e' = DAEnv.FILTER
					     (SymbolSet.singleton sy, e)
			    in
				(sy, (Memoize.memoize ieth, e', allsyms))
			    end
			  | ie _ = raise Format
		    in
			share impexpM ie
		    end

		    val impexplist = list impexpListM impexp

		    fun r_exports () = let
			fun e #"e" =
			    foldl SymbolMap.insert'
			          SymbolMap.empty (impexplist ())
			  | e _ = raise Format
		    in
			share exportsM e
		    end

		    fun privileges () = let
			fun p #"p" =
			    StringSet.addList (StringSet.empty, stringlist ())
			  | p _ = raise Format
		    in
			share privilegesM p
		    end

		    val exports = r_exports ()
		    val required = privileges ()
		in
		    GG.GROUP { exports = exports,
			       kind = GG.LIB { version = version,
					       kind = GG.STABLE dropper },
			       required = required,
			       grouppath = group,
			       sources = SrcPathMap.empty,
			       sublibs = sublibs }
		end
	      | gr _ = raise Format
	in
	    share groupM gr
	end
    in
	SOME (SafeIO.perform { openIt = BinIO.openIn o mksname,
			       closeIt = BinIO.closeIn,
			       work = work,
			       cleanup = fn _ => () })
	handle Format => (error ["file is corrupted (old version?)"];
			  NONE)
             | IO.Io _ => NONE
    end

    fun stabilize _ { group = GG.ERRORGROUP, ... } = NONE
      | stabilize gp { group = g as GG.GROUP grec, anyerrors } = let

	val policy = #fnpolicy (#param gp)

	fun doit (wrapped, getBFC, vers) = let

	    val grouppath = #grouppath grec
	    val sublibs = #sublibs grec
	    val exports = #exports grec

	    fun force f = f ()

	    val libstamp =
		libStampOf (grouppath,
			    map (#2 o force o #1)
				(SymbolMap.listItems exports),
			    sublibs)

	    fun writeBFC s i = BF.write { stream = s,
					  content = getBFC i,
					  nopickle = true }
	    fun sizeBFC i = BF.size { content = getBFC i, nopickle = true }
	    fun pidBFC i = BF.staticPidOf (getBFC i)

	    val _ =
		Say.vsay ["[stabilizing ", SrcPath.descr grouppath, "]\n"]

	    val _ =
		if StringSet.isEmpty wrapped then ()
		else
		    Say.say ("$Stabilize: wrapping the following privileges:\n"
			     :: map (fn s => ("  " ^ s ^ "\n"))
			            (StringSet.listItems wrapped))

	    val grpSrcInfo = (#errcons gp, anyerrors)

	    val required = StringSet.difference (#required grec, wrapped)

	    (* The format of a stable archive is the following:
	     *  - It starts with the size s of the pickled dependency
	     *    graph. This size itself is written as four-byte string.
	     *  - The size t of the pickled environment for the entire
	     *    library (using the pickleEnvN interface of the pickler)
	     *    in the same format as s.
	     *  - The pickled dependency graph.  This graph contains
	     *    integer offsets of the binfiles for the individual ML
	     *    members. These offsets need to be adjusted by adding
	     *    s + t + 8. The pickled dependency graph also contains integer
	     *    offsets relative to other stable groups.  These offsets
	     *    need no further adjustment.
	     *  - Individual binfile contents (concatenated) but without
	     *    their static environments.
	     *)

	    val inverseMap = mkInverseMap sublibs

	    val members = ref []
	    val (registerOffset, getOffset) = let
		val dict = ref SmlInfoMap.empty
		val cur = ref 0
		fun reg (i, sz) = let
		    val os = !cur
		in
		    cur := os + sz;
		    dict := SmlInfoMap.insert (!dict, i, os);
		    members := i :: (!members);
		    os
		end
		fun get i = valOf (SmlInfoMap.find (!dict, i))
	    in
		(reg, get)
	    end

	    fun path2list p = let
		fun warn_relabs abs = let
		    val (relabs, is) = if abs then ("absolute", "is: ")
				       else ("relative", "was resolved as: ")
		    fun ppb pps =
			(PP.add_newline pps;
			 PP.add_string pps ("The library's path " ^ is);
			 PP.add_string pps (SrcPath.descr p);
			 PP.add_newline pps;
			 PP.add_string pps
    "(This means that in order to be able to use the result of stabilization,";
                         PP.add_newline pps;
			 PP.add_string pps "the library must be in the same ";
			 PP.add_string pps relabs;
			 PP.add_string pps " location as it is now.)";
			 PP.add_newline pps)
		in
		    EM.errorNoFile (#errcons gp, anyerrors) SM.nullRegion
				   EM.WARN
				   (concat [SrcPath.descr grouppath,
					    ": library referred to by ",
					    relabs, " pathname."])
				   ppb
		end
	    in
		SrcPath.pickle warn_relabs (p, grouppath)
	    end

	    (* Collect all BNODEs that we see and build
	     * a context suitable for P.envPickler. *)
	    val libctxt = let
		fun lst f [] k s = k s
		  | lst f (h :: t) k s = f h (lst f t k) s

		fun sbn n k (s as (bnodes, snodes)) =
		    case n of
			DG.SB_BNODE (DG.BNODE { bininfo = i, ... }, ii) => let
			    val (pos, sy) = inverseMap i
			    val bnodes' =
				StableMap.insert (bnodes, i,
						  ((pos, sy), #statenv ii))
			in
			    k (bnodes', snodes)
			end
		      | DG.SB_SNODE n => sn n k s

		and sn (DG.SNODE n) k (bnodes, snodes) = let
		    val i = #smlinfo n
		    val li = #localimports n
		    val gi = #globalimports n
		in
		    if SmlInfoSet.member (snodes, i) then
			k (bnodes, snodes)
		    else let
			val snodes' = SmlInfoSet.add (snodes, i)
		    in
			lst sn li (lst fsbn gi k) (bnodes, snodes')
		    end
		end

		and fsbn (_, n) k s = sbn n k s

		fun impexp (nth, _, _) k s = fsbn (nth ()) k s

		val bnodes =
		    lst impexp (SymbolMap.listItems exports)
		         #1
		        (StableMap.empty, SmlInfoSet.empty)

		val bnodel = StableMap.listItems bnodes

		fun libArg ([], _) = []
		  | libArg ((lsm, ge) :: t, m) = let
			val m' = GenModIdMap.mkMap' (ge (), m)
		    in
			(SOME lsm, m') :: libArg (t, m')
		    end
	    in
		libArg (bnodel, MI.emptyTmap)
	    end

	    val env_orig = P.envPickler (fn _ => ()) (P.LIBRARY libctxt)
	    val env = PU.lift_pickler lifter env_orig
	    val symenv_orig = P.symenvPickler
	    val symenv = PU.lift_pickler lifter symenv_orig
	    val lazy_env = PU.w_lazy env
	    val lazy_symenv = PU.w_lazy symenv

	    val bool = PU.w_bool
	    val int = PU.w_int
	    val symbol = PickleSymPid.w_symbol
	    val pid = PickleSymPid.w_pid
	    val share = PU.ah_share
	    val option = PU.w_option
	    val list = PU.w_list
	    val string = PU.w_string
	    val bool = PU.w_bool
	    val int = PU.w_int

	    fun symbolset ss = let
		val op $ = PU.$ SS
		fun raw_ss ss = "s" $ [list symbol (SymbolSet.listItems ss)]
	    in
		share SSs raw_ss ss
	    end

	    val filter = option symbolset

	    val op $ = PU.$ SHM
	    fun shm (Sharing.SHARE true) = "a" $ []
	      | shm (Sharing.SHARE false) = "b" $ []
	      | shm Sharing.DONTSHARE = "c" $ []

	    fun si i = let
		(* FIXME: this is not a technical flaw, but perhaps one
		 * that deserves fixing anyway:  If we only look at spec,
		 * then we are losing information about sub-grouping
		 * within libraries.  However, the spec in BinInfo.info
		 * is only used for diagnostics and has no impact on the
		 * operation of CM itself. *)
		val spec = SrcPath.specOf (SmlInfo.sourcepath i)
		val locs = SmlInfo.errorLocation gp i
		val offset = registerOffset (i, sizeBFC i)
		val { is_rts, ... } = SmlInfo.attribs i
		val sh_mode = SmlInfo.sh_mode i
		val op $ = PU.$ SI
		val rts_pid = if is_rts then SOME (pidBFC i) else NONE
	    in
		"s" $ [string spec, string locs, int offset,
		       option pid rts_pid, shm sh_mode]
	    end

	    fun abspath p = let
		val op $ = PU.$ AP
	    in
		"p" $ [list string (path2list p)]
	    end

	    fun sn n = let
		val op $ = PU.$ SN
		fun raw_sn (DG.SNODE n) =
		    "a" $ [si (#smlinfo n), list sn (#localimports n),
			   list fsbn (#globalimports n)]
	    in
		share SNs raw_sn n
	    end

	    (* Here we ignore the interface info because we will not
	     * need it anymore when we unpickle. *)
	    and sbn x = let
		val op $ = PU.$ SBN
	    in
		case x of
		    DG.SB_BNODE (DG.BNODE { bininfo = i, ... }, _) => let
			val (pos, sy) = inverseMap i
		    in
			"2" $ [int pos, symbol sy]
		    end
		  | DG.SB_SNODE n => "3" $ [sn n]
	    end
	
	    and fsbn (f, n) = let
		val op $ = PU.$ FSBN
	    in
		"f" $ [filter f, sbn n]
	    end

	    val lazy_fsbn = PU.w_lazy fsbn

	    (* Here is the place where we need to write interface info. *)
	    fun impexp (s, (nth, _, allsyms)) = let
		val op $ = PU.$ IMPEXP
		val { statenv, symenv, statpid, sympid } =
		    case nth () of
			(_, DG.SB_BNODE (_, ii)) => ii
		      | (_, DG.SB_SNODE (DG.SNODE { smlinfo, ... })) =>
			    getII smlinfo
	    in
		"i" $ [symbol s,
		       lazy_fsbn nth,
		       lazy_env statenv,
		       lazy_symenv symenv,
		       pid statpid,
		       pid sympid,
		       symbolset allsyms]
	    end

	    fun w_exports e = let
		val op $ = PU.$ EXPORTS
	    in
		"e" $ [list impexp (SymbolMap.listItemsi e)]
	    end

	    fun privileges p = let
		val op $ = PU.$ PRIV
	    in
		"p" $ [list string (StringSet.listItems p)]
	    end

	    fun version v = let
		val op $ = PU.$ VERSION
	    in
		"v" $ [string (Version.toString v)]
	    end

	    fun sg (p, gth) = let
		val op $ = PU.$ SG
		val vo = case gth () of
			     GG.GROUP { kind = GG.LIB x, ... } => #version x
			   | _ => NONE
	    in
		"s" $ [abspath p, option version vo]
	    end

	    fun group () = let
		val op $ = PU.$ G
	    in
		(* Pickle the sublibs first because we need to already
		 * have them back when we unpickle BNODEs. *)
		"g" $ [option version vers,
		       list sg sublibs,
		       w_exports exports,
		       privileges required]
	    end

	    val dg_pickle =
		Byte.stringToBytes (PU.pickle emptyMap (group ()))

	    val dg_sz = Word8Vector.length dg_pickle

	    val offset_adjustment = dg_sz + 4 + libstamp_nbytes

	    (* We could generate the graph for a stable group here directly
	     * by transcribing the original graph.  However, it is cumbersome
	     * and is likely to result in a larger memory footprint because
	     * we don't get the benefit of lazy unpickling of environments.
	     * It seems easier to simply rely on "loadStable" to re-fetch
	     * the stable graph. *)
	    fun refetchStableGroup () = let
		fun getGroup (p, _) = let
		    fun theSublib (q, _) = SrcPath.compare (p, q) = EQUAL
		    fun force f = f ()
		in
		    Option.map (force o #2) (List.find theSublib sublibs)
		end
	    in
		loadStable gp { getGroup = getGroup, anyerrors = anyerrors }
		           (grouppath, NONE)
	    end
			        
	    fun writeInt32 (s, i) = let
		val a = Word8Array.array (4, 0w0)
		val _ = Pack32Big.update (a, 0, LargeWord.fromInt i)
	    in
		BinIO.output (s, Word8Array.extract (a, 0, NONE))
	    end
	    val memberlist = rev (!members)

	    (* We do not use version information for making the stable path! *)
	    fun mksname () =
		FilenamePolicy.mkStableName policy (grouppath, NONE)

	    val libstamp_bytes = Pid.toBytes libstamp
	    val _ =
		if Word8Vector.length libstamp_bytes <> libstamp_nbytes then
		    EM.impossible "stabilize: libstamp size wrong"
		else ()
	    fun work outs =
		(BinIO.output (outs, libstamp_bytes);
		 writeInt32 (outs, dg_sz);
		 BinIO.output (outs, dg_pickle);
		 app (writeBFC outs) memberlist)
	in
	   (SafeIO.perform { openIt = AutoDir.openBinOut o mksname,
			     closeIt = BinIO.closeOut,
			     work = work,
			     cleanup = fn _ =>
				    (OS.FileSys.remove (mksname ())
				     handle _ => ()) };
	    refetchStableGroup ())
	    handle exn =>
		(EM.errorNoFile (#errcons gp, anyerrors) SM.nullRegion
		    EM.COMPLAIN
		    (concat ["Exception raised while stabilizing ",
			     SrcPath.descr grouppath])
		    EM.nullErrorBody;
		 NONE)
	end
    in
	case #kind grec of
	    GG.LIB { kind = GG.STABLE _, ... } => SOME g
	  | GG.NOLIB _ => EM.impossible "stabilize: no library"
	  | GG.LIB { kind = GG.DEVELOPED { wrapped, ... }, version } =>
	     (case recomp gp g of
		  NONE => (anyerrors := true; NONE)
		| SOME bfc_acc => let
		      fun notStable (_, gth) =
			  case gth () of
			      GG.GROUP { kind =
					 GG.LIB { kind = GG.STABLE _,
						  ... }, ... } =>
			      false
			    | _ => true
		  in
		    case List.filter notStable (#sublibs grec) of
			[] => doit (wrapped, bfc_acc, version)
		      | l => let
			    val grammar = case l of [_] => " is" | _ => "s are"
			    fun ppb pps = let
				fun loop [] = ()
				  | loop ((p, _) :: t) =
				    (PP.add_string pps (SrcPath.descr p);
				     PP.add_newline pps;
				     loop t)
			    in
				PP.add_newline pps;
				PP.add_string pps
				    (concat ["because the following sub-group",
					     grammar, " not stable:"]);
				PP.add_newline pps;
				loop l
			    end
			    val errcons = #errcons gp
			    val gdescr = SrcPath.descr (#grouppath grec)
			in
			    EM.errorNoFile (errcons, anyerrors) SM.nullRegion
			       EM.COMPLAIN
			       (gdescr ^ " cannot be stabilized")
			       ppb;
			    NONE
			end
		  end)
    end
end (* functor Stabilize *)

end (* local *)
