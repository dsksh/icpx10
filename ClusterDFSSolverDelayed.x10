import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolverDelayed[K] extends ClusterDFSSolver[K] {

    // number of.splitting each component
    static val cutoffD = 4;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        initPhase = false;
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        addDom(Result.unknown(), core.getInitialDomain());

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            //at (Place(pi)) sHandle().sentRequest.set(true);
//Console.OUT.println(here + ": linked "+pi+" -> "+dst);
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }

        if (reqQueue.getSize() > 0) {
            val prec = list1.getFirst().second.width() / (cutoffD - 1);
            while (list1.getFirst().second.width() >= prec) {
                val pair = removeFirstDom();
                finish searchPP(sHandle, pair.first, pair.second);
       
                finish list1.sort(
                    (e1:Pair[Result,IntervalVec[K]],e2:Pair[Result,IntervalVec[K]]) =>
                        e2.second.volume().compareTo(e1.second.volume()) );
            }
        }

        initPhase = true;
    }

    protected def contractBox(box:IntervalVec[K]) {
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            addDom(res, box);
        }
        //else Console.OUT.println(here + ": no solution");
    }

    protected def searchPP(sHandle:PlaceLocalHandle[Solver[K]], res:Result, box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        //val pv:Box[K] = box.prevVar();
        val v = selectVariable(res, box);
        if (v != null) {
            val bp = box.split(v()); 
            nSplits.getAndIncrement();
                
            contractBox(bp.first);
            contractBox(bp.second);
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

    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
//Console.OUT.println(here + ": start pp");

        while (true) 
            if (initPhase) {
                if (reqQueue.getSize() == 0) {
                    while (!list1.isEmpty())
                        list.add(removeLastDom().second);
                        //atomic solutions.add(removeLastDom());
                }
                else {
                    while (reqQueue.getSize() > 0) {

                        // split boxes for # boxes times.
                        var n:Int = list1.size();
                        for (i in 1..n) {
                            val pair = removeFirstDom();
                            finish searchPP(sHandle, pair.first, pair.second);
    
                            finish list1.sort(
                                (e1:Pair[Result,IntervalVec[K]],e2:Pair[Result,IntervalVec[K]]) =>
                                    e2.second.volume().compareTo(e1.second.volume()) );
                        }

                        val pi = reqQueue.removeFirstUnsafe();
        
                        val nB = list1.size();
//Console.OUT.println(here + ": nB: " + nB);
                        var b:Boolean = true;
                        finish for (i in 1..nB) {
                            val pair = removeFirstDom();
                            at (b ? here : Place(pi)) sHandle().addDom(pair.first, pair.second);
//Console.OUT.println(here + ": append at " + (b ? here.id : pi));
//Console.OUT.println(here + ": " + pair.second);
nSends.getAndIncrement();
                            b = !b;
                        }

                        at (Place(pi)) atomic sHandle().initPhase = true;
                    }
                    while (!list1.isEmpty())
                        list.add(removeLastDom().second);
                        //atomic solutions.add(removeLastDom());
                }
                initPhase = false;
                break;
            }
            else when (initPhase) { }

        // TODO: load balancing might conflict with above procedure...
        super.solve(sHandle);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
