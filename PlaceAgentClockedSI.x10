import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicDouble;
import x10.io.*;

public class PlaceAgentClockedSI[K] extends PlaceAgentClocked[K] {

    val neighbors:List[Place];

    public def this(solver:BAPSolver[K]) {
        super(solver);

        val gNN = new GlobalRef(new Cell[Int](0));
		at (Place(0)) {
   			val sNN = System.getenv("RPX10_N_NEIGHBORS");
			val nN:Int = sNN != null ? Int.parse(sNN) : 1;
			at (gNN.home) 
				gNN().set(nN);
		}
        val nN = Math.min(gNN().value, Place.numPlaces()-1);
x10.io.Console.OUT.println(here + ": nN: " + nN);
    	neighbors = new ArrayList[Place](nN);
        for (i in 1..nN) {
            val pid = (here.id() + (Math.ceil(Place.numPlaces()/(nN+1)) * i) as Int) % Place.numPlaces();
            neighbors(i-1) = Place(pid);
x10.io.Console.OUT.println(here + ": set neighbor: " + pid);
        }
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);
        volumeLB.set(totalVolume.get() / Place.numPlaces());
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        return false;
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        clocked finish {

            // search task
            clocked async search(sHandle);
    
            // send task
            clocked async send(sHandle);
    
            // termination
            clocked async terminate(sHandle);

        } // finish
    }

    val volumeLB:AtomicDouble = new AtomicDouble(0.);
    val volumeDelta:Double = 0.1;

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		while (initPhase) {
			Clock.advanceAll();
			Clock.advanceAll();
		}

        while (terminate != 3) {

            Clock.advanceAll();

sHandle().debugPrint(here + ": send: " + totalVolume.get() +","+ volumeLB.get());

            if (volumeLB.get() - totalVolume.get() >= volumeDelta) {
                // check and update the lb in the neighborhood.
                val v = totalVolume.get();
                for (p in neighbors) at (p) {
                    val vlb = (sHandle() as PlaceAgentClockedSI[K]).volumeLB;
                    if (v < vlb.get()) {
                        vlb.set(v + (sHandle() as PlaceAgentClockedSI[K]).volumeDelta);
sHandle().debugPrint(here + ": set lb: " + vlb.get());
                    }
                }
                volumeLB.set(v + volumeDelta);
            }

            val res = new Cell[Boolean](false);
            val lb = new Cell[Double](totalVolume.get());
            val gRes = new GlobalRef(res);
            val gLb = new GlobalRef(lb);
            while (!list.isEmpty() && totalVolume.get() - volumeLB.get() >= volumeDelta) {
                // send some work if overloaded.
                //lb.set(totalVolume.get());
                //lb.set( (Place.numPlaces()*lb.value + totalVolume.get()) / (Place.numPlaces()+1) );
                for (p in neighbors) {
                    if (list.isEmpty() || totalVolume.get() - volumeLB.get() < volumeDelta) break;
                    
                    //val p = Place(neighbors(nid));
                    val box = list.getFirst();
                    val pv:Box[K] = box.prevVar();
                    val v = lb.value;
                    res.set(false);
                    at (p) {
sHandle().debugPrint(here + ": " + v + " vs " + sHandle().totalVolume.get());
                        if (v > sHandle().totalVolume.get()) // lower than the average
                        {
                            box.setPrevVar(pv);
                            (sHandle() as PlaceAgentClocked[K]).addDomShared(box);
                            sHandle().totalVolume.addAndGet(box.volume());
                            at (gRes.home) gRes().set(true);
                        }

                        val vp = sHandle().totalVolume.get();
                        at (gLb.home) {
                            val n = (sHandle() as PlaceAgentClockedSI[K]).neighbors.size();
                            gLb().set( (n*gLb().value + vp) / (n+1) );
sHandle().debugPrint(here + ": update lb: " + gLb().value);
                        }
                    }
                    if (res.value) {
sHandle().debugPrint(here + ": box sent to:" + p + "\n" + box);
                        list.removeFirst();
                        totalVolume.addAndGet(-box.volume());
                        nSends++;
                    }
                }

                volumeLB.set(lb.value);
            }

            Clock.advanceAll();
        }
    }

    /*def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
		while (initPhase) {
			Clock.advanceAll();
			Clock.advanceAll();
		}

        while (terminate != 3) {

            Clock.advanceAll();

sHandle().debugPrint(here + ": send: " + totalVolume.get() +","+ volumeLB.get());

            if (volumeLB.get() - totalVolume.get() >= volumeDelta) {
                // check and update the lb in the neighborhood.
                val v = totalVolume.get();
                for (p in neighbors) at (p) {
                    val lb = (sHandle() as PlaceAgentClockedSI[K]).volumeLB;
                    if (v < lb.get()) {
                        lb.set(v);
sHandle().debugPrint(here + ": update lb: " + v);
                    }
                    // TODO: else update my lb value.
                }
            }

            val res = new Cell[Boolean](false);
            val lb = new Cell[Double](totalVolume.get());
            val gRes = new GlobalRef(res);
            val gLb = new GlobalRef(lb);
            while (!list.isEmpty() && totalVolume.get() - volumeLB.get() >= volumeDelta) {
                // send some work if overloaded.
                lb.set(totalVolume.get());
                for (p in neighbors) {
                    if (list.isEmpty() || totalVolume.get() - volumeLB.get() < volumeDelta) break;
                    
                    val box = list.removeFirst();
                    val pv:Box[K] = box.prevVar();
                    val v = totalVolume.get();
                    res.set(false);
                    at (p) 
                    if (v > sHandle().totalVolume.get()) 
                    {
                        box.setPrevVar(pv);
                        (sHandle() as PlaceAgentClocked[K]).addDomShared(box);
                        val vp = sHandle().totalVolume.addAndGet(box.volume());
                        at (gRes.home) {
                            gRes().set(true);
                            if (gLb().value > vp) gLb().set(vp);
                        }
                    }
                    if (res.value) {
//sHandle().debugPrint(here + ": box sent to:" + p + "\n" + box);
                        totalVolume.addAndGet(-box.volume());
                        nSends++;
                    }
                }
                volumeLB.set(Math.min(totalVolume.get(), lb.value));
            }

            Clock.advanceAll();
        }
    }*/
}

// vim: shiftwidth=4:tabstop=4:expandtab
