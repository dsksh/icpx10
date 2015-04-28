
#include "config.h"

#if USE_PAPI
#include <papi.h>
#endif

#include "RPX10__CoreProj.h"

#include "propagator.h"

const static int MaxDim(16);

using namespace std;
using namespace rp;


bool output_stat = false;
double max_time = 2048;
double t_base = 2;
double max_volume = -1;
bool check_volume_16 = false;
double max_rss = -1;
int max_sols = -1;

bool take_infl_box = true;
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
    for (int i(0); i < MaxDim; ++i) {
        yl[i] = "0"; yu[i] = "0";
    }

    xl[0] = "-1"; xu[0] = "1";
    xl[1] = "-1"; xu[1] = "1";
    xl[2] = "-10"; xu[2] = "10";
    xl[3] = "-10"; xu[3] = "10";
    yl[0] = "-1"; yu[0] = "1";
    yl[1] = "-1"; yu[1] = "1";
    yl[2] = "0"; yu[2] = "0";
    yl[3] = "0"; yu[3] = "0";

    switch (prob_id) {
    case 3: 
    case 4: 
        yl[2] = "-1"; yu[2] = "1";
        yl[3] = "-1"; yu[3] = "1";
		break;
    case 5: 
        xl[0] = "0"; xu[0] = "10";
        xl[1] = "-pi"; xu[1] = "pi";
        yl[0] = "-pi/2"; yu[0] = "pi/2";
        yl[1] = "-pi/2"; yu[1] = "pi/2";
        break;
    case 6: 
        xl[0] = "-10"; xu[0] = "10";
        xl[1] = "-10"; xu[1] = "10";
        yl[0] = "0"; yu[0] = "4";
        yl[1] = "-2"; yu[1] = "2";
        break;
    case 7: 
    case 8: 
        xl[0] = "-20"; xu[0] = "20";
        xl[1] = "-20"; xu[1] = "20";
        yl[0] = "-pi"; yu[0] = "pi"; yc[0] = true;
        yl[1] = "-pi"; yu[1] = "pi"; yc[1] = true;
        break;
    case 11: 
        yl[2] = "-1"; yu[2] = "1";
        yl[3] = "-1"; yu[3] = "1";
        yl[4] = "-1"; yu[4] = "1";
        yl[5] = "-1"; yu[5] = "1";
		break;
    case 12: 
        yl[2] = "-1"; yu[2] = "1";
        yl[3] = "-1"; yu[3] = "1";
        yl[4] = "-1"; yu[4] = "1";
        yl[5] = "-1"; yu[5] = "1";
        yl[6] = "-1"; yu[6] = "1";
        yl[7] = "-1"; yu[7] = "1";
		break;
    case 13: 
        yl[2] = "-1"; yu[2] = "1";
        yl[3] = "-1"; yu[3] = "1";
        yl[4] = "-1"; yu[4] = "1";
        yl[5] = "-1"; yu[5] = "1";
        yl[6] = "-1"; yu[6] = "1";
        yl[7] = "-1"; yu[7] = "1";
        yl[8] = "-1"; yu[8] = "1";
        yl[9] = "-1"; yu[9] = "1";
        yl[10] = "-1"; yu[10] = "1";
        yl[11] = "-1"; yu[11] = "1";
        yl[12] = "-1"; yu[12] = "1";
        yl[13] = "-1"; yu[13] = "1";
        yl[14] = "-1"; yu[14] = "1";
        yl[15] = "-1"; yu[15] = "1";
		break;
    case 15: 
        xl[0] = "-50"; xu[0] = "50";
        xl[1] = "-50"; xu[1] = "50";
        xl[2] = "-pi"; xu[2] = "pi";
        yl[0] = "10"; yu[0] = "32";
        yl[1] = "10"; yu[1] = "32";
        yl[2] = "10"; yu[2] = "32";
        break;
    case 16: 
        xl[0] = "-50"; xu[0] = "50";
        xl[1] = "-50"; xu[1] = "50";
        xl[2] = "-pi"; xu[2] = "pi";
        yl[0] = "-pi"; yu[0] = "pi"; yc[0] = true;
        yl[1] = "-pi"; yu[1] = "pi"; yc[1] = true;
        yl[2] = "-pi"; yu[2] = "pi"; yc[2] = true;
        break;
    case 17: 
        xl[0] = "-50"; xu[0] = "50";
        xl[1] = "-50"; xu[1] = "50";
        xl[2] = "-50"; xu[2] = "50";
        yl[0] = "0"; yu[0] = "32";
        yl[1] = "0"; yu[1] = "32";
        yl[2] = "0"; yu[2] = "32";
        break;
    case 18: 
        xl[0] = "-50"; xu[0] = "50";
        xl[1] = "-50"; xu[1] = "50";
        xl[2] = "-50"; xu[2] = "50";
        xl[3] = "-50"; xu[3] = "50";
        xl[4] = "-50"; xu[4] = "50";
        xl[5] = "-50"; xu[5] = "50";
        yl[0] = "0"; yu[0] = "32";
        yl[1] = "0"; yu[1] = "32";
        yl[2] = "0"; yu[2] = "32";
        yl[3] = "0"; yu[3] = "32";
        yl[4] = "0"; yu[4] = "32";
        yl[5] = "0"; yu[5] = "32";
        break;
    }

    // variable declarations:
    sp<Variable> x[MaxDim], y[MaxDim], su[MaxDim];

    for (int i(0); i < 3; ++i) {
        ostringstream os;
        os << 'x' << (i+1);
        x[i] = sp<Variable>(new RealVariable(os.str(), Interval('['+xl[i]+','+xu[i]+']'),
                                             prec, false, true ));
    }

    for (int i(0); i < MaxDim; ++i) {
        ostringstream os;
        os << 'y' << (i+1);
        y[i] = sp<Variable>(new RealVariable("y1", Interval('['+yl[i]+','+yu[i]+']'),
                                             prec*1, false, true ));
    }
    //y[1] = sp<Variable>(new RealVariable("y2", Interval('['+yl[1]+','+yu[1]+']'),
    //                                     prec*1, false, true));
    //y[2] = sp<Variable>(new RealVariable("y3", Interval('['+yl[2]+','+yu[2]+']'),
    //                                     prec, false, true));
    //y[3] = sp<Variable>(new RealVariable("y4", Interval("[-1,1]"), 
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

    case 10: { // Sphere (2x3x2, CP'06)
        dim = 3; dim_f = 2;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1] + y[2]);
        break;
    }

    case 11: { // Sphere (2x6)
        dim = dim_f = 6;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) + sqr(y[3]) + sqr(y[4]) + sqr(y[5]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        f[2] = new Term(x[0] + x[1] + y[1] + y[2]);
        f[3] = new Term(x[0] + x[1] + y[2] + y[3]);
        f[4] = new Term(x[0] + x[1] + y[3] + y[4]);
        f[5] = new Term(x[0] + x[1] + y[4] + y[5]);
        break;
    }

    case 12: { // Sphere (2x8)
        dim = dim_f = 8;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) + sqr(y[3]) + sqr(y[4]) + sqr(y[5]) + sqr(y[6]) + sqr(y[7]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        f[2] = new Term(x[0] + x[1] + y[1] + y[2]);
        f[3] = new Term(x[0] + x[1] + y[2] + y[3]);
        f[4] = new Term(x[0] + x[1] + y[3] + y[4]);
        f[5] = new Term(x[0] + x[1] + y[4] + y[5]);
        f[6] = new Term(x[0] + x[1] + y[5] + y[6]);
        f[7] = new Term(x[0] + x[1] + y[6] + y[7]);
        break;
    }

    case 13: { // Sphere (2x16)
        dim = dim_f = 16;
        f[0] = new Term(sqr(x[0]) + sqr(x[1]) + sqr(y[0]) + sqr(y[1]) + sqr(y[2]) + sqr(y[3]) + sqr(y[4]) + sqr(y[5]) + sqr(y[6]) + sqr(y[7]) + sqr(y[8]) + sqr(y[9]) + sqr(y[10]) + sqr(y[11]) + sqr(y[12]) + sqr(y[13]) + sqr(y[14]) + sqr(y[15]) - 1);
        f[1] = new Term(x[0] + x[1] + y[0] + y[1]);
        f[2] = new Term(x[0] + x[1] + y[1] + y[2]);
        f[3] = new Term(x[0] + x[1] + y[2] + y[3]);
        f[4] = new Term(x[0] + x[1] + y[3] + y[4]);
        f[5] = new Term(x[0] + x[1] + y[4] + y[5]);
        f[6] = new Term(x[0] + x[1] + y[5] + y[6]);
        f[7] = new Term(x[0] + x[1] + y[6] + y[7]);
        f[8] = new Term(x[0] + x[1] + y[7] + y[8]);
        f[9] = new Term(x[0] + x[1] + y[8] + y[9]);
        f[10] = new Term(x[0] + x[1] + y[9] + y[10]);
        f[11] = new Term(x[0] + x[1] + y[10] + y[11]);
        f[12] = new Term(x[0] + x[1] + y[11] + y[12]);
        f[13] = new Term(x[0] + x[1] + y[12] + y[13]);
        f[14] = new Term(x[0] + x[1] + y[13] + y[14]);
        f[15] = new Term(x[0] + x[1] + y[14] + y[15]);
        break;
    }

    case 14: { // Robot (2x3x2, under-constrained)
        dim = 3; dim_f = 2;
        //const Constant L (2);
        const Constant Cx(3);
        const Constant Cy(1);
        const Constant R (1);

        f[0] = new Term(x[0] - (y[0] + y[2]*cos(y[1])));
        f[1] = new Term(x[1] - (y[0] + y[2]*sin(y[1])));

        // TODO: to be removed:
        sp<Term> cf = new Term(sqr(x[0]-Cx) + sqr(x[1]-Cy) - R);
        constr_if->insert(new IntervalFunction(cf));

        break;
    }

    case 15: { // 3-RPR (3x3)
        dim = dim_x = dim_f = 3;
        static const Constant Phi(0.8822);
        static const Constant L2(17.0);
        static const Constant L3(20.8);
        static const Constant C2(15.9);
        static const Constant C3(0.0);
        static const Constant D3(10.0);

        f[0] = new Term(  sqr(x[0])
                        + sqr(x[1])
                        - sqr(y[0]) );
        f[1] = new Term(  sqr(x[0] + L2*cos(x[2]) - C2) 
                        + sqr(x[1] + L2*sin(x[2]))
                        - sqr(y[1]) );
        f[2] = new Term(  sqr(x[0] + L3*cos(x[2] + Phi) - C3)
                        + sqr(x[1] + L3*sin(x[2] + Phi) - D3) 
                        - sqr(y[2]) );
        break;
    }

    case 16: { // 3-RRR (3x3)
        dim = dim_x = dim_f = 3;
        static const Constant AX1(-10.0);
        static const Constant AY1(-10.0);
        static const Constant AX2( 10.0);
        static const Constant AY2(-10.0);
        static const Constant AX3(  0.0);
        static const Constant AY3( 10.0);
        static const Constant CX1(  0.0); // -a1-a5
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
         
        f[0] = new Term(  sqr(x[0] + CX1*cos(x[2]) - CY1*sin(x[2]) - AX1 - L1*cos(y[0]))
                        + sqr(x[1] + CX1*sin(x[2]) + CY1*cos(x[2]) - AY1 - L1*sin(y[0]))
                                                                 - sqr(M1));
        f[1] = new Term(  sqr(x[0] + CX2*cos(x[2]) - CY2*sin(x[2]) - AX2 - L2*cos(y[1]))
                        + sqr(x[1] + CX2*sin(x[2]) + CY2*cos(x[2]) - AY2 - L2*sin(y[1]))
                                                                 - sqr(M2));
        f[2] = new Term(  sqr(x[0] + CX3*cos(x[2]) - CY3*sin(x[2]) - AX3 - L3*cos(y[2]))
                        + sqr(x[1] + CX3*sin(x[2]) + CY3*cos(x[2]) - AY3 - L3*sin(y[2]))
                                                                 - sqr(M3));
        break;
    }

    case 17: { // Delta (3x3)
        dim = dim_x = dim_f = 3;
        static const Constant CX1(  0.0);
        static const Constant CY1(  0.0);
        static const Constant CZ1(  0.0);
        static const Constant CX2( 10.0);
        static const Constant CY2(  0.0);
        static const Constant CZ2(  0.0);
        static const Constant CX3(  0.0);
        static const Constant CY3( 20.0);
        static const Constant CZ3(  0.0);
         
        f[0] = new Term( sqr(x[0]-CX1) + sqr(x[1]-CY1) + sqr(x[2]-CZ1) - sqr(y[0]) );
        f[1] = new Term( sqr(x[0]-CX2) + sqr(x[1]-CY2) + sqr(x[2]-CZ2) - sqr(y[1]) );
        f[2] = new Term( sqr(x[0]-CX3) + sqr(x[1]-CY3) + sqr(x[2]-CZ3) - sqr(y[2]) );
        break;
    }

    case 18: { // Stewart (6x6)
        dim = dim_x = dim_f = 6;
        static const Constant RB(1.0);
        static const Constant RP(1.0);
        static const Constant PB(0.5);
        static const Constant PP(0.5);

        Term R11( cos(x[3])*cos(x[4]) );
        Term R12( cos(x[3])*sin(x[4])*sin(x[5]) - sin(x[3])*cos(x[5]) );
        Term R21( sin(x[3])*cos(x[4]) );
        Term R22( sin(x[3])*sin(x[4])*sin(x[5]) - cos(x[3])*cos(x[5]) );
        Term R31( 0.-sin(x[4]) );
        Term R32( cos(x[4])*sin(x[5]) );

        bool s(0);
        for (int i(0); i < 6; ++i) {
            Term Bx( RB*cos(gaol::pi*(i/2+1)/3+(s?-1:1)*PB) );
            Term By( RB*sin(gaol::pi*(i/2+1)/3+(s?-1:1)*PB) );
            Term Px( RP*cos(gaol::pi*(i/2+1)/3+(s?-1:1)*PP) );
            Term Py( RP*sin(gaol::pi*(i/2+1)/3+(s?-1:1)*PP) );
            s = !s;

            f[i] = new Term (
            sqr(x[0]) + sqr(x[1]) + sqr(x[2]) + sqr(RP) + sqr(RB)
            + 2* (R11*Px + R12*Py) * (x[0]-Bx)
            + 2* (R21*Px + R21*Py) * (x[1]-By)
            + 2* (R31*Px + R32*Py) * x[2]
            - 2* (x[0]*Bx + x[1]*By)
            - sqr(y[i])
            );
        }
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


void RPX10__CoreProj::initialize(x10::lang::String *filename, x10_int n) {

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
    */
    prob_id = n;
    prec = 1E-1;
    op_id = 4;


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
    //facto_box.generate(*problem,vop);

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


#if USE_PAPI
if (PAPI_library_init(PAPI_VER_CURRENT) != PAPI_VER_CURRENT) {
	printf("exit at init.");
	exit(1);
}
if (PAPI_thread_init(pthread_self) != PAPI_OK) {
	printf("exit at thread init.");
	exit(1);
}
for (int i(0); i < PAPI_EN; ++i) papi_result[i] = 0;
#endif
}

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
