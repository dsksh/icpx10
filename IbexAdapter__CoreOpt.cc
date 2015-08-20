
#include <cfloat>

#include <x10/lang/String.h>

#include "ibex_Ctc3BCid.h"
#include "ibex_CtcAcid.h"
#include "ibex_CtcCompo.h"
#include "ibex_CtcFixPoint.h"
#include "ibex_CtcForAll.h"
#include "ibex_CtcFwdBwd.h"
#include "ibex_CtcHC4.h"
#include "ibex_CtcMohc.h"
#include "ibex_CtcNewton.h"
#include "ibex_Linear.h"
#include "ibex_LinearException.h"
#include "ibex_SyntaxError.h"
#include "ibex_EmptyBoxException.h"

#include "innerVerification.h"
#include "IbexAdapter__CoreOpt.h"

using namespace std;
using namespace ibex;

RTT_CC_DECLS0(IbexAdapter__CoreOpt, "IbexAdapter.CoreOpt", x10aux::RuntimeType::class_kind)
    
IbexAdapter__CoreOpt *IbexAdapter__CoreOpt::_make() {
	IbexAdapter__CoreOpt *core = new IbexAdapter__CoreOpt();
    //core->initialize(filename, n);
    return core;
}


bool IbexAdapter__CoreOpt::initialize(const char *filename, const int n) {
    cout.precision(16);
//cout << "initialize" << endl;

    ctcPool_.clear();
    lrPool_.clear();

    projSc_.clear();
    paramSc_.clear();

    try {
	    system_ = SystemPtr(new ExtendedSystem(filename));

//cout << system_->nb_var << endl;
        for (int i=0, o=0; i < system_->args.size(); i++) {
//cout << system_->args[i].key << ", \"" << system_->args[i].name << "\"" << endl;
//cout << system_->args[i].dim.dim2 << endl;
            for (int j=0; j < system_->args[i].dim.dim2; j++) {
                string name(system_->args[i].name);
                if (name.substr(0,3) == "ppc") {
                    paramSc_.push_back(o);
                    cyclicSc_.push_back(o);
                } else if (name.substr(0,2) == "pp") {
                    paramSc_.push_back(o);
                } else 
                    projSc_.push_back(o);
                o++;
            }
        }
//cout << projSc_.size() << ", " << paramSc_.size() << ", " << cyclicSc_.size() << endl;

		/* ============================ building contractors ========================= */
		CtcPtr hc4(new CtcHC4(system_->ctrs, 0.01));
        ctcPool_.push_back(hc4);
		CtcPtr hc4_2(new CtcHC4(system_->ctrs, 0.1, true));
        ctcPool_.push_back(hc4_2);
		CtcPtr acid(new CtcAcid(*system_, *hc4_2));
        ctcPool_.push_back(acid);
		LRPtr linear_relax(new LinearRelaxCombo(*system_, LinearRelaxCombo::XNEWTON));
        lrPool_.push_back(linear_relax);
		CtcPtr polytope(new CtcPolytopeHull(*linear_relax, CtcPolytopeHull::ALL_BOX));
        ctcPool_.push_back(polytope);
		CtcPtr polytope_hc4(new CtcCompo(*polytope, *hc4));
        ctcPool_.push_back(polytope_hc4);
		CtcPtr fixpoint(new CtcFixPoint(*polytope_hc4));
        ctcPool_.push_back(fixpoint);
		ctc_ = CtcPtr(new CtcCompo(*hc4, *acid, *fixpoint));

		//ctc_ = CtcPtr(new CtcHC4(*system_, 0.01));

        impact_ = BitSet::all(system_->nb_var);
    }
	catch(ibex::SyntaxError& e) {
		cout << e << endl;
        return false;
    }
    return true;
}


//template<typename K>
IntervalVec<x10_long> *IbexAdapter__CoreOpt::getInitialDomain() {
    //rp::sp<rp::Box> sbx = list_->get_cell()->box;
    return toX10Box(system_->box);
}

//template<typename K>
BAPSolver__Result IbexAdapter__CoreOpt::contract(IntervalVec<x10_long> *iv) {
	if (IntervalVec<x10_long>::size(iv) == 0)
        return BAPSolver__Result::noSolution();

//cout << "contract" << endl;
    //rp::Box box( *list_->get_cell()->box );
    IntervalVector box(IntervalVec<x10_long>::size(iv));
    setToNativeBox(*iv, box);

    try {
        impact_.fill(0, ctc_->nb_var-1);
        ctc_->contract(box, impact_);

    } catch (EmptyBoxException& e) {
        setToX10Box(box, *iv);
        return BAPSolver__Result::noSolution();
    }

    innerResult res = verifyInner(system_->f, projSc_, paramSc_, cyclicSc_,
            box, system_->box, true, -1);

    BAPSolver__Result sr = BAPSolver__Result::unknown();
    if (box.is_empty())
        sr = BAPSolver__Result::noSolution();

    else if (res.regular)
        sr = BAPSolver__Result::inner();
    else if (res.regularJu)
        sr = BAPSolver__Result::regular();

    setToX10Box(box, *iv);
    return sr;
}


IntervalVec<x10_long> *IbexAdapter__CoreOpt::toX10Box(const ibex::IntervalVector& native) {

    IntervalArray *managed = IntervalArray::_make(native.size());
    for (int i(0); i < native.size(); ++i) {
        const ibex::Interval& intv(native[i]);
        ::Interval si = ::Interval::_make(intv.lb(), intv.ub());
        managed->put(i, si);
    }
    return reinterpret_cast<IntervalVec<x10_long> *>(managed);
}

void IbexAdapter__CoreOpt::setToNativeBox(IntervalVec<x10_long>& managed, 
                                        ibex::IntervalVector& native) {
    for (int i(0); i < ::IntervalVec<x10_long>::size(&managed); ++i) {
        ::Interval si = ::IntervalVec<x10_long>::getOrThrow(&managed, i);
        ibex::Interval intv(si.FMGL(left), si.FMGL(right));
        native[i] = intv;
    }
}

void IbexAdapter__CoreOpt::setToX10Box(const ibex::IntervalVector& native, 
                                     IntervalVec<x10_long>& managed) {
    for (int i = 0; i < native.size(); ++i) {
        const ibex::Interval& intv(native[i]);
        ::Interval si = ::Interval::_make(intv.lb(), intv.ub());
        IntervalVec<x10_long>::put(&managed, i, si);
    }
}


BAPSolver__Core<x10_long>::itable<IbexAdapter__CoreOpt>  IbexAdapter__CoreOpt::_itable_0(
        &IbexAdapter__CoreOpt::contract, 
        &IbexAdapter__CoreOpt::dummyBox, 
        &IbexAdapter__CoreOpt::equals, 
        &IbexAdapter__CoreOpt::finalize, 
        &IbexAdapter__CoreOpt::getInitialDomain, 
        &IbexAdapter__CoreOpt::hashCode, 
        &IbexAdapter__CoreOpt::initialize, 
        &IbexAdapter__CoreOpt::isProjected, 
        &IbexAdapter__CoreOpt::toString, 
        &IbexAdapter__CoreOpt::typeName );

x10::lang::Any::itable<IbexAdapter__CoreOpt>  IbexAdapter__CoreOpt::_itable_1(
        &IbexAdapter__CoreOpt::equals, 
        &IbexAdapter__CoreOpt::hashCode, 
        &IbexAdapter__CoreOpt::toString, 
        &IbexAdapter__CoreOpt::typeName );

x10aux::itable_entry IbexAdapter__CoreOpt::_itables[3] = 
    {x10aux::itable_entry(&x10aux::getRTT<BAPSolver__Core<x10_long> >, &_itable_0), 
     x10aux::itable_entry(&x10aux::getRTT<x10::lang::Any>, &_itable_1), 
     x10aux::itable_entry(NULL, (void*)x10aux::getRTT<IbexAdapter__CoreOpt>()) };

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
