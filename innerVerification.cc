#include <list>
#include <cmath>
#include <iostream>
#include <sstream>
#include <cassert>

#include <boost/shared_ptr.hpp>

//#include "ibex.h"
#include "ibex_Linear.h"

#include "config.h"
#include "util.h"
#include "innerVerification.h"

using namespace std;
using namespace ibex;

/// Check whether the initial domain of the box covers the box within the scope.
bool isSuperset(const Scope& scope, const IntervalVector& init, const IntervalVector& proj) {
    for (int i(0); i < scope.size(); ++i) {
        if (!init[scope[i]].is_superset(proj[i])) return false;
    }
    return true;
}

/// interval Gauss-Seidel operator
IntervalVector gaussSeidel(const IntervalMatrix& J, 
                           const IntervalVector& a, const IntervalVector& b) {
    int dim(a.size());

    // diagonal inverse matrix of J
    IntervalMatrix DiagJ(dim, dim, 0.);
    for (int i(0); i < dim; ++i)
    {
        if (J[i][i].is_superset(Interval::ZERO))
            throw(std::runtime_error("singular matrix!"));

        DiagJ[i][i] = 1 / J[i][i];
    }

    // off-diagonal matrix of J
    IntervalMatrix OffJ(dim, dim, 0.);
    for (int i(0); i < dim; ++i)
        for (int j(0); j < dim; ++j)
            if (i != j)
                OffJ[i][j] = J[i][j];
        
    return DiagJ * (b - OffJ*a);
}


bool regular(const IntervalMatrix& J);

void jacobianProj(const Function& fun, const Scope& scope, const IntervalVector& v,
                  IntervalMatrix& J) {
    IntervalVector gr(v.size());
    for (int i=0; i < fun.image_dim(); i++) {
        fun[i].gradient(v, gr);
        for (int j=0; j < scope.size(); j++)
            J[i][j] = gr[scope[j]];
    }
}

void fixRedundantParams(const IntervalVector& dom_bx, 
                        const Scope& scProj, const Scope& scParam__, 
                        Function& fun,
                        Scope& scParam);

IntervalVector getProjValue(const IntervalVector& box, const Scope& scope) {
    IntervalVector proj(scope.size());
    for (int i=0; i < scope.size(); i++) {
        proj[i] = box[scope[i]];
    }
    return proj;
}

void setProjValue(IntervalVector& box, const IntervalVector& proj, const Scope& scope) {
    for (int i=0; i < scope.size(); i++)
        box[scope[i]] = proj[i];
}

double norm(const Matrix& mtx) {
    double n=0;
    for (int i=0; i < mtx.nb_rows(); i++)
        for (int j=0; j < mtx.nb_cols(); j++)
            n += ::pow(mtx[i][j], 2);
    return ::sqrt(n);
}

IntervalVector contract(Function& fun, const Scope& scProj, const Scope& scParam,
                        const IntervalVector& dom, const IntervalVector& pjDom,
#if RPR_CENTERED_FORM
                        const IntervalVector& pjRangeCnt,
#endif
                        innerResult& result );


static const double Tau(1.01);
//static constdouble Tau(1.0);
static const double Mu(0.9);
//static const double Mu(0.999999);


/**
 * inner testing procedure
 */
innerResult verifyInner(Function& fun,
                        const Scope& scProj, const Scope& scParam_, const Scope& scCyclic, 
                        IntervalVector& dom, const IntervalVector& domInit, 
                        bool reduceBox, int inflTrial ) {

    int dim(fun.image_dim());

    innerResult result;     
    result.regularJu = false;

    if (scParam_.size() < dim)
        return result;

	Scope scParam;
    if (scParam_.size() == dim) 
        scParam = scParam_;
    else // scParam_.size() > dim
	    fixRedundantParams(dom, scProj, scParam_, fun, scParam);

#if RPR_DEBUG
    std::cout << std::endl;
    std::cout << "dom:" << std::endl;
    std::cout << dom << std::endl;
#endif

    const IntervalVector pjOrig(getProjValue(dom, scParam));
    IntervalVector pjDom(pjOrig);

#if RPR_CENTERED_FORM
    IntervalVector pjRange(getProjValue(dom, scProj));
    IntervalVector pjRangeCnt(pjRange - IntervalVector(pjRange.mid()) );
#endif

    // extract the non-cyclic scope 
    Scope scNonCyclic;
    for (int i=0, j=0; i < scParam.size();) {
//cout << "i: " << i << ", j: " << j << endl;
        if (j >= scCyclic.size() || scParam[i] < scCyclic[j])
            scNonCyclic.push_back(scParam[i++]);
        else if (scParam[i] > scCyclic[j])
            j++;
        else { // scParam[i] == scCyclic[j]
            scNonCyclic.push_back(scParam[i++]); j++;
        }
    }

    double d(HUGE_VAL), dPrev(HUGE_VAL);

    int k(0);
    while (d > 0.0 && d <= Mu*dPrev 
           && isSuperset(scNonCyclic, domInit, pjDom)
           && (inflTrial < 0 || k <= inflTrial)
          ) {


        IntervalVector pjContracted(dim);
        try {
            pjContracted = contract(fun, scProj, scParam, dom, pjDom,
#if RPR_CENTERED_FORM   
                                    pjRangeCnt,
#endif
                                    result );
        }
        catch (SingularMatrixException&) {
            result.regularJu = false;
            return result;
        }
        catch (const std::runtime_error& err) {
#if RPR_DEBUG
std::cout << err.what() << std::endl;
#endif

            // some element of J contains 0
            result.regularJu = false;
            return result;
        }

        // TODO
        if (pjContracted.is_empty())
            //break;
            throw(std::runtime_error("contracted to empty interval!"));

        if (pjDom.is_strict_superset(pjContracted) && 
            isSuperset(scNonCyclic, domInit, pjDom) ) {
//std::cout << "inner: " << pjContracted.width() / pjDom.width() << std::endl;

            if (reduceBox) {
                setProjValue(dom, pjContracted, scParam);
#if RPR_COND_NUM
                dom.cond_number = result.cond;
#endif
            }

//std::cout << "contracted" << std::endl;
            result.regular = true;
            return result;
        }

        // TODO
        if (reduceBox) {
            IntervalVector reduced( pjOrig & pjContracted );
            if (!reduced.is_empty())
                setProjValue(dom, reduced, scParam);

#if RPR_COND_NUM
            dom.cond_number = result.cond;
#endif
        }

        // domain inflation
        dPrev = d;
        d = ibex::distance(pjDom, pjContracted);
#if RPR_DEBUG
        std::cout << "d:  " << d << ", d-: " << Mu*dPrev << std::endl;
#endif
        // TODO
        //if (d == 0.0) throw(std::runtime_error("no contraction!"));

        pjDom = pjContracted - IntervalVector(pjContracted.mid());
        pjDom *= Interval(Tau);
        pjDom = IntervalVector(pjContracted.mid()) + pjDom;

        ++k;
    }

#if RPR_DEBUG
    std::cout << "inner box verification done" << std::endl;
#endif

    return result;
}


IntervalVector contract(Function& fun, const Scope& scProj, const Scope& scParam,
                        const IntervalVector& dom, const IntervalVector& pjDom,
#if RPR_CENTERED_FORM
                        const IntervalVector& pjRangeCnt,
#endif
                        innerResult& result ) {

    int dim(fun.image_dim());

    // Jacobian matrix
    IntervalMatrix J(dim, dim);
    IntervalVector box(dom);
    setProjValue(box, pjDom, scParam);
    jacobianProj(fun, scParam, box, J);

#if RPR_CENTERED_FORM
    IntervalMatrix Jcnt(dim, scProj.size());
    IntervalVector box1(dom);
    setProjValue(box1, IntervalVector(pjDom.mid()), scParam);
    jacobianProj(fun, scProj, box1, Jcnt);
#endif

    // preconditioning
    IntervalMatrix C(dim, dim);
    Matrix realC(dim, dim);
    Matrix midJ(J.mid());
    real_inverse(midJ, realC);
    C = IntervalMatrix(realC);

#if RPR_COND_NUM
    Matrix J_inv(dim, dim);
    real_inverse(midJ, J_inv)
    result.cond = norm(J_inv) * norm(midJ);
#endif

    J = C * J;

    // cf. [Goldsztejn+, RC'10] Col.3.1
    IntervalVector pjMid( pjDom.mid() );
    IntervalVector domMid(dom);
#if RPR_CENTERED_FORM
    domMid = dom.mid();
#endif
    setProjValue(domMid, pjMid, scParam);

    IntervalVector funMid(dim);
    funMid = fun.eval_vector(domMid);

    IntervalVector pjGamma(pjDom);
    pjGamma = gaussSeidel(J, pjDom - pjMid, 
#if !(RPR_CENTERED_FORM)
                        C * (-funMid)
#else
                        C * (-funMid) - (C*Jcnt) * pjRangeCnt
#endif
                       );

    result.regularJu = regular(J);

#if RPR_DEBUG
    std::cout << std::endl;
    std::cout << "J:  " << J << std::endl;
    std::cout << "C:  " << C << std::endl;
    std::cout << "Y:  " << pjDom << std::endl;
    std::cout << "Y': " << (pjMid + pjGamma) << std::endl;
#endif

    return pjMid + pjGamma;
}


bool regular(const IntervalMatrix& J) {
    int dim(J.nb_rows());

    const Matrix midJ(J.mid());

    // inverse of the center of J
    Matrix Inv(J.nb_rows(), J.nb_cols());
    try {
        if (J.nb_rows() == J.nb_cols()) {
            //if (!midJ.inverse(Inv))
            //  return false;
            real_inverse(midJ, Inv);
        } else {
            Matrix Inv_(dim, dim);
            //if (!Matrix(midJ * midJ.transpose()).inverse(Inv_))
            //  return false;
            real_inverse(Matrix(midJ * midJ.transpose()), Inv_);
            Inv = midJ.transpose() * Inv_;
        }
    } catch(SingularMatrixException&) {
        return false;
    }

    //J = IntervalMatrix(Inv) * J;
    IntervalMatrix CJ(J * IntervalMatrix(Inv));

#if RPR_DEBUG
    bool res(true);
#endif
    for (int i(0); i < dim; ++i) {
        double mag(0.0);
        for (int j(0); j < dim; ++j) {
#if RPR_DEBUG
std::cout << ' ' << CJ[i][j];
#endif
            if (i != j) mag += CJ[i][j].mag();
        }
#if RPR_DEBUG
std::cout << std::endl;
#endif

#if RPR_DEBUG
        std::cout << CJ[i][i].mig() << " vs "<< mag << std::endl;
#endif

        if (CJ[i][i].mig() <= mag)
#if !(RPR_DEBUG)
            return false;
#else
            res = false;
#endif
    }

#if !(RPR_DEBUG)
    return true;
#else
    return res;
#endif
}


void fixRedundantParams(const IntervalVector& dom_bx, 
                        const Scope& scProj, const Scope& scParam__, 
                        Function& fun,
                        Scope& scParam) {

    int dim(fun.image_dim());

    Scope scParam_(scParam__);

    // compute the the Jacobian matrix
    IntervalMatrix J(dim, scParam_.size());
    IntervalVector box(dom_bx);
    jacobianProj(fun, scParam_, box, J);

    // get the midpoint of the transposed Jacobian matrix
    typedef boost::shared_ptr<Vector> VectorPtr;
    typedef std::list<VectorPtr> MyMatrix;
    MyMatrix JMidTr;
    for (int i(0); i < scParam_.size(); ++i)
        JMidTr.push_back(VectorPtr(new Vector(dim)));
    for (int i(0); i < dim; ++i) {
        MyMatrix::iterator mit(JMidTr.begin());
        for (int j(0); j < scParam_.size() && mit != JMidTr.end(); ++j, ++mit)
            (**mit)[i] = J[i][j].mid();
    }

    Scope::iterator dit = scParam_.begin();

    // first, take the largest vector
    double maxNorm(0);
    Scope::iterator dit_(scParam_.begin());
    MyMatrix::iterator mit(JMidTr.begin()), mit_(JMidTr.begin());
    for (; dit_ != scParam_.end(), mit_ != JMidTr.end(); 
         ++dit_, ++mit_) {
        if ((**mit_).norm() > maxNorm) {
            maxNorm = (**mit_).norm();
            dit = dit_;
            mit = mit_;
        }
    }
//std::cout << *dit << std::endl;
    scParam.push_back(*dit);
    dit = scParam_.erase(dit);

    VectorPtr prev(*mit);
    JMidTr.erase(mit);

    // in the followings, take the most orthogonal ones
    while (scParam.size() < dim) {
        maxNorm = 0;
        dit = scParam_.begin(); dit_ = scParam_.begin();
        mit = JMidTr.begin(); mit_ = JMidTr.begin();
        for (; dit_ != scParam_.end(), mit_ != JMidTr.end(); 
             ++dit_, ++mit_) {
            Vector proj(*prev);
            proj *= ((*prev)*(**mit_)) / ((*prev)*(*prev));
            **mit_ -= proj;
            if ((**mit_).norm() > maxNorm) {
                maxNorm = (**mit_).norm();
                dit = dit_;
                mit = mit_;
            }
        }
//std::cout << *dit << std::endl;
        scParam.push_back(*dit);
        dit = scParam_.erase(dit);
        prev = *mit;
        JMidTr.erase(mit);
    }
}

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
