#include <string>
#include <cfloat>

#include <x10/lang/String.h>

// x10aux::math undefines HUGE_VAL
#define HUGE_VAL (DBL_MAX*DBL_MAX)
#include "realpaver"

#include "RPX10__Solver.h"

using namespace std;
using namespace rp;

RTT_CC_DECLS0(RPX10__Solver, "RPX10.Solver", x10aux::RuntimeType::class_kind)

RPX10__Solver *RPX10__Solver::_make() {
	return new RPX10__Solver();
}

x10_int RPX10__Solver::solve(x10::lang::String *filename) {
	Parser parser(filename->c_str());
	Timer tim;
	bool result;

	try {
		// parsing
	    tim.start();
	    result = parser.parse();
	    tim.stop();
	}
	catch (rp::Exception e) {
		cerr << "Parse error in file " << filename
		     << " at line " << parser.lineno() << endl;
		cerr << "  -> semantic error: " << e.what();
		return EXIT_FAILURE;
	}

	if (!result)
	{
		cerr << "Parse error in file " << filename
		 << " at line " << parser.lineno() << endl;
		cerr << "  -> syntax error: " << parser.token_on_error() << endl;
		return EXIT_FAILURE;
	} 

	// ----------------------------------------------------------------------
	// creation of propagator
	// ----------------------------------------------------------------------
    sp< ControlPropagator> control = new QueueControlPropagator(10);
	sp< Propagator > propag = new Propagator(control);
	FactoryHullBoxOperator facto(10,5);
	FactoryOperator::vector_type vop;
	facto.generate(*parser.problem(),vop);
	propag->insert(vop);
  
    // creation of Newton operator
    FactoryMultiNewtonOperator facto_nwt(10);
    FactoryOperator::vector_type vop_nwt;
    facto_nwt.generate(*parser.problem(),vop_nwt);
  
    // creation of solver contractor
    sp< SequenceOperator > contractor = new SequenceOperator();
    contractor->insert(propag);
    if (vop_nwt.size())
    { 
        contractor->insert(vop_nwt[0]);
    }

    // ----------------------------------------------------------------------
    
    // creation of splitting function
    sp< Split > split = new SplitMidpoint();
    
    // creation of variable selection function
    sp< SplitSelect > select = new SplitSelectRoundRobin(new SplitTestLocal(),
                                 parser.problem()->scope());

    // creation of solver
    Solver solver(parser.problem(),
          contractor,
          split,
          select);

    // solving
    tim.restart();
    while (solver.calculate_next() != Solution::no())
    {
      cout << "Solution " << solver.nsol() << " (" << tim << " s)" << endl
       << *solver.current_solution() << endl << endl; 
    }

    cout << solver.nsol() << " solution(s)" << endl
         << solver.nsplit() << " split(s)" << endl
         << tim << " s" << endl;

    return EXIT_SUCCESS;
}

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
