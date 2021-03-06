(* net-db-sig.sml
 *
 * COPYRIGHT (c) 1998 Bell Labs, Lucent Technologies.
 *
 * extracted from net-db.mldoc (v. 1.0; 1998-06-05)
 *)

signature NET_DB =
  sig
    eqtype net_addr
    type addr_family
    type entry
    val name : entry -> string
    val aliases : entry -> string list
    val addrType : entry -> addr_family
    val addr : entry -> net_addr
    val getByName : string -> entry option
    val getByAddr : net_addr * addr_family -> entry option
    val scan : (char, 'a) StringCvt.reader -> (net_addr, 'a) StringCvt.reader
    val fromString : string -> net_addr option
    val toString : net_addr -> string
    
  end
