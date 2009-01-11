#include "EXTERN.h"
#include "perl.h"
#include "embed.h"
#include "XSUB.h"

#ifdef sv_does
	#define CAN_HAS_DOES
#endif

#include "ppport.h"

STATIC SV *get_obj(pTHX_ SV *sv) {
	SvGETMAGIC(sv);

	if ( SvROK(sv) ) {
		SV * ob = SvRV(sv);

		if ( SvOBJECT(ob) ) {
			return ob;
		} else if ( SvTYPE(ob) == SVt_PVGV 
#ifdef isGV_with_GP
				&& isGV_with_GP(ob)
#endif
				&& (ob = (SV *)GvIO((const GV *)ob))
				&& SvOBJECT(ob) ) {
			return ob;
		} else {
			return NULL;
		}
	} else if ( SvOK(sv) ) {
		/* look for a named filehandle (e.g. "STDOUT") */
#ifdef gv_fetchsv
		GV *gv = gv_fetchsv(sv, 0, SVt_PVIO);
#else
		GV *gv = gv_fetchpv(SvPV_nolen(sv), 0, SVt_PVIO);
#endif

		if ( gv ) {
			return (SV *)GvIO((const GV *)gv);
		}
	}

	return NULL;
}

STATIC SV *get_obj_rv(pTHX_ SV *sv) {
	SV *real_obj = get_obj(aTHX_ sv);

	if ( real_obj ) {
		if ( SvROK(sv) && real_obj == SvRV(sv) ) {
			return sv;
		} else {
			return sv_2mortal(newRV_inc(real_obj));
		}
	}

	return NULL;
}

STATIC SV *obj(pTHX_ SV *obj) {
	return get_obj(aTHX_ obj) ? &PL_sv_yes : &PL_sv_no;
}

STATIC SV *call_bool_method(pTHX_ SV *sv, SV *class, const char *method) {
	dSP;
	int res;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(sv);
	XPUSHs(class);
	PUTBACK;

	call_method(method, G_SCALAR);

	SPAGAIN;

	res = SvTRUE(TOPs);

	PUTBACK;
	FREETMPS;
	LEAVE;

	return res ? &PL_sv_yes : &PL_sv_no;
}

STATIC SV *obj_method(pTHX_ SV *sv, SV *class, const char *method) {
	SV *real_obj = get_obj(aTHX_ sv);

	if ( real_obj ) {
		return call_bool_method(aTHX_ sv, class, method);
	}

	return &PL_sv_no;
}

STATIC SV *inv_method(pTHX_ SV *sv, SV *class, const char *method) {
	SV *real_obj = get_obj(aTHX_ sv);
   
	if ( real_obj || ( !SvROK(sv) && SvOK(sv) ) ) {
		return call_bool_method(aTHX_ sv, class, method);
	}

	return &PL_sv_no;
}

STATIC CV *stash_can(pTHX_ HV *stash, char *method) {
	GV * const gv = gv_fetchmethod_autoload(stash, method, FALSE);

	if (gv && isGV(gv))
		return GvCV(gv);

	return NULL;
}

STATIC CV *obj_can(pTHX_ SV *obj, char *method) {
	SV *real_obj = get_obj(aTHX_ obj);

	if ( real_obj )
		return stash_can(aTHX_ SvSTASH(real_obj), method);

	return NULL;
}

STATIC SV *obj_can_cv(pTHX_ SV *obj, char *method) {
	CV *cv = obj_can(aTHX_ obj, method);

	if ( cv )
		return sv_2mortal(SvREFCNT_inc(newRV_inc((SV *)cv)));
	else
		return &PL_sv_undef;
}

STATIC HV *inv_stash(SV *sv) {
	SV *real_obj = get_obj(aTHX_ sv);

	if ( real_obj ) {
		return SvSTASH(real_obj);
	} else if ( SvOK(sv) && !SvROK(sv) && SvTRUE(sv) ) {
		return gv_stashsv(sv, 0);
	}

	return NULL;
}

STATIC SV *inv_can(pTHX_ SV *sv, char *method) {
	HV *stash = inv_stash(sv);

	if ( stash ) {
		return stash_can(aTHX_ stash, method);
	}

	return NULL;
}

STATIC SV *inv_can_cv(pTHX_ SV *obj, char *method) {
	CV *cv = inv_can(aTHX_ obj, method);

	if ( cv )
		return sv_2mortal(SvREFCNT_inc(newRV_inc((SV *)cv)));
	else
		return &PL_sv_undef;
}

STATIC SV *obj_isa(pTHX_ SV *sv, SV *class) {
	return obj_method(aTHX_ sv, class, "isa");
}

STATIC SV *obj_does(pTHX_ SV *sv, SV *class) {
#ifdef CAN_HAS_DOES
	return obj_method(aTHX_ sv, class, "DOES");
#else
	if ( obj_can(aTHX_ sv, "DOES") ) {
		return obj_method(aTHX_ sv, class, "DOES");
	} else {
		return obj_method(aTHX_ sv, class, "isa");
	}
#endif
}

STATIC SV *inv_isa(pTHX_ SV *sv, SV *class) {
	return inv_method(aTHX_ sv, class, "isa");
}

STATIC SV *inv_does(pTHX_ SV *sv, SV *class) {
#ifdef CAN_HAS_DOES
	return inv_method(aTHX_ sv, class, "DOES");
#else
	if ( inv_can(aTHX_ sv, "DOES") ) {
		return inv_method(aTHX_ sv, class, "DOES");
	} else {
		return inv_method(aTHX_ sv, class, "isa");
	}
#endif
}


MODULE = Check::ISA PACKAGE = Check::ISA

PROTOTYPES: ENABLE

SV *
obj(sv, ...)
	SV *sv
	PROTOTYPE: $;$
	CODE:
		RETVAL = items > 1 ? obj_isa(aTHX_ sv, ST(1)) : obj(aTHX_ sv);
	OUTPUT: RETVAL

SV *
obj_does(sv, ...)
	SV *sv
	PROTOTYPE: $;$
	CODE:
		RETVAL = items > 1 ? obj_does(aTHX_ sv, ST(1)) : obj(aTHX_ sv);
	OUTPUT: RETVAL

SV *
obj_can(sv, method)
	SV *sv
	char *method
	PROTOTYPE: $$
	CODE:
		RETVAL = obj_can_cv(aTHX_ sv, method);
	OUTPUT: RETVAL






SV *
inv(sv, ...)
	SV *sv
	PROTOTYPE: $;$
	CODE:
		if ( inv_stash(sv) ) {
			RETVAL = items > 1 ? inv_does(aTHX_ sv, ST(1)) : &PL_sv_yes;
		} else {
			RETVAL = &PL_sv_no;
		}
	OUTPUT: RETVAL


SV *
inv_can(sv, method)
	SV *sv
	char *method
	PROTOTYPE: $$
	CODE:
		RETVAL = inv_can_cv(aTHX_ sv, method);
	OUTPUT: RETVAL
