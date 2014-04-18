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
		at (Place(0)) {
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

    var term:Int = 0;

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish {
		//async terminate(sHandle);

        while (terminate != 3) {

            if (preprocessor == null || !preprocessor.process(sHandle)) {
			    search(sHandle);
            }

            if (here.id() == 0)
                atomic if ((list.size()+listShared.size()) == 0 && terminate == 0 ) {
debugPrint(here + ": start termination");
                    terminate = 1;
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


    def terminate1(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var termBak:Int = 0;

        if (//list.isEmpty() && 
            term != terminate) {

            atomic {
debugPrint(here + ": terminate: " + terminate);
                termBak = terminate;
                if (here.id() == 0 && terminate == 2)
                    terminate = 3;
                else if (here.id() == 0 && terminate == 4) {
                    if ((list.size()+listShared.size()) == 0)
                        terminate = 1;
                    else {
                        terminate = 0;
                        //listShared.add(sHandle().solver.core.dummyBox());
                        return;
                    }
                }
                else if ((terminate == 2) &&
                         (list.size()+listShared.size()) > 0 &&
                         !sentBw.get()) {

                    listShared.add(sHandle().solver.core.dummyBox());
                    return;
                }
                else if (here.id() > 0 && terminate != 3) 
                    //terminate = 1;
                    terminate = 0;
    
                term = terminate;
            }

            // begin termination detection
            if (here.id() == 0 && term == 1) {
                at (here.next()) atomic {
                    sHandle().terminate = 2;
                    // put a dummy box
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
					//sHandle().initPhase = false;
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) atomic {
                    sHandle().terminate = 3;
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            else if (here.id() > 0) {
                val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
debugPrint(here + ": sending token " +v+ " to " + here.next());
                //atomic terminate = 0;
                at (here.next()) atomic {
                    sHandle().terminate = v;
sHandle().debugPrint(here + ": setting token " + sHandle().terminate);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
					//sHandle().initPhase = false;
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != 3)
                //    atomic terminate = 1;
            }
        }
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
            if (here.id() == 0 && terminate == 2)
                terminate = 3;
            else if (here.id() == 0 && terminate == 4) {
                if ((list.size()+listShared.size()) == 0)
                    terminate = 1;
                else {
                    terminate = 0;
                    //listShared.add(sHandle().solver.core.dummyBox());
                    unlock();
                    return;
                }
            }
            else if ((terminate == 2) &&
                     (list.size()+listShared.size()) > 0 &&
                     !sentBw.get()) {

                listShared.add(sHandle().solver.core.dummyBox());
                unlock();
                return;
            }
            else if (here.id() > 0 && terminate != 3) 
                //terminate = 1;
                terminate = 0;

            term = terminate;


            // begin termination detection
            if (here.id() == 0 && term == 1) {
                at (here.next()) {
                    (sHandle() as PlaceAgentSeq[K]).lock();
                    sHandle().terminate = 2;
                    // put a dummy box
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    (sHandle() as PlaceAgentSeq[K]).unlock();
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) {
                    (sHandle() as PlaceAgentSeq[K]).lock();
                    sHandle().terminate = 3;
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                    (sHandle() as PlaceAgentSeq[K]).unlock();
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            else if (here.id() > 0) {
                val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
debugPrint(here + ": sending token " +v+ " to " + here.next());
                //atomic terminate = 0;
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

    def terminate3(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var termBak:Int = 0;

		when (!initPhase) {}

        while (term != 3) {

            when ((list.size()+listShared.size()) == 0 &&
                  term != terminate
              ) {
debugPrint(here + ": terminate: " + terminate);

                termBak = terminate;
                if (here.id() == 0 && terminate == 2)
                    terminate = 3;
                else if (here.id() == 0 && terminate == 4)
                    //terminate = 1;
                    terminate = 0;
                else if (here.id() > 0 && terminate != 3) 
                    //terminate = 1;
                    terminate = 0;
    
                term = terminate;
            }

            // begin termination detection
            if (here.id() == 0 && term == 1) {
                at (here.next()) atomic {
                    sHandle().terminate = 2;
                    // put a dummy box
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
					//sHandle().initPhase = false;
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) atomic {
                    sHandle().terminate = 3;
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            else if (here.id() > 0) {
                val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
debugPrint(here + ": sending token " +v+ " to " + here.next());
                //atomic terminate = 0;
                at (here.next()) atomic {
                    sHandle().terminate = v;
sHandle().debugPrint(here + ": setting token " + sHandle().terminate);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(sHandle().solver.core.dummyBox());
					//sHandle().initPhase = false;
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != 3)
                //    atomic terminate = 1;
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
