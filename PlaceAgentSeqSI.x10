import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    //val sizeNbors:Int = 5; // FIXME
    val deltaBox:Int;
    val deltaRelBox1:Double;
    val deltaRelBox2:Double;
    val deltaLoad:Int;
    val deltaRelLoad:Double;
    val accelThres:Int;
    //var nSendsBox:Double;
    var nSendsLoad:Int;
    //val minNSendsBox:Double;

    val tSearchInterval:Double;

    val neighbors:List[Int];

	// list of the neighbors' loads.
    val loads:List[Box[Int]];
    var weight:Double;

	private val lockLoads:Lock = new Lock();
    protected def lockLoads() {
        if (!lockLoads.tryLock()) {
            Runtime.increaseParallelism();
            lockLoads.lock();
            Runtime.decreaseParallelism(1);
        }
        //lockLoads.lock();
    }
    protected def unlockLoads() {
        lockLoads.unlock();
    }

	def getLoad(i:Int) : Box[Int] {
		lockLoads();
		try {
			return loads(i);
		}
		finally {
			unlockLoads();
		}
	}
	def getAndResetLoad(i:Int) : Box[Int] {
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
	def setLoad(i:Int, l:Int) {
		lockLoads();
		loads(i) = new Box[Int](l);
		unlockLoads();
	}


	// list of the inverse neighbor links.
    val neighborsInv:List[Int];

	private val lockNborsInv:Lock = new Lock();
    protected def lockNborsInv() {
        if (!lockNborsInv.tryLock()) {
            Runtime.increaseParallelism();
            lockNborsInv.lock();
            Runtime.decreaseParallelism(1);
        }
    }
    protected def unlockNborsInv() {
        lockNborsInv.unlock();
    }


    public def this(solver:BAPSolver[K]) {
        super(solver);

        // read env variables.
		val gDB = new GlobalRef(new Cell[Int](0));
		val gDRB1 = new GlobalRef(new Cell[Double](0.));
		val gDRB2 = new GlobalRef(new Cell[Double](0.));
		val gDL = new GlobalRef(new Cell[Int](0));
		val gDRL = new GlobalRef(new Cell[Double](0.));
		val gAT = new GlobalRef(new Cell[Int](0));
		val gNSB = new GlobalRef(new Cell[Double](0.));
		val gNSL = new GlobalRef(new Cell[Int](0));
		val gSI = new GlobalRef(new Cell[Double](0.));
        val p0 = Place(0);
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
			val nDB:Int = sDB != null ? Int.parse(sDB) : 10;
			val nDRB1:Double = sDRB1 != null ? Double.parse(sDRB1) : 0.;
			val nDRB2:Double = sDRB2 != null ? Double.parse(sDRB2) : 0.;
			val nDL:Int = sDL != null ? Int.parse(sDL) : 0;
			val nDRL:Double = sDRL != null ? Double.parse(sDRL) : 0.;
			val nAT:Int = sAT != null ? Int.parse(sAT) : -1;
			val nNSB:Double = sNSB != null ? Double.parse(sNSB) : 2.;
			val nNSL:Int    = sNSL != null ? Int.parse(sNSL) : 2;
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

        neighbors = new ArrayList[Int](nSendsLoad);

        /*var pow:Int = 1;
        for (1..nSendsLoad) {
            val pid = (here.id() + pow) % Place.numPlaces();
            pow *= 2;
            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }*/

        val num = 1./(nSendsLoad as Double);
        var pidBak:Int = -1;
        for (i in 0..(nSendsLoad-1)) {
            var pid:Int = here.id() + (Math.floor(Math.pow((Place.numPlaces() as Double), i*num)) as Int);
            if (pid <= pidBak) pid = pidBak+1;
            pidBak = pid;
            pid = pid % Place.numPlaces();

            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }

        loads = new ArrayList[Box[Int]](nSendsLoad);
        for (neighbors.indices()) 
            //loads.add(Int.MAX_VALUE/(neighbors.size()+1));
            //loads.add(new Box(-1));
            loads.add(null);

        neighborsInv = new ArrayList[Int](nSendsLoad);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);

        //@Pragma(Pragma.FINISH_SPMD) 
        finish for (p in Place.places())
        // at (p) async { <-- this results in an error
        at (p) async {
            when ((sHandle() as PlaceAgentSeqSI[K]).neighbors != null) {}

            val id = here.id();
            //@Pragma(Pragma.FINISH_SPMD) finish
            for (pid in (sHandle() as PlaceAgentSeqSI[K]).neighbors) {
sHandle().debugPrint(here + ": neighbor: " + pid);
                val p1 = Place(pid);
                at (p1) //async
                atomic {
					//lockNborsInv();
                    (sHandle() as PlaceAgentSeqSI[K]).neighborsInv.add(id);
					//unlockNborsInv();
				}
            }
        }
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        //finish
        while (getTerminate() != TokDead || (list.size()+listShared.size()) > 0) {
finish {
            if (preprocessor == null || !preprocessor.process(sHandle)) {

			    balance(sHandle);

                if (here.id() == 0 &&
                    (list.size()+listShared.size()) == 0 && getTerminate() == TokActive ) {
                        // force search to activate termination
                        //addDomShared(sHandle().solver.core.dummyBox());
						atomic active = true;
                }
    
   			    search(sHandle);
            }

            if (here.id() == 0) {
                lockTerminate();
                if ((list.size()+listShared.size()) == 0 && terminate == TokActive) {
debugPrint(here + ": start termination");
                    terminate = TokInvoke;
    		    }
                unlockTerminate();
            }
tWaitComm -= System.nanoTime();
}
tWaitComm += System.nanoTime();
			
			terminate(sHandle);

            ++nIters;
        }
	}

    var loadBak:Int = -1;

    def balance(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": balance");

		if (Place.numPlaces() == 1) return;

        /*// not the initial path and not possessing many boxes.
		if (!initPhase && list.size() <= deltaBox) {
//sHandle().debugPrint(here + ": quit balance: " + terminate);
            return;
        }*/

        val load = list.size();

        //if (loadBak < 0 || Math.abs(load - loadBak) > deltaLoad) {
            loadBak = load;
    
            // send load to neighborsInv.
sHandle().debugPrint(here + ": my load: " + load);
            val hereId = here.id();
            //async {
			//lockNborsInv();

            // TODO: For some reason this often results in an error.
            //for (pid in neighborsInv.get()) {
            //for (pid in neighborsInv) {
            var iMax:Int = -1;
			iMax = neighborsInv.size() - 1;
            for (i in 0..iMax) {
            // TODO: (inefficient) workaround
            //for (p in Place.places()) {
                //if (p == here) continue;
                //val p = Place(pid);
				var pid:Int = -1;
				pid = neighborsInv(i);
				if (pid < 0) continue;
                val p = Place(pid);

                at (p) async 
                {
sHandle().lockTerminate();
if (sHandle().getTerminate() != TokDead) {
                    val id = (sHandle() as PlaceAgentSeqSI[K]).neighbors.indexOf(hereId);
                    if (id >= 0) {
sHandle().debugPrint(here + ": setting load " + load + " from " + hereId + " at " + id);
                        (sHandle() as PlaceAgentSeqSI[K]).setLoad(id, load);
                    }
}
else
    sHandle().debugPrint(here + ": cannot send load");
sHandle().unlockTerminate();
       		    }
sHandle().debugPrint(here + ": inform to: " + p.id());
            }

            //}

            nReqs += neighborsInv.size();

			//unlockNborsInv();
        //}

        // compute the average load.
        var loadAvg:Int = load;
        var c:Int = 1;
        for (i in neighbors.indices()) {
            val l = getLoad(i);
sHandle().debugPrint(here + ": load: " + l);
            if (l != null) {
                loadAvg += l();
                ++c;
            }
        }
        loadAvg /= c;

sHandle().debugPrint(here + ": load: " + load + " vs. " + loadAvg);

        val delta = list.size() - loadAvg;

		// send boxes.
        if (delta >= deltaBox)
            distributeSearchSpace(sHandle, load);

sHandle().debugPrint(here + ": balance done");
    }

    class RecipientInfo {
        public val boxes:List[IntervalVec[K]] = new LinkedList[IntervalVec[K]]();
        public val id:Int;
        public var amount:Int;

        public def this(id:Int, amount:Int) {
            this.id = id; this.amount = amount;
        }
    }

    def distributeSearchSpace(sHandle:PlaceLocalHandle[PlaceAgent[K]], load:Int) {
        // list of lists of boxes
        //val boxesList = new ArrayList[Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]]](neighbors.size()+1);
        val boxesList = new ArrayList[RecipientInfo](neighbors.size()+1);

        // list of boxes to be kept local.
        //val bs0 = new LinkedList[IntervalVec[K]]();
        //val p0 = new Pair[Int,Cell[Int]](here.id(),new Cell[Int](-1));
        //val pp0 = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs0, p0);
        //boxesList.add(pp0);

        boxesList.add(new RecipientInfo(here.id(), -1));

        for (i in neighbors.indices()) {
            val l = getAndResetLoad(i);
            if (l == null) continue;

            //val amount = load - l();
            val amount = (load - l()) / nSendsLoad;
sHandle().debugPrint(here + ": amount: " + amount);
            if (amount <= 0) continue;

            // create a list of boxes.
            //val bs = new LinkedList[IntervalVec[K]]();
            //val p = new Pair[Int,Cell[Int]](neighbors(i), new Cell[Int](amount));
            //val pp = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs, p);
            val info = new RecipientInfo(neighbors(i), amount);
            boxesList.add(info);
        }

        // distribute the content of the list
        var i:Int = 0;
        while (!list.isEmpty()) {
            val j = i % boxesList.size();
            //val pair = boxesList(j);
            val info = boxesList(j);
            //val cnt = pair.second.second();
            if ((j == 0 && info.amount < 0) || info.amount > 0) {
                val box:IntervalVec[K] = list.removeLast();
                if (box.size() > 0) { // not dummy
                    //pair.first.add(box); pair.second.second() = cnt-1;
                    info.boxes.add(box);
                    info.amount--;
                    box.count();
                    ++i;
                }
                else
                    addDomShared(box);
            }
            else ++i;
        }

        //for (pair in boxesList) {
        for (info in boxesList) {
            //val boxes = pair.first;
            val boxes = info.boxes;

            if (boxes.isEmpty()) continue;

            async 
			{
tBoxSend.addAndGet(-System.nanoTime());

                val gRes = new GlobalRef(new Cell[Boolean](false));
                //val p = Place(pair.second.first);
                val p = Place(info.id);
sHandle().debugPrint(here + ": sending to: " + p.id());
val hereId = here.id();

if (p.id() != here.id())
                at (p) {

                    var res:Boolean = false;
sHandle().debugPrint(here + ": sending from: " + hereId);
                    //sHandle().lockTerminate();
                    if (sHandle().tryLockTerminate() && sHandle().terminate != TokDead) {
                        (sHandle() as PlaceAgentSeq[K]).joinWithListShared(boxes);
                        //atomic sHandle().active = true;
                        res = true;

	                    sHandle().unlockTerminate();
                    }

                    val r = res;
                    at (gRes.home) { gRes().set(r); }

                }
sHandle().debugPrint(here + ": sending to " + p.id() + " done: " + gRes().value);

//BoxSend.addAndGet(-System.nanoTime());

                if (gRes().value) { // boxes were sent to other place.
                    if (p.id() < here.id()) sentBw.set(true);

                    nSends.incrementAndGet();
                    nSentBoxes.addAndGet(boxes.size());
                }
                else {
                    // retract the list.
                    joinWithListShared(boxes);

                    //nSends.decrementAndGet();
                }

tBoxSend.addAndGet(System.nanoTime());
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
