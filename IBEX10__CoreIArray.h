#ifndef IBEX10__CORE_H
#define IBEX10__CORE_H

#include <memory>
#include <vector>

#include <boost/shared_ptr.hpp>

#include "ibex.h"
#include "ibex_Ctc.h"
#include "ibex_Pdc.h"
#include "ibex_Bsc.h"
#include "ibex_CellBuffer.h"
#include "ibex_SubPaving.h"
#include "ibex_Timer.h"
#include "ibex_Exception.h"

#include "Interval.h"
#include "IntervalVec.h"
#include "IntervalArray.h"
#include "BAPSolver__Result.h"
#include "BAPSolver__Core.h"

#include "util.h"

class IBEX10__CoreIArray : public x10::lang::X10Class {
	typedef std::auto_ptr<ibex::System> SystemPtr;
	typedef boost::shared_ptr<ibex::Ctc> CtcPtr;
	typedef std::vector<CtcPtr> CtcPtrVec;
	typedef boost::shared_ptr<ibex::LinearRelax> LRPtr;
	typedef std::vector<LRPtr> LRPtrVec;
	//typedef boost::shared_ptr<ibex::Bsc> BscPtr;
	//typedef boost::shared_ptr<ibex::CellBuffer> BufferPtr;

public:
    RTT_H_DECLS_CLASS

	IBEX10__CoreIArray() { }
	//~IBEX10__CoreIArray() { }

    static x10aux::itable_entry _itables[3];
    virtual x10aux::itable_entry *_getITables() { return _itables; }
    static BAPSolver__Core<x10_long>::itable<IBEX10__CoreIArray> _itable_0;
    static x10::lang::Any::itable<IBEX10__CoreIArray> _itable_1;

    // X10 serialization requires these functions be stubbed out.
    // We never intend to serialize instances of SatX10_Solver or
    // its subclasses, so stub them out here to raise errors if they
    // are called.
    virtual x10aux::serialization_id_t _get_serialization_id() { abort(); return -1; }
    virtual void _serialize_body(x10aux::serialization_buffer &) { abort(); }

    static IBEX10__CoreIArray *_make(x10::lang::String *filename, x10_int n);

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

    virtual IntervalVec<x10_long> *getInitialDomain();
	virtual BAPSolver__Result contract(IntervalVec<x10_long> *box);

    virtual x10_boolean isProjected(x10_long v) {
//#if RPX_PROJ
//		return v < proj_sc->size();
//#else
//		return false;
//#endif
		for (int i=0; i < projSc_.size(); i++)
			if (projSc_[i] == v) return true;
		return false;

	}

	virtual IntervalVec<x10_long> *dummyBox() {
    	return reinterpret_cast<IntervalVec<x10_long> *>(IntervalArray::_make(x10_long(0)));
	}


protected:
	virtual IntervalVec<x10_long> *toX10Box(const ibex::IntervalVector& native);
	virtual void setToNativeBox(IntervalVec<x10_long>& managed, ibex::IntervalVector& native);
	virtual void setToX10Box(const ibex::IntervalVector& native, IntervalVec<x10_long>& managed);

	SystemPtr system_;

	CtcPtr ctc_;
	CtcPtrVec ctcPool_;
	LRPtrVec lrPool_;
	//BscPtr bsc_;
	//BufferPtr buffer_;
	
	Scope projSc_;
	Scope paramSc_;
	Scope cyclicSc_;

	ibex::BitSet impact_;
};

#endif // IBEX10__CORE_H

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
