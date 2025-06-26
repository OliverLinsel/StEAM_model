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

Contents:
 - Recording realized parameter values
    - result helper sets
    - gnu results
    - Investment results
    - Reserve results
    - Group results
    - Feasibility results
    - Cost results
 - Output invariants calculated in 4a because of time series
 - Model Solve & Status
 - Diagnostic results
 - Additional result tables


$offtext

* =============================================================================
* --- Recording realized parameter values -------------------------------------
* =============================================================================

* --- Result helper sets ------------------------------------------------------

// Improve performance & readibility by using a few helper sets

// clearing values from the previous solve
option clear=t_startp, clear=sft_resdgn, s_realized < sft_realized;

// t in stored results from a single solve
t_startp(t_realized(t))
   ${[ord(t) > mSettings(mSolve, 't_start')]
     and [ord(t) <= mSettings(mSolve, 't_end')+1]     // +1 because t000000 is the first one
     } =yes;


* --- gnu results -------------------------------------------------------------

// if st_start part of t_startp, pick storage and online values just before samples
// filtering t's just before samples, +1 to shift to move to t before the start
option clear = tt;
tt(t_current(t)) $ { sum(s_active(s), st_start(s, t+1))
                     and t_startp(t+1)}
    = yes;

// r_state and r_online just before the start of samples
if(card(tt)>0,
    loop(sf(s, f_realization(f)),
        r_state_gnft(gn_state(grid, node), f, tt(t))
            = v_state.l(grid, node, s, f, t);
        r_online_uft(unit_online(unit), f, tt(t))
            = + v_online_LP.l(unit, s, f, t)$unit_online_LP(unit)
              + v_online_MIP.l(unit, s, f, t)$unit_online_MIP(unit);
        // storing also the new r_state with s dimension
        r_state_gnsft(gn_state(grid, node), s, f, tt(t))
            = v_state.l(grid, node, s, f, t);
    ); // END loop(sf)
); // END if(tt)

// realized results in the solve
loop(s_realized(s),

    // nodes
    if (mSolve('invest'),
        // q_balance marginal values
        r_balance_marginalValue_gnft(gn_balance(grid, node), f_realization(f), t_startp(t))
            $ { sft_realized(s, f, t) }  // if sft needed because s is not a part of result table dimensions
            = q_balance.m(grid, node, s, f, t)/p_msWeight('invest', s);
    ); // END if(mSolve('invest'))
    if (mSolve('schedule'),
        // q_balance marginal values
        r_balance_marginalValue_gnft(gn_balance(grid, node), f_realization(f), t_startp(t))
            $ { sft_realized(s, f, t) }
            = q_balance.m(grid, node, s, f, t);
    ); // END if(mSolve('schedule'))
    // Storage states
    r_state_gnft(gn_state(grid, node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_state.l(grid, node, s, f, t);
    // Energy spilled from nodes
    r_spill_gnft(gn_balance(grid, node_spill(node)), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_spill.l(grid, node, s, f, t)
          * p_stepLength(t);
    // v_stateSlack values for calculation of realized costs later on
    r_stateSlack_gnft(slack, gn_stateSlack(grid, node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_stateSlack.l(slack, grid, node, s, f, t);

    // units
    // Unit generation and consumption
    r_gen_gnuft(gnu(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_gen.l(grid, node, unit, s, f, t);
    // delayed generation
    r_gen_delay_gnuft(gnu_delay(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_gen_delay.l(grid, node, unit, s, f, t);
    // upward ramps of ramp constrained units
    r_genRamp_gnuft(gnu_rampUp(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_genRampUp.l(grid, node, unit, s, f, t);
    // downward ramps of ramp constrained units
    r_genRamp_gnuft(gnu_rampDown(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = -v_genRampDown.l(grid, node, unit, s, f, t);
    // Realized unit online history
    r_online_uft(unit_online(unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = + v_online_LP.l(unit, s, f, t)$usft_onlineLP(unit, s, f, t)
          + round(v_online_MIP.l(unit, s, f, t))$usft_onlineMIP(unit, s, f, t);
    // Unit startup and shutdown history
    r_startup_uft(starttype, unit_online(unit), f_realization(f), t_startp(t))
        $ { unitStarttype(unit, starttype)
            and sft_realized(s, f, t) }
        = + v_startup_LP.l(starttype, unit, s, f, t)$usft_onlineLP(unit, s, f, t)
          + round(v_startup_MIP.l(starttype, unit, s, f, t))$usft_onlineMIP(unit, s, f, t);
    r_shutdown_uft(unit_online(unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = + v_shutdown_LP.l(unit, s, f, t)$usft_onlineLP(unit, s, f, t)
          + round(v_shutdown_MIP.l(unit, s, f, t))$usft_onlineMIP(unit, s, f, t);
    // unit ramp costs, upwards
    r_cost_unitRampCost_gnuft(gnu_rampUpCost(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = // flat upward ramp cost
          + [v_genRampUp.l(grid, node, unit, s, f, t)
              * p_gnu(grid, node, unit, 'rampUpCost')] $ p_gnu(grid, node, unit, 'rampUpCost')
          // piecewise upward ramp costs
          + sum(upwardSlack(slack)$p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'),
              v_genRampUpDown.l(slack, grid, node, unit, s, f, t)
              * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
              )  // END sum(upwardSlack)
    ;

    // unit ramp costs, downwards
    r_cost_unitRampCost_gnuft(gnu_rampDownCost(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = // flat downward ramp cost
          + [v_genRampDown.l(grid, node, unit, s, f, t)
              * p_gnu(grid, node, unit, 'rampDownCost') ] $ p_gnu(grid, node, unit, 'rampDownCost')
          // piecewise downward ramp cost
          + sum(downwardSlack(slack)$p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'),
              v_genRampUpDown.l(slack, grid, node, unit, s, f, t)
              * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
              ) // END sum(downwardSlack)
    ;

    // transfers
    // Transfer of energy between nodes
    r_transfer_gnnft(gn2n(grid, from_node, to_node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_transfer.l(grid, from_node, to_node, s, f, t);
    // Transfer of energy from first node to second node
    r_transferRightward_gnnft(gn2n_directional(grid, from_node, to_node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_transferRightward.l(grid, from_node, to_node, s, f, t);
    // Transfer of energy from second node to first node
    r_transferLeftward_gnnft(gn2n_directional(grid, to_node, from_node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = v_transferLeftward.l(grid, to_node, from_node, s, f, t);

); // END loop(s_realized)

// Storage states, new table with s dimension
r_state_gnsft(gn_state(grid, node), sft_realized(s, f, t_startp(t)) )
    = v_state.l(grid, node, s, f, t);


* --- Investment results ---------------------------------------------------------

// Unit investments
r_invest_unitCount_u(unit_invest(unit))
    ${ p_unit(unit, 'becomeAvailable') <= t_solveFirst + mSettings(mSolve, 't_jump')
       }
    = + v_invest_LP.l(unit)
      + v_invest_MIP.l(unit);

// Link investments
r_invest_transferCapacity_gnn(grid, node, node_, t_invest(t))${ p_gnn(grid, node, node_, 'transferCapInvLimit')
*                                                   and t_current(t)
                                                   and ord(t) <= t_solveFirst + mSettings(mSolve, 't_jump')
                                                   }
    = + v_investTransfer_LP.l(grid, node, node_, t)
      + v_investTransfer_MIP.l(grid, node, node_, t)
          * p_gnn(grid, node, node_, 'unitSize');


* --- Reserve results ---------------------------------------------------------

if(card(restypeDirection)>0,
    // t in stored reserve results from a single solve
    sft_resdgn(restypeDirectionGridNode(restype, up_down, gn), sft(s, f, t_startp(t)))
      ${ord(t) <= t_solveFirst + p_gnReserves(gn, restype, 'reserve_length')} = yes;


    loop(s_realized(s),
        // q_resDemand marginal values
        r_reserve_marginalValue_ft(restypeDirectionGroup(restype, up_down, group), f_realization(f), t_startp(t))
            $ { sft_realized(s, f, t) }
            = q_resDemand.m(restype, up_down, group, s, f, t);

        // reserve provision to reserve markets outside model balance
        r_reserveMarkets_ft(restypeDirectionGroup(restype, up_down, group), ft_realized(f_(f+df_reservesGroup(group, restype, f, t)), t_startp(t)) )
            ${sft_realized(s, f, t)
              and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
              and p_groupReserves(group, restype, 'usePrice')}
            = v_resToMarkets.l(restype, up_down, group, s, f_, t);

        // if conditions over reserve horizon (sft_resdgn), as the reserve variables use a different ft-structure due to commitment
        // Reserve provisions of units
        r_reserve_gnuft(gnu_resCapable(restype, up_down, grid, node, unit), f_(f+df_reserves(grid, node, restype, f, t)), t)
            ${ (not sft_realized(s, f_, t)$restypeReleasedForRealization(restype))$sft_resdgn(restype, up_down, grid, node, s, f, t) }
            = + v_reserve.l(restype, up_down, grid, node, unit, s, f_, t)
              + sum(restype_$p_gnuRes2Res(grid, node, unit, restype_, up_down, restype),
                  + v_reserve.l(restype_, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
                      * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
              );

        // Reserve transfer capacity for links defined out from this node
        r_reserveTransferRightward_gnnft(restype, up_down, gn2n_directional(grid, from_node, to_node), f_(f+df_reserves(grid, from_node, restype, f, t)), t)
            ${ restypeDirectionGridNodeNode(restype, up_down, grid, from_node, to_node)$sft_resdgn(restype, up_down, grid, from_node, s, f, t) }
            = v_resTransferRightward.l(restype, up_down, grid, from_node, to_node, s, f_, t);

        r_reserveTransferLeftward_gnnft(restype, up_down, gn2n_directional(grid, from_node, to_node), f_(f+df_reserves(grid, to_node, restype, f, t)), t)
            ${ restypeDirectionGridNodeNode(restype, up_down, grid, to_node, from_node)$sft_resdgn(restype, up_down, grid, from_node, s, f, t) }
            = v_resTransferLeftward.l(restype, up_down, grid, from_node, to_node, s, f_, t);

        if(card(unit_fail)>0,
            // Loop over group reserve horizon
            loop((restypeDirectionGroup(restype, up_down, group), sft_realized(s, f, t_startp(t)))
                ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')},

                // Reserve requirement due to N-1 reserve constraint
                r_reserveDemand_largestInfeedUnit_ft(restype, 'up', group, f_(f+df_reservesGroup(group, restype, f, t)), t)
                  $ ( sum((gnGroup(gn, group),unit_fail)$p_gnuReserves(gn, unit_fail, restype, 'portion_of_infeed_to_reserve'),1))  // Calculate only for groups with units that can fail.
                    = smax((gnGroup(grid, node, group),unit_fail)$p_gnuReserves(grid, node, unit_fail, restype, 'portion_of_infeed_to_reserve'),
                        + v_gen.l(grid, node, unit_fail, s, f, t)
                          * p_gnuReserves(grid, node, unit_fail, restype, 'portion_of_infeed_to_reserve')
                        ) // END smax(unit_fail)
                    ;
            ); // END loop(restypeDirectionGroup, sft)
        ); // END if(card unit_fail)

        // Dummy reserve demand changes
        r_qReserveDemand_ft(restypeDirectionGroup(restype, up_down, group), f_(f+df_reservesGroup(group, restype, f, t)), t_startp(t))
            ${sft_realized(s, f, t)
              and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
              and sft_realized(s, f, t)}
            = vq_resDemand.l(restype, up_down, group, s, f_, t);

        // Dummy reserve missing changes
        r_qReserveMissing_ft(restypeDirectionGroup(restype, up_down, group), f_(f+df_reservesGroup(group, restype, f, t)), t_startp(t))
            ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
              and sft_realized(s, f, t)}
            = vq_resMissing.l(restype, up_down, group, s, f_, t);

    ); // END loop(s_realized)

); // END if(card(restypeDirection))

* --- Group results -------------------------------------------------------

// processing if ROCOF active in solve
loop(s_realized(s) $ {sum(group, p_groupPolicy(group, 'ROCOF'))},
    // RoCoF due to a unit failure
    // RoCoF = DefaultFreq * MW_LostUnit / 2 / (sumINERTIA - INERTIA_LostUnit)
    r_stability_rocof_unit_ft(group, f_realization(f), t_startp(t))
        ${sft_realized(s, f, t)
          and p_groupPolicy(group, 'defaultFrequency')
          and p_groupPolicy(group, 'ROCOF')
          and p_groupPolicy(group, 'dynamicInertia')}

        = smax(unit_fail(unit_)
            ${  sum(gnGroup(grid, node, group), gnu_output(grid, node, unit_))
                and usft(unit_, s, f, t)
                },
            p_groupPolicy(group, 'defaultFrequency')
            * sum(gnu_output(grid, node, unit_)${gnGroup(grid, node, group)},
                + v_gen.l(grid, node, unit_ , s, f, t)
                ) // END sum(gnu_output)
            / 2
            / [
                + sum(gnu_output(grid, node, unit)${   ord(unit) ne ord(unit_)
                                                       and gnGroup(grid, node, group)
                                                       and usft(unit, s, f, t)
                                                       },
                    + p_gnu(grid, node, unit, 'inertia')
                        * p_gnu(grid ,node, unit, 'unitSizeMVA')
                        * [
                            + v_online_LP.l(unit, s, f+df_central_t(f, t), t)
                                ${usft_onlineLP(unit, s, f, t)}
                            + v_online_MIP.l(unit, s, f+df_central_t(f, t), t)
                                ${usft_onlineMIP(unit, s, f, t)}
                            + (v_gen.l(grid, node, unit, s, f, t)
                                / p_gnu(grid, node, unit, 'unitSize'))
                                ${  p_gnu(grid, node, unit, 'unitSize')
                                    and not usft_online(unit, s, f, t)
                                    }
                            ] // * p_gnu
                    ) // END sum(gnu_output)
                ] // END / p_groupPolicy
            ) // END smax
    ;
); // END loop(s_realized)


// processing if userconstraints are active in solve
if(card(groupUc1234)>0,
    loop(s_realized(s),
        // userconstraint if the type is 'toVariable' and method forEachTimestep
        // Note: 4b_outputInvariant.gms picks for 'sumOfTimesteps' from the last solve
        r_userconstraint_ft(group_uc, f_realization(f), t_startp(t))
            $ { sft_realized(s, f, t)
                and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
                and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'toVariable'))
                and [not group_ucSftFiltered(group_uc)           // if not sft filtered userconstraint
                     or [group_ucSftFiltered(group_uc)           // or if sft filtered userconstraint
                         and sft_groupUc(group_uc, s, f, t)      // ... and included sft
                         ]
                     ]
                }
            = v_userconstraint_LP_t.l(group_uc, s, f, t) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP_t.l(group_uc, s, f, t) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable');

        // increase from userconstraint eq, eachTimestep
        r_qUserconstraint_ft('increase', group_uc, f_realization(f), t_startp(t))
            ${sft_realized(s, f, t)
              and not dropVqUserconstraint(group_uc, t)
              and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
              and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
              }
            = vq_userconstraintInc_t.l(group_uc, s, f, t);

        // decrease from userconstraint eq, gt, and lt, eachTimestep
        r_qUserconstraint_ft('decrease', group_uc, f_realization(f), t_startp(t))
            ${sft_realized(s, f, t)
              and not dropVqUserconstraint(group_uc, t)
              and not sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'toVariable'))
              and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
              }
            = vq_userconstraintDec_t.l(group_uc, s, f, t);

    ); // END loop(s_realized)

    // increase from userconstraint eq, sumOfTimesteps
    r_qUserconstraint_ft('increase', group_uc, f_realization, t_solve)
        ${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
          and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
          }
        = vq_userconstraintInc.l(group_uc);

    // Decrease from userconstraint eq, gt, and lt, sumOfTimesteps
    r_qUserconstraint_ft('decrease', group_uc, f_realization, t_solve)
        ${not sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'toVariable'))
          and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
          }
        = vq_userconstraintDec.l(group_uc);

); // END if(card(groupUc1234))


* --- Other feasibility results -----------------------------------------------------

loop(s_realized(s),
    // Dummy generation & consumption
    r_qGen_gnft(inc_dec, gn(grid, node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = vq_gen.l(inc_dec, grid, node, s, f, t);

    // Dummy upward ramps
    r_qGenRamp_gnuft('increase', gnu_rampUp(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t)}
        = vq_genRampUp.l(grid, node, unit, s, f, t);

    // Dummy downward ramps
    r_qGenRamp_gnuft('decrease', gnu_rampDown(grid, node, unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t)}
        = vq_genRampDown.l(grid, node, unit, s, f, t);

    // Dummy capacity
    r_qCapacity_ft(gn(grid, node), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t)
            and p_gn(grid, node, 'capacityMargin')}
        = vq_capacity.l(gn, s, f, t);

    // Dummy unit eq/gt/lt constraint
    r_qUnitConstraint_uft(inc_dec, constraint, unit, f_realization(f), t_startp(t))
        ${sft_realized(s, f, t)
          and unitConstraint(unit, constraint)
          and not dropVqUnitConstraint(unit, constraint, t)}
        = vq_unitConstraint.l(inc_dec, constraint, unit, s, f, t);

); // END loop(s_realized)




* --- Cost results ------------------------------------------------------------

// Cumulative Objective function value
r_cost_objectiveFunction_t(t_solve)
    = r_cost_objectiveFunction_t(t_solve - mSettings(mSolve, 't_jump'))
      + v_obj.l
        / 1e6   // conversion to MEUR for backward compatibility
;




* =============================================================================
* --- Output invariants calculated in 4a because of time series ---------------
* =============================================================================

loop(s_realized(s),

    // Calculating curtailed generation from all flow units in the node.
    r_curtailments_gnft(gn_balance(grid, node), f_realization(f), t_startp(t))
        ${ sft_realized(s, f, t)
           and sum(flow, flowNode(flow, node))
           }
        = sum(flowUnit(flow, unit)$gnu_output(grid, node, unit),
            // existing capacity + investmented unitCount * unitSize
            + [+ p_gnu(grid, node, unit, 'capacity')
               + r_invest_unitCount_u(unit) * p_gnu(grid, node, unit, 'unitSize')
               ]
               // processed ts_cf used in solve
               * ts_cf_(flow, node, f, t)

            // - actual generation
            - r_gen_gnuft(grid, node, unit, f, t)
            ); // END sum(flowUnit)


    // Unit variable O&M costs (M EUR/timestep)
    r_cost_unitVOMCost_gnuft(gnu_vomCost(grid, node, unit), f_realization(f), t_startp(t))
        ${ sft_realized(s, f, t) }
        = 1e-6 // Scaling to MEUR
            * p_stepLengthNoReset(t)                     // h/timestep
            * abs(r_gen_gnuft(grid, node, unit, f, t))   // MWh/h
            * [ + p_gnu(grid, node, unit, 'vomCosts') $ {not gnu_timeseries(grid, node, unit, 'vomCosts') and not p_roundingParam('p_vomCost')}    // EUR/MWh, constant, not rounded
                + round(p_gnu(grid, node, unit, 'vomCosts'), p_roundingParam('p_vomCost')) $ {not gnu_timeseries(grid, node, unit, 'vomCosts') and p_roundingParam('p_vomCost')}    // EUR/MWh, constant, rounded
                + ts_gnu_(grid, node, unit, 'vomCosts', f, t) $ {gnu_timeseries(grid, node, unit, 'vomCosts') and not p_roundingTs('ts_vomCost_')}  // EUR/MWh, ts, not roudned
                + round(ts_gnu_(grid, node, unit, 'vomCosts', f, t), p_roundingTs('ts_vomCost_')) $ {gnu_timeseries(grid, node, unit, 'vomCosts') and not p_roundingTs('ts_vomCost_')}  // EUR/MWh, ts, not roudned
                ] ;

    // Unit variable fuel and emission costs (M EUR/timestep)
    r_cost_unitFuelEmissionCost_gnuft(gnu_vomCost(grid, node, unit), f_realization(f), t_startp(t))
        ${ sft_realized(s, f, t) }
        = + 1e-6 // Scaling to MEUR. Multiplying by -1 because v_gen input is negative, and input is cost
            * p_stepLengthNoReset(t)
            * r_gen_gnuft(grid, node, unit, f, t)
            * [ // negative sign for input, because v_gen is negative for input
                -1$gnu_input(grid, node, unit)
                +1$gnu_output(grid, node, unit)
                ]
            * [ + p_vomCost(grid, node, unit, 'price')$p_vomCost(grid, node, unit, 'useConstant')
                + ts_vomCost_(grid, node, unit, t)$p_vomCost(grid, node, unit, 'useTimeseries')
                + p_vomCostNew(grid, node, unit, f, 'price')$p_vomCostNew(grid, node, unit, f, 'useConstant')
                + ts_vomCostNew_(grid, node, unit, f, t)$p_vomCostNew(grid, node, unit, f, 'useTimeseries')
                ]
          // reducing vomCosts as those are included in p_vomCost/ts_vomCost, but reported in r_cost_unitVOMCost_gnuft
          - r_cost_unitVOMCost_gnuft(grid, node, unit, f, t)
          ;

    // Unit startup costs (M EUR/timestep)
    r_cost_unitStartupCost_uft(unit_startCost(unit), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = 1e-6 // Scaling to MEUR
            * sum(unitStarttype(unit, starttype),
                + r_startup_uft(starttype, unit, f, t)
                * [ // Unit startup costs
                    + p_startupCost(unit, starttype, 'price')$p_startupCost(unit, starttype, 'useConstant')
                    + ts_startupCost_(unit, starttype, t)$p_startupCost(unit, starttype, 'useTimeSeries')
                    + p_startupCostNew(unit, starttype, f, 'price')$p_startupCostNew(unit, starttype, f, 'useConstant')
                    + ts_startupCostNew_(unit, starttype, f, t)$p_startupCostNew(unit, starttype, f, 'useTimeSeries')
                    ]
                ); // END sum(unitStarttype)

    // Variable Transfer Costs
    r_cost_linkVOMCost_gnnft(gn2n_directional_vomCost(grid, node, node_), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        = 1e-6 // Scaling to MEUR
            * p_stepLengthNoReset(t)
                *[+ p_gnn(grid, node_, node, 'variableTransCost')
                  * r_transferLeftward_gnnft(grid, node, node_, f, t)
                  + p_gnn(grid, node, node_, 'variableTransCost')
                  * r_transferRightward_gnnft(grid, node, node_, f, t)];


    // Transfer link node costs, e.g. selling electricity
    r_cost_linkNodeCost_gnnft(gn2n_directional_vomCost(grid, node, node_), f_realization(f), t_startp(t))
        $ { sft_realized(s, f, t) }
        =
          // transfer costs (vomcost, node energy price), leftward
          + 1e-6 // Scaling to MEUR
          * p_stepLength(t)                 // Time step length
          * r_transferLeftward_gnnft(grid, node, node_, f, t)    // transfer volume (MWh)
          * [ // transfer link vomCost (EUR/MWh)
              + p_linkVomCost(grid, node_, node, f, 'price')$p_linkVomCost(grid, node_, node, f, 'useConstant')
              + ts_linkVomCost_(grid, node_, node, f, t)$p_linkVomCost(grid, node_, node, f, 'useTimeseries')
              ]

          // transfer costs (vomcost, node energy price), rightward
          + 1e-6 // Scaling to MEUR
          * p_stepLength(t)                 // Time step length
          * r_transferRightward_gnnft(grid, node, node_, f, t)    // transfer volume (MWh)
          * [ // transfer link vomCost (EUR/MWh)
              + p_linkVomCost(grid, node, node_, f, 'price')$p_linkVomCost(grid, node, node_, f, 'useConstant')
              + ts_linkVomCost_(grid, node, node_, f, t)$p_linkVomCost(grid, node, node_, f, 'useTimeseries')
              ]

          // reducing vomCosts as those are included in p_linkVomCost/ts_linkVomCost, but reported in r_cost_linkVOMCost_gnnft
          - r_cost_linkVOMCost_gnnft(grid, node, node_, f, t);

); // END loop(s_realized)


* =============================================================================
* --- Model Solve & Status ----------------------------------------------------
* =============================================================================

// Model/solve status
if (mSolve('schedule'),
    r_info_solveStatus(t_solve,'modelStat')=schedule.modelStat;
    r_info_solveStatus(t_solve,'solveStat')=schedule.solveStat;
    r_info_solveStatus(t_solve,'totalTime')=schedule.etSolve;
    r_info_solveStatus(t_solve,'solverTime')=schedule.etSolver;
    r_info_solveStatus(t_solve,'iterations')=schedule.iterUsd;
    r_info_solveStatus(t_solve,'nodes')=schedule.nodUsd;
    r_info_solveStatus(t_solve,'numEqu')=schedule.numEqu;
    r_info_solveStatus(t_solve,'numDVar')=schedule.numDVar;
    r_info_solveStatus(t_solve,'numVar')=schedule.numVar;
    r_info_solveStatus(t_solve,'numNZ')=schedule.numNZ;
    r_info_solveStatus(t_solve,'sumInfes')=schedule.sumInfes;
    r_info_solveStatus(t_solve,'objEst')=schedule.objEst;
    r_info_solveStatus(t_solve,'objVal')=schedule.objVal;
);
if (mSolve('invest'),
    r_info_solveStatus(t_solve,'modelStat')=invest.modelStat;
    r_info_solveStatus(t_solve,'solveStat')=invest.solveStat;
    r_info_solveStatus(t_solve,'totalTime')=invest.etSolve;
    r_info_solveStatus(t_solve,'solverTime')=invest.etSolver;
    r_info_solveStatus(t_solve,'iterations')=invest.iterUsd;
    r_info_solveStatus(t_solve,'nodes')=invest.nodUsd;
    r_info_solveStatus(t_solve,'numEqu')=invest.numEqu;
    r_info_solveStatus(t_solve,'numDVar')=invest.numDVar;
    r_info_solveStatus(t_solve,'numVar')=invest.numVar;
    r_info_solveStatus(t_solve,'numNZ')=invest.numNZ;
    r_info_solveStatus(t_solve,'sumInfes')=invest.sumInfes;
    r_info_solveStatus(t_solve,'objEst')=invest.objEst;
    r_info_solveStatus(t_solve,'objVal')=invest.objVal;
);
if (mSolve('building'),
    r_info_solveStatus(t_solve,'modelStat')=building.modelStat;
    r_info_solveStatus(t_solve,'solveStat')=building.solveStat;
    r_info_solveStatus(t_solve,'totalTime')=building.etSolve;
    r_info_solveStatus(t_solve,'solverTime')=building.etSolver;
    r_info_solveStatus(t_solve,'iterations')=building.iterUsd;
    r_info_solveStatus(t_solve,'nodes')=building.nodUsd;
    r_info_solveStatus(t_solve,'numEqu')=building.numEqu;
    r_info_solveStatus(t_solve,'numDVar')=building.numDVar;
    r_info_solveStatus(t_solve,'numVar')=building.numVar;
    r_info_solveStatus(t_solve,'numNZ')=building.numNZ;
    r_info_solveStatus(t_solve,'sumInfes')=building.sumInfes;
    r_info_solveStatus(t_solve,'objEst')=building.objEst;
    r_info_solveStatus(t_solve,'objVal')=building.objVal;
);


* =============================================================================
* --- Diagnostics Results -----------------------------------------------------
* =============================================================================

// Only include these if '--diag=yes' given as a command line argument
$iftheni.diag %diag% == 'yes'

loop(s_realized(s),

    // t for result printing in each solve
    d_tStartp(t_solve, t_startp(t)) = 1;

    // vq_gen for each solve
    d_qGen_gnftt(inc_dec, gn_balance(grid, node), ft(f, t), t_solve)
            = vq_gen.l(inc_dec, grid, node, s, f, t);

    // vq_genRampUp and vq_genRampDown for each solve
    d_qGenRamp_gnuftt('increase', gnu_rampUp(grid, node, unit), ft(f, t), t_solve)
            = vq_genRampUp.l(grid, node, unit, s, f, t);
    d_qGenRamp_gnuftt('decrease', gnu_rampDown(grid, node, unit), ft(f, t), t_solve)
            = vq_genRampDown.l(grid, node, unit, s, f, t);

    // Dummy reserve demand changes
    d_qReserveDemand_ftt(restypeDirectionGroup(restype, up_down, group), ft(f+df_reservesGroup(group, restype, f, t), t), t_solve)
        ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
          }
        = vq_resDemand.l(restype, up_down, group, s, f, t);

    // Dummy reserve missing changes
    d_qReserveMissing_ftt(restypeDirectionGroup(restype, up_down, group), ft(f+df_reservesGroup(group, restype, f, t), t), t_solve)
        ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
          }
          = vq_resMissing.l(restype, up_down, group, s, f, t);

    // Dummy unit constraints
    d_qUnitConstraint_uftt(inc_dec, constraint, unit, ft(f, t), t_solve)
        ${unitConstraint(unit, constraint)
          }
        = vq_unitConstraint.l(inc_dec, constraint, unit, s, f, t);

    // Dummy userconstraints
    d_qUserconstraint_ftt('increase', group_uc, ft(f, t), t_solve)
        = vq_userconstraintInc_t.l(group_uc, s, f, t);
    d_qUserconstraint_ftt('decrease', group_uc, ft(f, t), t_solve)
        = vq_userconstraintDec_t.l(group_uc, s, f, t);


); // END loop(s_realized(s)

// userconstraint if the type is 'toVariable' and method 'sumOfTimesteps'
d_userconstraint(group_uc, t_solve)
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
        and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'toVariable'))
        }
    = v_userconstraint_LP.l(group_uc) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
      + v_userconstraint_MIP.l(group_uc) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable');

$endif.diag


* =============================================================================
* --- Additional result tables ------------------------------------------------
* =============================================================================

$ifthen.addOutputVar exist '%input_dir%/additional_outputVariants.inc'
   $$include '%input_dir%/additional_outputVariants.inc'
$endif.addOutputVar
