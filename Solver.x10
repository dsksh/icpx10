import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class Solver[K] {

    public static struct Result {
        private val code:Int;
        private def this(code:Int) : Result { 
            this.code = code; 
        }
        public static def noSolution() : Result { return new Result(1); }
        public static def unknown()    : Result { return new Result(0); }
        public static def verified()   : Result { return new Result(2); }
        public def hasNoSolution() : Boolean { return code == 1; }
    }

    public static interface Core[K] {
        public def initialize(filename:String) : void;
        public def getInitialDomain() :IntervalVec[K];
        public def solve() : int;
        //public def calculateNext() : int;
        public atomic def contract(box:IntervalVec[K]) : Result;
    } 

    /*@NativeRep("c++", "Solver__Core *", "Solver__Core", null)
    @NativeCPPOutputFile("Solver__Core.h")
    @NativeCPPCompilationUnit("Solver__Core.cc")
    static class Core implements CoreI[String] {
        public def this() : Core {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String) : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalMap { 
            return new IntervalMap(); 
        };
        @Native("c++", "(#0)->solve()")
        public def solve() : int = 0;
        //@Native("c++", "(#0)->calculateNext()")
        //public def calculateNext() : int = 0;

        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[String]) : Result { return Result.unknown(); };
    }*/
    /*static class Core implements CoreI[String] {
        public def this() : Core {}
        public def initialize(filename:String) : void {};
        public def getInitialDomain() : IntervalMap { 
            return new IntervalMap(); 
        };
        public def solve() : int = 0;

        public def contract(box:IntervalVec[String]) : Result { return Result.unknown(); };
    }*/

    val core:Core[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[Result,IntervalVec[K]]];

    public var nSols:AtomicInteger = new AtomicInteger(0);
    public var nContracts:AtomicInteger = new AtomicInteger(0);
    public var nSplits:AtomicInteger = new AtomicInteger(0);
    public var nReqs:AtomicInteger = new AtomicInteger(0);
    public var nSends:AtomicInteger = new AtomicInteger(0);

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(core:Core[K], selector:(box:IntervalVec[K])=>Box[K], filename:String) {
        this.core = core;
        core.initialize(filename);
        selectVariable = selector;

        list = new ArrayList[IntervalVec[K]]();
        if (here.id() == 0)
            list.add(core.getInitialDomain());
        solutions = new ArrayList[Pair[Result,IntervalVec[K]]]();

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) { }

    public def getSolutions() : List[Pair[Result,IntervalVec[K]]] { return solutions; }
    
    protected val selectVariable : (box:IntervalVec[K]) => Box[K];

    public def solve0() {
   		Console.OUT.println(here + ": start solving... ");
        core.solve();
   		Console.OUT.println(here + ": done");
    }

    protected def search(box:IntervalVec[K]) {
	    Console.OUT.println(here + ": search:\n" + box + '\n');

        //val res:Result = core.contract(box);
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }

        if (!res.hasNoSolution()) {
            val v = selectVariable(box);
            if (v != null) {
                val bp = box.split(v());
                nSplits.getAndIncrement();
                async search(bp.first);
                async search(bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                atomic Console.OUT.println(here + ": solution:\n" + box + '\n');
                nSols.getAndIncrement();
            }
        }
        //else Console.OUT.println(here + ": no solution");
    }

    protected def search1() {
        for (box in list) async {
   		    Console.OUT.println(here + ": search:");
   		    Console.OUT.println(box);
   		    Console.OUT.println();

            var res:Result = Result.unknown();
            atomic { res = core.contract(box); }

            if (!res.hasNoSolution()) {
                val v = selectVariable(box);
                if (v != null) {
                    val bp = box.split(v());
                    nSplits.getAndIncrement();
                    atomic list.add(bp.first);
                    atomic list.add(bp.second);
                    search1();
                }
                else {
                    atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                    atomic Console.OUT.println(here + ": solution:\n" + box + '\n');
                    nSols.getAndIncrement();
                }
            }
            else
                Console.OUT.println(here + ": no solution");
        }
    }

    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
    //public def solve() {
   		Console.OUT.println(here + ": start solving... ");

        // main solving process
        val box:IntervalVec[K] = list.removeFirst();
        finish search(box);
        
        //finish search1();

        // print solutions
        val it = solutions.iterator();
        for (var i:Int = 0; it.hasNext(); ++i) {
            val p = it.next();
   		    //Console.OUT.println("solution " + i + ":");
   		    Console.OUT.println(p.second);
   		    Console.OUT.println();
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
