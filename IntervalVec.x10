import x10.util.*;

public class IntervalVec extends HashMap[String,Interval] { 
    public var vit:Iterator[String] = null;

    public def this() : IntervalVec { } 
    public def this(lhs:IntervalVec) : IntervalVec { 
        super(lhs.serialize()); 
        this.vit = lhs.vit;
    } 

    public def split(variable:String) : Pair[IntervalVec,IntervalVec] {
        val b1 = new IntervalVec(this); 
        val b2 = new IntervalVec(this); 
        val ip = get(variable).value.split();
        b1.put(variable, ip.first);
        b2.put(variable, ip.second);
        return new Pair[IntervalVec,IntervalVec](b1,b2);
    }

    public def width() : Double {
        var width:Double = 0.;
        val it = entries().iterator();
        while (it.hasNext()) {
            val e = it.next();
            val w = e.getValue().width();
            if (w > width) width = w;
        }
        return width;
    }

    public def toString() :String {
        val sb:StringBuilder = new StringBuilder();
        sb.add('{');
        sb.add("\"plot\" : 3,\n");
        val it:Iterator[String] = keySet().iterator();
        var b:Boolean = false;
        while (it.hasNext()) {
            if (b) sb.add(",\n"); else b = true;
            val n:String = it.next();
            sb.add('"');
            sb.add(n);
            sb.add("\" : ");
            sb.add(get(n));
        }
        sb.add('}');
        return sb.result();
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
