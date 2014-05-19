import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSID[K] extends PlaceAgentSeqSI[K] {

    val weights:List[Int] = new ArrayList[Int]();

	def setLoadAvg(i:Int, la:Int) {
		lockLoads();
		loads(i+nSendsLoad) = la;
		unlockLoads();
	}


    public def this(solver:BAPSolver[K]) {
        super(solver);

        for (0..loads.size())
            weights.add(1);

        // adds slots for the averages.
        for (loads.size()..(2*nSendsLoad-1)) {
            loads.add(-1);
            weights.add(nSendsLoad);
        }
    }


    def balance(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": balance");

		if (Place.numPlaces() == 1) return;

        val load = list.size();


        // compute the average load.
        var la:Int = load;
        var c:Int = 1;
        for (i in neighbors.indices()) {
            val l:Int = getLoad(i);
            val w = weights(i);
sHandle().debugPrint(here + ": load: " + l);
            if (l >= 0) {
                la += l*w;
                //++c;
                c += w;
            }
        }
        la /= c;

        val loadAvg = la;


        // send load to neighborsInv.
sHandle().debugPrint(here + ": my load: " + load);
        val hereId = here.id();
        //async {
		//lockNborsInv();

        // TODO: For some reason this often results in an error.
        //for (pid in neighborsInv.get()) {
        //for (pid in neighborsInv) {
        var iMax:Int = -1;
		iMax = neighborsInv.size() - 1;
        for (i in 0..iMax) {
        // TODO: (inefficient) workaround
        //for (p in Place.places()) {
            //if (p == here) continue;
            //val p = Place(pid);
			var pid:Int = -1;
			pid = neighborsInv(i);
			if (pid < 0) continue;
            val p = Place(pid);

            at (p) async {
sHandle().lockTerminate();
if (sHandle().getTerminate() != TokDead) {
                val id = (sHandle() as PlaceAgentSeqSI[K]).neighbors.indexOf(hereId);
                if (id >= 0) {
sHandle().debugPrint(here + ": setting load " + load + " from " + hereId + " at " + id);
                    (sHandle() as PlaceAgentSeqSI[K]).setLoad(id, load);
                    (sHandle() as PlaceAgentSeqSID[K]).setLoadAvg(id, loadAvg);
                }
}
else
    sHandle().debugPrint(here + ": cannot send load");
sHandle().unlockTerminate();
   		    }
sHandle().debugPrint(here + ": inform to: " + p.id());
        }

        nReqs += neighborsInv.size();

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta)
            distributeSearchSpace(sHandle, loadAvg);

sHandle().debugPrint(here + ": balance done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
