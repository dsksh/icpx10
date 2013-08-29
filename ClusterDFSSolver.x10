import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

// FIXME: initPhase should be turned off.

public class ClusterDFSSolver[K] extends Solver[K] {
    private random:Random;
    //private var initPhase:Boolean;
    private var selected:Iterator[Place] = null;

    static val SendWhenContracted = false;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        random = new Random(System.nanoTime());
        initPhase = here.id() != 0;
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        super.setup(sHandle);

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            at (Place(pi)) sHandle().sentRequest.set(true);
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }
    }

    protected def selectPlace() : Place {
        var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);

/*        if (selected == null || !selected.hasNext())
            selected = Place.places().iterator();
        val p = selected.next();
        if (p != here) {
//Console.OUT.println(here + ": selected " + p);
            return p;
        }
        else
            return selectPlace();
*/
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        // for dummy boxes
        if (box.size() == 0)
            return;

        var res:Result = Result.unknown();
        atomic { 
//tContract -= System.nanoTime();
            res = core.contract(box); 
//tContract += System.nanoTime();
        }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val pv:Box[K] = box.prevVar();

if (SendWhenContracted) {
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from " + id);
                }
                if (id >= 0) {
                    val p = Place(id);
                    async at (p) {
                        sHandle().sentRequest.set(false);
                        box.setPrevVar(pv);
                        atomic sHandle().list.add(box);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                    return;
                }
}

//if (reqQueue.getSize() == 0)
//    initPhase = false;

                val bp = box.split(v()); 
                nSplits.getAndIncrement();
//Console.OUT.println(here + ": split");
                
if (!SendWhenContracted) {
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from: " + id);
                }
                if (id >= 0) {
                    val p = Place(id);
                    async at (p) {
                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(bp.first);
                    }
//Console.OUT.println(here + ": responded to " + id);
                    if (id < here.id()) sentBw.set(true);
                    nSends.getAndIncrement();
                }
                else {
                    async 
                    search(sHandle, bp.first);
                }
} else {
                async 
                search(sHandle, bp.first);
}
                async 
                search(sHandle, bp.second);
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
        //else Console.OUT.println(here + ": no solution");
    }    

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            if (!list.isEmpty()) {
                val box = list.removeFirst();
                finish async search(sHandle, box);
            }

            else { //if (list.isEmpty()) {

                // cancel the received requests.
                while (!initPhase && reqQueue.getSize() > 0) {
//Console.OUT.println(here + ": canceling...");
                    val id:Int = reqQueue.removeFirstUnsafe();
                    async at (Place(id)) {
                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(sHandle().core.dummyBox());
                    }
                }

                val t = getAndResetTerminate();

                // begin termination detection
                if (here.id() == 0 && (t == 0 || t == 2)) {
                    at (here.next()) atomic {
                        sHandle().terminate = 1;
                        sHandle().sentBw.set(false);
                        // put a dummy box
                        atomic sHandle().list.add(sHandle().core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token 1 to " + here.next());
                }
                // termination token went round.
                else if (here.id() == 0 && t == 1) {
                    //val t = getAndResetTerminate();
                    if (t == 1) {
                        at (here.next()) atomic {
                            sHandle().terminate = 3;
                            atomic sHandle().list.add(sHandle().core.dummyBox());
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
                        atomic sHandle().list.add(sHandle().core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token " + v + " to " + here.next());
                    if (t == 3) {
                        break;
                    }
                }

                // request for a domain
                if (Place.numPlaces() > 1 && !sentRequest.getAndSet(true)) {
                    val id = here.id();
                    val p = selectPlace();
                    at (p) {
                        sHandle().reqQueue.addLast(id);
                        atomic sHandle().list.add(sHandle().core.dummyBox());
//Console.OUT.println(here + ": requested from " + id);
                    }
//Console.OUT.println(here + ": requested to " + p);
                    nReqs.getAndIncrement();
                }

//Console.OUT.println(here + ": wait...");

                when (!list.isEmpty()) {
initPhase = false;
                    //sentRequest.set(false);
//Console.OUT.println(here + ": got box, terminate: " + terminate);
                }
            }
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
