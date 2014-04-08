import x10.compiler.*;
import x10.util.*;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSI1[K] extends PlaceAgentSeq[K] {

    val sizeNbors:Int = 5; // FIXME
    val maxDelta:Int;
    var nSendsBox:Double;
    val minNSendsBox:Double;

    //val neighbors:List[Int];
    //val neighborsInv:List[Int];
    val loads:List[Box[Pair[Int,Int]]];

    var load:Box[Int] = null;

    public def this(solver:BAPSolver[K]) {
        super(solver);

        // read env variables.
		val gMD = new GlobalRef(new Cell[Int](0));
		val gNSB = new GlobalRef(new Cell[Double](0.));
		val gNSL = new GlobalRef(new Cell[Int](0));
		at (Place(0)) {
   			val sMD = System.getenv("RPX10_MAX_DELTA");
   			val sNSB = System.getenv("RPX10_N_SENDS_BOX");
   			val sNSL = System.getenv("RPX10_N_SENDS_LOAD");
			val nMD:Int = sMD != null ? Int.parse(sMD) : 10;
			val nNSB:Double = sNSB != null ? Double.parse(sNSB) : 2.;
			val nNSL:Int    = sNSL != null ? Int.parse(sNSL) : 2;
			at (gMD.home) {
				gMD().set(nMD);
				gNSB().set(nNSB);
				gNSL().set(nNSL);
            }
		}
    	maxDelta = gMD().value;
    	nSendsBox = gNSB().value;
    	minNSendsBox = gNSB().value;
    	val nSendsLoad = gNSL().value;

        /*neighbors = new ArrayList[Int]();
        var pow:Int = 1;
        for (1..nSendsLoad) {
            val pid = (here.id() + pow) % Place.numPlaces();
            pow *= 2;
            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }*/

        //neighborsInv = new ArrayList[Int]();

        loads = new ArrayList[Box[Pair[Int,Int]]]();
        for (1..nSendsLoad) loads.add(null);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);

        //finish for (p in Place.places()) at (p) {
        //    async (sHandle() as PlaceAgentSeqSI[K]).prepareSend(sHandle);
        //}
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish
        while (terminate != 3 || list.size()+listShared.size() > 0) {
finish {
            atomic this.load = new Box(list.size());

            // look at the load of each neighbor.
            val hereId = here.id();
            for (1..loads.size()) async {
                val gL = new GlobalRef(new Cell[Int](-1));
                val pl = selectPlace();
        		at (pl) {
if (sHandle().terminate != 3) {
                    var load:Int = -1;
                    //atomic {
                        val l = (sHandle() as PlaceAgentSeqSI1[K]).load;
                        if (l != null)
                            load = l();
                    //}
                    if (load >= 0) {
                        val l1 = load;
                        at (gL.home) gL().set(l1);
                    }
}
                }
                if (gL().value >= 0) atomic {
sHandle().debugPrint(here + ": load " + gL().value + " at " + pl.id());
                    loads.add(new Box(new Pair[Int,Int](pl.id(), gL().value)));
                    loads.removeFirst();
                }

                nReqs++;
            }

			send(sHandle);

            if (here.id() == 0) {
                atomic if ((list.size()+listShared.size()) == 0 && terminate == 0) {
                    // skip search and activate termination
                    initPhase = true;
                }
		    }

			search(sHandle);
}
			
			terminate(sHandle);
        }
	}

    /*def prepareSend(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        val id = here.id();
        finish for (pid in neighbors) {
debugPrint(here + ": neighbor: " + pid);
            async at (Place(pid)) atomic {
                (sHandle() as PlaceAgentSeqSI[K]).neighborsInv.add(id);
            }
        }
    }*/

    private var selectedPid:Int = 0;

    protected def selectPlace() : Place {
        var id:Int = -1;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (id == here.id());
        return Place(id);

        //if (selectedPid == neighbors.size()) selectedPid = 0;
        //return Place( neighbors(selectedPid++) );
    }

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": send");

		if (Place.numPlaces() == 1) return;

        // not the initial path and not possessing many boxes.
		if (!initPhase && list.size() <= maxDelta) {
sHandle().debugPrint(here + ": quit send");
            return;
        }

        val load = list.size();

        /*// send load to neighbors.
sHandle().debugPrint(here + ": load: " + load);
        val hereId = here.id();
        for (loads.indices()) {
            val pl = selectPlace();
    		async at (pl) {
if (sHandle().terminate != 3) {
                atomic {
                    val loads = (sHandle() as PlaceAgentSeqSI1[K]).loads;
                    loads.add(new Box(new Pair[Int,Int](hereId, load)));
                    loads.removeFirst();
                }
}
else
    sHandle().debugPrint(here + ": cannot send load");
    		}
sHandle().debugPrint(here + ": inform to: " + pl.id());

            nReqs++;
        }
        */

        // compute the average load.
        var loadAvg:Int = load;
//atomic {
            var cnt:Int = 1;
            for (i in 0..(loads.size()-1)){
                val pair = loads(i);
                if (pair != null) {
sHandle().debugPrint(here + ": load: " + pair().second);
                    loadAvg += pair().second;
                    ++cnt;
                }
            }
sHandle().debugPrint(here + ": loadAvg: " + loadAvg);
            loadAvg /= cnt;
//}

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = load - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta) {
            // list of lists of boxes
            val boxesList = new ArrayList[Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]]]();
            // list of boxes to be kept here.
            val l0 = new ArrayList[IntervalVec[K]]();
            val p0 = new Pair[Int,Cell[Int]](here.id(),new Cell[Int](-1));
            val pp0 = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](l0, p0);
            boxesList.add(pp0);
atomic 
            for (pair in loads) {
                if (pair == null) continue;

                val ld = loadAvg - pair().second;
sHandle().debugPrint(here + ": ld: " + ld);
                if (ld <= 0) continue;

                // create a list of boxes.
                val l = new ArrayList[IntervalVec[K]]();
                val p = new Pair[Int,Cell[Int]](pair().first, new Cell[Int](ld));
                val pp = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](l, p);
                boxesList.add(pp);
            }

            // distribute the content of the list
            var i:Int = 0;
            while (!list.isEmpty()) {
                val j = i % boxesList.size();
                val pair = boxesList(j);
                val c = pair.second.second();
                if ((j == 0 && c < 0) || c > 0) {
                    val box:IntervalVec[K] = list.removeLast();
                    pair.first.add(box); pair.second.second() = c-1;
                    box.count();
                }
                ++i;
            }

            for (pair in boxesList) {
                val boxes = pair.first;

                if (boxes.isEmpty()) continue;

                async {
                    val gRes = new GlobalRef(new Cell[Boolean](false));
                    val pid = pair.second.first;
sHandle().debugPrint(here + ": sending to: " + pid);
                    at (Place(pid)) {
                        var res:Boolean = false;
                        atomic if (sHandle().terminate != 3) {
                            val ls = (sHandle() as PlaceAgentSeq[K]).listShared;
                            for (b in ls) boxes.add(b);
                            (sHandle() as PlaceAgentSeq[K]).listShared = null;
                            (sHandle() as PlaceAgentSeq[K]).listShared = boxes;
                            res = true;
                        }
                        val r = res;
                        at (gRes.home) { gRes().set(r); }
                    }
sHandle().debugPrint(here + ": sending done: " + gRes().value);
    
                    if (gRes().value) { // boxes were sent.
                        if (pid < here.id()) sentBw.set(true);
                        nSends++;
                    }
                    else atomic {
                        // retract the list.
                        for (b in listShared) boxes.add(b);
                        listShared = null;
                        listShared = boxes;
                    }
                }
            }
		}

sHandle().debugPrint(here + ": send done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
