
* Additional_outputVariants.inc is read each solve and can be used to 
* calculate user given result tables that need values directly from the model variables.
* This is a template file giving examples how this can be used to expand the result file.
* This file calculates the values of objective function in different forecast branches and 
* stores the result to r_cost_objectiveFunction_ft.

* remove temp_objectiveCostFt_ from the file name
* and place to folder backbone\input


// Value of the objective function in one solve in different forecasts
// costs with f dimension to correct f branch
r_cost_objectiveFunction_ft(f_active(f), t_solve(t_))
    $ { ord(t_) = t_solveFirst}
    =

* --- Unit Operation Costs ----------------------------------------------------

    // unit vomCosts
    + sum(gnusft(grid, node, unit, s, f, t)${ p_vomCost(grid, node, unit, 'useConstant')
                                              or p_vomCost(grid, node, unit, 'useTimeSeries')
                                              or p_vomCostNew(grid, node, unit, f, 'useConstant')
                                              or p_vomCostNew(grid, node, unit, f, 'useTimeSeries')
                                              },
        + p_sft_probability(s, f, t)        // sft probability
        * p_s_discountFactor(s)             // Discount costs
        * p_stepLength(t)                   // time step length
        / p_scaling_obj                     // objective scaling
        * v_gen.l(grid, node, unit, s, f, t)  // Unit Generation variables
        * [ // negative sign for input, because v_gen is negative for input
            -1$gnu_input(grid, node, unit)
            +1$gnu_output(grid, node, unit)
           ]
        * [ // Unit vomCosts
            + p_vomCost(grid, node, unit, 'price')$p_vomCost(grid, node, unit, 'useConstant')
            + ts_vomCost_(grid, node, unit, t)$p_vomCost(grid, node, unit, 'useTimeSeries')
            + p_vomCostNew(grid, node, unit, f, 'price')$p_vomCostNew(grid, node, unit, f, 'useConstant')
            + ts_vomCostNew_(grid, node, unit, f, t)$p_vomCostNew(grid, node, unit, f, 'useTimeSeries')
           ]
        * p_scaling_u(unit)
      ) // END sum(gnusft)

    // unit rampCosts
    + sum(gnusft_rampCost(slack, grid, node, unit, s, f, t)$p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'),
        + p_sft_probability(s, f, t)        // sft probability
        * p_s_discountFactor(s)             // Discount costs
        / p_scaling_obj                     // objective scaling
        * p_stepLength(t)                   // time step length
        * v_genRampUpDown.l(slack, grid, node, unit, s, f, t)
        * p_scaling_u(unit)
        * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
      ) // END sum(gnusft_rampCost)

    // unit start-up costs, initial startup free as units could have been online before model started
    + sum(usft_online(unit_startCost(unit), s, f, t),
        + p_sft_probability(s, f, t)        // sft probability
        * p_s_discountFactor(s)             // Discount costs
        / p_scaling_obj                     // objective scaling
        * sum(unitStarttype(unit, starttype),
                + [ // Unit startup variables
                    + v_startup_LP.l(starttype, unit, s, f, t)$usft_onlineLP(unit, s, f, t)
                    + v_startup_MIP.l(starttype, unit, s, f, t)$usft_onlineMIP(unit, s, f, t)
                    ]
                * [ // Unit startup costs
                    + p_startupCost(unit, starttype, 'price')$p_startupCost(unit, starttype, 'useConstant')
                    + ts_startupCost_(unit, starttype, t)$p_startupCost(unit, starttype, 'useTimeSeries')
                    + p_startupCostNew(unit, starttype, f, 'price')$p_startupCostNew(unit, starttype, f, 'useConstant')
                    + ts_startupCostNew_(unit, starttype, f, t)$p_startupCostNew(unit, starttype, f, 'useTimeSeries')
                   ]
                ) // END sum(starttype)
      ) // END sum(usft_online)

    // unit shut-down costs, initial shutdown free?
    + sum(usft_online(unit, s, f, t)$p_uShutdown(unit, 'cost'),
        + p_sft_probability(s, f, t)        // sft probability
        * p_s_discountFactor(s)             // Discount costs
        / p_scaling_obj                     // objective scaling
        * p_uShutdown(unit, 'cost')
        * [ // Unit shutdown variables
            + v_shutdown_LP.l(unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
            + v_shutdown_MIP.l(unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
            ]
    ) // END sum(usft_online)


* --- Transfer link operation costs ----------------------------     

    // transfer costs (EUR), leftward
    + sum(gn2nsft_directional(grid, node, node_, s, f, t)
        ${ p_linkVomCost(grid, node, node_, f, 'useConstant')
           or p_linkVomCost(grid, node, node_, f, 'useTimeSeries')
           },
        + p_sft_probability(s, f, t)      // Probability (weight coefficient) of (s, f, t)
        * p_s_discountFactor(s)           // Discount costs
        / p_scaling_obj                     // objective scaling
        * p_stepLength(t)                 // Time step length
        * v_transferLeftward.l(grid, node, node_, s, f, t)    // transfer volume (MWh)
        * p_scaling_nn(node, node_)
        * [ // transfer link vomCost (EUR/MWh)
            + p_linkVomCost(grid, node_, node, f, 'price')$p_linkVomCost(grid, node_, node, f, 'useConstant')
            + ts_linkVomCost_(grid, node_, node, f, t)$p_linkVomCost(grid, node_, node, f, 'useTimeseries')
            ]
    ) // END sum(gn2nsft_directional)

    // transfer costs (EUR), rightward
    + sum(gn2nsft_directional(grid, node, node_, s, f, t)
        ${ p_linkVomCost(grid, node_, node, f, 'useConstant')
           or p_linkVomCost(grid, node_, node, f, 'useTimeSeries')
           },
        + p_sft_probability(s, f, t)      // Probability (weight coefficient) of (s, f, t)
        * p_s_discountFactor(s)           // Discount costs
        / p_scaling_obj                     // objective scaling
        * p_stepLength(t)                 // Time step length
        * v_transferRightward.l(grid, node, node_, s, f, t)    // transfer volume (MWh)
        * p_scaling_nn(node, node_)
        * [ // transfer link vomCost (EUR/MWh)
            + p_linkVomCost(grid, node, node_, f, 'price')$p_linkVomCost(grid, node, node_, f, 'useConstant')
            + ts_linkVomCost_(grid, node, node_, f, t)$p_linkVomCost(grid, node, node_, f, 'useTimeseries')
            ]
    ) // END sum(gn2nsft_directional)

* --- Other Node Costs --------------------------------------------------------------

    // Node state slack variable costs
    + sum(gn_stateSlack(grid, node),
        // Sum over all slack, samples, forecasts, and time steps in the current model
        + sum((slack, sft(s, f, t))${p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            * v_stateSlack.l(slack, grid, node, s, f, t)
            * p_scaling_n(node)
            * p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')
            ) // END sum(slack, sft)
        ) // END sum(gn_stateSlack)

    // Cost of energy storage change
    // note: currently not discounted, but could be relevant depending on the case study
    + sum(gn_state(grid, node)${ sum(m, active(m, 'storageValue')) },
        + sum(ft_start(f, t),
            + sum(s${ p_sft_probability(s, f, t) },
                + [
                    + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                    + ts_storageValue_(grid, node, f+df_central(f, t), t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                  ]
                    * p_sft_probability(s, f, t)
                    * v_state.l(grid, node, s, f+df_central(f, t), t)
               ) // END sum(s)
            ) // END sum(ft_start)
            * p_scaling_n(node)
        - sum(ft_lastSteps(f, t),
            + sum(s${p_sft_probability(s, f, t)},
                + [
                    + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                    + ts_storageValue_(grid, node, f+df_central(f, t), t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                  ]
                    * p_sft_probability(s, f, t)
                    * v_state.l(grid, node, s, f+df_central(f, t), t)
                ) // END sum(s)
            ) // END sum(ft_lastSteps)
            * p_scaling_n(node)
        ) // END sum(gn_state)
        / p_scaling_obj                     // objective scaling

    // Reserve provision to reserve markets outside the modelled reserve balance
    - sum(restypeDirectionGroup(restype, up_down, group),
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t),
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            / p_scaling_obj                     // objective scaling
            * p_stepLength(t) // Time step length dependent costs
            * v_resToMarkets.l(restype, up_down, group, s, f, t)
            * p_scaling_restype(restype)
            * [ + p_reservePrice(restype, up_down, group, f, 'price')${ p_reservePrice(restype, up_down, group, f, 'useConstant') }
                + ts_reservePrice_(restype, up_down, group, f, t)${ p_reservePrice(restype, up_down, group, f, 'useTimeSeries') }
                ]
            ) // END sum(sft)
        ) // END sum(restypeDirectionGroup)


* --- Dummy variable penalties ------------------------------------------------

    // Energy balance feasibility dummy varible penalties, increase
    + sum(gn_balance(grid, node)${not dropVqGenInc_gn(grid, node)},  
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqGenInc_gnt(grid, node, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            / p_scaling_obj                     // objective scaling
            * vq_gen.l('increase', grid, node, s, f, t)
            * p_scaling_n(node)  // node scaling
            / p_scaling  // additional scaling for dummies
            *[ + PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               + ts_node_(grid, node, 'balancePenalty', f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               ]
            ) // END sum(sft)
        ) // END sum(gn_balance)

    // Energy balance feasibility dummy varible penalties, increase
    + sum(gn_balance(grid, node)${not dropVqGenInc_gn(grid, node)},
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)${not dropVqGenDec_gnt(grid, node, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            / p_scaling_obj                     // objective scaling
            * vq_gen.l('decrease', grid, node, s, f, t)
            * p_scaling_n(node)
            / p_scaling  // additional scaling for dummies
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
            / p_scaling_obj                     // objective scaling
            * vq_gen.l('decrease', grid, node, s, f, t)
            * p_scaling_n(node)
            / p_scaling  // additional scaling for dummies
            *[ + PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               + ts_node_(grid, node, 'balancePenalty', f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
               ]
            ) // END sum(sft)
        ) // END sum(gn_balance)

    // Unit eq/gt constraint feasibility dummy varible penalties
    + sum(unitConstraint(unit, constraint)
        $ {eq_constraint(constraint)
           or gt_constraint(constraint)
           },
        // Sum over all samples, forecasts, and time steps in the current model
        + sum(sft(s, f, t)
            ${ [p_unitConstraintNew(unit, constraint, 'constant')
                or ts_unitConstraint_(unit, constraint, 'constant', f+df_central(f, t), t)
                ]
               and not dropVqUnitConstraint(unit, constraint, t)
               },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            / p_scaling_obj                     // objective scaling
            * vq_unitConstraint.l('decrease', constraint, unit, s, f, t)
            * p_scaling_u(unit)
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
                or ts_unitConstraint_(unit, constraint, 'constant', f+df_central(f, t), t)
                ]
               and not dropVqUnitConstraint(unit, constraint, t)
               },
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            / p_scaling_obj                     // objective scaling
            * vq_unitConstraint.l('increase', constraint, unit, s, f, t)
            * p_scaling_u(unit)
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
            * vq_resDemand.l(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
            * p_scaling_restype(restype)
            / p_scaling       // additional scaling for dummies
            / p_scaling_obj                     // objective scaling
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
            * vq_resMissing.l(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)${ ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t) }
            * p_scaling_restype(restype)
            / p_scaling       // additional scaling for dummies
            / p_scaling_obj                     // objective scaling
            * PENALTY_RES_MISSING(restype, up_down)
            ) // END sum(sft)
    ) // END sum(restypeDirectionNode)

    // userconstraint feasibility dummy varible penalties
    + sum(group_uc,
        // Sum over all samples, forecasts, and time steps in the current model
        + sum((inc_dec, sft(s, f, t))${not dropVqUserconstraint(group_uc, t)},
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            * p_s_discountFactor(s) // Discount costs
            * p_stepLength(t) // Time step length dependent costs
            / p_scaling_obj                     // objective scaling
            * vq_userconstraint(inc_dec, group_uc, s, f, t)
            * PENALTY
            ) // END sum(inc_dec, sft)
        ) // END sum(group_uc)

;

// unit investment costs without f or t dimension to 'f00' and first solve
r_cost_objectiveFunction_ft(f_active(f), t_solve(t_))
    $ { sameAs(f, 'f00')
        and solveCount = 1
        and ord(t_) = t_solveFirst}
    =
    // previous calculations
    + r_cost_objectiveFunction_ft(f, t_)

* --- Fixed maintenance costs and investment costs of units -------------------

    // Fixed operation and maintenance costs of existing units (EUR)
    // includes existing capacity even if unit has v_invest variable
    // note: Not scaled as both multiplier and divisor have MW
    + sum((gnu(grid, node, unit), s_active(s))${ us(unit, s)   // consider unit only if it is active in the sample
                                                 and p_gnu(grid, node, unit, 'fomCosts')   // and it has fomCost defined
                                                 },
        + sum(m, p_msAnnuityWeight(m, s))       // sample annualization
        * p_s_discountFactor(s)                 // Discount costs
        / p_scaling_obj                     // objective scaling
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * p_unit(unit, 'unitCount')             // number of existing units
        * p_gnu(grid, node, unit, 'fomCosts')   // (EUR/MW/a)
        ) // END sum(gnu, s_active)

    // Unit investment costs and fixed operation and maintenance costs of new units (EUR)
    // note: Not scaled as both multiplier and divisor have MW
    + sum((gnu(grid, node, unit_invest(unit)), s_active(s))${ us(unit, s)   // consider unit only if it is active in the sample
                                                              and [p_gnu(grid, node, unit, 'fomCosts')   // and it has fomCost or invCost parameter defined
                                                                   or p_gnu(grid, node, unit, 'invCosts')
                                                                   ]
                                                              },
        + sum(m, p_msAnnuityWeight(m, s)) // sample annualization
        * p_s_discountFactor(s) // Discount costs
        / p_scaling_obj                     // objective scaling
        * [ // number of invested units
            + v_invest_LP.l(unit)${ unit_investLP(unit) }
            + v_invest_MIP.l(unit)${ unit_investMIP(unit) }
            ]
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * [ // sum of fom and annualized inv costs
            + p_gnu(grid, node, unit, 'fomCosts')  // (EUR/MW)
            + p_gnu(grid, node, unit, 'invCosts') * p_gnu(grid, node, unit, 'annuityFactor')  // (EUR/MW) * annualizationFactor
            ]
        ) // END sum(gnu, s_active)

    // capacity emission costs: fixed o&M emissions and investment emissions (EUR)
    // note: calculated from p_emissionPrice('constant') or from the average of ts_emissionPrice that is stored in p_emissionPrice('average')
    // note: Not scaled as both multiplier and divisor have MW
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
        / p_scaling_obj                     // objective scaling
        * p_gnuEmission(grid, node, unit, emission, 'fomEmissions')       // (tEmissions/MW)
        * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
        * [ // Number of units
            + p_unit(unit, 'unitCount')         // (number of existing units)
            + v_invest_LP.l(unit)${unit_investLP(unit)}        // (number of invested units)
            + v_invest_MIP.l(unit)${unit_investMIP(unit)}      // (number of invested units)
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
    // note: Not scaled as both multiplier and divisor have MW
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
        / p_scaling_obj                     // objective scaling
        * p_gnuEmission(grid, node, unit, emission, 'invEmissions')    // (tEmission/MW)
        * p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor')    // factor dividing emissions to N years
        * p_gnu(grid, node, unit, 'unitSize')     // (MW/unit)
        * [ // Investments to new capacity
            + v_invest_LP.l(unit)${unit_investLP(unit)}         // (number of invested units)
            + v_invest_MIP.l(unit)${unit_investMIP(unit)}       // (number of invested units)
            ]
        * [ // constant or average emission price
            + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')
            + p_emissionPrice(emission, group, 'average')$p_emissionPrice(emission, group, 'useTimeSeries')
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'price')$p_emissionPriceNew(emission, group, f, 'useConstant'))
            + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'average')$p_emissionPriceNew(emission, group, f, 'useTimeseries'))
            ]
        ) // END sum(gnu, emissionGroup, s_active)
;

// Transfer link investment costs without f dimension to 'f00', but to correct t
r_cost_objectiveFunction_ft(f_active(f), t_solve(t_))
    $ { sameAs(f, 'f00')
        and ord(t_) = t_solveFirst}
    =
    // previous calculations
    + r_cost_objectiveFunction_ft(f, t_)

    // Transfer link investment costs
    + sum((gn2n_directional(grid, from_node, to_node), s_active(s), t_invest(t))
         ${ ord(t) <= sum(m, msEnd(m, s))
           and [gn2n_directional_investLP(grid, from_node, to_node)
                or gn2n_directional_investMIP(grid, from_node, to_node)]
           },
        // v_investTransfer_LP
        + sum(m, p_msAnnuityWeight(m, s))
        * p_s_discountFactor(s)                 // Discount costs
        / p_scaling_obj                     // objective scaling
        * v_investTransfer_LP.l(grid, from_node, to_node, t)${ gn2n_directional_investLP(grid, from_node, to_node) }
        * [
            + p_gnn(grid, from_node, to_node, 'invCost')
              * p_gnn(grid, from_node, to_node, 'annuityFactor')
            + p_gnn(grid, to_node, from_node, 'invCost')
              * p_gnn(grid, to_node, from_node, 'annuityFactor')
            ] // END * v_investTransfer_LP
        // v_investTransfer_MIP
        + sum(m, p_msAnnuityWeight(m, s))
        * p_s_discountFactor(s)                 // Discount costs
        * v_investTransfer_MIP.l(grid, from_node, to_node, t)${ gn2n_directional_investMIP(grid, from_node, to_node) }
        * [
            + p_gnn(grid, from_node, to_node, 'unitSize')
              * p_gnn(grid, from_node, to_node, 'invCost')
              * p_gnn(grid, from_node, to_node, 'annuityFactor')
            + p_gnn(grid, to_node, from_node, 'unitSize')
              * p_gnn(grid, to_node, from_node, 'invCost')
              * p_gnn(grid, to_node, from_node, 'annuityFactor')
            ] // END * v_investTransfer_MIP
        ) // END sum(gn2n_directional, s_active, t_invest)
;