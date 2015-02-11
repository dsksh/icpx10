package glb;

import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.StringBuilder;

/**
 * <p>Class that collects lifeline statistics of GLB
 * </p>
 */
public final class Logger {
	
	/* workload sent/recieved stat*/
    public var nodesCount:Long = 0;
    public var nodesGiven:Long = 0;
    public var lifelineNodesReceived:Long = 0;

    public val listNodesCount = new ArrayList[Long]();
    public val listNodesGiven = new ArrayList[Long]();

    public val listQueueSize = new ArrayList[Long]();
    
    /* (random)stealing requests stat*/
    public var stealsAttempted:Long = 0;
    public var stealsPerpetrated:Long = 0;
    public var stealsReceived:Long = 0;
    public var stealsSuffered:Long = 0;
    public var nodesReceived:Long = 0;

    public val listNodesReceived = new ArrayList[Long]();

    /* (lifeline)stealing requests stat*/
    public var lifelineStealsAttempted:Long = 0;
    public var lifelineStealsPerpetrated:Long = 0;
    public var lifelineStealsReceived:Long = 0;
    public var lifelineStealsSuffered:Long = 0;
   

    /* timing stat */
    public var lastStartStopLiveTimeStamp:Long = -1;
    public var timeAlive:Long = 0;
    public var timeDead:Long = 0;
    public var startTime:Long = 0;
    public val timeReference:Long;

    /* etc */
    public var timeProc:Long = 0;
    public var timeStampProc:Long = 0;
    public var timeComm:Long = 0;
    public var timeStampComm:Long = 0;

    public val tInterval:Double = 0.1;
    
    public var strBuffer:String = "";

    //public val listDepthOfPaths = new ArrayList[Long]();
    public val mapDepthCount = new HashMap[Long,Long]();
    
    
    /**
     * Constructor
     * @param b true, called when prior-calculation; false, called when post-calculation
     */
    public def this(b:Boolean) {
        if (b) x10.util.Team.WORLD.barrier();
        timeReference = System.nanoTime();
    }
    
    public def this(b:Boolean, interval:Double) {
        this(b);
        this.tInterval = interval;
    }


    /**
     * Timer is started before processing, which includes calculation, distribution and requesting/rejects tasks
     */
    public def startLive() {
        val time = System.nanoTime();
        if (startTime == 0) startTime = time;
        if (lastStartStopLiveTimeStamp >= 0) {
            timeDead += time - lastStartStopLiveTimeStamp;
        }
        lastStartStopLiveTimeStamp = time;
    }

    /**
     * Timer is stopped when running out of tasks and failing to steal any task
     */
    public def stopLive() {
        val time = System.nanoTime();
        timeAlive += time - lastStartStopLiveTimeStamp;
        lastStartStopLiveTimeStamp = time;
    }


    public def startProc() {
        timeStampProc = System.nanoTime();
    }
    public def stopProc() {
        val time = System.nanoTime();
        val diff = time - timeStampProc;
        timeProc += diff;
        timeStampProc = time;
    }

    public def startComm() {
        timeStampComm = System.nanoTime();
    }
    public def stopComm() {
        val time = System.nanoTime();
        timeComm += time - timeStampComm;
        timeStampComm = time;
    }

    public def incrDepthCount(depth:Long) {
        val c = mapDepthCount.getOrElse(depth, 0);
        mapDepthCount.put(depth, c+1);
    }


    /**
     * Aggregate stats for all places
     * @param logs log from every place
     */
    public def collect(logs:Rail[Logger]) {
        for (l in logs) add(l);
    }

    /**
     * Print out the actual workload re-distribution by showing the steals that were carried out.
     */
    public def stats() {
        /*Console.OUT.println(nodesGiven + " Task items stolen = " + nodesReceived + " (direct) + " +
            lifelineNodesReceived + " (lifeline)."); 
        Console.OUT.println(stealsPerpetrated + " successful direct steals."); 
        Console.OUT.println(lifelineStealsPerpetrated + " successful lifeline steals.");
        */
        Console.OUT.println("\"stats\" : {");
        Console.OUT.println("\"# items stolen\":" + nodesGiven + ",");
        Console.OUT.println("\"# items stolen (direct)\":" + nodesReceived + ",");
        Console.OUT.println("\"# items stolen (ll)\":" + lifelineNodesReceived + ","); 
        Console.OUT.println("\"# successful steals (direct)\":" + stealsPerpetrated + ","); 
        Console.OUT.println("\"# successful steals (ll)\":" + lifelineStealsPerpetrated + " },");
        Console.OUT.println();
    }

    /**
     * Gets part of the string.
     * @param str original string
     * @param start starting index of the string
     * @param end ending index of the string
     * @return string from start to end
     */
    static def sub(str:String, start:Int, end:Int) = str.substring(start, Math.min(end, str.length()));

    /**
     * Sum up stat with another logger
     * @param other another logger to sum up with
     */
    public def add(other:Logger) {
        nodesCount += other.nodesCount;
        nodesGiven += other.nodesGiven;
        nodesReceived += other.nodesReceived;
        stealsPerpetrated += other.stealsPerpetrated;
        lifelineNodesReceived += other.lifelineNodesReceived;
        lifelineStealsPerpetrated += other.lifelineStealsPerpetrated;

        strBuffer += other.strBuffer;
    }

    /**
     * Print out more detailed lifeline stats when verbose flag turned on
     * @param verbose verbose flag true when {@link GLBParameters} show glb flag is on.
     */
    public def get(verbose:Boolean) {
        if (verbose) {
            /*Console.OUT.println("" + Runtime.hereLong() + " -> " +
                sub("" + (timeAlive/1E9), 0n, 6n) + " : " +
                sub("" + (timeDead/1E9), 0n, 6n) + " : " + 
                sub("" + ((timeAlive + timeDead)/1E9), 0n, 6n) + " : " + 
                sub("" + (100.0*timeAlive/(timeAlive+timeDead)), 0n, 6n) + "%" + " :: " +
                sub("" + ((startTime-timeReference)/1E9), 0n, 6n) + " : " +
                sub("" + ((lastStartStopLiveTimeStamp-timeReference)/1E9), 0n, 6n)  + " :: " +
                nodesCount + " :: " +
                nodesGiven + " : " +
                nodesReceived + " : " +
                lifelineNodesReceived + " :: " +
                stealsReceived + " : " +
                lifelineStealsReceived + " :: " +
                stealsSuffered + " : " +
                lifelineStealsSuffered + " :: " +
                stealsAttempted + " : " +
                (stealsAttempted - stealsPerpetrated) + " :: " +
                lifelineStealsAttempted + " : " +
                (lifelineStealsAttempted - lifelineStealsPerpetrated));
            */

            val sb = new StringBuilder();

            sb.add("{\"pid\":" + Runtime.hereLong() + ", ");
            sb.add("\"t alive\":"      + sub("" + (timeAlive/1E9), 0n, 6n) + ", ");
            sb.add("\"t dead\":"       + sub("" + (timeDead/1E9), 0n, 6n) + ", ");
            sb.add("\"t total\":"      + sub("" + ((timeAlive + timeDead)/1E9), 0n, 6n) + ", ");
            sb.add("\"ta ratio (%)\":" + sub("" + (100.0*timeAlive/(timeAlive+timeDead)), 0n, 6n) + ", ");
            sb.add("\"t rel\":"        + sub("" + ((startTime-timeReference)/1E9), 0n, 6n) + ", ");
            sb.add("\"t lssl\":"       + sub("" + ((lastStartStopLiveTimeStamp-timeReference)/1E9), 0n, 6n)  + ", ");
            sb.add("\"t proc\":"       + sub("" + (timeProc/1E9), 0n, 6n)  + ", ");
            //sb.add("\"t comm\":"       + sub("" + (timeComm/1E9), 0n, 6n)  + ", ");
            sb.add("\"nodes count\":"  + nodesCount + ", ");
            sb.add("\"nodes given\":"  + nodesGiven + ", ");
            sb.add("\"nodes recv\":"   + nodesReceived + ", ");
            sb.add("\"ll nodes recv\":" + lifelineNodesReceived + ", ");
            sb.add("\"steals recv\":"  + stealsReceived + ", ");
            sb.add("\"ll steals recv\":" + lifelineStealsReceived + ", ");
            sb.add("\"steals suff\":"  + stealsSuffered + ", ");
            sb.add("\"ll steals suff\":" + lifelineStealsSuffered + ", ");
            sb.add("\"steals att\":" + stealsAttempted + ", ");
            //sb.add("\"ll steals att\":" + (stealsAttempted - stealsPerpetrated) + ", ");
            sb.add("\"ll steals att\":" + lifelineStealsAttempted + ", ");
            //sb.add("\"\":" + (lifelineStealsAttempted - lifelineStealsPerpetrated)

            sb.add("\"list nodes count\": [");
            var f:Boolean = true;
            for (d in listNodesCount) {
                if (f) f = false; else sb.add(",");
                sb.add(d);
            }
            sb.add("], ");

            sb.add("\"list nodes given\": [");
            f = true;
            for (d in listNodesGiven) {
                if (f) f = false; else sb.add(",");
                sb.add(d);
            }
            sb.add("], ");

            sb.add("\"list nodes recv\": [");
            f = true;
            for (d in listNodesGiven) {
                if (f) f = false; else sb.add(",");
                sb.add(d);
            }
            sb.add("], ");

            sb.add("\"list queue size\": [");
            f = true;
            for (d in listQueueSize) {
                if (f) f = false; else sb.add(",");
                sb.add(d);
            }
            sb.add("],");

            sb.add("\"depth counts\": {");
            f = true;
            //for (d in listDepthOfPaths) {
            //    if (f) f = false; else sb.add(",");
            //    sb.add(d);
            //}
            for (e in mapDepthCount.entries()) {
                if (f) f = false; else sb.add(",");
                sb.add("\""); sb.add(e.getKey()); sb.add("\":"); sb.add(e.getValue());
            }
            sb.add("} }");
            strBuffer = sb.result();
        }
        return this;
    }
}
