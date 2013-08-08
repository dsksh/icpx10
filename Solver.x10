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
        public static def unknown()    : Result { return new Result(2); }
        public static def inner()   : Result { return new Result(12); }
        public static def regular()   : Result { return new Result(4); }
        public def hasNoSolution() : Boolean { return code == 1; }
        public def entails(res:Result) : Boolean { return (code & res.code) == res.code; }
        public def toString() : String {
            return "Result["+code+"]";
        }
    }

    public static interface Core[K] {
        //public def initialize(filename:String, n:Int) : void;
        public def getInitialDomain() :IntervalVec[K];
        //public def solve() : int;
        //public def calculateNext() : int;
        public atomic def contract(box:IntervalVec[K]) : Result;
        public def isProjected(v:K) : Boolean;
        public def dummyBox() : IntervalVec[K];
    } 

    val core:Core[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[Result,IntervalVec[K]]];

    val reqQueue:CircularQueue[Int];
    var terminate : Int = 0;
    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);

    public var nSols:AtomicInteger = new AtomicInteger(0);
    public var nContracts:AtomicInteger = new AtomicInteger(0);
    public var nSplits:AtomicInteger = new AtomicInteger(0);
    public var nReqs:AtomicInteger = new AtomicInteger(0);
    public var nSends:AtomicInteger = new AtomicInteger(0);

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]
        //, filename:String, n:Int
    ) {
        this.core = core;
        //core.initialize(filename, n);
        selectVariable = selector;

        list = new ArrayList[IntervalVec[K]]();
        if (here.id() == 0)
            list.add(core.getInitialDomain());
        solutions = new ArrayList[Pair[Result,IntervalVec[K]]]();

        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+100);

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) { }

    public def getSolutions() : List[Pair[Result,IntervalVec[K]]] { return solutions; }
    
    protected val selectVariable : (res:Result, box:IntervalVec[K]) => Box[K];

    /*public def solve0() {
   		Console.OUT.println(here + ": start solving... ");
        core.solve();
   		Console.OUT.println(here + ": done");
    }*/

    protected def search(box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        //val res:Result = core.contract(box);
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
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
                val v = selectVariable(res, box);
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
