import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;

public class PlaceAgentSeq[K] extends PlaceAgent[K] {

	val nSearchSteps:Int;

    var listShared:List[IntervalVec[K]] = null;

    var preprocessor:PreprocessorSeq[K] = null;

    public def this(solver:BAPSolver[K]) {
        super(solver);

		val gNSS = new GlobalRef(new Cell[Int](0));
        val p0 = Place(0);
		at (p0) {
   			val sNSS = System.getenv("RPX10_N_SEARCH_STEPS");
			val nSS:Int = sNSS != null ? Int.parse(sNSS) : 1;
			at (gNSS.home) 
				gNSS().set(nSS);
		}
    	this.nSearchSteps = gNSS().value;

        listShared = new ArrayList[IntervalVec[K]]();

        // TODO
        active = true;
        //active = false;
    }

    public def setPreprocessor(pp:PreprocessorSeq[K]) {
        this.preprocessor = pp;
        // TODO
        active = false;
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        if (preprocessor != null) {
    		val box = solver.core.getInitialDomain();
//totalVolume.addAndGet(box.volume());
            list.add(box);
            preprocessor.setup(sHandle);
        }
        else
            super.setup(sHandle);

        active = true;
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        return false;
    }

    public def addDom(box:IntervalVec[K]) {
        return list.add(box);
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

	public def getLoad() {
        try {
            lockSList();
            return list.size()+listShared.size();
        }
        finally {
            unlockSList();
        }
	}

    var term:Int = TokActive;

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish
        while (getTerminate() != TokDead || (list.size()+listShared.size()) > 0) {

            if (preprocessor == null || !preprocessor.process(sHandle)) {
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

			terminate(sHandle);
        }
	}

    def waitActivation() {
        while (true) {
            atomic 
			if (active || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + active + ", " + list.size()+","+listShared.size());
                active = false;
                return;
            }

            System.sleep(100);
        }
    }

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

if (tEndPP < 0l) tEndPP += System.nanoTime();

debugPrint(here + ": wait");
        when (active || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + active + ", " + list.size()+","+listShared.size());
            active = false;
        }

        //waitActivation();

        joinTwoLists();

    	finish 
    	for (1..nSearchSteps) {
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


    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        if (term != getTerminate()) {

            lockTerminate();

debugPrint(here + ": terminate: " + terminate);
            val termBak = terminate;

            if (here.id() == 0 && terminate == TokIdle)
                terminate = TokDead;

            else if (here.id() == 0 && terminate == TokCancel) {
                if ((list.size()+listShared.size()) == 0)
                    terminate = TokInvoke;
                else {
                    terminate = term = TokActive;
                    unlockTerminate();
                    return;
                }
            }
            else if (here.id() > 0 && terminate == TokIdle && !sentBw.get()) {
                if ((list.size()+listShared.size()) == 0)
                    terminate = TokActive;
                else {
                    unlockTerminate();
                    //addDomShared(sHandle().solver.core.dummyBox());
                    atomic sHandle().active = true;
                    return;
                }
            }
            else if (here.id() > 0 && terminate != TokDead) 
                terminate = TokActive;

            term = terminate;

            unlockTerminate();


            // begin termination detection
            if (here.id() == 0 && term == TokInvoke) {
                at (here.next()) {
                    sHandle().setTerminate(TokIdle);
                    // put a dummy box
                    //(sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    atomic sHandle().active = true;
                }
debugPrint(here + ": sent token Idle to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == TokDead) {
                at (here.next()) {
                    sHandle().setTerminate(TokDead);
                    //(sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    atomic sHandle().active = true;
                }
debugPrint(here + ": sent token Dead to " + here.next());
            }
            else if (here.id() > 0) {
				val sb = sentBw.getAndSet(false);
                val t = (termBak == TokIdle && sb) ? TokCancel : termBak;
debugPrint(here + ": sending token " + t + " to " + here.next());
                at (here.next()) {
                    sHandle().setTerminate(t);
                    //(sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    atomic sHandle().active = true;
                }
debugPrint(here + ": sent token " + t + " to " + here.next());
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
