import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent1[K] extends PlaceAgent[K] {

    // the number of boxes that should be kept in the list
    val requestThreshold:Int;

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

		var rth:Int = 0;
		var mnr:Int = 0;
		val gRth = new GlobalRef(new Cell(rth));
		val gMnr = new GlobalRef(new Cell(mnr));
		at (Place(0)) {
    		val sRth = System.getenv("RPX10_REQUEST_THRESHOLD");
   			val sMnr = System.getenv("RPX10_MAX_N_REQUESTS");
			val rth1:Int = sRth != null ? Int.parse(sRth) : 5;
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

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent1[K]]) { 
        list.add(solver.core.getInitialDomain());

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            at (Place(pi)) sHandle().nSentRequests.incrementAndGet();
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
			val gRes = new GlobalRef(new Cell(res));
            at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
sHandle().debugPrint(here + ": RIF load: " + (sHandle().list.size() + sHandle().nSearchPs.get()));
				if (sHandle().list.size() + sHandle().nSearchPs.get() <= thres) {
                	box.setPrevVar(pv);
sHandle().debugPrint(here + ": adding box");
 	                async atomic sHandle().list.add(box);

	                at (gRes.home) gRes().set(true);
sHandle().debugPrint(here + ": gRes set");
				}
            }
			if (gRes().value) {
debugPrint(here + ": responded to " + id);
	            if (id < here.id()) sentBw.set(true);
	            nSends.getAndIncrement();
			}
            return gRes().value;
        }
        else
            return false;
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

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

/*            if (here.id() == 0) 
                async while (true)
                    when (terminate != 1 && 
                          nSentRequests.get() == 0 && nSearchPs.get() == 0) {
    
                        if (terminate == 3) break;
                        else if (terminate == 0 || terminate == 4) {
debugPrint(here + ": start termination");
                            terminate = 1;
                        }
                    }
*/
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
sHandle().debugPrint(here + ": #sp: " + sHandle().nSearchPs.get() + ", #r: " + sHandle().nSentRequests.get() + ", #list: " + sHandle().list.size());
            }
            else break;
        }
    }

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //finish
        while (true) {
            var box:IntervalVec[K] = null;

debugPrint(here + ": wait...");
            when (!list.isEmpty()) {
                //isActive.set(true);
                box = list.removeFirst();
debugPrint(here + ": got box:\n" + box);
initPhase = false;
            }

debugPrint(here + ": load in search: " + (list.size() + nSearchPs.get()));

            //finish 
nSearchPs.incrementAndGet();
            solver.search(sHandle, box);
//nSearchPs.decrementAndGet();

//debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

            if (here.id() == 0) atomic
                if (list.size() == 0
                    && nSearchPs.get() == 0
                    //&& nSentRequests.get() == 0 
                    //&& (terminate == 0 || terminate == 4)) {
                    && terminate == 0) {
debugPrint(here + ": start termination");
                    terminate = 1;
                }

            atomic if (terminate == 3 && list.size() == 0) { 
debugPrint(here + ": finish search");
                break;
            }
        }            
    }

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		when (!initPhase) {}

        while (true) {
debugPrint(here + ": wait requesting");
            when (((list.size() + nSearchPs.get()) <= requestThreshold && 
                   nSentRequests.get() < maxNRequests)
                  || terminate == 3
              ) {
                // not used?
                //isActive.set(false);

debugPrint(here + ": load when requesting: " + (list.size() + nSearchPs.get()));
            }

            if (terminate == 3) {
debugPrint(here + ": finish req");
                break;
            }

            // cancel the received requests.
            if (!initPhase && list.size() == 0 && nSearchPs.get() == 0) 
                cancelRequests(sHandle);

            // request for a domain
            if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                ) {
                val id = here.id();
                val p = selectPlace();
debugPrint(here + ": select place to request: " + p);
                //val gNReqs = GlobalRef[AtomicInteger](nReqs);
                //val gNSentRequests = GlobalRef[AtomicInteger](nSentRequests);
                at (p) //if (sHandle().terminate != 3) 
                    sHandle().reqQueue.addLast(id);
debugPrint(here + ": requested to " + p);
                nReqs.getAndIncrement();
                nSentRequests.getAndIncrement();
            }
        }
    }

    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var term:Int = 0;
    
        while (true) {

            var termBak:Int = 0;
            when (term != terminate) {
debugPrint(here + ": terminate: " + terminate);
                termBak = terminate;
                if (here.id() == 0 && terminate == 2) 
                    terminate = 3;
                else if (here.id() == 0 && terminate == 4)
                    terminate = 1;
                else if (here.id() > 0 && terminate != 3) 
                    terminate = 1;
    
                term = terminate;
            }
    
            // begin termination detection
            if (here.id() == 0 && term == 1) {
                at (here.next()) atomic {
                    sHandle().terminate = 2;
                    // put a dummy box
                    //sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) atomic {
                    sHandle().terminate = 3;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            //else if (here.id() == 0 && term == 4) {
            //    atomic terminate = 1;
            //}
/*            else if (here.id() > 0 && term > 1) {
                val v = (term == 2 && sentBw.getAndSet(false)) ? 4 : term;
                //atomic terminate = 0;
                at (here.next()) atomic {
sHandle().debugPrint(here + ": token before: " + sHandle().terminate);
                    sHandle().terminate = v;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != 3)
                //    atomic terminate = 1;
            }
*/
            else if (here.id() > 0) {
                val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
                //atomic terminate = 0;
                at (here.next()) atomic {
                    sHandle().terminate = v;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != 3)
                //    atomic terminate = 1;
            }
    
            if (term == 3) {
debugPrint(here + ": finish termination");
                break;
            }
        }
    }
    
    def cancelOnTermination(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        when (terminate == 3) {}

debugPrint(here + ": cancel req");
        cancelRequests(sHandle);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
