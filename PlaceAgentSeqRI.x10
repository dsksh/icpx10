import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class PlaceAgentSeqRI[K] extends PlaceAgentSeq[K] {

    // the number of boxes that should be kept in the list
    val requestThreshold:Double;

    // max number of requests
    val maxNRequests:Int;

    public def this(solver:BAPSolver[K]) {
        super(solver);

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

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        var id:Int = -1;
        atomic if (reqQueue.getSize() > 0) {
            id = reqQueue.removeFirstUnsafe();
//sHandle().debugPrint(here + ": got req from: " + id);
        }

        if (id >= 0) {
            val pv:Box[K] = box.prevVar();
//sHandle().debugPrint(here + ": sending box:\n" + box + '\n');
            val p = Place(id);
            async at (p) {
                sHandle().nSentRequests.decrementAndGet();
                box.setPrevVar(pv);
                //(sHandle() as PlaceAgentSeq[K]).addDomShared(box);
                atomic (sHandle() as PlaceAgentSeq[K]).listShared.add(box);
sHandle().totalVolume.addAndGet(box.volume());
            }
//sHandle().debugPrint(here + ": responded to " + id);
            if (id < here.id()) sentBw.set(true);
            //nSends.getAndIncrement();
            nSends++;

            return true;
        }
        else
            return false;
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish
        while (terminate != TokDead) {

			search(sHandle);
			
			request(sHandle);

			terminate(sHandle);
        }
	}

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

//debugPrint(here + ": wait requesting");
            if ((//(list.size() + nSearchPs.get()) <= requestThreshold && 
				   totalVolume.get() <= requestThreshold &&
                   nSentRequests.get() < maxNRequests)
                  || terminate == TokDead
              ) {
//debugPrint(here + ": load when requesting: " + (list.size() + nSearchPs.get()));
//debugPrint(here + ": load when requesting: " + totalVolume.get());

//            if (terminate == TokDead) {
//debugPrint(here + ": finish req");
//                Clock.advanceAll();
//                break;
//            }

                // cancel the received requests.
                if (list.size() == 0) 
                    cancelRequests(sHandle);
    
                // request for a domain
                if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                    ) {
                    val p = selectPlace();
debugPrint(here + ": select place to request: " + p);
                    val id = here.id();
                    async at (p) //if (sHandle().terminate != TokDead) 
                        sHandle().reqQueue.addLast(id);
debugPrint(here + ": requested to " + p);
                    //nReqs.getAndIncrement();
                    nReqs++;
                    nSentRequests.getAndIncrement();
                }
            }
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
}

// vim: shiftwidth=4:tabstop=4:expandtab
