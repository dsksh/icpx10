import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class BAPSolver[K] {

    public static struct Result {
        private val code:Long;
        private def this(code:Long) : Result { 
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
        public def contract(box:IntervalVec[K]) : Result;
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

    /*protected def contract(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) : Result {
        var res:Result = Result.unknown();
var time:Long = -System.nanoTime();
        //atomic { 
            res = core.contract(box); 
time += System.nanoTime();
//Console.OUT.printf(here + ": %f\n", RPX10.format(time));
//sHandle().tContracts.getAndAdd(time);
sHandle().tContracts += time;
sHandle().nContracts++;
        //}
        return res;
    }
    */
    
    protected val selectVariable : (res:Result, box:IntervalVec[K]) => Box[K];

var sid0:Long = 0;

    /*protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
val sid:Long = sid0++;
//atomic sHandle().debugPrint(here + "," + sid + ": search:\n" + box + '\n');
//try {
        // for dummy boxes
        if (box.size() == 0) {
//sHandle().nSearchPs.decrementAndGet();
            return;
		}

//sHandle().nSearchPs.incrementAndGet();

//sHandle().debugPrint(here + "," + sid + ": load: " + sHandle().list.size() + " + " + sHandle().nSearchPs.get());
sHandle().debugPrint(here + "," + sid + ": load: " + sHandle().totalVolume.get());

val vol0 = box.volume();
        var res:Result = contract(sHandle, box);
//Console.OUT.println("after contraction:");
Console.OUT.println(box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
//Console.OUT.println("split: " + v);
                val pv:Box[K] = box.prevVar();
                val bp = box.split(v()); 
                //sHandle().nSplits.getAndIncrement();
                sHandle().nSplits++;
val vol = box.volume();
sHandle().totalVolume.addAndGet(-vol0+vol);
                
//finish {
                //async {
				if (!sHandle().respondIfRequested(sHandle, bp.first)) {
//atomic sHandle().nSearchPs.incrementAndGet();
                    //async 
                    search(sHandle, bp.first);
                }
else sHandle().totalVolume.addAndGet(-vol/2);
                //}

                //async
				search(sHandle, bp.second);
//}
sHandle().debugPrint(here + "," + sid + ": branch done");
            }
            else {
//sHandle().nSearchPs.decrementAndGet();
sHandle().totalVolume.addAndGet(-vol0);
                sHandle().addSolution(res, box);
            }
        }
        else {
			//Console.OUT.println(here + ": no solution");
//sHandle().nSearchPs.decrementAndGet();
sHandle().totalVolume.addAndGet(-vol0);
		}

//} catch (exp:Exception) {
//    Console.OUT.println(here + "," + sid + ": exception thrown:");
//    exp.printStackTrace(Console.ERR);
//}
    }
    */
}

// vim: shiftwidth=4:tabstop=4:expandtab
