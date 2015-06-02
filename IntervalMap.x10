import x10.util.Box;
import x10.util.Pair;

// kludge for "Interval is incomplete type" error
class Dummy_IntervalMap {
    val dummy : Interval = new Interval(0.,0.);
}

public class IntervalMap extends HashMap[String,Interval] 
implements IntervalVec[String] { 

    public var vit:Iterator[String] = null;
    public def vit() : Iterator[String] { return vit; }

    public var prevVar:String = null;
    public def prevVar() : Box[String] { return (prevVar != null) ? new Box(prevVar) : null; }
    public def setPrevVar(v:Box[String]) : void { prevVar = v != null ? v() : null; }

    public def this() : IntervalMap { } 
    public def this(lhs:IntervalMap) : IntervalMap { 
        super(); 

        // copy
        // TODO: use serializer?
        val it = lhs.entries().iterator();
        while (it.hasNext()) {
            val e:Map.Entry[String,Interval] = it.next();
            // TODO
            //put(e.getKey(), e.getValue());
        }

        this.prevVar = lhs.prevVar;
    } 

    public def varIterator() : Iterator[String] {
        return super.keySet().iterator();        
    }

    public def split(variable:String) : Pair[IntervalVec[String],IntervalVec[String]] {
        val b1 = new IntervalMap(this); 
        //if (vit != null) b1.vit = vit.clone(b1);
        val b2 = new IntervalMap(this); 
        //if (vit != null) b2.vit = vit.clone(b2);
        val ip = get(variable)().split();
        b1.put(variable, ip.first);
        b2.put(variable, ip.second);
        return new Pair[IntervalVec[String],IntervalVec[String]](b1,b2);
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
        return toString(3n);
    }
    public def toString(plot:Int) :String {
        val sb:StringBuilder = new StringBuilder();
        sb.add('{');
        sb.add("\"plot\" : "+plot+",\n");
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

    public def volume() : Double {
        // FIXME
        return -1.;
    }

    public def depth() : Long {
        return 0;
    }
    public def deepen() { }

    var count:Long = 0;

    public def count() : Long {
        return count++;
    }

    public operator this+(b:IntervalVec[String]) : IntervalVec[String] {
        return this;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
