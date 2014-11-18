

import x10.compiler.*;
import x10.util.Option;
import x10.util.OptionsParser;
import x10.util.Box;
import x10.util.Random;
import x10.util.ArrayList;

import x10.glb.GLB;
import x10.glb.GLBResult;
import x10.glb.GLBParameters;

// kludge for "Interval is incomplete type" error
class Dummy_Main {
    val dummy : Interval = new Interval(0.,0.);
    val dummyRes : BAPSolver.Result = BAPSolver.Result.unknown();
}

public class Main[K] extends RPX10[K] {

    /*static def format(t:Long) = (t as Double) * 1.0e-9;

    static class CoreIMap0 implements BAPSolver.Core[String] {
        public def this() : CoreIMap0 {}
        public def initialize(filename:String, n:Int) : void {};
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
    */

    public static def init[K](core:BAPSolver.Core[K]) {
Console.OUT.println(here.id() + ": init");

        val tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
            tester.testPrec(0.1, res, box, v);

        val selector = new VariableSelector[K](test);
        var select:(BAPSolver.Result,IntervalVec[K])=>Box[K];
        val selectBnd = (select0:(BAPSolver.Result,IntervalVec[K])=>Box[K]) =>
            ((res:BAPSolver.Result, box:IntervalVec[K]) =>
                selector.selectBoundary(select0, res, box) );
        select = selectBnd(
            (res:BAPSolver.Result, box:IntervalVec[K]) => selector.selectGRR(res, box) );

        return new Queue[K](core, select);
    }

    public static def main(args:Rail[String]) {
	    val opts = new OptionsParser(args, new Rail[Option](), [
                                                                Option("b", "", "Branching factor"),
                                                                Option("r", "", "Seed (0 <= r < 2^31"),
                                                                Option("d", "", "Tree depth"),
                                                                Option("n", "", "Number of nodes to process before probing. Default 200."),
                                                                Option("w", "", "Number of thieves to send out. Default 1."),
                                                                Option("l", "", "Base of the lifeline"),
                                                                Option("m", "", "Max potential victims"),
                                                                Option("v", "", "Verbose. Default 0 (no).")]);

        val b = opts("-b", 2n);
        val r = opts("-r", 19n);
        val d = opts("-d", 13n);
        val n = opts("-n", 511n);
        val l = opts("-l", 32n);
        val m = opts("-m", 1024n);
        val verbose = opts("-v", GLBParameters.SHOW_RESULT_FLAG);

        val P = Place.MAX_PLACES;

        var z0:Int = 1n;
        var zz:Int = l;
        while (zz < P) {
            z0++;
            zz *= l;
        }
        val z = z0;

        val w = opts("-w", z);

        Console.OUT.println("places=" + P +
                "   b=" + b +
                        "   r=" + r +
                                "   d=" + d +
                                        "   w=" + w +
                                                "   n=" + n +
                                                        "   l=" + l + 
                                                                "   m=" + m + 
                                                                        "   z=" + z);
        //val core = new CoreIArray("hoge", 2n);
        val init = ()=>{ 
            val core = new CoreIArray("hoge", 2n);
            return Main.init(core); 
        };
        val glb = new GLB[Queue[Long],Long](init, 
            GLBParameters(n, w, l, z, m, verbose), true );
        glb.run(()=>{});
    }
}
