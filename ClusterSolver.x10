import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterSolver[K] extends Solver[K] {
    private random:Random;

    static val frontierN = 4;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        //reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random(System.nanoTime());
        initPhase = here.id() == 0;
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        addDom(Result.unknown(), core.getInitialDomain());

        var pos:Int = 0;
        var pow2:Int = 1;
        for (i in 1..(Place.numPlaces()-1)) {
            at (Place(pos)) sHandle().reqQueue.addLast(i);
            //at (Place(i)) sHandle().sentRequest.set(true);
            if (pos+1 < pow2) pos++; 
            else { pos = 0; pow2 *= 2; }
        }

/*        while (list1.size() < frontierN) {
            if (list1.isEmpty()) break;
            val pair = removeFirstDom();
            finish search(sHandle, pair.first, pair.second);
        }

        val nB = list1.size();
        var p:Place = here;
        for (i in 1..nB) {
            val pair = removeFirstDom();
            at (p) sHandle().addDom(pair.first, pair.second);
            p = p.next();
        }
*/
    }

    protected def contractBox(box:IntervalVec[K]) {
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) addDom(res, box);
        //else Console.OUT.println(here + ": no solution");
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], res:Result, box:IntervalVec[K]) {
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

        while (true) 
        //if (!list1.isEmpty()) {
        if (initPhase) {
            while (reqQueue.getSize() > 0) {
                val pi = reqQueue.removeFirstUnsafe();

                while (list1.size() < frontierN) {
                    if (list1.isEmpty()) break;
                    val pair = removeFirstDom();
                    finish search(sHandle, pair.first, pair.second);
                }
        
                val nB = list1.size();
                var b:Boolean = true;
                for (i in 1..nB) {
                    val pair = removeFirstDom();
                    at (b ? here : Place(pi)) sHandle().addDom(pair.first, pair.second);
//Console.OUT.println(here + ": append at " + (b ? 0 : pi));
                    b = !b;
                }
                at (Place(pi)) atomic sHandle().initPhase = true;
            }
            break;
        }
        else when (initPhase) { }

        while (true) {
            finish while (!list1.isEmpty()) {
                val pair = removeFirstDom();
                async search(sHandle, pair.first, pair.second);
            }

            if (list1.isEmpty()) break;

/*            {
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
*/
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
