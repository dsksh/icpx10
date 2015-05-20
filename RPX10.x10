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

public class RPX10[K] {

    static def format(t:Long) = (t as Double) * 1.0e-9;

    static class CoreIMap0 implements BAPSolver.Core[String] {
        public def this() : CoreIMap0 {}
        public def initialize(filename:String, n:Int) : void {};
        public def finalize() : void {};
        public def getInitialDomain() : IntervalVec[String] { 
            return new IntervalMap(); 
        };
        public def contract(box:IntervalVec[String]) : BAPSolver.Result { return BAPSolver.Result.unknown(); };
        public def isProjected(v:String) : Boolean { return false; }
        public def dummyBox() : IntervalVec[String] { return new IntervalMap(); }
    }
    @NativeRep("c++", "RPX10__CoreIArray *", "RPX10__CoreIArray", null)
    @NativeCPPOutputFile("RPX10__CoreIArray.h")
    @NativeCPPCompilationUnit("RPX10__CoreIArray.cc")
    @NativeCPPOutputFile("RPX10__CoreEx.h")
    @NativeCPPOutputFile("RPX10__Core.h")
    @NativeCPPCompilationUnit("RPX10__Core.cc")
    @NativeCPPOutputFile("RPX10__CoreProj.h")
    @NativeCPPCompilationUnit("RPX10__CoreProj.cc")
    @NativeCPPOutputFile("propagator.h")
    @NativeCPPOutputFile("prover.h")
    @NativeCPPCompilationUnit("prover.cc")
    @NativeCPPOutputFile("config.h")
    static class CoreIArray implements BAPSolver.Core[Long] {
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
    @NativeRep("c++", "RPX10__CoreIMap *", "RPX10__CoreIMap", null)
    @NativeCPPOutputFile("RPX10__CoreIMap.h")
    @NativeCPPCompilationUnit("RPX10__CoreIMap.cc")
    static class CoreIMap implements BAPSolver.Core[String] {
        public def this(filename:String, n:Int) : CoreIMap {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String, n:Int) : void {};
        @Native("c++", "(#0)->finalize()")
        public def finalize() : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[String] { 
            return new IntervalMap(); 
        };
        //@Native("c++", "(#0)->solve()")
        //public def solve() : int = 0;
        //@Native("c++", "(#0)->calculateNext()")
        //public def calculateNext() : int = 0;
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[String]) : BAPSolver.Result { return BAPSolver.Result.unknown(); };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:String) : Boolean { return false; }
        @Native("c++", "(#0)->dummyBox((#1))")
        public def dummyBox() : IntervalVec[String] { return new IntervalMap(); }
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
