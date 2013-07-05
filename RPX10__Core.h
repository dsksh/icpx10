#ifndef RPX10__CORE_H
#define RPX10__CORE_H

#include <x10rt.h>

// x10aux::math undefines HUGE_VAL
#ifndef DBL_MAX
#define DBL_MAX 1.7976931348623158e+308
#endif
#ifndef HUGE_VAL
#define HUGE_VAL (DBL_MAX*DBL_MAX)
#endif

#include "rp_box.h"
#include "rp_solution.h"
#include "rp_propagator.h"
#include "rp_search_strategy.h"
#include "rp_problem.h"
#include "rp_split.h"
#include "rp_split_select.h"

class RPX10__Core 
//: public x10::lang::X10Class 
{
public:
	//RPX10__Core() {}
	//~RPX10__Core() {}

	void initialize(const char *);
	void initialize(x10::lang::String *filename) {
   		initialize(filename->c_str());
	}

	x10_int solve();

    /**
     * @return the solution flag of the next solution, Solution::no()
     * if there is no solution at all
     */
	rp::Solution calculateNext();

	//virtual Solver__Result contract(IntervalVec<x10::lang::String *> *box);

    /**
     * @return the next solution
     */
	rp::sp<rp::Box> currentSolution() const {
   		return currentSol_;
	}

    /**
     * @return the number of computed solutions
     */
    int nsol() const {
	    return nsol_;
	}

    /**
     * @return the number of splitting steps
     */
    int nsplit() const {
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

	rp::sp<rp::Operator> contractor_;
    rp::sp<rp::SearchStrategy> list_;
private:
    rp::sp<rp::Split> split_;
    rp::sp<rp::SplitSelect> selector_;

    int nsol_;   // number of computed solutions
    int nsplit_; // number of splitting steps

	rp::sp<rp::Box> currentSol_;
};

#endif // RPX10__CORE_H
