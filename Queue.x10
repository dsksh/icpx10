import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.util.concurrent.AtomicDouble;

import x10.glb.Context;
import x10.glb.GLBResult;
import x10.glb.TaskQueue;
import x10.glb.TaskBag;

// kludge for "Interval is incomplete type" error
class Dummy_Queue {
    val dummy : Interval = new Interval(0.,0.);
    val dummyVec : IntervalVec[Long] = new IntervalArray(0);
}

public class Queue[K] extends BAPSolver[K] implements TaskQueue[Queue[K], Long] {
    var list:List[IntervalVec[K]] = null;
    var count:Long = 0;
    val solutions:List[Pair[BAPSolver.Result,IntervalVec[K]]];

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);

        list = new LinkedList[IntervalVec[K]]();
        if (here.id() == 0) {
		    val box = core.getInitialDomain();
Console.OUT.println(here + ": init:\n" + box + '\n');
            list.add(box);
        }

        solutions = new ArrayList[Pair[BAPSolver.Result, IntervalVec[K]]]();
    }

    public def process(n:Long, context:Context[Queue[K], Long]) {
        var box:IntervalVec[K] = null;

        var i:Long = 0;
        for (; i < n && !list.isEmpty(); ++i) {

//var time:Long = -System.nanoTime();

            box = list.removeFirst();
//Console.OUT.println(here + ": search:\n" + box + '\n');

            var res:Result = Result.unknown();
            res = core.contract(box); 
            //res:Result = contract(sHandle, box);
            ++count;
 
            if (!res.hasNoSolution()) {
                val v = selectVariable(res, box);
                if (v != null) {
//Console.OUT.println(here + ": split: " + v);
                    val bp = box.split(v());
                    list.add(bp.first);
                    list.add(bp.second);
                }
                else 
		            solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
            }        
        }
//Console.OUT.println(here + ": processed: " + count);
        return i == n;
    }

    public def split() {
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

    public def merge(bag:Bag[K]) {
        for (b in bag.data)
            list.add(b);
    }

    public def merge(bag:TaskBag) {
        merge(bag as Bag[K]);
    }

    // override
    public def printLog(){
    }

    @Inline public def count() = count;


    var result:RPX10Result = null;
    public def getResult(): RPX10Result {
        return new RPX10Result();
    }

    /*public class RPX10Result extends GLBResult[IntervalVec[K]]{
        r:Rail[IntervalVec[K]];
        public def this(sols:List[Pair[Result,IntervalVec[K]]]) {
            //r = new Rail[IntervalVec[K]](sols.size);
            r = new Rail[IntervalVec[K]](1);
            //var i = 0;
            //for (b in r) {
            //    res(i++) = b.second;
            //}
            r(0) = sols(0).second;
        }
        public def getResult() : Rail[IntervalVec[K]] {
            return (solutions as ArrayList[IntervalVec[K]]).toRail();
        }
        public def getReduceOperator() : Int {
            return Team.AND;
        }
        public def display(r:Rail[IntervalVec[K]]) : void {
            Console.OUT.println("# results: " + r.size);
        }

        public operator this+(r1:RPX10Result) : RPX10Result {
            //val res = new Rail[IntervalVec[K]](r.size + r1.size);
            //var i = 0;
            //for (b in r) {
            //    res(i++) = b;
            //}
            //for (b in r1) {
            //    res(i++) = b;
            //}
            //return res;
            return new RPX10Result(solutions);
        }
    }
    */
    public class RPX10Result extends GLBResult[Long] {
        r:Rail[Long] = new Rail[Long](1);
        public def getResult() : Rail[Long] {
            r(0) = count;
            return r;
        }
        public def getReduceOperator() : Int {
            return Team.ADD;
        }
        public def display(r:Rail[Long]) : void {
            Console.OUT.println("# results: " + r(0) +", "+ r.size);
        }
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
