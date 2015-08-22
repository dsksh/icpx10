import x10.compiler.*;
import x10.util.Box;
import x10.util.concurrent.AtomicBoolean;
import x10.io.Console; 

public class BAPSolverOpt[K] extends BAPSolver[K] {

    public static interface Core[K] extends BAPSolver[K].Core[K] {
        public def getGoalVar() : K;
        public def updateObjUB(ub:Double, box:IntervalVec[K]) : Double;
    } 

    val core:Core[K];

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
        this.core = core;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
