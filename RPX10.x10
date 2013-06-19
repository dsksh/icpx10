import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class RPX10 {

    /*@NativeRep("c++", "RPX10__Solver *", "RPX10__Solver", null)
    @NativeCPPOutputFile("RPX10__Solver.h")
    @NativeCPPCompilationUnit("RPX10__Solver.cc")

    static class Solver {
        public def this() : Solver { }
        @Native("c++", "(#0)->solve((#1))")
        public def solve (filename:String):int = 0;
    } 
    */

    static def format(t:Long) = (t as Double) * 1.0e-9;

    /*public static def main(args:Array[String](1)) {
        val solver = new Solver(args(0));
        solver.solve();
    }
    */

    public static def main(args:Array[String](1)) {
        // create a solver at each place
        val everyone = Dist.makeUnique();
        //val sHandle = PlaceLocalHandle.make[Solver](everyone, 
        //        () => new Solver(args(0)) );
        val sHandle = PlaceLocalHandle.make[Solver1](everyone, 
                () => new Solver1(args(0)) );
        //val ref:GlobalRef[PlaceLocalHandle[Solver1]] = GlobalRef[PlaceLocalHandle[Solver1]](sHandle);

        val masterP = here;

        var time:Long = -System.nanoTime();
        sHandle().setup(sHandle);

        finish for (p in Place.places()) at (p) async {
		    val solver = sHandle();
            //solver.solve();
            solver.solve(sHandle);
        }

        /*val it = solutions.iterator();
        for (var i:Int = 0; it.hasNext(); ++i) {
            val p = it.next();
   		    //Console.OUT.println("solution " + i + ":");
   		    Console.OUT.println(p.second);
   		    Console.OUT.println();
        }
        */

        time += System.nanoTime();
        Console.OUT.println();
        Console.OUT.println("time: " + format(time) + " s");

        // sum up the # solutions at each place
        val nSols = new GlobalRef(new Cell(0));
        Console.OUT.print("# sols:");
        for (p in Place.places()) at (p) {
            val v = sHandle().nSols.get();
            at (masterP) {
                Console.OUT.print((p == here ? " " : " + ") + v);
                nSols().value += v;
            }
        }
        Console.OUT.println(" = " + nSols().value);

        // sum up the # splits at each place
        val nSplits = new GlobalRef(new Cell(0));
        Console.OUT.print("# splits:");
        for (p in Place.places()) at (p) {
            val v = sHandle().nSplits.get();
            at (masterP) {
                Console.OUT.print((p == here ? " " : " + ") + v);
                nSplits().value += v;
            }
        }
        Console.OUT.println(" = " + nSplits().value);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
