import x10.io.*;
import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

public class ClusterSolver[K] extends Solver[K] {
    private random:Random;

    static val frontierN = 4;

    public def this(core:Core[K], selector:(Result,IntervalVec[K])=>Box[K]) {
        super(core, selector);
        //reqQueue = new CircularQueue[Int](2*Place.numPlaces()+10);
        random = new Random(System.nanoTime());
        initPhase = here.id() == 0;
    }

    public def setup(sHandle:PlaceLocalHandle[Solver[K]]) {
        addDom(Result.unknown(), core.getInitialDomain());

        var dst:Int = 0;
        var pow2:Int = 1;
        for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) sHandle().reqQueue.addLast(pi);
            //at (Place(pi)) sHandle().sentRequest.set(true);
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }

/*        while (list1.size() < frontierN) {
            if (list1.isEmpty()) break;
            val pair = removeFirstDom();
            finish search(sHandle, pair.first, pair.second);
        }

        val nB = list1.size();
        var p:Place = here;
        for (i in 1..nB) {
            val pair = removeFirstDom();
            at (p) sHandle().addDom(pair.first, pair.second);
            p = p.next();
        }
*/
    }

    protected def contractBox(box:IntervalVec[K]) {
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }
        nContracts.getAndIncrement();

        if (!res.hasNoSolution()) addDom(res, box);
        //else Console.OUT.println(here + ": no solution");
    }

    protected def search(sHandle:PlaceLocalHandle[Solver[K]], res:Result, box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        //val pv:Box[K] = box.prevVar();
        val v = selectVariable(res, box);
        if (v != null) {
            val bp = box.split(v()); 
            nSplits.getAndIncrement();
                
            contractBox(bp.first);
            contractBox(bp.second);
        }
        else {
            atomic solutions.add(new Pair[Result,IntervalVec[K]](res, box));
            /*Console.OUT.println(here + ": solution:");
            val plot = res.entails(Solver.Result.inner()) ? 5 : 3;
            atomic { 
                Console.OUT.println(box.toString(plot));
                Console.OUT.println(); 
            }
            */
            nSols.getAndIncrement();
        }
    }    

    var selected:Iterator[Place] = null;
    protected def selectPlace() : Place {
        var id:Int;
        do {
            id = random.nextInt(Place.numPlaces());
        } while (Place.numPlaces() > 1 && (id == here.id()));

        return Place(id);

/*        if (selected == null || !selected.hasNext())
            selected = Place.places().iterator();
        val p = selected.next();
        if (p != here) {
//Console.OUT.println(here + ": selected " + p);
            return p;
        }
        else
            return selectPlace();
*/
    }

    protected atomic def getAndResetTerminate() : Int {
        val t = terminate;
        terminate = 0;
        return t;
    }

    public def solve(sHandle:PlaceLocalHandle[Solver[K]]) {
   		Console.OUT.println(here + ": start solving... ");

        while (true) 
        //if (!list1.isEmpty()) {
        if (initPhase) {
            while (reqQueue.getSize() > 0) {
                val pi = reqQueue.removeFirstUnsafe();

                while (list1.size() < frontierN) {
                    if (list1.isEmpty()) break;
                    val pair = removeLastDom();
                    finish search(sHandle, pair.first, pair.second);
                }
        
                val nB = list1.size();
                var b:Boolean = true;
                for (i in 1..nB) {
                    val pair = removeLastDom();
                    at (b ? here : Place(pi)) sHandle().addDom(pair.first, pair.second);
//Console.OUT.println(here + ": append at " + (b ? 0 : pi));
                    b = !b;
                }
                at (Place(pi)) atomic sHandle().initPhase = true;
            }
            break;
        }
        else when (initPhase) { }

        while (true) {
            finish while (!list1.isEmpty()) {
                val pair = removeLastDom();
                async search(sHandle, pair.first, pair.second);
            }

            if (list1.isEmpty()) break;
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
