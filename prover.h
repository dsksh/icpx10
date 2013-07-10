namespace rp
{
	struct inner_result
	{
		inner_result()
		: regular(false), regular_Ju(false), cond(0)
		{}

		bool regular;
		bool regular_Ju;

		REAL cond;
	};

	bool regular(const IntervalMatrix& J);

	/// inner testing procedure
	inner_result inner(Box& dom_bx, const Scope& proj_sc, const Scope& param_sc__, 
					   const Scope& cyclic_sc, 
					   IntervalFunctionVector& fun,
					   bool reduce_box, int infl_trial);
}
