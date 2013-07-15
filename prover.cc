#include <list>
#include <cmath>
#include <iostream>
#include <sstream>
#include <cassert>

#include "realpaver"
#include "rp_interval.h"

#include "config.h"
//#include "util.h"
#include "prover.h"

namespace rp {

	bool is_superset(const Scope& scope, const IntervalVector& vec)
	{
		Scope::const_iterator it(scope.begin());
		for (SIZE_TYPE i(0); i < scope.size() && i < vec.size(); ++it, ++i)
		{
			try {
				Interval& intv = dynamic_cast<Interval&>((*it)->domain());
				if (!intv.is_superset(vec[i]))
					return false;
			} 
			catch (const std::bad_cast&) {
				//return false;
				throw("initial domain is a point!");
			}
		}
		return true;
	}

	/// interval Gauss-Seidel operator
	IntervalVector GaussSeidel(const IntervalMatrix& J, 
							   const IntervalVector& a, const IntervalVector& b)
	{
		int dim(a.size());

		// diagonal inverse matrix of J
		IntervalMatrix DiagJ(dim, dim);
		for (SIZE_TYPE i(0); i < dim; ++i)
		{
			if (J(i,i).is_superset(Interval(0.0)))
				throw(std::runtime_error("singular matrix!"));

			DiagJ(i, i) = 1 / J(i, i);
		}

		// off-diagonal matrix of J
		IntervalMatrix OffJ(dim, dim);
		for (SIZE_TYPE i(0); i < dim; ++i)
			for (SIZE_TYPE j(0); j < dim; ++j)
				if (i != j)
					OffJ(i, j) = J(i, j);
			
		return DiagJ * (b - OffJ*a);
	}


	bool regular(const IntervalMatrix& J)
	{
		int dim(J.nrows());

		const RealMatrix midJ(J.midpoint());

		// inverse of the center of J
		RealMatrix Inv(J.ncols(), J.nrows());
		if (J.nrows() == J.ncols()) {
			if (!midJ.inverse(Inv))
				return false;
		} else {
			RealMatrix Inv_(dim, dim);
			if (!RealMatrix(midJ * midJ.transpose()).inverse(Inv_))
				return false;
			Inv = midJ.transpose() * Inv_;

			//RealMatrix Inv_(J.ncols(), J.ncols());
			//if (!RealMatrix(midJ.transpose() * midJ).inverse(Inv_)) {
			//	return false;
			//}
			//Inv = Inv_ * midJ.transpose();
		}

		//J = IntervalMatrix(Inv) * J;
		IntervalMatrix CJ(J * IntervalMatrix(Inv));

		bool res(true);
		for (SIZE_TYPE i(0); i < dim; ++i)
		{
			REAL mag(0.0);
			for (SIZE_TYPE j(0); j < dim; ++j)
			{
#if RPR_DEBUG
std::cout << ' ' << CJ(i,j);
#endif
				if (i != j)
					mag += CJ(i,j).mag();
			}
#if RPR_DEBUG
std::cout << std::endl;
#endif

#if RPR_DEBUG
			std::cout << CJ(i,i).mig() << " vs "<< mag << std::endl;
#endif

			if (CJ(i,i).mig() <= mag)
#ifndef RPR_DEBUG
				return false;
#else
				res = false;
#endif
		}

#ifndef RPR_DEBUG
		return true;
#else
		return res;
#endif
	}


	inline double euclidean_norm(const RealVector& vec)
	{
		double r(0);
		for (SIZE_TYPE i=0; i<vec.size(); ++i)
			r += vec[i]*vec[i];
		return std::sqrt(r);
	}


	void fix_redundant_params(const Box& dom_bx, 
							  const Scope& proj_sc, const Scope& param_sc__, 
							  IntervalFunctionVector& fun,
							  Scope& param_sc, Scope& fixed_sc)
	{
		int dim(fun.nfuns());
		IntervalMatrix J(dim, param_sc__.size());

		if (param_sc__.size() > fun.nfuns()) {
			Scope param_sc_(param_sc__);

			// compute the midpoint of Jacobian matrix
			//RealMatrix Jtr(param_sc_.size(), dim);
			typedef std::list< sp<RealVector> > Matrix;
			Matrix Jtr;
			for (SIZE_TYPE i(0); i < param_sc_.size(); ++i)
				Jtr.push_back(sp<RealVector>(new RealVector(dim)));

			Box box(dom_bx);
			Scope::const_iterator dit(dom_bx.scope()->begin());
			//for (; dit != dom_bx.scope()->end(); ++dit)
			//	box.set_interval(**dit, box.get_interval(**dit).midpoint());

			//IntervalVector dom(get_interval_vector(dom_bx, param_sc_));
			//set_interval_vector(box, dom, param_sc_);
			for (SIZE_TYPE i(0); i < dim; ++i) {
				fun[i]->eval(box);
				Scope::const_iterator dit(param_sc_.begin());
				Matrix::iterator mit(Jtr.begin());
				for (SIZE_TYPE j(0); dit != param_sc_.end(), mit != Jtr.end(); 
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
			REAL max_norm(0);
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

			sp<RealVector> prev(*mit);
			Jtr.erase(mit);

			// in the followings, take the most orthogonal ones
			while (param_sc.size() < fun.nfuns()) {
				max_norm = 0;
				dit = param_sc_.begin(); dit_ = param_sc_.begin();
				mit = Jtr.begin(); mit_ = Jtr.begin();
				for (; dit_ != param_sc_.end(), mit_ != Jtr.end(); 
					 ++dit_, ++mit_) {
					RealVector proj(*prev);
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
			for (SIZE_TYPE j(0); dit != param_sc__.end(); ++dit, ++j) {
				param_sc.insert(*dit);

				for (SIZE_TYPE i(0); i < dim; ++i)
					J(i,j) = fun[i]->deriv(**dit);
			}
		}

		//result.regular_Ju = regular(J);
	}


	static const double Tau(1.01);
	//static constdouble Tau(1.0);
	static const double Mu(0.9);
	//static const double Mu(0.999999);

	/**
	 * inner testing procedure
	 */
	inner_result inner(Box& dom_bx, const Scope& proj_sc, const Scope& param_sc__, 
					   const Scope& cyclic_sc, 
					   IntervalFunctionVector& fun,
					   bool reduce_box, int infl_trial )
	{
		assert(param_sc__.size() >= fun.nfuns());
		//assert(param_sc_.size() <= fun.nfuns()+1);
		int dim(fun.nfuns());

		inner_result result;		
		result.regular_Ju = false;

#if RPR_DEBUG
		std::cout << "dom_bx" << std::endl;
		std::cout << dom_bx << std::endl;
#endif

		///

		Scope param_sc, fixed_sc;
		fix_redundant_params(dom_bx, proj_sc, param_sc__, fun, param_sc, fixed_sc);

		const IntervalVector dom_orig(get_interval_vector(dom_bx, param_sc));
		IntervalVector dom(get_interval_vector(dom_bx, param_sc));

#if RPR_CENTERED_FORM
		IntervalVector range(get_interval_vector(dom_bx, proj_sc));
		IntervalVector cnt_range(range - IntervalVector(range.midpoint()) );
#endif

		// extract the non-cyclic scope 
		Scope non_cyclic_sc(param_sc);
		non_cyclic_sc.set_difference(cyclic_sc);
		//non_cyclic_sc.set_difference(fixed_sc);

		double d(HUGE_VAL), d_prev(HUGE_VAL);

//#if RPR_DEBUG
//		std::cout << dom_bx << std::endl;
//#endif

		int k(0);
		// TODO
		while (d > 0.0 && d <= Mu*d_prev 
			   && is_superset(non_cyclic_sc, dom)
			   && (infl_trial < 0 || k <= infl_trial)
			)
		{

			// Jacobian matrix
			IntervalMatrix J(dim, dim);
			Box box(dom_bx);
			set_interval_vector(box, dom, param_sc);
#if RPR_CENTERED_FORM
			IntervalMatrix dxf(dim, proj_sc.size());
			Box box1(dom_bx);
			set_interval_vector(box1, IntervalVector(dom.midpoint()), param_sc);
#endif

/*			// fix the value
			Scope::const_iterator dit(fixed_sc.begin());
			for (; dit != fixed_sc.end(); ++dit) {
				box.set_interval(**dit, box.get_interval(**dit).midpoint());
			}
#if RPR_CENTERED_FORM
			dit = fixed_sc.begin();
			for (; dit != fixed_sc.end(); ++dit) {
				box1.set_interval(**dit, box1.get_interval(**dit).midpoint());
			}
#endif
*/
			for (SIZE_TYPE i(0); i < dim; ++i)
			{
				fun[i]->eval(box);
				Scope::const_iterator dit(param_sc.begin());
				for (SIZE_TYPE j(0); dit != param_sc.end(); ++dit, ++j) {
					J(i,j) = fun[i]->deriv(**dit);
				}
#if RPR_CENTERED_FORM
				fun[i]->eval(box1);
				dit = proj_sc.begin();
				for (SIZE_TYPE j(0); dit != proj_sc.end(); ++dit, ++j) {
					dxf(i,j) = fun[i]->deriv(**dit);
				}
#endif
			}

/*#if RPR_COND_NUM
			IntervalMatrix dxf1(dim, dim);
			for (SIZE_TYPE i(0); i < dim; ++i)
			{
				fun[i]->eval(box);
				Scope::const_iterator dit(proj_sc.begin());
				for (SIZE_TYPE j(0); dit != proj_sc.end(); ++dit, ++j)
				{
					dxf1(i,j) = fun[i]->deriv(**dit);
				}
			}
#endif*/

			// preconditioning
			IntervalMatrix C(dim, dim);
			RealMatrix realC(dim, dim);
			RealMatrix midJ(J.midpoint());
			if (!midJ.inverse(realC)) {
				result.regular_Ju = false;
				return result;
				//break;
			}
			C = IntervalMatrix(realC);

#if RPR_COND_NUM
			/*RealMatrix mid_dxf(dxf1.midpoint());
			RealMatrix dudx_inv(dim, dim, 0.0); // is zero, initially
			RealMatrix dudx( dudx_inv - mid_dxf * C );
			if (!dudx.inverse(dudx_inv))
				return result;
			result.cond = dudx_inv.norm() * dudx.norm();
			*/

			RealMatrix mid_J(J.midpoint());
			RealMatrix J_inv(dim, dim);
			if (!mid_J.inverse(J_inv)) {
				result.regular_Ju = false;
				return result;
				//break;
			}
			result.cond = J_inv.norm() * mid_J.norm();

#endif

//std::cout << "regular J" << std::endl;

			J = C * J;

			// cf. Col.3.1
			IntervalVector mid( dom.midpoint() );
			Box mid_bx(dom_bx);
#ifndef RPR_CENTERED_FORM
			set_interval_vector(mid_bx, mid, param_sc);
#else
			dom_bx.midpoint(mid_bx);
			set_interval_vector(mid_bx, mid, param_sc);
#endif

			IntervalVector mid_fun;
			mid_fun.resize(dim);
			for (SIZE_TYPE i(0); i < dim; ++i)
				mid_fun[i] = fun[i]->eval(mid_bx);

			IntervalVector gamma;
			try {
				gamma = GaussSeidel(J, dom - mid, 
#ifndef RPR_CENTERED_FORM
									C * (-mid_fun)
#else
									C * (-mid_fun) - (C*dxf) * cnt_range
#endif
					);
			}
			catch (const std::runtime_error& err) {
#if RPR_DEBUG
std::cout << err.what() << std::endl;
#endif

				// some element of J contains 0
				result.regular_Ju = false;
				return result;
				//break;
			}
			IntervalVector contracted(mid + gamma);

//std::cout << "J not contain 0" << std::endl;

			//if (k == 0)
				result.regular_Ju = regular(J);
			//else
			//	result.regular_Ju = false;

#if RPR_DEBUG
			std::cout << std::endl;
			std::cout << "k:  " << k << std::endl;
			std::cout << "J:  " << J << std::endl;
			std::cout << "C:  " << C << std::endl;
			//std::cout << "mu: " << mid_bx << std::endl;
			//std::cout << "mf: " << mid_fun << std::endl;
			std::cout << "Y:  " << dom << std::endl;
			std::cout << "Y': " << contracted << std::endl;
			std::cout << "inclusion: " << dom.is_strict_superset(contracted) << std::endl;
#endif

			// TODO
			if (contracted.is_empty())
				//break;
				throw("contracted to empty interval!");

			if ( dom.is_strict_superset(contracted) && 
				 is_superset(non_cyclic_sc, dom) ) 
			{
//std::cout << "inner: " << contracted.width() / dom.width() << std::endl;

				if (reduce_box) {
					set_interval_vector(dom_bx, contracted, param_sc);
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
					set_interval_vector(dom_bx, reduced, param_sc);

#if RPR_COND_NUM
				dom_bx.cond_number = result.cond;
#endif
			}


			// domain inflation
			d_prev = d;
			// TODO
			d = distance(dom, contracted);
#if RPR_DEBUG
			std::cout << "d:  " << d << ", d-: " << Mu*d_prev << std::endl;
#endif
			// TODO
			//if (d == 0.0) throw("no contraction!");

			++k;

			dom = contracted - IntervalVector(contracted.midpoint());
			dom *= Interval(Tau);
			dom = IntervalVector(contracted.midpoint()) + dom;
		}

		//continue;
		//}

		return result;
	}
}
