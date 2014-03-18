import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class PlaceAgentSeqSI[K] extends PlaceAgentSeq[K] {

    public def this(solver:BAPSolver[K]) {
        super(solver);
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
    val maxDelta = 10;
    val nDist = 2;

    def send(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        var loadAvg:Int = list.size();
        atomic {
            for (l in loadsNbor) 
                loadAvg += l;
            loadAvg /= (loadsNbor.size()+1);
            loadsNbor.clear();
        }

sHandle().debugPrint(here + ": delta: " + list.size() + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;
        finish for (2..nDist) {
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
                val load = list.size();
                async at (selectPlace())
                    atomic (sHandle() as PlaceAgentSeqSI[K]).loadsNbor.add(load);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
