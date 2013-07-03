import x10.util.*;

// kludge for "Interval is incomplete type" error
class Dummy_IntervalMap {
    val dummy : Interval = new Interval(0.,0.);
}

//public class IntervalMap extends MyHashMap[String,Interval]
public class IntervalMap extends HashMap[String,Interval] 
implements IntervalVec[String] { 

    public var vit:Iterator[String] = null;
    public def vit() : Iterator[String] { return vit; }
    //public var vit:MyHashMap.KeyIterator[String,Interval] = null;

    public var prevVar:String = null;
    public def prevVar() : Box[String] { return (prevVar != null) ? new Box(prevVar) : null; }
    public def setPrevVar(variable:String) : void { prevVar = variable; }

    public def this() : IntervalMap { } 
    public def this(lhs:IntervalMap) : IntervalMap { 
        super(lhs.serialize()); 
        //this.vit = lhs.vit.clone(this); // TODO: this cannot be compiled
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
        val ip = get(variable).value.split();
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

/*    public def varIterator() : VarIterator {
        val iterator = new EntriesIterator[String,Interval](this);
        iterator.advance();
        return new VarIterator(iterator, (e: IntervalVec.HashEntry[String,Interval]) => e.key);
    }                            

    //protected static class VarIterator implements Iterator[IntervalVec.HashEntry[String,Interval]] {
    protected static class VarIterator implements Iterator[String] {
        val i : IntervalVec.EntriesIterator[String,Interval];
        val f : (IntervalVec.HashEntry[String,Interval]) => String;

        def this(i:IntervalVec.EntriesIterator[String,Interval], f:(IntervalVec.HashEntry[String,Interval])=>String) {
            this.i = i;
            this.f = f;
        }
        def this(lhs:VarIterator) {
            this(new IntervalVec.EntriesIterator[String,Interval](lhs.i), lhs.f);
        }

        public def hasNext() : Boolean = i.hasNext();
        public def next() : String = f(i.next());
    }

    //protected static class EntriesIterator[String,Interval] implements Iterator[HashMap[String,Interval].HashEntry[String,Interval]] {
    protected static class EntriesIterator extends HashMap.EntriesIterator[String,Interval] {
        val map: IntervalVec;
        var i: Int;
        var originalModCount:Int;        

        def this(map:IntervalVec) { 
            this.map = map;
            this.i = 0; 
            this.originalModCount = map.modCount;
        }
        def this(lhs:EntriesIterator) {
            this.map = lhs.map; 
            this.i = lhs.i; 
            this.originalModCount = lhs.originalModCount;
        }

        def advance(): void {
            while (i < map.table.length()) { 
                if (map.table(i) != null && ! map.table(i).removed)
                     return;
                i++;
            }
        }

        public def hasNext(): Boolean {
            if (i < map.table.length()) {
                return true;
            }   
            return false;
        }   

        public def next(): HashEntry[Key,Value] {
            if (originalModCount!=map.modCount) throw new Exception("Your code has a concurrency bug! You updated the hashmap "+(map.modCount-originalModCount)+" times since you created the iterator.");
            val j = i;
            i++;
            advance();
            return map.table(j);
        }   
    }
*/
}

// vim: shiftwidth=4:tabstop=4:expandtab
