import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class Solver1 extends Solver {
    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    private var nProcs:Int = 0;
    public var nSplit:AtomicInteger = new AtomicInteger(0);
    private var request:AtomicBoolean = new AtomicBoolean(false);
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    private var finished:Boolean = false;
    //public var sHandle:PlaceLocalHandle[Solver1];

    public def this(filename:String, prec:Double) {
        super(filename, prec);
    }
    public def this(filename:String) {
        super(filename);
    }

    public def setup(sHandle:PlaceLocalHandle[Solver1]) {
        // split the initial domain (#P-1) times
        for (i in 1..Place.numPlaces()) {
            val box:IntervalVec = list.removeFirst();
            val v = selectVariable(box);
            val bp = box.split(v);
            nSplit.getAndIncrement();
            list.add(bp.first);
            list.add(bp.second);
        }
        
        // distribute the sub-domains
        //finish for (p in Place.places()) async {
        for (p in Place.places()) {
            if (p != here) {
                val box:IntervalVec = list.removeFirst();
                at (p) {
                    sHandle().list.add(box);
                }
            }
        }
    }


    protected def search(sHandle:PlaceLocalHandle[Solver1], box:IntervalVec) {
    //protected def search(box:IntervalVec) {
        //nProcs.getAndIncrement();

        //Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }

        if (!res.hasNoSolution()) {
            if (isSplittable(box)) {
                val v = selectVariable(box);
                val bp = box.split(v); 
                nSplit.getAndIncrement();
                //nSplit++;
                
                //Console.OUT.println(here + ": request: " + request.get() + '\n');

                if (request.compareAndSet(true, false)) {
                    //request.set(false);
                    Console.OUT.println(here + ": got request");
                    at (here.next()) {
                        atomic sHandle().list.add(bp.first);
                    }
                }
                else {
                    atomic nProcs++;
                    async search(sHandle, bp.first);
                }

                //nProcs.getAndIncrement();
                atomic nProcs++;
                async search(sHandle, bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec](res, box));
                Console.OUT.println(here + ": solution:\n" + box + '\n');
            }
        }
        //else Console.OUT.println("no solution");

        //nProcs.getAndDecrement();
        atomic nProcs--;
        //Console.OUT.println(here + ": nProcs: " + nProcs + '\n');
    }

    protected def getNextBox(sHandle:PlaceLocalHandle[Solver1]) : IntervalVec {
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
   		        Console.OUT.println(here + ": set request");
                sHandle().request.set(true);
            }
            when (!list.isEmpty() || finished) {
   		        Console.OUT.println(here + ": activated");
                if (!list.isEmpty()) {
   		            Console.OUT.println(here + ": got box");
                    return list.removeFirst();
                }
                else {
                    return null;
                }
            }
        }
    }

    public def solve(sHandle:PlaceLocalHandle[Solver1]) {
    //public def solve() {
   		Console.OUT.println(here + ": start solving... ");

        //while (!finished.get()) {
        //while (!finished) {
        finish while (true) {
            val box:IntervalVec = getNextBox(sHandle);
            if (box != null) {
                //nProcs.getAndIncrement();
                atomic nProcs++;
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
	            Console.OUT.println(here + ": set finished");
                //sHandle().finished.set(true);
                sHandle().finished = true;
            }
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
