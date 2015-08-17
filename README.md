# ICPX10

ICPX10 is a parallel interval-based numerical constraint solver implemented with X10 and IBEX.

## Requirements

* IBEX <http://www.ibex-lib.org/> (tested with version 2.1.13)
* X10 <http://x10-lang.org/> (tested with version 2.5.3)
* C/C++ (tested with gcc version 4.7.4 and version 4.8.2)

Tested on Linux version 3.2.0-4-amd64 and Mac OS X version 10.9.5.

## Install

`$(ICPX10_DIR)` represents the path to the unpacked directories of ICPX10.

1. Modify the Makefile if necessary.
2. Build ICPX10.
```
$ cd $(ICPX10_DIR)
$ make
```

Binary file `$(ICPX10_DIR)/Main` will be generated.

## Example

A command-line script for solving the Sphere and Plane benchmark (w. 2+2 variables):
```
$ X10_NPLACES=4 ./Main -f benchs-uc/sp22.bch -e 0.01 -v 7 -i 0.001 -li 100 -w 1 -l 2
```
The solving parameters are configured as:
* `X10_NPLACES=4`: use 4 X10 places (when using Sockets X10RT implementation).
* `-e 0.01`: set the precision threshold for the branch and prune algorithm.
* `-v 7`: set the verbose level (no outputs when `-v 0`).
* `-i 0.001`: set the minimal intervals for load balancing (in seconds).
* `-li 100`: set the log sampling interval (in seconds).
* `-w 1`: set the number of random stealing attempts.
* `-l 2`: set the diameter of the lifeline graph.

## Reference

D. Ishii, K. Yoshizoe, and T. Suzumura. Scalable Parallel Numerical Constraint Solver Using Global Load Balancing. In X10 Workshop, pages 33-38, 2015.

D. Ishii, K. Yoshizoe, and T. Suzumura. Scalable Parallel Numerical CSP Solver. In 20th International Conference on Principles and Practice of Constraint Programming (CP), LNCS 8656, pages 398-406, 2014.

## Copyright and license

Copyright (c) 2013-2015 [Daisuke Ishii](http://www.dsksh.com/).
Code is released under the Eclipse Public License v1.0.
Code under the "glb" directory is taken from the source tree of X10 version 2.4.3.2.
"LinkedList.x10" is a modification of "LinkedList.java" taken from an OpenJDK distribution, which is released under GPLv2.
