#!/bin/sh

pid=$1
prec=$2
#nlid=$3
nlid=1

export X10_NTHREADS=6
export GC_NPROCS=2 

#export RPX10_N_SEARCH_STEPS=10
export RPX10_N_SEARCH_STEPS=$4

export RPX10_N_DESTINATIONS=2
export RPX10_N_BOXES_MIN=64
export RPX10_DIST_DELAY=0

export RPX10_MAX_DELTA=10
export RPX10_N_SENDS_BOX=1
#export RPX10_N_SENDS_LOAD=2
export RPX10_N_SENDS_LOAD=$3

export RPX10_REQUEST_THRESHOLD=-1
export RPX10_MAX_N_REQUESTS=1

echo "{\"params\" : [$RPX10_N_BOXES_MIN, $RPX10_N_SENDS_LOAD, $RPX10_MAX_DELTA, $RPX10_N_SEARCH_STEPS]}"

#np=500; sync; X10_NTHREADS=6 GC_NPROCS=2 RPX10_DEBUG=false RPX10_REQUEST_THRESHOLD=-1 RPX10_MAX_N_REQUESTS=1 RPX10_N_SEARCH_STEPS=1000 RPX10_N_DESTINATIONS=2 RPX10_N_BOXES_MIN=64 RPX10_DIST_DELAY=0 mpirun -hostfile nodefile.txt -np $np ./RPX10 hoge 4 1e-2 1 2 3

#sync; mpirun -hostfile nodefile$nlid.txt -np 120 ./RPX10 hoge $pid $prec 1 2 3;

#sync; mpirun -np  1 ./RPX10 hoge $pid $prec 1 2 0;

sync; mpirun -np 16 ./RPX10 hoge $pid $prec 1 2 1;
sync; mpirun -np 24 ./RPX10 hoge $pid $prec 1 2 1;
sync; mpirun -np 32 ./RPX10 hoge $pid $prec 1 2 1;
sync; mpirun -np 36 ./RPX10 hoge $pid $prec 1 2 1;
sync; mpirun -np 40 ./RPX10 hoge $pid $prec 1 2 1;

#sync; mpirun -np  1 ./RPX10 hoge $pid $prec 1 2 4;
sync; mpirun -np 16 ./RPX10 hoge $pid $prec 1 2 4;
sync; mpirun -np 24 ./RPX10 hoge $pid $prec 1 2 4;
sync; mpirun -np 32 ./RPX10 hoge $pid $prec 1 2 4;
sync; mpirun -np 36 ./RPX10 hoge $pid $prec 1 2 4;
sync; mpirun -np 40 ./RPX10 hoge $pid $prec 1 2 4;

#sync; mpirun -np  1 ./RPX10 hoge $pid $prec 1 2 6;
sync; mpirun -np 16 ./RPX10 hoge $pid $prec 1 2 6;
sync; mpirun -np 24 ./RPX10 hoge $pid $prec 1 2 6;
sync; mpirun -np 32 ./RPX10 hoge $pid $prec 1 2 6;
sync; mpirun -np 36 ./RPX10 hoge $pid $prec 1 2 6;
sync; mpirun -np 40 ./RPX10 hoge $pid $prec 1 2 6;
