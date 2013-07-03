import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolver[K] extends Solver[K] {
    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    private val reqQueue:CircularQueue[Int];
    private var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    private var terminate : Int = 0;
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    private var finished:Boolean = false;
    private var sentBw:AtomicBoolean = new AtomicBoolean(false);
    //public var sHandle:PlaceLocalHandle[ClusterDFSSolver[K];
    private random:Random;

    public def this(core:Core[K], selector:(box:IntervalVec[K])=>Box[K], filename:String) {
        super(core, selector, filename);
        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random();
    }

    public def setup(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]]) {
        // split the initial domain (#P-1) times
        for (i in 1..(Place.numPlaces()-1)) {
            val box:IntervalVec[K] = list.removeFirst();
            val v = selectVariable(box)();
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
    }


    protected def search(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {

            var id:Int = -1;
            atomic if (reqQueue.getSize() > 0) {
                id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got id: " + id);
            }
            if (id >= 0) {
                at (Place(id)) {
                    atomic sHandle().list.add(box);
                }
//Console.OUT.println(here + ": responded to " + id);
                if (id < here.id()) sentBw.set(true);
                nSends.getAndIncrement();
                return;
            }

            val v = selectVariable(box);
            if (v != null) {
                val bp = box.split(v()); 
                nSplits.getAndIncrement();
                
                /*var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got id: " + id);
                }
                if (id >= 0) {
                    at (Place(id)) {
                        atomic sHandle().list.add(bp.first);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                }
                else {
                    async search(sHandle, bp.first);
                }*/
                async 
                search(sHandle, bp.first);

                async 
                search(sHandle, bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                Console.OUT.println(here + ": solution:\n" + box + '\n');
                nSols.getAndIncrement();
            }
        }
        //else Console.OUT.println("no solution");
    }

    var selected:Place = here;
    protected def selectPlace() : Place {
        /*var id:Int;
        do {
            //id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);
        */

        do selected = selected.next(); while (Place.numPlaces() > 1 && selected == here);
        return selected;

        //return here.prev();
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    protected def getNextBox(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]]) : IntervalVec[K] {
        if (!list.isEmpty())
            return list.removeFirst();
        else {
            //val t = getAndResetTerminate();
            if (here.id() == 0) {
                at (here.next()) atomic sHandle().terminate = 1;
//Console.OUT.println(here + ": sent token to " + here.next());
            }

            if (!sentRequest.getAndSet(true)) {
            //val srG = GlobalRef[AtomicBoolean](sentRequest);
            //while (!sentRequest.get()) {
                val id = here.id();
                at (selectPlace()) {
                    //if (sHandle().reqQueue.getSize() == 0) {
                    sHandle().reqQueue.addLast(id);
//Console.OUT.println(here + ": requested from " + id);
                    //at (srG.home) { srG().set(true); }
                    //}
                }
                nReqs.getAndIncrement();
            }

/*            while (true) {
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) 
                    id = reqQueue.removeFirstUnsafe();
                if (id == -1) break;           
                else {
Console.OUT.println(here + ": resend " + id);
                    at (selectPlace()) {
                        sHandle().reqQueue.addLast(id);
                    }
                }
            }
*/

//Console.OUT.println(here + ": wait...");

            when (!list.isEmpty() || terminate > 0 /*|| reqQueue.getSize() > 0*/) {
            //when (!list.isEmpty() || terminate > 0) {
//Console.OUT.println(here + ": activated");
                if (!list.isEmpty()) {
                    sentRequest.set(false);
//Console.OUT.println(here + ": got box");
                    return list.removeFirst();
                }
                else if (terminate > 0) {
//Console.OUT.println(here + ": " + terminate);
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
                else {
                    return getNextBox(sHandle);
                }
            }
        }
    }

    public def solve(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            val box:IntervalVec[K] = getNextBox(sHandle);
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
//Console.OUT.println(here + ": passed the token " + v + " to " + here.next());
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
