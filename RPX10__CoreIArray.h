#ifndef RPX10__COREIARRAY_H
#define RPX10__COREIARRAY_H

#include <x10rt.h>

// x10aux::math undefines HUGE_VAL
#ifndef DBL_MAX
#define DBL_MAX 1.7976931348623158e+308
#endif
#ifndef HUGE_VAL
#define HUGE_VAL (DBL_MAX*DBL_MAX)
#endif

#include "rp_propagator.h"
#include "rp_problem.h"
#include "rp_split.h"
#include "rp_split_select.h"
#include "rp_search_strategy.h"
#include "rp_exception.h"

#include "Interval.h"
#include "IntervalVec.h"
#include "IntervalArray.h"
#include "Solver__Result.h"
#include "Solver__Core.h"

class RPX10__CoreIArray : public x10::lang::X10Class {
public:
    RTT_H_DECLS_CLASS

    static x10aux::itable_entry _itables[3];
    virtual x10aux::itable_entry* _getITables() { return _itables; }
    static Solver__Core<x10_int>::itable<RPX10__CoreIArray> _itable_0;
    static x10::lang::Any::itable<RPX10__CoreIArray> _itable_1;

    // X10 serialization requires these functions be stubbed out.
    // We never intend to serialize instances of SatX10_Solver or
    // its subclasses, so stub them out here to raise errors if they
    // are called.
    virtual x10aux::serialization_id_t _get_serialization_id() { abort(); return -1; }
    virtual void _serialize_body(x10aux::serialization_buffer &) { abort(); }

    void _constructor() {}

    static RPX10__CoreIArray *_make();

	virtual void initialize(x10::lang::String *);

    virtual IntervalVec<x10_int> *getInitialDomain();

	virtual x10_int solve();

    /**
     * @return the solution flag of the next solution, Solution::no()
     * if there is no solution at all
     */
	virtual rp::Solution calculateNext();

	virtual Solver__Result contract(IntervalVec<x10_int> *box);

    /**
     * @return the next solution
     */
	virtual rp::sp<rp::Box> currentSolution() const {
   		return currentSol_;
	}

    /**
     * @return the number of computed solutions
     */
    virtual int nsol() const {
	    return nsol_;
	}

    /**
     * @return the number of splitting steps
     */
    virtual int nsplit() const {
	    return nsplit_;
  	}

protected:
	rp::sp<rp::BoxCell> extract();
    void postProcess(const rp::Solution& sol, rp::sp<rp::Box> sbx);

#if SETDIFF_EXTRACT
    void sdPrune     (rp::BoxCell& cell);
    void sdPruneCheap(rp::Box& sbx);
#endif

#if MANAGE_NEIGHBORS || MANAGE_HIDDEN_NEIGHBORS
    void updateNeighbors(const rp::Solution& sol, rp::BoxCell& cell);
#endif

#if SETDIFF_EXTRACT || MANAGE_HIDDEN_NEIGHBORS
	rp::BoxVec solutions;
#endif

private:
	rp::sp<rp::Operator> contractor_;
    rp::sp<rp::Split> split_;
    rp::sp<rp::SplitSelect> selector_;
    rp::sp<rp::SearchStrategy> list_;

    int nsol_;   // number of computed solutions
    int nsplit_; // number of splitting steps

	rp::sp<rp::Box> currentSol_;
};

#endif // RPX10__COREIARRAY_H
