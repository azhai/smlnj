/* set-int-timer.c
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * NOTE: this implementation is UNIX-specific right now; I would like to
 * define an OS abstraction layer for interval timers, which would cover
 * both alarm timers and profiling, but I need to look at what other systems
 * do first.
 */

#include "ml-base.h"
#ifdef OPSYS_UNIX
#  include "ml-unixdep.h"
#  include <sys/time.h>
#elif defined(OPSYS_WIN32)
#  include "win32-timers.h"
#endif
#include "ml-c.h"
#include "ml-values.h"
#include "ml-objects.h"
#include "smlnj-runtime.h"

/* setIntTimer : (int * int) option -> unit
 *
 * Set the interval timer; NONE means disable the timer
 */
void setIntTimer (ml_state_t *msp, ML_int_pair_opt_t itv)
{
#ifdef HAS_SETITIMER
    struct itimerval	new_itv;
    int			sts;
    ml_val_t		tmp;

    if (itv == OPTION_NONE) {
      /* turn the timer off */
	new_itv.it_interval.tv_sec	=
	new_itv.it_value.tv_sec		=
	new_itv.it_interval.tv_usec	=
	new_itv.it_value.tv_usec	= 0;
    }
    else {
      /* turn the timer on */
	tmp = OPTION_get(itv);
	new_itv.it_interval.tv_sec	=
	new_itv.it_value.tv_sec		= REC_SELINT32(tmp, 0);
	new_itv.it_interval.tv_usec	=
	new_itv.it_value.tv_usec	= REC_SELINT(tmp, 1);
    }

    sts = setitimer (ITIMER_REAL, &new_itv, NIL(struct itimerval *));

    /*  FIXME: need to check for errors and raise an exn
    CHK_RETURN_UNIT(msp, sts);
    */

#elif defined(OPSYS_WIN32)
    if (itv == OPTION_NONE) {
	if (!win32StopTimer())
	    /*  FIXME: raise exn
	    return RAISE_ERROR(msp,"win32 setitimer: couldn't stop timer");
	    */
    }
    else {
	ml_val_t	tmp = OPTION_get(itv);
	int		mSecs = REC_SELINT32(tmp,0) * 1000 + REC_SELINT(tmp,1) / 1000;

	if (mSecs <= 0)
	    /*  FIXME: raise exn
	    return RAISE_ERROR(msp, "win32 setitimer: invalid resolution");
	    */
	else {
	    if (!win32StartTimer(mSecs))
	        /*  FIXME: raise exn
		return RAISE_ERROR(msp,"win32 setitimer: couldn't start timer");
		*/
	}
    }
#else
    /*  FIXME: raise exn
    return RAISE_ERROR(msp, "setitimer not supported");
    */
#endif

}
