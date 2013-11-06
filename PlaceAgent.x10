import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent[K] {

    val solver:BAPSolver[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[BAPSolver.Result,IntervalVec[K]]];

    val reqQueue:CircularQueue[Int];
    var terminate:Int = 0;
//    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var initPhase:Boolean = true;

    public var nSols:AtomicInteger = new AtomicInteger(0);
    public var nContracts:AtomicInteger = new AtomicInteger(0);
    public var nSplits:AtomicInteger = new AtomicInteger(0);
    public var nReqs:AtomicInteger = new AtomicInteger(0);
    public var nSends:AtomicInteger = new AtomicInteger(0);
    public var nBranches:AtomicInteger = new AtomicInteger(0);
    public var tContract:Long = 0;

    private random:Random;

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;


    public def this(solver:BAPSolver[K]) {
        this.solver = solver;

        list = new ArrayList[IntervalVec[K]]();
//        list1 = new ArrayList[Pair[Result,IntervalVec[K]]]();
        solutions = new ArrayList[Pair[BAPSolver.Result,IntervalVec[K]]]();

        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);

        random = new Random(System.nanoTime());

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
Console.OUT.println(here + ": initD: " + solver.core.getInitialDomain());
        list.add(solver.core.getInitialDomain());
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

    public def getSolutions() : List[Pair[BAPSolver.Result,IntervalVec[K]]] { return solutions; }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        var id:Int = -1;
        atomic if (reqQueue.getSize() > 0) {
            id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from: " + id);
        }

        if (id >= 0) {
            val p = Place(id);
//async 
            at (p) {
//                sHandle().sentRequest.set(false);
                atomic sHandle().list.add(box);
            }
//Console.OUT.println(here + ": responded to " + id);
            if (id < here.id()) sentBw.set(true);
            nSends.getAndIncrement();
            return true;
        }
        else
            return false;
    }

    public atomic def addSolution(res:BAPSolver.Result, box:IntervalVec[K]) {
        solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
//        Console.OUT.println(here + ": solution:");
        val plot = res.entails(BAPSolver.Result.inner()) ? 5 : 3;
atomic {
        Console.OUT.println(box.toString(plot));
        Console.OUT.println(); 
        Console.OUT.flush();
}
        nSols.getAndIncrement();
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) {
            if (!list.isEmpty()) {
                val box = list.removeFirst();
                finish solver.search(sHandle, box);
            }
            else { //if (list.isEmpty()) {

                // cancel the received requests.
                while (!initPhase && reqQueue.getSize() > 0) {
                    val id:Int = reqQueue.removeFirstUnsafe();
//async
                    at (Place(id)) {
//                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
                }

                val t = getAndResetTerminate();
//Console.OUT.println(here + ": t: " + t);

                // begin termination detection
                if (here.id() == 0 && (t == 0 || t == 2)) {
//async
                    at (here.next()) atomic {
                        sHandle().terminate = 1;
                        sHandle().sentBw.set(false);
                        // put a dummy box
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token 1 to " + here.next());
                }
                // termination token went round.
                else if (here.id() == 0 && t == 1) {
                    //val t = getAndResetTerminate();
                    if (t == 1) {
//async
                        at (here.next()) atomic {
                            sHandle().terminate = 3;
                            atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                        }
//Console.OUT.println(here + ": sent token 3 to " + here.next());
                        break;
                    }
                    //else if (t == 2) continue;
                }
                else if (here.id() > 0 && t > 0) {
                    val v = (t == 1 && sentBw.get()) ? 2 : t;
//async
                    at (here.next()) atomic {
                        sHandle().terminate = v;
                        sHandle().sentBw.set(false);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token " + v + " to " + here.next());
                    if (t == 3) {
                        break;
                    }
                }

                // request for a domain
                if (Place.numPlaces() > 1 //&& !sentRequest.getAndSet(true)
                    ) {
                    val id = here.id();
                    val p = selectPlace();
//async
                    at (p) {
                        sHandle().reqQueue.addLast(id);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
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
