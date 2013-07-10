#ifndef RPX10__CORE_PROJ_H
#define RPX10__CORE_PROJ_H

#include <x10rt.h>

#include "RPX10__Core.h"

class RPX10__CoreProj : public RPX10__Core {
public:

	RPX10__CoreProj() 
	: problem(new rp::Problem()),
	  proj_sc(new rp::Scope()),
	  param_sc(new rp::Scope()),
	  cyclic_sc(new rp::Scope())
	{ }
	//~RPX10__CoreProj() { }

	virtual void initialize(const char *);

protected:
    rp::sp<rp::Problem> problem;
    rp::sp<rp::Scope> proj_sc;
    rp::sp<rp::Scope> param_sc;
    rp::sp<rp::Scope> cyclic_sc;
};

#endif // RPX10__CORE_PROJ_H
