import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

// FIXME: initPhase should be turned off.

public class ClusterDFSSolverSwitched[K] extends ClusterDFSSolver[K] {

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        super.setup(sHandle);

        contractBox(list.getFirst());
    }

    protected def contractBox(box:IntervalVec[K]) {
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();
        return res;
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
        if (box.size() > 0) // for dummy boxes
            searchSw(sHandle, Result.unknown(), box);
    }

    protected def searchSw(sHandle:PlaceLocalHandle[Solver[K]], res:Result, box:IntervalVec[K]) {
//Console.OUT.println(here + ": searchSw:\n" + box + '\n');

//if (reqQueue.getSize() == 0)
//    initPhase = false;

        val v = selectVariable(res, box);
        if (v != null) {
            val bp = box.split(v()); 
            nSplits.getAndIncrement();
                
            val resL = contractBox(bp.first);
            val resR = contractBox(bp.second);
            if (!resL.hasNoSolution() && !resR.hasNoSolution()) {
//Console.OUT.println(here + ": both");
//nBranches.getAndIncrement();
                val pv:Box[K] = box.prevVar();
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from: " + id);
                }
                if (id >= 0) {
                    val p = Place(id);
                    async at (p) {
                        sHandle().sentRequest.set(false);
                        bp.first.setPrevVar(pv);
                        atomic sHandle().list.add(bp.first);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                }
                else {
                    async 
                    searchSw(sHandle, resL, bp.first);
                }

                async searchSw(sHandle, resR, bp.second);
            }
            else if (!resL.hasNoSolution()) {
//Console.OUT.println(here + ": left");
//if (bp.first.width() > 1e-8)
//nBranches.getAndIncrement();
                async searchSw(sHandle, resL, bp.first);
            }
            else if (!resR.hasNoSolution()) {
//Console.OUT.println(here + ": right");
//if (bp.first.width() > 1e-8)
//nBranches.getAndIncrement();
                async searchSw(sHandle, resR, bp.second);
            }
            //else Console.OUT.println(here + ": no solution");
        }
        else {
            atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
            /*Console.OUT.println(here + ": solution:");
            val plot = res.entails(Solver.Result.inner()) ? 5 : 3;
            atomic { 
                Console.OUT.println(box.toString(plot));
                Console.OUT.println(); 
            }
            */
            nSols.getAndIncrement();
        }
    }    
}

// vim: shiftwidth=4:tabstop=4:expandtab
