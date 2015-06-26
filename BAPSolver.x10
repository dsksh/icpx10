import x10.compiler.*;
import x10.util.Box;
import x10.util.concurrent.AtomicBoolean;
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
        public def initialize(filename:String, n:Int) : Boolean;
		public def finalize() : void;
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

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        this.core = core;
        selectVariable = selector;
    }

    protected val selectVariable : (res:Result, box:IntervalVec[K]) => Box[K];
}

// vim: shiftwidth=4:tabstop=4:expandtab
