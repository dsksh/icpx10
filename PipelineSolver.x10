import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;

public class PipelineSolver[K] extends Solver[K] {
    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    private var request:AtomicBoolean = new AtomicBoolean(false);
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    private var finished:Boolean = false;
    //public var sHandle:PlaceLocalHandle[PipelineSolver[K]];

    public def this(selector:(box:IntervalVec[K])=>Box[K], filename:String) {
        super(selector, filename);
    }

    public def setup(sHandle:PlaceLocalHandle[PipelineSolver[K]]) {
        /*// split the initial domain (#P-1) times
        for (i in 1..(Place.numPlaces()-1)) {
            val box:IntervalVec[K] = list.removeFirst();
            val v = selectVariable(box);
            val bp = box.split(v);
            nSplits.getAndIncrement();
            list.add(bp.first);
            list.add(bp.second);
        }
        
        // distribute the sub-domains
        //finish for (p in Place.places()) async {
        for (p in Place.places()) {
            if (p != here) {
                val box:IntervalVec[K] = list.removeFirst();
                at (p) {
                    sHandle().list.add(box);
                }
            }
        }
        */
    }


    protected def search(sHandle:PlaceLocalHandle[PipelineSolver[K]], box:IntervalVec[K]) {
    //protected def search(box:IntervalVec[K]) {
        //nProcs.getAndIncrement();
        //Console.OUT.println(here + ": nProcs: " + nProcs);

//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            val v = selectVariable(box);
            if (v != null) {
                val bp = box.split(v); 
                nSplits.getAndIncrement();
                
                if (request.compareAndSet(true, false)) {
                    Console.OUT.println(here + ": got request");
                    at (here.next()) {
                        atomic sHandle().list.add(bp.first);
                    }
                    nSends.getAndIncrement();
                }
                else {
                    //nProcs.getAndIncrement();
                    async search(sHandle, bp.first);
                }

                //nProcs.getAndIncrement();
                async search(sHandle, bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                Console.OUT.println(here + ": solution:\n" + box + '\n');
                nSols.getAndIncrement();
            }
        }
        //else Console.OUT.println("no solution");

        //nProcs.getAndDecrement();
    }

    protected def getNextBox(sHandle:PlaceLocalHandle[PipelineSolver[K]]) : IntervalVec[K] {
        if (!list.isEmpty())
            return list.removeFirst();
        else if (here.id() == 0) {
//            //when (nProcs.get() == 0) {
//            when (nProcs == 0) {
//                //finished.set(true);
//                atomic finished = true;
//                /*at (here.next()) {
//       		        Console.OUT.println(here + ": set finished");
//                    //sHandle().finished.set(true);
//                    sHandle().finished = true;
//                }*/
//                //if (request.get()) {
//                //}
//       		    Console.OUT.println(here + ": finished");
//                return null;
//            }
            return null;
        }
        else {
   		    //Console.OUT.println(here + ": request box to " + here.prev());
            at (here.prev()) {
                sHandle().request.set(true);
   		        Console.OUT.println(here + ": set request");
            }
            when (!list.isEmpty() || finished) {
   		        //Console.OUT.println(here + ": activated");
                if (!list.isEmpty()) {
   		            //Console.OUT.println(here + ": got box");
                    return list.removeFirst();
                }
                else {
                    return null;
                }
            }
        }
    }

    public def solve(sHandle:PlaceLocalHandle[PipelineSolver[K]]) {
    //public def solve() {
   		Console.OUT.println(here + ": start solving... ");

        //while (!finished.get()) {
        //while (!finished) {
        finish while (true) {
            val box:IntervalVec[K] = getNextBox(sHandle);
            if (box != null) {
                //nProcs.getAndIncrement();
                search(sHandle, box);
            }
            else break;
        }

        if (here.id() == 0) {
            //finished.set(true);
            atomic finished = true;
        }

        //if (here.id() == Place.numPlaces()-1) 
        at (here.next()) {
            when (sHandle().list.isEmpty()) {
	            //Console.OUT.println(here + ": set finished");
                //sHandle().finished.set(true);
                sHandle().finished = true;
            }
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
