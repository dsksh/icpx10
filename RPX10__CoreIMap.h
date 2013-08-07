#ifndef RPX10__CORE_IMAP_H
#define RPX10__CORE_IMAP_H

#include "Interval.h"
#include "IntervalVec.h"
#include "IntervalMap.h"
#include "Solver__Result.h"
#include "Solver__Core.h"

#include "RPX10__CoreEx.h"

class RPX10__CoreIMap : public x10::lang::X10Class, public RPX10__CoreEx<x10::lang::String *> {
public:
    RTT_H_DECLS_CLASS

	RPX10__CoreIMap() : RPX10__CoreEx<x10::lang::String *>() { }
	//~RPX10__CoreIMap() { }

    static x10aux::itable_entry _itables[3];
    virtual x10aux::itable_entry *_getITables() { return RPX10__CoreIMap::_itables; }
    static Solver__Core<x10::lang::String *>::itable<RPX10__CoreIMap> _itable_0;
    static x10::lang::Any::itable<RPX10__CoreIMap> _itable_1;

    // X10 serialization requires these functions be stubbed out.
    // We never intend to serialize instances of SatX10_Solver or
    // its subclasses, so stub them out here to raise errors if they
    // are called.
    virtual x10aux::serialization_id_t _get_serialization_id() { abort(); return -1; }
    virtual void _serialize_body(x10aux::serialization_buffer &) { abort(); }

    void _constructor() {}

    static RPX10__CoreIMap *_make(x10::lang::String *filename, x10_int n);

    virtual x10_boolean isProjected(x10::lang::String *vName) {
#if RPX_PROJ
		rp::sp<rp::Variable> var = proj_sc->find(vName->c_str());
		return var != 0;
#else
		return false;
#endif
	}

	virtual IntervalVec<x10::lang::String *> *dummyBox() {
    	return reinterpret_cast<IntervalVec<x10::lang::String *> *>(IntervalMap::_make());
	}


protected:
	virtual IntervalVec<x10::lang::String *> *getIVFromBox(const rp::Box& box);
	virtual void setIVIntoBox(IntervalVec<x10::lang::String *>& iv, rp::Box& box);
	virtual void setBoxIntoIV(const rp::Box& box, IntervalVec<x10::lang::String *>& iv);
};

#endif // RPX10__CORE_IMAP_H
