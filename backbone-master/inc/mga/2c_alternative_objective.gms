$ontext
This file is part of Backbone.

Backbone is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Backbone is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with Backbone.  If not, see <http://www.gnu.org/licenses/>.
$offtext


* =============================================================================
* --- Objective Function Definition -------------------------------------------
* =============================================================================


q_obj ..

    + v_obj                                                                    

    =E=

    // Sum over all the samples, forecasts, and time steps in the current model
    + sum(sft(s, f, t),
        // Probability (weight coefficient) of (s, f, t)
        + p_sft_probability(s, f, t)
            * [
                // Time step length dependent costs
                + p_stepLength(t)                                         // length of time interval (h)
                    * [

                        + //1e6 *                                                 // increase penalty terms by factor of 1e6
                              (
                                  // Dummy variable penalties
                                  // Energy balance feasibility dummy varible penalties
                                  + sum(inc_dec,
                                      + sum(gn(grid, node),
                                          + vq_gen(inc_dec, grid, node, s, f, t)
                                              *( PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
                                              + ts_node_(grid, node, 'balancePenalty', s, f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
                                                )
                                          ) // END sum(gn)
                                      ) // END sum(inc_dec)

                                  // Reserve provision feasibility dummy variable penalties
                                  + sum(restypeDirectionGroup(restype, up_down, group),
                                      + vq_resDemand(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
                                          * PENALTY_RES(restype, up_down)
                                      + vq_resMissing(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)${ ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t) }
                                          * PENALTY_RES_MISSING(restype, up_down)
                                      ) // END sum(restypeDirectionNode)
          
                                  // Capacity margin feasibility dummy variable penalties
                                  + sum(gn(grid, node)${ p_gn(grid, node, 'capacityMargin') },
                                      + vq_capacity(grid, node, s, f, t)
                                          * PENALTY_CAPACITY(grid, node)
                                      ) // END sum(gn)
                              ) 

                    // weighted sum of generation, if generationWeight_MGA is used
                    + sum(group$p_groupPolicy(group, 'generationWeight_MGA'),  // sum over groups, for which "generationWeight_MGA" is defined

                        + p_groupPolicy(group, 'generationWeight_MGA')
                            * [

                                // generation from inputs
                                - sum(gnusft(grid, node, unit, s, f, t)${ gnu_input(grid, node, unit)
                                                                      and uGroup(unit, group)
                                                                      },  
                                    + v_gen(grid, node, unit, s, f, t)                  // energy generation in interval (MW)
                                
                                    ) // END sum(gnusft)

                                // generation from outputs
                                + sum(gnusft(grid, node, unit, s, f, t)${ gnu_output(grid, node, unit)
                                                                      and uGroup(unit, group)
                                                                      },
                                    + v_gen(grid, node, unit, s, f, t)
                                        
                                    ) // END sum(gnusft)

                                ] // END * p_groupPolicyUnit(group, 'generationWeight_MGA')

                            ) // END sum(group)

                        ] // END * p_stepLength
            

                ]                                                               // END * p_msft_probability(m,s,f,t)
        )                                                                       // END sum over msft(m, s, f, t)

    + sum(s_active(s), // consider only active s
        + sum(m, p_msAnnuityWeight(m, s)) // Sample weighting to calculate annual costs

          * [
              // weighted sum of capacity investments, if capacityWeight_MGA is used
              sum(group$p_groupPolicy(group, 'capacityWeight_MGA'),  // sum over groups, for which "capacityWeight_MGA" is defined

                        + p_groupPolicy(group, 'capacityWeight_MGA')
                            * [

                                // invest variables LP and MIP
                                + sum(gnu(grid, node, unit)$uGroup(unit, group), // sum over units in the considered uGroup
                                        + v_invest_LP(unit)${ unit_investLP(unit) and us(unit, s)} // consider unit only if it is active in the sample
                                        * p_gnu(grid, node, unit, 'unitSize')
                                        / 1e3 // convert to GW
                                        + v_invest_MIP(unit)${ unit_investMIP(unit) and us(unit, s)} // consider unit only if it is active in the sample
                                        * p_gnu(grid, node, unit, 'unitSize')
                                        / 1e3 // convert to GW
                                        ) // END sum(gnu)
                                        
                                ] // END * p_groupPolicyUnit(group, 'capacityWeight_MGA')

                            ) // END sum(group)
            
          ] // END * p_msAnnuityWeight
          ) // END sum over ms


$ifthen.addterms exist '%input_dir%/2c_additional_objective_terms.gms'
    $$include '%input_dir%/2c_additional_objective_terms.gms';
$endif.addterms


;
