import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSID[K] extends PlaceAgentSeqSI[K] {

    public def this(solver:BAPSolver[K]) {
        super(solver);

        for (0..4) loadsBak.add(0);
    }

    var loadBak:Int = Int.MAX_VALUE;
    var deltaBak:Int = 0;
    var loadRatioBak:Double = 1.;

    var loadsBak:List[Int] = new ArrayList[Int](5);
    var lbPos:Int = 0;
    def pushLB(lb:Int) { 
        loadsBak(lbPos) = lb; 
        lbPos = lbPos < (loadsBak.size()-1) ? lbPos+1 : 0;
    }
    def getLBAvg() {
        var sum:Int = 0;
        for (lb in loadsBak) sum += lb;
        return sum/loadsBak.size();
    }

    var deltaC:Int = 0;

    def balance(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
sHandle().debugPrint(here + ": balance");

		if (Place.numPlaces() == 1) return;

        val load = list.size()+listShared.size();


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

        //val loadAvg = Math.max(la, 0);
        val loadAvg = la;


        la = load;
        // estimate the required sends.
        if (load < loadAvg)
            for (i in neighbors.indices()) {
                val l = getLoad(i);
                if (l != null && l() < loadAvg)
                    la -= loadAvg - l();
            }
        val loadDim = la;

        deltaC = Math.max(loadAvg, 0);
        //val deltaC = 10;

if (Math.abs(loadDim - loadBak) >= deltaLoad + deltaRelLoad * deltaC) {
loadBak = loadDim;

        // send load to neighborsInv.
sHandle().debugPrint(here + ": load: " + load + ", avg: " + loadAvg + ", dim: " + loadDim);
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
                    (sHandle() as PlaceAgentSeqSI[K]).setLoad(id, loadDim);
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
//else
//    Console.OUT.println(here + ": skipped");
pushLB(loadDim);


sHandle().debugPrint(here + ": load: " + load + " vs. " + loadAvg);

        var deltaC_:Double = deltaC;
        if (load != 0) {
            deltaC_ *= loadAvg;
            deltaC_ /= load;
        }

        val delta = load - loadAvg;

        val deltaRB2:Double = load == 0 ? 0. : deltaRelBox2 * (deltaC/load);

		// send boxes.
//Console.OUT.println(here + ": avg: " + loadAvg + ",\tdelta: " + delta);
        //if (delta >= deltaBox + deltaRelBox1 * deltaC + deltaRB2) {
        if (delta >= deltaBox + deltaRelBox1 * deltaC_) {
            distributeSearchSpace(sHandle, load);
        }
//else
//    Console.OUT.println(here + ": skipped");

/*        //if (deltaBak != 0) {
            //var loadRatio:Double = load as Double;
            //loadRatio /= loadAvg;
if (deltaBak != 0)
Console.OUT.println(here + ": ratio: " + (delta / deltaBak));
            if (delta > 0 && deltaBak > 0 && delta / deltaBak > 2. &&
                nSearchSteps.get() > 10.)

                nSearchSteps.set(10.);
            else if (delta < 0 && deltaBak < 0 &&
                //delta / deltaBak < 0.8 && 
                nSearchSteps.get() < 1000.)

                nSearchSteps.set(1000.);
            else
                nSearchSteps.set(100.);

            //loadRatioBak = loadRatio;
        //}
Console.OUT.println(here + ": nSS: " + nSearchSteps.get());

        deltaBak = delta;
*/

        if (accelThres > 0 && loadAvg > accelThres)
            nSearchSteps.set(nSearchSteps0 * 10);

sHandle().debugPrint(here + ": balance done");
    }

val tLogStart:Long = System.nanoTime();
var tLogNext:Double = 0.;
val logData:List[Pair[Int,Int]] = new ArrayList[Pair[Int,Int]]();
var nSBBak:Int = 0;

    def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

if (tEndPP < 0l) tEndPP += System.nanoTime();

debugPrint(here + ": wait");
        when (active || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + active + ", " + list.size()+","+listShared.size());
            active = false;
        }

        //waitActivation();

        joinTwoLists();

        val tSearchStart = System.nanoTime();

    	finish 
    	while (RPX10.format(System.nanoTime() - tSearchStart) < tSearchInterval) {
    		if (!searchBody(sHandle))
    			break;

val t = System.nanoTime();
while (RPX10.format(t - tLogStart) >= tLogNext) {
    tLogNext += 1.; // FIXME
    //Console.OUT.println(here + ": time: " + RPX10.format(t - tLogStart) +  ", load: " + list.size());
    logData.add(new Pair(list.size()+listShared.size(), nSentBoxes - nSBBak));
    nSBBak = nSentBoxes;
} 
        }
debugPrint(here + ": done search");
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
