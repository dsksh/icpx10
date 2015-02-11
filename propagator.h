#include <cassert>

#include <stdio.h>
#include <sys/time.h>
#include <sys/resource.h>

#include "prover.h"

const double ContrURate = 0.2;

namespace rp
{

	class PropagatorWithAspectDetection : public Propagator
	{
	public:
		/**
		 * Class constructor
		 */
		PropagatorWithAspectDetection(const sp<ControlPropagator> pc,
									  sp<Scope> proj_sc, sp<Scope> param_sc,
									  sp<Scope> cyclic_sc,
									  sp<IntervalFunctionVector> fun,
									  const int nbors_thres,
									  bool take_infl_box,
									  int infl_trial )
			: Propagator(pc),
			  proj_sc_(proj_sc), param_sc_(param_sc), cyclic_sc_(cyclic_sc), fun_(fun),
			  nbors_thres_(nbors_thres),
			  take_infl_box_(take_infl_box),
			  infl_trial_(infl_trial)
		{
			// Operator name
			Propagator::set_name("PropagatorWithAspectDetection");
		}

		/**
		 * Base class contraction method such that all the operators in self
		 * are active at the beginning
		 * @param bx the box to be contracted
		 * @return the solution flag
		 */
		Solution contract(Box& bx)
		{
//struct timeval s, e;
//gettimeofday(&s, NULL);
//std::cout << std::endl << bx << std::endl;

			//IntervalVector bx_bak (get_interval_vector(bx, *bx.scope()));
			IntervalVector bx_orig(get_interval_vector(bx, *param_sc_));
			IntervalVector bx_orig_x(get_interval_vector(bx, *proj_sc_));
			Solution sol( Propagator::contract(bx) );
			// used for the inflation examples:
			//Solution sol( Solution::maybe() );

			if (sol == Solution::no() || bx.is_empty()) {
//gettimeofday(&e, NULL);
//printf("time = %lf\n", (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec)*1.0E-6);

				bx.set_empty();
				return Solution::no();
			}


			if (sol != Solution::only()) {
				inner_result res( inner(bx, *proj_sc_, *param_sc_, *cyclic_sc_, *fun_, 
								  take_infl_box_, infl_trial_) );

//gettimeofday(&e, NULL);
//printf("time = %lf\n", (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec)*1.0E-6);

				// TODO
				if (bx.is_empty())
					return Solution::no();

				if ( res.regular ) {
					sol = Solution::only();

					// TODO: kludge for termination
					//IntervalVector contracted(get_interval_vector(bx, *param_sc_));
					//set_interval_vector(bx, bx_orig & contracted, *param_sc_);

					// TODO
					if (bx.is_empty())
						return Solution::no();
				}
				else if ( res.regular_Ju ) {

					sol = Solution::regular();
				}
				//else if ( is_contracted_x && !res.regular_Ju ) {
				// TODO
#if MANAGE_NEIGHBORS
#if !MANAGE_NEIGHBORS_VECTOR
				else if ( nbors_thres_ >= 1 ? bx.get_neighbors().size() >= nbors_thres_ : false ) {
#else
				else if ( nbors_thres_ >= 1 ? bx.get_vec_count() >= nbors_thres_ : false ) {
//std::cout << bx.get_vec_count() << std::endl;
#endif
				//else if ( is_contracted_u ) {

//std::cout << "singular" << std::endl;
					sol = Solution::singular();
				}
#endif

				sol.cond = res.cond;
			}

			return sol;
		}

	protected:
		sp<Scope> proj_sc_;
		sp<Scope> param_sc_;
		sp<Scope> cyclic_sc_;
		sp<IntervalFunctionVector> fun_;
		const int nbors_thres_;
		const bool take_infl_box_;
		const int infl_trial_;
	};


	class PropagatorDomainConstraint : public PropagatorWithAspectDetection
	{
	public:
		/**
		 * Class constructor
		 */
		PropagatorDomainConstraint(const sp<ControlPropagator> pc,
								   sp<Scope> proj_sc, sp<Scope> param_sc, 
								   sp<Scope> cyclic_sc,
								   sp<IntervalFunctionVector> fun,
								   const int nbors_thres,
								   bool take_infl_box,
								   int infl_trial,
								   sp<IntervalFunction> constr_fun)
			: PropagatorWithAspectDetection(pc, proj_sc, param_sc, cyclic_sc, fun, 
											nbors_thres, 
											take_infl_box,
											infl_trial),
		      constr_fun_(constr_fun)
		{
			// Operator name
			Propagator::set_name("PropagatorDomainConstraint");
		}

		/**
		 * Base class contraction method such that all the operators in self
		 * are active at the beginning
		 * @param bx the box to be contracted
		 * @return the solution flag
		 */
		Solution contract(Box& bx)
		{
			Solution sol( PropagatorWithAspectDetection::contract(bx) );

			if (sol != Solution::no()) {
				//Interval val( constr_fun_->eval(bx) );
				Interval val( constr_fun(bx) );
#if RPR_DEBUG
std::cout << "g: " << val << std::endl;
#endif
				if (val.is_empty() 
					|| val.right() < 0
					) {
					bx.set_empty();
					return Solution::no();
				}
				else if (val.is_superset(0.0)) {
					//if (sol == Solution::only())
						return Solution::maybe();
				}
			}
			return sol;
		}

		Interval constr_fun(const Box& bx) {
			static const Interval Cx(3);
			static const Interval Cy(1);
			static const double R(1);

			IntervalVector A(2), C(2);
			const IntervalVector u(get_interval_vector(bx, *param_sc_));
			A[0] = u[0]; A[1] = u[0];
			IntervalVector B( get_interval_vector(bx, *proj_sc_) );
			C[0] = Cx; C[1] = Cy;

			Interval dist;
			if (dot(B - A, C - A).right() < 0) {
				dist = dot(C - A, C - A);
			}
			else if (dot(A - B, C - B).right() < 0) {
				dist = dot(C - B, C - B);
			}
			else {
				dist = 
					//dot(C - A, C - A) - sqr(dot(B - A, C - A))
					sqr( (B-A)[0] * (C-A)[1] - (B-A)[1] * (C-A)[0] )
					/ dot(B - A, B - A);
			}

			return dist - R*R;
		}

	private:
		sp<IntervalFunction> constr_fun_;
	};
}
