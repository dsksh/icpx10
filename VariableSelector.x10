import x10.util.*;

public class VariableSelector {
    private val precision:Double;
    private var variableIt:Iterator[String] = null;

    //public val GRR : (IntervalVec)=>String;

    public def this(precision:Double) {
        this.precision = precision;
        //this.GRR = ((box:IntervalVec) => this.selectGRR(box));
    }

    public operator this(box:IntervalVec) : String {
        return null; 
    }

    public def selectGRR(box:IntervalVec) : String {
        if (variableIt == null || !variableIt.hasNext()) variableIt = box.keySet().iterator();
        val v0 = variableIt.next();
        if (box(v0).value.width() > precision)
            return v0;

        // try rest of the vars.
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (box(v).value.width() > precision)
                return v;
        }

        // try the preceding vars.
        variableIt = box.keySet().iterator();
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (v == v0)
                break;
            if (box(v).value.width() > precision)
                return v;
        }

        return null;
    }

    // (local) round-robin selector
    public def selectLRR(box:IntervalVec) : String {
        if (box.vit == null || !box.vit.hasNext()) box.vit = box.keySet().iterator();
        val v0 = box.vit.next();
        if (box(v0).value.width() > precision)
            return v0;

        // try rest of the vars.
        while (box.vit.hasNext()) {
            val v = box.vit.next();
            if (box(v).value.width() > precision)
                return v;
        }

        // try the preceding vars.
        box.vit = box.keySet().iterator();
        while (box.vit.hasNext()) {
            val v = box.vit.next();
            if (v == v0)
                break;
            if (box(v).value.width() > precision)
                return v;
        }

        return null;
    }

    // largest-first selector
    public def selectLF(box:IntervalVec) : String {
        var variable:String = null;
        var maxW:Double = precision;
        val it = box.keySet().iterator();
        while (it.hasNext()) {
            val v = it.next();
            val c = box(v).value;
            if (c.width() > maxW) {
                variable = v; 
                maxW = c.width();
            }
        }
        return variable;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
