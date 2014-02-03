import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

// kludge for "Interval is incomplete type" error
//class Dummy_RPX10 {
//    val dummy : Interval = new Interval(0.,0.);
//    val dummyRes : BAPSolver.Result = BAPSolver.Result.unknown();
//}

public class RPX10[K] {

    static def format(t:Long) = (t as Double) * 1.0e-9;

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
    static class CoreIArray implements BAPSolver.Core[Int] {
        public def this(filename:String, n:Int) : CoreIArray {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String, n:Int) : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[Int] { 
            return new IntervalArray(1); 
        };
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[Int]) : BAPSolver.Result { return BAPSolver.Result.unknown(); };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:Int) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Int] { return new IntervalArray(0); }
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

    private def setup(core:BAPSolver.Core[K], args:Array[String](1)) : PlaceAgent[K] {

        val tester = new VariableSelector.Tester[K]();
        var an:Int = 2;
        val prec = Double.parse(args(an++));
        val debug = Boolean.parse(args(an++));
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
            tester.testPrec(prec, res, box, v);
//        val test1 = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
//            tester.testRegularity(test, (v:K)=>!core.isProjected(v), res, box, v);

        val selector = new VariableSelector[K](test);
        var select:(BAPSolver.Result,IntervalVec[K])=>Box[K];
        val selectBnd = (select0:(BAPSolver.Result,IntervalVec[K])=>Box[K]) =>
            ((res:BAPSolver.Result, box:IntervalVec[K]) =>
                selector.selectBoundary(select0, res, box) );
        switch (Int.parse(args(an++))) {
        case 0:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectGRR(res, box) );
            break;
        case 1:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectLRR(res, box) );
            break;
        default:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectLF(res, box) );
            break;
        }

        var solver:BAPSolver[K] = null;
        switch (Int.parse(args(an++))) {
        case 0:
            solver = new BAPSolver[K](core, select);
            break;
        case 1:
            solver = new BAPListSolver[K](core, select);
            break;
        default:
            return new PlaceAgentMSplit[K](
                new BAPSolverMSplit[K](core, select) );
        }

        switch (Int.parse(args(an++))) {
        case 0:
            return new PlaceAgent1[K](solver, debug);
        default:
            val pa = new PlaceAgentDelayed[K](solver, debug);
            pa.initPP(core, prec);
            return pa;
        }
    }

    // kludge for a success of compilation
    val dummy:Double = 0.;
    val dummyI:Interval = new Interval(0.,0.);
    val dummyR:BAPSolver.Result = BAPSolver.Result.unknown();

    public static def main(args:Array[String](1)) {

        if (args.size < 6) {
            Console.OUT.println("usage: RPX10 prob.rp n prec sel solver pagent");
            return;
        }

        Console.OUT.print("\n{\"args\" : \"" + args + "\",");
		Console.OUT.println("\"# places\" : " + Place.numPlaces() + "}\n");

        // create a solver at each place
        val everyone = Dist.makeUnique();
        val sHandle = PlaceLocalHandle.make[PlaceAgent[Int]](
            everyone, 
            ()=> {
                val main = new RPX10[Int]();
                val core = new CoreIArray(args(0), Int.parse(args(1)));
                return main.setup(core, args);
            } );

        val masterP = here;

        var time:Long = -System.nanoTime();
        //finish for (p in Place.places()) at (p) async 
        sHandle().setup(sHandle);

        finish for (p in Place.places()) async at (p) {
            sHandle().run(sHandle);
        }

        time += System.nanoTime();

/*        // print solutions
        Console.OUT.println(); 
        for (p in Place.places()) at (p) {
            val ss = sHandle().getSolutions();
            val it = ss.iterator();
            while (it.hasNext()) atomic {
                val pair = it.next();
                val plot = pair.first.entails(BAPSolver.Result.inner()) ? 5 : 3;
                val stringB = pair.second.toString(plot);
                Console.OUT.println(stringB);
                Console.OUT.println(); 
//                Console.OUT.flush();
            }
            Console.OUT.flush();
        }
*/
        // print description of the solving process.
        val sb = new StringBuilder();
        val sbG = new GlobalRef[StringBuilder](sb);
        sb.add("{\"summary\" : {");
        sb.add(" \"time (s)\" : " + format(time) + ",\n");

        // sum up the # solutions at each place
        val nSols = new GlobalRef(new Cell(0));
        sb.add("  \"# sols (sep)\" : [");
        for (p in Place.places()) at (p) {
            val v = sHandle().nSols.get();
            at (masterP) {
                at (sbG.home)
                    sbG().add((p == here ? " " : ", ") + v);
                nSols().value += v;
            }
        }
        sb.add("],");
        sb.add(" \"# sols\" : " + nSols().value + ",\n");

        // sum up the # contracts at each place
        val nContracts = new GlobalRef(new Cell(0));
        val nSplits    = new GlobalRef(new Cell(0));
        val nReqs      = new GlobalRef(new Cell(0));
        val nSends     = new GlobalRef(new Cell(0));
        val cContracts = new Cell[String]("  \"# contracts (sep)\" : ["); 
        val cSplits    = new Cell[String]("  \"# splits (sep)\" : ["); 
        val cReqs      = new Cell[String]("  \"# reqs (sep)\" : ["); 
        val cSends     = new Cell[String]("  \"# sends (sep)\" : ["); 
        val gContracts = GlobalRef[Cell[String]](cContracts);
        val gSplits    = GlobalRef[Cell[String]](cSplits);
        val gReqs      = GlobalRef[Cell[String]](cReqs);
        val gSends     = GlobalRef[Cell[String]](cSends);
        for (p in Place.places()) at (p) {
            val vContacts = sHandle().nContracts.get();
            val vSplits = sHandle().nSplits.get();
            val vReqs = sHandle().nReqs.get();
            val vSends = sHandle().nSends.get();
            at (gContracts.home) {
                gContracts().set(gContracts()() + (p == here ? "" : ", ") + vContacts);
                nContracts().value += vContacts;
            }
            at (gSplits.home) {
                gSplits().set(gSplits()() + (p == here ? "\n" : ",\n") + vSplits);
                nSplits().value += vSplits;
            }
            at (gReqs.home) {
                gReqs().set(gReqs()() + (p == here ? "" : ", ") + vReqs);
                nReqs().value += vReqs;
            }
            at (gSends.home) {
                gSends().set(gSends()() + (p == here ? "" : ", ") + vSends);
                nSends().value += vSends;
            }
        }
        sb.add(cContracts() + "], \"# contracts\" : " + nContracts().value + ",\n");
        sb.add(cSplits()    + "\n],    \"# splits\" : " + nSplits().value + ",\n");
        sb.add(cReqs()      + "], \"# reqs\" : " + nReqs().value + ",\n");
        sb.add(cSends()     + "], \"# sends\" : " + nSends().value);
        sb.add(" } }");

        Console.OUT.flush();
        Console.OUT.println(sb);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
