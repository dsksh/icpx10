import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPListSolver[K] extends BAPSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);

        list = new ArrayList[IntervalVec[K]]();
    }

    // auxiliary list
    // TODO: ArrayList might be slow.
    private val list:List[IntervalVec[K]];
    protected atomic def clearDom() {
        list.clear();
    }
    protected atomic def addDom(box:IntervalVec[K]) {
        // add last.
        list.add(box);
    }
    protected atomic def removeDom() : IntervalVec[K] {
        return list.removeFirst();
//        return list.removeLast();
    }
    protected atomic def hasDom() : Boolean {
        return !list.isEmpty();
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        // for dummy boxes
        if (box.size() == 0)
            return;

        addDom(box);

        while (hasDom())
            finish while (hasDom()) {
                val dom = removeDom();
                async searchBody(sHandle, dom);
            }
    }

    protected def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
        val res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val bp = box.split(v()); 
                sHandle().nSplits.getAndIncrement();
                if (!sHandle().respondIfRequested(sHandle, bp.first))
                    addDom(bp.first);
                addDom(bp.second);
            }
            else {
                sHandle().addSolution(res, box);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
