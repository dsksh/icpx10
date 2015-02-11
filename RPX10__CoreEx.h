#ifndef RPX10__CORE_EX_H
#define RPX10__CORE_EX_H

#include <unistd.h>

#include <sys/time.h>
#include <sys/resource.h>

#include "Interval.h"
#include "IntervalVec.h"
#include "BAPSolver__Result.h"
#include "RPX10__Core.h"
#include "RPX10__CoreProj.h"

#include "config.h"

#if USE_PAPI
#include <papi.h>
#endif

template<typename K>
#if !RPX_PROJ
class RPX10__CoreEx : public RPX10__Core {
#else
class RPX10__CoreEx : public RPX10__CoreProj {
#endif
public:

#if RPX_PROJ
	RPX10__CoreEx() : RPX10__CoreProj() { }
#endif

	//~RPX10__CoreEx() { }

    virtual IntervalVec<K> *getInitialDomain();
	virtual BAPSolver__Result contract(IntervalVec<K> *box);

protected:
	virtual IntervalVec<K> *getIVFromBox(const rp::Box& box) = 0;
	virtual void setIVIntoBox(IntervalVec<K>& iv, rp::Box& box) = 0;
	virtual void setBoxIntoIV(const rp::Box& box, IntervalVec<K>& iv) = 0;
};


template<typename K>
IntervalVec<K> *RPX10__CoreEx<K>::getInitialDomain() {
    rp::sp<rp::Box> sbx = list_->get_cell()->box;
    return getIVFromBox(*sbx);
}

template<typename K>
BAPSolver__Result RPX10__CoreEx<K>::contract(IntervalVec<K> *iv) {
	if (IntervalVec<K>::size(iv) == 0)
        return BAPSolver__Result::noSolution();

    rp::Box box( *list_->get_cell()->box );
    setIVIntoBox(*iv, box);

//struct rusage usage;
//struct timeval ut1, ut2;
//struct timeval st1, st2;
//
//getrusage(RUSAGE_SELF, &usage);
//ut1 = usage.ru_utime;
//st1 = usage.ru_stime;

//struct timeval s, e;
//gettimeofday(&s, NULL);

struct timespec s, e; 
//if (clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &s) == -1) {
//if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &s) == -1) {
//	std::cerr << "clock gettime error" << std::endl;
//	//exit(EXIT_FAILURE);
//}

#if USE_PAPI
papi_es = PAPI_NULL;

if (PAPI_create_eventset(&papi_es) != PAPI_OK) {
	printf("exit in creating es.");
	exit(1);
}

// PAPI_L2_TCA, PAPI_L3_TCA, PAPI_L3_TCM, PAPI_TOT_CYC, PAPI_LD_INS, PAPI_SR_INS
int ecodes[PAPI_EN] = {PAPI_L2_TCA, PAPI_L3_TCA, PAPI_L3_TCM, PAPI_LD_INS};
for (int i(0); i < PAPI_EN; ++i) {
	if (PAPI_add_event(papi_es, ecodes[i]) != PAPI_OK) {
		printf("exit when adding event %d.", i);
		exit(1);
	}
}

if (PAPI_start(papi_es) != PAPI_OK) exit(1);
#endif

    rp::Solution sol = contractor_->contract(box);
    setBoxIntoIV(box, *iv);

//rp::Solution sol = rp::Solution::no();
//contractor_->contract(box);
////usleep(100);

//getrusage(RUSAGE_SELF, &usage );
//ut2 = usage.ru_utime;
//st2 = usage.ru_stime;

//printf("user time = %lf\n", (ut2.tv_sec - ut1.tv_sec) + (ut2.tv_usec - ut1.tv_usec)*1.0E-6);
//printf("sys  time = %lf\n", (st2.tv_sec - st1.tv_sec) + (st2.tv_usec - st1.tv_usec)*1.0E-6);

//gettimeofday(&e, NULL);
//printf("time = %lf\n", (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec)*1.0E-6);

//if (clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &e) == -1) {
//if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &e) == -1) {
//	std::cerr << "clock gettime error" << std::endl;
//	//exit(EXIT_FAILURE);
//}
//printf("time = %lf\n", (e.tv_sec - s.tv_sec) + (e.tv_nsec - s.tv_nsec)*1.0E-9);

#if USE_PAPI
long long papi_res[PAPI_EN];
if (PAPI_stop(papi_es, papi_res) != PAPI_OK) exit(1);

//printf("papi: %lld, %lld, %lld, %lld\n", papi_res[0], papi_res[1], papi_res[2], papi_res[3]);

for (int i(0); i < PAPI_EN; ++i) {
	papi_result[i] += papi_res[i];

	if (PAPI_remove_event(papi_es, ecodes[i]) != PAPI_OK) {
		printf("exit when removing event %d.", i);
		exit(1);
	}
}

if (PAPI_destroy_eventset(&papi_es) != PAPI_OK) exit(1);
#endif

    if (sol == rp::Solution::no())
        return BAPSolver__Result::noSolution();
	else if (sol == rp::Solution::only())
        return BAPSolver__Result::inner();
	else if (sol == rp::Solution::regular())
        return BAPSolver__Result::regular();
    else
        return BAPSolver__Result::unknown();
}

#endif // RPX10__CORE_EX_H
