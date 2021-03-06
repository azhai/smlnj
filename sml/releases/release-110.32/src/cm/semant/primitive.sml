(*
 * "Primitives".
 *   - provide access to compiler internals in an orderly fashion
 *
 * (C) 1999 Lucent Technologies, Bell Laboratories
 *
 * Author: Matthias Blume (blume@kurims.kyoto-u.ac.jp)
 *)
signature PRIMITIVE = sig

    type configuration
    type primitive

    type pidInfo = { statpid: GenericVC.PersStamps.persstamp,
		     sympid: GenericVC.PersStamps.persstamp,
		     ctxt: GenericVC.ModuleId.Set.set }

    val eq : primitive * primitive -> bool

    val fromString : configuration -> string -> primitive option
    val toString : primitive -> string

    val toIdent : configuration -> primitive -> char
    val fromIdent : configuration -> char -> primitive option

    val reqpriv : primitive -> StringSet.set

    (* the domain of (lookup p) must always properly include (exports p) *)
    val exports : configuration -> primitive -> SymbolSet.set
    val da_env : configuration -> primitive -> DAEnv.env
    val env : configuration -> primitive -> GenericVC.Environment.environment
    val pidInfo : configuration -> primitive -> pidInfo
    val iinfo : configuration -> primitive -> IInfo.info

    type pspec = { name: string,
		   env: GenericVC.Environment.environment,
		   pidInfo: pidInfo }

    val configuration : pspec list -> configuration

    val primEnvConf : configuration
end

structure Primitive :> PRIMITIVE = struct

    structure BE = GenericVC.BareEnvironment
    structure E = GenericVC.Environment
    structure DE = DAEnv
    structure PS = GenericVC.PersStamps
    structure SE = GenericVC.CMStaticEnv

    type primitive = string

    type pidInfo =
	{ statpid: PS.persstamp, sympid: PS.persstamp,
	  ctxt: GenericVC.ModuleId.Set.set }

    type pinfo = { name: string,
		   exports: SymbolSet.set,
		   da_env: DE.env,
		   env: E.environment,
		   pidInfo: pidInfo,
		   ident: char }

    type pspec = { name: string,
		   env: E.environment,
		   pidInfo: pidInfo }

    type configuration =
	pinfo StringMap.map * primitive Vector.vector

    fun eq (p1 : primitive, p2) = p1 = p2

    fun fromString ((sm, v): configuration) s =
	case StringMap.find (sm, s) of
	    NONE => NONE
	  | SOME _ => SOME s

    fun toString (p: primitive) = p

    fun get ((sm, v): configuration) p =
	case StringMap.find (sm, p) of
	    NONE => GenericVC.ErrorMsg.impossible "Primitive: bad primitive"
	  | SOME i => i

    infix o'
    fun (f o' g) x y = f (g x y)

    val exports = #exports o' get
    val da_env = #da_env o' get
    val env = #env o' get
    val pidInfo = #pidInfo o' get
    val toIdent = #ident o' get

    fun iinfo c p = let
	val e = env c p
	val { statpid, sympid, ctxt } = pidInfo c p
	val ste = E.staticPart e
	val sye = E.symbolicPart e
    in
	{ statenv = fn () => { env = ste, ctxt = ctxt },
	  symenv = fn () => sye,
	  statpid = statpid,
	  sympid = sympid }
    end

    val reqpriv = StringSet.singleton o toString

    fun fromIdent ((sm, v): configuration) c = let
	val p = Char.ord c
    in
	if p < Vector.length v then SOME (Vector.sub (v, p)) else NONE
    end

    fun configuration l = let
	(* First we make the list into a map to become independent of the
	 * order of the elements. *)
	val m = foldl (fn (x: pspec, m) => StringMap.insert (m, #name x, x))
	              StringMap.empty l
	fun gen_pinfo ({ name, env, pidInfo }, i) = let
	    val es2bs = GenericVC.CoerceEnv.es2bs
	    val (da_env, mkExports) =
		Statenv2DAEnv.cvt (es2bs (E.staticPart env))
	in
	    { name = name, exports = mkExports (), da_env = da_env,
	      env = env, pidInfo = pidInfo,
	      ident = Char.chr i }
	end
	fun one (ps, (sm, sl, i)) =
	    (StringMap.insert (sm, #name ps, gen_pinfo (ps, i)),
	     #name ps :: sl,
	     i + 1)
	val (sm, sl, _) = StringMap.foldl one (StringMap.empty, [], 0) m
    in
	(sm, Vector.fromList (rev sl))
    end

    val primEnvConf = let
	(* We could actually go and calculate the actual pid of primEnv.
	 * But in reality it's pretty pointless to do so... *)
	val bogusPid = PS.fromBytes (Byte.stringToBytes "0123456789abcdef")
	val pspec = { name = "primitive",
		      env = E.mkenv { static = E.primEnv,
				      symbolic = E.symbolicPart E.emptyEnv,
				      dynamic = E.dynamicPart E.emptyEnv },
		      pidInfo = { statpid = bogusPid,
				  sympid = bogusPid,
				  ctxt = GenericVC.ModuleId.Set.empty } }
    in
	configuration [pspec]
    end
end
