import x10.util.*;

public class VariableSelector[K] {
    private val precision:Double;
    private var variableIt:Iterator[K] = null;

    //public val GRR : (IntervalVec[K])=>String;

    public def this(precision:Double) {
        this.precision = precision;
        //this.GRR = ((box:IntervalVec[K]) => this.selectGRR(box));
    }

    /*public operator this(box:IntervalVec[K]) : K {
        return null; 
    }*/

    public def selectGRR(box:IntervalVec[K]) : Box[K] {
        if (variableIt == null || !variableIt.hasNext()) variableIt = box.varIterator();
        val v0 = variableIt.next();
        if (box(v0).value.width() > precision)
            return new Box[K](v0);

        // try rest of the vars.
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (box(v).value.width() > precision)
                return new Box[K](v);
        }

        // try the preceding vars.
        variableIt = box.varIterator();
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (v == v0)
                break;
            if (box(v).value.width() > precision)
                return new Box[K](v);
        }

        return null;
    }

    // (local) round-robin selector
    public def selectLRR(box:IntervalVec[K]) : Box[K] {
        var it:Iterator[K] = box.varIterator();

        // find the previously selected var
        while (box.prevVar() != null && it.hasNext()) {
            val v = it.next();
            if (v.equals(box.prevVar()()))
                break;
        }

        if (!it.hasNext()) it = box.varIterator();
        val v0 = it.next();
        if (box(v0).value.width() > precision) {
            box.setPrevVar(v0);
            return new Box[K](v0);
        }

        // try rest of the vars.
        while (it.hasNext()) {
            val v = it.next();
            if (box(v).value.width() > precision) {
                box.setPrevVar(v);
                return new Box[K](v);
            }
        }

        // try the preceding vars.
        it = box.varIterator();
        while (it.hasNext()) {
            val v = it.next();
            if (v.equals(v0))
                break;
            if (box(v).value.width() > precision) {
                box.setPrevVar(v);
                return new Box[K](v);
            }
        }

        return null;
    }
    /*public def selectLRR(box:IntervalVec[K]) : String {
        if (box.vit == null || !box.vit.hasNext()) box.vit = box.keyIterator();
        val v0 = box.vit.next();
Console.OUT.println(here + ": v0: " + v0);
        if (box(v0).value.width() > precision)
            return v0;

        // try rest of the vars.
        while (box.vit.hasNext()) {
            val v = box.vit.next();
Console.OUT.println(here + ": v: " + v);
            if (box(v).value.width() > precision)
                return v;
        }

        // try the preceding vars.
        box.vit = box.keyIterator();
        while (box.vit.hasNext()) {
            val v = box.vit.next();
Console.OUT.println(here + ": v: " + v);
            if (v == v0)
                break;
            if (v.equals(v0))
                break;
            if (box(v).value.width() > precision)
                return v;
        }

        return null;
    }
    */

    // largest-first selector
    public def selectLF(box:IntervalVec[K]) : Box[K] {
        var variable:Box[K] = null;
        var maxW:Double = precision;
        val it = box.varIterator();
        while (it.hasNext()) {
            val v = it.next();
            val c = box(v).value;
            if (c.width() > maxW) {
                variable = new Box[K](v); 
                maxW = c.width();
            }
        }
        return variable;
    }

    // kludge for "Interval is incomplete type" error
    val dummy : Interval = new Interval(0.,0.);
}

// vim: shiftwidth=4:tabstop=4:expandtab
