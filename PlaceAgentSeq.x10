import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;

public class PlaceAgentSeq[K] extends PlaceAgentSeparated[K] {

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
        initPhase = true;
        //initPhase = false;
    }

    public def setPreprocessor(pp:PreprocessorSeq[K]) {
        this.preprocessor = pp;
        // TODO
        initPhase = false;
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        if (preprocessor != null) {
    		val box = solver.core.getInitialDomain();
totalVolume.addAndGet(box.volume());
            list.add(box);
            preprocessor.setup(sHandle);
        }
        else
            super.setup(sHandle);

        initPhase = true;
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        return false;
    }

    public def addDom(box:IntervalVec[K]) {
        return list.add(box);
    }

    public atomic def addDomShared(box:IntervalVec[K]) {
        return listShared.add(box);
    }

    var term:Int = TokActive;

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish {
		//async terminate(sHandle);

        while (terminate != TokDead) {

            if (preprocessor == null || !preprocessor.process(sHandle)) {
			    search(sHandle);
            }

            if (here.id() == 0)
                atomic if ((list.size()+listShared.size()) == 0 && terminate == TokActive) {
debugPrint(here + ": start termination");
                    terminate = TokInvoke;
    		    }

			terminate(sHandle);
        }
        }
	}

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        //if (preprocessor == null || !preprocessor.process(sHandle)) {

if (tEndPP < 0l) tEndPP += System.nanoTime();

debugPrint(here + ": wait");
            when (initPhase || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + initPhase + ", " + list.size()+","+listShared.size());

                initPhase = false;

                // append the two lists.
                for (box in listShared)
                    list.add(box);

                // reset
                listShared.clear();
            }

        	finish 
        	for (1..nSearchSteps) {
        		if (!searchBody(sHandle))
        			break;
            }
        //}
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


    val lock = new Lock();

    def lock() {
        if (!lock.tryLock()) {
            Runtime.increaseParallelism();
            lock.lock();
            Runtime.decreaseParallelism(1);
        }
    }
    def unlock() {
        lock.unlock();
    }

    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        if (term != terminate) {

            lock();

debugPrint(here + ": terminate: " + terminate);
            val termBak = terminate;
            if (here.id() == 0 && terminate == TokIdle)
                terminate = TokDead;
            else if (here.id() == 0 && terminate == TokCancel) {
                if ((list.size()+listShared.size()) == 0)
                    terminate = TokInvoke;
                else {
                    terminate = term = TokActive;
                    //listShared.add(sHandle().solver.core.dummyBox());
                    unlock();
                    return;
                }
            }
            else if ((terminate == TokIdle) &&
                     (list.size()+listShared.size()) > 0 &&
                     !sentBw.get()) {

                listShared.add(sHandle().solver.core.dummyBox());
                unlock();
                return;
            }
            else if (here.id() > 0 && terminate != TokDead) 
                //terminate = TokInvoke;
                terminate = TokActive;

            term = terminate;


            // begin termination detection
            if (here.id() == 0 && term == TokInvoke) {
                at (here.next()) {
                    (sHandle() as PlaceAgentSeq[K]).lock();
                    sHandle().terminate = TokIdle;
                    // put a dummy box
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    (sHandle() as PlaceAgentSeq[K]).unlock();
                }
debugPrint(here + ": sent token Idle to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == TokDead) {
                at (here.next()) {
                    (sHandle() as PlaceAgentSeq[K]).lock();
                    sHandle().terminate = TokDead;
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    (sHandle() as PlaceAgentSeq[K]).unlock();
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            else if (here.id() > 0) {
                val v = (termBak == TokIdle && sentBw.getAndSet(false)) ? TokCancel : termBak;
debugPrint(here + ": sending token " +v+ " to " + here.next());
                //atomic terminate = TokActive;
                at (here.next()) {
                    (sHandle() as PlaceAgentSeq[K]).lock();
                    sHandle().terminate = v;
    sHandle().debugPrint(here + ": setting token " + sHandle().terminate);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    (sHandle() as PlaceAgentSeq[K]).unlock();
                }
    debugPrint(here + ": sent token " + v + " to " + here.next());
    
            }

            unlock();
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
