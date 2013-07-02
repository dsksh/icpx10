import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class Solver {

    public static struct Result {
        private val code:Int;
        private def this(code:Int) : Result { this.code = code; }
        public static def noSolution() : Result { return new Result(1); }
        public static def unknown()    : Result { return new Result(0); }
        public static def verified()   : Result { return new Result(2); }
        public def hasNoSolution() : Boolean { return code == 1; }
    }

    @NativeRep("c++", "Solver__Core *", "Solver__Core", null)
    @NativeCPPOutputFile("Solver__Core.h")
    @NativeCPPCompilationUnit("Solver__Core.cc")
    static class Core {
        public def this() :Core {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String) :void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() :IntervalVec { 
            return new IntervalVec(); 
        };
        @Native("c++", "(#0)->solve()")
        public def solve():int = 0;
        @Native("c++", "(#0)->calculateNext()")
        public def calculateNext():int = 0;
        @Native("c++", "(#0)->contract((#1))")
        public atomic def contract(box:IntervalVec):Result { return Result.unknown(); };
    } 

    val core:Core;
    val list:List[IntervalVec];
    //val list:CircularQueue[IntervalVec];
    val solutions:List[Pair[Result,IntervalVec]];

    public var nSols:AtomicInteger = new AtomicInteger(0);
    public var nContracts:AtomicInteger = new AtomicInteger(0);
    public var nSplits:AtomicInteger = new AtomicInteger(0);
    public var nReqs:AtomicInteger = new AtomicInteger(0);
    public var nSends:AtomicInteger = new AtomicInteger(0);

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(selector:(box:IntervalVec)=>String, filename:String) {
        core = new Core();
        core.initialize(filename);
        list = new ArrayList[IntervalVec]();
        if (here.id() == 0)
            list.add(core.getInitialDomain());
        solutions = new ArrayList[Pair[Result,IntervalVec]]();
        dummy = 0;
        dummyI = new Interval(0.,0.);
        selectVariable = selector;
    }

    public def setup(sHandle:PlaceLocalHandle[Solver]) { }

    public def getSolutions() : List[Pair[Result,IntervalVec]] { return solutions; }
    
    public def solve0() {
   		Console.OUT.println(here + ": start solving... ");
        core.solve();
   		Console.OUT.println(here + ": done");
    }

    protected val selectVariable : (box:IntervalVec) => String;

    protected def search(box:IntervalVec) {
	    Console.OUT.println(here + ": search:\n" + box + '\n');

        //val res:Result = core.contract(box);
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }

        if (!res.hasNoSolution()) {
            val v = selectVariable(box);
            if (v != null) {
                val bp = box.split(v);
                nSplits.getAndIncrement();
                async search(bp.first);
                async search(bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec](res, box));
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
                    val bp = box.split(v);
                    nSplits.getAndIncrement();
                    atomic list.add(bp.first);
                    atomic list.add(bp.second);
                    search1();
                }
                else {
                    atomic solutions.add(new Pair[Result,IntervalVec](res, box));
                    atomic Console.OUT.println(here + ": solution:\n" + box + '\n');
                    nSols.getAndIncrement();
                }
            }
            else
                Console.OUT.println(here + ": no solution");
        }
    }

    public def solve(sHandle:PlaceLocalHandle[Solver]) {
    //public def solve() {
   		Console.OUT.println(here + ": start solving... ");

        // main solving process
        val box:IntervalVec = list.removeFirst();
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
