import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    val sizeNbors:Int = 5; // FIXME
    val maxDelta:Int;
    var nSendsBox:Double;
    val minNSendsBox:Double;
    val nSendsLoad:Int;

    val neighbors:List[Int];

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
    	nSendsLoad = gNSL().value;

        neighbors = new ArrayList[Int]();
        var pow:Int = 1;
        for (1..nSendsLoad) {
            neighbors.add((here.id() + pow) % Place.numPlaces());
            pow *= 2;
        }
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

tEndPP = -System.nanoTime();

        finish
        while (terminate != 3) {

			search(sHandle);
			
			send(sHandle);

			terminate(sHandle);
        }
	}

    private var selectedPid:Int = 0;

    protected def selectPlace() : Place {
        //val id:Int = random.nextInt(Place.numPlaces());
        //return Place(id);

        if (selectedPid == neighbors.size()) selectedPid = 0;
        return Place( neighbors(selectedPid++) );
    }

    val loadsNbor:List[Int] = new ArrayList[Int]();
    var loadDeltaBak:Int = 0;

    def send1(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

		if (Place.numPlaces() == 1) return;

		// send the self load to other places (and this place).
        //finish for (1..Math.min(Place.numPlaces()-1, nSendsLoad)) {
        finish for (1..nSendsLoad) {
            val load = list.size();
            val p = selectPlace();
            async at (p) {
                atomic (sHandle() as PlaceAgentSeqSI[K]).loadsNbor.add(load);
			}
sHandle().debugPrint(here + ": sent load to: " + p);
        }

        // compute the average load.
        var loadAvg:Int = list.size();
        atomic {
sHandle().debugPrint(here + ": sizeNbors: " + loadsNbor.size());
            // loads information is not enough.
            if (loadsNbor.size() < Math.min(Place.numPlaces(), sizeNbors))
                return;

            for (l in loadsNbor) 
                loadAvg += l;
            loadAvg /= (loadsNbor.size()+1);
            loadsNbor.clear();
        }

sHandle().debugPrint(here + ": delta: " + list.size() + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

        if (loadDelta >= maxDelta) {
			// adjust the nSendsBox.
	        if (loadDeltaBak >= maxDelta) {
				//if (loadDelta < loadDeltaBak)
		            nSendsBox *= minNSendsBox;
				//else
		        //    nSendsBox /= 2.;
			}
			else
				nSendsBox = minNSendsBox;

            if (nSendsBox > loadDelta) nSendsBox = loadDelta;

sHandle().debugPrint(here + ": nSendsBox: " + nSendsBox);

			// send boxes.
            finish for (i in 1..(nSendsBox as Int)) {
                if (list.isEmpty()) break;
    
                val box = list.removeFirst();
                val pv:Box[K] = box.prevVar();
                val p = selectPlace();
                async at (p) {
                    box.setPrevVar(pv);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(box);
                }
                if (p != here) nSends++;
            }
		}
		else
			nSendsBox = minNSendsBox;

        loadDeltaBak = loadDelta;
    }

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

		if (Place.numPlaces() == 1) return;

        // compute the average load.
        var loadAvg:Int = list.size();
        finish for (pid in neighbors) {
    		val gL = new GlobalRef(new Cell[Int](0));
    		async at (Place(pid)) {
                val load = sHandle().list.size();
    			at (gL.home) gL().set(load);
    		}
        	loadAvg += gL().value;
        }        
        loadAvg /= (neighbors.size()+1);

sHandle().debugPrint(here + ": delta: " + list.size() + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

        if (loadDelta >= maxDelta) {
			// adjust the nSendsBox.
	        if (loadDeltaBak >= maxDelta) {
				//if (loadDelta < loadDeltaBak)
		            nSendsBox *= minNSendsBox;
				//else
		        //    nSendsBox /= 2.;
			}
			else
				nSendsBox = minNSendsBox;

            if (nSendsBox > loadDelta) nSendsBox = loadDelta;

sHandle().debugPrint(here + ": nSendsBox: " + nSendsBox);

			// send boxes.
            finish for (i in 1..(nSendsBox as Int)) {
                if (list.isEmpty()) break;
    
                val box = list.removeFirst();
                val pv:Box[K] = box.prevVar();
                val p = selectPlace();
                async at (p) {
                    box.setPrevVar(pv);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(box);
                }
                if (p != here) nSends++;
            }
		}
		else
			nSendsBox = minNSendsBox;

        loadDeltaBak = loadDelta;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
