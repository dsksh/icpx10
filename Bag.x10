
import x10.compiler.*;

// kludge for "Interval is incomplete type" error
class Dummy_Bag {
    val dummy : Interval = new Interval(0.,0.);
}

public final class Bag[K] implements x10.glb.TaskBag {
    public val data:Rail[IntervalVec[K]];

    public def this(size:Long) {
        data = new Rail[IntervalVec[K]](size);
    }

    @Inline public def size() = data.size;
}
