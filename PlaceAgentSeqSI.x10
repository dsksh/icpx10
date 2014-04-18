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
    //val loads:List[Box[Int]];
    val loads:List[Int];
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
            pidBak = pid;
            pid = pid % Place.numPlaces();

            if (pid != here.id() && !neighbors.contains(pid))
                neighbors.add(pid);
        }

        //loads = new ArrayList[Box[Int]]();
        loads = new ArrayList[Int]();
        for (neighbors.indices()) 
            //loads.add(Int.MAX_VALUE/(neighbors.size()+1));
            loads.add(-1);

        neighborsInv = new ArrayList[Int]();
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
        super.setup(sHandle);

        //finish for (p in Place.places()) at (p) {
        //    async (sHandle() as PlaceAgentSeqSI[K]).prepareSend(sHandle);
        //}

        finish for (p in Place.places()) async at (p) {
            when ((sHandle() as PlaceAgentSeqSI[K]).neighbors != null) {}

            val id = here.id();
            for (pid in (sHandle() as PlaceAgentSeqSI[K]).neighbors) {
            //for (p1 in Place.places()) {
sHandle().debugPrint(here + ": neighbor: " + pid);
                //async 
                at (Place(pid)) atomic
                    (sHandle() as PlaceAgentSeqSI[K]).neighborsInv.add(id);
            }
        }
    }

    /*def prepareSend(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        val id = here.id();
        finish for (pid in neighbors) {
debugPrint(here + ": neighbor: " + pid);
            async 
            at (Place(pid)) atomic {
                (sHandle() as PlaceAgentSeqSI[K]).neighborsInv.add(id);
            }
        }
    }*/

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        //prepareSend(sHandle);

tEndPP = -System.nanoTime();

        finish {
        //async terminate(sHandle);

        while (terminate != 3) {
finish {
            if (preprocessor == null || !preprocessor.process(sHandle)) {

			    send(sHandle);

                if (here.id() == 0) 
                    atomic if ((list.size()+listShared.size()) == 0 && terminate == 0 ) {
    
                        // force search to activate termination
//debugPrint(here + ": start termination");
                        //atomic terminate = 1;
                        listShared.add(sHandle().solver.core.dummyBox());
                    }
    
   			    search(sHandle);
            }

            if (here.id() == 0)
                atomic if ((list.size()+listShared.size()) == 0 && terminate == 0 ) {
debugPrint(here + ": start termination");
                    terminate = 1;
    		    }
}
			
			terminate(sHandle);
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

    var loadBak:Int = -1;

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": send");

		if (Place.numPlaces() == 1) return;

        /*// not the initial path and not possessing many boxes.
		if (!initPhase && list.size() <= maxDelta) {
sHandle().debugPrint(here + ": quit send: " + terminate);
            return;
        }*/

        val load = list.size();

        //if (loadBak < 0 || Math.abs(load - loadBak) > maxDelta) {
            loadBak = load;
    
            // send load to neighborsInv.
sHandle().debugPrint(here + ": my load: " + load);
            val hereId = here.id();
            //async
            // TODO: I don't know why but this often results in an error.
            //for (pid in neighborsInv) {
            // TODO: (inefficient) workaround
            for (p in Place.places()) {
                if (p == here) continue;
        		async 
                //at (Place(pid)) {
                at (p) {
if (sHandle().terminate != 3) {
                    val id = (sHandle() as PlaceAgentSeqSI[K]).neighbors.indexOf(hereId);
                    if (id >= 0) {
sHandle().debugPrint(here + ": setting load " + load + " from " + hereId + " at " + id);
                        atomic (sHandle() as PlaceAgentSeqSI[K]).loads(id) = load;
                    }
}
else
    sHandle().debugPrint(here + ": cannot send load");
       		    }
//sHandle().debugPrint(here + ": inform to: " + pid);
sHandle().debugPrint(here + ": inform to: " + p.id());
            }        

            nReqs += neighborsInv.size();
        //}

        // compute the average load.
        var loadAvg:Int = load;
        //atomic {
            var c:Int = 1;
            for (i in neighbors.indices()) {
                var l:Int = -1;
                atomic l = loads(i);
sHandle().debugPrint(here + ": load: " + l);
                //if (l != null) {
                if (l >= 0) {
                    loadAvg += l;
                    ++c;
                }
            }
            loadAvg /= c;
        //}

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		/*// send boxes.
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
		}*/

		// send boxes.
        if (loadDelta >= maxDelta) {
            // list of lists of boxes
            val boxesList = new ArrayList[Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]]]();
            // list of boxes to be kept local.
            val bs0 = new ArrayList[IntervalVec[K]]();
            val p0 = new Pair[Int,Cell[Int]](here.id(),new Cell[Int](-1));
            val pp0 = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs0, p0);
            boxesList.add(pp0);
            for (i in neighbors.indices()) atomic {
                //var l:Box[Int] = null;
                var l:Int = -1;
                atomic l = loads(i);
                //if (l == null) continue;
                if (l < 0) continue;

                val ld = loadAvg - l;
sHandle().debugPrint(here + ": ld: " + ld);
                if (ld <= 0) continue;

                // create a list of boxes.
                val bs = new ArrayList[IntervalVec[K]]();
                val p = new Pair[Int,Cell[Int]](neighbors(i), new Cell[Int](ld));
                val pp = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs, p);
                boxesList.add(pp);
            }

            // distribute the content of the list
            var i:Int = 0;
            while (!list.isEmpty()) {
                val j = i % boxesList.size();
                val pair = boxesList(j);
                val cnt = pair.second.second();
                if ((j == 0 && cnt < 0) || cnt > 0) {
                    val box:IntervalVec[K] = list.removeLast();
                    if (box.size() > 0) { // dummy
                        pair.first.add(box); pair.second.second() = cnt-1;
                        box.count();
                    }
                    else
                        atomic listShared.add(box);
                }
                ++i;
            }

            for (pair in boxesList) {
                val boxes = pair.first;

                if (boxes.isEmpty()) continue;

                //async {
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
                        atomic nSends++;
                    }
                    else atomic {
                        // retract the list.
                        for (b in listShared) boxes.add(b);
                        listShared = null;
                        listShared = boxes;
                    }
                //}
            }
		}

sHandle().debugPrint(here + ": send done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
