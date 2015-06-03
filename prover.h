#ifndef PROVER_H
#define PROVER_H

#include "ibex.h"

#include "util.h"

struct innerResult {
    innerResult()
    : regular(false), regularJu(false), cond(0)
    {}

    bool regular;
    bool regularJu;

    double cond;
};

bool regular(const ibex::IntervalMatrix& J);

/// inner box verification
innerResult verifyInner(ibex::IntervalVector& box, const ibex::IntervalVector& box_dom0, 
                        const Scope& proj_sc, const Scope& param_sc, 
                        const Scope& cyclic_sc, 
                        ibex::Function& fun,
                        bool reduce_box, int infl_trial);

#endif // PROVER_H

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
