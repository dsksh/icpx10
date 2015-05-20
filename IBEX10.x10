import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;
import x10.regionarray.Dist;

// kludge for "Interval is incomplete type" error
class Dummy_RPX10 {
    val dummy : Interval = new Interval(0.,0.);
    val dummyRes : BAPSolver.Result = BAPSolver.Result.unknown();
}

public class IBEX10 {

    static def format(t:Long) = (t as Double) * 1.0e-9;

    @NativeRep("c++", "IBEX10__CoreIArray *", "IBEX10__CoreIArray", null)
    @NativeCPPOutputFile("IBEX10__CoreIArray.h")
    @NativeCPPCompilationUnit("IBEX10__CoreIArray.cc")
    //@NativeCPPOutputFile("RPX10__CoreEx.h")
    //@NativeCPPOutputFile("RPX10__Core.h")
    //@NativeCPPCompilationUnit("RPX10__Core.cc")
    //@NativeCPPOutputFile("RPX10__CoreProj.h")
    //@NativeCPPCompilationUnit("RPX10__CoreProj.cc")
    //@NativeCPPOutputFile("propagator.h")
    //@NativeCPPOutputFile("prover.h")
    //@NativeCPPCompilationUnit("prover.cc")
    @NativeCPPOutputFile("config.h")
    public static class CoreIArray implements BAPSolver.Core[Long] {
        public def this(filename:String, n:Int) : CoreIArray {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String, n:Int) : void {};
        @Native("c++", "(#0)->finalize()")
        public def finalize() : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[Long] { 
            return new IntervalArray(1); 
        };
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[Long]) : BAPSolver.Result { return BAPSolver.Result.unknown(); };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:Long) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Long] { return new IntervalArray(0); }
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
