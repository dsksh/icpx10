
#include "RPX10__CoreProj.h"

#include "propagator.h"

const static int MaxDim(6);

using namespace std;
using namespace rp;


bool output_stat = false;
double max_time = 2048;
double t_base = 2;
double max_volume = -1;
bool check_volume_16 = false;
double max_rss = -1;
int max_sols = -1;

bool take_infl_box = false;
int infl_trial = -1;

double prec;
int op_id;
double ratio;
double nbors_thres = 1;

unsigned int prob_id;

bool discard_inner_test = 0;
int split_select;
int split_test;

string xl[MaxDim], xu[MaxDim], yl[MaxDim], yu[MaxDim];
bool yc[MaxDim];


void def_problem(sp<Problem> problem, sp<Scope> proj_sc, sp<Scope> param_sc,
                 sp<IntervalFunctionVector> if_vec,
                 sp<Scope> cyclic_sc,
                 sp<IntervalFunctionVector> constr_if)
{
    // variable declarations:
    sp<Variable> x[MaxDim], y[MaxDim], su[MaxDim];

    x[0] = sp<Variable>(new RealVariable("x1", Interval('['+xl[0]+','+xu[0]+']'),
                                         prec, false, true));
    x[1] = sp<Variable>(new RealVariable("x2", Interval('['+xl[1]+','+xu[1]+']'),
                                         prec, false, true));
    x[2] = sp<Variable>(new RealVariable("x3", Interval('['+xl[2]+','+xu[2]+']'),
                                         prec, false, true));

    y[0] = sp<Variable>(new RealVariable("y1", Interval('['+yl[0]+','+yu[0]+']'),
                                         prec*1, false, true));
    y[1] = sp<Variable>(new RealVariable("y2", Interval('['+yl[1]+','+yu[1]+']'),
                                         prec*1, false, true));
    y[2] = sp<Variable>(new RealVariable("y3", Interval('['+yl[2]+','+yu[2]+']'),
                                         prec, false, true));
    //y[3] = sp<Variable>(new RealVariable("y4", Interval("[-1,1]"), 
    //                                   prec, false, true));
    //y[3] = sp<Variable>(new RealVariable("y4", Interval('['+yl[3]+','+yu[3]+']'),
    //                                     prec, false, true));
    //y[4] = sp<Variable>(new RealVariable("y5", Interval('['+yl[3]+','+yu[3]+']'),
    //                                     prec, false, true));
    //y[5] = sp<Variable>(new RealVariable("y6", Interval('['+yl[3]+','+yu[3]+']'),
    //                                     prec, false, true));

    // constraint:
    sp<Term> f[MaxDim];
    int dim(2), dim_x(2), dim_f(2);
    switch (prob_id) {
    case 0: { // Simple (1x1)
        dim = dim_x = 1;
        //f[0] = new Term(Interval(1.0, 1.5) - sqr(x1) - sqr(y[0]));
        //f[0] = new Term(Interval(1.0) - sqr(x[0]) - sqr(y[0]));

        f[0] = new Term(sqr(x[0] + cos(3*y[0])) + sqr(y[0] + 1.0) - Interval(1.0));
        //f[0] = new Term(sqr(x[0] + cos(3*y[0])) + sqr(y[0] - 5.0) - Interval(1.0));
        break;
    }

    case 1: { // Sphere (1x1)
        dim = 1;
        f[0] = new Term(sqr(x[0]) + sqr(y[0]) - 1);
        break; 
    }

    case 2: { // Sphere (2x2)
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        break; 
    }

    case 3: { // Sphere (2x3)
        dim = dim_f = 3;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        f[2] = new Term(x[0] + x[1] + y[1] + y[2]);
        break; 
    }

    case 4: { // Sphere (2x4)
        dim = dim_f = 4;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) + sqr(y[3]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        f[2] = new Term(x[0] + x[1] + y[1] + y[2]);
        f[3] = new Term(x[0] + x[1] + y[2] + y[3]);
        //f[1] = new Term(x[0] + x[1] + y[0] + y[1] + y[2]);
        //f[2] = new Term(x[0] + x[1] + y[1] + y[2] + y[3]);
        //f[3] = new Term(x[0] + x[1] + y[2] + y[3] + y[0]);
        break;
    }

    case 5: { // SailBoat (2x2)
        //const Constant As(500);
        const Constant As(100);
        const Constant Ar(300);
        const Constant Af(60);
        const Constant V (10);
        const Constant Rs(1);
        const Constant Rr(2);
        const Constant L (1);

        //f[0] = new Term(As*(V*cos(x[1]+y[1]) - x[0]*sin(y[1]))*sin(y[1])
        //          - Ar*x[0]*sqr(sin(y[0])) - Af*x[0]);
        //f[1] = new Term(As*(V*cos(x[1]+y[1]) - x[0]*sin(y[1]))*(L - Rs*cos(y[1]))
        //          - Rr*Ar*x[0]*sin(y[0])*cos(y[0]));

        Term Fs( As*(V*cos(x[1]+y[1]) - x[0]*sin(y[1])) );
        Term Fr( Ar*x[0]*sin(y[0]) ); 

        f[0] = new Term(Fs*sin(y[1]) - Fr*sin(y[0]) - Af*x[0]);
        f[1] = new Term(Fs*(L - Rs*cos(y[1])) - Fr*Rr*cos(y[0]));
        break; 
    }

    case 6: { // Robot (2x2)
        const Constant L (2);
        const Constant Cx(3);
        const Constant Cy(1);
        const Constant R (1);

        f[0] = new Term(x[0] - (y[0] + L*cos(y[1])));
        f[1] = new Term(x[1] - (y[0] + L*sin(y[1])));

        //Term constr_f(sqr(x[0]-Cx) + sqr(x[1]-Cy) - R);
        //Term constr_f(Cx);
        sp<Term> cf = new Term(sqr(x[0]-Cx) + sqr(x[1]-Cy) - R);
        //constr_if = sp<IntervalFunction>(new IntervalFunction(Cx));
        constr_if->insert(new IntervalFunction(cf));

        break;
    }

    case 7: { // RR-RRR (2x2)
        const Constant M(9.0);
        const Constant L1(8.0);
        const Constant L2(5.0);
        const Constant L3(5.0);
        const Constant L4(8.0);

        f[0] = new Term(  sqr(x[0] - L1*cos(y[0]))
                        + sqr(x[1] - L1*sin(y[0]))
                        - sqr(L2));
        f[1] = new Term(  sqr(x[0] - L2*cos(y[1]) - M)
                        + sqr(x[1] - L2*sin(y[1]))  
                        - sqr(L4));
        break;
    }

    case 8: { // RR-RRR (2x2)
        const Constant M(9.0);
        const Constant L1(8.0);
        const Constant L2(5.0);
        const Constant L3(5.0);
        const Constant L4(8.0);

        f[0] = new Term(  sqr(y[0] - L1*cos(x[0]))
                        + sqr(y[1] - L1*sin(x[0]))
                        - sqr(L2));
        f[1] = new Term(  sqr(y[0] - L2*cos(x[1]) - M)
                        + sqr(y[1] - L2*sin(x[1]))  
                        - sqr(L4));
        break;
    }

    case 9: { // 3-RRR (2x4)
        dim = dim_f = 3;

        static const Constant AX1(-10.0);
        static const Constant AY1(-10.0);
        static const Constant AX2( 10.0);
        static const Constant AY2(-10.0);
        static const Constant AX3(  0.0);
        static const Constant AY3( 10.0);
        static const Constant CX1(  0.0);
        static const Constant CY1(  0.0);
        static const Constant CX2( 10.0);
        static const Constant CY2(  0.0);
        static const Constant CX3( 10.0);
        static const Constant CY3( 10.0);
        static const Constant L1(10.0);
        static const Constant L2(10.0);
        static const Constant L3(10.0);
        static const Constant M1(10.0);
        static const Constant M2(10.0);
        static const Constant M3(10.0);

        f[0] = new Term(  sqr(x[0] + CX1*cos(y[3]) - CY1*sin(y[3]) - AX1 - L1*cos(y[0]))
                        + sqr(x[1] + CX1*sin(y[3]) + CY1*cos(y[3]) - AY1 - L1*sin(y[0]))
                        - sqr(M1));
        f[1] = new Term(  sqr(x[0] + CX2*cos(y[3]) - CY2*sin(y[3]) - AX2 - L2*cos(y[1]))
                        + sqr(x[1] + CX2*sin(y[3]) + CY2*cos(y[3]) - AY2 - L2*sin(y[1]))
                        - sqr(M2));
        f[2] = new Term(  sqr(x[0] + CX3*cos(y[3]) - CY3*sin(y[3]) - AX3 - L3*cos(y[2]))
                        + sqr(x[1] + CX3*sin(y[3]) + CY3*cos(y[3]) - AY3 - L3*sin(y[2]))
                        - sqr(M3));
        break;
    }

    default:
        dim = dim_f = 3;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) - sqr(Constant(1)));
        f[1] = new Term(sqr(x[0]) - x[1]);
        f[2] = new Term(sin(x[1]) - x[2]);
    }

    // insert variables
    for (int i(0); i < dim; ++i) {
        problem->insert_var(y[i]);
        param_sc->insert(y[i]);
        if (yc[i]) cyclic_sc->insert(y[i]);

        if (i < dim_x) {
            problem->insert_var(x[i]);
            proj_sc->insert(x[i]);
        }

#if SETDIFF_PROVED || SETDIFF_EXTRACT || MANAGE_HIDDEN_NEIGHBORS
        y[i]->set_projected(false);
        if (i < dim_x)
            x[i]->set_projected(true);
#endif

        if (i < dim_f) {
            problem->insert_ctr( new RealConstraint(rp::operator==(*f[i], Constant(0.0))) );
            if_vec->insert( new IntervalFunction(*f[i]) );
        }
    }
}


void RPX10__CoreProj::initialize(const char *filename) {
    /*rp::Parser parser(filename);
	//Timer tim;
	bool result;

	try {
		// parsing
	    //tim.start();
	    result = parser.parse();
	    //tim.stop();
	}
	catch (rp::Exception e) {
		cerr << "Parse error in file " << filename
		     << " at line " << parser.lineno() << endl;
		cerr << "  -> semantic error: " << e.what();
		//return EXIT_FAILURE;
        return;
	}

	if (!result) {
		cerr << "Parse error in file " << filename
		     << " at line " << parser.lineno() << endl;
		cerr << "  -> syntax error: " << parser.token_on_error() << endl;
		//return EXIT_FAILURE;
        return;
	} 
    */

    //sp<Problem> problem(new Problem());
    //sp<Scope> proj_sc(new Scope());
    //sp<Scope> param_sc(new Scope());
    //sp<Scope> cyclic_sc(new Scope());
    sp<IntervalFunctionVector> if_vec(new IntervalFunctionVector());
    // TODO
    //sp<IntervalFunction> constr_if;
    sp<IntervalFunctionVector> constr_if(new IntervalFunctionVector());


    //cmd = "solve";
    /*prob_id = 0;
    prec = 1E-1;
    op_id = 4;

    xl[0] = "-10"; xu[0] = "10";
    xl[1] = "0"; xu[1] = "0";
    xl[2] = "0"; xu[2] = "0";
    xl[3] = "0"; xu[3] = "0";
    yl[0] = "-10"; yu[0] = "10";
    yl[1] = "0"; yu[1] = "0";
    yl[2] = "0"; yu[2] = "0";
    yl[3] = "0"; yu[3] = "0";
    */
    prob_id = 2;
    prec = 1E-1;
    op_id = 4;

    xl[0] = "-1"; xu[0] = "1";
    xl[1] = "-1"; xu[1] = "1";
    xl[2] = "-10"; xu[2] = "10";
    xl[3] = "-10"; xu[3] = "10";
    yl[0] = "-1"; yu[0] = "1";
    yl[1] = "-1"; yu[1] = "1";
    yl[2] = "0"; yu[2] = "0";
    yl[3] = "0"; yu[3] = "0";


    def_problem(problem, proj_sc, param_sc, if_vec, cyclic_sc, constr_if);
    
	// ----------------------------------------------------------------------
	// creation of propagator
	// ----------------------------------------------------------------------
    sp<BoxEval> evaluator = 
        new BoxEval();
        //new BoxEvalSumDistance();
        //new BoxEvalFactorWidth();

    sp<ControlPropagator> control(new QueueControlPropagator(10, evaluator));
    //sp<Propagator> contractor = new Propagator(control);
    sp<Propagator> contractor;
    if (prob_id == 6 || prob_id == 14)
        contractor = new PropagatorDomainConstraint(
            control, proj_sc, param_sc, cyclic_sc, if_vec, nbors_thres,
            take_infl_box,
            infl_trial,
            (*constr_if)[0]);
    else
        contractor = new PropagatorWithAspectDetection(
            control, proj_sc, param_sc, cyclic_sc, if_vec, nbors_thres,
            take_infl_box, infl_trial );

    FactoryOperator::vector_type vop;
    FactoryHullOperator facto_hull;
    FactoryBoxOperator facto_box(10,false,5);
    FactoryMultiNewtonOperator facto_nwt(10,5);

    facto_hull.generate(*problem,vop);
    facto_box.generate(*problem,vop);

    contractor->insert(vop);

    // ----------------------------------------------------------------------
    
    // creation of splitting function
    //sp< Split > split = new SplitMidpoint();
    
    // creation of variable selection function
    //sp< SplitSelect > select = new SplitSelectRoundRobin(new SplitTestLocal(),
    //                             parser.problem()->scope());

    // creation of solver
    //Solver solver(parser.problem(), contractor, split, select);

    nsol_ = 0;
    nsplit_ = 0;
    currentSol_ = 0;
    contractor_ = contractor;

    split_ = new rp::SplitMidpoint();
    selector_ = new rp::SplitSelectRoundRobin(new rp::SplitTestLocal(), problem->scope());
    list_ = new rp::SearchStrategyDFS();
    list_->insert(new rp::Box(problem->scope()), selector_, 0);
    list_->init();
}

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab