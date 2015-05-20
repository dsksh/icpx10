
#include <cfloat>

#include <x10/lang/String.h>

#include "IBEX10__CoreIArray.h"

using namespace std;
//using namespace rp;
using namespace ibex;

RTT_CC_DECLS0(IBEX10__CoreIArray, "IBEX10.Core", x10aux::RuntimeType::class_kind)
    
IBEX10__CoreIArray *IBEX10__CoreIArray::_make(x10::lang::String *filename, x10_int n) {
	IBEX10__CoreIArray *core = new IBEX10__CoreIArray();
    core->initialize(filename, n);
    return core;
}


void IBEX10__CoreIArray::initialize(const char *filename, const int n) {
    cout.precision(16);
cout << "initialize" << endl;

    try {
	    system_ = SystemPtr(new System(filename));

		/* ============================ building contractors ========================= */
		//Ctc *hc4(new CtcHC4(*system_, 0.01));
		//Ctc *hc4_2(new CtcHC4(*system_, 0.1, true));
		//Ctc *acid(new CtcAcid(*system_, *hc4_2));
		//Ctc *newton(new CtcNewton(system_->f, 5e+08, 1e-08, 1e-04));
		//LinearRelax *linear_relax(new LinearRelaxCombo(*system_, LinearRelaxCombo::COMPO));
		//Ctc *polytope(new CtcPolytopeHull(*linear_relax, CtcPolytopeHull::ALL_BOX));
		//Ctc *polytope_hc4(new CtcCompo(*polytope, *hc4));
		//Ctc *fixpoint(new CtcFixPoint(*polytope_hc4));
		//ctc_ = CtcPtr(new CtcCompo(*hc4, *acid, *newton, *fixpoint));
        
		ctc_ = CtcPtr(new CtcHC4(*system_, 0.01));

		/* Create a bisection heuristic. */
		//SmearSumRelative bisector(sys, prec);
		//bsc_ = BscPtr(new RoundRobin(1e-8));
	
		/* Create a "stack of boxes" (CellStack) (depth-first search). */
		//buffer_ = BufferPtr(new CellStack());
	
		/* Create a solver with the previous objects */
		//Solver s(compo, bisector, buff);
        //
		//s.time_limit = 10.;
		//s.trace = 1;  // the solutions are printed when they are found
        
        impact_ = BitSet::all(system_->nb_var);
    }
	catch(ibex::SyntaxError& e) {
		cout << e << endl;
    }
}


//template<typename K>
IntervalVec<x10_long> *IBEX10__CoreIArray::getInitialDomain() {
    //rp::sp<rp::Box> sbx = list_->get_cell()->box;
cout << "getID" << endl;
    return getIVFromBox(system_->box);
}

//template<typename K>
BAPSolver__Result IBEX10__CoreIArray::contract(IntervalVec<x10_long> *iv) {
	if (IntervalVec<x10_long>::size(iv) == 0)
        return BAPSolver__Result::noSolution();

cout << "contract" << endl;
    //rp::Box box( *list_->get_cell()->box );
    IntervalVector box(IntervalVec<x10_long>::size(iv));
    setIVIntoBox(*iv, box);
cout << "c0" << endl;

    try {

        impact_.fill(0, ctc_->nb_var-1);
cout << "c1" << endl;

        ctc_->contract(box, impact_);

    } catch (EmptyBoxException& e) {
cout << "c done0" << endl;
        setBoxIntoIV(box, *iv);
cout << "c done00" << endl;
        return BAPSolver__Result::noSolution();
    }

cout << "c done1" << endl;
    setBoxIntoIV(box, *iv);
cout << "c done11" << endl;
    return BAPSolver__Result::unknown();
}


IntervalVec<x10_long> *IBEX10__CoreIArray::getIVFromBox(const ibex::IntervalVector& box) {
    IntervalArray *iv = IntervalArray::_make(box.size());

    for (int i(0); i < box.size(); ++i) {
        const ibex::Interval& intv(box[i]);
        ::Interval si = ::Interval::_make(intv.lb(), intv.ub());
        iv->put(i, si);
    }

    return reinterpret_cast<IntervalVec<x10_long> *>(iv);
}

void IBEX10__CoreIArray::setIVIntoBox(IntervalVec<x10_long>& iv, ibex::IntervalVector& box) {
    for (int i(0); i < box.size(); ++i) {
        ::Interval si = ::IntervalVec<x10_long>::getOrThrow(&iv, i);
        ibex::Interval intv(si.FMGL(left), si.FMGL(right));
        box[i] = intv;
    }
}

void IBEX10__CoreIArray::setBoxIntoIV(const ibex::IntervalVector& box, 
                                IntervalVec<x10_long>& iv) {
    for (int i = 0; i < box.size(); ++i) {
        const ibex::Interval& intv(box[i]);
        ::Interval si = ::Interval::_make(intv.lb(), intv.ub());
        IntervalVec<x10_long>::put(&iv, i, si);
    }
}


BAPSolver__Core<x10_long>::itable<IBEX10__CoreIArray>  IBEX10__CoreIArray::_itable_0(
        &IBEX10__CoreIArray::contract, 
        &IBEX10__CoreIArray::dummyBox, 
        &IBEX10__CoreIArray::equals, 
        &IBEX10__CoreIArray::finalize, 
        &IBEX10__CoreIArray::getInitialDomain, 
        &IBEX10__CoreIArray::hashCode, 
        &IBEX10__CoreIArray::isProjected, 
        &IBEX10__CoreIArray::toString, 
        &IBEX10__CoreIArray::typeName );

x10::lang::Any::itable<IBEX10__CoreIArray>  IBEX10__CoreIArray::_itable_1(
        &IBEX10__CoreIArray::equals, 
        &IBEX10__CoreIArray::hashCode, 
        &IBEX10__CoreIArray::toString, 
        &IBEX10__CoreIArray::typeName );

x10aux::itable_entry IBEX10__CoreIArray::_itables[3] = 
    {x10aux::itable_entry(&x10aux::getRTT<BAPSolver__Core<x10_long> >, &_itable_0), 
     x10aux::itable_entry(&x10aux::getRTT<x10::lang::Any>, &_itable_1), 
     x10aux::itable_entry(NULL, (void*)x10aux::getRTT<IBEX10__CoreIArray>()) };

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
