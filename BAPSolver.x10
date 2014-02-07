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

    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var initPhase:Boolean;

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        this.core = core;
        selectVariable = selector;

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    protected def contract(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) : Result {
        var res:Result = Result.unknown();
var time:Long = -System.nanoTime();
        atomic { res = core.contract(box); }
time += System.nanoTime();
//Console.OUT.printf("%f\n", RPX10.format(time));
sHandle().tContracts.getAndAdd(time);
        sHandle().nContracts.getAndIncrement();
        return res;
    }
    
    protected val selectVariable : (res:Result, box:IntervalVec[K]) => Box[K];

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//sHandle().debugPrint(here + ": search:\n" + box + '\n');
//try {
        // for dummy boxes
        if (box.size() == 0)
            return;

sHandle().nSearchPs.incrementAndGet();

sHandle().debugPrint(here + ": load: " + (sHandle().list.size() + sHandle().nSearchPs.get()));

        var res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val pv:Box[K] = box.prevVar();
                val bp = box.split(v()); 
                sHandle().nSplits.getAndIncrement();
                
finish {
                async if (!sHandle().respondIfRequested(sHandle, bp.first)) {
                    //async 
                    search(sHandle, bp.first);
                }

                async 
                search(sHandle, bp.second);
}
sHandle().debugPrint(here + ": branch done");
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

sHandle().nSearchPs.decrementAndGet();
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
