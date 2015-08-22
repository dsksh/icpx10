import x10.compiler.*;

public final class GlbBagImpl[K] implements glb.TaskBag {
    public val data:Rail[IntervalVec[K]];
    public var objUB:Double;

    public def this(size:Long) {
        data = new Rail[IntervalVec[K]](size);
        objUB = Double.POSITIVE_INFINITY;
    }

    @Inline public def size() = data.size;
}
