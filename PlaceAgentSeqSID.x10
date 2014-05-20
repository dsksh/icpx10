import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSID[K] extends PlaceAgentSeqSI[K] {

    public def this(solver:BAPSolver[K]) {
        super(solver);
    }

    var loadBak:Int = Int.MAX_VALUE;
    var loadDeltaBak:Int = 0;
    var loadRatioBak:Double = 1.;

    def balance(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": balance");

		if (Place.numPlaces() == 1) return;

        val load = list.size();


        // compute the average load.
        var la:Int = load;
        var c:Int = 1;
        for (i in neighbors.indices()) {
            val l = getLoad(i);
            //val w = weights(i);
sHandle().debugPrint(here + ": load: " + l);
            if (l != null) {
                la += l();
                ++c;
                //c += w;
            }
        }
        la /= c;

        val loadAvg = Math.max(la, 0);


        // estimate the required sends.
        la = load;
        for (i in neighbors.indices()) {
            val l = getLoad(i);
            if (l != null && l() < loadAvg)
                la -= loadAvg - l();
        }

        val loadExt = la;

        var deltaC:Double = loadAvg /10.;
        //val deltaC = 10;
        if (load != 0) {
            deltaC *= loadAvg;
            deltaC /= load;
        }

if (Math.abs(loadExt - loadBak) > maxDelta * deltaC) {

        // send load to neighborsInv.
sHandle().debugPrint(here + ": load: " + load + ", avg: " + loadAvg + ", ext: " + loadExt);
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
                    (sHandle() as PlaceAgentSeqSI[K]).setLoad(id, loadExt);
                    //(sHandle() as PlaceAgentSeqSID[K]).setLoadAvg(id, loadAvg);
                }
}
else
    sHandle().debugPrint(here + ": cannot send load");
sHandle().unlockTerminate();
   		    }
sHandle().debugPrint(here + ": inform to: " + p.id());
        }

        nReqs += neighborsInv.size();

}


sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta * deltaC) {
            distributeSearchSpace(sHandle, load);
        }

/*        //if (loadDeltaBak != 0) {
            //var loadRatio:Double = load as Double;
            //loadRatio /= loadAvg;
if (loadDeltaBak != 0)
Console.OUT.println(here + ": ratio: " + (loadDelta / loadDeltaBak));
            if (loadDelta > 0 && loadDeltaBak > 0 && loadDelta / loadDeltaBak > 2. &&
                nSearchSteps.get() > 10.)

                nSearchSteps.set(10.);
            else if (loadDelta < 0 && loadDeltaBak < 0 &&
                //loadDelta / loadDeltaBak < 0.8 && 
                nSearchSteps.get() < 1000.)

                nSearchSteps.set(1000.);
            else
                nSearchSteps.set(100.);

            //loadRatioBak = loadRatio;
        //}
Console.OUT.println(here + ": nSS: " + nSearchSteps.get());


        loadBak = loadExt;
        loadDeltaBak = loadDelta;
*/

sHandle().debugPrint(here + ": balance done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
