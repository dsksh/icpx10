import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    //val sizeNbors:Int = 5; // FIXME
    val maxDelta:Int;
    //var nSendsBox:Double;
    var nSendsLoad:Int;
    //val minNSendsBox:Double;

    val neighbors:List[Int];

	// list of the neighbors' loads.
    val loads:List[Int];
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

	def getLoad(i:Int) {
		lockLoads();
		try {
			return loads(i);
		}
		finally {
			unlockLoads();
		}
	}
	def setLoad(i:Int, l:Int) {
		lockLoads();
		loads(i) = l;
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
		val gMD = new GlobalRef(new Cell[Int](0));
		val gNSB = new GlobalRef(new Cell[Double](0.));
		val gNSL = new GlobalRef(new Cell[Int](0));
        val p0 = Place(0);
		at (p0) {
   			val sMD = System.getenv("RPX10_MAX_DELTA");
   			val sNSB = System.getenv("RPX10_N_SENDS_BOX");
   			val sNSL = System.getenv("RPX10_N_SENDS_LOAD");
			val nMD:Int = sMD != null ? Int.parse(sMD) : 10;
			val nNSB:Double = sNSB != null ? Double.parse(sNSB) : 2.;
			val nNSL:Int    = sNSL != null ? Int.parse(sNSL) : 2;
			at (gMD.home) {
				gMD().set(nMD);
				gNSB().set(nNSB);
				gNSL().set(nNSL);
            }
		}
    	maxDelta = gMD().value;
    	//nSendsBox = gNSB().value;
    	//minNSendsBox = gNSB().value;
    	nSendsLoad = gNSL().value;

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

        loads = new ArrayList[Int](nSendsLoad);
        for (neighbors.indices()) 
            //loads.add(Int.MAX_VALUE/(neighbors.size()+1));
            loads.add(-1);

        neighborsInv = new ArrayList[Int](nSendsLoad);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);

        @Pragma(Pragma.FINISH_SPMD) 
        finish for (p in Place.places())
        // at (p) async { <-- this results in an error
        async at (p) {
            when ((sHandle() as PlaceAgentSeqSI[K]).neighbors != null) {}

            val id = here.id();
            @Pragma(Pragma.FINISH_SPMD) finish
            for (pid in (sHandle() as PlaceAgentSeqSI[K]).neighbors) {
sHandle().debugPrint(here + ": neighbor: " + pid);
                val p1 = Place(pid);
                at (p1) async
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
		if (!initPhase && list.size() <= maxDelta) {
//sHandle().debugPrint(here + ": quit balance: " + terminate);
            return;
        }*/

        val load = list.size();

        //if (loadBak < 0 || Math.abs(load - loadBak) > maxDelta) {
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
            val l:Int = getLoad(i);
sHandle().debugPrint(here + ": load: " + l);
            if (l >= 0) {
                loadAvg += l;
                ++c;
            }
        }
        loadAvg /= c;

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta)
            distributeSearchSpace(sHandle, loadAvg);

sHandle().debugPrint(here + ": balance done");
    }

    def distributeSearchSpace(sHandle:PlaceLocalHandle[PlaceAgent[K]], loadAvg:Int) {
        // list of lists of boxes
        val boxesList = new ArrayList[Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]]](neighbors.size()+1);

        // list of boxes to be kept local.
        val bs0 = new LinkedList[IntervalVec[K]]();
        val p0 = new Pair[Int,Cell[Int]](here.id(),new Cell[Int](-1));
        val pp0 = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs0, p0);
        boxesList.add(pp0);

        for (i in neighbors.indices()) {
            val l:Int = getLoad(i);
            if (l < 0) continue;

            val ld = loadAvg - l;
sHandle().debugPrint(here + ": ld: " + ld);
            if (ld <= 0) continue;

            // create a list of boxes.
            val bs = new LinkedList[IntervalVec[K]]();
            val p = new Pair[Int,Cell[Int]](neighbors(i), new Cell[Int](ld));
            val pp = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs, p);
            boxesList.add(pp);
        }

        // distribute the content of the list
        var i:Int = 0;
        while (!list.isEmpty()) {
            val j = i % boxesList.size();
            val pair = boxesList(j);
            val cnt = pair.second.second();
            if ((j == 0 && cnt < 0) || cnt > 0) {
                val box:IntervalVec[K] = list.removeLast();
                if (box.size() > 0) { // dummy
                    pair.first.add(box); pair.second.second() = cnt-1;
                    box.count();
                }
                else
                    addDomShared(box);
            }
            ++i;
        }

        for (pair in boxesList) {
            val boxes = pair.first;

            if (boxes.isEmpty()) continue;

            async 
			{
                val gRes = new GlobalRef(new Cell[Boolean](false));
                val p = Place(pair.second.first);
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

                if (gRes().value) { // boxes were sent to other place.
                    if (p.id() < here.id()) sentBw.set(true);
                }
                else {
                    // retract the list.
                    joinWithListShared(boxes);
                    //for (b in listShared) boxes.add(b);
                    //listShared = null;
                    //listShared = boxes;
                    //atomic {
                    //    active = true;
                    //    nSends--;
                    //}
                    nSends--;
                }
            }

            nSends++;
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
