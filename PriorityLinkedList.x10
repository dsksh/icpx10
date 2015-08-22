import x10.util.List;
import x10.util.ListIterator;
import x10.util.Box;

public class PriorityLinkedList[E] extends LinkedList[E] {

    val compare:(E,E)=>Double;

    public def this(compare:(E,E)=>Double) {
        this.compare = compare;
    }

    public def add(e:E): Boolean {
        var i:Long = 0;
        val it = iterator();
        while (it.hasNext()) {
            val e1 = it.next();
            if (compare(e,e1) <= 0.) {
//Console.OUT.println("add:\n"+e+"\nbefore\n"+e1);
                addBefore(i, e);
                return true;
            }
            i++;
        }
        linkLast(e);
        return true;
    }
}
