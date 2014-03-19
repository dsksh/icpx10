import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    val maxDelta:Int;
    val nSendIters:Int;

    public def this(solver:BAPSolver[K]) {
        super(solver);

        // read env variables.
		val gMD = new GlobalRef(new Cell[Int](0));
		val gNS = new GlobalRef(new Cell[Int](0));
		at (Place(0)) {
   			val sMD = System.getenv("RPX10_MAX_DELTA");
   			val sNS = System.getenv("RPX10_N_SENDS");
			val nMD:Int = sMD != null ? Int.parse(sMD) : 10;
			val nNS:Int = sNS != null ? Int.parse(sNS) : 2;
			at (gMD.home) {
				gMD().set(nMD);
				gNS().set(nNS);
            }
		}
    	maxDelta = gMD().value;
    	nSendIters = gNS().value;
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

    protected def selectPlace() : Place {
        var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);
    }

    val loadsNbor:List[Int] = new ArrayList[Int]();

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        // compute the average load
        var loadAvg:Int = list.size();
        atomic {
            for (l in loadsNbor) 
                loadAvg += l;
            loadAvg /= (loadsNbor.size()+1);
            loadsNbor.clear();
        }

sHandle().debugPrint(here + ": delta: " + list.size() + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;
        finish for (i in 2..Math.max(loadDelta, nSendIters)) {
            if (loadDelta >= maxDelta) {
                val box = list.removeFirst();
                val pv:Box[K] = box.prevVar();
                val load = list.size();
                async at (selectPlace()) {
                    atomic (sHandle() as PlaceAgentSeqSI[K]).loadsNbor.add(load);
    
                    box.setPrevVar(pv);
                    (sHandle() as PlaceAgentSeq[K]).addDomShared(box);
                }
                nSends++;
            }
            else {
                if (i > Place.numPlaces()) break;

                //val load = list.size();
                val load = loadAvg;
                async at (selectPlace())
                    atomic (sHandle() as PlaceAgentSeqSI[K]).loadsNbor.add(load);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
