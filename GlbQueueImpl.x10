import x10.compiler.*;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.Box;
import x10.util.concurrent.Lock;
import x10.util.StringBuilder;
import x10.xrx.Runtime;

import glb.Context;
import glb.GLBResult;
import glb.TaskQueue;
import glb.TaskBag;
import glb.Logger;

public class GlbQueueImpl[K,R] extends BAPSolver[K] implements TaskQueue[GlbQueueImpl[K,R], R] {

    var list:List[IntervalVec[K]] = null;
    var cntPrune:Long = 0;
    var cntBranch:Long = 0;
    val solutions:ArrayList[IntervalVec[K]];

    val initResult:(Rail[IntervalVec[K]])=>R;

    private val listLock = new Lock();
    protected def tryLockList() : Boolean {
        return listLock.tryLock();
    }
    protected def lockList() {
        if (!listLock.tryLock()) {
            Runtime.increaseParallelism();
            listLock.lock();
            Runtime.decreaseParallelism(1n);
        }
    }
    protected def unlockList() {
        listLock.unlock();
    }

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K],
                    initResult:(Rail[IntervalVec[K]])=>R) {
        super(core, selector);

//lockList();
        list = new LinkedList[IntervalVec[K]]();
        if (here.id() == 0) {
		    val box = core.getInitialDomain();
            list.add(box);
        }
//unlockList();

        solutions = new ArrayList[IntervalVec[K]]();

        this.initResult = initResult;
    }

    public def process(n:Long, context:Context[GlbQueueImpl[K,R], R]) {
        var box:IntervalVec[K] = null;

try {
lockList();

        var i:Long = 0;
        for (; i < n && !list.isEmpty(); ++i) {

//var time:Long = -System.nanoTime();

            box = list.removeFirst();
//Console.OUT.println(here + ": search:\n" + box + '\n');

            var res:Result = Result.unknown();
            res = core.contract(box); 
            //res:Result = contract(sHandle, box);
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
val p = res.entails(Result.regular()) ? 5 : 3;
Console.OUT.println(here + ": solution:\n: " + box.toString() + '\n');
		            //solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
		            solutions.add(box);
                }
            }        
        }
//Console.OUT.println(here + ": processed: " + cntPrune);

        return i == n;
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

    public def process(interval:Double, context:Context[GlbQueueImpl[K,R], R], logger:Logger) {
        var box:IntervalVec[K] = null;

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
    }

    public def split() {
try {
lockList();

        val sz = list.size();
        if (sz <= 1)
            return null;

        val bag = new GlbBagImpl[K](sz/2);
        val list1 = new LinkedList[IntervalVec[K]]();
        val it = list.iterator();
        for (var i:Long = 0; it.hasNext(); ++i) {
            list1.add(it.next());
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
        return new GlbResultImpl[K,R](initResult(solutions.toRail()));
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
