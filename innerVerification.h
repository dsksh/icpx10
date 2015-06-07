#ifndef INNER_VERIFICATION_H
#define INNER_VERIFICATION_H

#include "ibex.h"
#include "ibex_Interval.h"
#include "ibex_IntervalVector.h"
#include "ibex_Function.h"

#include "util.h"

struct innerResult {
    innerResult()
    : regular(false), regularJu(false), cond(0)
    {}

    bool regular;
    bool regularJu;

    double cond;
};

bool regular(const ibex::IntervalMatrix&);

/// inner box verification
innerResult verifyInner(ibex::Function&,
                        const Scope&, const Scope&, const Scope&, 
                        ibex::IntervalVector&, const ibex::IntervalVector&, 
                        bool, int );

#endif // INNER_VERIFICATION_H

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
