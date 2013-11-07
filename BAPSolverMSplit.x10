import x10.util.*;
import x10.io.Console; 

public class BAPSolverMSplit[K] extends BAPSolver[K] {

    val maxNSplits:Int = 1;

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
Console.OUT.println(here + ": search:\n" + box + '\n');

        // for dummy boxes
        if (box.size() == 0)
            return;

        val res:Result = contract(sHandle, box);
        
        if (!res.hasNoSolution()) {
            // prepare destination list
            val reqList = sHandle().getMultipleRequests(maxNSplits);
Console.OUT.println(here+": # reqs = "+reqList.size());

/*            var nS:Int = -1;
            var ids:ArrayList[Int] = null;
            atomic {
                nS = Math.min(maxNSplits, Math.log2(reqQueue.getSize()+1));
Console.OUT.println(here+": # reqs = "+(reqQueue.getSize()+1));
Console.OUT.println(here+": log2 = "+Math.log2(reqQueue.getSize()+1));
                ids = new ArrayList[Int](Math.pow2(nS));
                for (i in 2..ids.size()) {
                    val id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from " + id);
                    ids.add(id);
                }
            }
*/
            reqList.add(here.id());
            if (reqList.size() == 1) // split at least once.
                reqList.add(here.id());

            // prepare (# reqs) boxes
            val bList = new ArrayList[IntervalVec[K]](reqList.size());
            bList.add(box);
            while (bList.size() < reqList.size() && !bList.isEmpty()) {
                val b = bList.removeFirst();
                val v:Box[K] = selectVariable(res, b);
                if (v != null) {
                    val bp = b.split(v()); 
                    sHandle().nSplits.getAndIncrement();
                    bList.add(bp.first);
                    bList.add(bp.second);
//Console.OUT.println(here+": ("+i+","+j+"), bp.second: "+bp.second);
                }
                else {
                    sHandle().addSolution(res, b);
//                    break;
                }
            }
Console.OUT.println(here+": # boxes = "+bList.size());

/*            var nB:Int = 1;
            for (i in 1..nS) {
                val prev = i==1 ? 1 : Math.pow2(i-2);
                for (j in 0..(prev-1)) {
                    var v:Box[K] = selectVariable(res, boxes.get(j));
                    if (v != null) {
                        val bp = boxes.get(j).split(v()); 
                        nSplits.getAndIncrement();
                        boxes.set(bp.first, j);
                        boxes.add(bp.second); nB++;
Console.OUT.println(here+": ("+i+","+j+"), bp.second: "+bp.second);
                    }
                    else break;
                }
            }
*/

            val pv:Box[K] = box.prevVar();
            finish while (!reqList.isEmpty()) {
                val req = reqList.removeLast();
                if (!bList.isEmpty()) {
                    val b = bList.removeLast();
                    if (req == here.id()) {
                        async 
                        search(sHandle, b);
                    }
                    else {
                        async 
                        at (Place(req)) {
                            b.setPrevVar(pv);
                            atomic sHandle().list.add(b);
                        }
Console.OUT.println(here + ": responded to " + req);
//Console.OUT.println(box);

                        if (req < here.id()) sentBw.set(true);
                        sHandle().nSends.getAndIncrement();
                    }
                }
                else {
                    if (req != here.id())
                        sHandle().reqQueue.addLast(req);
                }
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
