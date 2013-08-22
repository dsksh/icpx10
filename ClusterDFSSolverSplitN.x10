import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolverSplitN[K] extends ClusterDFSSolver[K] {
    val maxNSplits:Int = 1;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        var dst:Int = 0;
        var pow:Int = 1;
        var i:Int = 0;
        for (pi in 1..(Place.numPlaces()-1)) {
//Console.OUT.println(here + ": "+pi+", "+dst+", "+pow+", "+i);
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            at (Place(pi)) sHandle().sentRequest.set(true);
            if (++i == Math.pow2(maxNSplits)-1) {
                i = 0;
                if (++dst == pow) { 
                    dst = 0; 
                    pow *= Math.pow2(maxNSplits); 
                }
            }
        }
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();
//Console.OUT.println(here + ": contracted:\n" + box + '\n');

        if (!res.hasNoSolution()) {
            // destination list
            var nS:Int = -1;
            var ids:ArrayList[Int] = null;
            atomic {
                nS = Math.min(maxNSplits, Math.log2(reqQueue.getSize()+1));
                ids = new ArrayList[Int](Math.pow2(nS));
                for (i in 2..Math.pow2(nS)) {
                    val id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from " + id);
                    ids.add(id);
                }
                ids.add(here.id());
            }
            if (ids.size() == 1) { ids.add(here.id()); nS++; }
//Console.OUT.println(here+": ids.size' = "+ids.size());
//Console.OUT.println(here+": nS: "+nS);

            // prepare n boxes
            val boxes = new ArrayList[IntervalVec[K]](ids.size());
            boxes.add(box);
            var nB:Int = 1;
            if (nS > 0)
            for (i in 0..(nS-1)) {
                val prev = i>0 ? Math.pow2(i-1) : 1;
                for (j in 0..(prev-1)) {
                    var v:Box[K] = selectVariable(res, boxes.get(j));
                    if (v != null) {
                        val bp = boxes.get(j).split(v()); 
                        nSplits.getAndIncrement();
                        boxes.set(bp.first, j);
                        boxes.add(bp.second); nB++;
//Console.OUT.println(here+": ("+i+","+j+"), bp.second: "+bp.second);
                    }
                    else break;
                }
            }

            if (nB == 1) { // cannot split
                atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                //Console.OUT.println(here + ": solution:");
                //val plot = res.entails(Solver.Result.inner()) ? 5 : 3;
                //atomic { 
                //    Console.OUT.println(box.toString(plot));
                //    Console.OUT.println(); 
                //}
                nSols.getAndIncrement();
            }
            else {
                val pv:Box[K] = box.prevVar();
                for (i in 0..(ids.size()-1)) {
                    if (i < nB) {
                        val src = here.id();
                        val dst = ids.get(i);
                        val b = boxes.get(i);
                        if (src == dst) {
                            async
                            search(sHandle, b);
                        }
                        else {
                            async at (Place(dst)) {
                                sHandle().sentRequest.set(false);
                                b.setPrevVar(pv);
                                atomic sHandle().list.add(b);
                            }
//Console.OUT.println(here + ": responded to " + dst);
//Console.OUT.println(b);

                            if (dst < src) sentBw.set(true);
                            nSends.getAndIncrement();
                        }
                    }
                    else {
                        reqQueue.addLast(ids.get(i));
                    }
                }
            }
        }
        //else Console.OUT.println(here + ": no solution");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
