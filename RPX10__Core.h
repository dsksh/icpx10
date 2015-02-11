#ifndef RPX10__CORE_H
#define RPX10__CORE_H

#include <x10rt.h>
#include <x10/lang/String.h>

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

#include "config.h"

#if USE_PAPI
#include <papi.h>
#endif

class RPX10__Core 
//: public x10::lang::X10Class 
{
public:
	//RPX10__Core() {}
	//~RPX10__Core() {}

	virtual void initialize(const char *, const int n);
	void initialize(x10::lang::String *filename, x10_int n) {
   		initialize(filename->c_str(), n);
	}

	void finalize() {
#if USE_PAPI
PAPI_shutdown();
std::cout << "\"papi(" << papi_es << ")\": [";
bool f(true);
for (int i(0); i < PAPI_EN; ++i) {
	if (f) f = false; else std::cout << ",";
	std::cout << papi_result[i];
}
std::cout << "]," << std::endl;
#endif
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

#if USE_PAPI
int papi_es;
long long papi_result[PAPI_EN];
#endif

protected:
    rp::sp<rp::Split> split_;
    rp::sp<rp::SplitSelect> selector_;

    int nsol_;   // number of computed solutions
    int nsplit_; // number of splitting steps

	rp::sp<rp::Box> currentSol_;
};

#endif // RPX10__CORE_H
