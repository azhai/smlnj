(* posix.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * Structure for POSIX 1003.1 binding
 *
 *)

structure Posix : POSIX =
  struct

    structure Error   = POSIX_Error
    structure Signal  = POSIX_Signal
    structure Process = POSIX_Process
    structure ProcEnv = POSIX_ProcEnv
    structure FileSys = POSIX_FileSys
    structure IO      = POSIX_IO
    structure SysDB   = POSIX_Sys_DB
    structure TTY     = POSIX_TTY

  end (* structure Posix *)

