import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

// kludge for "Interval is incomplete type" error
class Dummy_RPX10 {
    val dummy : Interval = new Interval(0.,0.);
    val dummyRes : Solver.Result = Solver.Result.unknown();
}

public class RPX10 {

    static def format(t:Long) = (t as Double) * 1.0e-9;

    static class CoreIMap0 implements Solver.Core[String] {
        public def this() : CoreIMap0 {}
        public def initialize(filename:String, n:Int) : void {};
        public def getInitialDomain() : IntervalVec[String] { 
            return new IntervalMap(); 
        };
        public def contract(box:IntervalVec[String]) : Solver.Result { return Solver.Result.unknown(); };
        public def isProjected(v:String) : Boolean { return false; }
        public def dummyBox() : IntervalVec[String] { return new IntervalMap(); }
    }
    /*static class CoreIArray0 implements Solver.Core[Int] {
        public def this() : CoreIArray0 {}
        public def initialize(filename:String, n:Int) : void {};
        public def getInitialDomain() : IntervalVec[Int] { 
            return new IntervalArray(1); 
        };
        public def contract(box:IntervalVec[Int]) : Solver.Result { return Solver.Result.unknown(); };
        public def isProjected(v:Int) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Int] { return new IntervalArray(0); }
    }*/
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
    static class CoreIArray implements Solver.Core[Int] {
        public def this(filename:String, n:Int) : CoreIArray {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String, n:Int) : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[Int] { 
            return new IntervalArray(1); 
        };
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[Int]) : Solver.Result { return Solver.Result.unknown(); };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:Int) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Int] { return new IntervalArray(0); }
    }
    @NativeRep("c++", "RPX10__CoreIMap *", "RPX10__CoreIMap", null)
    @NativeCPPOutputFile("RPX10__CoreIMap.h")
    @NativeCPPCompilationUnit("RPX10__CoreIMap.cc")
    static class CoreIMap implements Solver.Core[String] {
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
        public def contract(box:IntervalVec[String]) : Solver.Result { return Solver.Result.unknown(); };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:String) : Boolean { return false; }
        @Native("c++", "(#0)->dummyBox((#1))")
        public def dummyBox() : IntervalVec[String] { return new IntervalMap(); }
    }


    private static def initSolverArray(fname:String, prec:Double, n:Int
            //, ns:Int
        ) : Solver[Int] {
        val core = new CoreIArray(fname, n);

        val tester = new VariableSelector.Tester[Int]();
        val test = (res:Solver.Result, box:IntervalVec[Int], v:Int) => tester.testPrec(prec, res, box, v);
        val test1 = (res:Solver.Result, box:IntervalVec[Int], v:Int) => 
            tester.testRegularity(test, (v:Int)=>!core.isProjected(v), res, box, v);
        //val testBr = (res:Solver.Result, box:IntervalVec[Int], v:Int) => 
        //    tester.testNSplits(test, ns, res, box, v);

        val selector = new VariableSelector[Int](test1);

        val select = (res:Solver.Result, box:IntervalVec[Int])=>selector.selectLRR(res, box);
        val select1 = (res:Solver.Result, box:IntervalVec[Int])=>selector.selectBoundary(select, res, box);

        //return new ClusterDFSSolver[Int](core, select1);
        //return new ClusterDFSSolverSwitched[Int](core, select1);
        //val solver = new ClusterDFSSolverSwitched[Int](core, select1);
        //tester.nSplits = solver.nSplits;
        //return solver;
        return new ClusterDFSSolverDelayed[Int](core, select1);
        //return new ClusterSolver[Int](core, select1);
    }

    private static def initSolverMap(fname:String, prec:Double, n:Int) : Solver[String] {
        val core = new CoreIMap(fname, n);

        //val prec = 1E-1;
        val tester = new VariableSelector.Tester[String]();
        val test = (res:Solver.Result, box:IntervalVec[String], v:String) => tester.testPrec(prec, res, box, v);
        val test1 = (res:Solver.Result, box:IntervalVec[String], v:String) => 
            tester.testRegularity(test, (v:String)=>!core.isProjected(v), res, box, v);

        val selector = new VariableSelector[String](test1);

        val select = (res:Solver.Result, box:IntervalVec[String])=>selector.selectLRR(res, box);
        val select1 = (res:Solver.Result, box:IntervalVec[String])=>selector.selectBoundary(select, res, box);

        return new ClusterDFSSolver[String](core, select1);
    }

    public static def main(args:Array[String](1)) {

        if (args.size < 3) {
            Console.OUT.println("usage: RPX10 prob.rp prec n");
            return;
        }

        // create a solver at each place
        val everyone = Dist.makeUnique();
        val sHandle = PlaceLocalHandle.make[Solver[Int]](everyone, ()=>initSolverArray(args(0), Double.parse(args(1)), Int.parse(args(2))
            //, Int.parse(args(3))
            ));
        //val sHandle = PlaceLocalHandle.make[Solver[String]](everyone, ()=>initSolverMap(args(0), Double.parse(args(1)), Int.parse(args(2))));

        var time:Long = -System.nanoTime();

        //finish for (p in Place.places()) at (p) async 
        sHandle().setup(sHandle);

        finish for (p in Place.places()) at (p) async {
            sHandle().solve(sHandle);
        }

        time += System.nanoTime();

/*        // output the solutions.
        Console.OUT.println();
        for (p in Place.places()) at (p) atomic {
            val it = sHandle().solutions.iterator();
            for (var i:Int = 0; it.hasNext(); ++i) {
                val pair = it.next();
                val plot = pair.first.entails(Solver.Result.inner()) ? 5 : 3;
                Console.OUT.println(pair.second.toString(plot));
                Console.OUT.println(); 
            }
            Console.OUT.flush();
        }
*/

        // output description of the solving process.
        val sb = new StringBuilder();
        val sbG = new GlobalRef[StringBuilder](sb);
        sb.add("{\"desc\" : \"");
        sb.add("time: " + format(time) + " s,\n");

        // sum up the # solutions at each place
        val nSols = new GlobalRef(new Cell(0));
        sb.add("  # sols:");
        val masterP = here;
        for (p in Place.places()) at (p) {
            val v = sHandle().nSols.get();
            at (masterP) {
                at (sbG.home)
                    sbG().add((p == here ? " " : " + ") + v);
                nSols().value += v;
            }
        }
        sb.add(" = " + nSols().value + ",\n");

        // sum up the # contracts at each place
        val nContracts = new GlobalRef(new Cell(0));
        val nSplits = new GlobalRef(new Cell(0));
        val nReqs = new GlobalRef(new Cell(0));
        val nSends = new GlobalRef(new Cell(0));
        val nBranches = new GlobalRef(new Cell(0));
        val tContract = new GlobalRef(new Cell[Long](0));
        val cContracts = new Cell[String]("  # contracts:"); val gContracts = GlobalRef[Cell[String]](cContracts);
        val cSplits = new Cell[String]("  # splits:"); val gSplits = GlobalRef[Cell[String]](cSplits);
        val cReqs = new Cell[String]("  # reqs:"); val gReqs = GlobalRef[Cell[String]](cReqs);
        val cSends = new Cell[String]("  # sends:"); val gSends = GlobalRef[Cell[String]](cSends);
        val cBranches = new Cell[String]("  # branches:"); val gBranches = GlobalRef[Cell[String]](cBranches);
        for (p in Place.places()) at (p) {
            val vContacts = sHandle().nContracts.get();
            val vSplits = sHandle().nSplits.get();
            val vReqs = sHandle().nReqs.get();
            val vSends = sHandle().nSends.get();
            val vBranches = sHandle().nBranches.get();
            val vTContract = sHandle().tContract;
            at (gContracts.home) {
                gContracts().set(gContracts()() + (p == here ? " " : " + ") + vContacts);
                nContracts().value += vContacts;
            }
            at (gSplits.home) {
                gSplits().set(gSplits()() + (p == here ? " " : " + ") + vSplits);
                nSplits().value += vSplits;
            }
            at (gReqs.home) {
                gReqs().set(gReqs()() + (p == here ? " " : " + ") + vReqs);
                nReqs().value += vReqs;
            }
            at (gSends.home) {
                gSends().set(gSends()() + (p == here ? " " : " + ") + vSends);
                nSends().value += vSends;
            }
            at (gBranches.home) {
                gBranches().set(gBranches()() + (p == here ? " " : " + ") + vBranches);
                nBranches().value += vBranches;
            }
            at (tContract.home) {
                tContract().value += vTContract;
            }
        }
        sb.add(cContracts() + " = " + nContracts().value + ",\n");
        sb.add(cSplits() + " = " + nSplits().value + ",\n");
        sb.add(cReqs() + " = " + nReqs().value + ",\n");
        sb.add(cSends() + " = " + nSends().value + ",\n");
        //sb.add(cBranches() + " = " + nBranches().value + ",\n");
        sb.add("  time contract: " + (100.* tContract().value / time) + " %");
        sb.add("\" }");

        Console.OUT.flush();
        Console.OUT.println(sb);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
