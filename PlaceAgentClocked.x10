import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicDouble;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgentClocked[K] extends PlaceAgentSeparated[K] {

	val nSearchSteps:Int;

    public def this(solver:BAPSolver[K]) {
        super(solver);

		var nSS:Int = 0;
		val gNSS = new GlobalRef(new Cell(nSS));
		at (Place(0)) {
   			val sNSS = System.getenv("RPX10_N_SEARCH_STEPS");
			val nSS1:Int = sNSS != null ? Int.parse(sNSS) : 1;
			at (gNSS.home) 
				gNSS().set(nSS1);
		}
    	this.nSearchSteps = gNSS().value;
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
                sHandle().nSentRequests.decrementAndGet();
                box.setPrevVar(pv);
				//async
                atomic {
                    sHandle().list.add(box);
sHandle().totalVolume.addAndGet(box.volume());
                }
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

/*    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        var id:Int = -1;
        // TODO
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
//sHandle().debugPrint(here + ": RIF load: " + sHandle().totalVolume.get());
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
    */

	var prevTime:Long = System.currentTimeMillis();

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        // ??
        if (list.isEmpty() && nSentRequests.get() == 0)
            list.add(solver.core.dummyBox());

        clocked finish {

            // search task
            clocked async search(sHandle);
    
            // request task
            clocked async request(sHandle);
    
            // termination
            clocked async terminate(sHandle);
    
            // cancelling task
            async cancelOnTermination(sHandle);

        } // finish
    }

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //finish
        //while (terminate != 3 || list.size() > 0) {
        while (terminate != 3) {

            if (!list.isEmpty()) {

/*var time:Long = -System.nanoTime();

            	var box:IntervalVec[K] = null;
                atomic box = list.removeFirst();
//debugPrint(here + ": got box:\n" + box);
initPhase = false;

//debugPrint(here + ": load in search: " + (list.size() + nSearchPs.get()));
//debugPrint(here + ": load in search: " + totalVolume.get());

                finish
                solver.search(sHandle, box);

//debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

                if (here.id() == 0) atomic
                    if (list.size() == 0
                        //&& nSearchPs.get() == 0
                        //&& nSentRequests.get() == 0 
                        //&& (terminate == 0 || terminate == 4)) {
                        && terminate == 0) {
debugPrint(here + ": start termination");
                        terminate = 1;
                    }

time += System.nanoTime();
sHandle().tSearch += time;
*/

				finish 
				for (i in 1..nSearchSteps)
					if (!searchBody(sHandle))
						break;
            }
            else System.sleep(1);

            Clock.advanceAll();
            Clock.advanceAll();
        }
    }

	def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {

        var box:IntervalVec[K] = null;

        if (!list.isEmpty()) {

var time:Long = -System.nanoTime();

            atomic box = list.removeFirst();

//debugPrint(here + ": got box:\n" + box);
initPhase = false;

//debugPrint(here + ": load in search: " + (list.size() + nSearchPs.get()));
//debugPrint(here + ": load in search: " + totalVolume.get());

            //finish
            solver.search(sHandle, box);

//debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

time += System.nanoTime();
sHandle().tSearch += time;

            if (here.id() == 0) atomic
                if (list.size() == 0 && terminate == 0) {
debugPrint(here + ": start termination");
                    terminate = 1;
                }

			return true;
		}
		else return false;
	}

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		while (initPhase) {
			Clock.advanceAll();
			Clock.advanceAll();
		}

        //while (true) {
        while (terminate != 3) {

            Clock.advanceAll();

debugPrint(here + ": wait requesting");
            if ((//(list.size() + nSearchPs.get()) <= requestThreshold && 
				   totalVolume.get() <= requestThreshold &&
                   nSentRequests.get() < maxNRequests)
                  || terminate == 3
              ) {
//debugPrint(here + ": load when requesting: " + (list.size() + nSearchPs.get()));
//debugPrint(here + ": load when requesting: " + totalVolume.get());

//            if (terminate == 3) {
//debugPrint(here + ": finish req");
//                Clock.advanceAll();
//                break;
//            }

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
                    at (p) //if (sHandle().terminate != 3) 
                        sHandle().reqQueue.addLast(id);
debugPrint(here + ": requested to " + p);
                    //nReqs.getAndIncrement();
                    nReqs++;
                    nSentRequests.getAndIncrement();
                }
            }

            Clock.advanceAll();
        }
    }


    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var term:Int = 0;
    
		while (initPhase) {
			Clock.advanceAll();
			Clock.advanceAll();
		}

        while (term != 3) {

            Clock.advanceAll();
            Clock.advanceAll();

            var termBak:Int = 0;
            if (list.isEmpty() && term != terminate) {
                atomic {
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
                        //sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
debugPrint(here + ": sent token 3 to " + here.next());
                }
                else if (here.id() > 0) {
                    val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
                    //atomic terminate = 0;
                    at (here.next()) atomic {
                        sHandle().terminate = v;
                        //sHandle().list.add(sHandle().solver.core.dummyBox());
                    }
debugPrint(here + ": sent token " + v + " to " + here.next());
        
                    //if (term != 3)
                    //    atomic terminate = 1;
                }
            }
        }
    }
    
    def cancelOnTermination(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        when (terminate == 3) {}

debugPrint(here + ": cancel req");
        cancelRequests(sHandle);
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
//sHandle().debugPrint(here + ": CR #sp: " + sHandle().nSearchPs.get() + ", #r: " + sHandle().nSentRequests.get() + ", #list: " + sHandle().list.size());
            }
            else break;
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
