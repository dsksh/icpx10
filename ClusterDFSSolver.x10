import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolver extends Solver {
    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    private val reqQueue:CircularQueue[Int];
    private var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    private var terminate : Int = 0;
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    private var finished:Boolean = false;
    private var sentBw:AtomicBoolean = new AtomicBoolean(false);
    //public var sHandle:PlaceLocalHandle[ClusterDFSSolver];
    private random:Random;

    public def this(selector:(box:IntervalVec)=>String, filename:String) {
        super(selector, filename);
        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random();
    }

    public def setup(sHandle:PlaceLocalHandle[ClusterDFSSolver]) {
        // split the initial domain (#P-1) times
        for (i in 1..(Place.numPlaces()-1)) {
            val box:IntervalVec = list.removeFirst();
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
                val box:IntervalVec = list.removeFirst();
                at (p) {
                    sHandle().list.add(box);
                }
            }
        }
    }


    protected def search(sHandle:PlaceLocalHandle[ClusterDFSSolver], box:IntervalVec) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            val v = selectVariable(box);
            if (v != null) {
                val bp = box.split(v); 
                nSplits.getAndIncrement();
                
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
Console.OUT.println(here + ": got id: " + id);
                }
                if (id >= 0) {
                    at (Place(id)) {
                        atomic sHandle().list.add(bp.first);
                    }
                    Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                }
                else {
                    async search(sHandle, bp.first);
                }

                async search(sHandle, bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec](res, box));
                Console.OUT.println(here + ": solution:\n" + box + '\n');
                nSols.getAndIncrement();
            }
        }
        //else Console.OUT.println("no solution");
    }

    protected def selectPlace() : Place {
        var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && id == here.id());


        return Place(id);
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    protected def getNextBox(sHandle:PlaceLocalHandle[ClusterDFSSolver]) : IntervalVec {
        if (!list.isEmpty())
            return list.removeFirst();
        else {
            //val t = getAndResetTerminate();
            if (here.id() == 0) {
                at (here.next()) atomic sHandle().terminate = 1;
   		        Console.OUT.println(here + ": sent token to " + here.next());
            }
            //if (1 <= t && t <= 2) {
            //    val v = sentBw.getAndSet(true) ? 2 : t;
   		    //    Console.OUT.println(here + ": passed the token " + v + " to " + here.next());
            //    at (here.next()) sHandle().terminate = v;
            //}

            if (!sentRequest.getAndSet(true)) {
       		    //Console.OUT.println(here + ": request box to " + here.prev());
                val id = here.id();
                at (selectPlace()) {
                    sHandle().reqQueue.addLast(id);
       		        Console.OUT.println(here + ": requested from " + id);
                }
            }

Console.OUT.println(here + ": wait...");

            when (!list.isEmpty() || terminate > 0) {
   		        Console.OUT.println(here + ": activated");
                if (!list.isEmpty()) {
                    sentRequest.set(false);
   		            Console.OUT.println(here + ": got box");
                    return list.removeFirst();
                }
                else {
Console.OUT.println(here + ": " + terminate);
/*                    if (here.id() == 0 && terminate == 1 || terminate == 3) {
                        //at (here.next()) atomic sHandle().terminate = 3;
                        return null;
                    }
                    else { // if (t < 3)
                        //val v = sentBw.get() ? 2 : t;
                        //at (here.next()) atomic sHandle().terminate = v;
                        return getNextBox(sHandle);
                    }
                    */
                    return null;
                }
            }
        }
    }

    public def solve(sHandle:PlaceLocalHandle[ClusterDFSSolver]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            val box:IntervalVec = getNextBox(sHandle);
            if (box != null) {
                //nProcs.getAndIncrement();
                finish search(sHandle, box);
            }
            else {
                val t = getAndResetTerminate();
                if (here.id() == 0 && t == 2) 
                    continue; 

                if (here.id() > 0 && 1 <= t && t <= 2) {
                    val v = sentBw.getAndSet(false) ? 2 : t;
                    at (here.next()) atomic sHandle().terminate = v;
        	        Console.OUT.println(here + ": passed the token " + v + " to " + here.next());
                    continue; 
                }

                break;
            }
        }

        //if (here.id() == 0) {
            //finished.set(true);
            //atomic finished = true;
            at (here.next()) atomic sHandle().terminate = 3;
        //}


/*        //if (here.id() == Place.numPlaces()-1) 
        at (here.next()) {
            when (sHandle().list.isEmpty()) {
	            //Console.OUT.println(here + ": set finished");
                //sHandle().finished.set(true);
                sHandle().finished = true;
            }
        }
*/

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
