
#include <cfloat>

#include <x10/lang/String.h>

// x10aux::math undefines HUGE_VAL
#ifndef HUGE_VAL
#define HUGE_VAL (DBL_MAX*DBL_MAX)
#endif
#include "realpaver"

#include "Solver__Core.h"
#include "x10/util/MyHashMap__KeyIterator.h"

using namespace std;
//using namespace rp;

RTT_CC_DECLS0(Solver__Core, "Solver.Core", x10aux::RuntimeType::class_kind)

Solver__Core *Solver__Core::_make() {
	return new Solver__Core();
}

void Solver__Core::initialize(x10::lang::String *filename) {
	//string filename(problem->filename()->c_str());
    rp::Parser parser(filename->c_str());
	//Timer tim;
	bool result;

	try {
		// parsing
	    //tim.start();
	    result = parser.parse();
	    //tim.stop();
	}
	catch (rp::Exception e) {
		cerr << "Parse error in file " << filename
		     << " at line " << parser.lineno() << endl;
		cerr << "  -> semantic error: " << e.what();
		//return EXIT_FAILURE;
        return;
	}

	if (!result) {
		cerr << "Parse error in file " << filename
		     << " at line " << parser.lineno() << endl;
		cerr << "  -> syntax error: " << parser.token_on_error() << endl;
		//return EXIT_FAILURE;
        return;
	} 

	// ----------------------------------------------------------------------
	// creation of propagator
	// ----------------------------------------------------------------------
    rp::sp< rp::ControlPropagator> control = new rp::QueueControlPropagator(10);
	rp::sp< rp::Propagator > propag = new rp::Propagator(control);
    rp::FactoryHullBoxOperator facto(10,5);
	rp::FactoryOperator::vector_type vop;
	facto.generate(*parser.problem(),vop);
	propag->insert(vop);
  
    // creation of Newton operator
    rp::FactoryMultiNewtonOperator facto_nwt(10);
    rp::FactoryOperator::vector_type vop_nwt;
    facto_nwt.generate(*parser.problem(),vop_nwt);
  
    // creation of solver contractor
    rp::sp< rp::SequenceOperator > contractor = new rp::SequenceOperator();
    contractor->insert(propag);
    if (vop_nwt.size())
    { 
        contractor->insert(vop_nwt[0]);
    }

    // ----------------------------------------------------------------------
    
    // creation of splitting function
    //sp< Split > split = new SplitMidpoint();
    
    // creation of variable selection function
    //sp< SplitSelect > select = new SplitSelectRoundRobin(new SplitTestLocal(),
    //                             parser.problem()->scope());

    // creation of solver
    //Solver solver(parser.problem(), contractor, split, select);

    nsol_ = 0;
    nsplit_ = 0;
    currentSol_ = 0;
    contractor_ = contractor;

    split_ = new rp::SplitMidpoint();
    selector_ = new rp::SplitSelectRoundRobin(new rp::SplitTestLocal(),
                       parser.problem()->scope());
    list_ = new rp::SearchStrategyDFS();
    list_->insert(new rp::Box(parser.problem()->scope()),selector_,0);
    list_->init();
}

// util
IntervalVec *getIVFromBox(const rp::Box& box) {
    IntervalVec *iv = IntervalVec::_make();

    rp::Scope::const_iterator it = box.scope()->begin();
    for (; it != box.scope()->end(); ++it) {
        rp::Interval i = box.get_interval(**it);
        Interval si = Interval::_make(i.left(), i.right());
        iv->put(x10::lang::String::_make((*it)->name().c_str(), true), si);
    }

    return iv;
}

// util
void setIVIntoBox(rp::Box& box, IntervalVec& iv) {
    rp::Scope::const_iterator it = box.scope()->begin();
    for (int i = 0; it != box.scope()->end(); ++it, ++i) {
        Interval si = iv.getOrThrow(x10::lang::String::_make((*it)->name().c_str(), true));
        rp::Interval i(si.FMGL(left), si.FMGL(right));
        box.set_interval(**it, i);
    }
}

IntervalVec *Solver__Core::getInitialDomain() {
    /*Solver__IntervalVec *iv = Solver__IntervalVec::_make();

    sp<Box> sbx = list_->get_cell()->box;
    Scope::const_iterator it = sbx->scope()->begin();
    for (; it != sbx->scope()->end(); ++it) {
        Interval i = dynamic_cast<const Interval&>((*it)->domain());
        Solver__Interval si = Solver__Interval::_make(i.left(), i.right());
        iv->put(x10::lang::String::_make((*it)->name().c_str(), true), si);
    }

    return iv;
    */
    rp::sp< rp::Box > sbx = list_->get_cell()->box;
    return getIVFromBox(*sbx);
}

x10_int Solver__Core::solve() {
    // solving
    //tim.restart();
    rp::Solution s;
    do {
        list_->update();
        while (!list_->empty()) {
            s = calculateNext();
        }
        cout << "Solution " << nsol() //<< " (" << tim << " s)" 
            << endl << *currentSolution() << endl << endl; 
    }
    while (s != rp::Solution::no());

    cout << nsol() << " solution(s)" << endl
         << nsplit() << " split(s)" << endl
         //<< tim << " s" << endl
         ;

    return EXIT_SUCCESS;
}


rp::Solution Solver__Core::calculateNext() {
    //list_->update();
    //while (!list_->empty()) {
        rp::sp< rp::BoxCell > cell = extract();
        rp::sp< rp::Box > sbx = cell->box;
      
        if (sbx->is_empty()) 
            //continue;
            calculateNext();

        // apply the contractor to the current item
        rp::Solution sol = contractor_->contract(*sbx);

        RP_DEBUG("apres contraction\n" << *sbx);

        if (sol != rp::Solution::no()) {
#if MANAGE_NEIGHBORS || MANAGE_HIDDEN_NEIGHBORS
            //cell->box = sbx;
    	    updateNeighbors(sol, *cell);
#endif

        	// split?
        	const rp::Variable *v = cell->split_select->next(sol, *sbx);
        	if (v) {
//if (!v->is_projected())
                ++nsplit_;

            	RP_DEBUG("split : " << v->name());
//std::cout << std::endl << "split:" << v->name() << std::endl;

            	// domain of v has to be split
                rp::Split::vector_type split_bx;
            	split_->apply(sbx,*v,split_bx);
            
            	// insert the new regions in the search space
                rp::Split::vector_type::const_iterator iter;
            	for (iter=split_bx.begin(); iter!=split_bx.end(); ++iter) {
                    //cell_list::iterator pos;
                    list_->insert(*iter, cell->split_select->clone(), v);
                }
            }
            else {
                //std::cout << "solution" << *sbx << std::endl;
                // one more solution
                postProcess(sol, sbx);
                // TODO
                //sbx->update_neighbors();
                return sol;
            }
        }
}

Solver__Result Solver__Core::contract(IntervalVec *iv) {
    rp::Box box( *list_->get_cell()->box );
    setIVIntoBox(box, *iv);
//std::cout << std::endl << "extracted:" << std::endl << box << std::endl;
    //x10::util::MyHashMap__KeyIterator<x10::lang::String*, Interval> *vit = iv->FMGL(vit);

    rp::Solution sol = contractor_->contract(box);
    *iv = *getIVFromBox(box);

    //iv->FMGL(vit) = vit;

    if (sol == rp::Solution::no())
        return Solver__Result::noSolution();
    else
        return Solver__Result::unknown();
}

rp::sp<rp::BoxCell> Solver__Core::extract() {

    rp::sp<rp::BoxCell> cell = list_->get_cell();
    list_->remove();

    rp::sp<rp::Box> sbx = cell->box;
//std::cout << std::endl << "extracted:" << std::endl << *sbx << std::endl;
//std::cout << std::endl << "extracted:" << std::endl << sbx->width() << std::endl;
//assert(sbx->width() <= w_bak);
//w_bak = sbx->width();
    
#if PROJ_LOGGING
    //print_prof_data();
#endif

#if SETDIFF_EXTRACT
    //IntervalVector before( get_interval_vector(*sbx, *sbx->scope()) );
#  if SD_CHEAP
    sd_prune_cheap(*sbx);
#  else
    sd_prune(*cell);
#  endif
    //assert( before.is_superset( get_interval_vector(*sbx, *sbx->scope()) ) );
#endif

    return cell;
}
  
#if SETDIFF_EXTRACT
void Solver__Core::sd_prune_cheap(Box& sbx) {
    rp::Box::neighbor_list& neighbors = sbx.get_neighbors();
//std::cout << "nbors: " << neighbors.size() << std::endl;
    
# if PROJ_LOGGING
    if (neighbors.size() > nl_length_max)
        nl_length_max = neighbors.size();
    nl_length_total += neighbors.size();
    nl_length_count++;
# endif
    
    rp::Box::neighbor_list::const_iterator it( neighbors.begin() );
    for (int c(0); it != neighbors.end(); ++it, ++c) {
# if MANAGE_NEIGHBORS_VECTOR
        if (rp::Box::is_empty_cell(*it)) 
            //continue;
            calculateNext();
# endif
      
        rp::Box& nbor(*it->first);
      
        if (nbor.is_solution)
	        if (set_difference_cheap(sbx, nbor)) {
	            if (!sbx.is_empty())
            	    sd_prune_cheap(sbx);
                	break;
        	}
    }
}
  
void Solver__Core::sd_prune(BoxCell& cell) {
    rp::sp<rp::Box> sbx = cell.box;
    rp::Box::neighbor_list& neighbors = sbx->get_neighbors();
//std::cout << "nbors: " << neighbors.size() << std::endl;
    
# if PROJ_LOGGING
    if (neighbors.size() > nl_length_max)
        nl_length_max = neighbors.size();
    nl_length_total += neighbors.size();
    nl_length_count++;
# endif

    rp::Box::neighbor_list::const_iterator it( neighbors.begin() );
    for (int c(0); it != neighbors.end(); ++it, ++c) {
#if MANAGE_NEIGHBORS_VECTOR
        if (rp::Box::is_empty_cell(*it)) continue;
#endif

        rp::Box& neighbor(*it->first);

        if (neighbor.is_solution) {
            rp::BoxVec bv( set_difference(*sbx, neighbor) );

            if (bv.empty()) { // included in the neighbor
                sbx->set_empty();
            }
            else {
                rp::BoxVec::iterator bv_it( bv.begin() );
                cell.box = *bv_it; ++bv_it;

                for (; bv_it != bv.end(); ++bv_it) {
                    rp::sp<rp::BoxCell> c(new rp::BoxCell(*bv_it, cell.split_select->clone(), cell.variable));
                    list_->insert(c);
                }
                sd_prune(cell);
            }

            break;
        }
    }
}
#endif


void Solver__Core::postProcess(const rp::Solution& sol, rp::sp<rp::Box> sbx) {

    ++nsol_;
    currentSol_ = sbx;
    list_->solution(sbx);
    
#if SETDIFF_EXTRACT
    if (sol == rp::Solution::only()) {
        sbx->is_solution = true;
        solutions.push_back(sbx);
    }
#endif
    
#if PROJ_LOGGING && (SETDIFF_EXTRACT || MANAGE_HIDDEN_NEIGHBORS)
    timer.stop();
    if (sol == rp::Solution::only()) {
        //volume += sbx->volume(*v_scope);
        volume += calculate_volume1(*this, *sbx, *v_scope);
      
# if !SETDIFF_EXTRACT
        sbx->is_solution = true;
        solutions.push_back(sbx);
# endif
    }
    timer.start();
#endif
}
  

#if MANAGE_NEIGHBORS || MANAGE_HIDDEN_NEIGHBORS
void Solver__Core::updateNeighbors(const rp::Solution& sol, rp::BoxCell& cell) {

# if !SETDIFF_PROVED
#   if MANAGE_HIDDEN_NEIGHBORS
    timer.stop();
    cell.box->update_hidden_neighbors();
    timer.start();
#   else
    cell.box->update_neighbors();
#   endif
    return;

# else // SETDIFF_PROVED

    rp::sp< rp::Box > box(cell.box);
//std::cout << "update: " << *box << ", " << (sol == Solution::only()) << std::endl;

    rp::Box::neighbor_list& neighbors = box->get_neighbors();
//std::cout << neighbors.size() << std::endl;
    rp::Box::neighbor_list::iterator it( neighbors.begin() );
    for (; it != neighbors.end(); ) {
//std::cout << std::endl << "bx:" << std::endl << *it->first << std::endl;

        if (!box->is_close(*it->first, 0.0, true)) {
            it->first->remove_neighbor(it->second);
            it = neighbors.erase(it);
        }
        else {
            if (sol != rp::Solution::only())
                ++it;
            else {
                // compute set difference.
                rp::Box& neighbor(*it->first);

                neighbor.remove_neighbor(it->second);
                it = neighbors.erase(it);

#   if SD_CHEAP
                set_difference_cheap(neighbor, *box);
#   else
                rp::BoxVec bv( set_difference(neighbor, *box) );
                rp::BoxVec::iterator bv_it( bv.begin() );
                for (; bv_it != bv.end(); ++bv_it) {
                    rp::sp<rp::BoxCell> c(new rp::BoxCell(*bv_it, cell.split_select->clone(), cell.variable));
                    list_->insert_before(neighbor, c);
                }
                list_->remove(neighbor);
#   endif
            }
        }
    }
# endif // !SETDIFF_PROVED
}
#endif
// vim: shiftwidth=4:tabstop=4:softtabstop=0:expandtab
