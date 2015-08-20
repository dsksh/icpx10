import x10.compiler.*;

public final class GlbBagImpl[K] implements glb.TaskBag {
    public val data:Rail[IntervalVec[K]];

    public def this(size:Long) {
        data = new Rail[IntervalVec[K]](size);
    }

    @Inline public def size() = data.size;
}
