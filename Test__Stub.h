#ifndef Test__Stub_h
#define Test__Stub_h

//#include <x10aux/config.h>
#include <x10aux/RTT.h>
//#include <x10aux/fun_utils.h>
//#include "x10/lang/VoidFun_0_1.h"
//#include "x10/lang/Fun_0_0.h"
#include "x10/lang/X10Class.h"
#include <x10/lang/String.h>

#include <string>

namespace x10 { namespace lang { 
class String;
} } 

//class Test__Stub : public x10::lang::X10Class {
class Test__Stub {
public:
    RTT_H_DECLS_CLASS

	Test__Stub() {}
	~Test__Stub() {}

    static Test__Stub* _make();

	x10::lang::String *hello(void) {
		//return new x10::lang::String();
    	return x10aux::makeStringLit("hoge");
	}
};

#endif // Test__Stub_h

