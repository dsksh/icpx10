#!/bin/sh

pid=$1
prec=$2
#nlid=$3
nlid=1

export X10_NTHREADS=6
export GC_NPROCS=2 

export RPX10_REQUEST_THRESHOLD=-1
export RPX10_MAX_N_REQUESTS=1
export RPX10_N_SEARCH_STEPS=10
export RPX10_N_DESTINATIONS=2
export RPX10_N_BOXES_MIN=64
export RPX10_DIST_DELAY=0

#np=500; sync; X10_NTHREADS=6 GC_NPROCS=2 RPX10_DEBUG=false RPX10_REQUEST_THRESHOLD=-1 RPX10_MAX_N_REQUESTS=1 RPX10_N_SEARCH_STEPS=1000 RPX10_N_DESTINATIONS=2 RPX10_N_BOXES_MIN=64 RPX10_DIST_DELAY=0 mpirun -hostfile nodefile.txt -np $np ./RPX10 hoge 4 1e-2 1 2 3

sync; mpirun -hostfile nodefile$nlid.txt -np 120 ./RPX10 hoge $pid $prec 1 2 3;
sync; mpirun -hostfile nodefile$nlid.txt -np 240 ./RPX10 hoge $pid $prec 1 2 3;
sync; mpirun -hostfile nodefile$nlid.txt -np 360 ./RPX10 hoge $pid $prec 1 2 3;
sync; mpirun -hostfile nodefile$nlid.txt -np 480 ./RPX10 hoge $pid $prec 1 2 3;
sync; mpirun -hostfile nodefile$nlid.txt -np 600 ./RPX10 hoge $pid $prec 1 2 3;
