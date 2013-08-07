import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolver[K] extends Solver[K] {
    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    //private val reqQueue:CircularQueue[Int];
    //private var terminate : Int = 0;
    //private var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    private var finished:Boolean = false;
    //private var sentBw:AtomicBoolean = new AtomicBoolean(false);
    //public var sHandle:PlaceLocalHandle[ClusterDFSSolver[K];
    private random:Random;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        //reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random();
    }

    //public def setup(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]]) {
    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
/*        // split the initial domain (#P-1) times
        for (i in 1..(Place.numPlaces()-1)) {
            val box:IntervalVec[K] = list.removeFirst();
            val v = selectVariable(Result.unknown(), box)();
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

        if (here.next().id() != 0) {
            reqQueue.addLast(here.next().id());
            at (here.next()) {
                sHandle().sentRequest.set(true);
            }
        }
    }


    protected def search(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            //val pv:Box[K] = box.prevVar();
            val v = selectVariable(res, box);
            if (v != null) {

                /*var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got id: " + id);
                }
                if (id >= 0) {
                    at (Place(id)) {
                        sHandle().sentRequest.set(false);
                        box.setPrevVar(pv);
                        atomic sHandle().list.add(box);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                    return;
                }*/

                val bp = box.split(v()); 
                nSplits.getAndIncrement();
                
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got id: " + id);
                }
                if (id >= 0) {
                    at (Place(id)) {
                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(bp.first);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                }
                else {
                    //async 
                    search(sHandle, bp.first);
                }
                //async 
                //search(sHandle, bp.first);
                //async 
                search(sHandle, bp.second);
            }
            else {
                //atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
                Console.OUT.println(here + ": solution:");
                val plot = res.entails(Solver.Result.inner()) ? 5 : 3;
                atomic { 
                    Console.OUT.println(box.toString(plot));
                    Console.OUT.println(); 
                }
                nSols.getAndIncrement();
            }
        }
        //else Console.OUT.println("no solution");
    }

    var selected:Iterator[Place] = null;
    protected def selectPlace() : Place {
        /*var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);
        */

        if (selected == null || !selected.hasNext())
            selected = Place.places().iterator();
        val p = selected.next();
        if (p != here) {
//Console.OUT.println(here + ": selected " + p);
            return p;
        }
        else
            return selectPlace();

        //return here.prev();
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

//    protected def getNextBox(sHandle:PlaceLocalHandle[Solver[K]]) : IntervalVec[K] {
//        if (!list.isEmpty())
//            return list.removeFirst();
//        else {
//            //val t = getAndResetTerminate();
//            if (here.id() == 0) {
//                at (here.next()) {
//                    atomic sHandle().terminate = 1;
//                    // put a dummy box
//                    atomic sHandle().list.add(sHandle().core.dummyBox());
//                }
////atomic Console.OUT.println(here + ": sent token to " + here.next());
//                //return null;
//            }
//
//            else if (!sentRequest.getAndSet(true)) {
//            //val srG = GlobalRef[AtomicBoolean](sentRequest);
//            //while (!sentRequest.get()) {
//                val id = here.id();
//                at (selectPlace()) {
//                    //if (sHandle().reqQueue.getSize() == 0) {
//                    sHandle().reqQueue.addLast(id);
////Console.OUT.println(here + ": requested from " + id);
//                    //at (srG.home) { srG().set(true); }
//                    //}
//                }
//                nReqs.getAndIncrement();
//            }
//
////Console.OUT.println(here + ": wait...");
//
//            when (!list.isEmpty() /*|| terminate > 0 || reqQueue.getSize() > 0*/) {
//            //when (!list.isEmpty() || terminate > 0) {
////Console.OUT.println(here + ": activated");
//                if (!list.isEmpty()) {
//                    sentRequest.set(false);
////Console.OUT.println(here + ": got box");
//                    return list.removeFirst();
//                }
//                else if (terminate > 0) {
////Console.OUT.println(here + ": " + terminate);
//                    /*if (here.id() == 0 && terminate == 1 || terminate == 3) {
//                        //at (here.next()) atomic sHandle().terminate = 3;
//                        return null;
//                    }
//                    else { // if (t < 3)
//                        //val v = sentBw.get() ? 2 : t;
//                        //at (here.next()) atomic sHandle().terminate = v;
//                        return getNextBox(sHandle);
//                    }
//                    */
//                    return null;
//                }
//                else {
//                    return getNextBox(sHandle);
//                }
//            }
//        }
//    }

/*    //public def solve(sHandle:PlaceLocalHandle[ClusterDFSSolver[K]]) {
    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            val box:IntervalVec[K] = getNextBox(sHandle);
            if (box != null && terminate == 0) {
                //nProcs.getAndIncrement();
                finish search(sHandle, box);
            }
            else {
                val t = getAndResetTerminate();
                if (here.id() == 0) {
                    if (terminate > 0) {
Console.OUT.println(here + ": " + terminate);
                    if (terminate != 2) break;
                    else continue;
                }

                if (here.id() > 0 && 1 <= t && t <= 2) {
                    val v = sentBw.getAndSet(false) ? 2 : t;
                    at (here.next()) {
                        atomic sHandle().terminate = v;
                        // put a dummy box
                        atomic sHandle().list.add(sHandle().core.dummyBox());
                    }
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

   		Console.OUT.println(here + ": done");
    }
*/
    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            if (!list.isEmpty()) {
                val box = list.removeFirst();
                finish async search(sHandle, box);
            }

            else { //if (list.isEmpty()) {

                val t = getAndResetTerminate();

                // begin termination detection
                if (here.id() == 0 && (t == 0 || t == 2)) {
                    at (here.next()) atomic {
                        sHandle().terminate = 1;
                        sHandle().sentBw.set(false);
                        // put a dummy box
                        sHandle().list.add(sHandle().core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token 1 to " + here.next());
                }
                // termination token went round.
                else if (here.id() == 0 && t == 1) {
                    //val t = getAndResetTerminate();
                    if (t == 1) {
                        at (here.next()) atomic {
                            sHandle().terminate = 3;
                            sHandle().list.add(sHandle().core.dummyBox());
                        }
//Console.OUT.println(here + ": sent token 3 to " + here.next());
                        break;
                    }
                    //else if (t == 2) continue;
                }
                else if (here.id() > 0 && t > 0) {
                    val v = (t == 1 && sentBw.get()) ? 2 : t;
                    at (here.next()) atomic {
                        sHandle().terminate = v;
                        sHandle().sentBw.set(false);
                        sHandle().list.add(sHandle().core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token " + v + " to " + here.next());
                    if (t == 3) break;
                }

                // request for a domain
                if (Place.numPlaces() > 1 && !sentRequest.getAndSet(true)) {
                    val id = here.id();
                    at (selectPlace()) {
                        sHandle().reqQueue.addLast(id);
//Console.OUT.println(here + ": requested from " + id);
                    }
                    nReqs.getAndIncrement();
                }

//Console.OUT.println(here + ": wait...");

                when (!list.isEmpty()) {
                    //sentRequest.set(false);
//Console.OUT.println(here + ": got box, terminate: " + terminate);
                }
            }
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
