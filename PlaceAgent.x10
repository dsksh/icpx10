import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicLong;
import x10.util.concurrent.AtomicDouble;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent[K] {

    static val TokActive = 0;
    static val TokInvoke = 1;
    static val TokIdle   = 2;
    static val TokCancel = 4;
    static val TokDead   = 8;

    //var loc:AtomicInteger = new AtomicInteger(0);

    val solver:BAPSolver[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[BAPSolver.Result,IntervalVec[K]]];

    val reqQueue:CircularQueue[Int];
    var terminate:Int = TokActive;
    var nSentRequests:AtomicInteger = new AtomicInteger(0);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var active:Boolean = true;
	var totalVolume:AtomicDouble = new AtomicDouble(0.);

    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var isActive:AtomicBoolean = new AtomicBoolean(false);
    var nSearchPs:AtomicInteger = new AtomicInteger(0);

    public var tEndPP:Long = 0l;
    public var nSols:Int = 0;
    public var nContracts:Int = 0;
    public var tContracts:Long = 0l;
    public var tSearch:Long = 0l;
    public var nSplits:Int = 0;
    public var nReqs:Int = 0;
    public var nSends:Int = 0;
    public var tWaitComm:Long = 0l;
    public var nIters:Int = 0;

    protected random:Random;

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

        //list = new ArrayList[IntervalVec[K]]();
        list = new LinkedList[IntervalVec[K]]();
//        list1 = new ArrayList[Pair[Result,IntervalVec[K]]]();
        solutions = new ArrayList[Pair[BAPSolver.Result,IntervalVec[K]]]();

        reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);

        random = new Random(System.nanoTime());

        dummy = 0;
        dummyI = new Interval(0.,0.);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
//Console.OUT.println(here + ": initD: " + solver.core.getInitialDomain());
		val box = solver.core.getInitialDomain();
totalVolume.addAndGet(box.volume());
        list.add(box);

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
        if (doDebugPrint) {
            Console.OUT.println(msg);
			Console.OUT.flush();
		}
    }

    //private var selected:Iterator[Place] = null;
    private var selectedPid:Int = 0;

    protected def selectPlace() : Place {
/*        var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);
*/

        if (selectedPid == Place.numPlaces()) selectedPid = 0;
        val p = Place( selectedPid++ % Place.numPlaces() );
        if (p != here) {
debugPrint(here + ": selected " + p);
            return p;
        }
        else
            return selectPlace();
    }

    public def getSolutions() : List[Pair[BAPSolver.Result,IntervalVec[K]]] { return solutions; }

    protected def removeDom() : IntervalVec[K] {
        return list.removeFirst();
    }

    protected def sortDom() {
        list.sort(
            (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                b2.volume().compareTo(b1.volume()) );
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        var id:Int = -1;
        atomic if (reqQueue.getSize() > 0) {
            id = reqQueue.removeFirstUnsafe();
//Console.OUT.println(here + ": got req from: " + id);
        }

        if (id >= 0) {
            val pv:Box[K] = box.prevVar();
//sHandle().debugPrint(here + ": sending box:\n" + box + '\n');
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
        //atomic 
		solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
        nSols++;
    }

    private val terminateLock = new Lock();

    protected def tryLockTerminate() : Boolean {
        return terminateLock.tryLock();
    }
    protected def lockTerminate() {
        if (!terminateLock.tryLock()) {
            Runtime.increaseParallelism();
            terminateLock.lock();
            Runtime.decreaseParallelism(1);
        }
    }
    protected def unlockTerminate() {
        terminateLock.unlock();
    }

    protected def getAndResetTerminate() : Int {
        lockTerminate();
        val t = terminate;
		terminate = TokActive;
        unlockTerminate();
        return t;
    }

    protected def getTerminate() {
        try {
			lockTerminate();
			return terminate;
		}
		finally {
	        unlockTerminate();
		}
		//return terminate;
    }

    protected def setTerminate(tok:Int) {
        lockTerminate();
        terminate = tok;
        unlockTerminate();
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
active = false;
                box = list.removeFirst();
//debugPrint(here + ": got box:\n" + box);
            }

            finish solver.search(sHandle, box);
debugPrint(here + ": search done");

time += System.nanoTime();
sHandle().tSearch += time;

            if (list.isEmpty()) {
                isActive.set(false);

                // cancel the received requests.
                while (!active && reqQueue.getSize() > 0) {
                    val id:Int = reqQueue.removeFirstUnsafe();
//async
                    at (here.next()) {
                        sHandle().sentRequest.set(false);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
                }

                var term:Int;
try {
lockTerminate();
                //val term = getAndResetTerminate();
                term = terminate;
//Console.OUT.println(here + ": term: " + term);

                if (sentRequest.get() && term != TokDead)
                    continue;
                else
                    terminate = TokActive;
}
finally {
    unlockTerminate();
}

                // begin termination detection
                if (here.id() == 0 && (term == TokActive || term == TokCancel)) {
//async
                    at (here.next()) {
                        sHandle().setTerminate(TokIdle);
                        // put a dummy box
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token Idle to " + here.next());
                }
                // termination token went round.
                else if (here.id() == 0 && term == TokIdle) {
                    at (here.next()) {
                        sHandle().setTerminate(TokDead);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token Dead to " + here.next());
                    break;
                }
                else if (here.id() > 0 && term != TokActive) {
                    val v = (term == TokIdle && sentBw.getAndSet(false)) ? TokCancel : term;
                    at (here.next()) {
                        sHandle().setTerminate(v);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
//Console.OUT.println(here + ": sent token " + v + " to " + here.next());
                    if (term == TokDead) {
                        break;
                    }
                }

                // request for a domain
                if (Place.numPlaces() > 1 && !sentRequest.getAndSet(true)) {
                    val id = here.id();
                    val p = selectPlace();
//async
                    at (p) {
                        sHandle().reqQueue.addLast(id);
                        atomic sHandle().list.add(sHandle().solver.core.dummyBox());
//Console.OUT.println(here + ": requested from " + id);
                    }
//Console.OUT.println(here + ": requested to " + p);
                    //nReqs.getAndIncrement();
                    nReqs++;
                }
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
