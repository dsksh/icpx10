import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class RPX10 {

    @NativeRep("c++", "RPX10__Solver *", "RPX10__Solver", null)
    @NativeCPPOutputFile("RPX10__Solver.h")
    @NativeCPPCompilationUnit("RPX10__Solver.cpp")

    static class Solver {
        public def this() : Solver { }
        @Native("c++", "(#0)->solve((#1))")
        public def solve (filename:String):int = 0;
    } 

    public static def main(args:Array[String](1)) {

        // create a solver at each place
        val everyone = Dist.makeUnique();
        //val s_handle = PlaceLocalHandle.make[RestartableSolver](everyone,
        //        () => new RestartableSolver(configuration) );

        // place ID of the master process that handles restart sequence, if
        // that option is used by the solvers; this place also runs a regular
        // solver like the rest of the places, responding to getNewRestart()
        // requests whenever it handles incoming messages
        val master_id = here.id();
        Console.OUT.println(here + ": starting master process for restart sequence");

        // launch a solver at each place; wait for all solvers to finish
        // (by solving or by being killed)
        finish ateach (i in everyone) {
		    val s = new Solver();
    		Console.OUT.print(here + ": start solving... ");
            s.solve(args(0));
    		Console.OUT.println(here + ": done");
        }

    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
