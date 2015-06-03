#include <list>
#include <cmath>
#include <iostream>
#include <sstream>
#include <cassert>

#include "ibex.h"

#include "config.h"
#include "util.h"
#include "prover.h"

using namespace std;
using namespace ibex;

/// Check whether the initial domain of the box covers the box within the scope.
bool isSuperset(const Scope& scope, const IntervalVector& init, const IntervalVector& box) {
	for (int i(0); i < scope.size() && i < box.size(); ++i) {
		if (!init[i].is_superset(box[i])) return false;
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


bool regular(const IntervalMatrix& J) {
	int dim(J.nb_rows());

	const Matrix midJ(J.mid());

	// inverse of the center of J
	Matrix Inv(J.nb_rows(), J.nb_cols());
	try {
		if (J.nb_rows() == J.nb_cols()) {
			//if (!midJ.inverse(Inv))
			//	return false;
			real_inverse(midJ, Inv);
		} else {
			Matrix Inv_(dim, dim);
			//if (!Matrix(midJ * midJ.transpose()).inverse(Inv_))
			//	return false;
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


inline double euclideanNorm(const Vector& vec) {
	double r(0);
	for (int i=0; i < vec.size(); ++i)
		r += vec[i]*vec[i];
	return std::sqrt(r);
}


/*void fix_redundant_params(const Box& dom_bx, 
						  const Scope& proj_sc, const Scope& param_sc__, 
						  IntervalFunctionVector& fun,
						  Scope& param_sc, Scope& fixed_sc)
{
	int dim(fun.nfuns());
	IntervalMatrix J(dim, param_sc__.size());

	if (param_sc__.size() > fun.nfuns()) {
		Scope param_sc_(param_sc__);

		// compute the midpoint of Jacobian matrix
		//Matrix Jtr(param_sc_.size(), dim);
		typedef std::list< sp<Vector> > Matrix;
		Matrix Jtr;
		for (int i(0); i < param_sc_.size(); ++i)
			Jtr.push_back(sp<Vector>(new Vector(dim)));

		Box box(dom_bx);
		Scope::const_iterator dit(dom_bx.scope()->begin());
		//for (; dit != dom_bx.scope()->end(); ++dit)
		//	box.set_interval(**dit, box.get_interval(**dit).midpoint());

		//IntervalVector dom(getProjValue(dom_bx, param_sc_));
		//setProjValue(box, dom, param_sc_);
		for (int i(0); i < dim; ++i) {
			fun[i]->eval(box);
			Scope::const_iterator dit(param_sc_.begin());
			Matrix::iterator mit(Jtr.begin());
			for (int j(0); dit != param_sc_.end(), mit != Jtr.end(); 
				 ++dit, ++mit, ++j) {
				(**mit)[i] = fun[i]->deriv(**dit).midpoint();
#if RPR_DEBUG
std::cout << ' ' << (**mit)[i];
#endif

				//J(i,j) = fun[i]->deriv(**dit);
#if RPR_DEBUG
std::cout << ' ' << J(i,j);
#endif
			}
#if RPR_DEBUG
std::cout << std::endl;
#endif
		}

		dit = param_sc_.begin();

		// first, take the largest vector
		double max_norm(0);
		Scope::const_iterator dit_(param_sc_.begin());
		Matrix::iterator mit(Jtr.begin()), mit_(Jtr.begin());
		for (; dit_ != param_sc_.end(), mit_ != Jtr.end(); 
			 ++dit_, ++mit_) {
			if (euclidean_norm(**mit_) > max_norm) {
				max_norm = euclidean_norm(**mit_);
				dit = dit_;
				mit = mit_;
			}
		}
//std::cout << *dit << std::endl;
		param_sc.insert(*dit);
		param_sc_.remove(**dit);

		sp<Vector> prev(*mit);
		Jtr.erase(mit);

		// in the followings, take the most orthogonal ones
		while (param_sc.size() < fun.nfuns()) {
			max_norm = 0;
			dit = param_sc_.begin(); dit_ = param_sc_.begin();
			mit = Jtr.begin(); mit_ = Jtr.begin();
			for (; dit_ != param_sc_.end(), mit_ != Jtr.end(); 
				 ++dit_, ++mit_) {
				Vector proj(*prev);
				proj *= prev->scalar_product(**mit_) / prev->scalar_product(*prev);
				**mit_ -= proj;
				if (euclidean_norm(**mit_) > max_norm) {
					max_norm = euclidean_norm(**mit_);
					dit = dit_;
					mit = mit_;
				}
			}
//std::cout << *dit << std::endl;
			param_sc.insert(*dit);
			param_sc_.remove(**dit);
			prev = *mit;
			Jtr.erase(mit);
		}

		dit = param_sc_.begin();
		for (; dit != param_sc_.end(); ++dit)
			fixed_sc.insert(*dit);
	}
	else { // param_sc_.size() == fun.nfuns()
		Scope::const_iterator dit(param_sc__.begin());
		for (int j(0); dit != param_sc__.end(); ++dit, ++j) {
			param_sc.insert(*dit);

			for (int i(0); i < dim; ++i)
				J(i,j) = fun[i]->deriv(**dit);
		}
	}

	//result.regularJu = regular(J);
}
*/

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

void jacobianProj(const Function& fun, const Scope& scope, const IntervalVector& v,
				  IntervalMatrix& J) {
	IntervalVector gr(v.size());
	for (int i=0; i < fun.image_dim(); i++) {
		fun[i].gradient(v, gr);
		for (int j=0; j < scope.size(); j++)
			J[i][j] = gr[scope[j]];
	}
}


static const double Tau(1.01);
//static constdouble Tau(1.0);
static const double Mu(0.9);
//static const double Mu(0.999999);

/**
 * inner testing procedure
 */
innerResult verifyInner(IntervalVector& dom_bx, const IntervalVector& bx_dom0, 
						const Scope& proj_sc, const Scope& param_sc, 
			 		    const Scope& cyclic_sc, 
					    Function& fun,
					    bool reduce_box, int infl_trial ) {

	//assert(param_sc.size() >= fun.image_dim());
	int dim(fun.image_dim());

	innerResult result;		
	result.regularJu = false;

	if (param_sc.size() < dim)
		return result;

#if RPR_DEBUG
	std::cout << std::endl;
	std::cout << "dom_bx" << std::endl;
	std::cout << dom_bx << std::endl;
#endif

	//Scope param_sc, fixed_sc;
	//fix_redundant_params(dom_bx, proj_sc, param_sc__, fun, param_sc, fixed_sc);

	const IntervalVector dom_orig(getProjValue(dom_bx, param_sc));
	IntervalVector dom(dom_orig);

#if RPR_CENTERED_FORM
	IntervalVector range(getProjValue(dom_bx, proj_sc));
	IntervalVector cnt_range(range - IntervalVector(range.mid()) );
#endif

	// extract the non-cyclic scope 
	//Scope non_cyclic_sc(param_sc);
	//non_cyclic_sc.set_difference(cyclic_sc);
	////non_cyclic_sc.set_difference(fixed_sc);
	Scope non_cyclic_sc;
	for (int i=0, j=0; i < param_sc.size();) {
//cout << "i: " << i << ", j: " << j << endl;
		if (j >= cyclic_sc.size() || param_sc[i] < cyclic_sc[j])
			non_cyclic_sc.push_back(param_sc[i++]);
		else if (param_sc[i] > cyclic_sc[j])
			j++;
		else { // param_sc[i] == cyclic_sc[j]
			non_cyclic_sc.push_back(param_sc[i++]); j++;
		}
	}

	double d(HUGE_VAL), d_prev(HUGE_VAL);

	int k(0);
	while (d > 0.0 && d <= Mu*d_prev 
		   && isSuperset(non_cyclic_sc, bx_dom0, dom)
		   && (infl_trial < 0 || k <= infl_trial)
		  ) {

		// Jacobian matrix
		IntervalMatrix J(dim, proj_sc.size());
		IntervalVector box(dom_bx);
		setProjValue(box, dom, param_sc);
		//fun.jacobian(box, J);
		jacobianProj(fun, param_sc, box, J);
		/*IntervalVector gr(dom_bx.size());
		for (int i=0; i < dim; i++) {
			fun[i].gradient(box, gr);
			for (int j=0; j < proj_sc.size(); j++)
				J[i][j] = gr[param_sc[j]];
		}*/

#if RPR_CENTERED_FORM
		IntervalMatrix Jcnt(dim, proj_sc.size());
		IntervalVector box1(dom_bx);
		setProjValue(box1, IntervalVector(dom.mid()), param_sc);
		jacobianProj(fun, param_sc, box1, Jcnt);
#endif

		// preconditioning
		IntervalMatrix C(dim, dim);
		Matrix realC(dim, dim);
		Matrix midJ(J.mid());
		try {
			real_inverse(midJ, realC);
		} 
		catch(SingularMatrixException&) {
			result.regularJu = false;
			return result;
		}
		C = IntervalMatrix(realC);

#if RPR_COND_NUM
		Matrix J_inv(dim, dim);
		try {
			real_inverse(midJ, J_inv)
		} 
		catch (SingularMatrixException&) {
			result.regularJu = false;
			return result;
		}
		result.cond = norm(J_inv) * norm(midJ);
#endif

		J = C * J;

		// cf. [Goldsztejn+, RC'10] Col.3.1
		IntervalVector mid( dom.mid() );
		IntervalVector mid_bx(dom_bx);
#if RPR_CENTERED_FORM
		mid_bx = dom_bx.mid();
#endif
		setProjValue(mid_bx, mid, param_sc);

		IntervalVector midFun(dim);
		midFun = fun.eval_vector(mid_bx);

		IntervalVector gamma(dom);
		try {
			gamma = gaussSeidel(J, dom - mid, 
#if !(RPR_CENTERED_FORM)
								C * (-midFun)
#else
								C * (-midFun) - (C*Jcnt) * cnt_range
#endif
				);
		} catch (const std::runtime_error& err) {
#if RPR_DEBUG
std::cout << err.what() << std::endl;
#endif

			// some element of J contains 0
			result.regularJu = false;
			return result;
		}
		IntervalVector contracted(mid + gamma);

		result.regularJu = regular(J);

#if RPR_DEBUG
		std::cout << std::endl;
		std::cout << "k:  " << k << std::endl;
		std::cout << "J:  " << J << std::endl;
		std::cout << "C:  " << C << std::endl;
		std::cout << "Y:  " << dom << std::endl;
		std::cout << "Y': " << contracted << std::endl;
		std::cout << "inclusion: " << dom.is_strict_superset(contracted) << std::endl;
#endif

		// TODO
		if (contracted.is_empty())
			//break;
			throw(std::runtime_error("contracted to empty interval!"));

		if ( dom.is_strict_superset(contracted) && 
			 isSuperset(non_cyclic_sc, bx_dom0, dom) ) {
//std::cout << "inner: " << contracted.width() / dom.width() << std::endl;

			if (reduce_box) {
				setProjValue(dom_bx, contracted, param_sc);
#if RPR_COND_NUM
				dom_bx.cond_number = result.cond;
#endif
			}

//std::cout << "contracted" << std::endl;
			result.regular = true;
			return result;
		}

		// TODO
		if (reduce_box) {
			IntervalVector reduced( dom_orig & contracted );
			if (!reduced.is_empty())
				setProjValue(dom_bx, reduced, param_sc);

#if RPR_COND_NUM
			dom_bx.cond_number = result.cond;
#endif
		}

		// domain inflation
		d_prev = d;
		d = ibex::distance(dom, contracted);
#if RPR_DEBUG
		std::cout << "d:  " << d << ", d-: " << Mu*d_prev << std::endl;
#endif
		// TODO
		//if (d == 0.0) throw(std::runtime_error("no contraction!"));

		dom = contracted - IntervalVector(contracted.mid());
		dom *= Interval(Tau);
		dom = IntervalVector(contracted.mid()) + dom;

		++k;
	}

#if RPR_DEBUG
	std::cout << "inner box verification done" << std::endl;
#endif

	return result;
}

// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
