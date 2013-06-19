import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class Solver {
    public static struct Interval {
        public val left:Double;
        public val right:Double;
    
        public def this(left:Double, right:Double) : Interval {
            this.left = left;
            this.right = right;
        }

        public def width() : Double {
            return right - left;
        }
        
        public def split() : Pair[Interval,Interval] {
            val mid = (left+right)/2;
            return new Pair(new Interval(left,mid), new Interval(mid,right));
        }
    
        public def toString() : String {
            return "[" + left+ ", " + right + "]";
        }
    }

    public static class IntervalVec extends HashMap[String,Interval] { 
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

    public static struct Result {
        private val code:Int;
        private def this(code:Int) : Result { this.code = code; }
        public static def noSolution() : Result { return new Result(1); }
        public static def unknown()    : Result { return new Result(0); }
        public static def verified()   : Result { return new Result(2); }
        public def hasNoSolution() : Boolean { return code == 1; }
    }

    @NativeRep("c++", "Solver__Core *", "Solver__Core", null)
    @NativeCPPOutputFile("Solver__Core.h")
    @NativeCPPCompilationUnit("Solver__Core.cc")
    static class Core {
        public def this() :Core {}
        @Native("c++", "(#0)->initialize((#1))")
        public def initialize(filename:String) :void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() :IntervalVec { 
            return new IntervalVec(); 
        };
        @Native("c++", "(#0)->solve()")
        public def solve():int = 0;
        @Native("c++", "(#0)->calculateNext()")
        public def calculateNext():int = 0;
        @Native("c++", "(#0)->contract((#1))")
        public atomic def contract(box:IntervalVec):Result { return Result.unknown(); };
    } 

    val core:Core;
    val list:List[IntervalVec];
    //val list:CircularQueue[IntervalVec];
    val solutions:List[Pair[Result,IntervalVec]];
    val precision:Double;
    val dummy:Double; // kludge for a success of compilation

    public def this(filename:String, prec:Double) {
        core = new Core();
        core.initialize(filename);
        list = new ArrayList[IntervalVec]();
        if (here.id() == 0)
            list.add(core.getInitialDomain());
        solutions = new ArrayList[Pair[Result,IntervalVec]]();
        precision = prec;
        dummy = 0;
    }
    public def this(filename:String) { this(filename, 1E-1); }

    public def getSolutions() : List[Pair[Result,IntervalVec]] { return solutions; }
    
    public def solve0() {
   		Console.OUT.println(here + ": start solving... ");
        core.solve();
   		Console.OUT.println(here + ": done");
    }

    protected def isSplittable(box:IntervalVec) : Boolean {
        return box.width() > precision;
    }

    private var variableIt:Iterator[String] = null;
    // (global) round-robin selector
    /*protected def selectVariable(box:IntervalVec) : String {
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
    }*/
    // (local) round-robin selector
    protected def selectVariable(box:IntervalVec) : String {
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
    /*protected def selectVariable(box:IntervalVec) : String {
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
    }*/

    protected def search(box:IntervalVec) {
	    //Console.OUT.println(here + ": search:\n" + box + '\n');

        //val res:Result = core.contract(box);
        var res:Result = Result.unknown();
        atomic { res = core.contract(box); }

        if (!res.hasNoSolution()) {
            if (isSplittable(box)) {
                val v = selectVariable(box);
                val bp = box.split(v);
                async search(bp.first);
                async search(bp.second);
            }
            else {
                atomic solutions.add(new Pair[Result,IntervalVec](res, box));
                atomic Console.OUT.println(here + ": solution:\n" + box + '\n');
            }
        }
        //else Console.OUT.println(here + ": no solution");
    }

    protected def search1() {
        for (box in list) async {
   		    Console.OUT.println(here + ": search:");
   		    Console.OUT.println(box);
   		    Console.OUT.println();

            var res:Result = Result.unknown();
            atomic { res = core.contract(box); }

            if (!res.hasNoSolution()) {
                if (isSplittable(box)) {
                    val v = selectVariable(box);
                    val bp = box.split(v);
                    atomic list.add(bp.first);
                    atomic list.add(bp.second);
                    search1();
                }
                else {
                    atomic solutions.add(new Pair[Result,IntervalVec](res, box));
                    atomic Console.OUT.println(here + ": solution:\n" + box + '\n');
                }
            }
            else
                Console.OUT.println(here + ": no solution");
        }
    }

    public def solve() {
   		Console.OUT.println(here + ": start solving... ");

        // main solving process
        val box:IntervalVec = list.removeFirst();
        finish search(box);
        
        //finish search1();

        // print solutions
        val it = solutions.iterator();
        for (var i:Int = 0; it.hasNext(); ++i) {
            val p = it.next();
   		    //Console.OUT.println("solution " + i + ":");
   		    Console.OUT.println(p.second);
   		    Console.OUT.println();
        }

   		Console.OUT.println(here + ": done");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
