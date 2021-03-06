(*
 * Handling compile-servers under Unix- (and Unix-like) operating systems.
 *
 *  This is still rather crude and not very robust.
 *
 * (C) 1999 Lucent Technologies, Bell Laboratories
 *
 * Author: Matthias Blume (blume@kurims.kyoto-u.ac.jp)
 *)
structure Servers :> SERVERS = struct

    structure P = Posix

    type pathtrans = (string -> string) option
    datatype server = S of { id: int,
			     name: string,
			     proc: Unix.proc,
			     pt: pathtrans,
			     pref: int,
			     decommissioned: bool ref }

    fun servId (S { id, ... }) = id
    fun decommission (S { decommissioned, ... }) = decommissioned := true
    fun decommissioned (S { decommissioned = d, ... }) = !d
    fun servName (S { name, ... }) = name
    fun servPref (S { pref, ... }) = pref
    fun servPT (S { pt, ... }) = pt
    fun servProc (S { proc, ... }) = proc
    val servIns = #1 o Unix.streamsOf o servProc
    val servOuts = #2 o Unix.streamsOf o servProc

    val newId = let
	val r = ref 0
    in
	fn () => let val i = !r in r := i + 1; i end
    end
    val enabled = ref false

    val idle = ref ([]: server list)
    val someIdle = ref (Concur.pcond ())

    local
	val nservers = ref 0
	val all = ref (IntMap.empty: server IntMap.map)
    in
	fun noServers () = !nservers = 0
	fun allServers () = IntMap.listItems (!all)
	fun addServer s = let
	    val ns = !nservers
	in
	    nservers := ns + 1;
	    all := IntMap.insert (!all, servId s, s)
	end
	fun delServer s = let
	    val ns = !nservers - 1
	in
	    all := #1 (IntMap.remove (!all, servId s));
	    nservers := ns;
	    (* If this was the last server we need to wake up
	     * everyone who is currently waiting to grab a server.
	     * The "grab"-loop will then gracefully fail and
	     * not cause a deadlock. *)
	    if ns = 0 then
		(Say.dsay ["No more servers -> back to sequential mode.\n"];
		 Concur.signal (!someIdle))
	    else ()
	end
    end

    (* This really shouldn't be here, but putting it into SrcPath would
     * create a dependency cycle.  Some better structuring will fix this. *)
    fun isAbsoluteDescr d =
	(case String.sub (d, 0) of #"/" => true | #"%" => true | _ => false)
	handle _ => false

    fun fname (n, s) =
	case servPT s of
	    NONE => n
	  | SOME f => if isAbsoluteDescr n then f n else n

    (* protect some code segment from sigPIPE signals... *)
    fun pprotect work = let
	val pipe = UnixSignals.sigPIPE
	fun disable () = Signals.setHandler (pipe, Signals.IGNORE)
	fun reenable sa = ignore (Signals.setHandler (pipe, sa))
    in
	SafeIO.perform { openIt = disable, closeIt = reenable,
			 work = fn _ => work (), cleanup = fn _ => () }
    end

    (* Send a message to a slave. This must be sigPIPE-protected. *)
    fun send (s, msg) = let
	val outs = servOuts s
    in
	Say.dsay ["-> ", servName s, " : ", msg];
	pprotect (fn () =>
		  (TextIO.output (outs, msg); TextIO.flushOut outs)
		  handle _ => ())
    end

    fun show_idle () =
	Say.dsay ("Idle:" ::
		  foldr (fn (s, l) => " " :: servName s :: l) ["\n"] (!idle))

    (* Mark a server idle; signal all those who are currently waiting for
     * that...*)
    fun mark_idle s =
	(idle := s :: !idle;
	 Concur.signal (!someIdle);
	 Say.dsay ["Scheduler: slave ", servName s, " has become idle.\n"];
	 show_idle ())

    (* Grab an idle server; wait if necessary; reinitialize condition
     * if taking the only server. *)
    fun grab () =
	(* We need to check the following every time (at least the
	 * "noServers" part) because it might be that all servers
	 * have meanwhile gone away for some reason (crashed, etc.). *)
	if not (!enabled) orelse noServers () then NONE
	else case !idle of
	    [] => (Concur.wait (!someIdle); grab ())
	  | [only] =>
		(Say.dsay ["Scheduler: taking last idle slave (",
			   servName only, ").\n"];
		 idle := [];
		 someIdle := Concur.pcond ();
		 SOME only)
	  | first :: more => let
		fun best (b, [], rest) = (b, rest)
		  | best (b, s :: r, rest) = let
			val bp = servPref b
			val sp = servPref s
		    in
			if sp > bp then best (s, r, b :: rest)
			else best (b, r, s :: rest)
		    end
		val (b, rest) = best (first, more, [])
	    in
		Say.dsay ["Scheduler: taking idle slave (",
			  servName b, ").\n"];
		idle := rest;
		show_idle ();
		SOME b
	    end

    fun wait_status (s, echo) = let
	val name = servName s
	val ins = servIns s

	fun unexpected l = let
	    fun word (w, l) = " " :: w :: l
	in
	    Say.say ("! Unexpected response from slave " ::
		     name :: ":" :: foldr word ["\n"] l)
	end
	     
	fun serverExit () = let
	    val what =
		case pprotect (fn () => Unix.reap (servProc s)) of
		    (P.Process.W_EXITED | P.Process.W_EXITSTATUS 0w0) =>
			"shut down"
		  | _ => "crashed"
	in
	    decommission s;
	    Say.say ["[!Slave ", name, " has ", what, ".]\n"];
	    delServer s
	end

	val show =
	    if echo then (fn report => Say.say (rev report))
	    else (fn _ => ())

	fun loop report =
	    if decommissioned s then false
	    else
		(Concur.wait (Concur.inputReady ins);
		 case TextIO.inputLine ins of
		     "" => (serverExit (); false)
		   | line =>
			 (Say.dsay ["<- ", name, ": ", line];
			  case String.tokens Char.isSpace line of
			      ["SLAVE:", "ok"] =>
				  (mark_idle s; show report; true)
			    | ["SLAVE:", "error"] =>
				  (mark_idle s;
				   (* In the case of error we don't show
				    * the report because it will be re-enacted
				    * locally. *)
				   false)
			    | "SLAVE:" :: l => (unexpected l; loop report)
			    | _ => loop (line :: report)))
    in
	loop []
    end

    (* Send a "ping" to all servers and wait for the "pong" responses.
     * This should work for all servers, busy or no.  Busy servers will
     * take longer to respond because they first need to finish what
     * they are doing.
     * We use wait_all after we receive an interrupt signal.  The ping-pong
     * protocol does not suffer from the race condition that we would have
     * if we wanted to only wait for "ok"s from currently busy servers.
     * (The race would happen when an interrupt occurs between receiving
     * "ok" and marking the corresponding slave idle). *)
    fun wait_all is_int = let
	val al = allServers ()
	fun ping s = let
	    val name = servName s
	    val ins = servIns s
	    fun loop () =
		if decommissioned s then ()
		else
		    (Concur.wait (Concur.inputReady ins);
		     case TextIO.inputLine ins of
			 "" =>
			     (* server has gone away -> no pong *)
			     Say.dsay ["<-(EOF) ", name, "\n"]
		       | line => 
			     (Say.dsay ["<- ", name, ": ", line];
			      case String.tokens Char.isSpace line of
				  ["SLAVE:", "pong"] => ()
				| _ => loop ()))
	in
	    send (s, "ping\n");
	    loop ()
	end
	val si = Concur.pcond ()
    in
	if List.null al then ()
	else (Concur.signal si;
	      if is_int then
		  Say.say
		  ["Waiting for attached servers to become idle...\n"]
	      else ());
	app ping al;
	idle := al;
	someIdle := si
    end

    fun shutdown (s, method) = let
	val i = servId s
	fun unidle () =
	    idle := #2 (List.partition (fn s' => servId s' = i) (!idle))
	fun waitForExit () =
	    (unidle ();
	     ignore (wait_status (s, false));
	     if not (decommissioned s) then
		 waitForExit ()
	     else ())
    in
	method ();
	waitForExit ()
    end

    fun stop s =
	shutdown (s, fn () => send (s, "shutdown\n"))

    fun kill s =
	shutdown (s, fn () => Unix.kill (servProc s, P.Signal.term))

    fun start { name, cmd, pathtrans, pref } = let
	val p = Unix.execute cmd
	val i = newId ()
	val s = S { id = i, name = name,
		    proc = p, pt = pathtrans, pref = pref,
		    decommissioned = ref false }
    in
	if wait_status (s, false) then (addServer s; SOME s)
	else NONE
    end
	
    fun compile p =
	case grab () of
	    NONE => false
	  | SOME s => let
		val f = fname (p, s)
	    in
		Say.vsay ["[(", servName s, "): compiling ", f, "]\n"];
		send (s, concat ["compile ", f, "\n"]);
		wait_status (s, true)
	    end

    fun reset is_int = (Concur.reset (); wait_all is_int)

    fun startAll st = let
	val l = !idle
	val _ = idle := []
	val tl = map (fn s => Concur.fork (fn () => st s)) l
    in
	SafeIO.perform { openIt = fn () => (),
			 closeIt = fn () => (),
			 work = fn () => app Concur.wait tl,
			 cleanup = reset }
    end

    fun cd d = let
	fun st s = let
	    val d' = fname (d, s)
	in
	    send (s, concat ["cd ", d', "\n"]);
	    ignore (wait_status (s, false))
	end
    in
	startAll st
    end

    fun cm { archos, project } = let
	fun st s = let
	    val f = fname (project, s)
	in
	    send (s, concat ["cm ", archos, " ", f, "\n"]);
	    ignore (wait_status (s, false))
	end
    in
	startAll st
    end

    fun cmb { archos, root } = let
	fun st s =
	    (send (s, concat ["cmb ", archos, " ", root, "\n"]);
	     ignore (wait_status (s, false)))
    in
	startAll st
    end

    fun dirbase db = let
	fun st s =
	    (send (s, concat ["dirbase ", db, "\n"]);
	     ignore (wait_status (s, false)))
    in
	startAll st
    end

    fun enable () = enabled := true
    fun disable () = enabled := false

    fun withServers f =
	SafeIO.perform { openIt = enable,
			 closeIt = disable,
			 work = f,
			 cleanup = reset }

    val name = servName
end
