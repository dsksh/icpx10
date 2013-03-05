#ifndef RPX10__Solver_h
#define RPX10__Solver_h

//#include <x10aux/config.h>
//#include <x10aux/RTT.h>
//#include <x10aux/fun_utils.h>
//#include "x10/lang/VoidFun_0_1.h"
//#include "x10/lang/Fun_0_0.h"
#include <x10/lang/X10Class.h>

class RPX10__Solver : public x10::lang::X10Class {
public:
    RTT_H_DECLS_CLASS

    // X10 serialization requires these functions be stubbed out.
    // We never intend to serialize instances of SatX10_Solver or
    // its subclasses, so stub them out here to raise errors if they
    // are called.
    virtual x10aux::serialization_id_t _get_serialization_id() { abort(); return -1; }
    virtual void _serialize_body(x10aux::serialization_buffer &) { abort(); }

	RPX10__Solver() {}
	~RPX10__Solver() {}

    static RPX10__Solver* _make();

	x10_int solve(x10::lang::String *);
};

#endif // RPX10__Solver_h 
