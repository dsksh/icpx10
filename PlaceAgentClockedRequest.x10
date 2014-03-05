import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class PlaceAgentClockedRequest[K] extends PlaceAgentClocked[K] {

    public def this(solver:BAPSolver[K]) {
        super(solver);
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
                //(sHandle() as PlaceAgentClocked[K]).addDomShared(box);
                atomic (sHandle() as PlaceAgentClocked[K]).listShared.add(box);
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

        clocked finish {

            // search task
            clocked async search(sHandle);
    
            // request task
            clocked async request(sHandle);
    
            // termination
            clocked async terminate(sHandle);
    
        } // finish

        // cancelling task
        cancelRequests(sHandle);
    }

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		while (initPhase) {
			Clock.advanceAll();
			Clock.advanceAll();
		}

        //while (true) {
        while (terminate != 3) {

            Clock.advanceAll();

//debugPrint(here + ": wait requesting");
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
                if (list.size() == 0) 
                    cancelRequests(sHandle);
    
                // request for a domain
                if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                    ) {
                    val p = selectPlace();
debugPrint(here + ": select place to request: " + p);
                    val id = here.id();
                    async at (p) //if (sHandle().terminate != 3) 
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
}

// vim: shiftwidth=4:tabstop=4:expandtab
