import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.Lock;
import x10.io.*;
import x10.io.Console;

public class PlaceAgentSeqSID[K] extends PlaceAgentSeqSI[K] {

    val weights:List[Int] = new ArrayList[Int]();

	def setLoadAvg(i:Int, la:Int) {
		lockLoads();
		loads(i+nSendsLoad) = new Box[Int](la);
		unlockLoads();
	}


    public def this(solver:BAPSolver[K]) {
        super(solver);

        /*for (0..loads.size())
            weights.add(1);

        // adds slots for the averages.
        for (loads.size()..(2*nSendsLoad-1)) {
            loads.add(-1);
            weights.add(nSendsLoad*10);
        }
        */
    }


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

        val loadAvg = la;


        la = load;
        for (i in neighbors.indices()) {
            val l = getLoad(i);
            if (l != null && l() < loadAvg)
                la -= loadAvg - l();
        }

        val loadExt = la;


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

sHandle().debugPrint(here + ": delta: " + load + " vs. " + loadAvg);

        val loadDelta = list.size() - loadAvg;

		// send boxes.
        if (loadDelta >= maxDelta)
            distributeSearchSpace(sHandle, load);

sHandle().debugPrint(here + ": balance done");
    }

/*    def distributeSearchSpace(sHandle:PlaceLocalHandle[PlaceAgent[K]], loadAvg:Int) {
        // list of lists of boxes
        val boxesList = new ArrayList[Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]]](neighbors.size()+1);

        // list of boxes to be kept local.
        val bs0 = new LinkedList[IntervalVec[K]]();
        val p0 = new Pair[Int,Cell[Int]](here.id(),new Cell[Int](-1));
        val pp0 = new Pair[List[IntervalVec[K]],Pair[Int,Cell[Int]]](bs0, p0);
        boxesList.add(pp0);

        for (i in 0..(nSendsLoad-1)) {
            val l0 = getLoad(i);
            val w0 = weights(i);
            val la = getLoad(i+nSendsLoad);
            val wa = weights(i+nSendsLoad);
            val l = (l0*w0+la*wa)/(w0+wa) * (nSendsLoad+1);
            if (l < 0) continue;

            val ld = loadAvg - l;
sHandle().debugPrint(here + ": ld: " + ld);
Console.OUT.println(here + ": ld: " + ld);
            if (ld <= 0) continue;

            // create a list of boxes.
            val bs = new LinkedList[IntervalVec[K]]();
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
                if (box.size() > 0) { // ! dummy
                    pair.first.add(box); pair.second.second() = cnt-1;
                    box.count();
                }
                else
                    addDomShared(box);
            }
            ++i;
        }

        for (pair in boxesList) {
            val boxes = pair.first;

            if (boxes.isEmpty()) continue;

            async 
			{
                val gRes = new GlobalRef(new Cell[Boolean](false));
                val p = Place(pair.second.first);
sHandle().debugPrint(here + ": sending to: " + p.id());
val hereId = here.id();

if (p.id() != here.id())
                at (p) {
                    var res:Boolean = false;
sHandle().debugPrint(here + ": sending from: " + hereId);
                    //sHandle().lockTerminate();
                    if (sHandle().tryLockTerminate() && sHandle().terminate != TokDead) {
                        (sHandle() as PlaceAgentSeq[K]).joinWithListShared(boxes);
                        //atomic sHandle().active = true;
                        res = true;

	                    sHandle().unlockTerminate();
                    }

                    val r = res;
                    at (gRes.home) { gRes().set(r); }
                }
sHandle().debugPrint(here + ": sending to " + p.id() + " done: " + gRes().value);

                if (gRes().value) { // boxes were sent to other place.
                    if (p.id() < here.id()) sentBw.set(true);
                }
                else {
                    // retract the list.
                    joinWithListShared(boxes);
                    //for (b in listShared) boxes.add(b);
                    //listShared = null;
                    //listShared = boxes;
                    //atomic {
                    //    active = true;
                    //    nSends--;
                    //}
                    nSends--;
                }
            }

            nSends++;
        }
    }
*/
}

// vim: shiftwidth=4:tabstop=4:expandtab
