import x10.compiler.*;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Box;
import x10.util.concurrent.Lock;
import x10.util.StringBuilder;
//import x10.xrx.Runtime;

import glb.Context;
import glb.GLBResult;
import glb.TaskQueue;
import glb.TaskBag;
import glb.Logger;

public class GlbQueueImplOpt[K,R] extends BAPSolverOpt[K] implements TaskQueue[GlbQueueImplOpt[K,R], R] {

    val goalVar:K;

    var list:List[IntervalVec[K]] = null;
    var cntPrune:Long = 0;
    var cntBranch:Long = 0;
    val solutions:ArrayList[IntervalVec[K]];

    public var objUB:Double = Double.POSITIVE_INFINITY;
    public var objLB:Double = Double.NEGATIVE_INFINITY;
    public var objLBEpsBox:Double = Double.POSITIVE_INFINITY;

    val initResult:(Rail[IntervalVec[K]],Interval)=>R;

    private val lockList = new Lock();
    protected def tryLockList() : Boolean {
        return lockList.tryLock();
    }
    protected def lockList() {
        if (!lockList.tryLock()) {
            Runtime.increaseParallelism();
            lockList.lock();
            Runtime.decreaseParallelism(1n);
        }
    }
    protected def unlockList() {
        lockList.unlock();
    }

    private val lockObjUB = new Lock();
    protected def tryLockObjUB() : Boolean {
        return lockObjUB.tryLock();
    }
    protected def lockObjUB() {
        if (!lockObjUB.tryLock()) {
            Runtime.increaseParallelism();
            lockObjUB.lock();
            Runtime.decreaseParallelism(1n);
        }
    }
    protected def unlockObjUB() {
        lockObjUB.unlock();
    }


	public def getObjUB() : Double { return objUB; }
	public def setObjUB(ub:Double) {
		lockObjUB();	
		if (objUB > ub)
			objUB = ub;
		unlockObjUB();	
	}


    static def cmpBoxes[K](vid:K, b1:IntervalVec[K], b2:IntervalVec[K]) {
        val b1l = b1.get(vid)().left;
        val b1r = b1.get(vid)().right;
        val b2l = b2.get(vid)().left;
        val b2r = b2.get(vid)().right;
        if (b1l != b2l)
            return b1l - b2l;
            //return b1r - b2r;
        else 
            return b1r - b2r;
            //return b1l - b2l;
    };

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K],
                    initResult:(Rail[IntervalVec[K]],Interval)=>R) {
        super(core, selector);

        this.goalVar = core.getGoalVar();

//lockList();
        //list = new LinkedList[IntervalVec[K]]();
        list = new PriorityLinkedList[IntervalVec[K]](
            (b1:IntervalVec[K], b2:IntervalVec[K])=>
                { return cmpBoxes[K](core.getGoalVar(), b1,b2); } );

        if (here.id() == 0) {
		    val box = core.getInitialDomain();
            list.add(box);
        }
//unlockList();

        solutions = new ArrayList[IntervalVec[K]]();

        this.initResult = initResult;
    }

    public def process(n:Long, context:Context[GlbQueueImplOpt[K,R], R]) : Boolean {
        var box:IntervalVec[K] = null;

try {
lockList();

        var i:Long = 0;
        for (; i < n && !list.isEmpty(); ++i) {

//var time:Long = -System.nanoTime();

            box = list.removeFirst();
//Console.OUT.println(here + ": search:\n" + box + '\n');

            // contract the domain of the obj function value

            //var objMax:Double;
            //if (objUB == Double.POSITIVE_INFINITY) objMax = Double.POSITIVE_INFINITY;
            //else objMax = 

            //val goalVar = core.getGoalVar();
            val goalVal = box.get(goalVar)().intersect(
                              new Interval(Double.NEGATIVE_INFINITY, objUB) );
            if (goalVal != null)
                box.put(goalVar, goalVal());
            else
                continue;

            // contract the box
            var res:Result = Result.unknown();
//logger.startProc();
            res = core.contract(box); 
//logger.stopProc();
            ++cntPrune;
//Console.OUT.println(here + ": contracted:\n" + box + '\n');

            if (!res.hasNoSolution()) {
                // update objUB
                val ub = core.updateObjUB(objUB, box);
lockObjUB();
            if (objUB > ub) {
                    objUB = ub;
//Console.OUT.println(here + ": ub: " + objUB);
                }
unlockObjUB();

                val v = selectVariable(res, box);
                if (v != null) {
//Console.OUT.println(here + ": split: " + v);
                    val bp = box.split(v());
                    ++cntBranch;
                    list.add(bp.first);
                    list.add(bp.second);
                }
                else {
                    val lb = box.get(goalVar)().left;
                    if (objLBEpsBox > lb)
                        objLBEpsBox = lb;

//Console.OUT.println(here + ": solution:\n: " + box.toString() + '\n');
		            solutions.add(box);
                }
            }        
        }
//Console.OUT.println(here + ": processed: " + cntPrune);

        //return i == n;
        return !list.isEmpty();
}
finally {
	unlockList();
}
    }

    @Inline static def format(t:Long) = (t as Double) * 1.0e-9;

    var tLogNext:Double = format(System.nanoTime());
    var ncBak:Long = 0;
    var ngBak:Long = 0;
    var nrBak:Long = 0;

    public def process(interval:Double, context:Context[GlbQueueImplOpt[K,R], R], logger:Logger) {
/*        var box:IntervalVec[K] = null;

        val tStart = System.nanoTime();

try {
lockList();

    	while (format(System.nanoTime()-tStart) < interval && !list.isEmpty()) {

//var time:Long = -System.nanoTime();

            box = list.removeFirst();
//Console.OUT.println(here + ": search:\n" + box + '\n');

            var res:Result = Result.unknown();
logger.startProc();
            res = core.contract(box); 
logger.stopProc();
            ++cntPrune;
 
            if (!res.hasNoSolution()) {
                val v = selectVariable(res, box);
                if (v != null) {
//Console.OUT.println(here + ": split: " + v);
                    val bp = box.split(v());
                    ++cntBranch;
                    list.add(bp.first);
                    list.add(bp.second);
                }
                else {
// count depth
logger.incrDepthCount(box.depth());
//Console.OUT.println(here + ": solution:");
val p = res.entails(Result.inner()) ? 5 : 3;
//Console.OUT.println("" + box.toString(p) + '\n');
		            solutions.add(box);
                }

val t = format(System.nanoTime());
while (t >= tLogNext) {
    tLogNext += logger.tInterval;
    val nc = count();
    val ng = logger.nodesGiven;
    val nr = logger.nodesReceived;
    logger.listNodesCount.add(nc - ncBak);
    logger.listNodesGiven.add(ng - ngBak);
    logger.listNodesReceived.add(nr - nrBak);
    logger.listQueueSize.add(list.size());
    ncBak = nc;
    ngBak = ng;
    nrBak = nr;
} 
            }        
            else { // hasNoSolution()
// count depth
logger.incrDepthCount(box.depth());
            }
        }
//Console.OUT.println(here + ": processed: " + cntPrune);

        return !list.isEmpty();
}
finally {
	unlockList();
}
*/
        return false;
    }

    public def split() {
try {
lockList();

        val sz = list.size();
        if (sz <= 1) {
            return null;
		}

        val bag = new GlbBagImpl[K](sz/2);
        bag.objUB = objUB;

        val list1 = new LinkedList[IntervalVec[K]]();

        val it = list.iterator();
        for (var i:Long = 0; it.hasNext(); ++i) {
            list1.addLast(it.next());
            if (it.hasNext())
                bag.data(i) = it.next();
        }

        list = list1;

        return bag;
}
finally {
	unlockList();
}
    }

    public def merge(bag:GlbBagImpl[K]) {
lockList();
        for (b in bag.data) if (b != null)
            list.add(b);
unlockList();
lockObjUB();
Console.OUT.println(here+": merge: "+objUB+" v. "+bag.objUB);
        if (objUB > bag.objUB)
            objUB = bag.objUB;
unlockObjUB();
    }

    public def merge(bag:TaskBag) {
        merge(bag as GlbBagImpl[K]);
    }

    // override
    public def printLog(sb:StringBuilder){
        sb.add("{\"# prunes\":" + cntPrune + 
            ", \"# branches\":" + cntBranch + 
            ", \"# solutions\":" + solutions.size() + "}");

		core.finalize();
    }

    @Inline public def count() = cntPrune;

    public def getResult() : GlbResultImpl[K,R] {
        return new GlbResultImpl[K,R](initResult(solutions.toRail(), 
                                          new Interval(objLBEpsBox, objUB) ));
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
