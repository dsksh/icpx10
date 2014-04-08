import x10.compiler.*;
import x10.util.*;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    val sizeNbors:Int = 5; // FIXME
    val maxDelta:Int;
    var nSendsBox:Double;
    val minNSendsBox:Double;

    val neighbors:List[Int];
    val loads:List[Box[Int]];
    val neighborsInv:List[Int];

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

        neighbors = new ArrayList[Int]();

        /*var pow:Int = 1;
        for (1..nSendsLoad) {
            val pid = (here.id() + pow) % Place.numPlaces();
            pow *= 2;
            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }*/

        val num = 1./(nSendsLoad as Double);
        var pidBak:Int = -1;
        for (i in 0..(nSendsLoad-1)) {
            var pid:Int = here.id() + (Math.floor(Math.pow((Place.numPlaces() as Double), i*num)) as Int);
            if (pid <= pidBak) pid = pidBak+1;
            pid = pid % Place.numPlaces();
            pidBak = pid;
Console.OUT.println(here + ": nid: " + pid);

            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }

        loads = new ArrayList[Box[Int]]();
        for (neighbors.indices()) 
            //loads.add(Int.MAX_VALUE/(neighbors.size()+1));
            loads.add(null);

        neighborsInv = new ArrayList[Int]();
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);

        finish for (p in Place.places()) at (p) {
            async (sHandle() as PlaceAgentSeqSI[K]).prepareSend(sHandle);
        }
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        //prepareSend(sHandle);

tEndPP = -System.nanoTime();

        finish
        while (terminate != 3 || list.size()+listShared.size() > 0) {
finish {
			send(sHandle);

            if (here.id() == 0 &&
                (list.size()+listShared.size()) == 0 && terminate == 0 ) {

                // skip search and activate termination
debugPrint(here + ": start termination");
                atomic terminate = 1;
            }
            else
      			search(sHandle);
}
			
			terminate(sHandle);
        }
	}

    def prepareSend(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        val id = here.id();
        finish for (pid in neighbors) {
debugPrint(here + ": neighbor: " + pid);
            async 
            at (Place(pid)) atomic {
                (sHandle() as PlaceAgentSeqSI[K]).neighborsInv.add(id);
            }
        }
    }

    private var selectedPid:Int = 0;

    /*protected def selectPlace() : Place {
        //val id:Int = random.nextInt(Place.numPlaces());
        //return Place(id);

        if (selectedPid == neighbors.size()) selectedPid = 0;
        return Place( neighbors(selectedPid++) );
    }*/

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": send");

		if (Place.numPlaces() == 1) return;

        // not the initial path and not possessing many boxes.
		if (!initPhase && list.size() <= maxDelta) {
sHandle().debugPrint(here + ": quit send: " + terminate);
            return;
        }

        // send load to neighborsInv.
        val load = list.size();
sHandle().debugPrint(here + ": load: " + load);
        val hereId = here.id();
        for (pid in neighborsInv) {
    		async 
            at (Place(pid)) {
if (sHandle().terminate != 3) {
                val id = (sHandle() as PlaceAgentSeqSI[K]).neighbors.indexOf(hereId);
                atomic (sHandle() as PlaceAgentSeqSI[K]).loads(id) = new Box[Int](load);
}
else
    sHandle().debugPrint(here + ": cannot send load");
    		}
sHandle().debugPrint(here + ": inform to: " + pid);

            nReqs++;
        }        

        // compute the average load.
        var loadAvg:Int = load;
        //atomic {
            var c:Int = 1;
            for (i in loads.indices()) {
                val l = loads(i);
sHandle().debugPrint(here + ": load: " + l);
                if (l != null) {
                    loadAvg += l();
                    ++c;
                }
            }
            loadAvg /= c;
        //}

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta) {
            for (i in neighbors.indices()) {
                var l:Int = -1;
                //atomic 
                if (loads(i) != null) l = loads(i)();
                if (l < 0) continue;

                val ld = loadAvg - l;
sHandle().debugPrint(here + ": ld: " + ld);
                if (ld <= 0) continue;

                // create a list of boxes.
                val boxes = new ArrayList[IntervalVec[K]]();
                for (1..ld) {
                    var box:IntervalVec[K] = null;
                    while (true) { // skip the dummy boxes
                        if (list.isEmpty()) break;
                        box = list.removeFirst();
                        if (box.size() == 0)
                            listShared.add(box);
                        else
                            break;
                    }
                    if (box != null) {
                        boxes.add(box);
                        box.count();
                    }
                }

                if (boxes.isEmpty()) break;

                async {
                    val gRes = new GlobalRef(new Cell[Boolean](false));
                    at (Place(neighbors(i))) {
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
    
                    if (gRes().value) { // boxes were sent.
                        if (neighbors(i) < here.id()) sentBw.set(true);
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
