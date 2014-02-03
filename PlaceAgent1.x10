import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent1[K] extends PlaceAgent[K] {

    //var nSearchPs:AtomicInteger = new AtomicInteger(0);

    public def this(solver:BAPSolver[K], debug:Boolean) {
        super(solver, debug);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
//debugPrint(here + ": initD: " + solver.core.getInitialDomain());
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
            at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
                box.setPrevVar(pv);
                atomic sHandle().list.add(box);
            }
debugPrint(here + ": responded to " + id);
            if (id < here.id()) sentBw.set(true);
            nSends.getAndIncrement();
            return true;
        }
        else
            return false;
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    val reqThres = 10;
    val maxNRequests = 5;

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (true) {
            var box:IntervalVec[K] = null;

debugPrint(here + ": wait...");
            when (!list.isEmpty()) {
                //isActive.set(true);
initPhase = false;

                box = list.removeFirst();
debugPrint(here + ": got box:\n" + box);
            }

            //nSearchPs.incrementAndGet();
            finish solver.search(sHandle, box);
            //nSearchPs.decrementAndGet();
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

            atomic if (terminate == 3 && list.size() == 0) { 
debugPrint(here + ": finish search");
                break;
            }
        }            
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
//   		debugPrint(here + ": start solving... ");

        // ??
        if (list.isEmpty() && nSentRequests.get() == 0)
            list.add(solver.core.dummyBox());

        finish {

            // search task
            async search(sHandle);
    
            // request task
            async request(sHandle);
    
            // cancelling task
            async cancel(sHandle);
    
            // termination
            async terminate(sHandle);

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

//debugPrint(here + ": boxAvail: " + !list.isEmpty());
//   		debugPrint(here + ": done");
//   		Console.ERR.flush();
    }

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (true) {
debugPrint(here + ": REQ wait requesting");
            when ((list.size() <= reqThres && nSentRequests.get() < maxNRequests)
                  || terminate == 3
              ) {
                // not used?
                //isActive.set(false);
            }

/*            // cancel the received requests.
debugPrint(here + ": REQ cancel req");
            //atomic while (!initPhase && reqQueue.getSize() > 0) {
            while (true) {
                if (initPhase) break;

                var id:Int = -1;
                atomic { 
                    if (reqQueue.getSize() > 0)
                        id = reqQueue.removeFirstUnsafe();
                }
                if (id >= 0) at (Place(id)) {
                    sHandle().nSentRequests.decrementAndGet();
                    //atomic sHandle().list.add(sHandle().solver.core.dummyBox());
                }
                else break;
            }
*/

debugPrint(here + ": REQ terminate: " + terminate);
            if (terminate == 3) {
debugPrint(here + ": REQ finish req");
                break;
            }

debugPrint(here + ": REQ requesting");
            // request for a domain
            if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                ) {
                val id = here.id();
                val p = selectPlace();
debugPrint(here + ": REQ select place: " + p);
                //val gNReqs = GlobalRef[AtomicInteger](nReqs);
                //val gNSentRequests = GlobalRef[AtomicInteger](nSentRequests);
                at (p) //if (sHandle().terminate != 3) 
                {
                    sHandle().reqQueue.addLast(id);
                    //atomic sHandle().list.add(sHandle().solver.core.dummyBox());
//sHandle().debugPrint(here + ": REQ requested from " + id);
                    /*at (gNReqs.home) {
                        gNReqs().incrementAndGet();
                        gNSentRequests().incrementAndGet();
                    }*/
                }
debugPrint(here + ": requested to " + p);
                nReqs.getAndIncrement();
                nSentRequests.getAndIncrement();
debugPrint(here + ": REQ done");
            }
        }
    }
    
    def cancel(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        when (terminate == 3) {}

debugPrint(here + ": cancel req");
        // cancel the received requests.
        while (true) {
            if (initPhase) break;

            var id:Int = -1;
            atomic { 
                if (reqQueue.getSize() > 0)
                    id = reqQueue.removeFirstUnsafe();
            }
            if (id >= 0) at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
                //atomic sHandle().list.add(sHandle().solver.core.dummyBox());
sHandle().debugPrint(here + ": #sp: " + sHandle().nSearchPs.get() + ", #r: " + sHandle().nSentRequests.get() + ", #list: " + sHandle().list.size());
            }
            else break;
        }
debugPrint(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get());
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
}

// vim: shiftwidth=4:tabstop=4:expandtab
