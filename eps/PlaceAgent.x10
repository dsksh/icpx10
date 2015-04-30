import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.*;
import x10.io.*;
import x10.io.Console;

public class PlaceAgent[K] {

    //val sizeNbors:Long = 5; // FIXME
    val solver:BAPSolverImpl[K];
    val list:List[IntervalVec[K]];
    //val list:CircularQueue[IntervalVec[K]];
    val solutions:List[Pair[BAPSolver.Result,IntervalVec[K]]];

    //val reqQueue:CircularQueue[Long];
    //var terminate:Int = TokActive;
    var nSentRequests:AtomicInteger = new AtomicInteger(0n);
    var sentBw:AtomicBoolean = new AtomicBoolean(false);
    var active:Boolean = false;
	var totalVolume:AtomicDouble = new AtomicDouble(0.);

    var sentRequest:AtomicBoolean = new AtomicBoolean(false);
    var isActive:AtomicBoolean = new AtomicBoolean(false);
    var nSearchPs:AtomicInteger = new AtomicInteger(0n);

    public var tEndPP:Long = 0l;
    public var nSols:Long = 0;
    public var nContracts:Long = 0;
    public var tContracts:Long = 0l;
    public var tSearch:Long = 0l;
    public var nSplits:Long = 0;
    public var nReqs:Long = 0;
    public var nSends:AtomicLong = new AtomicLong(0n);
    public var nSentBoxes:AtomicLong = new AtomicLong(0n);
    public var tWaitComm:Long = 0l;
    public var nIters:Long = 0;
    public var tBoxSend:AtomicLong = new AtomicLong(0l);

    protected random:Random;

    // kludge for a success of compilation
    val dummy:Double;
    val dummyI:Interval;

	val nSearchSteps0:Long;
	val nSearchSteps:AtomicDouble;

    var listShared:List[IntervalVec[K]] = null;

    var preprocessor:Preprocessor[K] = null;

    val deltaBox:Long;
    val deltaRelBox1:Double;
    val deltaRelBox2:Double;
    val deltaLoad:Long;
    val deltaRelLoad:Double;
    val accelThres:Long;
    //var nSendsBox:Double;
    var nSendsLoad:Long;
    //val minNSendsBox:Double;

    val tSearchInterval:Double;

    val neighbors:List[Long];

	// list of the neighbors' loads.
    val loads:List[Box[Long]];
    var weight:Double;

	private val lockLoads:Lock = new Lock();
    protected def lockLoads() {
        if (!lockLoads.tryLock()) {
            Runtime.increaseParallelism();
            lockLoads.lock();
            Runtime.decreaseParallelism(1n);
        }
        //lockLoads.lock();
    }
    protected def unlockLoads() {
        lockLoads.unlock();
    }

	def getLoad(i:Long) : Box[Long] {
		lockLoads();
		try {
			return loads(i);
		}
		finally {
			unlockLoads();
		}
	}
	def getAndResetLoad(i:Long) : Box[Long] {
		lockLoads();
		try {
			val l = loads(i);
            loads(i) = null;
            return l;
		}
		finally {
			unlockLoads();
		}
	}
	def setLoad(i:Long, l:Long) {
		lockLoads();
		loads(i) = new Box[Long](l);
		unlockLoads();
	}


	// list of the inverse neighbor links.
    val neighborsInv:List[Long];

	private val lockNborsInv:Lock = new Lock();
    protected def lockNborsInv() {
        if (!lockNborsInv.tryLock()) {
            Runtime.increaseParallelism();
            lockNborsInv.lock();
            Runtime.decreaseParallelism(1n);
        }
    }
    protected def unlockNborsInv() {
        lockNborsInv.unlock();
    }


    public def this(solver:BAPSolverImpl[K]) {

        this.solver = solver;

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

        //reqQueue = new CircularQueue[Long](2*Place.numPlaces()+10);

        random = new Random(System.nanoTime());

        dummy = 0;
        dummyI = new Interval(0.,0.);
		val gNSS = new GlobalRef(new Cell[Long](0));
        val p0 = Place(0);
		at (p0) {
   			val sNSS = System.getenv("RPX10_N_SEARCH_STEPS");
			val nSS:Long = sNSS != null ? Long.parse(sNSS) : 1;
			at (gNSS.home) 
				gNSS().set(nSS);
		}
    	this.nSearchSteps0 = gNSS().value;
    	this.nSearchSteps = new AtomicDouble(nSearchSteps0);

        listShared = new LinkedList[IntervalVec[K]]();

        // read env variables.
		val gDB = new GlobalRef(new Cell[Long](0));
		val gDRB1 = new GlobalRef(new Cell[Double](0.));
		val gDRB2 = new GlobalRef(new Cell[Double](0.));
		val gDL = new GlobalRef(new Cell[Long](0));
		val gDRL = new GlobalRef(new Cell[Double](0.));
		val gAT = new GlobalRef(new Cell[Long](0));
		val gNSB = new GlobalRef(new Cell[Double](0.));
		val gNSL = new GlobalRef(new Cell[Long](0));
		val gSI = new GlobalRef(new Cell[Double](0.));
        //val p0 = Place(0);
		at (p0) {
   			val sDB = System.getenv("RPX10_DELTA_BOX");
   			val sDRB1 = System.getenv("RPX10_DELTA_REL_BOX1");
   			val sDRB2 = System.getenv("RPX10_DELTA_REL_BOX2");
   			val sDL = System.getenv("RPX10_DELTA_LOAD");
   			val sDRL = System.getenv("RPX10_DELTA_REL_LOAD");
   			val sAT = System.getenv("RPX10_ACCEL_THRES");
   			val sNSB = System.getenv("RPX10_N_SENDS_BOX");
   			val sNSL = System.getenv("RPX10_N_SENDS_LOAD");
   			val sSI = System.getenv("RPX10_SEARCH_INTERVAL");
			val nDB:Long = sDB != null ? Long.parse(sDB) : 10;
			val nDRB1:Double = sDRB1 != null ? Double.parse(sDRB1) : 0.;
			val nDRB2:Double = sDRB2 != null ? Double.parse(sDRB2) : 0.;
			val nDL:Long = sDL != null ? Long.parse(sDL) : 0;
			val nDRL:Double = sDRL != null ? Double.parse(sDRL) : 0.;
			val nAT:Long = sAT != null ? Long.parse(sAT) : -1;
			val nNSB:Double = sNSB != null ? Double.parse(sNSB) : 2.;
			val nNSL:Long = sNSL != null ? Long.parse(sNSL) : 2;
			val nSI:Double  = sSI != null ? Double.parse(sSI) : 1.;
			at (gDB.home) {
				gDB().set(nDB);
				gDRB1().set(nDRB1);
				gDRB2().set(nDRB2);
				gDL().set(nDL);
				gAT().set(nAT);
				gDRL().set(nDRL);
				gNSB().set(nNSB);
				gNSL().set(nNSL);
				gSI().set(nSI);
            }
		}
    	deltaBox = gDB().value;
    	deltaRelBox1 = gDRB1().value;
    	deltaRelBox2 = gDRB2().value;
    	deltaLoad = gDL().value;
    	deltaRelLoad = gDRL().value;
    	accelThres = gAT().value;
    	//nSendsBox = gNSB().value;
    	//minNSendsBox = gNSB().value;
    	nSendsLoad = gNSL().value;
    	tSearchInterval = gSI().value;

        neighbors = new ArrayList[Long](nSendsLoad);

        /*var pow:Int = 1;
        for (1..nSendsLoad) {
            val pid = (here.id() + pow) % Place.numPlaces();
            pow *= 2;
            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }*/

        val num = 1./(nSendsLoad as Double);
        var pidBak:Long = -1;
        for (i in 0..(nSendsLoad-1)) {
            var pid:Long = here.id() + (Math.floor(Math.pow((Place.numPlaces() as Double), i*num)) as Long);
            if (pid <= pidBak) pid = pidBak+1;
            pidBak = pid;
            pid = pid % Place.numPlaces();

            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }

        loads = new ArrayList[Box[Long]](nSendsLoad);
        for (neighbors.indices()) 
            //loads.add(Int.MAX_VALUE/(neighbors.size()+1));
            //loads.add(new Box(-1));
            loads.add(null);

        neighborsInv = new ArrayList[Long](nSendsLoad);
    }

    public def setPreprocessor(pp:Preprocessor[K]) {
        this.preprocessor = pp;
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
  		val box = solver.core.getInitialDomain();
//totalVolume.addAndGet(box.volume());
        list.add(box);
        preprocessor.setup(sHandle);

        active = true;

        //@Pragma(Pragma.FINISH_SPMD) 
        finish for (p in Place.places())
        // at (p) async { <-- this results in an error
        at (p) async {
            when ((sHandle() as PlaceAgent[K]).neighbors != null) {}

            val id = here.id();
            //@Pragma(Pragma.FINISH_SPMD) finish
            for (pid in (sHandle() as PlaceAgent[K]).neighbors) {
sHandle().debugPrint(here + ": neighbor: " + pid);
                val p1 = Place(pid);
                at (p1) //async
                atomic {
					//lockNborsInv();
                    (sHandle() as PlaceAgent[K]).neighborsInv.add(id);
					//unlockNborsInv();
				}
            }
        }
    }

    public val doDebugPrint:Boolean;
    public def debugPrint(msg:String) {
        if (doDebugPrint) {
            Console.OUT.println(msg);
			Console.OUT.flush();
		}
    }

    public def addSolution(res:BAPSolver.Result, box:IntervalVec[K]) {
        // FIXME
        //atomic 
		solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
        nSols++;
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


    private val lockSList = new Lock();

    protected def lockSList() {
/*        if (!lockSList.tryLock()) {
            Runtime.increaseParallelism();
            lockSList.lock();
            Runtime.decreaseParallelism(1);
        }
*/
    }
    protected def unlockSList() {
//        lockSList.unlock();
    }

    public def addDomShared(box:IntervalVec[K]) : Boolean {
atomic {
        try {
            lockSList();
			return listShared.add(box);
        }
        finally {
            unlockSList();
        }
}
    }

    public def joinTwoLists() {
        lockSList();
atomic {
        // append the two lists.
        for (box in listShared)
            list.add(box);

        // reset
        listShared.clear();
}
        unlockSList();
    }

    public def joinWithListShared(boxList:List[IntervalVec[K]]) {
        lockSList();

atomic {
        for (box in listShared) boxList.add(box);
        listShared = null;
        listShared = boxList;
}

        unlockSList();
    }


    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        // preprocess
        finish while (preprocessor.process(sHandle)) {}

        //finish
        while (//getTerminate() != TokDead || 
               (list.size()+listShared.size()) > 0) {
//finish {
            //if (!preprocessor.process(sHandle)) {

			    //balance(sHandle);

//                if (here.id() == 0 &&
//                    (list.size()+listShared.size()) == 0 //&& getTerminate() == TokActive 
//                ) {
//                    // force search to activate termination
//                    //addDomShared(sHandle().solver.core.dummyBox());
//				    atomic active = true;
//                }
    
   			    search(sHandle);
            //}

//            if (here.id() == 0) {
//                lockTerminate();
//                if ((list.size()+listShared.size()) == 0 && terminate == TokActive) {
//debugPrint(here + ": start termination");
//                    terminate = TokInvoke;
//    		    }
//                unlockTerminate();
//            }
//tWaitComm -= System.nanoTime();
//}
//tWaitComm += System.nanoTime();
			
			//terminate(sHandle);

            ++nIters;
        }
debugPrint(here + ": solving done");
	}

    var loadBak:Long = -1;

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

if (tEndPP < 0l) tEndPP += System.nanoTime();

debugPrint(here + ": wait");
        when (active || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + active + ", " + list.size()+","+listShared.size());
            active = false;
        }

        joinTwoLists();

    	finish 
    	for (1..(nSearchSteps.get() as Int)) {
    		if (!searchBody(sHandle))
    			break;
        }
debugPrint(here + ": done search");
    }

	def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
        var box:IntervalVec[K] = null;

        if (!list.isEmpty()) {

var time:Long = -System.nanoTime();

            box = list.removeFirst();

//debugPrint(here + ": got box:\n" + box);

//debugPrint(here + ": load in search: " + (list.size() + nSearchPs.get()));
//debugPrint(here + ": load in search: " + totalVolume.get());

            //finish
            solver.search(sHandle, box);

//debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

time += System.nanoTime();
sHandle().tSearch += time;

			return true;
		}
		else return false;
	}
}

// vim: shiftwidth=4:tabstop=4:expandtab
