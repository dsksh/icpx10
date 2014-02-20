import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicLong;
import x10.util.concurrent.AtomicDouble;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent[K] {

    val solver:BAPSolver[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[BAPSolver.Result,IntervalVec[K]]];

    val reqQueue:CircularQueue[Int];
    var terminate:Int = 0;
    var nSentRequests:AtomicInteger = new AtomicInteger(0);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var initPhase:Boolean = true;
	var totalVolume:AtomicDouble = new AtomicDouble(0.);

    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var isActive:AtomicBoolean = new AtomicBoolean(false);
    var nSearchPs:AtomicInteger = new AtomicInteger(0);

    public var tEndPP:Long = 0l;
    //public var nSols:AtomicInteger = new AtomicInteger(0);
    public var nSols:Int = 0;
    //public var nContracts:AtomicInteger = new AtomicInteger(0);
    //public var tContracts:AtomicLong = new AtomicLong(0);
    public var nContracts:Int = 0;
    public var tContracts:Long = 0l;
    public var tSearch:Long = 0l;
    //public var nSplits:AtomicInteger = new AtomicInteger(0);
    public var nSplits:Int = 0;
    //public var nReqs:AtomicInteger = new AtomicInteger(0); // TODO
    public var nReqs:Int = 0;
    //public var nSends:AtomicInteger = new AtomicInteger(0);
    public var nSends:Int = 0;
    //public var nBranches:AtomicInteger = new AtomicInteger(0);

    private random:Random;

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

    public def this(solver:BAPSolver[K]) {
        this.solver = solver;

/*        val debug = System.getenv("RPX10_DEBUG");
        if (debug != null)
            this.doDebugPrint = Boolean.parse(debug);
        else
            this.doDebugPrint = false;
*/
		var debug:Boolean = false;
		val gDebug= new GlobalRef(new Cell(debug));
		at (Place(0)) {
    		val sDebug = System.getenv("RPX10_DEBUG");
			if (sDebug != null) {
				val debug1 = Boolean.parse(sDebug);
				at (gDebug.home) gDebug().set(debug1);
			}
		}
    	this.doDebugPrint = gDebug().value;

        list = new ArrayList[IntervalVec[K]]();
//        list1 = new ArrayList[Pair[Result,IntervalVec[K]]]();
        solutions = new ArrayList[Pair[BAPSolver.Result,IntervalVec[K]]]();

        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);

        random = new Random(System.nanoTime());

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
//Console.OUT.println(here + ": initD: " + solver.core.getInitialDomain());
        list.add(solver.core.getInitialDomain());

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            at (Place(pi)) {
                sHandle().sentRequest.set(true);
                sHandle().nSentRequests.incrementAndGet();
			}
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }
    }

    public val doDebugPrint:Boolean;
    public def debugPrint(msg:String) {
        if (doDebugPrint)
            Console.OUT.println(msg);
    }

    private var selected:Iterator[Place] = null;

    protected def selectPlace() : Place {
/*        var id:Int;
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
            val pv:Box[K] = box.prevVar();
atomic sHandle().debugPrint(here + ": sending box:\n" + box + '\n');
//async 
            at (Place(id)) {
                sHandle().sentRequest.set(false);
                box.setPrevVar(pv);
                atomic sHandle().list.add(box);
            }
//Console.OUT.println(here + ": responded to " + id);
            if (id < here.id()) sentBw.set(true);
            //nSends.getAndIncrement();
            nSends++;
            return true;
        }
        else
            return false;
    }

/*    public atomic def getMultipleRequests(nMax:Int) : List[Int] {
        val n = Math.min(nMax, reqQueue.getSize());
        val list = new ArrayList[Int](n);
        for (i in 1..n) {
            val id = reqQueue.removeFirstUnsafe();
            list.add(id);
        }
        return list;
    }
*/

    public def addSolution(res:BAPSolver.Result, box:IntervalVec[K]) {
        // FIXME
        atomic solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
//Console.OUT.println(here + ": solution:");
//val plot = res.entails(BAPSolver.Result.inner()) ? 5 : 3;
//val stringB = box.toString(plot);
//async
//at (Place(0)) 
//atomic {
//    Console.OUT.println(stringB);
//    Console.OUT.println(); 
//    Console.OUT.flush();
//}
        //nSols.getAndIncrement();
        nSols++;
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
//   		Console.OUT.println(here + ": start solving... ");

        if (list.isEmpty() && !sentRequest.get())
            list.add(solver.core.dummyBox());

        while (true) {

            var box:IntervalVec[K] = null;

var time:Long;

debugPrint(here + ": wait...");
            when (!list.isEmpty()) {
time = -System.nanoTime();
                isActive.set(true);
initPhase = false;
                box = list.removeFirst();
debugPrint(here + ": got box:\n" + box);
            }

            finish solver.search(sHandle, box);
debugPrint(here + ": search done");

time += System.nanoTime();
sHandle().tSearch += time;

            if (list.isEmpty()) {
                isActive.set(false);

                // cancel the received requests.
                while (!initPhase && reqQueue.getSize() > 0) {
                    val id:Int = reqQueue.removeFirstUnsafe();
//async
                    at (here.next()) {
                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
                }

                var term:Int;
atomic {
                //val term = getAndResetTerminate();
                term = terminate;
//Console.OUT.println(here + ": term: " + term);

                if (sentRequest.get() && term != 3)
                    continue;
                else
                    terminate = 0;
}

                // begin termination detection
                if (here.id() == 0 && (term == 0 || term == 2)) {
//async
                    at (here.next()) atomic {
                        sHandle().terminate = 1;
//                        sHandle().sentBw.set(false);
                        // put a dummy box
                        sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token 1 to " + here.next());
                }
                // termination token went round.
                else if (here.id() == 0 && term == 1) {
                    //val term = getAndResetTerminate();
//                    if (term == 1) {
//async
                        at (here.next()) atomic {
                            sHandle().terminate = 3;
                            sHandle().list.add(sHandle().solver.core.dummyBox());
                        }
//Console.OUT.println(here + ": sent token 3 to " + here.next());
                        break;
//                    }
                    //else if (term == 2) continue;
                }
                else if (here.id() > 0 && term > 0) {
                    val v = (term == 1 && sentBw.getAndSet(false)) ? 2 : term;
//Console.OUT.println(here + ": sending token " + v + " to " + here.next());
                    //atomic terminate = 0;
//async
                    at (here.next()) atomic {
                        sHandle().terminate = v;
//                        sHandle().sentBw.set(false);
                        sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token " + v + " to " + here.next());
                    if (term == 3) {
                        break;
                    }
                }

                // request for a domain
                if (Place.numPlaces() > 1 && !sentRequest.getAndSet(true)
                    ) {
                    val id = here.id();
                    val p = selectPlace();
//async
                    at (p) {
                        sHandle().reqQueue.addLast(id);
                        sHandle().list.add(sHandle().solver.core.dummyBox());
//Console.OUT.println(here + ": requested from " + id);
                    }
//Console.OUT.println(here + ": requested to " + p);
                    //nReqs.getAndIncrement();
                    nReqs++;
                }

//}
//}

            }
        }

//Console.OUT.println(here + ": boxAvail: " + !list.isEmpty());
//   		Console.OUT.println(here + ": done");
//   		Console.OUT.flush();
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
