#ifndef RPX10__CORE_EX_H
#define RPX10__CORE_EX_H

#include "Interval.h"
#include "IntervalVec.h"
#include "Solver__Result.h"
#include "RPX10__Core.h"
#include "RPX10__CoreProj.h"

#include "config.h"

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
	virtual Solver__Result contract(IntervalVec<K> *box);

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
Solver__Result RPX10__CoreEx<K>::contract(IntervalVec<K> *iv) {
	if (IntervalVec<K>::size(iv) == 0)
        return Solver__Result::noSolution();

    rp::Box box( *list_->get_cell()->box );
    setIVIntoBox(*iv, box);

    rp::Solution sol = contractor_->contract(box);
    setBoxIntoIV(box, *iv);

    if (sol == rp::Solution::no())
        return Solver__Result::noSolution();
	else if (sol == rp::Solution::only())
        return Solver__Result::inner();
	else if (sol == rp::Solution::regular())
        return Solver__Result::regular();
    else
        return Solver__Result::unknown();
}

#endif // RPX10__CORE_EX_H
