import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class BAPSolverImpl[K] extends BAPSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    protected def contract(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) : Result {
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
    
var sid0:Long = 0;

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
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
}

// vim: shiftwidth=4:tabstop=4:expandtab
