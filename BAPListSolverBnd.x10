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
    public def addDom(box:IntervalVec[K]) {
        // add last.
        list1.add(box);
    }
    public def removeDom() : IntervalVec[K] {
        return list1.removeFirst();
    }
    public def hasDom() : Boolean {
        return !list1.isEmpty();
    }
    public def domSize() : Int {
        return list1.size();
    }
    protected def sortDom() {
        finish list1.sort(
            (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                b2.volume().compareTo(b1.volume()) );
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        // add to list if not a dummy box
        if (box.size() > 0)
            addDom(box);

        // TODO: parallelize? 
        while (hasDom() && domSize() < maxDomSize) {
            val dom = removeDom();
            searchBody(sHandle, dom);
        }
    }

    protected def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
        val res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val bp = box.split(v()); 
                sHandle().nSplits.getAndIncrement();
                addDom(bp.first);
                addDom(bp.second);

                sortDom();
            }
            else {
                sHandle().addSolution(res, box);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
