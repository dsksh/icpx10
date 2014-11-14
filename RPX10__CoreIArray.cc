
#include <cfloat>

#include <x10/lang/String.h>

#include "RPX10__CoreIArray.h"

using namespace std;
//using namespace rp;

RTT_CC_DECLS0(RPX10__CoreIArray, "RPX10.CoreIArray", x10aux::RuntimeType::class_kind)
    
RPX10__CoreIArray *RPX10__CoreIArray::_make(x10::lang::String *filename, x10_int n) {
	RPX10__CoreIArray *core = new RPX10__CoreIArray();
    core->initialize(filename, n);
    return core;
}


IntervalVec<x10_long> *RPX10__CoreIArray::getIVFromBox(const rp::Box& box) {
    IntervalArray *iv = IntervalArray::_make(box.scope()->size());

    rp::Scope::const_iterator it = box.scope()->begin();
    for (int i = 0; it != box.scope()->end(); ++i, ++it) {
        rp::Interval intv = box.get_interval(**it);
//cout << i << " === " << (*it)->name() << endl;
        Interval si = Interval::_make(intv.left(), intv.right());
        iv->put(i, si);
    }

    //return iv;
    return reinterpret_cast<IntervalVec<x10_long> *>(iv);
}

void RPX10__CoreIArray::setIVIntoBox(IntervalVec<x10_long>& iv, rp::Box& box) {
    rp::Scope::const_iterator it = box.scope()->begin();
    for (int i = 0; it != box.scope()->end(); ++i, ++it) {
        Interval si = IntervalVec<x10_long>::getOrThrow(&iv, i);
        rp::Interval intv(si.FMGL(left), si.FMGL(right));
        box.set_interval(**it, intv);
    }
}

void RPX10__CoreIArray::setBoxIntoIV(const rp::Box& box, IntervalVec<x10_long>& iv) {
    rp::Scope::const_iterator it = box.scope()->begin();
    for (int i = 0; it != box.scope()->end(); ++i, ++it) {
        rp::Interval intv = box.get_interval(**it);
        Interval si = Interval::_make(intv.left(), intv.right());
        IntervalVec<x10_long>::put(&iv, i, si);
    }
}


BAPSolver__Core<x10_long>::itable<RPX10__CoreIArray>  RPX10__CoreIArray::_itable_0(
        &RPX10__CoreIArray::contract, 
        &RPX10__CoreIArray::dummyBox, 
        &RPX10__CoreIArray::equals, 
        &RPX10__CoreIArray::getInitialDomain, 
        &RPX10__CoreIArray::hashCode, 
        //&RPX10__Core::initialize, 
        &RPX10__CoreIArray::isProjected, 
        &RPX10__CoreIArray::toString, 
        &RPX10__CoreIArray::typeName );

x10::lang::Any::itable<RPX10__CoreIArray>  RPX10__CoreIArray::_itable_1(
        &RPX10__CoreIArray::equals, 
        &RPX10__CoreIArray::hashCode, 
        &RPX10__CoreIArray::toString, 
        &RPX10__CoreIArray::typeName );

x10aux::itable_entry RPX10__CoreIArray::_itables[3] = 
    {x10aux::itable_entry(&x10aux::getRTT<BAPSolver__Core<x10_long> >, &_itable_0), 
     x10aux::itable_entry(&x10aux::getRTT<x10::lang::Any>, &_itable_1), 
     x10aux::itable_entry(NULL, (void*)x10aux::getRTT<RPX10__CoreIArray>()) };

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
