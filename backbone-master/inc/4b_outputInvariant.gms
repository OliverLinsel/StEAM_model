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

$offtext

* =============================================================================
* --- Preprocessing -----------------------------------------------------------
* =============================================================================

* -- helper sets for results calculations -------------------------------------
option us < usft;

// t needed when calculating sum results
option clear=t_startp;
t_startp(t_full(t))
    ${[ord(t) > sum(m, mSettings(m, 't_start')) + sum(m, mSettings(m, 't_initializationPeriod')) ]
      and [ord(t) <= sum(m, mSettings(m, 't_end')) + 1 ]
      and sum((s, f), sft_realizedNoReset(s, f, t))
      } = yes;

* -- Clearing results from initialization perid -------------------------------

if(sum(m, mSettings(m, 't_initializationPeriod')) > 0,

    // filtering t in initialization period, including t at the end of initialization period
    option clear = tt;
    tt(t) $ {[ord(t) > sum(m, mSettings(m, 't_start')) ]
              and [ord(t) <= sum(m, mSettings(m, 't_start')) + sum(m, mSettings(m, 't_initializationPeriod')) ]
              } = yes;

    // filtering t in initialization period, not including t at the end of initialization period
    option clear = tt_;
    tt_(t) $ {[ord(t) >= sum(m, mSettings(m, 't_start')) ]
              and [ord(t) < sum(m, mSettings(m, 't_start')) + sum(m, mSettings(m, 't_initializationPeriod')) ]
              } = yes;

    // clearing 4a results from the whole initialization period
    // gnu results
    r_balance_marginalValue_gnft(gn_balance, ft_realizedNoReset(f,tt(t)) )=0;
    r_spill_gnft(gn_balance(grid, node_spill(node)), ft_realizedNoReset(f,tt(t)) )=0;
    r_stateSlack_gnft(slack, gn_stateSlack(grid, node), ft_realizedNoReset(f,tt(t)) )=0;
    r_gen_gnuft(gnu(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_gen_delay_gnuft(gnu_delay(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_genRamp_gnuft(gnu_rampUp(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_genRamp_gnuft(gnu_rampDown(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_startup_uft(starttype, unit_online(unit), ft_realizedNoReset(f,tt(t)) ) $ {unitStarttype(unit, starttype)}=0;
    r_shutdown_uft(unit_online(unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_unitRampCost_gnuft(gnu_rampUpCost(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_unitRampCost_gnuft(gnu_rampDownCost(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_transfer_gnnft(gn2n(grid, from_node, to_node), ft_realizedNoReset(f,tt(t)) )=0;
    r_transferRightward_gnnft(gn2n_directional(grid, from_node, to_node), ft_realizedNoReset(f,tt(t)) )=0;
    r_transferLeftward_gnnft(gn2n_directional(grid, to_node, from_node), ft_realizedNoReset(f,tt(t)) )=0;

    // reserve results
    r_reserve_marginalValue_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f,tt(t)) )=0;
    r_reserveMarkets_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f,tt(t)) )=0;
    r_reserve_gnuft(gnu_resCapable(restype, up_down, grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_reserveTransferRightward_gnnft(restype, up_down, gn2n_directional(grid, from_node, to_node), ft_realizedNoReset(f,tt(t)) )=0;
    r_reserveTransferLeftward_gnnft(restype, up_down, gn2n_directional(grid, from_node, to_node), ft_realizedNoReset(f,tt(t)) )=0;
    r_reserveDemand_largestInfeedUnit_ft(restype, 'up', group, ft_realizedNoReset(f,tt(t)) )=0;

    // group results
    r_stability_rocof_unit_ft(group, ft_realizedNoReset(f,tt(t)) )=0;
    r_userconstraint_ft(group_uc, ft_realizedNoReset(f,tt(t)) )=0;

    // feasibility results
    r_qGen_gnft(inc_dec, gn(grid, node), ft_realizedNoReset(f,tt(t)) )=0;
    r_qGenRamp_gnuft('increase', gnu_rampUp(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_qGenRamp_gnuft('decrease', gnu_rampDown(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_qReserveDemand_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f,tt(t)) )=0;
    r_qReserveMissing_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f,tt(t)) )=0;
    r_qCapacity_ft(gn(grid, node), ft_realizedNoReset(f,tt(t)) ) ${p_gn(grid, node, 'capacityMargin')} =0;
    r_qUnitConstraint_uft(inc_dec, constraint, unit, ft_realizedNoReset(f,tt(t)) ) $ {unitConstraint(unit, constraint)}=0;
    r_qUserconstraint_ft(inc_dec, group_uc, ft_realizedNoReset(f,tt(t)) )=0;

    // Output invariants calculated in 4a because of time series
    r_curtailments_gnft(gn_balance(grid, node), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_unitVOMCost_gnuft(gnu_vomCost(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_unitFuelEmissionCost_gnuft(gnu_vomCost(grid, node, unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_unitStartupCost_uft(unit_startCost(unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_linkVOMCost_gnnft(gn2n_directional_vomCost(grid, node, node_), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_linkNodeCost_gnnft(gn2n_directional_vomCost(grid, node, node_), ft_realizedNoReset(f,tt(t)) )=0;


    // clearing 4a results from the initialization period excluding the last t of the initialization period
    r_state_gnft(gn_state(grid, node), ft_realizedNoReset(f,tt_(t)) )=0;
    r_state_gnsft(gn_state(grid, node), sft_realizedNoReset(s,f,tt_(t)) )=0;
    r_online_uft(unit_online(unit), ft_realizedNoReset(f,tt(t)) )=0;
    r_cost_objectiveFunction_t(tt_) = 0;

); // END if(t_initializationPeriod)


* -- Performance improvements -------------------------------------------------

// get rid of Eps in selected tables. Many zero values missing already and these remove the remaining ones.
r_gen_gnuft(gnu, ft_realizedNoReset(f,t))${(r_gen_gnuft(gnu, f, t)=0)$r_gen_gnuft(gnu, f, t)}=0;
r_gen_delay_gnuft(gnu_delay, ft_realizedNoReset(f,t))${(r_gen_delay_gnuft(gnu_delay, f, t)=0)$r_gen_delay_gnuft(gnu_delay, f, t)}=0;
r_state_gnft(gn_state, ft_realizedNoReset(f,t))${(r_state_gnft(gn_state, f, t)=0)$r_state_gnft(gn_state, f, t)}=0;
r_state_gnsft(gn_state, sft_realizedNoReset(s,f,t))${(r_state_gnsft(gn_state, s, f, t)=0)$r_state_gnsft(gn_state, s, f, t)}=0;
r_balance_marginalValue_gnft(gn_balance, ft_realizedNoReset(f,t))${(r_balance_marginalValue_gnft(gn_balance, f, t)=0)$r_balance_marginalValue_gnft(gn_balance, f, t)}=0;
r_spill_gnft(gn_balance(grid, node_spill(node)), ft_realizedNoReset(f,t))${(r_spill_gnft(grid, node, f, t)=0)$r_spill_gnft(grid, node, f, t)}=0;
r_reserve_gnuft(gnu_resCapable(restype, up_down, gnu), ft_realizedNoReset(f,t))${(r_reserve_gnuft(restype, up_down, gnu, f, t)=0)$r_reserve_gnuft(restype, up_down, gnu, f, t)}=0;
r_reserve_marginalValue_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f,t)) ${(r_reserve_marginalValue_ft(restype, up_down, group, f, t) =0)$r_reserve_marginalValue_ft(restype, up_down, group, f, t)}=0;
r_invest_unitCount_u(unit_invest(unit))${(r_invest_unitCount_u(unit)=0)$r_invest_unitCount_u(unit)}=0;

// get rid of numerical/rounding errors in selected tables. GAMS or solvers sometimes end up printing tiny values when there should be empty.
r_balance_marginalValue_gnft(gn_balance(gn), ft_realizedNoReset(f,t))${(abs(r_balance_marginalValue_gnft(gn, f, t))<1e-10)$r_balance_marginalValue_gnft(gn, f, t)}=0;
r_gen_gnuft(gnu, ft_realizedNoReset(f,t))${(abs(r_gen_gnuft(gnu, f, t))<1e-10)$r_gen_gnuft(gnu, f, t)}=0;
r_spill_gnft(gn_balance(grid, node_spill(node)), ft_realizedNoReset(f,t))${(abs(r_spill_gnft(grid, node, f, t))<1e-10)$r_spill_gnft(grid, node, f, t)}=0;
r_reserve_gnuft(gnu_resCapable(restype, up_down, gnu), ft_realizedNoReset(f,t))${(abs(r_reserve_gnuft(restype, up_down, gnu, f, t))<1e-10)$r_reserve_gnuft(restype, up_down, gnu, f, t)}=0;
r_curtailments_gnft(gn_balance(gn), ft_realizedNoReset(f,t))${(abs(r_curtailments_gnft(gn, f, t))<1e-10)$r_curtailments_gnft(gn, f, t)}=0;


* =============================================================================
* --- Time Step Dependent Results ---------------------------------------------
* =============================================================================

// Need to loop over the model dimension, as this file is no longer contained in the modelSolves loop...
loop(m,

* --- Node result Symbols --------------------------------------------------------
* --- Spill results -----------------------------------------------------------

    // Total energy spill from nodes
    r_spill_gn(grid, node_spill(node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_spill_gnft(grid, node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total spilled energy in each grid over the simulation
    r_spill_g(grid)
        = sum(gn(grid, node_spill(node)), r_spill_gn(grid, node));

    // Total spilled energy gn/g share
    r_spill_gnShare(gn(grid, node_spill))${ r_spill_g(grid) > 0 }
        = r_spill_gn(grid, node_spill)
            / r_spill_g(grid);

* --- Energy Transfer results -------------------------------------------------

    // Total transfer of energy between nodes
    r_transfer_gnn(gn2n(grid, from_node, to_node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_transfer_gnnft(grid, from_node, to_node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)


* --- Other node related results ----------------------------------------------

    // Total curtailments per node
    r_curtailments_gn(gn_balance(grid, node))
        ${sum(flow, flowNode(flow, node))}
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_curtailments_gnft(grid, node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
          ); // END sum (sft_realizedNoReset)

    // Diffusion from node to node_
    // Note that this result paramater does not necessarily consider the
    // implicit node state variable dynamics properly if energyStoredPerUnitOfState
    // is not equal to 0
    r_diffusion_gnnft(gnn_state(grid, node, node_), ft_realizedNoReset(f, t_startp(t)))
        ${gnn_state(grid, node, node_) or gnn_state(grid, node_, node)}
        = p_gnn(grid, node, node_, 'diffCoeff')
            * r_state_gnft(grid, node, f, t)
            * (1 - p_gnn(grid, node, node_, 'diffLosses'))
          - p_gnn(grid, node_, node, 'diffCoeff')
            * r_state_gnft(grid, node_, f, t);

    // Total diffusion of energy between nodes
    r_diffusion_gnn(gnn_state(grid, node, node_))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_diffusion_gnnft(grid, node, node_, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total slack in node
    r_stateSlack_gn(slack, gn_stateSlack(grid, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_stateSlack_gnft(slack, grid, node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
          ); // END sum (sft_realizedNoReset)


* --- Energy Generation/Consumption Result Symbols -------------------------------
* --- Energy Generation results------------------------------------------------

    // Total energy generation in gnu
    r_gen_gnu(gnu(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_gen_gnuft(grid, node, unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // energy generation for each gridnode (MW)
    r_gen_gnft(gn(grid, node), ft_realizedNoReset(f, t_startp(t)))
        = sum(unit, r_gen_gnuft(grid, node, unit, f, t));

    // Total generation in gn
    r_gen_gn(gn(grid, node))
        = sum(unit, r_gen_gnu(grid, node, unit));

    // Total generation in g
    r_gen_g(grid)
       = sum(gn(grid, node), r_gen_gn(grid, node));

    // get rid of rounding errors in selected tables.
    // Sum of generating and consuming units might end up having tiny values where they should be zero.
    r_gen_gnft(gn, ft_realizedNoReset(f, t_startp(t)))${(abs(r_gen_gnft(gn, f, t))<1e-9)$r_gen_gnft(gn, f, t)}=0;
    r_gen_gn(gn)${(abs(r_gen_gn(gn))<1e-9)$r_gen_gn(gn)}=0;
    r_gen_g(grid)${(abs(r_gen_g(grid))<1e-9)$r_gen_g(grid)}=0;

    // Total generation gnu/gn shares
    r_gen_gnuShare(gnu(grid, node, unit))${ r_gen_gn(grid, node) <> 0 }
       = r_gen_gnu(grid, node, unit)
           / r_gen_gn(grid, node);

    // Total generation gn/g shares
    r_gen_gnShare(gn(grid, node))${ r_gen_g(grid) <> 0 }
       = r_gen_gn(grid, node)
           / r_gen_g(grid);

* --- Approximate utilization rates -------------------------------------------

    // Approximate utilization rates for gnu over the simulation
    r_gen_utilizationRate_gnu(gnu(grid, node, unit))${ r_gen_gnu(grid, node, unit)
                                                       and [ p_gnu(grid, node, unit, 'capacity')>0
                                                             or (r_invest_unitCount_u(unit)>0 and p_gnu(grid, node, unit, 'unitSize')>0)
                                                             ]
                                                       }
        = abs(r_gen_gnu(grid, node, unit))
            / [p_gnu(grid, node, unit, 'capacity') + r_invest_unitCount_u(unit)*p_gnu(grid, node, unit, 'unitSize')]
            / sum(sft_realizedNoReset(s, f, t_startp(t)),
                  p_stepLengthNoReset(t)
                  * p_msProbability(m, s)
                  * p_msWeight(m, s)
                ); // END sum(sft_realizedNoReset)

* --- Energy generation results based on input, unittype, or group -------------------------------------------------------

    // Energy output to a node based on inputs from another node or flows
    // Note: this ignores consumption from the node
    r_genByFuel_gnft(gn(grid, node), node_, ft_realizedNoReset(f, t_startp(t)))
        ${sum(gnu_input(grid_, node_, unit)$gnu_output(grid, node, unit), r_gen_gnuft(grid_, node_, unit, f, t)) } //checking node -> node_ mapping to reduce calculation time
        = sum(gnu_output(grid, node, unit)$sum(gnu_input(grid_, node_, unit), 1),   // summing if node_ -> node applies for this unit
            + r_gen_gnuft(grid, node, unit, f, t)    // generation to node
          ); // END sum(gnu_output)

    // temporary set for units with more than one input
    option clear = unit_tmp;
    unit_tmp(unit)$ {sum(gn(grid, node)$gnu_input(grid, node, unit), 1) > 1}
                  = yes;

    if(card(unit_tmp)>0,
        // Temporary uft telling when units are using multiple inputs.
        // Needs to be this complicated as it is possible to define 3 input unit that can operate with 1-3 inputs based on optimization.
        option gnuft_tmp < r_gen_gnuft;
        uft_tmp(unit_tmp(unit), ft_realizedNoReset(f, t_startp(t))) $ { sum(gnuft_tmp(grid, node, unit, f, t)$gnu_input(grid, node, unit), 1) > 1}
        = yes;

        // Rewriting values for cases with units with multiple inputs
        r_genByFuel_gnft(gn(grid, node), node_, ft_realizedNoReset(f, t_startp(t)))
            ${sum(gnu_input(grid_, node_, unit_tmp(unit))$gnu_output(grid, node, unit), r_gen_gnuft(grid_, node_, unit, f, t)) } //checking node -> node_ mapping to reduce calculation time
            = sum(gnu_output(grid, node, unit)${sum(gnu_input(grid_, node_, unit), 1) },   // summing if node_ -> node applies for this unit
                + r_gen_gnuft(grid, node, unit, f, t)    // generation to node
                  * {+1 ${not uft_tmp(unit, f, t)}       // multiplied by 1 if using only 1 input in t
                     +[sum(gnu_input(grid_, node_, unit),    // multiplied by fuel use in node_
                      r_gen_gnuft(grid_, node_, unit, f, t))  // END sum(gnu_input)
                      / sum(gnu_input(grid__, node__, unit),  // divided by total fuel use of the unit
                      r_gen_gnuft(grid__, node__, unit, f, t))  // END sum(gnu_input)
                     ]$uft_tmp(unit, f, t)
                    }
              ); // END sum(gnu_output)

        option clear = gnuft_tmp, clear = uft_tmp;
    ); // END if(unit_tmp)

    // flow units
    r_genByFuel_gnft(gn(grid, node), flow, ft_realizedNoReset(f, t_startp(t)))$flowNode(flow, node)
        = sum(gnu_output(grid, node, unit)$flowUnit(flow, unit),
            + r_gen_gnuft(grid, node, unit, f, t));


    // Total energy generation in gn per input type over the simulation
    r_genByFuel_gn(gn(grid, node), node_)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_genByFuel_gnft(grid, node, node_, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)
    r_genByFuel_gn(gn(grid, node), flow)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_genByFuel_gnft(grid, node, flow, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total energy generation in grids per input type over the simulation
    r_genByFuel_g(grid, node_)
        = sum(gn(grid, node), r_genByFuel_gn(grid, node, node_));
    r_genByFuel_g(grid, flow)
        = sum(gn(grid, node), r_genByFuel_gn(grid, node, flow));

    // Total overall energy generation per input type over the simulation
    r_genByFuel_fuel(node_)
        = sum(gn(grid, node), r_genByFuel_gn(grid, node, node_));
    r_genByFuel_fuel(flow)
        = sum(gn(grid, node), r_genByFuel_gn(grid, node, flow));

    // Total energy generation in gn per input type as a share of total included energy generation in gn across all input types
    r_genByFuel_gnShare(gn(grid, node), node_)${ r_genByFuel_gn(grid, node, node_)
                                                 and [(sum(node__, r_genByFuel_gn(grid, node, node__)) + sum(flow_, r_genByFuel_gn(grid, node, flow_)) )>0 ]
                                                 }
        = r_genByFuel_gn(grid, node, node_)
            / (sum(node__, r_genByFuel_gn(grid, node, node__))
               + sum(flow_, r_genByFuel_gn(grid, node, flow_))
               );
    r_genByFuel_gnShare(gn(grid, node), flow)${ r_genByFuel_gn(grid, node, flow)
                                                and [(sum(node__, r_genByFuel_gn(grid, node, node__)) + sum(flow_, r_genByFuel_gn(grid, node, flow_)))>0 ]
                                                }
        = r_genByFuel_gn(grid, node, flow)
            / (sum(node__, r_genByFuel_gn(grid, node, node__))
               + sum(flow_, r_genByFuel_gn(grid, node, flow_))
              );

    // Energy generation for each unittype
    r_genByUnittype_gnft(gn(grid, node), unittype, ft_realizedNoReset(f, t_startp(t)))
        = sum(gnu(grid, node, unit)$unitUnittype(unit, unittype),
            + r_gen_gnuft(grid, node, unit, f, t)
            ); // END sum(unit)

    // Total energy generation in gnu by unit type
    r_genByUnittype_gn(gn(grid, node), unittype)${ sum(unit$unitUnittype(unit, unittype), 1) }
      = sum(gnu(grid,node,unit)$unitUnittype(unit, unittype),
             + r_gen_gnu(grid, node, unit)
            ); // END sum(gnu)

    // Total energy generation in gnu by unit type
    r_genByUnittype_g(grid, unittype)
      = sum(gn(grid,node),
             + r_genByUnittype_gn(grid, node, unittype)
            ); // END sum(gn)

    // gnTotalgen in units that belong to gnuGroups over the simulation
    r_genByGnuGroup_gn(grid, node, group)
        = sum(unit $ {gnuGroup(grid, node, unit, group)},
            + r_gen_gnu(grid, node, unit)
            ); // END sum(unit)

* --- Energy consumption during startups --------------------------------------

    // Unit start-up consumption
    r_gen_unitStartupConsumption_nuft(nu_startup(node, unit), ft_realizedNoReset(f, t_startp(t)))
        ${sum(starttype, unitStarttype(unit, starttype))}
        = sum(unitStarttype(unit, starttype),
            + r_startup_uft(starttype, unit, f, t)
                * p_unStartup(unit, node, starttype) // MWh/start-up
            ); // END sum(unitStarttype)

    // Sum of unit start-up consumption
    r_gen_unitStartupConsumption_nu(nu_startup(node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_gen_unitStartupConsumption_nuft(node, unit, f, t)
              * p_msProbability(m, s)
              * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

* --- Unit Online, startup, and shutdown Result Symbols ---------------------------------------
* --- other online, startup, and shutdown results ---------------------------------------

    // Total sub-unit-hours for units over the simulation
    r_online_u(unit)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_online_uft(unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total unit online hours per sub-unit over the simulation
    r_online_perUnit_u(unit)${ p_unit(unit, 'unitCount') > 0 }
        = r_online_u(unit)
            / p_unit(unit, 'unitCount');

    // Total sub-unit startups over the simulation
    r_startup_u(unit, starttype)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_startup_uft(starttype, unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total sub-unit shutdowns over the simulation
    r_shutdown_u(unit)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_shutdown_uft(unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)


* --- Investment Result Symbols ---------------------------------------

    // Capacity of unit investments
    r_invest_unitCapacity_gnu(grid, node, unit)${ r_invest_unitCount_u(unit) }
        = r_invest_unitCount_u(unit)
          * p_gnu(grid, node, unit, 'unitSize')
    ;

    // Energy consumed due to unit investments
    r_invest_unitEnergyCost_gnu(grid, node, unit)${ r_invest_unitCount_u(unit)
                                                    and p_gnu(grid, node, unit, 'invEnergyCost')
                                                    }
        = r_invest_unitCount_u(unit)
          * p_gnu(grid, node, unit, 'unitSize')
          * p_gnu(grid, node, unit, 'invEnergyCost')
    ;

* --- Emission results ---------------------------------------
* --- Emissions by activity type ---------------------------------------------

    // Emissions during normal operation (tEmission)
    r_emission_operationEmissions_gnuft(gn(grid, node), emission, unit, ft_realizedNoReset(f, t_startp(t)))
        $ {p_nEmission(node, emission)
           or p_gnuEmission(grid, node, unit, emission, 'vomEmissions')
          }
        =   + p_stepLengthNoReset(t)
            * (
               // Emissions from fuel use (gn related emissions)
               // multiply by -1 because consumption in r_gen is negative and production positive
               -r_gen_gnuft(grid, node, unit, f, t) * p_nEmission(node, emission)
               // Emissions from unit operation (gnu related vomEmissions)
               // absolute values as all unit specific emission factors are considered as emissions by default
               + abs(r_gen_gnuft(grid, node, unit, f, t)) * p_gnuEmission(grid, node, unit, emission, 'vomEmissions') // t/MWh
              ); // END *p_stepLengthNoReset

    // Emission sums from normal operation, gnu sum (tEmission)
    r_emission_operationEmissions_gnu(gnu(grid, node, unit), emission)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
              + r_emission_operationEmissions_gnuft(grid, node, emission, unit, f, t)
              * p_msProbability(m, s)
              * p_msWeight(m, s)
          ); // END sum(sft_realizedNoReset)

    // Emission sums from normal operation, nu sum (tEmission)
    r_emission_operationEmissions_nu(nu(node, unit), emission)
        = sum(gn(grid, node), r_emission_operationEmissions_gnu(grid, node, unit, emission)
          ); // END sum(gn)

    // Emissions from unit start-ups (tEmission)
    r_emission_startupEmissions_nuft(node, emission, unit, ft_realizedNoReset(f, t_startp(t)))
        ${sum(starttype, p_unStartup(unit, node, starttype))
          and p_nEmission(node, emission)
         }
        = sum(unitStarttype(unit, starttype),
            + r_startup_uft(starttype, unit, f, t) // number of startups
                * p_unStartup(unit, node, starttype) // MWh_fuel/startup
                * p_nEmission(node, emission) // tEmission/MWh_fuel
            ); // END sum(starttype)

    // Emission sums from start-ups, nu sum (tEmission)
    r_emission_StartupEmissions_nu(nu_startup(node, unit), emission)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_emission_startupEmissions_nuft(node, emission, unit, f, t)
                 * p_msProbability(m, s)
                 * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Emissions from fixed o&m emissions and investments (tEmission)
    r_emission_capacityEmissions_nu(node, unit, emission)
        ${[sum(gn, p_gnuEmission(gn, unit, emission, 'fomEmissions'))
           or sum(gn, p_gnuEmission(gn, unit, emission, 'invEmissions'))
           ]
          and [sum(grid, p_gnu(grid, node, unit, 'capacity'))>0
               or sum(grid, r_invest_unitCapacity_gnu(grid, node, unit))>0
               ]
          }
        = + sum(grid$p_gnuEmission(grid, node, unit, emission, 'fomEmissions'),
               p_gnuEmission(grid, node, unit, emission, 'fomEmissions')
               * (p_gnu(grid, node, unit, 'capacity')
                  + r_invest_unitCapacity_gnu(grid, node, unit))
            ) // END sum(gn)
          + sum(grid$p_gnuEmission(grid, node, unit, emission, 'invEmissions'),
               p_gnuEmission(grid, node, unit, emission, 'invEmissions')
               * r_invest_unitCapacity_gnu(grid, node, unit)
               * p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor')
            ); // END sum(gn)

* --- Emission Sum Results ----------------------------------------------------

    // Emission in gnGroup
    r_emissionByNodeGroup(emission, group)
        // Emissions from operation: consumption and production of fuels - gn related emissions (tEmission)
        = + sum(gnu(grid, node, unit)${gnGroup(grid, node, group)},
                + r_emission_operationEmissions_gnu(grid, node, unit, emission)
                ) // END sum(gnu)
        // Emissions from operation: Start-up emissions (tEmission)
        + sum(nu_startup(node, unit)${sum(grid, gnGroup(grid, node, group)) and p_nEmission(node, emission)},
              r_emission_startupEmissions_nu(node, unit, emission)
              ) // END sum(nu_startup)
        // Emissions from capacity: fixed o&m emissions and investment emissions (tEmission)
        + sum(gnu(grid, node, unit)${ gnGroup(grid, node, group) },
              r_emission_capacityEmissions_nu(node, unit, emission)
              ) // END sum(gnu)
    ;
    // Total emissions by node and unit
    r_emission_nu(nu(node, unit), emission)
        = r_emission_operationEmissions_nu(node, unit, emission)
            + r_emission_StartupEmissions_nu(node, unit, emission)
            + r_emission_capacityEmissions_nu(node, unit, emission)
    ;
    // Total emissions by node
    r_emission_n(node, emission)
        = sum(unit, r_emission_nu(node, unit, emission))
    ;
    // Total emissions by grid
    r_emission_g(grid, emission)
        = sum(gn(grid, node), r_emission_n(node, emission))
    ;
    // Total emissions by unit
    r_emission_u(unit, emission)
        = sum(node, r_emission_nu(node, unit, emission))
    ;
    // Total emissions
    r_emission(emission)
        = sum(node, r_emission_n(node, emission))
    ;

* --- Reserve Result Symbols ---------------------------------------
* --- Unit level reserve Results ---------------------------------------------

    // Total reserve provisions over the simulation
    r_reserve_gnu(gnu_resCapable(restype, up_down, grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_reserve_gnuft(restype, up_down, grid, node, unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total reserve provisions over the simulation
    r_reserve_gn(restype, up_down, grid, node)
        =  sum(unit, r_reserve_gnu(restype, up_down, grid, node, unit))
    ;

    // Total reserve provisions over the simulation
    r_reserve_g(restype, up_down, grid)
        =  sum(gn(grid, node), r_reserve_gn(restype, up_down, grid, node) )
    ;

    // Group sum of reserves of specific types (MW)
    r_reserveByGroup_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f, t_startp(t)) )
        = sum(gnu(grid, node, unit)${ gnGroup(grid, node, group)
                                              and groupRestype(group, restype)
                                              },
            + r_reserve_gnuft(restype, up_down, grid, node, unit, f, t)
          ); // END sum(gnu)

    // Total reserve provision in groups over the simulation
    r_reserveByGroup(restypeDirectionGroup(restype, up_down, group))
        = sum(gnu_resCapable(restype, up_down, grid, node, unit)${gnGroup(grid, node, group)},
            + r_reserve_gnu(restype, up_down, grid, node, unit)
        ); // END sum(gnu_resCapable)

    r_reserve_gnuShare(gnu_resCapable(restype, up_down, grid, node, unit))
        ${ sum(gnGroup(grid, node, group), r_reserveByGroup(restype, up_down, group)) > 0 }
        = r_reserve_gnu(restype, up_down, grid, node, unit)
            / sum(gnGroup(grid, node, group), r_reserveByGroup(restype, up_down, group));

    // Calculate the overlapping reserve provisions
    r_reserve2Reserve_gnuft(gnu_resCapable(restype, up_down, grid, node, unit), restype_, ft_realizedNoReset(f, t_startp(t)))
        ${ p_gnuRes2Res(grid, node, unit, restype, up_down, restype_) }
        = r_reserve_gnuft(restype, up_down, grid, node, unit, f, t)
            * p_gnuRes2Res(grid, node, unit, restype, up_down, restype_);

* --- Other reserve Results ---------------------------------------------

    r_reserve_marginalValue_average(restype, up_down, group)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
             + r_reserve_marginalValue_ft(restype, up_down, group, f, t)
                // * p_stepLengthNoReset(t)   // not including steplength due to division by number of timesteps
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ) // END sum(sft_realizedNoReset)
            / (card(t_startp)) // divided by number of realized time steps
            ;

    // Total reserve to markets
    r_reserveMarkets(restype, up_down, group)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
             + r_reserveMarkets_ft(restype, up_down, group, f, t)
                * p_stepLengthNoReset(t)   // not including steplength due to division by number of timesteps
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ) // END sum(sft_realizedNoReset)
            ;

    // Total reserve transfer rightward over the simulation
    r_reserveTransferRightward_gnn(restype, up_down, grid, node, to_node)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_reserveTransferRightward_gnnft(restype, up_down, grid, node, to_node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total reserve transfer leftward over the simulation
    r_reserveTransferLeftward_gnn(restype, up_down, grid, node, to_node)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_reserveTransferLeftward_gnnft(restype, up_down, grid, node, to_node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)


* --- Additional state results ----------------------------------------------------

    // temporary sets for the first and last t
    Option clear = tt;
    tt(t_realizedNoReset(t))${ord(t) = mSettings(m, 't_start') + mSettings(m, 't_initializationPeriod')} = yes;  // storage start state initiated at t_start-1
    Option clear = tt_;
    tt_(t_realizedNoReset(t))${ord(t) = mSettings(m, 't_end')+1} = yes; // storage end state at t_end

    // state change between the first and the last t
    r_stateChange_gn(gn_state(grid, node))
        = + sum((f_realization(f), tt_(t)), r_state_gnft(grid, node, f, t))
          - sum((f_realization(f), tt(t)), r_state_gnft(grid, node, f, t))  ;

    // Full load cycles of storages
    loop(gn_state(grid, node),
        // Finding maximum storage capacity used in the estimate
        tmp = [ // max capacity, constant
              + (p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
                   * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
                   )$p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')
              // max capacity, ts
              + (smax(ft_realizedNoReset(f, t_startp(t)), (ts_node(grid, node, 'upwardLimit', f, t)))
                   * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
                   )$p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeseries')

              // max capacity, from units
              + sum(gnu(grid, node, unit)$p_gnu(grid, node, unit, 'upperLimitCapacityRatio'),
                  + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                    * p_gnu(grid, node, unit, 'unitSize')
                    * [ // existing units
                        + p_unit(unit, 'unitCount')
                        // investments
                        + r_invest_unitCount_u(unit)
                        ]
                  ) // END sum(gnu)

              // min capacity, constant
              - (p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'constant')
                   * p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'multiplier')
                   )$p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')

              // min capacity, ts
              - (smin(ft_realizedNoReset(f, t_startp(t)), (ts_node(grid, node, 'downwardLimit', f, t)))
                   * p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'multiplier')
                   )$p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeseries')
              ];

        // sum to storage from units (unit output) divided by storage maximum capacity.
        r_state_fullCycles_gn(grid, node, 'input')${tmp > 0}
            = sum(gnu_output(grid, node, unit), r_gen_gnu(grid, node, unit))
                / tmp;

        // sum from storage to units (unit input) divided by storage maximum capacity. Converting unit input to positive numbers.
        r_state_fullCycles_gn(grid, node, 'output')${tmp > 0}
            = -sum(gnu_input(grid, node, unit), r_gen_gnu(grid, node, unit))
                 / tmp;

        ); // END loop(gn_state)

* --- Marginal value of energy results ----------------------------------------

    // calculating the average of marginal values if marginal values do not reach dummy variables
    // if constant dummy values
    r_balance_marginalValue_gnAverage(gn_balance(grid, node))
        ${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')
          and sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< PENALTY_BALANCE(grid, node)}, 1) }
        = sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< PENALTY_BALANCE(grid, node)},
             + r_balance_marginalValue_gnft(grid, node, f, t)
                // * p_stepLengthNoReset(t)   // not including steplength due to division by number of timesteps
                * p_msProbability(m, s)
                //* p_msWeight(m, s)$(not mSolve('invest')) //only for non-investment runs
            ) // END sum(sft_realizedNoReset)
            / sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< PENALTY_BALANCE(grid, node)}, 1)
            ;

    // calculating the average of marginal values if marginal values do not reach user defined dummy variables
    // if time series for dummy values
    r_balance_marginalValue_gnAverage(gn_balance(grid, node))
        ${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')
          and sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< ts_node(grid, node, 'balancePenalty', f, t)}, 1)}
        = sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< ts_node(grid, node, 'balancePenalty', f, t)},
             + r_balance_marginalValue_gnft(grid, node, f, t)
                // * p_stepLengthNoReset(t)   // not including steplength due to division by number of timesteps
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ) // END sum(sft_realizedNoReset)
            / sum(sft_realizedNoReset(s, f, t_startp(t))${abs(r_balance_marginalValue_gnft(grid, node, f, t))< ts_node(grid, node, 'balancePenalty', f, t)}, 1)
            ;


* --- Group Result Symbols ----------------------------------------------------

    // Total value of r_userconstraint_ft if the type of the userconstraint is 'toVariable'
    r_userconstraint(group_uc)
        $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep')) }
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_userconstraint_ft(group_uc, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    r_userconstraint(group_uc)
        $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps')) }
        = v_userconstraint_LP.l(group_uc) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
          + v_userconstraint_MIP.l(group_uc) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable');


* --- Dummy Result Symbols ----------------------------------------------------
* --- Results regarding solution feasibility ----------------------------------

    // Total dummy generation/consumption in gn
    r_qGen_gn(inc_dec, gn(grid, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qGen_gnft(inc_dec, grid, node, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total dummy generation in g
    r_qGen_g(inc_dec, grid)
        = sum(gn(grid, node), r_qGen_gn(inc_dec, grid, node));

    // Total dummy ramps in gnu. Maintaining the inc_dec in dimensions
    r_qGenRamp_gnu('increase', gnu_rampUp(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qGenRamp_gnuft('increase', grid, node, unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)
    r_qGenRamp_gnu('decrease', gnu_rampDown(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qGenRamp_gnuft('decrease', grid, node, unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total dummy reserve provisions over the simulation
    r_qReserveDemand(restypeDirectionGroup(restype, up_down, group))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qReserveDemand_ft(restype, up_down, group, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total dummy reserve decrease over the simulation
    r_qReserveMissing(restypeDirectionGroup(restype, up_down, group))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qReserveMissing_ft(restype, up_down, group, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    // Total dummy generation/consumption in gn
    r_qUnitConstraint_u(inc_dec, constraint, unit) $ unitConstraint(unit, constraint)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qUnitConstraint_uft(inc_dec, constraint, unit, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)

    r_qUserconstraint(inc_dec, group_uc)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_qUserconstraint_ft(inc_dec, group_uc, f, t)
                * p_stepLengthNoReset(t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            ); // END sum(sft_realizedNoReset)


* --- Cost result Symbols -----------------------------------------------------------
* --- Unit operational Cost Components ----------------------------------------------

    // Total unit VOM costs
    r_cost_unitVOMCost_gnu(gnu(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_unitVOMCost_gnuft(grid, node, unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total fuel & emission costs
    r_cost_unitFuelEmissionCost_u(gnu(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_unitFuelEmissionCost_gnuft(grid, node, unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total unit startup costs
    r_cost_unitStartupCost_u(unit_startcost(unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_unitStartupCost_uft(unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Unit shutdown costs (MEUR)
    r_cost_unitShutdownCost_uft(unit, f, t)
        = 1e-6 // Scaling to MEUR
            * r_shutdown_uft(unit, f, t) // number of shutdowns
            * p_uShutdown(unit, 'cost') // EUR/shutdown
          ;

    // Total unit shutdown costs over the simulation (MEUR)
    r_cost_unitShutdownCost_u(unit)
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_unitShutdownCost_uft(unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total unit ramp costs
    r_cost_unitRampCost_gnu(gnu(grid, node, unit))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_unitRampCost_gnuft(grid, node, unit, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total gnu fixed O&M costs over the simulation, existing and invested units (MEUR)
    r_cost_unitFOMCost_gnu(gnu(grid, node, unit))
        ${ sum(s, us(unit, s))
           and ([p_gnu(grid, node, unit, 'unitSize') * p_unit(unit, 'unitCount')]<1e10)  // excluding cases if capacity input data is given as inf instead of empty. Calculating from unitSize * unitCount to match the approach in 2c_objective.gms.
           and [[p_gnu(grid, node, unit, 'unitSize') * p_unit(unit, 'unitCount')]>0      // excluding cases where capacity = Eps. Calculating from unitSize * unitCount to match the approach in 2c_objective.gms.
                or r_invest_unitCount_u(unit)>0
                ]
           }
        = 1e-6 // Scaling to MEUR
            * sum(s_active(s), // consider active s only if it has active sft
                + [
                    + p_unit(unit, 'unitCount')        // existing capacity
                    + r_invest_unitCount_u(unit)       // new investments
                    ]
                    * p_gnu(grid, node, unit, 'unitSize')
                    * p_msAnnuityWeight(m, s) // Sample weighting to calculate annual costs
                    * p_s_discountFactor(s) // Discount costs
                ) // END * sum(s_active)
            * p_gnu(grid, node, unit, 'fomCosts');

    // Unit investment costs
    r_cost_unitInvestmentCost_gnu(gnu(grid, node, unit))
        = 1e-6 // Scaling to MEUR
            * sum(s_active(s), // consider active s only if it has active sft
                + r_invest_unitCount_u(unit)
                    * p_msAnnuityWeight(m, s) // Sample weighting to calculate annual costs
                    * p_s_discountFactor(s) // Discount costs
                ) // END * sum(s_active)
            * p_gnu(grid, node, unit, 'unitSize')
            * p_gnu(grid, node, unit, 'invCosts')
            * p_gnu(grid, node, unit, 'annuityFactor');

    // Cost from unit FOM emissions and investment emissions (MEUR)
    r_cost_unitCapacityEmissionCost_nu(node, unit)
        ${ sum(s, us(unit, s)) }
        = 1e-6 // Scaling to MEUR
            * sum(s_active(s), // consider active s only if it has active sft
                +p_msAnnuityWeight(m, s) // Sample weighting to calculate annual costs
                * p_s_discountFactor(s) // Discount costs

                * sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                    + r_emission_capacityEmissions_nu(node, unit, emission)
                    * [ + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')
                        + p_emissionPrice(emission, group, 'average')$p_emissionPrice(emission, group, 'useTimeSeries')
                        + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'price')$p_emissionPriceNew(emission, group, f, 'useConstant'))
                        + sum(f_realization(f), p_emissionPriceNew(emission, group, f, 'average')$p_emissionPriceNew(emission, group, f, 'useTimeSeries'))
                      ]// END * p_gnuEmssion
                    ) // END sum(emissionGroup)
                ); // END * sum(s_active)


* --- Transfer Link Operational Cost Components ----------------------------------------------

    // Total Variable Transfer costs
    r_cost_linkVOMCost_gnn(gn2n_directional(grid, node, node_))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_linkVOMCost_gnnft(grid, node, node_, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total Transfer node costs
    r_cost_linkNodeCost_gnn(gn2n_directional(grid, node_, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_linkNodeCost_gnnft(grid, node_, node, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Transfer link investment costs
    r_cost_linkInvestmentCost_gnn(gn2n_directional(grid, from_node, to_node)) // gn2n_directional only, as in q_obj
        = 1e-6 // Scaling to MEUR
            * sum(s_active(s), // consider active s only if it has active sft
                + sum(t_invest(t)${ord(t) <= msEnd(m, s)}, // only if investment was made before or during the sample
                    + r_invest_transferCapacity_gnn(grid, from_node, to_node, t)
                    )
                    * p_msAnnuityWeight(m, s) // Sample weighting to calculate annual costs
                    * p_s_discountFactor(s) // Discount costs
                ) // END * sum(s_active)
            * [
                + p_gnn(grid, from_node, to_node, 'invCost')
                    * p_gnn(grid, from_node, to_node, 'annuityFactor')
                + p_gnn(grid, to_node, from_node, 'invCost')
                    * p_gnn(grid, to_node, from_node, 'annuityFactor')
                ]; // END * r_invest_transferCapacity_gnn;


* --- Nodel Cost Components ----------------------------------------------

    // Node state slack costs
    r_cost_stateSlackCost_gnt(gn_stateSlack(grid, node), ft_realizedNoReset(f, t_startp(t)))
        = 1e-6 // Scaling to MEUR
            * p_stepLengthNoReset(t)
            * sum(slack${ p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost') },
                + r_stateSlack_gnft(slack, grid, node, f, t)
                    * p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')
                ); // END sum(slack)

    // Total state variable slack costs
    r_cost_stateSlackCost_gn(gn_stateSlack(grid, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_stateSlackCost_gnt(grid, node, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Storage Value Change
    r_cost_storageValueChange_gn(gn_state(grid, node))${ active(m, 'storageValue') }    // search key: activeFeatures
        = 1e-6
            * [
                + sum(ft_realizedNoReset(f, t)${ ord(t) = mSettings(m, 't_end') + 1 },
                    + [
                        + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                        + ts_storageValue(grid, node, f, t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                      ]
                        * r_state_gnft(grid, node, f, t)
                    ) // END sum(ft_realizedNoReset)
                - sum(ft_realizedNoReset(f, t)${ ord(t) = mSettings(m, 't_start') + mSettings(m, 't_initializationPeriod') }, // INITIAL v_state NOW INCLUDED IN THE RESULTS
                    + [
                        + p_storageValue(grid, node)${ not p_gn(grid, node, 'storageValueUseTimeSeries') }
                        + ts_storageValue(grid, node, f, t)${ p_gn(grid, node, 'storageValueUseTimeSeries') }
                      ]
                        * r_state_gnft(grid, node, f, t)
                    ) // END sum(ft_realizedNoReset)
                ]; // END * 1e-6

* --- Reserve Cost Components -------------------------------------------------

    // revenue from selling reserves to markets
    r_cost_reserveMarkets_ft(restypeDirectionGroup(restype, up_down, group), ft_realizedNoReset(f, t_startp(t)) )
        $ p_groupReserves(group, restype, 'usePrice')
        = 1e-6
            * [ // negative as selling to markets
                - r_reserveMarkets_ft(restype, up_down, group, f, t)
                    * (+p_reservePrice(restype, up_down, group, f, 'price')${ p_reservePrice(restype, up_down, group, f, 'useConstant') }
                       +ts_reservePrice(restype, up_down, group, f, t)${ p_reservePrice(restype, up_down, group, f, 'useTimeSeries') }
                       )
                ]; // END * 1e-6

    // Total revenue from selling reserves to markets
    r_cost_reserveMarkets(restypeDirectionGroup(restype, up_down, group))
        $ p_groupReserves(group, restype, 'usePrice')
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_reserveMarkets_ft(restype, up_down, group, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

* --- Other Cost Components ---------------------------------------------------

    // Cost from userconstraint when using toVariable equation type and enabling 'cost' parameter (MEUR)
    r_cost_userconstraint_t(group_uc, t_startp(t))
        ${groupUcParamUserconstraint(group_uc, 'cost')
          and groupUcParamUserconstraint(group_uc, 'eachTimestep')
          }
        = 1e-6
          * sum(f_realization(f),
             + r_userconstraint_ft(group_uc, f, t)
               * sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'cost'))
          ); // END sum(f_realization)

    // Total costs from userconstraints
    r_cost_userconstraint(group_uc)
        ${groupUcParamUserconstraint(group_uc, 'cost') }
        = 1e-6
          * r_userconstraint(group_uc)
          * p_userconstraint(group_uc, '-', '-', '-', '-', 'cost');

* --- Realized System Operating Costs -----------------------------------------

    // Total realized gn operating costs
    r_cost_realizedOperatingCost_gnft(gn(grid, node), ft_realizedNoReset(f, t_startp(t)))
        = // VOM costs
          + sum(gnu(grid, node, unit),
              + r_cost_unitVOMCost_gnuft(grid, node, unit, f, t)
              + r_cost_unitFuelEmissionCost_gnuft(grid, node, unit, f, t)
              + r_cost_unitRampCost_gnuft(grid, node, unit, f, t)
            )

          // Allocate startup costs on energy basis, but for output nodes only
          + sum(unit$(r_gen_gnuft(grid, node, unit, f, t)$gnu_output(grid, node, unit)),
              + abs{r_gen_gnuft(grid, node, unit, f, t)}  // abs is due to potential negative outputs like energy from a cooling unit. It's the energy contribution that matters, not direction.
                   / sum(gnu_output(grid_output, node_output, unit),
                       + abs{r_gen_gnuft(grid_output, node_output, unit, f, t)}
                     ) // END sum(gnu_output)
                * r_cost_unitStartupCost_uft(unit, f, t)
            )
          // Allocate reserve market revenues
          // likely does not handle res2res transfers correctly
          + [ sum(restypeDirectionGroup(restype, up_down, group), r_cost_reserveMarkets_ft(restype, up_down, group, f, t))   // total revenues
               / sum(restypeDirectionGroup(restype, up_down, group), r_reserveMarkets_ft(restype, up_down, group, f, t))    // reserves provided to markets
               * sum(gnu_resCapable(restype, up_down, grid, node, unit), r_reserve_gnuft(restype, up_down, grid, node, unit, f, t))  // reserves provided by units in gn
               ] $ {sum(restypeDirectionGroup(restype, up_down, group), p_groupReserves(group, restype, 'usePrice')) // if usePrice activated
                    and sum(restypeDirectionGroup(restype, up_down, group), r_cost_reserveMarkets_ft(restype, up_down, group, f, t))} // if values in the r_cost_reserveMarkets_ft

          // Transfer link variable costs
          + sum(gn2n_directional(grid, node_, node),
              + r_cost_linkVOMCost_gnnft(grid, node_, node, f, t)
              + r_cost_linkNodeCost_gnnft(grid, node_, node, f, t)
            )

          // Node state slack costs
          + r_cost_stateSlackCost_gnt(grid, node, f, t)
    ;

    // Total realized operating costs on each gn over the simulation
    r_cost_realizedOperatingCost_gn(gn(grid, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_realizedOperatingCost_gnft(grid, node, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)

    // Total realized operating costs on each grid over the simulation
    r_cost_realizedOperatingCost_g(grid)
        = sum(gn(grid, node), r_cost_realizedOperatingCost_gn(grid, node));

    // Total realized system operating costs over the simulation: gn cost + userconstraint cost (MEUR)
    r_cost_realizedOperatingCost
        = sum(gn(grid, node), r_cost_realizedOperatingCost_gn(grid, node))   // gn costs
          + sum(group_uc, r_cost_userconstraint(group_uc));                  // + userconstraint costs

    // Total realized operating costs gn/g share
    r_cost_realizedOperatingCost_gnShare(gn(grid, node))${ r_cost_realizedOperatingCost_g(grid) <> 0 }
        = r_cost_realizedOperatingCost_gn(grid, node)
            / r_cost_realizedOperatingCost_g(grid);

    // Total realized net operating costs on each gn over the simulation
    r_cost_realizedNetOperatingCost_gn(gn(grid, node))
        = r_cost_realizedOperatingCost_gn(grid, node)                        // gn costs
          - r_cost_storageValueChange_gn(grid, node);                        // - storage value change

    // Total realized net operating costs on each grid over the simulation
    r_cost_realizedNetOperatingCost_g(grid)
        = sum(gn(grid, node), r_cost_realizedNetOperatingCost_gn(grid, node));

    // Total realized system operating costs over the simulation: gn cost + userconstraint cost - the increase in storage values (MEUR)
    r_cost_realizedNetOperatingCost
        = sum(gn(grid, node), r_cost_realizedNetOperatingCost_gn(grid, node))  // gn costs - storage value change
          + sum(group_uc, r_cost_userconstraint(group_uc));                    // + userconstraint costs

* --- Realized System Costs ---------------------------------------------

    // Total realized costs on each gn over the simulation
    r_cost_realizedCost_gn(gn(grid, node))
        = r_cost_realizedOperatingCost_gn(grid, node)
           // unit costs to nodes
           + sum(gnu(grid, node, unit),
                + r_cost_unitFOMCost_gnu(grid, node, unit)
                + r_cost_unitInvestmentCost_gnu(grid, node, unit)
                )
           // transfer link investment costs to nodes
           // Half of the link costs are allocated to the receiving end
            + sum(gn2n_directional(grid, from_node, node),
                + r_cost_linkInvestmentCost_gnn(grid, from_node, node)
                )  / 2
            // Half of the link costs are allocated to the sending end
            + sum(gn2n_directional(grid, node, to_node),
                + r_cost_linkInvestmentCost_gnn(grid, node, to_node)
            )  / 2  ;

    // Total realized costs on each grid over the simulation
    r_cost_realizedCost_g(grid)
        = sum(gn(grid, node), r_cost_realizedCost_gn(grid, node));

    // Total realized system costs over the simulation: gn cost + userconstraint cost (MEUR)
    r_cost_realizedCost
        = sum(gn(grid, node), r_cost_realizedCost_gn(grid, node))              // gn costs
          + sum(group_uc, r_cost_userconstraint(group_uc));                    // + userconstraint costs

    // Total realized costs gn/g share
    r_cost_realizedCost_gnShare(gn(grid, node))${ r_cost_realizedCost_g(grid) <> 0 }
        = r_cost_realizedCost_gn(grid, node)
            / r_cost_realizedCost_g(grid);

    // Total realized net costs on each gn over the simulation
    r_cost_realizedNetCost_gn(gn(grid, node))
        = r_cost_realizedCost_gn(grid, node)                                   // gn costs
          - r_cost_storageValueChange_gn(grid, node);                          // - storage value change

    // Total realized net costs on each grid over the simulation
    r_cost_realizedNetCost_g(grid)
        = sum(gn(grid, node), r_cost_realizedNetCost_gn(grid, node));

    // Total realized system costs over the simulation: gn cost + userconstraint cost - the increase in storage values (MEUR)
    r_cost_realizedNetCost
        = sum(gn(grid, node), r_cost_realizedNetCost_gn(grid, node))           // gn costs
          + sum(group_uc, r_cost_userconstraint(group_uc));                    // + userconstraint costs




* --- Penalty costs -----------------------------------------------------------

    // Total penalty costs in all dummy result tables for each t (MEUR). Note: Not included in total costs.
    r_cost_penalty_ft(f_realization(f), t_startp(t))
        = // r_qGen
          + sum((inc_dec, gn(grid, node)) $ r_qGen_gn(inc_dec, gn),
                r_qGen_gnft(inc_dec, gn, f, t)
                * [ + PENALTY_BALANCE(grid, node)${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
                    + ts_node(grid, node, 'balancePenalty', f, t)${p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')}
                    ]
            ) // END sum(inc_dec, gn_tmp)

    // r_qGenRamp
          + sum((inc_dec, gnu_rampUp(grid, node, unit)) $ r_qGenRamp_gnu('increase', gnu_rampUp) ,
              r_qGenRamp_gnuft('increase', grid, node, unit, f, t)
              * PENALTY_GENRAMP(grid, node, unit)
            ) // END sum(inc_dec, gnu_rampUp)
          + sum((inc_dec, gnu_rampDown(grid, node, unit)) $ r_qGenRamp_gnu('decrease', gnu_rampDown) ,
              r_qGenRamp_gnuft('decrease', grid, node, unit, f, t)
              * PENALTY_GENRAMP(grid, node, unit)
            ) // END sum(inc_dec, gnu_rampUp)

    // r_qReserveMissing
          + sum(restypeDirectionGroup(restype, up_down, group)$r_qReserveMissing(restypeDirectionGroup),
              r_qReserveMissing_ft(restype, up_down, group, f, t)
              * PENALTY_RES_MISSING(restype, up_down)
            ) // END sum(restypeDirectionGroup)

    // r_qCapacity
          + sum(gn $ p_gn(gn, 'capacityMargin'),
                r_qCapacity_ft(gn, f, t)
                * PENALTY_CAPACITY(gn)
            ) // END sum(gn_tmp_)

    // r_qUnitConstraint
          + sum((inc_dec, unitConstraint(unit, constraint)) $ r_qUnitConstraint_u(inc_dec, constraint, unit),
              r_qUnitConstraint_uft(inc_dec, constraint, unit, f, t)
              * PENALTY
            ) // END sum(inc_dec, unitConstraint)

    // r_qUserconstraint
          + sum((inc_dec, group_uc) $ r_qUserconstraint(inc_dec, group_uc),
              r_qUserconstraint_ft(inc_dec, group_uc, f, t)
              * PENALTY_UC(group_uc)
            ) // END sum(inc_dec, group_uc)
    ; // END r_cost_penalty_ft


    // Total penalty costs in all dummy result tables over the simulation (MEUR). Note: Not included in total costs.
    r_cost_penalty
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_cost_penalty_ft(f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ); // END sum(sft_realizedNoReset)


* --- Approximated profits ----------------------------------------------------

    // State change multiplied by average marginal value
    // NOTE: This is very similar to r_cost_storageValueChange_gn, but does not impact
    // optimization through objective function and is based on average marginal values
    // instead of user given storage values
    r_stateChangeValue_gn(gn_state(grid, node))
        = - r_stateChange_gn(grid, node) // decrease in state results to decrease in value
          * r_balance_marginalValue_gnAverage(grid, node)
          / 1e6;

    // sum over nodes
    r_stateChangeValue
        = sum(gn_state, r_stateChangeValue_gn(gn_state));

   // Transfer marginal value (Me) calculated from r_transfer * balanceMarginal * transferLosses
   r_transferValue_gnnft(gn2n_directional(grid, node_, node), ft_realizedNoReset(f, t_startp(t)))
        = p_stepLengthNoReset(t)
            * [ r_transferRightward_gnnft(grid, node_, node, f, t)
                * r_balance_marginalValue_gnft(grid, node, f, t)
                - r_transferLeftward_gnnft(grid, node_, node, f, t)
                * r_balance_marginalValue_gnft(grid, node_, f, t)
              ]
            * [ 1 - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                  - ts_gnn(grid, node_, node, 'transferLoss', f, t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
              ]
    ;

    // Total transfer marginal value over the simulation
    r_transferValue_gnn(gn2n_directional(grid, node_, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_transferValue_gnnft(grid, node_, node, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
                * p_s_discountFactor(s)
            ) // END sum(sft_realizedNoReset)
    ;

    // Annual sum of unit specific costs and balance prices of inputs and outpus.
    // The sum approximates the unit profits, but currently excludes reserves.
    r_unit_profit_u(unit)
    = // negative sign as these are costs
      - sum(gnu(grid, node, unit),
            + r_cost_unitVOMCost_gnu(gnu)
            + r_cost_unitFuelEmissionCost_u(gnu)
            + r_cost_unitFOMCost_gnu(gnu)
            + r_cost_unitInvestmentCost_gnu(gnu)
            + r_cost_unitCapacityEmissionCost_nu(node, unit)
      ) // END sum(gnu)

      // negative sign as these are costs
      - r_cost_unitStartupCost_u(unit)
      - r_cost_unitShutdownCost_u(unit)

      // negative sign as balance marginal value needs to be reversed
      - sum(gnu(grid, node, unit)${gn_balance(grid, node)},
            sum(ft_realizedNoReset(f, t_startp(t)),
                + r_gen_gnuft(gnu, f, t)
                  * r_balance_marginalValue_gnft(grid, node, f, t)
            ) // END sum(ft_realizedNoReset)
      ) // END sum(gnu)
      / 1e6  // converting to MEUR
    ;

    // rounding to 10 decimals
    r_unit_profit_u(unit) = round(r_unit_profit_u(unit), 10);

* --- info Results ------------------------------------------------------------

    // copying model settings
    r_info_mSettings(mSetting) = mSettings(m, mSetting);

    // copying realized t
    r_info_t_realized(t_startp(t))${ sum(sf, sft_realizedNoReset(sf, t)) } = yes;

); // END loop(m)


* =============================================================================
* --- Checks if realized dummies --------------------------------------------
* =============================================================================

// warning if qGen with default penalty value or constant custom values higher than default penalty
if(%warnings%=1
    and sum((inc_dec, gn(grid, node))${ not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')
                                        and PENALTY_BALANCE(grid, node)>=PENALTY
                                        },
             r_qGen_gn(inc_dec, grid, node))> 0 //END sum(inc_dec, gn)
    ,
    put log '!!! Warning: Completed model run has dummies in the r_qGen, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider running the model with --diag=yes and checking d_qGen diagnostic table for dummies in forecast branches.' /;
    ); // END card
    put log ' ' /;
);

// Notifying if qGen with custom penalty values lower than default of timeseries penalty value
if(%warnings%=1
    and sum((inc_dec, gn(grid, node))${ p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useTimeSeries')
                                        or PENALTY_BALANCE(grid, node)<PENALTY
                                        },
             r_qGen_gn(inc_dec, grid, node))> 0 //END sum(inc_dec, gn)
    ,
    put log 'Note: Completed model run has dummies in the r_qGen for the nodes with custom penalty values lower than the default penalty value.' /;
    put log ' ' /;
);

// warning if qReserveDemand
if(%warnings%=1 and card(r_qGenRamp_gnu)> 0,
    put log '!!! Warning: Completed model run has dummies in the r_qGenRamp, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider running the model with --diag=yes and checking d_qGenRamp diagnostic table for dummies in forecast branches.' /;
    ); // END card
);

// warning if qReserveDemand
if(%warnings%=1 and card(r_qReserveDemand)> 0,
    put log '!!! Warning: Completed model run has dummies in the r_qReserveDemand, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider running the model with --diag=yes and checking d_qResDemand diagnostic table for dummies in forecast branches.' /;
    ); // END card
);

// warning if qReserveMissing
if(%warnings%=1 and card(r_qReserveMissing)> 0,
    put log '!!! Warning: Completed model run has dummies in the r_qReserveMissing, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider running the model with --diag=yes and checking d_qReserveMissing diagnostic table for dummies in forecast branches.' /;
    ); // END card
);

// warning if qCapacity
if(%warnings%=1 and card(r_qCapacity_ft)> 0,
    put log '!!! Warning: Complered model run has dummies in the r_qCapacity, check the results file' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider running the model with --diag=yes and checking d_qCapacity diagnostic table for dummies in forecast branches.' /;
    ); // END card
    put log ' ' /;
);

// warning if qUnitConstraint
if(%warnings%=1 and card(r_qUnitConstraint_u)> 0,
    put log '!!! Warning: Completed model run has dummies in the r_qUnitConstraint, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider also running the model with --diag=yes and checking d_qUnitConstraint diagnostic table for dummies in forecast branches.' /;
    ); // END card
);

// warning if qUserconstraint with default penalty value
if(%warnings%=1
    and sum((inc_dec, group_uc) ${PENALTY_UC(group_uc)>=PENALTY}, r_qUserconstraint(inc_dec, group_uc))> 0
    ,
    put log '!!! Warning: Completed model run has dummies in the r_qUserconstraint, check the results file.' /;
    if(card(f_active)>2,
        put log 'There is more than one active forecast. Consider also running the model with --diag=yes and checking d_qUserconstraint diagnostic table for dummies in forecast branches.' /;
    ); // END card
);

// Notify if qUserconstraint with custom penalty values smaller than default penalty
if(%warnings%=1
    and sum((inc_dec, group_uc) ${PENALTY_UC(group_uc)<PENALTY}, r_qUserconstraint(inc_dec, group_uc))> 0
    ,
    put log 'Note: Completed model run has dummies in the r_qUSerconstraint for the nodes with custom penalty values lower than the default penalty value.' /;
);


* =============================================================================
* --- Diagnostic Results ------------------------------------------------------
* =============================================================================

// Only include these if '--diag=yes' given as a command line argument
$iftheni.diag '%diag%' == yes

// Estimated efficiency
d_eff(unit(unit), ft_realizedNoReset(f, t_startp(t)))
    ${not unit_flow(unit)}
    = sum(gnu_output(grid, node, unit),
        + r_gen_gnuft(grid, node, unit, f, t)
        ) // END sum(gnu_output)
        / [ sum(gnu_input(grid, node, unit),
                + abs(r_gen_gnuft(grid, node, unit, f, t))
                ) // END sum(gnu_input)
            + 1${not sum(gnu_input(grid, node, unit), abs(r_gen_gnuft(grid, node, unit, f, t)))}
            ]
        + Eps; // Eps to correct GAMS plotting (zeroes are not skipped)
$endif.diag


* =============================================================================
* --- Reducing the File Size if Using Small Results ---------------------------
* =============================================================================

// Only include these if '--small_results_file=yes' given as a command line argument
// clears time series result tables significantly reducing the resutls.gdx size
$iftheni.small_results_file '%small_results_file%' == yes

option clear = r_balance_MarginalValue_gnft;

option clear = r_cost_linkVOMCost_gnnft;
option clear = r_cost_realizedOperatingCost_gnft;
option clear = r_cost_unitFuelEmissionCost_gnuft;
option clear = r_cost_unitstartupCost_uft;
option clear = r_cost_unitShutdownCost_uft;
option clear = r_cost_unitVOMCost_gnuft;

option clear = r_diffusion_gnnft;

option clear = r_emission_operationEmissions_gnuft;
option clear = r_emission_startupEmissions_nuft;

option clear = r_gen_gnuft;
option clear = r_gen_gnft;
option clear = r_genByUnittype_gnft;
option clear = r_genByFuel_gnft;

option clear = r_online_uft;
option clear = r_startup_uft;
option clear = r_shutdown_uft;

option clear = r_reserve_gnuft;
option clear = r_reserve_marginalValue_ft;
option clear = r_reserveByGroup_ft;
option clear = r_reserveTransferLeftward_gnnft;
option clear = r_reserveTransferRightward_gnnft;
option clear = r_reserve2Reserve_gnuft;
option clear = r_reserveDemand_largestInfeedUnit_ft;

option clear = r_state_gnft;
option clear = r_spill_gnft;

option clear = r_transfer_gnnft;
option clear = r_transferValue_gnnft;
option clear = r_transferLeftward_gnnft;
option clear = r_transferRightward_gnnft;

$endif.small_results_file

