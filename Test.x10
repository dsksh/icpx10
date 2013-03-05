import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class Test {

	public def moge():String {
		return "moge";
	}

    @NativeRep("c++", "Test__Stub*", "Test__Stub", null)
    @NativeCPPOutputFile("Test__Stub.h")
    @NativeCPPCompilationUnit("Test__Stub.cpp")

    static class Stub {
        public def this() : Stub { }
        @Native("c++", "(#0)->hello()")
        public def hello ():String = "";
    } 

    public static def main(argv:Array[String]) {
		val t = new Test();
		Console.OUT.println(t.moge());
		val s = new Stub();
		Console.OUT.println(s.hello());
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
