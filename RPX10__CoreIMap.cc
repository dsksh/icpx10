
#include <cfloat>

#include <x10/lang/String.h>

// x10aux::math undefines HUGE_VAL
#ifndef HUGE_VAL
#define HUGE_VAL (DBL_MAX*DBL_MAX)
#endif
#include "realpaver"

#include "Interval.h"
#include "IntervalMap.h"
#include "IntervalArray.h"
#include "RPX10__CoreIMap.h"

using namespace std;
//using namespace rp;

RTT_CC_DECLS0(RPX10__CoreIMap, "RPX10.CoreIMap", x10aux::RuntimeType::class_kind)
    
RPX10__CoreIMap *RPX10__CoreIMap::_make() {
	return new RPX10__CoreIMap();
}


IntervalVec<x10::lang::String *> *RPX10__CoreIMap::getIVFromBox(const rp::Box& box) {
    IntervalMap *iv = IntervalMap::_make();

    rp::Scope::const_iterator it = box.scope()->begin();
    for (; it != box.scope()->end(); ++it) {
        rp::Interval i = box.get_interval(**it);
        Interval si = Interval::_make(i.left(), i.right());
        iv->put(x10::lang::String::_make((*it)->name().c_str(), true), si);
    }

    //return iv;
    return reinterpret_cast<IntervalVec<x10::lang::String *> *>(iv);
}

void RPX10__CoreIMap::setIVIntoBox(IntervalVec<x10::lang::String *>& iv, rp::Box& box) {
    rp::Scope::const_iterator it = box.scope()->begin();
    for (; it != box.scope()->end(); ++it) {
        Interval si = IntervalVec<x10::lang::String *>::getOrThrow(&iv, x10::lang::String::_make((*it)->name().c_str(), true));
        rp::Interval i(si.FMGL(left), si.FMGL(right));
        box.set_interval(**it, i);
    }
}

void RPX10__CoreIMap::setBoxIntoIV(const rp::Box& box, IntervalVec<x10::lang::String *>& iv) {
    rp::Scope::const_iterator it = box.scope()->begin();
    for (; it != box.scope()->end(); ++it) {
        rp::Interval intv = box.get_interval(**it);
        Interval si = Interval::_make(intv.left(), intv.right());
        IntervalVec<x10::lang::String *>::put(&iv, x10::lang::String::_make((*it)->name().c_str(), true), si);
    }
}


Solver__Core<x10::lang::String*>::itable<RPX10__CoreIMap>  RPX10__CoreIMap::_itable_0(
        &RPX10__CoreIMap::contract, 
        &RPX10__CoreIMap::equals, 
        &RPX10__CoreIMap::getInitialDomain, 
        &RPX10__CoreIMap::hashCode, 
        &RPX10__CoreIMap::initialize, 
        &RPX10__CoreIMap::toString, 
        &RPX10__CoreIMap::typeName );

x10::lang::Any::itable<RPX10__CoreIMap>  RPX10__CoreIMap::_itable_1(
        &RPX10__CoreIMap::equals, 
        &RPX10__CoreIMap::hashCode, 
        &RPX10__CoreIMap::toString, 
        &RPX10__CoreIMap::typeName );

x10aux::itable_entry RPX10__CoreIMap::_itables[3] = 
    {x10aux::itable_entry(&x10aux::getRTT<Solver__Core<x10::lang::String*> >, &_itable_0), 
     x10aux::itable_entry(&x10aux::getRTT<x10::lang::Any>, &_itable_1), 
     x10aux::itable_entry(NULL, (void*)x10aux::getRTT<RPX10__CoreIMap>()) };

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
