import x10.compiler.*;

public class IbexAdapter {

    @NativeRep("c++", "IbexAdapter__Core *", "IbexAdapter__Core", null)
    @NativeCPPOutputFile("IbexAdapter__Core.h")
    @NativeCPPCompilationUnit("IbexAdapter__Core.cc")
    @NativeCPPOutputFile("innerVerification.h")
    @NativeCPPCompilationUnit("innerVerification.cc")
    @NativeCPPOutputFile("util.h")
    @NativeCPPOutputFile("config.h")
    public static class Core implements BAPSolver.Core[Long] {
        public def this() : Core {}
        @Native("c++", "(#0)->initialize(#1,#2)")
        public def initialize(filename:String, n:Int) : Boolean { return false; };
        @Native("c++", "(#0)->finalize()")
        public def finalize() : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[Long] { 
            return new IntervalArray(1); 
        };
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[Long]) : BAPSolver.Result { 
            return BAPSolver.Result.unknown(); 
        };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:Long) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Long] { return new IntervalArray(0); }
    }

    @NativeRep("c++", "IbexAdapter__CoreOpt *", "IbexAdapter__CoreOpt", null)
    @NativeCPPOutputFile("IbexAdapter__CoreOpt.h")
    @NativeCPPCompilationUnit("IbexAdapter__CoreOpt.cc")
    @NativeCPPOutputFile("innerVerification.h")
    @NativeCPPCompilationUnit("innerVerification.cc")
    @NativeCPPOutputFile("util.h")
    @NativeCPPOutputFile("config.h")
    public static class CoreOpt implements BAPSolver.Core[Long] {
        public def this() : CoreOpt {}
        @Native("c++", "(#0)->initialize(#1,#2)")
        public def initialize(filename:String, n:Int) : Boolean { return false; };
        @Native("c++", "(#0)->finalize()")
        public def finalize() : void {};
        @Native("c++", "(#0)->getInitialDomain()")
        public def getInitialDomain() : IntervalVec[Long] { 
            return new IntervalArray(1); 
        };
        @Native("c++", "(#0)->contract((#1))")
        public def contract(box:IntervalVec[Long]) : BAPSolver.Result { 
            return BAPSolver.Result.unknown(); 
        };
        @Native("c++", "(#0)->isProjected((#1))")
        public def isProjected(v:Long) : Boolean { return false; }
        public def dummyBox() : IntervalVec[Long] { return new IntervalArray(0); }
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
