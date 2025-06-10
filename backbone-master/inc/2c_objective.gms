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

For further information, see https://gitlab.vtt.fi/backbone/backbone/-/wikis/home

Table of Contents:
 - Objective value
 - Unit Operation Costs
 - Fixed maintenance costs and investment costs of units
 - Transfer link operation and investment costs
 - Other Node Costs
 - Dummy variable penalties

$offtext


* =============================================================================
* --- Objective Function Definition -------------------------------------------
* =============================================================================

q_obj ..

* --- Objective value ---------------------------------------------------------

    + v_obj // Objective function valued in EUR (or whatever monetary unit the data is in)

    =E=

* --- Unit Operation Costs ----------------------------------------------------

    // unit vomCosts, fuel costs, emission costs
    + sum(gnu_vomCost(grid, node, unit),
        + sum(usft(unit, s, f, t),              // sum over usft to watch for certain special cases where unit is not active in each sft
            + p_sft_probability(s, f, t)        // sft probability
            * p_s_discountFactor(s)             // Discount costs
            * p_stepLength(t)                   // time step length
            // Unit Generation variables
            * [ - v_gen(grid, node, unit, s, f, t)${gnu_input(grid, node, unit)} // negative sign for input, because v_gen is negative for input
                + v_gen(grid, node, unit, s, f, t)${gnu_output(grid, node, unit)}
                ]
            * [ // Unit vomCosts
                + p_vomCost(grid, node, unit, 'price')$p_vomCost(grid, node, unit, 'useConstant')
                + ts_vomCost_(grid, node, unit, t)$p_vomCost(grid, node, unit, 'useTimeSeries')
                + p_vomCostNew(grid, node, unit, f, 'price')$p_vomCostNew(grid, node, unit, f, 'useConstant')
                + ts_vomCostNew_(grid, node, unit, f, t)$p_vomCostNew(grid, node, unit, f, 'useTimeSeries')
               ]
            ) // END sum(sft)
        ) // END sum(gnu_vomCost)

    // unit rampCosts,
    // flat upward ramp cost
    + sum(gnu_rampUpCost(grid, node, unit) $ p_gnu(grid, node, unit, 'rampUpCost'),
        + sum(gnusft_ramp(grid, node, unit, s, f, t),  // sum over usft to watch for cases where unit is not active in each sft. Sum over gnusft_ramp to improve performance.
            + p_sft_probability(s, f, t)               // sft probability
            * p_s_discountFactor(s)                    // Discount costs
            * v_genRampUp(grid, node, unit, s, f, t)
            * p_gnu(grid, node, unit, 'rampUpCost')
            ) // END sum(gnusft_ramp)
        ) // END sum(gnu_rampUpCost)
    // piecewise upward ramp costs
    + sum((upwardSlack(slack), gnu_rampUpCost(grid, node, unit)) $ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'),
        + sum(gnusft_ramp(grid, node, unit, s, f, t),  // sum over usft to watch for cases where unit is not active in each sft. Sum over gnusft_ramp to improve performance.
            + p_sft_probability(s, f, t)               // sft probability
            * p_s_discountFactor(s)                    // Discount costs
            * v_genRampUpDown(slack, grid, node, unit, s, f, t)
            * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
            ) // END sum(gnusft_ramp)
        ) // END sum(upwardSlack, gnu_rampUpCost)
    // flat downward ramp cost
    + sum(gnu_rampDownCost(grid, node, unit) $ p_gnu(grid, node, unit, 'rampDownCost'),
        + sum(gnusft_ramp(grid, node, unit, s, f, t),  // sum over usft to watch for cases where unit is not active in each sft. Sum over gnusft_ramp to improve performance.
            + p_sft_probability(s, f, t)               // sft probability
            * p_s_discountFactor(s)                    // Discount costs
            * v_genRampDown(grid, node, unit, s, f, t)
            * p_gnu(grid, node, unit, 'rampDownCost')
            ) // END sum(gnusft_ramp)
        ) // END sum(gnu_rampDownCost)
    // piecewise downward ramp costs
    + sum((downwardSlack(slack), gnu_rampDownCost(grid, node, unit)) $ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'),
        + sum(gnusft_ramp(grid, node, unit, s, f, t),  // sum over usft to watch for cases where unit is not active in each sft. Sum over gnusft_ramp to improve performance.
            + p_sft_probability(s, f, t)               // sft probability
            * p_s_discountFactor(s)                    // Discount costs
            * v_genRampUpDown(slack, grid, node, unit, s, f, t)
            * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
            ) // END sum(gnusft_ramp)
        ) // END sum(downwardSlack, gnu_rampDownCost)

    // unit start-up costs, initial startup free as units could have been online before model started
    + sum(unitStarttype(unit_startCost(unit), starttype),
        + sum(usft_online(unit, s, f, t),       // sum over usft_online to include only hours when unit is online unit
            + p_sft_probability(s, f, t)        // sft probability
            * p_s_discountFactor(s)             // Discount costs
            * [ // Unit startup variables
                + v_startup_LP(starttype, unit, s, f, t)$usft_onlineLP(unit, s, f, t)
                + v_startup_MIP(starttype, unit, s, f, t)$usft_onlineMIP(unit, s, f, t)
                ]
            * [ // Unit startup costs
                + p_startupCost(unit, starttype, 'price')$p_startupCost(unit, starttype, 'useConstant')
                + ts_startupCost_(unit, starttype, t)$p_startupCost(unit, starttype, 'useTimeSeries')
                + p_startupCostNew(unit, starttype, f, 'price')$p_startupCostNew(unit, starttype, f, 'useConstant')
                + ts_startupCostNew_(unit, starttype, f, t)$p_startupCostNew(unit, starttype, f, 'useTimeSeries')
                ]
            ) // END sum(usft_online)
        ) // END sum(unit_starttype)

    // unit shut-down costs, initial shutdown free?
    + sum(unit$p_uShutdown(unit, 'cost'),
        + sum(usft_online(unit, s, f, t),       // sum over usft_online to include only hours when unit is online unit
            + p_sft_probability(s, f, t)        // sft probability
            * p_s_discountFactor(s)             // Discount costs
            * p_uShutdown(unit, 'cost')
            * [ // Unit shutdown variables
                + v_shutdown_LP(unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                + v_shutdown_MIP(unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                ]
            ) // END sum(usft_online)
        ) // END sum(unit)


* --- Fixed maintenance costs and investment costs of units -------------------

    // Fixed operation and maintenance costs of existing units (EUR)
    // includes existing capacity even if unit has v_invest variable
    + sum((gnu(grid, node, unit), s_active(s))${ us(unit, s)   // consider unit only if it is active in the sample
                                                 and p_gnu(grid, node, unit, 'fomCosts')   // and it has fomCost defined
                                                 },
        + sum(m, p_msAnnuityWeight(m, s))       // sample annualization
        * p_s_discountFactor(s)                 // Discount costs
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * p_unit(unit, 'unitCount')             // number of existing units
        * p_gnu(grid, node, unit, 'fomCosts')   // (EUR/MW/a)
        ) // END sum(gnu, s_active)

    // Unit investment costs and fixed operation and maintenance costs of new units (EUR)
    + sum((gnu(grid, node, unit_invest(unit)), s_active(s))${ us(unit, s)   // consider unit only if it is active in the sample
                                                              and [p_gnu(grid, node, unit, 'fomCosts')   // and it has fomCost or invCost parameter defined
                                                                   or p_gnu(grid, node, unit, 'invCosts')
                                                                   ]
                                                              },
        + sum(m, p_msAnnuityWeight(m, s)) // sample annualization
        * p_s_discountFactor(s) // Discount costs
        * [ // number of invested units
            + v_invest_LP(unit)${ unit_investLP(unit) }
            + v_invest_MIP(unit)${ unit_investMIP(unit) }
            ]
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * [ // sum of fom and annualized inv costs
            + p_gnu(grid, node, unit, 'fomCosts')  // (EUR/MW)
            + p_gnu(grid, node, unit, 'invCosts') * p_gnu(grid, node, unit, 'annuityFactor')  // (EUR/MW) * annualizationFactor
            ]
        ) // END sum(gnu, s_active)

    // capacity emission costs: fixed o&M emissions and investment emissions (EUR)
    // note: calculated from p_emissionPrice('constant') or from the average of ts_emissionPrice that is stored in p_emissionPrice('average')
    + sum((gnu(grid, node, unit), emissionGroup(emission, group), s_active(s))
        ${ us(unit, s)
           and p_gnuEmission(grid, node, unit, emission, 'fomEmissions')
           and gnGroup(grid, node, group)
           and [ p_emissionPrice(emission, group, 'useConstant')
                 or p_emissionPrice(emission, group, 'useTimeseries')
                 or sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'useConstant'))
                 or sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'useTimeseries'))
                 ]
           },
        + sum(m, p_msAnnuityWeight(m, s)) // Sample weighting to calculate annual costs
        * p_s_discountFactor(s) // Discount costs
        * p_gnuEmission(grid, node, unit, emission, 'fomEmissions')       // (tEmissions/MW)
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * [ // Number of units
            + p_unit(unit, 'unitCount')         // (number of existing units)
            + v_invest_LP(unit)${unit_investLP(unit)}        // (number of invested units)
            + v_invest_MIP(unit)${unit_investMIP(unit)}      // (number of invested units)
            ]
        * [ // constant or average emission price
            + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')
            + p_emissionPrice(emission, group, 'average')$p_emissionPrice(emission, group, 'useTimeSeries')
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'price')$p_emissionPriceNew(emission, group, f, 'useConstant'))
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'average')$p_emissionPriceNew(emission, group, f, 'useTimeseries'))
            ]
        ) // END sum(gnu, emissionGroup, s_active)

    // capacity emissions cost: investment emissions (EUR)
    // note: calculated from p_emissionPrice('constant') or from the average of ts_emissionPrice that is stored in p_emissionPrice('average')
    + sum((gnu(grid, node, unit_invest(unit)),emissionGroup(emission, group), s_active(s))
        ${ us(unit, s)
           and p_gnuEmission(grid, node, unit, emission, 'invEmissions')
           and gnGroup(grid, node, group)
           and [ p_emissionPrice(emission, group, 'useConstant')
                 or p_emissionPrice(emission, group, 'useTimeseries')
                 or sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'useConstant'))
                 or sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'useTimeseries'))
                 ]
           },
        // Capacity restriction
        + sum(m, p_msAnnuityWeight(m, s)) // Sample weighting to calculate annual costs
        * p_s_discountFactor(s) // Discount costs
        * p_gnuEmission(grid, node, unit, emission, 'invEmissions')    // (tEmission/MW)
        * p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor')    // factor dividing emissions to N years
        * p_gnu(grid, node, unit, 'unitSize')     // (MW/unit)
        * [ // Investments to new capacity
            + v_invest_LP(unit)${unit_investLP(unit)}         // (number of invested units)
            + v_invest_MIP(unit)${unit_investMIP(unit)}       // (number of invested units)
            ]
        * [ // constant or average emission price
            + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')
            + p_emissionPrice(emission, group, 'average')$p_emissionPrice(emission, group, 'useTimeSeries')
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'price')$p_emissionPriceNew(emission, group, f, 'useConstant'))
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'average')$p_emissionPriceNew(emission, group, f, 'useTimeseries'))
            ]
        ) // END sum(gnu, emissionGroup, s_active)


* --- Transfer link operation and investment costs ----------------------------

    // transfer costs (vomcost, node energy price), leftward
    + sum(gn2n_directional_vomCost(grid, node, node_),
        + sum(gn2nsft_directional(grid, node, node_, s, f, t),  // sum over gn2nsft to cover cases where link is not active in each sft
            + p_sft_probability(s, f, t)                        // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s)                             // Discount costs
            * p_stepLength(t)                                   // Time step length
            * v_transferLeftward(grid, node, node_, s, f, t)    // transfer volume (MWh)
            * [ // transfer link vomCost (EUR/MWh)
                + p_linkVomCost(grid, node_, node, f, 'price')$p_linkVomCost(grid, node_, node, f, 'useConstant')
                + ts_linkVomCost_(grid, node_, node, f, t)$p_linkVomCost(grid, node_, node, f, 'useTimeseries')
                ]
            ) // END sum(sft)
        ) // END sum(gn2n_directional)

    // transfer costs (vomcost, node energy price), rightward
    + sum(gn2n_directional_vomCost(grid, node, node_),
        + sum(gn2nsft_directional(grid, node, node_, s, f, t),  // sum over gn2nsft to cover cases where link is not active in each sft
            + p_sft_probability(s, f, t)                        // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s)                             // Discount costs
            * p_stepLength(t)                                   // Time step length
            * v_transferRightward(grid, node, node_, s, f, t)   // transfer volume (MWh)
            * [ // transfer link vomCost (EUR/MWh)
                + p_linkVomCost(grid, node, node_, f, 'price')$p_linkVomCost(grid, node, node_, f, 'useConstant')
                + ts_linkVomCost_(grid, node, node_, f, t)$p_linkVomCost(grid, node, node_, f, 'useTimeseries')
                ]
            ) // END sum(sft)
        ) // END sum(gn2n_directional)

    // Transfer link investment costs
    + sum((gn2n_directional(grid, from_node, to_node), s_active(s), t_invest(t))
        ${ ord(t) <= sum(m, msEnd(m, s))
           and [gn2n_directional_investLP(grid, from_node, to_node)
                or gn2n_directional_investMIP(grid, from_node, to_node)]
           },
        // v_investTransfer_LP
        + sum(m, p_msAnnuityWeight(m, s))
        * p_s_discountFactor(s)                 // Discount costs
        * v_investTransfer_LP(grid, from_node, to_node, t)${ gn2n_directional_investLP(grid, from_node, to_node) }
        * [
            + p_gnn(grid, from_node, to_node, 'invCost')
              * p_gnn(grid, from_node, to_node, 'annuityFactor')
            + p_gnn(grid, to_node, from_node, 'invCost')
              * p_gnn(grid, to_node, from_node, 'annuityFactor')
            ] // END * v_investTransfer_LP
        // v_investTransfer_MIP
        + sum(m, p_msAnnuityWeight(m, s))
        * p_s_discountFactor(s)                 // Discount costs
        * v_investTransfer_MIP(grid, from_node, to_node, t)${ gn2n_directional_investMIP(grid, from_node, to_node) }
        * [
            + p_gnn(grid, from_node, to_node, 'unitSize')
              * p_gnn(grid, from_node, to_node, 'invCost')
              * p_gnn(grid, from_node, to_node, 'annuityFactor')
            + p_gnn(grid, to_node, from_node, 'unitSize')
              * p_gnn(grid, to_node, from_node, 'invCost')
              * p_gnn(grid, to_node, from_node, 'annuityFactor')
            ] // END * v_investTransfer_MIP
        ) // END sum(gn2n_directional, s_active, t_invest)


* --- Other Costs -------------------------------------------------------------

    // Node state slack variable costs
    + sum((slack, gn_stateSlack(grid, node))
        $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')
            },
        // Sum over samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t),
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * v_stateSlack(slack, grid, node, s, f, t)
            * p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')
            ) // END sum(slack, sft)
        ) // END sum(gn_stateSlack)

    // Cost of energy storage change
    // note: currently not discounted, but could be relevant depending on the case study
    + sum(gn_state(grid, node)${ sum(m, active(m, 'storageValue')) },   // search key: activeFeatures
        + sum(ft_start(f, t),
            + sum(s${ p_sft_probability(s, f, t) },
                + [
                    + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                    + ts_storageValue_(grid, node, f+df_central_t(f, t), t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                  ]
                    * p_sft_probability(s, f, t)
                    * v_state(grid, node, s, f+df_central_t(f, t), t)
               ) // END sum(s)
            ) // END sum(ft_start)
        - sum(ft_lastSteps(f, t),
            + sum(s${p_sft_probability(s, f, t)},
                + [
                    + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                    + ts_storageValue_(grid, node, f+df_central_t(f, t), t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                  ]
                    * p_sft_probability(s, f, t)
                    * v_state(grid, node, s, f+df_central_t(f, t), t)
                ) // END sum(s)
            ) // END sum(ft_lastSteps)
        ) // END sum(gn_state)

    // Reserve provision to reserve markets outside the modelled reserve balance
    - sum(restypeDirectionGroup(restype, up_down, group),
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t),
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * v_resToMarkets(restype, up_down, group, s, f, t)
            * [ + p_reservePrice(restype, up_down, group, f, 'price')${ p_reservePrice(restype, up_down, group, f, 'useConstant') }
                + ts_reservePrice_(restype, up_down, group, f, t)${ p_reservePrice(restype, up_down, group, f, 'useTimeSeries') }
                ]
            ) // END sum(sft)
        ) // END sum(restypeDirectionGroup)


    // userconstraint costs if defined in UC input data
    // for each time step
    + sum(group_uc
        ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'cost'))
          and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
          },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t),
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s)      // Discount costs
            * p_stepLength(t)            // Time step length dependent costs
            * [v_userconstraint_LP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
               ]
            * sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'cost'))
            ) // END sum(sft)
        ) // END sum(group_uc)

    // for sum of timesteps
    + sum(group_uc
        ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'cost'))
          and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
          },
            + [v_userconstraint_LP(group_uc) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP(group_uc) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
               ]
            * sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'cost'))
        ) // END sum(group_uc)

* --- Dummy variable penalties ------------------------------------------------

    // Energy balance feasibility dummy varible penalties, increase
    + sum(gn_balance(grid, node)${not dropVqGenInc_gn(grid, node)},
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqGenInc_gnt(grid, node, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_gen('increase', grid, node, s, f, t)
            *[ + PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               + ts_node_(grid, node, 'balancePenalty', f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               ]
            ) // END sum(sft)
        ) // END sum(gn_balance)

    // Energy balance feasibility dummy varible penalties, decrease
    + sum(gn_balance(grid, node)${not dropVqGenDec_gn(grid, node)},
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqGenDec_gnt(grid, node, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_gen('decrease', grid, node, s, f, t)
            *[ + PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               + ts_node_(grid, node, 'balancePenalty', f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               ]
            ) // END sum(sft)
        ) // END sum(gn_balance)

    // Ramp feasibility dummy varible penalties
    + sum(gnu_rampUp(grid, node, unit),
        // note: sums over gnusft_ramp instead of sft, because gnusft_ramp is already checked agains step length etc.
        + sum(gnusft_ramp(grid, node, unit, s, f, t)${not dropVqGenRamp_gnut(grid, node, unit, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
              * p_s_discountFactor(s) // Discount costs
              * p_stepLength(t) // Time step length dependent costs
              * vq_genRampUp(grid, node, unit, s, f, t)
              * PENALTY_GENRAMP(grid, node, unit)
        ) // END sum(gnusft_ramp)
    ) // END sum(gnu_rampUp)
    + sum(gnu_rampDown(grid, node, unit),
        // note: sums over gnusft_ramp instead of sft, because gnusft_ramp is already checked agains step length etc.
        + sum(gnusft_ramp(grid, node, unit, s, f, t)${not dropVqGenRamp_gnut(grid, node, unit, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
              * p_s_discountFactor(s) // Discount costs
              * p_stepLength(t) // Time step length dependent costs
              * vq_genRampDown(grid, node, unit, s, f, t)
              * PENALTY_GENRAMP(grid, node, unit)
        ) // END sum(gnusft_ramp)
    ) // END sum(gnu_rampUp)


    // Capacity margin feasibility dummy variable penalties
    + sum(gn(grid, node)${ p_gn(grid, node, 'capacityMargin') },
        + sum(sft(s, f, t),
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_capacity(grid, node, s, f, t)
            * PENALTY_CAPACITY(grid, node)
            ) // END sum(sft)
        ) // END sum(gn)

    // Unit eq/gt constraint feasibility dummy varible penalties
    + sum(unitConstraint(unit, constraint)
        $ {eq_constraint(constraint)
           or gt_constraint(constraint)
           },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)
            ${ [p_unitConstraintNew(unit, constraint, 'constant')
                or ts_unitConstraint_(unit, constraint, 'constant', f+df_central_t(f, t), t)
                ]
               and not dropVqUnitConstraint(unit, constraint, t)
               },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_unitConstraint('decrease', constraint, unit, s, f, t)
            * PENALTY
            ) // END sum(sft)
        ) // END sum(unitConstraint)

    // Unit eq/lt constraint feasibility dummy varible penalties
    + sum(unitConstraint(unit, constraint)
        $ { eq_constraint(constraint)
            or lt_constraint(constraint)
            },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)
            ${ [p_unitConstraintNew(unit, constraint, 'constant')
                or ts_unitConstraint_(unit, constraint, 'constant', f+df_central_t(f, t), t)
                ]
               and not dropVqUnitConstraint(unit, constraint, t)
               },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_unitConstraint('increase', constraint, unit, s, f, t)
            * PENALTY
            ) // END sum(sft)
        ) // END sum(unitConstraint)

    // Reserve provision feasibility dummy variable penalties
    // vq_resDemand
    + sum(restypeDirectionGroup(restype, up_down, group),
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqResDemand(restype, up_down, group, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_resDemand(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
            * PENALTY_RES(restype, up_down)
            ) // END sum(sft)
    ) // END sum(restypeDirectionNode)
    // vq_resMissing
    + sum(restypeDirectionGroup(restype, up_down, group),
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqResMissing(restype, up_down, group, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_resMissing(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)${ ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t) }
            * PENALTY_RES_MISSING(restype, up_down)
            ) // END sum(sft)
    ) // END sum(restypeDirectionNode)

    // userconstraint feasibility dummy varible penalties
    // each time step
    // 'decrease' for eq, gt, and lt. Lt because it is written with same function than gt.
    + sum(group_uc
          ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
            },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqUserconstraint(group_uc, t)
                            and [not group_ucSftFiltered(group_uc)
                                 or [group_ucSftFiltered(group_uc)
                                     and sft_groupUc(group_uc, s, f, t)
                                     ]
                                 ]
                            },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_userconstraintDec_t(group_uc, s, f, t)
            * PENALTY_UC(group_uc)
            ) // END sum(sft)
        ) // END sum(group_uc)
    // 'increase' for eq
    + sum(group_uc
          ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
            and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
            },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqUserconstraint(group_uc, t)
                            and [not group_ucSftFiltered(group_uc)
                                 or [group_ucSftFiltered(group_uc)
                                     and sft_groupUc(group_uc, s, f, t)
                                     ]
                                 ]
                            },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * vq_userconstraintInc_t(group_uc, s, f, t)
            * PENALTY_UC(group_uc)
            ) // END sum(sft)
        ) // END sum(group_uc)

    // sum of timesteps
    // 'decrease' for eq, gt, and lt. Lt because it is written with same function than gt.
    + sum(group_uc
          ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
            },
            + vq_userconstraintDec(group_uc)
            * PENALTY_UC(group_uc)
        ) // END sum(group_uc)
    // 'increase' for eq
    + sum(group_uc
          ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
            and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
            },
            + vq_userconstraintInc(group_uc)
            * PENALTY_UC(group_uc)
        ) // END sum(group_uc)



$ifthen.addTerms exist '%input_dir%/2c_additional_objective_terms.gms'
    $$include '%input_dir%/2c_additional_objective_terms.gms';
$endif.addTerms
;
