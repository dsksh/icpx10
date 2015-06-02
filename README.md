# ICPX10

ICPX10 is a parallel interval/numerical constraint solver implemented with X10.

## Requirements

* IBEX <http://www.ibex-lib.org/> (tested with version 2.1.13)
* X10 <http://x10-lang.org/> (tested with version 2.4.3.2)
* C/C++ (tested with gcc version 4.7.4 and ver. 4.8.2)

Tested on Linux ver. 3.2.0-4-amd64 and Mac OS X ver. 10.9.5.

## Install

`$(ICPX10_DIR)` and `$(IBEX_DIR)` represents the path to the unpacked directory of ICPX10 and IBEX, respectively.

1. Modify the Makefile if necessary.
2. Build ICPX10.
```
$ cd $(ICPX10_DIR)
$ make
```

Binary file `$(ICPX10_DIR)/GlbMail` will be generated.

## Example

```
$ ./GlbMain -f $(IBEX_DIR)/benchs/benchs-satisfaction/benchs-coprin/BroydenTri-0010.bch -p 1 -e 0.01 -v 7 -i 0.001 -li 100 -w 1 -l 2
```

## Reference

D. Ishii, K. Yoshizoe, and T. Suzumura. Scalable Parallel Numerical Constraint Solver Using Global Load Balancing. In X10 Workshop, 2015. (to appear)

D. Ishii, K. Yoshizoe, and T. Suzumura. Scalable Parallel Numerical CSP Solver. In 20th International Conference on Principles and Practice of Constraint Programming (CP), LNCS 8656, pages 398-406. LNCS 8656, 2014.

## Copyright and license

Copyright (c) 2015 Daisuke Ishii <http://www.dsksh.com/>.
Code is released under the Eclipse Public License v1.0.
Code under the "glb" directory is taken from the source tree of X10 version 2.4.3.2.
"LinkedList.x10" is a modification of "LinkedList.java" taken from an OpenJDK distribution, which is released under GPLv2.
