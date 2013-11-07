import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class BAPSolver[K] {

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

//    val reqQueue:CircularQueue[Int];
//    var terminate:Int = 0;
//    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var initPhase:Boolean;

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        this.core = core;
//        this.master = master;
        selectVariable = selector;

//        list = new ArrayList[IntervalVec[K]]();
//        list1 = new ArrayList[Pair[Result,IntervalVec[K]]]();
//        solutions = new ArrayList[Pair[Result,IntervalVec[K]]]();

//        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

//    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) { 
//        list.add(core.getInitialDomain());
//    }

    //public def getSolutions() : List[Pair[Result,IntervalVec[K]]] { return solutions; }

    protected def contract(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) : Result {
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        sHandle().nContracts.getAndIncrement();
        return res;
    }
    
    protected val selectVariable : (res:Result, box:IntervalVec[K]) => Box[K];

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');
//try {
        // for dummy boxes
        if (box.size() == 0)
            return;

//        var res:Result = Result.unknown();
//        atomic { res = core.contract(box); }
//        sHandle().nContracts.getAndIncrement();
        var res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val pv:Box[K] = box.prevVar();
                val bp = box.split(v()); 
                sHandle().nSplits.getAndIncrement();
                
finish {
                if (!sHandle().respondIfRequested(sHandle, bp.first)) {
                    async 
                    search(sHandle, bp.first);
                }

                async 
                search(sHandle, bp.second);
}
            }
            else {
                sHandle().addSolution(res, box);
            }
        }
        //else Console.OUT.println(here + ": no solution");

//} catch (exp:Exception) {
//    Console.OUT.println(here + "," + sid + ": exception thrown:");
//    exp.printStackTrace(Console.ERR);
//}
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
