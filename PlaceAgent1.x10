import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgent1[K] extends PlaceAgent[K] {

    //var nSearchPs:AtomicInteger = new AtomicInteger(0);

    public def this(solver:BAPSolver[K]) {
        super(solver);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
//Console.OUT.println(here + ": initD: " + solver.core.getInitialDomain());
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
//Console.OUT.println(here + ": got req from: " + id);
        }

        if (id >= 0) {
            val pv:Box[K] = box.prevVar();
//async 
            at (Place(id)) {
                sHandle().nSentRequests.decrementAndGet();
                box.setPrevVar(pv);
                atomic sHandle().list.add(box);
            }
Console.OUT.println(here + ": responded to " + id);
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

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
//   		Console.OUT.println(here + ": start solving... ");

        // ??
        if (list.isEmpty() && nSentRequests.get() == 0)
            list.add(solver.core.dummyBox());

        finish {

        // search task
        async while (true) {
            var box:IntervalVec[K] = null;

Console.OUT.println(here + ": wait...");
            when (!list.isEmpty()) {
                //isActive.set(true);
initPhase = false;

                box = list.removeFirst();
Console.OUT.println(here + ": got box:\n" + box);
            }

            nSearchPs.incrementAndGet();
            finish solver.search(sHandle, box);
            nSearchPs.decrementAndGet();
Console.OUT.println(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get() + ", " + terminate);

            if (here.id() == 0) atomic
                if (list.size() == 0
                    && nSearchPs.get() == 0
                    //&& nSentRequests.get() == 0 
                    //&& (terminate == 0 || terminate == 4)) {
                    && terminate == 0) {
Console.OUT.println(here + ": start termination");
                    terminate = 1;
                }

            atomic if (terminate == 3 && list.size() == 0) { 
Console.OUT.println(here + ": finish search");
                break;
            }
        }            


        // request task
        async while (true) {
Console.OUT.println(here + ": REQ wait requesting");
            when ((list.size() <= reqThres && nSentRequests.get() < maxNRequests)
                  || terminate == 3
              ) {
                // not used?
                //isActive.set(false);
            }

/*            // cancel the received requests.
Console.OUT.println(here + ": REQ cancel req");
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

Console.OUT.println(here + ": REQ terminate: " + terminate);
            if (terminate == 3) {
Console.OUT.println(here + ": REQ finish req");
                break;
            }

Console.OUT.println(here + ": REQ requesting");
            // request for a domain
            if (Place.numPlaces() > 1 //&& nSentRequests.getAndIncrement() == 0
                ) {
                val id = here.id();
                val p = selectPlace();
Console.OUT.println(here + ": REQ select place: " + p);
                //val gNReqs = GlobalRef[AtomicInteger](nReqs);
                //val gNSentRequests = GlobalRef[AtomicInteger](nSentRequests);
                at (p) //if (sHandle().terminate != 3) 
                {
                    sHandle().reqQueue.addLast(id);
                    //atomic sHandle().list.add(sHandle().solver.core.dummyBox());
//Console.OUT.println(here + ": REQ requested from " + id);
                    /*at (gNReqs.home) {
                        gNReqs().incrementAndGet();
                        gNSentRequests().incrementAndGet();
                    }*/
                }
Console.OUT.println(here + ": requested to " + p);
                nReqs.getAndIncrement();
                nSentRequests.getAndIncrement();
Console.OUT.println(here + ": REQ done");
            }
        }

/*        if (here.id() == 0) 
            async while (true)
                when (terminate != 1 && 
                      nSentRequests.get() == 0 && nSearchPs.get() == 0) {

                    if (terminate == 3) break;
                    else if (terminate == 0 || terminate == 4) {
Console.OUT.println(here + ": start termination");
                        terminate = 1;
                    }
                }
*/

        // cancelling task
        async {
            when (terminate == 3) {}

Console.OUT.println(here + ": cancel req");
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
Console.OUT.println(here + ": #sp: " + sHandle().nSearchPs.get() + ", #r: " + sHandle().nSentRequests.get() + ", #list: " + sHandle().list.size());
                }
                else break;
            }
Console.OUT.println(here + ": #sp: " + nSearchPs.get() + ", #r: " + nSentRequests.get());
        }

        async {
            // termination token
            var term:Int = 0;
        
            while (true) {

            var termBak:Int = 0;
            when (term != terminate) {
Console.OUT.println(here + ": terminate: " + terminate);
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
atomic Console.OUT.println(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) atomic {
                    sHandle().terminate = 3;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
atomic Console.OUT.println(here + ": sent token 3 to " + here.next());
            }
            //else if (here.id() == 0 && term == 4) {
            //    atomic terminate = 1;
            //}
/*            else if (here.id() > 0 && term > 1) {
                val v = (term == 2 && sentBw.getAndSet(false)) ? 4 : term;
                //atomic terminate = 0;
                at (here.next()) atomic {
Console.OUT.println(here + ": token before: " + sHandle().terminate);
                    sHandle().terminate = v;
                    sHandle().list.add(sHandle().solver.core.dummyBox());
                }
atomic Console.OUT.println(here + ": sent token " + v + " to " + here.next());

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
atomic Console.OUT.println(here + ": sent token " + v + " to " + here.next());

                //if (term != 3)
                //    atomic terminate = 1;
            }

            if (term == 3) {
atomic Console.OUT.println(here + ": finish termination");
                break;
            }

            }
        }

        } // finish

//Console.OUT.println(here + ": boxAvail: " + !list.isEmpty());
//   		Console.OUT.println(here + ": done");
//   		Console.OUT.flush();
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
