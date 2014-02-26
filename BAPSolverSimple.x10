//import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPSolverSimple[K] extends BAPSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    var list:List[IntervalVec[K]] = null;

    public def setList(list:List[IntervalVec[K]]) {
        this.list = list;
    }

    protected def returnDom(box:IntervalVec[K]) {
        // add last.
		atomic list.add(box);
    }
    protected def sortDom() {
        finish list.sort(
            (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                b2.volume().compareTo(b1.volume()) );
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        // for dummy boxes
        if (box.size() == 0)
            return;

        if (list == null) list = sHandle().list;

val vol0 = box.volume();
        val res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val bp = box.split(v()); 
                //sHandle().nSplits.getAndIncrement();
                sHandle().nSplits++;
val vol = box.volume();
sHandle().totalVolume.addAndGet(-vol0+vol);

                if (sHandle().respondIfRequested(sHandle, bp.first))
                    sHandle().totalVolume.addAndGet(-vol/2);
                else
                    returnDom(bp.first);

                returnDom(bp.second);
            }
            else {
sHandle().totalVolume.addAndGet(-vol0);
                sHandle().addSolution(res, box);
            }
        }
        else 
sHandle().totalVolume.addAndGet(-vol0);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
