import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPListSolverBnd[K] extends BAPListSolver[K] {

    public var maxDomSize : Int = 0;

    private list1 : List[IntervalVec[K]];

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K],
                    list1:List[IntervalVec[K]]) {
        super(core, selector);
        this.list1 = list1;
    }

    protected atomic def clearDom() {
        list1.clear();
    }
    public atomic def addDom(box:IntervalVec[K]) {
        // add last.
        list1.add(box);
    }
    public atomic def removeDom() : IntervalVec[K] {
        return list1.removeFirst();
    }
    public atomic def hasDom() : Boolean {
        return !list1.isEmpty();
    }
    public atomic def domSize() : Int {
        return list1.size();
    }
    protected atomic def sortDom() {
        finish list1.sort(
            (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                b2.volume().compareTo(b1.volume()) );
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {

        // add to list if not a dummy box
        if (box.size() > 0)
            addDom(box);

        //sortDom();

        while (hasDom() && domSize() < maxDomSize) {
            val dom = removeDom();
            searchBody(sHandle, dom);
        }

        //sortDom();
    }

    protected def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//sHandle().debugPrint(here + ": search:\n" + box + '\n');
        val res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val bp = box.split(v()); 
                //sHandle().nSplits.getAndIncrement();
                sHandle().nSplits++;
                addDom(bp.first);
                addDom(bp.second);

                //sortDom();
            }
            else {
                sHandle().addSolution(res, box);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
