import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterDFSSolver[K] extends Solver[K] {
    val maxNSplits:Int = 1;

    //private var nProcs:AtomicInteger = new AtomicInteger(0);
    //private var finished:AtomicBoolean = new AtomicBoolean(false);
    //private var finished:Boolean = false;
    private random:Random;
    private var initPhase:Boolean;

    static val SendWhenContracted = false;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        //reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random(System.nanoTime());
        initPhase = here.id() != 0;
    }

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

/*        var pos:Int = 0;
        for (i in 1..(Place.numPlaces()-1)) {
            at (Place(pos)) sHandle().reqQueue.addLast(i);
            at (Place(i)) sHandle().sentRequest.set(true);
            if (pos+1 < i) pos++; else pos = 0;
        }
*/

        var dst:Int = 0;
        var i:Int = 0;
        for (p in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(p);
            at (Place(p)) sHandle().sentRequest.set(true);
            if (++i >= Math.pow2(maxNSplits)-1) {
                if (dst+1 < p) dst++; else dst = 0;
            }
        }
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) {
            val pv:Box[K] = box.prevVar();
            val v = selectVariable(res, box);
            if (v != null) {

if (SendWhenContracted) {
                var id:Int = -1;
                atomic if (reqQueue.getSize() > 0) {
                    id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from " + id);
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
                }
}

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
} else {
                async 
                search(sHandle, bp.first);
}
                //async 
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

    protected def search1(sHandle:PlaceLocalHandle[Solver[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search1:\n" + box + '\n');

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
                            search1(sHandle, b);
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

    var selected:Iterator[Place] = null;
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
                //finish async search(sHandle, box);
                finish search1(sHandle, box);
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
                    async at (here.next()) atomic {
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
                        async at (here.next()) atomic {
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
                    async at (here.next()) atomic {
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
                    val p = selectPlace();
                    async at (p) {
                        sHandle().reqQueue.addLast(id);
                        atomic sHandle().list.add(sHandle().core.dummyBox());
//Console.OUT.println(here + ": requested from " + id);
                    }
//Console.OUT.println(here + ": requested to " + p);
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
