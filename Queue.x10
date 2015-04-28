import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.util.concurrent.AtomicDouble;
import x10.util.StringBuilder;

import glb.Context;
import glb.GLBResult;
import glb.TaskQueue;
import glb.TaskBag;
import glb.Logger;

// kludge for "Interval is incomplete type" error
class Dummy_Queue {
    val dummy : Interval = new Interval(0.,0.);
    val dummyVec : IntervalVec[Long] = new IntervalArray(0);
}

public class Queue[K] extends BAPSolver[K] 
  implements TaskQueue[Queue[K], Long] {
  //implements TaskQueue[Queue[K], SolutionSet[K]] {

    var list:List[IntervalVec[K]] = null;
    var cntPrune:Long = 0;
    var cntBranch:Long = 0;
    //val solutions:ArrayList[Pair[BAPSolver.Result,IntervalVec[K]]];
    val solutions:ArrayList[IntervalVec[K]];

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

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);

//lockList();
        list = new LinkedList[IntervalVec[K]]();
        if (here.id() == 0) {
		    val box = core.getInitialDomain();
            list.add(box);
        }
//unlockList();

        //solutions = new ArrayList[Pair[BAPSolver.Result, IntervalVec[K]]]();
        solutions = new ArrayList[IntervalVec[K]]();
    }

    public def process(n:Long, context:
      Context[Queue[K], Long]) 
      //Context[Queue[K], SolutionSet[K]]) 
    {
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
                else 
		            //solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
		            solutions.add(box);
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

    public def process(interval:Double, context:Context[Queue[K], Long], logger:Logger) {
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
		            //solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
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

        val bag = new Bag[K](sz/2);
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

    public def merge(bag:Bag[K]) {
lockList();
        for (b in bag.data) if (b != null)
            list.add(b);
unlockList();
    }

    public def merge(bag:TaskBag) {
        merge(bag as Bag[K]);
    }

    // override
    public def printLog(sb:StringBuilder){
        sb.add("{\"# prunes\":" + cntPrune + 
            ", \"# branches\":" + cntBranch + 
            ", \"# solutions\":" + solutions.size() + "}");

		core.finalize();
    }

    @Inline public def count() = cntPrune;


    //var result:RPX10Result = null;
    public def getResult(): RPX10Result {
        return new RPX10Result();
    }

    public class RPX10Result extends GLBResult[Long] {
        r:Rail[Long] = new Rail[Long](1);
        public def getResult() : Rail[Long] {
            r(0) = solutions.size();
            return r;
        }
        public def getReduceOperator() : Int {
            return Team.ADD;
        }
        public def display(r:Rail[Long]) : void {
            Console.OUT.println("\"# sols\" : " + r(0) + ",");
            Console.OUT.println();
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
