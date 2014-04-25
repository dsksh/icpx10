import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicDouble;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgentSeparated[K] extends PlaceAgent[K] {

    // the number of boxes that should be kept in the list
    val requestThreshold:Double;

    // max number of requests
    val maxNRequests:Int;

    //var nSearchPs:AtomicInteger = new AtomicInteger(0);

    public def this(solver:BAPSolver[K]) {
        super(solver);

/*		if (here.id() == 0) {
        	val reqThres = System.getenv("RPX10_REQUEST_THRESHOLD");
        	if (reqThres != null) this.requestThreshold = Int.parse(reqThres);
	        else this.requestThreshold = 5;
		}

        val maxNReqs = System.getenv("RPX10_MAX_N_REQUESTS");
        if (maxNReqs != null) this.maxNRequests = Int.parse(maxNReqs);
        else this.maxNRequests = 5;
*/

		var rth:Double = 0;
		var mnr:Int = 0;
		val gRth = new GlobalRef(new Cell(rth));
		val gMnr = new GlobalRef(new Cell(mnr));
		at (Place(0)) {
    		val sRth = System.getenv("RPX10_REQUEST_THRESHOLD");
   			val sMnr = System.getenv("RPX10_MAX_N_REQUESTS");
			val rth1:Double = sRth != null ? Double.parse(sRth) : 1.;
			val mnr1:Int = sMnr != null ? Int.parse(sMnr) : 5;
			at (gRth.home) {
				gRth().set(rth1);
				gMnr().set(mnr1);
			}
		}
    	this.requestThreshold = gRth().value;
    	this.maxNRequests = gMnr().value;
//Console.OUT.println(here + ": rth: " + requestThreshold);
//Console.OUT.println(here + ": mnr: " + maxNRequests);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
		val box = solver.core.getInitialDomain();
totalVolume.addAndGet(box.volume());
        list.add(box);

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            at (Place(pi)) {
sHandle().debugPrint(here + ": inc #r");
                sHandle().nSentRequests.incrementAndGet();
            }
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        var id:Int = -1;
        atomic if (reqQueue.getSize() > 0) {
            id = reqQueue.removeFirstUnsafe();
//sHandle().debugPrint(here + ": got req from: " + id);
        }

        if (id >= 0) {
            val pv:Box[K] = box.prevVar();
			//async 
			val thres = requestThreshold; // FIXME
			var res:Boolean = false;
			//var res:Boolean = true;
			val gRes = new GlobalRef(new Cell(res));
sHandle().debugPrint(here + ": sending box:\n" + box + '\n');
            at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
//sHandle().debugPrint(here + ": RIF load: " + (sHandle().list.size() + sHandle().nSearchPs.get()));
sHandle().debugPrint(here + ": RIF load: " + sHandle().totalVolume.get());
				//if (sHandle().list.size() + sHandle().nSearchPs.get() <= thres) {
				if (sHandle().totalVolume.get() <= thres) {
                	box.setPrevVar(pv);
 	                async
    				atomic {
                        sHandle().list.add(box);
sHandle().totalVolume.addAndGet(box.volume());
                    }

	                at (gRes.home) gRes().set(true);
				}
            }
			if (gRes().value) {
//debugPrint(here + ": responded to " + id);
	            if (id < here.id()) sentBw.set(true);
	            //nSends.getAndIncrement();
	            nSends++;
			}
            return gRes().value;
        }
        else
            return false;
    }

	var prevTime:Long = System.currentTimeMillis();

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        // ??
        if (list.isEmpty() && nSentRequests.get() == 0)
            list.add(solver.core.dummyBox());

        finish {

            // search task
            async search(sHandle);
    
            // request task
            async request(sHandle);
    
            // termination
            async terminate(sHandle);
    
            // cancelling task
            async cancelOnTermination(sHandle);

        } // finish
    }

    /// cancel the received requests.
    def cancelRequests(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (true) {
            var id:Int = -1;
            atomic if (reqQueue.getSize() > 0)
                id = reqQueue.removeFirstUnsafe();

            if (id >= 0) at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
                //atomic sHandle().list.add(sHandle().solver.core.dummyBox());
atomic sHandle().debugPrint(here + ": CR #sp: " + sHandle().nSearchPs.get() + ", #r: " + sHandle().nSentRequests.get() + ", #list: " + sHandle().list.size());
            }
            else break;
        }
    }

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //finish
        while (terminate != TokDead || list.size() > 0) {

            var box:IntervalVec[K] = null;

var time:Long;

debugPrint(here + ": wait...");
            when (!list.isEmpty()) {
                //isActive.set(true);
//nSearchPs.incrementAndGet();

time = -System.nanoTime();

                box = list.removeFirst();
debugPrint(here + ": got box:\n" + box);
initPhase = false;
            }

//debugPrint(here + ": load in search: " + (list.size() + nSearchPs.get()));
debugPrint(here + ": load in search: " + totalVolume.get());

            finish
            solver.search(sHandle, box);

//debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

            if (here.id() == 0) atomic
                if (list.size() == 0 && terminate == TokActive) {
debugPrint(here + ": start termination");
                    terminate = TokInvoke;
                }

time += System.nanoTime();
sHandle().tSearch += time;
        }            
    }

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		when (!initPhase) {}

        while (true) {
debugPrint(here + ": wait requesting");
            when ((//(list.size() + nSearchPs.get()) <= requestThreshold && 
				   totalVolume.get() <= requestThreshold &&
                   nSentRequests.get() < maxNRequests)
                  || terminate == TokDead
              ) {
//debugPrint(here + ": load when requesting: " + (list.size() + nSearchPs.get()));
debugPrint(here + ": load when requesting: " + totalVolume.get());
            }

            if (terminate == TokDead) {
debugPrint(here + ": finish req");
                break;
            }

            // cancel the received requests.
            if (!initPhase && list.size() == 0 //&& nSearchPs.get() == 0
            ) 
                cancelRequests(sHandle);

            // request for a domain
            if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                ) {
                val id = here.id();
                val p = selectPlace();
debugPrint(here + ": select place to request: " + p);
                at (p) //if (sHandle().terminate != TokDead) 
                    sHandle().reqQueue.addLast(id);
debugPrint(here + ": requested to " + p);
                //nReqs.getAndIncrement();
                nReqs++;
                nSentRequests.getAndIncrement();
            }
        }
    }

    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var term:Int = TokActive;
    
		when (!initPhase) {}

        while (true) {

            var termBak:Int = TokActive;
            when (term != terminate) {
debugPrint(here + ": terminate: " + terminate);
                termBak = terminate;
                if (here.id() == 0 && terminate == TokIdle)
                    terminate = TokDead;
                else if (here.id() == 0 && terminate == TokCancel)
                    terminate = TokInvoke;
                else if (here.id() > 0 && terminate != TokDead) 
                    terminate = TokInvoke;
    
                term = terminate;
            }
    
            // begin termination detection
            if (here.id() == 0 && term == TokInvoke) {
                at (here.next()) atomic {
                    sHandle().terminate = TokIdle;
                    // put a dummy box
                    //sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == TokDead) {
                at (here.next()) atomic {
                    sHandle().terminate = TokDead;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            //else if (here.id() == 0 && term == TokCancel) {
            //    atomic terminate = TokInvoke;
            //}
/*            else if (here.id() > 0 && term > TokInvoke) {
                val v = (term == TokIdle && sentBw.getAndSet(false)) ? TokCancel : term;
                //atomic terminate = TokActive;
                at (here.next()) atomic {
sHandle().debugPrint(here + ": token before: " + sHandle().terminate);
                    sHandle().terminate = v;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != TokDead)
                //    atomic terminate = TokInvoke;
            }
*/
            else if (here.id() > 0) {
                val v = (termBak == TokIdle && sentBw.getAndSet(false)) ? TokCancel : termBak;
                //atomic terminate = TokActive;
                at (here.next()) atomic {
                    sHandle().terminate = v;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != TokDead)
                //    atomic terminate = TokInvoke;
            }
    
            if (term == TokDead) {
debugPrint(here + ": finish termination");
                break;
            }
        }
    }
    
    def cancelOnTermination(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        when (terminate == TokDead) {}

debugPrint(here + ": cancel req");
        cancelRequests(sHandle);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
