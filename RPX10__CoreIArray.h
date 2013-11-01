#ifndef RPX10__CORE_IARRAY_H
#define RPX10__CORE_IARRAY_H

#include "Interval.h"
#include "IntervalVec.h"
#include "IntervalArray.h"
#include "BAPSolver__Result.h"
#include "BAPSolver__Core.h"

#include "RPX10__CoreEx.h"

class RPX10__CoreIArray : public x10::lang::X10Class, public RPX10__CoreEx<x10_int> {
public:
    RTT_H_DECLS_CLASS

	RPX10__CoreIArray() : RPX10__CoreEx<x10_int>() { }
	//~RPX10__CoreIArray() { }

    static x10aux::itable_entry _itables[3];
    virtual x10aux::itable_entry *_getITables() { return _itables; }
    static BAPSolver__Core<x10_int>::itable<RPX10__CoreIArray> _itable_0;
    static x10::lang::Any::itable<RPX10__CoreIArray> _itable_1;

    // X10 serialization requires these functions be stubbed out.
    // We never intend to serialize instances of SatX10_Solver or
    // its subclasses, so stub them out here to raise errors if they
    // are called.
    virtual x10aux::serialization_id_t _get_serialization_id() { abort(); return -1; }
    virtual void _serialize_body(x10aux::serialization_buffer &) { abort(); }

    static RPX10__CoreIArray *_make(x10::lang::String *filename, x10_int n);

    virtual x10_boolean isProjected(x10_int v) {
#if RPX_PROJ
		return v < proj_sc->size();
#else
		return false;
#endif
	}

	virtual IntervalVec<x10_int> *dummyBox() {
    	return reinterpret_cast<IntervalVec<x10_int> *>(IntervalArray::_make(0));
	}


protected:
	virtual IntervalVec<x10_int> *getIVFromBox(const rp::Box& box);
	virtual void setIVIntoBox(IntervalVec<x10_int>& iv, rp::Box& box);
	virtual void setBoxIntoIV(const rp::Box& box, IntervalVec<x10_int>& iv);
};

#endif // RPX10__CORE_IARRAY_H
