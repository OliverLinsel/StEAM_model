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
* --- Constraint Equation Definitions -----------------------------------------
* =============================================================================

* --- Energy Balance ----------------------------------------------------------

q_balance(gn_balance(grid, node), sft(s, f, t)) // Energy/power balance dynamics solved using implicit Euler discretization
    ..

    // The left side of the equation is the change in the state (will be zero if the node doesn't have a state)
    // Unit conversion between v_state of a particular node and energy variables
    // note: defaults to 1, but can have node based values if e.g. v_state is in Kelvins and each node has a different heat storage capacity
    + p_gn(grid, node, 'energyStoredPerUnitOfState')$gn_state(grid, node)
        * [
            + v_state(grid, node, s, f+df_central_t(f, t), t)                   // The difference between current
            - v_state(grid, node, s, f+df(f, t+dt(t)), t+dt(t))               // ... and previous state of the node
            ]

    =E=

    // The right side of the equation contains all the changes converted to energy terms
    + p_stepLength(t) // Multiply with the length of the timestep to convert power into energy
        * (
            // Self discharge out of the model boundaries
            - p_gn(grid, node, 'selfDischargeLoss')$gn_state(grid, node)
                * v_state(grid, node, s, f+df_central_t(f, t), t) // The current state of the node

            // Energy diffusion from this node to neighbouring nodes
            - sum(gnn_state(grid, node, to_node),
                + p_gnn(grid, node, to_node, 'diffCoeff')
                    * v_state(grid, node, s, f+df_central_t(f, t), t)
                ) // END sum(to_node)

            // Energy diffusion from neighbouring nodes to this node
            + sum(gnn_state(grid, from_node, node),
                + p_gnn(grid, from_node, node, 'diffCoeff')
                    * v_state(grid, from_node, s, f+df_central_t(f, t), t) // Incoming diffusion based on the state of the neighbouring node
                    * (1 - p_gnn(grid, from_node, node, 'diffLosses'))
                ) // END sum(from_node)

            // Controlled energy transfer, applies when the current node is on the left side of the connection
            - sum(gn2nsft_directional(grid, node, node_, s, f, t),
                + v_transfer(grid, node, node_, s, f, t)
                + [
                    + p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    + ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    ] // Reduce transfer losses if transfer is from another node to this node
                    * v_transferLeftward(grid, node, node_, s, f, t)
                ) // END sum(gn2nsft_directional(node, node_)

            // Controlled energy transfer, applies when the current node is on the right side of the connection
            + sum(gn2nsft_directional(grid, node_, node, s, f, t),
                + v_transfer(grid, node_, node, s, f, t)
                - [
                    + p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    + ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    ] // Reduce transfer losses if transfer is from another node to this node
                    * v_transferRightward(grid, node_, node, s, f, t)
                ) // END sum(gn2nsft_directional(node_, node)

            // Interactions between the node and its units
            + sum(gnusft(grid, node, unit, s, f, t) $ {not gnu_delay(grid, node, unit) },
                + v_gen(grid, node, unit, s, f, t) // Unit energy generation and consumption
                ) // END sum(gnusft)

            // Interactions between the node and its units, for units with delays
            + sum(gnusft(gnu_delay(grid, node, unit), s, f, t),
                + v_gen_delay(grid, node, unit, s, f, t) // Unit energy generation and consumption
                ) // END sum(gnu)

            // Spilling energy out of the endogenous grids in the model
            - v_spill(grid, node, s, f, t)$node_spill(node)

            // Power inflow and outflow time series to/from the node. Incoming (positive) and outgoing (negative)
            // constant (MWh/h)
            + p_gn(grid, node, 'influx')$ {gn_influx(grid, node) and not gn_influxTs(grid, node)}
            // times series (MWh/h)
            + ts_influx_(grid, node, f, t)$gn_influxTs(grid, node)

            // Dummy generation variables, for feasibility purposes
            // Note! When stateSlack is permitted, have to take caution with the penalties so that it will be used first
            + [vq_gen('increase', grid, node, s, f, t)${not dropVqGenInc_gnt(grid, node, t)}
                ]${not dropVqGenInc_gn(grid, node)}
            - [vq_gen('decrease', grid, node, s, f, t)${not dropVqGenDec_gnt(grid, node, t)}
                ]${not dropVqGenDec_gn(grid, node)}
    ) // END * p_stepLength

    // Unit start-up consumption
    - [sum(usft(unit, s, f, t)$nu_startup(node, unit),
        + sum(unitStarttype(unit, starttype),
            + p_unStartup(unit, node, starttype) // MWh/start-up
            * [ // Startup type
                + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                ]
            ) // END sum(unitStarttype)
        ) // END sum(usft)
       ]$node_startupEnergyCost(node)

    // Unit investment energy cost (MWh). Consumes energy from input/output node by invested unitCount * unitSize * invEnergyCost
    - [sum(usft(unit, s, f, t)$ {p_gnu(grid, node, unit, 'invEnergyCost') and utAvailabilityLimits(unit, t, 'becomeAvailable')},
        + p_gnu(grid, node, unit, 'invEnergyCost')     // MWh/MW
            * p_gnu(grid, node, unit, 'unitSize')      // MW/unit
            * [
                + v_invest_LP(unit)${unit_investLP(unit)}    // number of units, LP
                + v_invest_MIP(unit)${unit_investMIP(unit)}  // number of units, MIP
                ]
        ) // END sum(usft)
       ]$node_invEnergyCost(node)
;

* --- Reserve Demand ----------------------------------------------------------
// NOTE! Currently, there are multiple identical instances of the reserve balance equation being generated for each forecast branch even when the reserves are committed and identical between the forecasts.
// NOTE! This could be solved by formulating a new "ft_reserves" set to cover only the relevant forecast-time steps, but it would possibly make the reserves even more confusing.

q_resDemand(restypeDirectionGroup(restype, up_down, group), sft(s, f, t))
    ${  ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
        and not [ restypeReleasedForRealization(restype)
                  and f_realization(f)]
        and not restype_inertia(restype)
        } ..

    // Reserve provision by capable units on this group
    + sum(gnusft(grid, node, unit, s, f, t)${ gnGroup(grid, node, group)
                                          and gnu_resCapable(restype, up_down, grid, node, unit)
                                          },
        + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                ] // END * v_reserve
        ) // END sum(gnusft)

    // Reserve provision from other reserve categories when they can be shared
    + sum((gnusft(grid, node, unit, s, f, t), restype_)${ gnGroup(grid, node, group)
                                                      and p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
                                                      },
        + v_reserve(restype_, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
            * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                    * p_gnuReserves(grid, node, unit, restype_, 'reserveReliability')
                ] // END * v_reserve
        ) // END sum(gnusft)

    // Reserve provision to this group via transfer links
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferRightward(restype, up_down, grid, node_, node, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node
        ) // END sum(gn2n_directional)
     + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferLeftward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node
        ) // END sum(gn2n_directional)


    =G=

    // Demand for reserves
    + ts_reserveDemand_(restype, up_down, group, f, t)${p_groupReserves(group, restype, 'useTimeSeries')}
    + p_groupReserves(group, restype, up_down)${not p_groupReserves(group, restype, 'useTimeSeries')}

    // Reserve provision to reserve markets outside the modelled reserve balance
    + v_resToMarkets(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t) $ p_groupReserves(group, restype, 'usePrice')

    // Reserve demand increase because of units
    + sum(gnusft(grid, node, unit, s, f, t)${ gnGroup(grid, node, group)
                                          and p_gnuReserves(grid, node, unit, restype, 'reserve_increase_ratio') // Could be better to have 'reserve_increase_ratio' separately for up and down directions
                                          },
        + v_gen(grid, node, unit, s, f, t)
            * p_gnuReserves(grid, node, unit, restype, 'reserve_increase_ratio')
        ) // END sum(gnusft)

    // Reserve provisions to other groups via transfer links
    + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node, node_)
                                                },   // If trasferring reserves to another node, increase your own reserves by same amount
        + v_resTransferRightward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node, node_)
                                                },   // If trasferring reserves to another node, increase your own reserves by same amount
        + v_resTransferLeftward(restype, up_down, grid, node_, node, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)

    // Reserve demand feasibility dummy variables
    - vq_resDemand(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${not dropVqResDemand(restype, up_down, group, t)}
    - vq_resMissing(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t)
          and not dropVqResMissing(restype, up_down, group, t)}
;

* --- N-1 Reserve Demand ----------------------------------------------------------
// NOTE! Currently, there are multiple identical instances of the reserve balance equation being generated for each forecast branch even when the reserves are committed and identical between the forecasts.
// NOTE! This could be solved by formulating a new "ft_reserves" set to cover only the relevant forecast-time steps, but it would possibly make the reserves even more confusing.

q_resDemandLargestInfeedUnit(restypeDirectionGroup(restype, 'up', group), usft(unit_fail(unit_), sft(s, f, t)))
    ${  ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
        and not [ restypeReleasedForRealization(restype)
                  and f_realization(f)
                  ]
        and sum(gnGroup(grid, node, group), p_gnuReserves(grid, node, unit_, restype, 'portion_of_infeed_to_reserve'))
        and sum(gnGroup(grid, node, group), gnu_output(grid, node, unit_)) // only units with output capacity 'inside the group'
        } ..

    // Reserve provision by capable units on this group excluding the failing one
    + sum(gnusft(grid, node, unit, s, f, t)${ gnGroup(grid, node, group)
                                              and gnu_resCapable(restype, 'up', grid, node, unit)
                                              and (ord(unit_) ne ord(unit))
                                              },
        + v_reserve(restype, 'up', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                ] // END * v_reserve
        ) // END sum(nuft)

    // Reserve provision from other reserve categories when they can be shared
    + sum((gnusft(grid, node, unit, s, f, t), restype_)${ gnGroup(grid, node, group)
                                                          and p_gnuRes2Res(grid, node, unit, restype_, 'up', restype)
                                                          and (ord(unit_) ne ord(unit))
                                                          },
        + v_reserve(restype_, 'up', grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
            * p_gnuRes2Res(grid, node, unit, restype_, 'up', restype)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                    * p_gnuReserves(grid, node, unit, restype_, 'reserveReliability')
                ] // END * v_reserve
        ) // END sum(nuft)

    // Reserve provision to this group via transfer links
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, 'up', grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferRightward(restype, 'up', grid, node_, node, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node

        ) // END sum(gn2n_directional)
    + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, 'up', grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferLeftward(restype, 'up', grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node
        ) // END sum(gn2n_directional)


    =G=

    // Demand for reserves due to a large unit that could fail
    + sum(gnGroup(grid, node, group),
        + v_gen(grid, node, unit_, s, f, t)
            * p_gnuReserves(grid, node, unit_, restype, 'portion_of_infeed_to_reserve')
        ) // END sum(gnGroup)

    // Reserve provisions to other groups via transfer links
    + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, 'up', grid, node, node_)
                                                },   // If trasferring reserves to another node, increase your own reserves by same amount
        + v_resTransferRightward(restype, 'up', grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and restypeDirectionGridNodeNode(restype, 'up', grid, node, node_)
                                                },   // If trasferring reserves to another node, increase your own reserves by same amount
        + v_resTransferLeftward(restype, 'up', grid, node_, node, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)

    // Reserve demand feasibility dummy variables
    - vq_resDemand(restype, 'up', group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${not dropVqResDemand(restype, 'up', group, t)}
    - vq_resMissing(restype, 'up', group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t)
          and not dropVqResMissing(restype, 'up', group, t)}
;

* --- ROCOF Limit -- Units ----------------------------------------------------
// NOTE! Currently, this equation does not work well with clustered unit
// commitment as the demand for rotational energy depends on the total
// generation of the failing unit cluster.

q_rateOfChangeOfFrequencyUnit(group, unit_fail(unit_), sft(s, f, t))
    ${  p_groupPolicy(group, 'defaultFrequency')
        and p_groupPolicy(group, 'ROCOF')
        and p_groupPolicy(group, 'dynamicInertia')
        and usft(unit_, s, f, t) // only active units
        and sum(gnGroup(grid, node, group), gnu_output(grid, node, unit_)) // only units with output capacity 'inside the group'
        } ..

    // Kinetic/rotational energy in the system
    + p_groupPolicy(group, 'ROCOF')*2
        * [
            + sum(gnu_output(grid, node, unit)${   ord(unit) ne ord(unit_)
                                                   and gnGroup(grid, node, group)
                                                   and usft(unit, s, f, t)
                                                   },
                + p_gnu(grid, node, unit, 'inertia')
                    * p_gnu(grid ,node, unit, 'unitSizeMVA')
                    * [
                        + v_online_LP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineLP(unit, s, f, t)}
                        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineMIP(unit, s, f, t)}
                        + v_gen(grid, node, unit, s, f, t)${not usft_online(unit, s, f, t)}
                            / p_gnu(grid, node, unit, 'unitSize')
                        ] // * p_gnu
                ) // END sum(gnu_output)
            ] // END * p_groupPolicy

    =G=

    // Demand for kinetic/rotational energy due to a large unit that could fail
    + p_groupPolicy(group, 'defaultFrequency')
        * sum(gnu_output(grid, node, unit_)${   gnGroup(grid, node, group)
                                                },
            + v_gen(grid, node, unit_ , s, f, t)
            ) // END sum(gnu_output)
;

* --- ROCOF Limit -- Transfer Links -------------------------------------------

q_rateOfChangeOfFrequencyTransfer(group, gn2n(grid, node_, node_fail), sft(s, f, t))
    ${  p_groupPolicy(group, 'defaultFrequency')
        and p_groupPolicy(group, 'ROCOF')
        and p_groupPolicy(group, 'dynamicInertia')
        and gnGroup(grid, node_, group) // only interconnectors where one end is 'inside the group'
        and not gnGroup(grid, node_fail, group) // and the other end is 'outside the group'
        and [ p_gnn(grid, node_, node_fail, 'portion_of_transfer_to_reserve')
              or p_gnn(grid, node_fail, node_, 'portion_of_transfer_to_reserve')
              ]
        } ..

    // Kinetic/rotational energy in the system
    + p_groupPolicy(group, 'ROCOF')*2
        * [
            + sum(gnu_output(grid, node, unit)${   gnGroup(grid, node, group)
                                                   and usft(unit, s, f, t)
                                                   },
                + p_gnu(grid, node, unit, 'inertia')
                    * p_gnu(grid ,node, unit, 'unitSizeMVA')
                    * [
                        + v_online_LP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineLP(unit, s, f, t)}
                        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineMIP(unit, s, f, t)}
                        + v_gen(grid, node, unit, s, f, t)${not usft_online(unit, s, f, t)}
                            / p_gnu(grid, node, unit, 'unitSize')
                        ] // * p_gnu
                ) // END sum(gnu_output)
            ] // END * p_groupPolicy

    =G=

    // Demand for kinetic/rotational energy due to a large interconnector that could fail
    + p_groupPolicy(group, 'defaultFrequency')
        * [
            // Loss of import due to potential interconnector failures
            + p_gnn(grid, node_fail, node_, 'portion_of_transfer_to_reserve')
                * v_transferRightward(grid, node_fail, node_, s, f, t)${gn2n_directional(grid, node_fail, node_)}
                * [1
                    - p_gnn(grid, node_fail, node_, 'transferLoss')${not gn2n_timeseries(grid, node_fail, node_, 'transferLoss')}
                    - ts_gnn_(grid, node_fail, node_, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node_fail, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_fail, node_, 'transferLoss')}
                    ]
            + p_gnn(grid, node_, node_fail, 'portion_of_transfer_to_reserve')
                * v_transferLeftward(grid, node_, node_fail, s, f, t)${gn2n_directional(grid, node_, node_fail)}
                * [1
                    - p_gnn(grid, node_fail, node_, 'transferLoss')${not gn2n_timeseries(grid, node_fail, node_, 'transferLoss')}
                    - ts_gnn_(grid, node_fail, node_, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node_fail, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_fail, node_, 'transferLoss')}
                    ]
            // Loss of export due to potential interconnector failures
            + p_gnn(grid, node_fail, node_, 'portion_of_transfer_to_reserve')
                * v_transferLeftward(grid, node_fail, node_, s, f, t)${gn2n_directional(grid, node_fail, node_)}
            + p_gnn(grid, node_, node_fail, 'portion_of_transfer_to_reserve')
                * v_transferRightward(grid, node_, node_fail, s, f, t)${gn2n_directional(grid, node_, node_fail)}
            ] // END * p_groupPolicy
;

* --- N-1 reserve demand due to a possibility that an interconnector that is transferring power to/from the node group fails -------------------------------------------------
// NOTE! Currently, there are multiple identical instances of the reserve balance equation being generated for each forecast branch even when the reserves are committed and identical between the forecasts.
// NOTE! This could be solved by formulating a new "ft_reserves" set to cover only the relevant forecast-time steps, but it would possibly make the reserves even more confusing.

q_resDemandLargestInfeedTransfer(restypeDirectionGroup(restype, up_down, group), gn2n(grid, node_left, node_right), sft(s, f, t))
    ${  ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
        and not [ restypeReleasedForRealization(restype)
                  and f_realization(f)]
        and gn2n_directional(grid, node_left, node_right)
        and [ (gnGroup(grid, node_left, group) and not gnGroup(grid, node_right, group)) // only interconnectors where one end is 'inside the group'
              or (gnGroup(grid, node_right, group) and not gnGroup(grid, node_left, group)) // and the other end is 'outside the group'
              ]
        and [ p_gnn(grid, node_left, node_right, 'portion_of_transfer_to_reserve')
              or p_gnn(grid, node_right, node_left, 'portion_of_transfer_to_reserve')
              ]
        and p_groupReserves3D(group, restype, up_down, 'LossOfTrans')
        } ..

    // Reserve provision by capable units on this group
    + sum(gnusft(grid, node, unit, s, f, t)${ gnGroup(grid, node, group)
                                          and gnu_resCapable(restype, up_down, grid, node, unit)
                                          },
        + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                ] // END * v_reserve
        ) // END sum(gnusft)

    // Reserve provision from other reserve categories when they can be shared
    + sum((gnusft(grid, node, unit, s, f, t), restype_)${ gnGroup(grid, node, group)
                                                      and p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
                                                      },
        + v_reserve(restype_, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
            * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                    * p_gnuReserves(grid, node, unit, restype_, 'reserveReliability')
                ] // END * v_reserve
        ) // END sum(gnusft)

    // Reserve provision to this group via transfer links
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and not (sameas(node_, node_left) and sameas(node, node_right)) // excluding the failing link
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferRightward(restype, up_down, grid, node_, node, s, f+df_reserves(grid, node_, restype, f, t), t)
        ) // END sum(gn2n_directional)
    + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and not (sameas(node, node_left) and sameas(node_, node_right)) // excluding the failing link
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                },
        + [1
            - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
            - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
            ]
            * v_resTransferLeftward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t)
        ) // END sum(gn2n_directional)

    =G=

    // Demand for upward reserve due to potential interconnector failures (sudden loss of import)
    + [
        + p_gnn(grid, node_left, node_right, 'portion_of_transfer_to_reserve')${gnGroup(grid, node_right, group)}
            * v_transferRightward(grid, node_left, node_right, s, f, t) // multiply with efficiency?
        + p_gnn(grid, node_right, node_left, 'portion_of_transfer_to_reserve')${gnGroup(grid, node_left, group)}
            * v_transferLeftward(grid, node_left, node_right, s, f, t) // multiply with efficiency?
        ]${sameas(up_down, 'up')}

    // Demand for downward reserve due to potential interconnector failures (sudden loss of export)
    + [
        + p_gnn(grid, node_left, node_right, 'portion_of_transfer_to_reserve')${gnGroup(grid, node_left, group)}
            * v_transferRightward(grid, node_left, node_right, s, f, t)
        + p_gnn(grid, node_right, node_left, 'portion_of_transfer_to_reserve')${gnGroup(grid, node_right, group)}
            * v_transferLeftward(grid, node_left, node_right, s, f, t)
        ]${sameas(up_down, 'down')}

    // Reserve provisions to other groups via transfer links
    + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and not (sameas(node, node_left) and sameas(node_, node_right)) // excluding the failing link
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node, node_)
                                                },
          // Reserve transfers to other nodes increase the reserve need of the present node
        + v_resTransferRightward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)
    + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group)
                                                and not gnGroup(grid, node_, group)
                                                and not (sameas(node_, node_left) and sameas(node, node_right)) // excluding the failing link
                                                and restypeDirectionGridNodeNode(restype, up_down, grid, node, node_)
                                                },
          // Reserve transfers to other nodes increase the reserve need of the present node
        + v_resTransferLeftward(restype, up_down, grid, node_, node, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gn2n_directional)

    // Reserve demand feasibility dummy variables
    - vq_resDemand(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${not dropVqResDemand(restype, up_down, group, t)}
    - vq_resMissing(restype, up_down, group, s, f+df_reservesGroup(group, restype, f, t), t)
        ${ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t)
          and not dropVqResMissing(restype, up_down, group, t)}
;

* --- Maximum Downward Capacity -----------------------------------------------

q_maxDownward(gnusft(grid, node, unit, s, f, t))
    ${ [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
       and { // Unit is either
             sum(restype, gnusft_resCapable(restype, 'down', grid, node, unit, s, f, t)) // capable to provide downward reserves,
             or [ // the unit has an online variable
                  usft_online(unit, s, f, t)
                  and [
                       (unit_minLoad(unit) and gnu_output(grid, node, unit)) // generating units with a min. load,
                       or gnu_input(grid, node, unit)                        // is a consuming unit with an online variable, or
                       ]
                  ] // END or
              or [
                  gnu_input(grid, node, unit) // is a consuming unit with investment possibility
                  and [unit_investLP(unit) or unit_investMIP(unit)]
                  ]
              }
       } ..

    // Energy generation/consumption
    + v_gen(grid, node, unit, s, f, t)

    // Downward reserve participation
    - [sum(gnusft_resCapable(restype, 'down', grid, node, unit, s, f, t)
        ${ not gnu_offlineResCapable(restype, grid, node, unit)},
        + v_reserve(restype, 'down', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t) // (v_reserve can be used only if the unit is capable of providing a particular reserve)
        ) // END sum(gnusft_resCapable)
      ]$unit_resCapable(unit)

    =G= // Must be greater than minimum load or maximum consumption  (units with min-load and both generation and consumption are not allowed)

    // Generation units, greater than minLoad
    + [p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
        * sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
            + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
            + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
            ) // END sum(effGroup)
        * [ // Online variables should only be generated for units with restrictions
            + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f+df_central_t(f, t), t)} // LP online variant
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f+df_central_t(f, t), t)} // MIP online variant
            ] // END v_online
        ]$unit_minLoad(unit)

    // Consuming units, greater than maxCons
    // Available capacity restrictions
    - [[
        + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
        + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
        ]
        * [
            // Capacity factors for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // END * unit availability
        * [
            // Online capacity restriction
            + p_gnu(grid, node, unit, 'capacity')${not usft_online(unit, s, f, t)} // Use initial maximum if no online variables
            // !!! TEMPORARY SOLUTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            + [
                + p_gnu(grid, node, unit, 'unitSize')
                + p_gnu(grid, node, unit, 'capacity')${not p_gnu(grid, node, unit, 'unitSize') > 0}
                    / ( p_unit(unit, 'unitCount') + 1${not p_unit(unit, 'unitCount') > 0} )
                ]
            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                * [
                    // Capacity online
                    + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
                    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

                    // Investments to additional non-online capacity
                    + v_invest_LP(unit)${unit_investLP(unit) and not usft_online(unit, s, f, t)} // NOTE! v_invest_LP also for consuming units is positive
                    + v_invest_MIP(unit)${unit_investMIP(unit) and not usft_online(unit, s, f, t)} // NOTE! v_invest_MIP also for consuming units is positive
                    ] // END * p_gnu(unitSize)
            ] // END * unit availability
      ]$gnu_input(grid, node, unit)

    // Units in run-up phase neet to keep up with the run-up rate
    + [p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(unitStarttype(unit, starttype),
              sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                  + [
                      + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                          ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                          ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      ]
                      * p_uCounter_runUpMin(unit, counter)
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
      ]$usft_startupTrajectory(unit, s, f, t)

    // Units in shutdown phase need to keep up with the shutdown rate
    + [p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(shutdownCounter(unit, counter)${t_active(t+dt_trajectory(counter)) }, // Sum over the shutdown intervals
              + [
                  + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                      ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                      ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  ]
                  * p_uCounter_shutdownMin(unit, counter)
              ) // END sum(shutdownCounter)
      ]$usft_shutdownTrajectory(unit, s, f, t)

;

* --- Maximum Downward Capacity for Production/Consumption, Online Reserves and Offline Reserves ---

q_maxDownwardOfflineReserve(gnusft(grid, node, unit_offlineRes(unit), s, f, t))
    ${ [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
       and {sum(restype, gnusft_resCapable(restype, 'down', grid, node, unit, s, f, t))} // capable to provide downward reserves,
       and {sum(restype, gnu_offlineResCapable(restype, grid, node, unit))}  // and it can provide some reserve products although being offline
       }..

    // Energy generation/consumption
    + v_gen(grid, node, unit, s, f, t)

    // Downward reserve participation
    - sum(gnusft_resCapable(restype, 'down', grid, node, unit, s, f, t),
        + v_reserve(restype, 'down', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(nuRescapable)

    =G= // Must be greater than maximum consumption

    // Consuming units
    // Available capacity restrictions
    // Consumption units are also restricted by their (available) capacity
    - [
        + p_unit(unit, 'availability')${gnu_input(grid, node, unit) and not p_unit(unit, 'useTimeseriesAvailability')}
        + ts_unit_(unit, 'availability', f, t)${gnu_input(grid, node, unit) and p_unit(unit, 'useTimeseriesAvailability')}
        ]
        * [
            // Capacity factors for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // END * unit availability
        * [
            // Existing capacity
            + p_gnu(grid, node, unit, 'capacity')
            // Investments to new capacity
            + [
                + p_gnu(grid, node, unit, 'unitSize')
                ]
                * [
                    + v_invest_LP(unit)${unit_investLP(unit)}
                    + v_invest_MIP(unit)${unit_investMIP(unit)}
                    ] // END * p_gnu(unitSize)
            ] // END * unit availability
;

* --- Maximum Upwards Capacity for Production/Consumption and Online Reserves ---

q_maxUpward(gnusft(grid, node, unit, s, f, t))
    ${ [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
       and { // Unit is either
             sum(restype, gnusft_resCapable(restype, 'up', grid, node, unit, s, f, t)) // capable to provide upward reserves,
             or [
                 usft_online(unit, s, f, t) // or the unit has an online variable
                 and [
                     [unit_minLoad(unit) and gnu_input(grid, node, unit)] // consuming units with min_load,
                     or gnu_output(grid, node, unit)                      // is a generator with an online variable, or
                     ]
                 ]
             or [
                 gnu_output(grid, node, unit) // is a generator with investment possibility
                 and (unit_investLP(unit) or unit_investMIP(unit))
                 ]
              }
       }..

    // Energy generation/consumption
    + v_gen(grid, node, unit, s, f, t)

    // Upwards reserve participation
    + [sum(gnusft_resCapable(restype, 'up', grid, node, unit, s, f, t)
        ${not gnu_offlineResCapable(restype, grid, node, unit)},
        + v_reserve(restype, 'up', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(gnusft_resCapable)
      ]$unit_resCapable(unit)

    =L= // must be less than available/online capacity

    // Consuming units, greater than minLoad
    - [p_gnu(grid, node, unit, 'unitSize')$gnu_input(grid, node, unit)
        * sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
            + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
            + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
            ) // END sum(effGroup)
        * [
            + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)} // Consuming units are restricted by their min. load (consuming is negative)
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)} // Consuming units are restricted by their min. load (consuming is negative)
            ] // END * p_gnu(unitSize)
        ]$unit_minLoad(unit)

    // Generation units
    // Available capacity restrictions
    // Generation units are restricted by their (available) capacity
    + [[
        + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
        + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
        ]
        * [
            // Capacity factor for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // END * unit availability
        * [
            // Online capacity restriction
            + p_gnu(grid, node, unit, 'capacity')${not usft_online(unit, s, f, t)} // Use initial capacity if no online variables
            + p_gnu(grid, node, unit, 'unitSize')
                * [
                    // Capacity online
                    + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
                    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

                    // Investments to non-online capacity
                    + v_invest_LP(unit)${unit_investLP(unit) and not usft_online(unit, s, f, t)}
                    + v_invest_MIP(unit)${unit_investMIP(unit) and not usft_online(unit, s, f, t)}
                    ] // END * p_gnu(unitSize)
            ] // END * unit availability
      ]$gnu_output(grid, node, unit)

    // Units in run-up phase neet to keep up with the run-up rate
    + [
      + p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(unitStarttype(unit, starttype),
              sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                  + [
                      + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                          ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                          ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      ]
                      * p_uCounter_runUpMax(unit, counter)
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
      ]$usft_startupTrajectory(unit, s, f, t)

    // Units in shutdown phase need to keep up with the shutdown rate
    + [
      + p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(shutdownCounter(unit, counter)${t_active(t+dt_trajectory(counter)) }, // Sum over the shutdown intervals
              + [
                  + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                      ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                      ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  ]
                  * p_uCounter_shutdownMax(unit, counter)
              ) // END sum(shutdownCounter)
      ]$usft_shutdownTrajectory(unit, s, f, t)
;

* --- Maximum Upwards Capacity for Production/Consumption, Online Reserves and Offline Reserves ---

q_maxUpwardOfflineReserve(gnusft(grid, node, unit_offlineRes(unit), s, f, t))
    ${ [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
       and {sum(restype, gnusft_resCapable(restype, 'up', grid, node, unit, s, f, t))} // capable to provide upward reserves,
       and {sum(restype, gnu_offlineResCapable(restype, grid, node, unit))}  // and it can provide some reserve products although being offline
       }..

    // Energy generation/consumption
    + v_gen(grid, node, unit, s, f, t)

    // Upwards reserve participation
    + sum(gnusft_resCapable(restype, 'up', grid, node, unit, s, f, t),
        + v_reserve(restype, 'up', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(nuRescapable)

    =L= // must be less than available capacity

    // Generation units
    // Available capacity restrictions

    // Generation units are restricted by their (available) capacity
    + [
        + p_unit(unit, 'availability')${gnu_output(grid, node, unit) and not p_unit(unit, 'useTimeseriesAvailability')}
        + ts_unit_(unit, 'availability', f, t)${gnu_output(grid, node, unit) and p_unit(unit, 'useTimeseriesAvailability')}
        ]
        * [
            // Capacity factor for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // END * unit availability
        * [
            // Capacity restriction
            + p_gnu(grid, node, unit, 'unitSize')
                * [
                    // Existing capacity
                    + p_unit(unit, 'unitCount')

                    // Investments to new capacity
                    + v_invest_LP(unit)${unit_investLP(unit)}
                    + v_invest_MIP(unit)${unit_investMIP(unit)}
                    ] // END * p_gnu(unitSize)
            ] // END * unit availability
;

* --- Fixed Flow Production/Consumption ---------------------------------------

q_fixedFlow(gnusft(grid, node, unit_flow(unit), s, f, t))
    ${  (p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize'))
        and p_unit(unit, 'fixedFlow')
}..

    // Energy generation/consumption
    + v_gen(grid, node, unit, s, f, t)

    =E= // must be equal to available capacity

    + [
        // Available capacity restrictions
        + p_unit(unit, 'availability')${gnu_output(grid, node, unit) and not p_unit(unit, 'useTimeseriesAvailability')}
        + ts_unit_(unit, 'availability', f, t)${gnu_output(grid, node, unit) and p_unit(unit, 'useTimeseriesAvailability')}
        - p_unit(unit, 'availability')${gnu_input(grid, node, unit) and not p_unit(unit, 'useTimeseriesAvailability')}
        - ts_unit_(unit, 'availability', f, t)${gnu_input(grid, node, unit) and p_unit(unit, 'useTimeseriesAvailability')}
        ]
        * sum(flowUnit(flow, unit), // Capacity factor for flow units
            + ts_cf_(flow, node, f, t)
            ) // END sum(flow)
        * [
            // Capacity restriction
            + p_gnu(grid, node, unit, 'unitSize')
                * [
                    // Existing capacity
                    + p_unit(unit, 'unitCount')

                    // Investments to new capacity
                    + v_invest_LP(unit)${unit_investLP(unit)}
                    + v_invest_MIP(unit)${unit_investMIP(unit)}
                    ] // END * p_gnu(unitSize)
            ] // END * unit availability
;

* --- Reserve Provision of Units with Investments -----------------------------

q_reserveProvision(gnusft_resCapable(restypeDirectionGridNode(restype, up_down, grid, node), unit_invest(unit), s, f, t))
    ${ not sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
               ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
       } ..

    + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)

    =L=

    + p_gnuReserves(grid, node, unit, restype, up_down)
        * [
            + p_gnu(grid, node, unit, 'capacity')
            + v_invest_LP(unit)${unit_investLP(unit)}
                * p_gnu(grid, node, unit, 'unitSize')
            + v_invest_MIP(unit)${unit_investMIP(unit)}
                * p_gnu(grid, node, unit, 'unitSize')
            ]
        // Taking into account availability...
        * [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
        * [
            // ... and capacity factor for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // How to consider reserveReliability in the case of investments when we typically only have "realized" time steps?
;

* --- Online Reserve Provision of Units with Online Variables -----------------

q_reserveProvisionOnline(gnusft_resCapable(restypeDirectionGridNode(restype, up_down, grid, node), unit, s, f, t))
    ${  not sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                    ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
        and usft_online(unit, s, f, t)
        and not gnu_offlineResCapable(restype, grid, node, unit)
        }..

    + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)

    =L=

    + p_gnuReserves(grid, node, unit, restype, up_down)
        * p_gnu(grid, node, unit, 'unitSize')
        * [
            + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}
            ]
        // Taking into account availability...
        * [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
        * [
            // ... and capacity factor for flow units
            + sum(flowUnit(flow, unit),
                + ts_cf_(flow, node, f, t)
                ) // END sum(flow)
            + 1${not unit_flow(unit)}
            ] // How to consider reserveReliability in the case of investments when we typically only have "realized" time steps?

;


* --- Unit Startup and Shutdown -----------------------------------------------

q_startshut(usft_online(unit, s, f, t))
    ..

    // Units currently online
    + v_online_LP (unit, s, f+df_central_t(f, t), t)${usft_onlineLP (unit, s, f, t)}
    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    // Units previously online
    // The same units
    - v_online_LP (unit, s, f+df(f, t+dt(t)), t+dt(t))${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt(t)), t+dt(t))
                                                             and not usft_aggregator_first(unit, s, f, t) } // This reaches to tFirstSolve when dt = -1   // t_solveFirst?
    - v_online_MIP(unit, s, f+df(f, t+dt(t)), t+dt(t))${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt(t)), t+dt(t))
                                                             and not usft_aggregator_first(unit, s, f, t) }

    // Aggregated units just before they are turned into aggregator units
    - sum(unit_${unitAggregator_unit(unit, unit_)},
        + v_online_LP (unit_, s, f+df(f, t+dt(t)), t+dt(t))${usft_onlineLP_withPrevious(unit_, s, f+df(f, t+dt(t)), t+dt(t))}
        + v_online_MIP(unit_, s, f+df(f, t+dt(t)), t+dt(t))${usft_onlineMIP_withPrevious(unit_, s, f+df(f, t+dt(t)), t+dt(t))}
        )${usft_aggregator_first(unit, s, f, t)} // END sum(unit_)

    =E=

    // Unit startup and shutdown

    // Add startup of units dt_toStartup before the current t (no start-ups for aggregator units before they become active)
    + sum(unitStarttype(unit, starttype),
        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t))
            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) }
        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t))
            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) }
        )${not [unit_aggregator(unit) and ord(t) + dt_toStartup(unit, t) <= t_solveFirst + p_unit(unit, 'lastStepNotAggregated')]} // END sum(starttype)

    // NOTE! According to 3d_setVariableLimits,
    // cannot start a unit if the time when the unit would become online is outside
    // the horizon when the unit has an online variable
    // --> no need to add start-ups of aggregated units to aggregator units

    // Shutdown of units at time t
    - v_shutdown_LP(unit, s, f, t)
        ${ usft_onlineLP(unit, s, f, t) }
    - v_shutdown_MIP(unit, s, f, t)
        ${ usft_onlineMIP(unit, s, f, t) }
;

*--- Startup Type -------------------------------------------------------------
// !!! NOTE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// This formulation doesn't work as intended when unitCount > 1, as one recent
// shutdown allows for multiple hot/warm startups on subsequent time steps.
// Pending changes.

q_startuptype(starttypeConstrained(starttype), usft_online(unit, s, f, t))
    ${  unitStarttype(unit, starttype)  // Matching units and starttypes.
        and [dt_starttypeUnit(starttype, unit) > -dt(t)] // If (starttype, unit) takes longer than the length of previous timestep
        } ..

    // Startup type
    + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
    + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }

    =L=

    // Subunit shutdowns within special startup timeframe
    + sum(unitCounter(unit, counter)${  dt_starttypeUnitCounter(starttype, unit, counter)
                                        and t_active(t+(dt_starttypeUnitCounter(starttype, unit, counter)+1))
                                        },
        + v_shutdown_LP(unit, s, f+df(f, t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)), t+(dt_starttypeUnitCounter(starttype, unit, counter)+1))
            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)), t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)) }
        + v_shutdown_MIP(unit, s, f+df(f, t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)), t+(dt_starttypeUnitCounter(starttype, unit, counter)+1))
            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)), t+(dt_starttypeUnitCounter(starttype, unit, counter)+1)) }
        ) // END sum(counter)

    // NOTE: for aggregator units, shutdowns for aggregated units are not considered
;


*--- Online Limits with Startup Type Constraints and Investments --------------

q_onlineLimit(usft_online(unit, s, f, t))
    ${  [p_unit(unit, 'minShutdownHours') and (p_unit(unit, 'minShutdownHours') > p_stepLength(t))]
        or p_u_runUpTimeIntervals(unit)
        or unit_invest(unit)
      } ..

    // Online variables
    + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    =L=

    // Number of existing units
    + p_unit(unit, 'unitCount')

    // Number of units unable to become online due to restrictions
    - sum(unitCounter(unit, counter)${  dt_downtimeUnitCounter(unit, counter)
                                        and t_active(t+(dt_downtimeUnitCounter(unit, counter) + 1))
                                        },
        + v_shutdown_LP(unit, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1))
            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1)) }
        + v_shutdown_MIP(unit, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1))
            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1)) }
        ) // END sum(counter)

    // Number of units unable to become online due to restrictions (aggregated units in the past horizon or if they have an online variable)
    - sum(unitAggregator_unit(unit, unit_),
        + sum(unitCounter(unit, counter)${  dt_downtimeUnitCounter(unit, counter)
                                            and t_active(t+(dt_downtimeUnitCounter(unit, counter) + 1))
                                            },
            + v_shutdown_LP(unit_, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1))
                ${ usft_onlineLP_withPrevious(unit_, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1)) }
            + v_shutdown_MIP(unit_, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1))
                ${ usft_onlineMIP_withPrevious(unit_, s, f+df(f, t+(dt_downtimeUnitCounter(unit, counter) + 1)), t+(dt_downtimeUnitCounter(unit, counter) + 1)) }
            ) // END sum(counter)
        )${unit_aggregator(unit)} // END sum(unit_)

    // Investments into units
    + v_invest_LP(unit)${unit_investLP(unit)}
    + v_invest_MIP(unit)${unit_investMIP(unit)}
;

*--- Both q_offlineAfterShutdown and q_onlineOnStartup work when there is only one unit.
*    These equations prohibit single units turning on and off at the same time step.
*    Unfortunately there seems to be no way to prohibit this when unit count is > 1.
*    (it shouldn't be worthwhile anyway if there is a startup cost, but it can fall within the solution gap).
q_onlineOnStartUp(usft_online(unit, s, f, t))
    ${  sum(starttype, unitStarttype(unit, starttype))
        }..

    // Units currently online
    + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    =G=

    + sum(unitStarttype(unit, starttype),
        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) //dt_toStartup displaces the time step to the one where the unit would be started up in order to reach online at t
            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) }
        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) //dt_toStartup displaces the time step to the one where the unit would be started up in order to reach online at t
            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_toStartup(unit, t)), t+dt_toStartup(unit, t)) }
      ) // END sum(starttype)
;

q_offlineAfterShutdown(usft_online(unit, s, f, t))
    ${  sum(starttype, unitStarttype(unit, starttype))
        }..

    // Number of existing units
    + p_unit(unit, 'unitCount')

    // Investments into units
    + v_invest_LP(unit)${unit_investLP(unit)}
    + v_invest_MIP(unit)${unit_investMIP(unit)}

    // Units currently online
    - v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
    - v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    =G=

    + v_shutdown_LP(unit, s, f, t)
        ${ usft_onlineLP(unit, s, f, t) }
    + v_shutdown_MIP(unit, s, f, t)
        ${ usft_onlineMIP(unit, s, f, t) }
;

*--- Minimum Unit Uptime ------------------------------------------------------

q_onlineMinUptime(usft_online(unit, s, f, t))
    ${ p_unit(unit, 'minOperationHours') > p_stepLength(t)
       } ..

    // Units currently online
    + v_online_LP(unit, s, f+df_central_t(f, t), t)${usft_onlineLP(unit, s, f, t)}
    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    =G=

    // Units that have minimum operation time requirements active
    + sum(unitCounter(unit, counter)${  dt_uptimeUnitCounter(unit, counter)
                                        and t_active(t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) // Don't sum over counters that don't point to an active time step
                                        },
        + sum(unitStarttype(unit, starttype),
            + v_startup_LP(starttype, unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1))
                ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) }
            + v_startup_MIP(starttype, unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1))
                ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) }
            ) // END sum(starttype)
        ) // END sum(counter)

    // Units that have minimum operation time requirements active (aggregated units in the past horizon or if they have an online variable)
    + sum(unitAggregator_unit(unit, unit_),
        + sum(unitCounter(unit, counter)${  dt_uptimeUnitCounter(unit, counter)
                                            and t_active(t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) // Don't sum over counters that don't point to an active time step
                                            },
            + sum(unitStarttype(unit, starttype),
                + v_startup_LP(starttype, unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1))
                    ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) }
                + v_startup_MIP(starttype, unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1))
                    ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)), t+(dt_uptimeUnitCounter(unit, counter)+dt_toStartup(unit, t) + 1)) }
                ) // END sum(starttype)
            ) // END sum(counter)
        )${unit_aggregator(unit)} // END sum(unit_)
;

* --- Cyclic Boundary Conditions for Online State -----------------------------

q_onlineCyclic(uss_bound(unit, s_, s))
    ${  s_active(s_)
        and s_active(s)
        }..

    // Initial value of the state of the unit at the start of the sample
    + sum(sft(s, f, t)$st_start(s, t),
           + v_online_LP(unit, s, f+df_noReset(f, t+dt(t)), t+dt(t))
               ${usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt(t)), t+dt(t))}
           + v_online_MIP(unit, s, f+df_noReset(f, t+dt(t)), t+dt(t))
               ${usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt(t)), t+dt(t))}
           ) // END sum(sft)

    =E=

    // State of the unit at the end of the sample
    + sum(sft(s_, f_, t_)$st_end(s_, t_),
           + v_online_LP(unit, s_, f_, t_)${usft_onlineLP(unit, s, f_, t_)}
           + v_online_MIP(unit, s_, f_, t_)${usft_onlineMIP(unit, s, f_, t_)}
           ) // END sum(sft)

;

* --- Ramp Constraints --------------------------------------------------------

q_genRampUp(gnusft_ramp(gnu_rampUp(grid, node, unit), s, f, t))
    ..

    // ramp rate (MW/h)
    + v_genRampUp(grid, node, unit, s, f, t) $ gnu_rampUp(grid, node, unit)
    // multiplying ramp rate by step length to convert to single hour values
        * p_stepLength(t)

    =G=

    // Change in generation over the interval: v_gen(t) - v_gen(t-1)
    // Unit generation at t
    + v_gen(grid, node, unit, s, f, t)

    // Unit generation at t-1 (except aggregator units right before the aggregation threshold, see next term)
    - v_gen(grid, node, unit, s, f+df(f, t+dt(t)), t+dt(t))${not usft_aggregator_first(unit, s, f, t)}
    // Unit generation at t-1, aggregator units right before the aggregation threshold
    + sum(unit_${unitAggregator_unit(unit, unit_)},
        - v_gen(grid, node, unit_, s, f+df(f, t+dt(t)), t+dt(t))
      )${usft_aggregator_first(unit, s, f, t)}
;

q_genRampDown(gnusft_ramp(gnu_rampDown(grid, node, unit), s, f, t))
    ..

    // ramp rate (MW/h)
    - v_genRampDown(grid, node, unit, s, f, t) $ gnu_rampDown(grid, node, unit)
    // multiplying ramp rate by step length to convert to single hour values
        * p_stepLength(t)

    =L=

    // Change in generation over the interval: v_gen(t) - v_gen(t-1)
    // Unit generation at t
    + v_gen(grid, node, unit, s, f, t)

    // Unit generation at t-1 (except aggregator units right before the aggregation threshold, see next term)
    - v_gen(grid, node, unit, s, f+df(f, t+dt(t)), t+dt(t))${not usft_aggregator_first(unit, s, f, t)}
    // Unit generation at t-1, aggregator units right before the aggregation threshold
    + sum(unit_${unitAggregator_unit(unit, unit_)},
        - v_gen(grid, node, unit_, s, f+df(f, t+dt(t)), t+dt(t))
      )${usft_aggregator_first(unit, s, f, t)}
;

* --- Ramp Up Limits ----------------------------------------------------------

q_rampUpLimit(gnusft_ramp(gnu_rampUp(grid, node, unit), s, f, t))
    ${ sum(restype, gnu_resCapable(restype, 'up', grid, node, unit))
       or usft_online(unit, s, f, t)
       or unit_invest(unit)
       } ..

    // upward ramp rate (MW/h)
    + v_genRampUp(grid, node, unit, s, f, t) $ gnu_rampUp(grid, node, unit)

    + sum(gnusft_resCapable(restype, 'up', grid, node, unit, s, f, t)
        ${ not gnu_offlineResCapable(restype, grid, node, unit)},
        + v_reserve(restype, 'up', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t) // (v_reserve can be used only if the unit is capable of providing a particular reserve)
        ) // END sum(nuRescapable)
        / p_stepLength(t)

    =L=

    // Ramping capability of units without an online variable
    + (
        + p_gnu(grid, node, unit, 'capacity')
        + v_invest_LP(unit)${unit_investLP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
        + v_invest_MIP(unit)${unit_investMIP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
      )${not usft_online(unit, s, f, t)}
        * p_gnu(grid, node, unit, 'maxRampUp')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Ramping capability of units with an online variable
    + (
        + v_online_LP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineLP(unit, s, f, t)}
        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineMIP(unit, s, f, t)}
      )
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'maxRampUp')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Generation units not be able to ramp from zero to min. load within one time interval according to their maxRampUp
    + sum(unitStarttype(unit, starttype)${   usft_online(unit, s, f, t)
                                             and gnu_output(grid, node, unit)
                                             and not usft_startupTrajectory(unit, s, f, t)
                                             and ( + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                                                       + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                                                       + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                                                     ) // END sum(effGroup)
                                                       / p_stepLength(t)
                                                   - p_gnu(grid, node, unit, 'maxRampUp')
                                                       * 60 > 0
                                                   )
                                             },
        + v_startup_LP(starttype, unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_startup_MIP(starttype, unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
      ) // END sum(starttype)
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
              ) // END sum(effGroup)
                / p_stepLength(t)
            - p_gnu(grid, node, unit, 'maxRampUp')
                * 60   // Unit conversion from [p.u./min] to [p.u./h]
          ) // END * v_startup

    // Units in the run-up phase need to keep up with the run-up rate
    + [
      + p_gnu(grid, node, unit, 'unitSize')
          * sum(unitStarttype(unit, starttype),
              sum(runUpCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large))}, // Sum over the run-up intervals
                  + [
                      + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                      + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                      ]
                      * [
                          + p_unit(unit, 'rampSpeedToMinLoad')
                          + ( p_gnu(grid, node, unit, 'maxRampUp') - p_unit(unit, 'rampSpeedToMinLoad') )${ not runUpCounter(unit, counter_large+1) } // Ramp speed adjusted for the last run-up interval
                              * ( p_u_runUpTimeIntervalsCeil(unit) - p_u_runUpTimeIntervals(unit) )
                          ]
                      * 60 // Unit conversion from [p.u./min] into [p.u./h]
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
      ]${usft_startupTrajectory(unit, s, f, t)}

    // Shutdown of consumption units according to maxRampUp
    + [
        + v_shutdown_LP(unit, s, f, t)
            ${usft_onlineLP(unit, s, f, t) and gnu_input(grid, node, unit)}
        + v_shutdown_MIP(unit, s, f, t)
            ${usft_onlineMIP(unit, s, f, t) and gnu_input(grid, node, unit)}
        ]
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'maxRampUp')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]
    // Consumption units not be able to ramp from min. load to zero within one time interval according to their maxRampUp
    + [
        + v_shutdown_LP(unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_shutdown_MIP(unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
        ]
        ${  gnu_input(grid, node, unit)
            and ( + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                      + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                      + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                      ) // END sum(effGroup)
                      / p_stepLength(t)
                  - p_gnu(grid, node, unit, 'maxRampUp')
                      * 60 > 0
                  )
            }
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                ) // END sum(effGroup)
                / p_stepLength(t)
            - p_gnu(grid, node, unit, 'maxRampUp')
                * 60   // Unit conversion from [p.u./min] to [p.u./h]
          ) // END * v_shutdown


    + vq_genRampUp(grid, node, unit, s, f, t)${not dropVqGenRamp_gnut(grid, node, unit, t)}
;


* --- Ramp Down Limits --------------------------------------------------------

q_rampDownLimit(gnusft_ramp(grid, node, unit, s, f, t))
    ${  gnu_rampDown(grid, node, unit)
        and [ sum(restype, gnu_resCapable(restype, 'down', grid, node, unit))
              or usft_online(unit, s, f, t)
              or unit_invest(unit)
              ]
        } ..

    // downward ramp rate (MW/h)
    - v_genRampDown(grid, node, unit, s, f, t) $ gnu_rampDown(grid, node, unit)

    - sum(gnusft_resCapable(restype, 'down', grid, node, unit, s, f, t)
        ${not gnu_offlineResCapable(restype, grid, node, unit)},
        + v_reserve(restype, 'down', grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t) // (v_reserve can be used only if the unit is capable of providing a particular reserve)
        ) // END sum(nuRescapable)
        / p_stepLength(t)

    =G=

    // Ramping capability of units without online variable
    - (
        + p_gnu(grid, node, unit, 'capacity')
        + v_invest_LP(unit)${unit_investLP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
        + v_invest_MIP(unit)${unit_investMIP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
      )${not usft_online(unit, s, f, t)}
        * p_gnu(grid, node, unit, 'maxRampDown')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Ramping capability of units that are online
    - (
        + v_online_LP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineLP(unit, s, f, t)}
        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineMIP(unit, s, f, t)}
      )
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'maxRampDown')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Shutdown of generation units according to maxRampDown
    - [
        + v_shutdown_LP(unit, s, f, t)
            ${  usft_onlineLP(unit, s, f, t) }
        + v_shutdown_MIP(unit, s, f, t)
            ${  usft_onlineMIP(unit, s, f, t) }
        ]
        ${  gnu_output(grid, node, unit)
            and not usft_shutdownTrajectory(unit, s, f, t)
            }
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'maxRampDown')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]
    // Generation units not be able to ramp from min. load to zero within one time interval according to their maxRampDown
    - [
        + v_shutdown_LP(unit, s, f, t)
            ${  usft_onlineLP(unit, s, f, t) }
        + v_shutdown_MIP(unit, s, f, t)
            ${  usft_onlineMIP(unit, s, f, t) }
        ]
        ${  gnu_output(grid, node, unit)
            and not usft_shutdownTrajectory(unit, s, f, t)
            and ( + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                      + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                      + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                    ) // END sum(effGroup)
                    / p_stepLength(t)
                  - p_gnu(grid, node, unit, 'maxRampDown')
                      * 60 > 0
                )
        }
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                ) // END sum(effGroup)
                / p_stepLength(t)
            - p_gnu(grid, node, unit, 'maxRampDown')
                * 60   // Unit conversion from [p.u./min] to [p.u./h]
          ) // END * v_shutdown

    // Units in shutdown phase need to keep up with the shutdown ramp rate
    - p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
        * [
            + sum(shutdownCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large)) and usft_shutdownTrajectory(unit, s, f, t)}, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                    ]
                    * [
                        + p_gnu(grid, node, unit, 'maxRampDown')${ not shutdownCounter(unit, counter_large-1) } // Normal maxRampDown limit applies to the time interval when v_shutdown happens, i.e. over the change from online to offline (symmetrical to v_startup)
                        + p_unit(unit, 'rampSpeedFromMinLoad')${ shutdownCounter(unit, counter_large-1) } // Normal trajectory ramping
                        + ( p_gnu(grid, node, unit, 'maxRampDown') - p_unit(unit, 'rampSpeedFromMinLoad') )${ shutdownCounter(unit, counter_large-1) and not shutdownCounter(unit, counter_large-2) } // Ramp speed adjusted for the first shutdown interval
                            * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) )
                        ]
                ) // END sum(shutdownCounter)
            // Units need to be able to shut down after shut down trajectory
            + [
                + v_shutdown_LP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t)) }
                + v_shutdown_MIP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t)) }
                ]${usft_shutdownTrajectory(unit, s, f, t)}
                * [
                    + p_unit(unit, 'rampSpeedFromMinload')
                    + ( p_gnu(grid, node, unit, 'maxRampDown') - p_unit(unit, 'rampSpeedFromMinLoad') )${ sum(shutdownCounter(unit, counter_large), 1) = 1 } // Ramp speed adjusted if the unit has only one shutdown interval
                        * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) )
                    ]
            ] // END sum(gnu)
        * 60 // Unit conversion from [p.u./min] to [p.u./h]

    // Consumption units not be able to ramp from zero to min. load within one time interval according to their maxRampDown
    - sum(unitStarttype(unit, starttype)${   usft_online(unit, s, f, t)
                                             and gnu_input(grid, node, unit)
                                             and ( + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                                                       + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                                                       + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                                                     ) // END sum(effGroup)
                                                       / p_stepLength(t)
                                                   - p_gnu(grid, node, unit, 'maxRampDown')
                                                       * 60 > 0
                                                   )
                                             },
        + v_startup_LP(starttype, unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_startup_MIP(starttype, unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
      ) // END sum(starttype)
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
              ) // END sum(effGroup)
                / p_stepLength(t)
            - p_gnu(grid, node, unit, 'maxRampDown')
                * 60   // Unit conversion from [p.u./min] to [p.u./h]
          ) // END * v_startup


    - vq_genRampDown(grid, node, unit, s, f, t)${not dropVqGenRamp_gnut(grid, node, unit, t)}


;

* --- Ramps separated into piecewise upward and downward ramps ----------------

q_rampUpDownPiecewise(gnusft_ramp(grid, node, unit, s, f, t))
    $ {sum(upwardSlack(slack), p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'))
       or sum(downwardSlack(slack), p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost'))
       }
    ..

    // ramp rate (MW/h)
    + v_genRampUp(grid, node, unit, s, f, t) $ gnu_rampUp(grid, node, unit)
    - v_genRampDown(grid, node, unit, s, f, t) $ gnu_rampDown(grid, node, unit)

    =E=

    // Upward and downward ramp categories
    + sum(upwardSlack(slack)${ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')} ,
        + v_genRampUpDown(slack, grid, node, unit, s, f, t)      // MW/h
      ) // END sum(upwardSlack)
    - sum(downwardSlack(slack)${ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')} ,
        + v_genRampUpDown(slack, grid, node, unit, s, f, t)    // MW/h
      ) // END sum(downwardSlack)


    // Start-up of generation units to min. load (not counted in the ramping costs)
    + sum(unitStarttype(unit, starttype)${   usft_online(unit, s, f, t)
                                             and gnu_output(grid, node, unit)
                                             and not usft_startupTrajectory(unit, s, f, t)
                                             },
        + v_startup_LP(starttype, unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_startup_MIP(starttype, unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
      ) // END sum(starttype)
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
              ) // END sum(effGroup)
                / p_stepLength(t)
          ) // END * v_startup

    // Generation units in the run-up phase need to keep up with the run-up rate (not counted in the ramping costs)
    + [
      + p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(unitStarttype(unit, starttype),
              sum(runUpCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large))}, // Sum over the run-up intervals
                  + [
                      + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))}
                      + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))}
                      ]
                      * [
                          + p_uCounter_runUpMin(unit, counter_large)${ not runUpCounter(unit, counter_large-1) } // Ramp speed adjusted for the first run-up interval
                              / p_stepLength(t) // Ramp is the change of v_gen divided by interval length
                          + p_unit(unit, 'rampSpeedToMinLoad')${ runUpCounter(unit, counter_large-1) and runUpCounter(unit, counter_large+1) } // Normal trajectory ramping in the middle of the trajectory
                              * 60 // Unit conversion from [p.u./min] into [p.u./h]
                          + p_u_minRampSpeedInLastRunUpInterval(unit)${ runUpCounter(unit, counter_large-1) and not runUpCounter(unit, counter_large+1) } // Ramp speed adjusted for the last run-up interval
                              * 60 // Unit conversion from [p.u./min] into [p.u./h]
                          ]
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
      ]${usft_startupTrajectory(unit, s, f, t)}

    // Shutdown of consumption units from min. load (not counted in the ramping costs)
    + [
        + v_shutdown_LP(unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) and gnu_input(grid, node, unit)}
        + v_shutdown_MIP(unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) and gnu_input(grid, node, unit)}
        ]
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                ) // END sum(effGroup)
                / p_stepLength(t)
          ) // END * v_shutdown

    // Shutdown of generation units from min. load (not counted in the ramping costs)
    - [
        + v_shutdown_LP(unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) and gnu_output(grid, node, unit) and not usft_shutdownTrajectory(unit, s, f, t)}
        + v_shutdown_MIP(unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) and gnu_output(grid, node, unit) and not usft_shutdownTrajectory(unit, s, f, t)}
        ]
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
                ) // END sum(effGroup)
                / p_stepLength(t)
          ) // END * v_shutdown

    // Generation units in shutdown phase need to keep up with the shutdown ramp rate (not counted in the ramping costs)
    - p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
        * [
            + sum(shutdownCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large)) and usft_shutdownTrajectory(unit, s, f, t)}, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))}
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))}
                    ]
                    * [
                        // Note that ramping happening during shutdown trajectory when ord(counter) = 1 is considered 'normal ramping' and causes ramping costs
                        + p_u_minRampSpeedInFirstShutdownInterval(unit)${ not shutdownCounter(unit, counter_large-2) and shutdownCounter(unit, counter_large-1) } // Ramp speed adjusted for the first shutdown interval
                            * 60 // Unit conversion from [p.u./min] into [p.u./h]
                        + p_unit(unit, 'rampSpeedFromMinLoad')${ shutdownCounter(unit, counter_large-2) } // Normal trajectory ramping in the middle of the trajectory
                            * 60 // Unit conversion from [p.u./min] into [p.u./h]
                        ]
                ) // END sum(shutdownCounter)
            // Units need to be able to shut down after shut down trajectory
            + [
                + v_shutdown_LP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))}
                + v_shutdown_MIP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))}
                ]
                * sum(shutdownCounter(unit, counter_large)${not shutdownCounter(unit, counter_large+1)}, p_uCounter_shutdownMin(unit, counter_large)) // Minimum generation level at the last shutdown interval
                / p_stepLength(t) // Ramp is the change of v_gen divided by interval length
            ]

    // Start-up of consumption units to min. load (not counted in the ramping costs)
    - sum(unitStarttype(unit, starttype)${   usft_online(unit, s, f, t)
                                             and gnu_input(grid, node, unit)
                                             },
        + v_startup_LP(starttype, unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_startup_MIP(starttype, unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
      ) // END sum(starttype)
        * p_gnu(grid, node, unit, 'unitSize')
        * (
            + sum(eff_usft(effGroup, unit, s, f, t), // Uses the minimum 'lb' for the current efficiency approximation
                + p_effGroupUnit(effGroup, unit, 'lb')${not ts_effGroupUnit_(effGroup, unit, 'lb', f, t)}
                + ts_effGroupUnit_(effGroup, unit, 'lb', f, t)
              ) // END sum(effGroup)
                / p_stepLength(t)
          ) // END * v_startup
;

* --- Upward and downward ramps constrained by slack boundaries ---------------

q_rampSlack(slack, gnusft_ramp(grid, node, unit, s, f, t))
    ${ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')}
    ..

    // Directional ramp speed of the unit
    + v_genRampUpDown(slack, grid, node, unit, s, f, t)       // MW/h

    =L=

    // Ramping capability of units without an online variable
    + (
        + p_gnu(grid, node, unit, 'capacity')
        + v_invest_LP(unit)${unit_investLP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
        + v_invest_MIP(unit)${unit_investMIP(unit)}
            * p_gnu(grid, node, unit, 'unitSize')
      )${not usft_online(unit, s, f, t)}
        * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Ramping capability of units with an online variable
    + (
        + v_online_LP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineLP(unit, s, f, t)}
        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
            ${usft_onlineMIP(unit, s, f, t)}
      )
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Shutdown of units from above min. load and ramping happening during the first interval of the shutdown trajectory (commented out in the other v_shutdown term below)
    + [
        + v_shutdown_LP(unit, s, f, t)
            ${ usft_onlineLP(unit, s, f, t) }
        + v_shutdown_MIP(unit, s, f, t)
            ${ usft_onlineMIP(unit, s, f, t) }
      ]
        * p_gnu(grid, node, unit, 'unitSize')
        * p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')
        * 60   // Unit conversion from [p.u./min] to [p.u./h]

    // Generation units in the last step of their run-up phase
    + [
      + p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
          * sum(unitStarttype(unit, starttype),
              sum(runUpCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large))}, // Sum over the run-up intervals
                  + [
                      + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                      + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                          ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                      ]
                      * [
                          + p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')${ not runUpCounter(unit, counter_large+1) } // Ramp speed adjusted for the last run-up interval
                              * ( p_u_runUpTimeIntervalsCeil(unit) - p_u_runUpTimeIntervals(unit) )
                          ]
                      * 60 // Unit conversion from [p.u./min] into [p.u./h]
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
      ]${usft_startupTrajectory(unit, s, f, t)}

    // Generation units in the first step of their shutdown phase and ramping from online to offline state
    + p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
        * [
            + sum(shutdownCounter(unit, counter(counter_large))${t_active(t+dt_trajectory(counter_large)) and usft_shutdownTrajectory(unit, s, f, t)}, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large))
                        ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter_large)), t+dt_trajectory(counter_large)) }
                    ]
                    * [
                        //+ p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')${ not shutdownCounter(unit, counter_large-1) } // Note that ramping happening during shutdown trajectory when ord(counter) = 1 is considered 'normal ramping' and causes ramping costs (calculated above in the other v_shutdown term)
                        + p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')${ shutdownCounter(unit, counter_large-1) and not shutdownCounter(unit, counter_large-2) } // Ramp speed adjusted for the first shutdown interval
                            * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) )
                        ]
                ) // END sum(shutdownCounter)
            // First step can also be the last step
            + [
                + v_shutdown_LP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))}
                + v_shutdown_MIP(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))
                    ${usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_toShutdown(unit, t)), t+dt_toShutdown(unit, t))}
                ]
                + p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')${ sum(shutdownCounter(unit, counter), 1) = 1 } // Ramp speed adjusted if the unit has only one shutdown interval
                    * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) )
            ]
        * 60 // Unit conversion from [p.u./min] to [p.u./h]
;

* --- Unit generation delays --------------------------------------------------

q_genDelay(gnu_delay(grid, node, unit), sft(s, f, t_))
    $ { sum(t_full(t), map_delay_gnutt(grid, node, unit, t, t_)) }
    ..

    // v_gen_delay in the timestep t_ where generation is delayed to
    v_gen_delay(grid, node, unit, s, f, t_)
    * p_stepLength(t_)

    =E=

    // Sum of the v_gen in timesteps t where the delay is from.
    // Divided by stepLength of t_, to scale the energy to the stepength of t_.
    // This works because the sum over each t is stepLength(t) in map_delay_gnutt.
    // The sum of multipliers for v_gen(t) for each t_ in this equation should be 1.
    sum(map_delay_gnutt(grid, node, unit, t, t_),
        v_gen(grid, node, unit, s, f +[df_realization(f)${t_realizedNoReset(t)}], t)
        * p_delay_gnutt(grid, node, unit, t, t_)
        ) // END sum(map_delay_gnutt)

;

* --- Direct Input-Output Conversion ------------------------------------------

q_conversionDirectInputOutput(eff_usft(effDirect(effGroup), unit, s, f, t))
    $ {not unit_sink(unit)
       and not unit_source(unit)
       }
    ..

    // Sum over endogenous energy inputs
    - sum(gnu_input(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + v_gen(grid, node, unit, s, f, t)
          * p_gnu(grid, node, unit, 'conversionCoeff')
        ) // END sum(gnu_input)

    =E=

    // Sum over energy outputs
    + sum(gnu_output(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + v_gen(grid, node, unit, s, f, t)
            * p_gnu(grid, node, unit, 'conversionCoeff')
            * [ // efficiency rate
                + p_effUnit(effGroup, unit, effGroup, 'slope')${ not ts_effUnit_(effGroup, unit, effGroup, 'slope', f, t) }
                + ts_effUnit_(effGroup, unit, effGroup, 'slope', f, t)
                ] // END * v_gen
        ) // END sum(gnu_output)

    // Consumption of keeping units online (no-load fuel use)
    +[ sum(gnu_output(grid, node, unit),
           + p_gnu(grid, node, unit, 'unitSize')
           ) // END sum(gnu_output)
        * [ // Unit online state
            + v_online_LP(unit, s, f+df_central_t(f, t), t)
                ${usft_onlineLP(unit, s, f, t)}
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)
                ${usft_onlineMIP(unit, s, f, t)}

            // Run-up and shutdown phase efficiency correction
            // Run-up 'online state'
            + sum(unitStarttype(unit, starttype)${usft_startupTrajectory(unit, s, f, t)},
                + sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                    + [
                        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      ]
                        * p_uCounter_runUpMin(unit, counter)
                        / p_unit(unit, 'op00') // Scaling the p_uCounter_runUp using minLoad
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
            // Shutdown 'online state'
            + sum(shutdownCounter(unit, counter)${t_active(t+dt_trajectory(counter))
                                                  and usft_shutdownTrajectory(unit, s, f, t)
                                                  }, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  ]
                    * p_uCounter_shutdownMin(unit, counter)
                        / p_unit(unit, 'op00') // Scaling the p_uCounter_shutdown using minLoad
              ) // END sum(shutdownCounter)
          ] // END * sum(gnu_output)
        * [
            + p_effGroupUnit(effGroup, unit, 'section')${not ts_effUnit_(effGroup, unit, effDirect, 'section', f, t)}
            + ts_effUnit_(effGroup, unit, effGroup, 'section', f, t)
          ] // END * sum(gnu_output)
        ]${unit_section(unit) }
;
* --- Incremental Heat Rate Conversion ------------------------------------------

q_conversionIncHR(eff_usft(effIncHR(effGroup), unit, s, f, t))
    $ {not unit_sink(unit)
       and not unit_source(unit)
       }
    ..

    // Sum over endogenous energy inputs
    - sum(gnu_input(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + v_gen(grid, node, unit, s, f, t) * p_gnu(grid, node, unit, 'conversionCoeff')
      ) // END sum(gnu_input)

    =E=

    // Sum over energy outputs
    + sum(gnu_output(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + sum(hr,
            + v_gen_inc(grid, node, unit, hr, s, f, t) // output of each heat rate segment
                * p_gnu(grid, node, unit, 'conversionCoeff')
                * [
                    + p_unit(unit, hr) // heat rate
                    / 3.6 // unit conversion from [GJ/MWh] into [MWh/MWh]
                  ] // END * v_gen_inc
          ) // END sum(hr)
      ) // END sum(gnu_output)

    // Consumption of keeping units online (no-load fuel use)
    +[ sum(gnu_output(grid, node, unit),
        + p_gnu(grid, node, unit, 'unitSize')
      ) // END sum(gnu_output)
        * [ // Unit online state
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

            // Run-up and shutdown phase efficiency correction
            // Run-up 'online state'
            + sum(unitStarttype(unit, starttype)${usft_startupTrajectory(unit, s, f, t)},
                + sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                    + [
                        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                      ]
                        * p_uCounter_runUpMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_runUp using minLoad
                  ) // END sum(runUpCounter)
              ) // END sum(unitStarttype)
            // Shutdown 'online state'
            + sum(shutdownCounter(unit, counter)${  t_active(t+dt_trajectory(counter))
                                                    and usft_shutdownTrajectory(unit, s, f, t)
                                                 }, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                  ]
                    * p_uCounter_shutdownMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_shutdown using minLoad
              ) // END sum(shutdownCounter)
          ] // END * sum(gnu_output)
        * [
            + p_effUnit(effGroup, unit, effGroup, 'section')${not ts_effUnit_(effGroup, unit, effIncHR, 'section', f, t)}
            + ts_effUnit_(effGroup, unit, effGroup, 'section', f, t)
          ] // END * sum(gnu_output)
        ]${unit_section(unit) }
;

* --- Incremental Heat Rate Conversion ------------------------------------------

q_conversionIncHRMaxOutput(gn(grid, node), eff_usft(effIncHR(effGroup), unit, s, f, t))
    ${  gnu_output(grid, node, unit)
        and not unit_sink(unit)
        and not unit_source(unit)
        } ..

    + v_gen(grid, node, unit, s, f, t)

    =E=

    // Sum over heat rate segments
    + sum(hr$(p_unit(unit, hr)),
        + v_gen_inc(grid, node, unit, hr, s, f, t)
        )// END sum (hr)
;

* --- Incremental Heat Rate Conversion ------------------------------------------

q_conversionIncHRBounds(gn(grid, node), hr, eff_usft(effIncHR(effGroup), unit, s, f, t))
    ${  gnu_output(grid, node, unit)
        and p_unit(unit, hr)
        and not unit_sink(unit)
        and not unit_source(unit)
        } ..

    + v_gen_inc(grid, node, unit, hr, s, f, t)

    =L=

    + (
        + sum(hrop${ord(hrop) = ord(hr)}, p_unit(unit, hrop))
        - sum(hrop${ord(hrop) = ord(hr) - 1}, p_unit(unit, hrop))
        )
        * p_gnu(grid, node, unit, 'unitSize')
        * [ // Unit online state
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

            // Run-up and shutdown phase efficiency correction
            // Run-up 'online state'
            + sum(unitStarttype(unit, starttype)${usft_startupTrajectory(unit, s, f, t)},
                + sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                    + [
                        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        ]
                        * p_uCounter_runUpMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_runUp using minLoad
                    ) // END sum(runUpCounter)
                ) // END sum(unitStarttype)
            // Shutdown 'online state'
            + sum(shutdownCounter(unit, counter)${  t_active(t+dt_trajectory(counter))
                                                    and usft_shutdownTrajectory(unit, s, f, t)
                                                    }, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    ]
                    * p_uCounter_shutdownMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_shutdown using minLoad
                ) // END sum(shutdownCounter)
            ] // END * p_gnu('unitSize')
;

* --- Incremental Heat Rate Conversion (First Segments First) -----------------

q_conversionIncHR_help1(gn(grid, node), hr, eff_usft(effIncHR(effGroup), unit_incHRAdditionalConstraints(unit), s, f, t))
    ${  gnu_output(grid, node, unit)
        and p_unit(unit, hr)
        and p_unit(unit, hr+1)
        and not unit_sink(unit)
        and not unit_source(unit)
        } ..

    + v_gen_inc(grid, node, unit, hr, s, f, t)
    - (
        + sum(hrop${ord(hrop) = ord(hr)}, p_unit(unit, hrop))
        - sum(hrop${ord(hrop) = ord(hr) - 1}, p_unit(unit, hrop))
        )
        * p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit)
        * [ // Unit online state
            + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

            // Run-up and shutdown phase efficiency correction
            // Run-up 'online state'
            + sum(unitStarttype(unit, starttype)${usft_startupTrajectory(unit, s, f, t)},
                + sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
                    + [
                        + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                            ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                        ]
                        * p_uCounter_runUpMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_runUp using minLoad
                    ) // END sum(runUpCounter)
                ) // END sum(unitStarttype)
            // Shutdown 'online state'
            + sum(shutdownCounter(unit, counter)${  t_active(t+dt_trajectory(counter))
                                                    and usft_shutdownTrajectory(unit, s, f, t)
                                                    }, // Sum over the shutdown intervals
                + [
                    + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                        ${  usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                    ]
                    * p_uCounter_shutdownMin(unit, counter)
                        / p_unit(unit, 'hrop00') // Scaling the p_uCounter_shutdown using minLoad
                ) // END sum(shutdownCounter)
            ] // END * p_gnu('unitSize')

    =G=

    - BIG_M
        * (1 - v_help_inc(grid, node, unit, hr, s, f, t))
;

q_conversionIncHR_help2(gn(grid, node), hr, eff_usft(effIncHR(effGroup), unit_incHRAdditionalConstraints(unit), s, f, t))
    ${  gnu_output(grid, node, unit)
        and p_unit(unit, hr)
        and p_unit(unit, hr-1)
        and not unit_sink(unit)
        and not unit_source(unit)
        } ..

    + v_gen_inc(grid, node, unit, hr, s, f, t)

    =L=

    + BIG_M
        * v_help_inc(grid, node, unit, hr-1, s, f, t)
;

* --- SOS2 Efficiency Approximation -------------------------------------------

q_conversionSOS2InputIntermediate(eff_usft(effLambda(effGroup), unit, s, f, t))
    $ {not unit_sink(unit)
       and not unit_source(unit)
       }
    ..

    // Sum over energy inputs
    - sum(gnu_input(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + v_gen(grid, node, unit, s, f, t) * p_gnu(grid, node, unit, 'conversionCoeff')
        ) // END sum(gnu_input)

    =E=

    // Sum over sos variables of the unit multiplied by unit size
    + sum(gnu_output(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + p_gnu(grid, node, unit, 'unitSize')
          * p_gnu(grid, node, unit, 'conversionCoeff')
      )
      * [
          // Unit p.u. output multiplied by heat rate
          + sum(effGroupSelectorUnit(effGroup, unit, effSelector),
              + v_sos2(unit, s, f, t, effSelector)
                  * [ // Operation points convert the v_sos2 variables into share of capacity used for generation
                      + p_effUnit(effGroup, unit, effSelector, 'op')${not ts_effUnit_(effGroup, unit, effSelector, 'op', f, t)}
                      + ts_effUnit_(effGroup, unit, effSelector, 'op', f, t)
                      ] // END * v_sos2
                  * [ // Heat rate
                      + p_effUnit(effGroup, unit, effSelector, 'slope')${not ts_effUnit_(effGroup, unit, effSelector, 'slope', f, t)}
                      + ts_effUnit_(effGroup, unit, effSelector, 'slope', f, t)
                      ] // END * v_sos2
              ) // END sum(effSelector)
         ]
;

* --- SOS 2 Efficiency Approximation Online Variables -------------------------

q_conversionSOS2Constraint(eff_usft(effLambda(effGroup), unit, s, f, t))
    $ {not unit_sink(unit)
       and not unit_source(unit)
       }
    ..

    // Total value of the v_sos2 equals the number of online units
    + sum(effGroupSelectorUnit(effGroup, unit, effSelector),
        + v_sos2(unit, s, f, t, effSelector)
        ) // END sum(effSelector)

    =E=

    // Number of units online
    + v_online_MIP(unit, s, f+df_central_t(f, t), t)${usft_onlineMIP(unit, s, f, t)}

    // Run-up and shutdown phase efficiency approximation
    // Run-up 'online state'
    + sum(unitStarttype(unit, starttype)${usft_startupTrajectory(unit, s, f, t)},
        + sum(runUpCounter(unit, counter)${t_active(t+dt_trajectory(counter))}, // Sum over the run-up intervals
            + [
                + v_startup_LP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                    ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                + v_startup_MIP(starttype, unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                    ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
                ]
                * p_uCounter_runUpMin(unit, counter)
                / p_unit(unit, 'op00') // Scaling the p_uCounter_runUp using minLoad
            ) // END sum(runUpCounter)
        ) // END sum(unitStarttype)
    // Shutdown 'online state'
    + sum(shutdownCounter(unit, counter)${t_active(t+dt_trajectory(counter)) and usft_shutdownTrajectory(unit, s, f, t)}, // Sum over the shutdown intervals
        + [
            + v_shutdown_LP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                ${ usft_onlineLP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
            + v_shutdown_MIP(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter))
                ${ usft_onlineMIP_withPrevious(unit, s, f+df(f, t+dt_trajectory(counter)), t+dt_trajectory(counter)) }
            ]
            * p_uCounter_shutdownMin(unit, counter)
            / p_unit(unit, 'op00') // Scaling the p_uCounter_shutdown using minLoad
        ) // END sum(shutdownCounter)
;

* --- SOS 2 Efficiency Approximation Output Generation ------------------------

q_conversionSOS2IntermediateOutput(eff_usft(effLambda(effGroup), unit, s, f, t))
    $ {not unit_sink(unit)
       and not unit_source(unit)
       }
    ..

    // Energy outputs as sos variables
    + sum(gnu_output(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + p_gnu(grid, node, unit, 'unitSize')
          * p_gnu(grid, node, unit, 'conversionCoeff')
      ) // END sum(gnu_output)
      * sum(effGroupSelectorUnit(effGroup, unit, effSelector),
          + v_sos2(unit, s, f, t, effSelector)
            * [ // Operation points convert v_sos2 into share of capacity used for generation
                + p_effUnit(effGroup, unit, effSelector, 'op')${not ts_effUnit_(effGroup, unit, effSelector, 'op', f, t)}
                + ts_effUnit_(effGroup, unit, effSelector, 'op', f, t)
              ] // END * v_sos2
        ) // END sum(effSelector)

    =E=

    // Energy outputs into v_gen
    + sum(gnu_output(grid, node, unit)$p_gnu(grid, node, unit, 'conversionCoeff'),
        + v_gen(grid, node, unit, s, f, t) * p_gnu(grid, node, unit, 'conversionCoeff')
      ) // END sum(gnu_output)
;

* --- Fixed ratio of inputs or outputs ----------------------------------------

q_unitEqualityConstraint(eq_constraint, usft(unit, s, f, t))
    $ unitConstraint(unit, eq_constraint) ..

    // Inputs and/or outputs multiplied by their coefficient
    + sum(gnu(grid, node, unit)${p_unitConstraintNode(unit, eq_constraint, node)
                                 and gnu_eqConstrained(eq_constraint, grid, node, unit)},
        + v_gen(grid, node, unit, s, f, t)
        * [p_unitConstraintNode(unit, eq_constraint, node)${not ts_unitConstraintNode_(unit, eq_constraint, node, f, t)}
           +ts_unitConstraintNode_(unit, eq_constraint, node, f+df_central_t(f, t), t) ]
        )

    =E=

    + [
      // Constant multiplied by the number of online sub-units
      + [ p_unitConstraintNew(unit, eq_constraint, 'constant') $ {not ts_unitConstraint_(unit, eq_constraint, 'constant', f+df_central_t(f, t), t)}
          + ts_unitConstraint_(unit, eq_constraint, 'constant', f+df_central_t(f, t), t)
          ]
        * [
            + 1 ${not usft_online(unit, s, f, t) or p_unitConstraintNew(unit, eq_constraint, 'onlineMultiplier')=0} // if the unit does not have an online variable in later effLevels
            + [v_online_LP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, eq_constraint, 'onlineMultiplier')
               ]${usft_onlineLP(unit, s, f, t)}
            + [v_online_MIP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, eq_constraint, 'onlineMultiplier')
               ]${usft_onlineMIP(unit, s, f, t)}
            ]
       + vq_unitConstraint('increase', eq_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, eq_constraint, t)}
       - vq_unitConstraint('decrease', eq_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, eq_constraint, t)}
      ]$ { p_unitConstraintNew(unit, eq_constraint, 'constant')<>0 or ts_unitConstraint_(unit, eq_constraint, 'constant', f+df_central_t(f, t), t) }
;

* --- Constrained ratio of inputs and/or outputs ------------------------------

q_unitGreaterThanConstraint(gt_constraint, usft(unit, s, f, t))
    $ unitConstraint(unit, gt_constraint) ..

    // Inputs and/or outputs multiplied by their coefficient
    + sum(gnu(grid, node, unit)${gnu_gtConstrained(gt_constraint, grid, node, unit)},
        + v_gen(grid, node, unit, s, f, t)
        * [p_unitConstraintNode(unit, gt_constraint, node)${not ts_unitConstraintNode_(unit, gt_constraint, node, f, t)}
           +ts_unitConstraintNode_(unit, gt_constraint, node, f+df_central_t(f, t), t) ]
        )

    =G=

    + [
      // Constant multiplied by the number of online sub-units
      + [ p_unitConstraintNew(unit, gt_constraint, 'constant') $ {not ts_unitConstraint_(unit, gt_constraint, 'constant', f+df_central_t(f, t), t)}
          + ts_unitConstraint_(unit, gt_constraint, 'constant', f+df_central_t(f, t), t)
          ]
        * [
            + 1 ${not usft_online(unit, s, f, t) or p_unitConstraintNew(unit, gt_constraint, 'onlineMultiplier')=0} // if the unit does not have an online variable
            + [v_online_LP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, gt_constraint, 'onlineMultiplier')
               ]${usft_onlineLP(unit, s, f, t)}
            + [v_online_MIP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, gt_constraint, 'onlineMultiplier')
               ]${usft_onlineMIP(unit, s, f, t)}
            ]
       //+ vq_unitConstraint('increase', gt_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, gt_constraint, t)}  // not needed for gt
       - vq_unitConstraint('decrease', gt_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, gt_constraint, t)}
      ]$ { p_unitConstraintNew(unit, gt_constraint, 'constant')<>0 or ts_unitConstraint_(unit, gt_constraint, 'constant', f+df_central_t(f, t), t) }
;

q_unitLesserThanConstraint(lt_constraint, usft(unit, s, f, t))
    $ unitConstraint(unit, lt_constraint) ..

    // Inputs and/or outputs multiplied by their coefficient
    + sum(gnu(grid, node, unit)${gnu_ltConstrained(lt_constraint, grid, node, unit)},
        + v_gen(grid, node, unit, s, f, t)
        * [p_unitConstraintNode(unit, lt_constraint, node)${not ts_unitConstraintNode_(unit, lt_constraint, node, f, t)}
           +ts_unitConstraintNode_(unit, lt_constraint, node, f+df_central_t(f, t), t) ]
        )

    =L=

    + [
      // Constant multiplied by the number of online sub-units
      + [ p_unitConstraintNew(unit, lt_constraint, 'constant') $ {not ts_unitConstraint_(unit, lt_constraint, 'constant', f+df_central_t(f, t), t)}
          + ts_unitConstraint_(unit, lt_constraint, 'constant', f+df_central_t(f, t), t)
          ]
        * [
            + 1 ${not usft_online(unit, s, f, t) or p_unitConstraintNew(unit, lt_constraint, 'onlineMultiplier')=0} // if the unit does not have an online variable in later effLevels
            + [v_online_LP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, lt_constraint, 'onlineMultiplier')
               ]${usft_onlineLP(unit, s, f, t)}
            + [v_online_MIP(unit, s, f+df_central_t(f, t), t)
               * p_unitConstraintNew(unit, lt_constraint, 'onlineMultiplier')
               ]${usft_onlineMIP(unit, s, f, t)}
            ]
       + vq_unitConstraint('increase', lt_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, lt_constraint, t)}
       // - vq_unitConstraint('decrease', lt_constraint, unit, s, f, t)${not dropVqUnitConstraint(unit, lt_constraint, t)}  // not needed for lt
      ]$ { p_unitConstraintNew(unit, lt_constraint, 'constant')<>0 or ts_unitConstraint_(unit, lt_constraint, 'constant', f+df_central_t(f, t), t) }
;

* --- Total Transfer Limits ---------------------------------------------------

q_transfer(gn2nsft_directional(grid, node, node_, s, f, t)) ..

    // Rightward + Leftward
    + v_transferRightward(grid, node, node_, s, f, t)
    - v_transferLeftward(grid, node, node_, s, f, t)

    =E=

    // = Total Transfer
    + v_transfer(grid, node, node_, s, f, t)
;

* --- Rightward Transfer Limits -----------------------------------------------

q_transferRightwardLimit(gn2nsft_directional(grid, node, node_, s, f, t))
    ${  p_gnn(grid, node, node_, 'transferCapInvLimit')
        } ..

    // Rightward transfer
    + v_transferRightward(grid, node, node_, s, f, t)

    =L=

    + [
        + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
        + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
        ]
        * [

            // Existing transfer capacity
            + p_gnn(grid, node, node_, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)$(ord(t_)<=ord(t)),
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ] // END * availability
;

* --- Leftward Transfer Limits ------------------------------------------------

q_transferLeftwardLimit(gn2nsft_directional(grid, node, node_, s, f, t))
    ${  p_gnn(grid, node, node_, 'transferCapInvLimit')
        } ..

    // Leftward transfer
    + v_transferLeftward(grid, node, node_, s, f, t)

    =L=

    + [
        + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
        + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
        ]
        * [
            // Existing transfer capacity
            + p_gnn(grid, node_, node, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)${ord(t_)<=ord(t)},
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ] // END * availability
;

* --- Rightward Reserve Transfer Limits ---------------------------------------

q_resTransferLimitRightward(gn2nsft_directional(grid, node, node_, s, f, t))
    ${  sum(restypeDirection(restype, 'up'), restypeDirectionGridNodeNode(restype, 'up', grid, node, node_))
        or sum(restypeDirection(restype, 'down'), restypeDirectionGridNodeNode(restype, 'down', grid, node_, node))
        } ..

    // Transfer from node
    + v_transfer(grid, node, node_, s, f, t)

    // Reserved transfer capacities from node
    + sum(restypeDirection(restype, 'up')${restypeDirectionGridNodeNode(restype, 'up', grid, node_, node)},
        + v_resTransferRightward(restype, 'up', grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t)
        ) // END sum(restypeDirection)
    + sum(restypeDirection(restype, 'down')${restypeDirectionGridNodeNode(restype, 'down', grid, node, node_)},
        + v_resTransferLeftward(restype, 'down', grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(restypeDirection)

    =L=

    + [
        + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
        + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
       ]
        * [

            // Existing transfer capacity
            + p_gnn(grid, node, node_, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)$(ord(t_)<=ord(t)),
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ] // END * availability
;

* --- Leftward Reserve Transfer Limits ----------------------------------------

q_resTransferLimitLeftward(gn2nsft_directional(grid, node, node_, s, f, t))
    ${  sum(restypeDirection(restype, 'up'), restypeDirectionGridNodeNode(restype, 'up', grid, node_, node))
        or sum(restypeDirection(restype, 'down'), restypeDirectionGridNodeNode(restype, 'down', grid, node, node_))
        } ..

    // Transfer from node
    + v_transfer(grid, node, node_, s, f, t)

    // Reserved transfer capacities from node
    - sum(restypeDirection(restype, 'up')${restypeDirectionGridNodeNode(restype, 'up', grid, node, node_)},
        + v_resTransferLeftward(restype, 'up', grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        ) // END sum(restypeDirection)
    - sum(restypeDirection(restype, 'down')${restypeDirectionGridNodeNode(restype, 'down', grid, node_, node)},
        + v_resTransferRightward(restype, 'down', grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t)
        ) // END sum(restypeDirection)

  =G=

    - [
        + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
        + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
        ]
        * [
            // Existing transfer capacity
            + p_gnn(grid, node_, node, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)${ord(t_)<=ord(t)},
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ] // END * availability
;

*--- transfer ramp for transfer links with ramp limit -------------------------------------------------------
q_transferRamp(gn2nsft_directional_ramp(grid, node, node_, s, f, t))
     ..

    // ramp rate MW/h
    + v_transferRamp(grid, node, node_, s, f, t)
    // multiplied by step length to divide by stepLength and convert to single hour values
        * p_stepLength(t)

    =E=

    // Change in transfers over the interval: v_transfer(t) - v_transfer(t-1)
    + v_transfer(grid, node, node_, s, f, t)
    - v_transfer(grid, node, node_, s, f+df(f, t+dt(t)), t+dt(t))
;

* --- Ramp limits for transfer links with investment variable -------------------------------------------------
// in case of no investment options, the directional limits are set in 3d_setVariableLimits
q_transferRampLimit1(gn2nsft_directional_ramp(grid, node, node_, s, f, t))
     ${p_gnn(grid, node, node_, 'rampLimit')                   // if ramp constrained
       and [p_gnn(grid, node, node_, 'transferCapInvLimit')    // if investments enabled, direction 1
            or p_gnn(grid, node_, node, 'transferCapInvLimit') // if investments enabled, direction 2
            ]
       } ..

    + v_transferRamp(grid, node, node_, s, f, t)   // MW/h

    =L=

    + [ // Existing transfer capacity
        p_gnn(grid, node, node_, 'transferCap')

        // Investments into additional transfer capacity
        + sum(t_invest(t_)${ord(t_)<=ord(t)},
           + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
           + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
               * p_gnn(grid, node, node_, 'unitSize')
          ) // END sum(t_invest)
      ]
      // availability of tranfer connections
      * [
          + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
          + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
        ]
      * p_gnn(grid, node, node_, 'rampLimit') // ramp limit of transfer connections
      * 60    // Unit conversion from [p.u./min] to [p.u./h]
;

q_transferRampLimit2(gn2nsft_directional_ramp(grid, node, node_, s, f, t))
     ${p_gnn(grid, node, node_, 'rampLimit')                   // if ramp constrained
       and [p_gnn(grid, node, node_, 'transferCapInvLimit')    // if investments enabled, direction 1
            or p_gnn(grid, node_, node, 'transferCapInvLimit') // if investments enabled, direction 2
            ]
       } ..

    + v_transferRamp(grid, node, node_, s, f, t)   // MW/h

    =G=

    - [ // Existing transfer capacity
        p_gnn(grid, node, node_, 'transferCap')

        // Investments into additional transfer capacity
        + sum(t_invest(t_)${ord(t_)<=ord(t)},
           + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
           + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
               * p_gnn(grid, node, node_, 'unitSize')
          ) // END sum(t_invest)
      ]
      // availability of tranfer connections
      * [
          + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
          + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
        ]
      * p_gnn(grid, node, node_, 'rampLimit') // ramp limit of transfer connections
      * 60    // Unit conversion from [p.u./min] to [p.u./h]
;

*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


* --- Rightward Reserve Provision Limits ----------------------------------------

q_reserveProvisionRightward(restypeDirectionGridNodeNode(restype, up_down, grid, node, node_), sft(s, f, t))
    ${  p_gnn(grid, node, node_, 'transferCapInvLimit')
        and gn2n_directional(grid, node, node_)
        and not [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                        ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
                 or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                        ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
                 ]
        } ..

    + v_resTransferRightward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t) // df_reserves based on the receiving node

    =L=

    + p_gnnReserves(grid, node, node_, restype, up_down)
        * [
            + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
            + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
            ]
        * [
            // Existing transfer capacity
            + p_gnn(grid, node, node_, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)${ord(t_)<=ord(t)},
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ]
;

* --- Leftward Reserve Provision Limits ----------------------------------------

q_reserveProvisionLeftward(restypeDirectionGridNodeNode(restype, up_down, grid, node_, node), sft(s, f, t))
    ${  p_gnn(grid, node, node_, 'transferCapInvLimit')
        and gn2n_directional(grid, node, node_)
        and not [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                        ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
                 or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                        ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
                 ]
        } ..

    + v_resTransferLeftward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t) // df_reserves based on the receiving node

    =L=

    + p_gnnReserves(grid, node_, node, restype, up_down)
        * [
            + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
            + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
            ]
        * [
            // Existing transfer capacity
            + p_gnn(grid, node_, node, 'transferCap')

            // Investments into additional transfer capacity
            + sum(t_invest(t_)${ord(t_)<=ord(t)},
                + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
                + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
                    * p_gnn(grid, node, node_, 'unitSize')
                ) // END sum(t_invest)
            ]
;

* --- Additional transfer constraints to make the constraints tight -----------
* These two constraints are only needed for links that have availability to both
* directions.

* This first constraint is defined for links that do not have investment
* possibility but have existing transfer capacity to both directions. If there
* is no existing transfer capacity to both directions, a two-way constraint
* like this is not needed.
q_transferTwoWayLimit1(gn2nsft_directional(grid, node, node_, s, f, t))
    ${not p_gnn(grid, node, node_, 'transferCapInvLimit')
      and (((p_gnn(grid, node, node_, 'availability')>0) and not gn2n_timeseries(grid, node, node_, 'availability'))
          or ((ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node, node_, 'availability')))
      and (((p_gnn(grid, node_, node, 'availability')>0) and not gn2n_timeseries(grid, node_, node, 'availability'))
          or ((ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node_, node, 'availability')))
      and p_gnn(grid, node, node_, 'transferCap')
      and p_gnn(grid, node_, node, 'transferCap')} ..

    // Rightward / (availability * capacity)
    + v_transferRightward(grid, node, node_, s, f, t)
        / [
            + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
            + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
            ]
        / p_gnn(grid, node, node_, 'transferCap')


    // Leftward / (availability * capacity)
    + v_transferLeftward(grid, node, node_, s, f, t)
        / [
            + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
            + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
            ]
        / p_gnn(grid, node_, node, 'transferCap')


    =L=

    + 1
;

* This second constraint is defined for links that have investment possibility
* and where the exististing capacity is the same in both directions. If the
* exististing capacity is not the same in both directions, a tight and linear
* constraint cannot be defined.
q_transferTwoWayLimit2(gn2nsft_directional(grid, node, node_, s, f, t))
    ${p_gnn(grid, node, node_, 'transferCapInvLimit')
      and p_gnn(grid, node, node_, 'transferCap') = p_gnn(grid, node_, node, 'transferCap')
      and (((p_gnn(grid, node, node_, 'availability')>0) and not gn2n_timeseries(grid, node, node_, 'availability'))
          or ((ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node, node_, 'availability')))
      and (((p_gnn(grid, node_, node, 'availability')>0) and not gn2n_timeseries(grid, node_, node, 'availability'))
          or ((ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node_, node, 'availability')))} ..

    // Rightward / availability
    + v_transferRightward(grid, node, node_, s, f, t)
        / [
            + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
            + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
            ]
    // Leftward / availability
    + v_transferLeftward(grid, node, node_, s, f, t)
        / [
            + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
            + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
            ]

    =L=

    // Existing transfer capacity
    + p_gnn(grid, node, node_, 'transferCap')

    // Investments into additional transfer capacity
    + sum(t_invest(t_)${ord(t_)<=ord(t)},
        + v_investTransfer_LP(grid, node, node_, t_)${gn2n_directional_investLP(grid, node, node_)}
        + v_investTransfer_MIP(grid, node, node_, t_)${gn2n_directional_investMIP(grid, node, node_)}
            * p_gnn(grid, node, node_, 'unitSize')
        ) // END sum(t_invest)
;

* =============================================================================
* --- Node State Constraints -------------------------------------------------
* =============================================================================


* --- State Variable Slack ----------------------------------------------------

q_stateUpwardSlack(gn_stateUpwardSlack(grid, node), sft(s, f, t))
    ${ not df_central_t(f, t)
       } ..

    // Slack value
    + sum(UpwardSlack(slack)
        $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
            or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
            },
        v_stateSlack(slack, grid, node, s, f, t))

    =G=

    // state of the node
    + v_state(grid, node, s, f, t)

    // Upper boundary of the variable, constant
    - (p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
       * p_gnBoundaryPropertiesForStates(grid, node,   'upwardLimit', 'multiplier')
       ) ${p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')}

    // Upper boundary of the variable, timeseries
    - (ts_node_(grid, node, 'upwardLimit', f, t)
       * p_gnBoundaryPropertiesForStates(grid, node,   'upwardLimit', 'multiplier')
       ) ${ p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeseries') }

    // Storage capacity from units
    - sum(gnu(grid, node, unit)
        $ { p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
            and usft(unit, s, f, t)
            },
        + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
            * p_gnu(grid, node, unit, 'unitSize')
            * [ // existing units
                + p_unit(unit, 'unitCount')
                // investments
                + v_invest_LP(unit)${unit_investLP(unit)}
                + v_invest_MIP(unit)${unit_investMIP(unit)}
                ]
        ) // END sum(gnu)
;

q_stateDownwardSlack(gn_stateDownwardSlack(grid, node), sft(s, f, t))
    ${ not df_central_t(f, t)
       } ..

    // Slack value
    + sum(downwardSlack(slack)
        $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
            or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
            },
        v_stateSlack(slack, grid, node, s, f, t))

    =G=

    // state of the node
    - v_state(grid, node, s, f, t)

    // Upper boundary of the variable, constant
    + (p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'constant')
       * p_gnBoundaryPropertiesForStates(grid, node,   'downwardLimit', 'multiplier')
       ) ${p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')}

    // Upper boundary of the variable, timeseries
    + (ts_node_(grid, node, 'downwardLimit', f, t)
       * p_gnBoundaryPropertiesForStates(grid, node,   'downwardLimit', 'multiplier')
       ) ${ p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeseries') }
;

* --- Upwards Limit for State Variables ---------------------------------------

q_stateUpwardLimit(gn_state(grid, node), sft(s, f, t))
    ${ not node_superpos(node)
       and [ // nodes that have units with endogenous output with possible reserve provision
             sum(gn2gnu(grid, node, grid_, node_output, unit) $(sum(restype, gnu_resCapable(restype, 'down', grid_, node_output, unit))), 1)
             // or nodes that have units with endogenous input with possible reserve provision
             or sum(gn2gnu(grid_, node_input, grid, node, unit)$(sum(restype, gnu_resCapable(restype, 'down', grid_, node_input , unit))), 1)
             // or nodes that have upward state slack activated
             or gn_stateUpwardSlack(grid, node)
             // or nodes that have units whose invested capacity limits their state
             or sum(gnu(grid, node, unit_invest(unit)), p_gnu(grid, node, unit, 'upperLimitCapacityRatio'))
             ]
       } ..

    // Utilizable headroom in the state variable
    + [
        // Current state of the variable
        - v_state(grid, node, s, f+df_central_t(f, t), t)

        // Upper boundary of the variable, constant
        + (p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
           * p_gnBoundaryPropertiesForStates(grid, node,   'upwardLimit', 'multiplier')
           ) ${p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')}

        // Upper boundary of the variable, timeseries
        + (ts_node_(grid, node, 'upwardLimit', f, t)
           * p_gnBoundaryPropertiesForStates(grid, node,   'upwardLimit', 'multiplier')
          ) ${ p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeseries') }

        // state slack
        + sum(upwardSlack(slack)
                  $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
                      or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
                      },
            + v_stateSlack(slack, grid, node, s, f, t)
            ) // END sum(upwardSlack)

        // Investments
        + sum(gnu(grid, node, unit)
            $ { p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                and usft(unit, s, f, t)
                },
            + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                * p_gnu(grid, node, unit, 'unitSize')
                * [ // existing units
                    + p_unit(unit, 'unitCount')
                    // investments
                    + v_invest_LP(unit)${unit_investLP(unit)}
                    + v_invest_MIP(unit)${unit_investMIP(unit)}
                    ]
            ) // END sum(gnu)

        ] // END Headroom
        * [
            // Conversion to energy
            + p_gn(grid, node, 'energyStoredPerUnitOfState')

            // Accounting for losses from the node
            + p_stepLength(t)
                * [
                    + p_gn(grid, node, 'selfDischargeLoss')
                    + sum(gnn_state(grid, node, to_node),
                        + p_gnn(grid, node, to_node, 'diffCoeff')
                        ) // END sum(to_node)
                    ]
            ] // END * Headroom

    =G=

    // Convert reserve power to energy
    + p_stepLength(t)
        * [
            // Reserve provision from units that output to this node
            + sum(gn2gnu(grid_, node_input, grid, node, unit)${usft(unit, s, f, t)},
                // Downward reserves from units that output energy to the node
                + sum(gnusft_resCapable(restype, 'down', grid_, node_input, unit, s, f, t),
                    + v_reserve(restype, 'down', grid_, node_input, unit, s, f+df_reserves(grid_, node_input, restype, f, t), t)
                        * p_gnReserves(grid_, node_input, restype, 'reserve_activation_duration')
                        / p_gnReserves(grid_, node_input, restype, 'reserve_reactivation_time')
                        / sum(eff_usft(effGroup, unit, s, f, t),
                            + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                            + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                            ) // END sum(effGroup)
                    ) // END sum(restype)
                ) // END sum(gn2gnu)

            // Reserve provision from units that take input from this node
            + sum(gn2gnu(grid, node, grid_, node_output, unit)${usft(unit, s, f, t)},
                // Downward reserves from units that use the node as energy input
                + sum(gnusft_resCapable(restype, 'down', grid_, node_output, unit, s, f, t),
                    + v_reserve(restype, 'down', grid_, node_output, unit, s, f+df_reserves(grid_, node_output, restype, f, t), t)
                        * p_gnReserves(grid_, node_output, restype, 'reserve_activation_duration')
                        / p_gnReserves(grid_, node_output, restype, 'reserve_reactivation_time')
                        * sum(eff_usft(effGroup, unit, s, f, t),
                            + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                            + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                            ) // END sum(effGroup)
                    ) // END sum(restype)
                ) // END sum(gn2gnu)

            // Here we could have a term for using the energy in the node to offer reserves as well as imports and exports of reserves, but as long as reserves are only
            // considered in power grids that do not have state variables, these terms are not needed. Earlier commit (29.11.2016) contains a draft of those terms.

            ] // END * p_stepLength
;

* --- Downwards Limit for State Variables -------------------------------------

q_stateDownwardLimit(gn_state(grid, node), sft(s, f, t))
    ${ //ordinary nodes with no superpositioning of state
       not node_superpos(node)
       and [ // nodes that have units with endogenous output with possible reserve provision
             sum(gn2gnu(grid, node, grid_, node_output, unit)$(sum(restype, gnu_resCapable(restype, 'up', grid_, node_output, unit))), 1)
             // or nodes that have units with endogenous input with possible reserve provision
             or sum(gn2gnu(grid_, node_input, grid, node, unit) $(sum(restype, gnu_resCapable(restype, 'up', grid_, node_input , unit))), 1)
             // or nodes that have downward state slack activated
             or gn_stateDownwardSlack(grid, node)
             ]
       } ..

    // Utilizable headroom in the state variable
    + [
        // Current state of the variable
        + v_state(grid, node, s, f+df_central_t(f, t), t)

        // Lower boundary of the variable
        // Lower boundary of the variable, constant
        - (p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'constant')
           * p_gnBoundaryPropertiesForStates(grid, node,   'downwardLimit', 'multiplier')
           ) ${p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')}

        // Lower boundary of the variable, timeseries
        - (ts_node_(grid, node, 'downwardLimit', f, t)
           * p_gnBoundaryPropertiesForStates(grid, node,   'downwardLimit', 'multiplier')
          ) ${ p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeseries') }

        // state slack
        + sum(downwardSlack(slack)
                  $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
                      or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
                      },
            + v_stateSlack(slack, grid, node, s, f, t)
            ) // END sum(downwardSlack)

        ] // END Headroom
        * [
            // Conversion to energy
            + p_gn(grid, node, 'energyStoredPerUnitOfState')

            // Accounting for losses from the node
            + p_stepLength(t)
                * [
                    + p_gn(grid, node, 'selfDischargeLoss')
                    + sum(gnn_state(grid, node, to_node),
                        + p_gnn(grid, node, to_node, 'diffCoeff')
                        ) // END sum(to_node)
                    ]
            ] // END * Headroom

    =G=

    // Convert reserve power to energy
    + p_stepLength(t)
        * [
            // Reserve provision from units that output to this node
            + sum(gn2gnu(grid_, node_input, grid, node, unit)${usft(unit, s, f, t)},
                // Upward reserves from units that output energy to the node
                + sum(gnusft_resCapable(restype, 'up', grid_, node_input, unit, s, f, t),
                    + v_reserve(restype, 'up', grid_, node_input, unit, s, f+df_reserves(grid_, node_input, restype, f, t), t)
                        * p_gnReserves(grid_, node_input, restype, 'reserve_activation_duration')
                        / p_gnReserves(grid_, node_input, restype, 'reserve_reactivation_time')
                        / sum(eff_usft(effGroup, unit, s, f, t),
                            + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                            + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                            ) // END sum(effGroup)
                    ) // END sum(restype)
                ) // END sum(gn2gnu)

            // Reserve provision from units that take input from this node
            + sum(gn2gnu(grid, node, grid_, node_output, unit)${usft(unit, s, f, t)},
                // Upward reserves from units that use the node as energy input
                + sum(gnusft_resCapable(restype, 'up', grid_, node_output, unit, s, f, t),
                    + v_reserve(restype, 'up', grid_, node_output, unit, s, f+df_reserves(grid_, node_output, restype, f, t), t)
                        * p_gnReserves(grid_, node_output, restype, 'reserve_activation_duration')
                        / p_gnReserves(grid_, node_output, restype, 'reserve_reactivation_time')
                        * sum(eff_usft(effGroup, unit, s, f, t),
                            + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                            + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                            ) // END sum(effGroup)
                    ) // END sum(restype)
                ) // END sum(gn2gnu)

            // Here we could have a term for using the energy in the node to offer reserves as well as imports and exports of reserves, but as long as reserves are only
            // considered in power grids that do not have state variables, these terms are not needed. Earlier commit (29.11.2016) contains a draft of those terms.

            ] // END * p_stepLength
;

* --- State Variable Difference -----------------------------------------------

q_boundStateMaxDiff(gnn_boundState(grid, node, node_), sft(s, f, t))
    ${ //ordinary nodes with no superpositioning of state
       not node_superpos(node)
    }..

    // State of the bound node
   + v_state(grid, node, s, f+df_central_t(f, t), t)

    // Reserve contributions affecting bound node, converted to energy
    + p_stepLength(t)
        * [
            // Downwards reserve provided by input units
            + sum(gnusft_resCapable(restype, 'down', grid_, node_input, unit, s, f, t)
                ${ p_gn(grid, node, 'energyStoredPerUnitOfState') // Reserve provisions not applicable if no state energy content
                   and gn2gnu(grid_, node_input, grid, node, unit)
                   },
                + v_reserve(restype, 'down', grid_, node_input, unit, s, f+df_reserves(grid_, node_input, restype, f, t), t)
                    * p_gnReserves(grid_, node_input, restype, 'reserve_activation_duration')
                    / p_gnReserves(grid_, node_input, restype, 'reserve_reactivation_time')
                    / sum(eff_usft(effGroup, unit, s, f, t),
                        + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                        + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                        ) // END sum(effGroup)
                ) // END sum(nuRescapable)

            // Downwards reserve provided by output units
            + sum(gnusft_resCapable(restype, 'down', grid_, node_output, unit, s, f, t)
                ${ p_gn(grid, node, 'energyStoredPerUnitOfState') // Reserve provisions not applicable if no state energy content
                   and gn2gnu(grid, node, grid_, node_output, unit)
                   },
                + v_reserve(restype, 'down', grid_, node_output, unit, s, f+df_reserves(grid_, node_output, restype, f, t), t)
                    * p_gnReserves(grid_, node_output, restype, 'reserve_activation_duration')
                    / p_gnReserves(grid_, node_output, restype, 'reserve_reactivation_time')
                    * sum(eff_usft(effGroup, unit, s, f, t),
                        + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                        + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                        ) // END sum(effGroup)
                ) // END sum(nuRescapable)

            // Here we could have a term for using the energy in the node to offer reserves as well as imports and exports of reserves, but as long as reserves are only
            // considered in power grids that do not have state variables, these terms are not needed. Earlier commit (16.2.2017) contains a draft of those terms.

            ] // END * p_stepLength

            // Convert the reserve provisions into state variable values
            / ( p_gn(grid, node, 'energyStoredPerUnitOfState') + 1${not p_gn(grid, node, 'energyStoredPerUnitOfState')} )

    =L=

    // State of the binding node
    + v_state(grid, node_, s, f+df_central_t(f, t), t)

   // Maximum state difference parameter
    + p_gnn(grid, node, node_, 'boundStateMaxDiff')

    // Reserve contributions affecting bounding node, converted to energy
    - p_stepLength(t)
        * [
            // Upwards reserve by input node
            + sum(gnusft_resCapable(restype, 'up', grid_, node_input, unit, s, f, t)
                ${ p_gn(grid, node_, 'energyStoredPerUnitOfState')
                   and gn2gnu(grid_, node_input, grid, node_, unit)
                   },
                + v_reserve(restype, 'up', grid_, node_input, unit, s, f+df_reserves(grid_, node_input, restype, f, t), t)
                    * p_gnReserves(grid_, node_input, restype, 'reserve_activation_duration')
                    / p_gnReserves(grid_, node_input, restype, 'reserve_reactivation_time')
                    / sum(eff_usft(effGroup, unit, s, f, t),
                        + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                        + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                        ) // END sum(effGroup)
                ) // END sum(nuRescapable)

            // Upwards reserve by output node
            + sum(gnusft_resCapable(restype, 'up', grid_, node_output, unit, s, f, t)
                ${ p_gn(grid, node_, 'energyStoredPerUnitOfState')
                   and gn2gnu(grid, node_, grid_, node_output, unit)
                   },
                + v_reserve(restype, 'up', grid_, node_output, unit, s, f+df_reserves(grid_, node_output, restype, f, t), t)
                    * p_gnReserves(grid_, node_output, restype, 'reserve_activation_duration')
                    / p_gnReserves(grid_, node_output, restype, 'reserve_reactivation_time')
                    * sum(eff_usft(effGroup, unit, s, f, t),
                        + p_effGroupUnit(effGroup, unit, 'slope')${not ts_effGroupUnit_(effGroup, unit, 'slope', f, t)}
                        + ts_effGroupUnit_(effGroup, unit, 'slope', f, t) // Efficiency approximated using maximum slope of effGroup?
                        ) // END sum(effGroup)
                ) // END sum(nuRescapable)

            // Here we could have a term for using the energy in the node to offer reserves as well as imports and exports of reserves, but as long as reserves are only
            // considered in power grids that do not have state variables, these terms are not needed. Earlier commit (16.2.2017) contains a draft of those terms.

            ] // END * p_stepLength

            // Convert the reserve provisions into state variable values
            / ( p_gn(grid, node_, 'energyStoredPerUnitOfState') + 1${not p_gn(grid, node_, 'energyStoredPerUnitOfState')} )
;

* --- Cyclic Boundary Conditions ----------------------------------------------

* Binding the node state values in the end of one sample to the value in the beginning of another sample

q_boundCyclic(gnss_bound(gn_state(grid, node), s_, s))
    ${  s_active(s_)
        and s_active(s)
        and not node_superpos(node) //do not write this constraint for superposed node states
    }..

    // Initial value of the state of the node at the start of the sample s
    + sum(sft(s, f, t)$st_start(s, t),
           + v_state(grid, node, s, f+df_noReset(f, t+dt(t)), t+dt(t))
           ) // END sum(sft)

    =E=

    // Initial value of the state of the node at the start of the sample s_
    + sum(sft(s_, f, t)$st_start(s_, t),
           + v_state(grid, node, s_, f+df_noReset(f, t+dt(t)), t+dt(t))
           ) // END sum(sft)
    // Change in the state value over the sample s_, multiplied by
    // sample s_ temporal weight, multiplied by selfDischargeLoss
    + [
        // State of the node at the end of the sample s_
        + sum(sft(s_, f, t)$st_end(s_, t),
               + v_state(grid, node, s_, f, t)
               ) // END sum(sft)
        // State of the node at the start of the sample s_
        - sum(sft(s_, f, t)$st_start(s_, t),
               + v_state(grid, node, s_, f+df_noReset(f, t+dt(t)), t+dt(t))
               ) // END sum(sft)
        ]
    // temporal weight of sample s_ if no selfDischargeLoss
    // selfDischargeLoss as exponential function sum over the repeats of sample s_
    // sum_i=1...N (r ^(b*(i-1))) = (r^bN - 1)/(r^b - 1)
    // where r = 1-selfDischargeLoss, b = sample length in hours, and
    // N = number of times the sample is repeated = sample weigth
    // this contains the sampleWeight parameter
    * [ + sum(m, p_msWeight(m, s_)) $ {p_gn(grid, node, 'selfDischargeLoss') = 0}
        + (
              ( (1-p_gn(grid, node, 'selfDischargeLoss')) ** ( p_sLengthInHours(s_) * sum(m, p_msWeight(m, s_)) ) - 1 )
             /( (1-p_gn(grid, node, 'selfDischargeLoss')) ** p_sLengthInHours(s_) - 1)

          ) $ {p_gn(grid, node, 'selfDischargeLoss') > 0}
        ] // selfDischargeLoss factor
;

* =============================================================================
* --- Equations for superposed states -------------------------------------
* =============================================================================


*--- End value for superposed states  ----------------------------
* The end value here is the node state at the end of the last candidate period z

q_superposBoundEnd(gn_state(grid, node_superpos(node)), m)
    $(p_gn(grid, node, 'boundEnd') )..

    // Value of the superposed state of the node at the end of the last candidate
    // period
    sum(mz(m,z)$(ord(z) eq mSettings(m, 'candidate_periods') ),
        //the inter-period state at the beginning of the last candidate period
        v_state_z(grid, node, z)
        *
        //multiplied by the self discharge loss over the period
        sum(zs(z, s_),
            power(1 - mSettings(m, 'stepLengthInHours')
                    * p_gn(grid, node, 'selfDischargeLoss'),
                 msEnd(m,s_) - msStart(m,s_) )
        )
        +
        //change of the intra-period state during the representative period
        sum(zs(z, s_),
        // State of the node at the end of the sample s_
             + sum(sft(s_, f, t)$st_end(s_, t),
                 + v_state(grid, node, s_, f, t)
                 ) // END sum(sft)

        // State of the node at the start of the sample s_
                - sum(sft(s_, f, t)$st_start(s_, t),
                    + v_state(grid, node, s_, f+df_noReset(f, t+dt(t)), t+dt(t))
                 ) // END sum(sft)
        ) // end sum(zs)
    )

    =E=

    p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
        * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier')
;

*--- Inter-period state dynamic equation for superpositioned states -----------
* Note: diffusion from and to other nodes is not supported

q_superposInter(gn_state(grid, node_superpos(node)), mz(m,z))
    ${  ord(z) > 1
        }..

    // Inter-period state of the node at the beginning of period z
    v_state_z(grid, node, z)

    =E=

    // State of the node at the beginning of previous period z-1
    v_state_z(grid, node, z-1)
    *
    //multiplied by the self discharge loss over the period
    sum(zs(z-1, s_),
        power(1 - mSettings(m, 'stepLengthInHours')
                * p_gn(grid, node, 'selfDischargeLoss'),
             msEnd(m,s_) - msStart(m,s_) )
    )
    +
    //change of the intra-period state during the previous period z-1
    sum(zs(z-1, s_),
        // State of the node at the end of the sample s_
          + sum(sft(s_, f, t)$st_end(s_, t),
              + v_state(grid, node, s_, f, t)
              ) // END sum(sft)

        // State of the node at the start of the sample s_
                - sum(sft(s_, f, t)$st_start(s_, t),
                    + v_state(grid, node, s_, f+df_noReset(f, t+dt(t)), t+dt(t))
                 ) // END sum(sft)
      ) // end sum(zs)
;

*--- Max intra-period state value during a sample for superpositioned states --
q_superposStateMax(gn_state(grid, node_superpos(node)), sft(s, f, t))..

    v_statemax(grid, node, s)

    =G=

    v_state(grid, node, s, f+df_noReset(f, t+dt(t)), t+dt(t))

;

*--- Min intra-period state value during a sample for superpositioned states --

q_superposStateMin(gn_state(grid, node_superpos(node)), sft(s, f, t))..

    v_statemin(grid, node, s)

    =L=

    v_state(grid, node, s, f+df_noReset(f, t+dt(t)), t+dt(t))

;


*--- Upward limit for superpositioned states -----------------
* Note:

q_superposStateUpwardLimit(gn_state(grid, node_superpos(node)), mz(m,z))..

    // Utilizable headroom in the state variable

    // Upper boundary of the variable
    + p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
        ${p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')}

    // Investments
    + sum(gnu(grid, node, unit),
        + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
            * p_gnu(grid, node, unit, 'unitSize')
            * [ // existing units
                + p_unit(unit, 'unitCount')
                // investments
                + v_invest_LP(unit)${unit_investLP(unit)}
                + v_invest_MIP(unit)${unit_investMIP(unit)}
                ]
      ) // END sum(gnu)

    // State of the node at the beginning of period z
    - v_state_z(grid, node, z)

    // Maximum state reached during the related sample
    - sum(zs(z,s_),
       v_statemax(grid, node, s_)
    )



    =G= 0
;

*--- Downward limit for superpositioned states -----------------

q_superposStateDownwardLimit(gn_state(grid, node_superpos(node)), mz(m,z))..

    // Utilizable headroom in the state variable


    // State of the node at the beginning of period z
    + v_state_z(grid, node, z)
    *
    // multiplied by the self discharge loss over the whole period
    // (note here we make a conservative assumption that the minimum
    // intra-period state v_statemin is reached near the end of the period
    // so that maximal effect of the self-discharge loss applies.)
    sum(zs(z, s_),
        power(1 - mSettings(m, 'stepLengthInHours')
                * p_gn(grid, node, 'selfDischargeLoss'),
             msEnd(m,s_) - msStart(m,s_) )
    )
    // Minimum state reached during the related sample
    + sum(zs(z,s_),
       v_statemin(grid, node, s_)
    )

    // Lower boundary of the variable
    - p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'constant')${p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')}

    =G= 0
;

* =============================================================================
* --- Security related constraints  ------------------------------------------
* =============================================================================


*--- Minimum Inertia ----------------------------------------------------------

q_inertiaMin(restypeDirectionGroup(restype_inertia, up_down, group), sft(s, f, t))
    ${  ord(t) <= t_solveFirst + p_groupReserves(group, restype_inertia, 'reserve_length')
        and not [ restypeReleasedForRealization(restype_inertia)
                  and f_realization(f)]
        and p_groupPolicy(group, 'ROCOF')
        and p_groupPolicy(group, 'defaultFrequency')
        and p_groupPolicy(group, 'staticInertia')
        } ..

    // Rotational energy in the system
    + p_groupPolicy(group, 'ROCOF')*2
        * [
            + sum(gnu(grid, node, unit)${ p_gnu(grid, node, unit, 'unitSize')
                                            and usft(unit, s, f, t)
                                        },
                + p_gnu(grid, node, unit, 'inertia')
                    * p_gnu(grid ,node, unit, 'unitSizeMVA')
                    * [
                        + v_online_LP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineLP(unit, s, f, t)}
                        + v_online_MIP(unit, s, f+df_central_t(f, t), t)
                            ${usft_onlineMIP(unit, s, f, t)}
                        + v_gen(grid, node, unit, s, f, t)${not usft_online(unit, s, f, t)}
                            / (p_gnu(grid, node, unit, 'unitSize')$gnu_output(grid, node, unit) - p_gnu(grid, node, unit, 'unitSize')$gnu_input(grid, node, unit))
                        ] // * p_gnu
                ) // END sum(gnu)
            ] // END * p_groupPolicy

    =G=

    // Demand for rotational energy / fast frequency reserve
    + p_groupPolicy(group, 'defaultFrequency')
        * [
            + p_groupReserves(group, restype_inertia, up_down)
            - sum(gnusft(grid, node, unit, s, f, t)${   gnGroup(grid, node, group)
                                                    and gnu_resCapable(restype_inertia, up_down, grid, node, unit)
                                                    },
                + v_reserve(restype_inertia, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_inertia, f, t), t)
                    * [ // Account for reliability of reserves
                        + 1${sft_realized(s, f+df_reserves(grid, node, restype_inertia, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                        + p_gnuReserves(grid, node, unit, restype_inertia, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype_inertia, f, t), t)}
                        ] // END * v_reserve
                ) // END sum(gnusft)

            // Reserve demand feasibility dummy variables
            - vq_resDemand(restype_inertia, up_down, group, s, f+df_reservesGroup(group, restype_inertia, f, t), t)
                ${not dropVqResDemand(restype_inertia, up_down, group, t)}
            - vq_resMissing(restype_inertia, up_down, group, s, f+df_reservesGroup(group, restype_inertia, f, t), t)
                ${ft_reservesFixed(group, restype_inertia, f+df_reservesGroup(group, restype_inertia, f, t), t)
                  and not dropVqResMissing(restype_inertia, up_down, group, t)}
            ] // END * p_groupPolicy
;


*--- Maximum Share of Instantaneous Generation --------------------------------

q_instantaneousShareMax(group, sft(s, f, t))
    ${  p_groupPolicy(group, 'instantaneousShareMax')
        } ..

    // Generation of units in the group
    + sum(gnusft(gnu_output(grid, node, unit), s, f, t)$(
                                                      ( gnuGroup(grid, node, unit, group)
                                                          $p_gnu(grid, node, unit, 'unitSize')
                                                      ) $gnGroup(grid, node, group)
                                                    ),
        + v_gen(grid, node, unit, s, f, t)
        ) // END sum(gnu)

    // Controlled transfer to this node group
    // Set gn2nGroup controls whether transfer is included in the equation
    + sum(gn2nGroup(gn2n_directional(grid, node, node_), group)$(
                                                                  ( not gnGroup(grid, node_, group)
                                                                  ) $gnGroup(grid, node, group)
                                                                ),
        + v_transferLeftward(grid, node, node_, s, f, t)
            * (1
                - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
              )
        ) // END sum(gn2n_directional)

    + sum(gn2nGroup(gn2n_directional(grid, node_, node),group)$(
                                                                 ( not gnGroup(grid, node_, group)
                                                                 ) $gnGroup(grid, node, group)
                                                               ),
        + v_transferRightward(grid, node_, node, s, f, t)
            * (1
                - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
              )
        ) // END sum(gn2n_directional)

    =L=

    + p_groupPolicy(group, 'instantaneousShareMax')
        * [
            // External power inflow/outflow
            - sum(gnGroup(grid, node, group),
                // constant
                + p_gn(grid, node, 'influx') $ {gn_influx(grid, node) and not gn_influxTs(grid, node)}
                // times series (MWh/h)
                + ts_influx_(grid, node, f, t) $ gn_influxTs(grid, node)
                ) // END sum(gnGroup)

            // Consumption of units
            - sum(gnusft(gnu_input(grid, node, unit), s, f, t)$( p_gnu(grid, node, unit, 'unitSize')
                                                              $gnGroup(grid, node, group)
                                                           ),
                + v_gen(grid, node, unit, s, f, t)
                ) // END sum(gnu)

            // Controlled transfer from this node group
            + sum(gn2n_directional(grid, node, node_)$(
                                                        ( not gnGroup(grid, node_, group)
                                                        ) $gnGroup(grid, node, group)
                                                      ),
                + v_transferRightward(grid, node, node_, s, f, t)
                ) // END sum(gn2n_directional)

            + sum(gn2n_directional(grid, node_, node)$(
                                                        ( not gnGroup(grid, node_, group)
                                                        ) $gnGroup(grid, node, group)
                                                      ),
                + v_transferLeftward(grid, node_, node, s, f, t)
                ) // END sum(gn2n_directional)
$ontext
        // No uncontrolled (AC) transfer because this equation is typically used
        // for one synchronous area which does not have any external AC links

        // Energy diffusion from this node to neighbouring nodes
      + sum(gnn_state(grid, node, node_)${  gnGroup(grid, node, group)
                                            and not gnGroup(grid, node_, group)
            }, p_gnn(grid, node, node_, 'diffCoeff') * v_state(grid, node, f+df_central_t(f, t), t)
        )
        // Energy diffusion from neighbouring nodes to this node
      - sum(gnn_state(grid, node_, node)${  gnGroup(grid, node, group)
                                            and not gnGroup(grid, node_, group)
            }, p_gnn(grid, node_, node, 'diffCoeff') * v_state(grid, node_, f+df_central_t(f, t), t)
        )
$offtext
            ] // END * p_groupPolicy

;

*--- Constrained Number of Online Units ---------------------------------------

q_constrainedOnlineMultiUnit(group, sft(s, f, t))
    ${  p_groupPolicy(group, 'constrainedOnlineTotalMax')
        or groupPolicyTimeseries (group, 'constrainedOnlineTotalMax')
        or sum(unit$uGroup(unit, group), abs(p_groupPolicyUnit(group, 'constrainedOnlineMultiplier', unit)))
        } ..

    // Sum of multiplied online units
    + sum(unit$uGroup(unit, group),
        + p_groupPolicyUnit(group, 'constrainedOnlineMultiplier', unit)
            * [
                + v_online_LP(unit, s, f+df_central_t(f, t), t)
                    ${usft_onlineLP(unit, s, f, t)}
                + v_online_MIP(unit, s, f+df_central_t(f, t), t)
                    ${usft_onlineMIP(unit, s, f, t)}
                ] // END * p_groupPolicyUnit(group, 'constrainedOnlineMultiplier', unit)
        ) // END sum(unit)

    =L=

    // Total maximum of multiplied online units, constant
    + p_groupPolicy(group, 'constrainedOnlineTotalMax') $ {not groupPolicyTimeseries (group, 'constrainedOnlineTotalMax')}

    // Total maximum of multiplied online units, time series
    + ts_groupPolicy_(group, 'constrainedOnlineTotalMax', t) $ {groupPolicyTimeseries (group, 'constrainedOnlineTotalMax')}
;

*--- Required Capacity Margin -------------------------------------------------

q_capacityMargin(gn(grid, node), sft(s, f, t))
    ${  p_gn(grid, node, 'capacityMargin')
        } ..

    // Availability of output units, based on 'availabilityCapacityMargin'
    + sum(gnu_output(grid, node, unit)${ usft(unit, s, f, t)
                                         and p_gnu(grid, node, unit, 'availabilityCapacityMargin')
                                         },
        + [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
            * p_gnu(grid, node, unit, 'availabilityCapacityMargin')
            * [
                // Output capacity before investments
                + p_gnu(grid, node, unit, 'capacity')

                // Output capacity investments
                + p_gnu(grid, node, unit, 'unitSize')
                    * [
                        + v_invest_LP(unit)${unit_investLP(unit)}
                        + v_invest_MIP(unit)${unit_investMIP(unit)}
                        ] // END * p_gnu(unitSize)
                ] // END * unit availability
        ) // END sum(gnu_output)

    // Availability of input units, based on 'availabilityCapacityMargin'
    - sum(gnu_input(grid, node, unit)${ usft(unit, s, f, t)
                                         and p_gnu(grid, node, unit, 'availabilityCapacityMargin')
                                         },
        + [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
            * p_gnu(grid, node, unit, 'availabilityCapacityMargin')
            * [
                // Output capacity before investments
                + p_gnu(grid, node, unit, 'capacity')

                // Output capacity investments
                + p_gnu(grid, node, unit, 'unitSize')
                    * [
                        + v_invest_LP(unit)${unit_investLP(unit)}
                        + v_invest_MIP(unit)${unit_investMIP(unit)}
                        ] // END * p_gnu(unitSize)
                ] // END * unit availability
        ) // END sum(gnu_output)

    // Availability of units, including capacity factors for flow units and v_gen for other units
    + sum(gnu(grid, node, unit)${ usft(unit, s, f, t)
                                         and not p_gnu(grid, node, unit, 'availabilityCapacityMargin')
                                         },
        // Capacity factors for flow units
        + sum(flowUnit(flow, unit)${ unit_flow(unit) },
            + ts_cf_(flow, node, f, t)
            ) // END sum(flow)
            // Taking into account availability.
            * [
                + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
                + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
                ]
            // adding exception of input flow units
            * [ -1 $ gnu_input(grid, node, unit)
                +1 $ gnu_output(grid, node, unit)
                ]
            // capacity
            * [
                // Output capacity before investments
                + p_gnu(grid, node, unit, 'capacity')

                // Output capacity investments
                + p_gnu(grid, node, unit, 'unitSize')
                    * [
                        + v_invest_LP(unit)${unit_investLP(unit)}
                        + v_invest_MIP(unit)${unit_investMIP(unit)}
                        ] // END * p_gnu(unitSize)
                ] // END * unit availability

        + v_gen(grid, node, unit, s, f, t)${not unit_flow(unit)}
        ) // END sum(gnu_output)

    // Transfer to node
    + sum(gn2n_directional(grid, node_, node),
        + v_transfer(grid, node_, node, s, f, t)
        - v_transferRightward(grid, node_, node, s, f, t)
            * [
                + p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                + ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                ]
        ) // END sum(gn2n_directional)

    // Transfer from node
    - sum(gn2n_directional(grid, node, node_),
        + v_transfer(grid, node, node_, s, f, t)
        + v_transferLeftward(grid, node, node_, s, f, t)
            * [
                + p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                + ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                ]
        ) // END sum(gn2n_directional)

    // Diffusion to node
    + sum(gnn_state(grid, from_node, node),
        + p_gnn(grid, from_node, node, 'diffCoeff')
            * v_state(grid, from_node, s, f+df_central_t(f, t), t)
            * (1 - p_gnn(grid, from_node, node, 'diffLosses'))
        ) // END sum(gnn_state)

    // Diffusion from node
    - sum(gnn_state(grid, node, to_node),
        + p_gnn(grid, node, to_node, 'diffCoeff')
            * v_state(grid, node, s, f+df_central_t(f, t), t)
        ) // END sum(gnn_state)

    // Energy influx
    // constant (MWh/h)
    + p_gn(grid, node, 'influx') $ {gn_influx(grid, node) and not gn_influxTs(grid, node)}
    // times series (MWh/h)
    + ts_influx_(grid, node, f, t) $ gn_influxTs(grid, node)

    // Capacity margin feasibility dummy variables
    + vq_capacity(grid, node, s, f, t)

    =G=

    // Capacity minus influx must be greated than the desired margin
    + p_gn(grid, node, 'capacityMargin')
;

*--- Constrained Investment Ratios and Sums For Groups of Units -----------

q_constrainedCapMultiUnit(group)
    ${  p_groupPolicy(group, 'constrainedCapTotalMax')
        or sum(uGroup(unit, group), abs(p_groupPolicyUnit(group, 'constrainedCapMultiplier', unit)))
        } ..

    // Sum of multiplied investments
    + sum(uGroup(unit, group),
        + p_groupPolicyUnit(group, 'constrainedCapMultiplier', unit)
            * [
                + v_invest_LP(unit)${unit_investLP(unit)}
                + v_invest_MIP(unit)${unit_investMIP(unit)}
                ] // END * p_groupPolicyUnit(group, 'constrainedCapMultiplier', unit)
        ) // END sum(unit)

    =L=

    // Total maximum of multiplied investments
    + p_groupPolicy(group, 'constrainedCapTotalMax')
;

*--- Required Emission Cap ----------------------------------------------------
* Limit for emissions in a specific group of nodes, gnGroup, during specified time steps, sGroup.
* This can limit total emissions by grouping all nodes in one group, but
* allows controlling also smaller subsets, e.g. a single country.
* Corresponding results table is r_emissionByNodeGroup, however that does not take into account sGroup condition.
* result tables r_emission_operationEmissions, r_emission_startupEmissions,
* and r_emission_capacityEmissions cover emissions even if they are not in any group

* !!! NOTES !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
* This limits emissions only included in gnGroup and sGroup
* This equation doesn't currently work with rolling planning simulations. Is there any way to make it work?
* Limiting emissions from a specific unit group, e.g. all coal power plants, would require a corresponding constraint for gnuGroup

q_emissioncapNodeGroup(group, emission)
    ${  p_groupPolicyEmission(group, 'emissionCap', emission)
        } ..

    // Emissions depending on time step length

    // Emissions from operation: gn related emissions (tEmission), typically consumption and production of fuels
    // if consumption -> emissions, if production -> negative emissions due to emissions bound to product
    // multiply by -1 because consumption is negative and production positive
    - sum(gnusft(grid, node, unit, s, f, t)${sGroup(s, group)
                                             and gnGroup(grid, node, group)
                                             and p_nEmission(node, emission)
                                             },
        + p_sft_probability(s, f, t)
        * p_stepLength(t)
        * v_gen(grid, node, unit, s, f, t)
        * p_nEmission(node, emission)
        ) // END sum(gnusft)

    // LCA emissions from operation: activity related emissions
    // if consumption -> emissions, if production -> emissions
    + sum(gnusft(grid, node, unit, s, f, t)${sGroup(s, group)
                                             and gnGroup(grid, node, group)
                                             and p_gnuEmission(grid, node, unit, emission, 'vomEmissions')
                                             },
        + p_sft_probability(s, f, t)
        * p_stepLength(t)
        * v_gen(grid, node, unit, s, f, t)
        * p_gnuEmission(grid, node, unit, emission, 'vomEmissions') // tEmission/MWh
        // negative sign for input, because v_gen is negative for input
        * (-1$gnu_input(grid, node, unit)
           +1$gnu_output(grid, node, unit)
           )
        ) // END sum(gnusft)

    // Emissions not depending on time step length

    // Emission from start-ups
    + sum((usft_online(unit, s, f, t), starttype)${sGroup(s, group)
                                                   and [unitStarttype(unit, starttype) and p_uStartup(unit, starttype, 'consumption')]
                                                   },
        + p_sft_probability(s, f, t)
        * [// number of start-ups
           + v_startup_LP(starttype, unit, s, f, t)$usft_onlineLP(unit, s, f, t)
           + v_startup_MIP(starttype, unit, s, f, t)$usft_onlineMIP(unit, s, f, t)
           ]
        * [// node specific emissions
           +sum(nu_startup(node, unit)${sum(grid, gnGroup(grid, node, group))
                                        and p_nEmission(node, emission)
                                        },
                      + p_unStartup(unit, node, starttype) // MWh/start-up
                          * p_nEmission(node, emission) // t/MWh
                      ) // END sum(nu_startup)
           ]
        ) // sum(usft_online)

    + sum(s_active(s) $ sGroup(s, group), // consider ms only if it has active s and belongs to group
        + sum(m, p_msAnnuityWeight(m, s)) // Sample weighting to calculate annual emissions
        * [
            // capacity emissions: fixed o&M emissions (tEmission)
            + sum(gnu(grid, node, unit)${p_gnuEmission(grid, node, unit, emission, 'fomEmissions')
                                         and us(unit, s) // consider unit only if it is active in the sample
                                         and gnGroup(grid, node, group) },
                + p_gnuEmission(grid, node, unit, emission, 'fomEmissions')       // (tEmissions/MW)
                    * p_gnu(grid, node, unit, 'unitSize')   // (MW/unit)
                    * [
                        // Existing capacity
                        + p_unit(unit, 'unitCount')         // (number of existing units)

                        // Investments to new capacity
                        + v_invest_LP(unit)${unit_investLP(unit)}        // (number of invested units)
                        + v_invest_MIP(unit)${unit_investMIP(unit)}      // (number of invested units)
                      ] // END * p_gnuEmssion
                ) // END sum(gnu)

            // capacity emissions: investment emissions (tEmission)
            + sum(gnu(grid, node, unit_invest(unit))${p_gnuEmission(grid, node, unit, emission, 'invEmissions')
                                                      and us(unit, s) // consider unit only if it is active in the sample
                                                      and gnGroup(grid, node, group) },
                // Capacity restriction
                + p_gnuEmission(grid, node, unit, emission, 'invEmissions')    // (tEmission/MW)
                    * p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor')    // factor dividing emissions to N years
                    * p_gnu(grid, node, unit, 'unitSize')     // (MW/unit)
                    * [
                        // Investments to new capacity
                        + v_invest_LP(unit)${unit_investLP(unit)}         // (number of invested units)
                        + v_invest_MIP(unit)${unit_investMIP(unit)}       // (number of invested units)
                      ] // END * p_gnuEmssion
                ) // END sum(gnu)
          ] // END * p_msAnnuityWeight
      ) // END sum(s_active)


    =L=

    // Permitted nodal emission cap
    + p_groupPolicyEmission(group, 'emissionCap', emission)
;

*--- Limited Energy -----------------------------------------------------------
* Limited energy production or consumption from particular grid-node-units over
* particular samples. Both production and consumption units to be considered in
* the constraint are defined in gnuGroup. Samples are defined in sGroup.

q_energyLimit(group, min_max)
    ${  (sameas(min_max, 'max') and p_groupPolicy(group, 'energyMax'))
        or (sameas(min_max, 'min') and p_groupPolicy(group, 'energyMin'))
        } ..

  [
    + sum(sft(s, f, t)${sGroup(s, group)},
        + p_sft_Probability(s, f, t)
            * p_stepLength(t)
            * [
                // Production of units in the group
                + sum(gnu_output(grid, node, unit)${    gnuGroup(grid, node, unit, group)
                                                        and usft(unit, s, f, t)
                                                        },
                    + v_gen(grid, node, unit, s, f, t)
                    ) // END sum(gnu)
                // Consumption of units in the group
                + sum(gnu_input(grid, node, unit)${    gnuGroup(grid, node, unit, group)
                                                       and usft(unit, s, f, t)
                                                       },
                    - v_gen(grid, node, unit, s, f, t)
                    ) // END sum(gnu)
                ] // END * p_stepLength
        ) // END sum(sft)
        - [
            + p_groupPolicy(group, 'energyMax')$sameas(min_max, 'max')
            + p_groupPolicy(group, 'energyMin')$sameas(min_max, 'min')
            ]
    ] // END [sum(sft) - p_groupPolicy]
    * [
        // Convert to greater than constraint for 'min' case
        + 1$sameas(min_max, 'max')
        - 1$sameas(min_max, 'min')
        ]  // END * [sum(sft) - p_groupPolicy]

    =L=

    0
;

*--- Limited Energy Share -----------------------------------------------------
* Limited share of energy production from particular grid-node-units over
* particular samples and based on consumption calculated from influx in
* particular grid-nodes plus consumption of particular grid-node-units. Both
* production and consumption units to be considered in the constraint are
* defined in gnuGroup. Samples are defined in sGroup and influx nodes in
* gnGroup.

q_energyShareLimit(group, min_max)
    ${  (sameas(min_max, 'max') and p_groupPolicy(group, 'energyShareMax'))
        or (sameas(min_max, 'min') and p_groupPolicy(group, 'energyShareMin'))
        } ..

    + sum(sft( s, f, t)${sGroup(s, group)},
        + p_sft_Probability(s, f, t)
            * p_stepLength(t)
            * [
                // Generation of units in the group
                + sum(gnu_output(grid, node, unit)${    gnuGroup(grid, node, unit, group)
                                                        and usft(unit, s, f, t)
                                                        },
                    + v_gen(grid, node, unit, s, f, t) // production is taken into account if the grid-node-unit is in gnuGroup
                    ) // END sum(gnu)

                // External power inflow/outflow and consumption of units times the share limit
                - [
                    + p_groupPolicy(group, 'energyShareMax')$sameas(min_max, 'max')
                    + p_groupPolicy(group, 'energyShareMin')$sameas(min_max, 'min')
                    ]
                  * [
                    - sum(gnGroup(grid, node, group),
                        // influx is taken into account if the node is in gnGroup
                        // constant (MWh/h)
                        + p_gn(grid, node, 'influx') $ {gn_influx(grid, node) and not gn_influxTs(grid, node)}
                        // times series (MWh/h)
                        + ts_influx_(grid, node, f, t) $ gn_influxTs(grid, node)
                        ) // END sum(gnGroup)
                    - sum(gnu_input(grid, node, unit)${ gnuGroup(grid, node, unit, group)
                                                        and usft(unit, s, f, t)
                                                        },
                        + v_gen(grid, node, unit, s, f, t) // consumption is taken into account if the grid-node-unit is in gnuGroup
                        ) // END sum(gnu_input)
                    ] // END * p_groupPolicy
                ] // END * p_stepLength
        ) // END sum(sft)
        * [
            // Convert to greater than constraint for 'min' case
            + 1$sameas(min_max, 'max')
            - 1$sameas(min_max, 'min')
            ]  // END * sum(sft)

    =L=

    0
;

*--- Maximum Share of Reserve Provision ---------------------------------------

q_ReserveShareMax(group, restypeDirectionGroup(restype, up_down, group_), sft(s, f, t))
    ${  ord(t) <= t_solveFirst + p_groupReserves(group_, restype, 'reserve_length')
        and not [ restypeReleasedForRealization(restype)
                  and f_realization(f)]
        and p_groupReserves4D(group, restype, up_down, group_, 'ReserveShareMax')
        }..

    // Reserve provision from units in 'group'
    + sum(gnusft(grid, node, unit, s, f, t)${ gnu_resCapable(restype, up_down, grid, node, unit)
                                              and gnuGroup(grid, node, unit, group)
                                              },
        + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                ] // END * v_reserve
        ) // END sum(nuft)

    // Reserve provision from other reserve categories when they can be shared
    + sum((gnusft(grid, node, unit, s, f, t), restype_)${ p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
                                                          and gnuGroup(grid, node, unit, group)
                                                          },
        + v_reserve(restype_, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
            * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
            * [ // Account for reliability of reserves
                + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                    * p_gnuReserves(grid, node, unit, restype_, 'reserveReliability')
                ] // END * v_reserve
        ) // END sum(nuft)

    =L=

    + p_groupReserves4D(group, restype, up_down, group_, 'ReserveShareMax')
        * [
    // Reserve provision by units to the nodes in 'group_'
            + sum(gnusft(grid, node, unit, s, f, t)${ gnu_resCapable(restype, up_down, grid, node, unit)
                                                      and gnGroup(grid, node, group_)
                                                      },
                + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
                    * [ // Account for reliability of reserves
                        + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                        + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                        ] // END * v_reserve
                  ) // END sum(nuft)

    // Reserve provision from other reserve categories when they can be shared
            + sum((gnusft(grid, node, unit, s, f, t), restype_)${ p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
                                                                  and gnGroup(grid, node, group_)
                                                                  },
                + v_reserve(restype_, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype_, f, t), t)
                    * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
                    * [ // Account for reliability of reserves
                        + 1${sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)} // reserveReliability limits the reliability of reserves locked ahead of time.
                        + p_gnuReserves(grid, node, unit, restype, 'reserveReliability')${not sft_realized(s, f+df_reserves(grid, node, restype, f, t), t)}
                            * p_gnuReserves(grid, node, unit, restype_, 'reserveReliability')
                        ] // END * v_reserve
                  ) // END sum(nuft)

    // Reserve provision to 'group_' via transfer links
            + sum(gn2n_directional(grid, node_, node)${ gnGroup(grid, node, group_)
                                                        and not gnGroup(grid, node_, group_)
                                                        and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                        },
                + [1
                    - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    ]
                    * v_resTransferRightward(restype, up_down, grid, node_, node, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node
                ) // END sum(gn2n_directional)
            + sum(gn2n_directional(grid, node, node_)${ gnGroup(grid, node, group_)
                                                        and not gnGroup(grid, node_, group_)
                                                        and restypeDirectionGridNodeNode(restype, up_down, grid, node_, node)
                                                        },
                + [1
                    - p_gnn(grid, node_, node, 'transferLoss')${not gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    - ts_gnn_(grid, node_, node, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'transferLoss')}
                    ]
                    * v_resTransferLeftward(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node_, restype, f, t), t) // Reserves from another node - reduces the need for reserves in the node
                ) // END sum(gn2n_directional)

          ] // END * p_groupPolicy
;


*--- Generic user constraints -------------------------------------------------

// EQ constraint and 'toVariable' type, for each timestep
q_userconstraintEq_eachTimestep(group_uc, sft(s, f, t))
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
        and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
        and [not group_ucSftFiltered(group_uc)
             or [group_ucSftFiltered(group_uc)
                 and sft_groupUc(group_uc, s, f, t)
                 ]
             ]
        } ..

    // Variables
    + sum(gn_state(grid, node) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_state'),
        + v_state(gn_state, s, f+df_central_t(f, t), t)
          * p_userconstraint(group_uc, gn_state, '-', '-', 'v_state')
        ) // END sum(gn_state)

    + sum(gn(grid, node_spill(node)) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill'),
        + v_spill(grid, node, sft)
          * p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill')
        ) // END sum(gn_state)

    + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer'),
        + v_transfer(gn2n_directional, sft)
          * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer')
        ) // END sum(gn2n_directional)

    + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward'),
        + v_transferLeftward(gn2n_directional, sft)
          * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward')
        ) // END sum(gn2n_directional)

    + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward'),
        + v_transferRightward(gn2n_directional, sft)
          * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward')
         ) // END sum(gn2n_directional)

    + sum(gn2n_directional_ramp(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp'),
        + v_transferRamp(gn2n_directional_ramp, sft)
          * p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp')
        ) // END sum(gn2n_directional_ramp)

    + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer'),
        + [v_investTransfer_LP(gn2n_directional, t)
           * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
           ] $ gn2n_directional_investLP(gn2n_directional)
        + [v_investTransfer_MIP(gn2n_directional, t)
           * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
           ] $ gn2n_directional_investMIP(gn2n_directional)
         ) // END sum(gn2n_directional)

    + sum(gnu(grid, node, unit) $ {p_userconstraint(group_uc, gnu, '-', 'v_gen')},
        + v_gen(gnu, sft) $ gnusft(gnu, sft)
          * p_userconstraint(group_uc, gnu, '-', 'v_gen')
        ) // END sum(gnu)

    + sum(gnu_rampUp $ {p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')},
        + v_genRampUp(gnu_rampUp, sft) $ gnusft_ramp(gnu_rampUp, sft)
          * p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')
        ) // END sum(gnu_rampUp)

    + sum(gnu_rampDown $ {p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')},
        + v_genRampDown(gnu_rampDown, sft) $ gnusft_ramp(gnu_rampDown, sft)
          * p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')
        ) // END sum(gnu_rampDown)

    + sum(gnu_delay(grid, node, unit) $ {p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')},
        + v_gen_delay(gnu_delay, sft) $ gnusft(gnu_delay, sft)
          * p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')
        ) // END sum(gnu_delay)

    + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')},
        + v_online_LP(unit, s, f+df_central_t(f, t), t) $ usft_onlineLP(unit, s, f, t)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
        + v_online_MIP(unit, s, f+df_central_t(f, t), t) $ usft_onlineMIP(unit, s, f, t)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
        ) // END sum(unit_online)

    // v_startup if sum of starttypes
    + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')},
        + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
        + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
        ) // END sum(unitStarttype)

    // v_startup if specific starttype
    + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')},
        + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
          * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
        + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
          * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
        ) // END sum(unitStarttype)

    + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')},
        + v_shutdown_LP(unit, s, f, t) $ usft_onlineLP(unit, s, f, t)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
        + v_shutdown_MIP(unit, s, f, t) $ usft_onlineMIP(unit, s, f, t)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
        ) // END sum(unit_online)

    + sum(unit_invest(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')},
        + v_invest_LP(unit) $ unit_investLP(unit)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
        + v_invest_MIP(unit) $ unit_investMIP(unit)
          * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
        ) // END sum(unit_invest)

    + sum(gnu_resCapable(restype, up_down, grid, node, unit) $ {p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')},
        + v_reserve(gnu_resCapable, s, f+df_reserves(grid, node, restype, f, t), t)
          * p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')
        ) // END sum(gnu_resCapable)

    + sum(group_ $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                    and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'EachTimestep'))
                    },
        + [v_userconstraint_LP_t(group_, s, f, t) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
           + v_userconstraint_MIP_t(group_, s, f, t) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
           ]
          * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
        ) // END sum(group_)

    + sum(group_ $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                    and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
                    },
        + [v_userconstraint_LP(group_) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
           + v_userconstraint_MIP(group_) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
           ]
          * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
        ) // END sum(group_)

    =E=

    // Timeseries
    + sum(unit_timeseries(unit, param_unit) $ {p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')},
        + ts_unit_(unit, param_unit, f, t)
          * p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')
        ) // END sum(unit_timeseries)

    + sum(gn_influxTs(grid, node) $ {p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')},
        + ts_influx_(grid, node, f, t)
          * p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')
        ) // END sum(gn_influxTs)

    + sum(flowNode(flow, node) $ {p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')},
        + ts_cf_(flow, node, f, t)
          * p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')
    ) // END sum(flowNode)

    + sum(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)  $ {p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')},
        + ts_node_(grid, node, param_gnBoundaryTypes, f, t)
          * p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')
        ) // END sum(gn_BoundaryType_ts)

    + sum(gn2n_timeseries(grid, node, node_, param_gnn)  $ {p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')},
        + ts_gnn_(grid, node, node_, param_gnn, f, t)
          * p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')
        ) // END sum(gn2n_timeseries)

    + sum(restypeDirectionGroup(restype, up_down, group_)  $ {p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')},
        + ts_reserveDemand_(restype, up_down, group_, f, t)
          * p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')
        ) // END sum(gn2n_timeseries)

    + sum(param_policy $ {p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')},
        + ts_groupPolicy_(group_uc, param_policy, t)
          * p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')
        ) // END sum(param_policy)

    // Constant
    + p_userconstraint(group_uc, '-', '-', '-', '-', 'constant')

    // Storing the equation value to a new variable when toVariable is activated
    + [v_userconstraint_LP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
       + v_userconstraint_MIP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
       ]${p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable') or p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')}
      * p_userconstraint(group_uc, '-', '-', '-', '-', 'toVariableMultiplier')

    // Dummies to ensure feasibility if dummies are active
    + vq_userconstraintInc_t(group_uc, sft)${not dropVqUserconstraint(group_uc, t)}
    - vq_userconstraintDec_t(group_uc, sft)${not dropVqUserconstraint(group_uc, t)}

;


// GT+LT constraints, for each timestep
q_userconstraintGtLt_eachTimestep(group_uc, sft(s, f, t))
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt')
                                                       + p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt')
                                                       )
        and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eachTimestep'))
        and [not group_ucSftFiltered(group_uc)
             or [group_ucSftFiltered(group_uc)
                 and sft_groupUc(group_uc, s, f, t)
                 ]
             ]
        } ..

    // converting =G= to =L= by multiplying LHS and RHS by -1 if lt
    [ +1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt'))
      -1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt'))
      ]
    // Variables
    * [
        + sum(gn_state(grid, node) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_state'),
            + v_state(gn_state, s, f+df_central_t(f, t), t)
              * p_userconstraint(group_uc, gn_state, '-', '-', 'v_state')
            ) // END sum(gn_state)

        + sum(gn(grid, node_spill(node)) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill'),
            + v_spill(grid, node, sft)
              * p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill')
            ) // END sum(gn_state)

        + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer'),
            + v_transfer(gn2n_directional, sft)
              * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer')
            ) // END sum(gn2n_directional)

        + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward'),
            + v_transferLeftward(gn2n_directional, sft)
              * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward')
            ) // END sum(gn2n_directional)

        + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward'),
            + v_transferRightward(gn2n_directional, sft)
              * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward')
             ) // END sum(gn2n_directional)

        + sum(gn2n_directional_ramp(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp'),
            + v_transferRamp(gn2n_directional_ramp, sft)
              * p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp')
            ) // END sum(gn2n_directional_ramp)

        + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer'),
            + [v_investTransfer_LP(gn2n_directional, t)
               * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
               ] $ gn2n_directional_investLP(gn2n_directional)
            + [v_investTransfer_MIP(gn2n_directional, t)
               * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
               ] $ gn2n_directional_investMIP(gn2n_directional)
            ) // END sum(gn2n_directional)

        + sum(gnu(grid, node, unit) $ {p_userconstraint(group_uc, gnu, '-', 'v_gen')},
            + v_gen(gnu, sft) $ gnusft(gnu, sft)
              * p_userconstraint(group_uc, gnu, '-', 'v_gen')
            ) // END sum(gnu)

        + sum(gnu_rampUp $ {p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')},
            + v_genRampUp(gnu_rampUp, sft) $ gnusft_ramp(gnu_rampUp, sft)
              * p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')
            ) // END sum(gnu_rampUp)

        + sum(gnu_rampDown $ {p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')},
            + v_genRampDown(gnu_rampDown, sft) $ gnusft(gnu_rampDown, sft)
              * p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')
            ) // END sum(gnu_rampDown)

        + sum(gnu_delay(grid, node, unit) $ {p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')},
            + v_gen_delay(gnu_delay, sft) $ gnusft(gnu_delay, sft)
              * p_userconstraint(group_uc, gnu_delay, '-', 'v_gen')
            ) // END sum(gnu_delay)

        + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')},
            + v_online_LP(unit, s, f+df_central_t(f, t), t) $ usft_onlineLP(unit, s, f, t)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
            + v_online_MIP(unit, s, f+df_central_t(f, t), t) $ usft_onlineMIP(unit, s, f, t)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
            ) // END sum(unit_online)

        // v_startup if sum of starttypes
        + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')},
            + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
            + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
            ) // END sum(unitStarttype)

        // v_startup if specific starttype
        + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')},
            + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
              * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
            + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
              * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
            ) // END sum(unitStarttype)

        + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')},
            + v_shutdown_LP(unit, s, f, t) $ usft_onlineLP(unit, s, f, t)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
            + v_shutdown_MIP(unit, s, f, t) $ usft_onlineMIP(unit, s, f, t)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
            ) // END sum(unit_online)

        + sum(unit_invest(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')},
            + v_invest_LP(unit) $ unit_investLP(unit)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
            + v_invest_MIP(unit) $ unit_investMIP(unit)
              * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
            ) // END sum(unit_invest)

        + sum(gnu_resCapable(restype, up_down, grid, node, unit) $ {p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')},
            + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
              * p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')
            ) // END sum(gnu)

        + sum(group_ $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')},
            + [v_userconstraint_LP_t(group_, s, f, t) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP_t(group_, s, f, t) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
               ]
              * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
            ) // END sum(group_)

        + sum(group_ $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                        and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
                        },
            + [v_userconstraint_LP(group_) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP(group_) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
               ]
              * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
            ) // END sum(group_)

      ] // End converting =G= to =L=

    =G=

    // converting =G= to =L= by multiplying LHS and RHS by -1 if lt
    [ +1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt'))
      -1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt'))
      ]
    // Timeseries
    * [
        + sum(unit_timeseries(unit, param_unit) $ {p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')},
            + ts_unit_(unit, param_unit, f, t)
              * p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')
            ) // END sum(unit_timeseries)

        + sum(gn_influxTs(grid, node) $ {p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')},
            + ts_influx_(grid, node, f, t)
              * p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')
            ) // END sum(gn_influxTs)

        + sum(flowNode(flow, node) $ {p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')},
            + ts_cf_(flow, node, f, t)
              * p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')
            ) // END sum(flowNode)

        + sum(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)  $ {p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')},
            + ts_node_(grid, node, param_gnBoundaryTypes, f, t)
              * p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')
            ) // END sum(gn_BoundaryType_ts)

        + sum(gn2n_timeseries(grid, node, node_, param_gnn)  $ {p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')},
            + ts_gnn_(grid, node, node_, param_gnn, f, t)
              * p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')
            ) // END sum(gn2n_timeseries)

        + sum(restypeDirectionGroup(restype, up_down, group_)  $ {p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')},
            + ts_reserveDemand_(restype, up_down, group_, f, t)
              * p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')
            ) // END sum(gn2n_timeseries)

        + sum(param_policy $ {p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')},
            + ts_groupPolicy_(group_uc, param_policy, t)
              * p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')
            ) // END sum(param_policy)

        // Constant
        + p_userconstraint(group_uc, '-', '-', '-', '-', 'constant')

        // Giving model an option to store the equation value to a new variable when toVariable is activated. Needs to be used carefully with GT and LT.
        + [v_userconstraint_LP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
           + v_userconstraint_MIP_t(group_uc, s, f, t) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
           ]${p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable') or p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')}
          * p_userconstraint(group_uc, '-', '-', '-', '-', 'toVariableMultiplier')

        ] // End converting =G= to =L=

     // Dummies to ensure feasibility. vq_userconstraintDec for both gt and lt as the equation type is =G=
    - vq_userconstraintDec_t(group_uc, sft)${not dropVqUserconstraint(group_uc, t) }
;


// EQ constraint and 'toVariable' type, sum of timesteps
q_userconstraintEq_sumOfTimesteps(group_uc)
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))
        and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
        } ..

    // sum of all included sft
    + sum(sft(s, f, t)${not group_ucSftFiltered(group_uc)
                        or [group_ucSftFiltered(group_uc)
                            and sft_groupUc(group_uc, s, f, t)
                            ]
                        },
        // timestep probability and steplength
        + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
        // Variables
        * [
            + sum(gn_state(grid, node) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_state'),
                + v_state(gn_state, s, f+df_central_t(f, t), t)
                  * p_userconstraint(group_uc, gn_state, '-', '-', 'v_state')
                ) // END sum(gn_state)

            + sum(gn(grid, node_spill(node)) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill'),
                + v_spill(grid, node, sft)
                  * p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gn_state)

            + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer'),
                + v_transfer(gn2n_directional, sft)
                  * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gn2n_directional)

            + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward'),
                + v_transferLeftward(gn2n_directional, sft)
                  * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gn2n_directional)

            + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward'),
                + v_transferRightward(gn2n_directional, sft)
                  * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward')
                  * p_stepLength(t)            // Time step length dependent variable
                 ) // END sum(gn2n_directional)

            + sum(gn2n_directional_ramp(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp'),
                + v_transferRamp(gn2n_directional_ramp, sft)
                  * p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp')
                ) // END sum(gn2n_directional_ramp)

            + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer'),
                + [v_investTransfer_LP(gn2n_directional, t)
                   * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
                   ] $ gn2n_directional_investLP(gn2n_directional)
                + [v_investTransfer_MIP(gn2n_directional, t)
                   * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
                   ] $ gn2n_directional_investMIP(gn2n_directional)
                ) // END sum(gn2n_directional)

            + sum(gnu(grid, node, unit) $ {p_userconstraint(group_uc, gnu, '-', 'v_gen')},
                + v_gen(gnu, sft) $ gnusft(gnu, sft)
                  * p_userconstraint(group_uc, gnu, '-', 'v_gen')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gnu)

            + sum(gnu_rampUp $ {p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')},
                + v_genRampUp(gnu_rampUp, sft) $ gnusft_ramp(gnu_rampUp, sft)
                  * p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')
                ) // END sum(gnu_rampUp)

            + sum(gnu_rampDown $ {p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')},
                + v_genRampDown(gnu_rampDown, sft) $ gnusft_ramp(gnu_rampDown, sft)
                  * p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')
                ) // END sum(gnu_rampDown)

            + sum(gnu_delay(grid, node, unit) $ {p_userconstraint(group_uc, gnu_delay, '-', 'v_gen')},
                + v_gen_delay(gnu_delay, sft) $ gnusft(gnu_delay, sft)
                  * p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gnu_delay)

            + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')},
                + v_online_LP(unit, s, f+df_central_t(f, t), t) $ usft_onlineLP(unit, s, f, t)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
                + v_online_MIP(unit, s, f+df_central_t(f, t), t) $ usft_onlineMIP(unit, s, f, t)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
                ) // END sum(unit_online)

            // v_startup if sum of starttypes
            + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')},
                + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
                + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
                ) // END sum(unitStarttype)

            // v_startup if specific starttype
            + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')},
                + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                  * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
                + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                  * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
                ) // END sum(unitStarttype)

            + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')},
                + v_shutdown_LP(unit, s, f, t) $ usft_onlineLP(unit, s, f, t)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
                + v_shutdown_MIP(unit, s, f, t) $ usft_onlineMIP(unit, s, f, t)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
                ) // END sum(unit_online)

            + sum(unit_invest(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')},
                + v_invest_LP(unit) $ unit_investLP(unit)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
                + v_invest_MIP(unit) $ unit_investMIP(unit)
                  * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
                ) // END sum(unit_invest)

            + sum(gnu_resCapable(restype, up_down, grid, node, unit) $ {p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')},
                + v_reserve(gnu_resCapable, s, f+df_reserves(grid, node, restype, f, t), t)
                  * p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(gnu_resCapable)

            + sum(group_
                $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                   and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'EachTimestep'))
                   },
                + [v_userconstraint_LP_t(group_, s, f, t) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
                   + v_userconstraint_MIP_t(group_, s, f, t) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
                   ]
                  * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                  * p_stepLength(t)            // Time step length dependent variable
                ) // END sum(group_)
            ] // End variables

        ) // end sum(sft)

    + sum(group_
        $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
           and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
           },
        + [v_userconstraint_LP(group_) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
           + v_userconstraint_MIP(group_) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
           ]
          * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
        ) // END sum(group_)

    =E=

    // sum of all included sft
    + sum(sft(s, f, t)${not group_ucSftFiltered(group_uc)
                        or [group_ucSftFiltered(group_uc)
                            and sft_groupUc(group_uc, s, f, t)
                            ]
                        },

        // timestep probability and steplength
        + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
        // Timeseries
        * [
            + sum(unit_timeseries(unit, param_unit) $ {p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')},
                + ts_unit_(unit, param_unit, f, t)
                  * p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')
                ) // END sum(unit_timeseries)

            + sum(gn_influxTs(grid, node) $ {p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')},
                + ts_influx_(grid, node, f, t)
                  * p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')
                  * p_stepLength(t)            // Time step length dependent parameter
                ) // END sum(gn_influxTs)

            + sum(flowNode(flow, node) $ {p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')},
                + ts_cf_(flow, node, f, t)
                  * p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')
                ) // END sum(flowNode)

            + sum(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)  $ {p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')},
                + ts_node_(grid, node, param_gnBoundaryTypes, f, t)
                  * p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')
                ) // END sum(gn_BoundaryType_ts)

            + sum(gn2n_timeseries(grid, node, node_, param_gnn)  $ {p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')},
                + ts_gnn_(grid, node, node_, param_gnn, f, t)
                  * p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')
                ) // END sum(gn2n_timeseries)

            + sum(restypeDirectionGroup(restype, up_down, group_)  $ {p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')},
                + ts_reserveDemand_(restype, up_down, group_, f, t)
                  * p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')
                  * p_stepLength(t)            // Time step length dependent parameter
                ) // END sum(gn2n_timeseries)

            + sum(param_policy $ {p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')},
                + ts_groupPolicy_(group_uc, param_policy, t)
                  * p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')
                  * p_stepLength(t)            // Time step length dependent parameter
                ) // END sum(param_policy)
            ] // End timeseries

        ) // end sum(sft)

    // Constant
    + p_userconstraint(group_uc, '-', '-', '-', '-', 'constant')

    // Storing the equation value to a variable when type is toVariable
    + [v_userconstraint_LP(group_uc) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
       + v_userconstraint_MIP(group_uc) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
       ]${p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable') or p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')}
       * p_userconstraint(group_uc, '-', '-', '-', '-', 'toVariableMultiplier')

    // Dummies to ensure feasibility when type is eq
    + vq_userconstraintInc(group_uc)${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))}
    - vq_userconstraintDec(group_uc)${sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'eq'))}

;


// GT+LT constraints, sum of timesteps
q_userconstraintGtLt_sumOfTimesteps(group_uc)
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt')
                                                       + p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt')
                                                       )
        and sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
        } ..

    // converting =G= to =L= by multiplying LHS and RHS by -1 if lt
    [ +1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt'))
      -1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt'))
      ]
    * [
        // sum of all included sft
        + sum(sft(s, f, t)${not group_ucSftFiltered(group_uc)
                            or [group_ucSftFiltered(group_uc)
                                and sft_groupUc(group_uc, s, f, t)
                                ]
                            },

            // timestep probability
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            // Variables
            * [
                + sum(gn_state(grid, node) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_state'),
                    + v_state(gn_state, s, f+df_central_t(f, t), t)
                      * p_userconstraint(group_uc, gn_state, '-', '-', 'v_state')
                    ) // END sum(gn_state)

                + sum(gn(grid, node_spill(node)) $ p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill'),
                    + v_spill(grid, node, sft)
                      * p_userconstraint(group_uc, grid, node, '-', '-', 'v_spill')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gn_state)

                + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer'),
                    + v_transfer(gn2n_directional, sft)
                      * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transfer')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gn2n_directional)

                + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward'),
                    + v_transferLeftward(gn2n_directional, sft)
                      * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferLeftward')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gn2n_directional)

                + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward'),
                    + v_transferRightward(gn2n_directional, sft)
                      * p_userconstraint(group_uc, gn2n_directional, '-', 'v_transferRightward')
                      * p_stepLength(t)            // Time step length dependent variable
                     ) // END sum(gn2n_directional)

                + sum(gn2n_directional_ramp(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp'),
                    + v_transferRamp(gn2n_directional_ramp, sft)
                      * p_userconstraint(group_uc, gn2n_directional_ramp, '-', 'v_transferRamp')
                    ) // END sum(gn2n_directional_ramp)

                + sum(gn2n_directional(grid, node, node_) $ p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer'),
                    + [v_investTransfer_LP(gn2n_directional, t)
                       * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
                       ] $ gn2n_directional_investLP(gn2n_directional)
                    + [v_investTransfer_MIP(gn2n_directional, t)
                       * p_userconstraint(group_uc, gn2n_directional, '-', 'v_investTransfer')
                       ] $ gn2n_directional_investMIP(gn2n_directional)
                    ) // END sum(gn2n_directional)

                + sum(gnu(grid, node, unit) $ {p_userconstraint(group_uc, gnu, '-', 'v_gen')},
                    + v_gen(gnu, sft) $ gnusft(gnu, sft)
                      * p_userconstraint(group_uc, gnu, '-', 'v_gen')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gnu)

                + sum(gnu_rampUp $ {p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')},
                    + v_genRampUp(gnu_rampUp, sft) $ gnusft_ramp(gnu_rampUp, sft)
                      * p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp')
                    ) // END sum(gnu_rampUp)

                + sum(gnu_rampDown $ {p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')},
                    + v_genRampDown(gnu_rampDown, sft) $ gnusft_ramp(gnu_rampDown, sft)
                      * p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown')
                    ) // END sum(gnu_rampDown)

                + sum(gnu_delay(grid, node, unit) $ {p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')},
                    + v_gen_delay(gnu_delay, sft) $ gnusft(gnu_delay, sft)
                      * p_userconstraint(group_uc, gnu_delay, '-', 'v_gen_delay')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gnu_delay)

                + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')},
                    + v_online_LP(unit, s, f+df_central_t(f, t), t) $ usft_onlineLP(unit, s, f, t)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
                    + v_online_MIP(unit, s, f+df_central_t(f, t), t) $ usft_onlineMIP(unit, s, f, t)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_online')
                    ) // END sum(unit_online)

                // v_startup if sum of starttypes
                + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')},
                    + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
                    + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_startup')
                    ) // END sum(unitStarttype)

                // v_startup if specific starttype
                + sum(unitStarttype(unit, starttype) $ {p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')},
                    + v_startup_LP(starttype, unit, s, f, t)${ usft_onlineLP(unit, s, f, t) }
                      * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
                    + v_startup_MIP(starttype, unit, s, f, t)${ usft_onlineMIP(unit, s, f, t) }
                      * p_userconstraint(group_uc, unit, starttype, '-', '-', 'v_startup')
                    ) // END sum(unitStarttype)

                + sum(unit_online(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')},
                    + v_shutdown_LP(unit, s, f, t) $ usft_onlineLP(unit, s, f, t)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
                    + v_shutdown_MIP(unit, s, f, t) $ usft_onlineMIP(unit, s, f, t)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_shutdown')
                    ) // END sum(unit_online)

                + sum(unit_invest(unit) $ {p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')},
                    + v_invest_LP(unit) $ unit_investLP(unit)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
                    + v_invest_MIP(unit) $ unit_investMIP(unit)
                      * p_userconstraint(group_uc, unit, '-', '-', '-', 'v_invest')
                    ) // END sum(unit_invest)

                + sum(gnu_resCapable(restype, up_down, grid, node, unit) $ {p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')},
                    + v_reserve(restype, up_down, grid, node, unit, s, f+df_reserves(grid, node, restype, f, t), t)
                      * p_userconstraint(group_uc, restype, up_down, node, unit, 'v_reserve')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(gnu)

                + sum(group_
                    $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                       and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'EachTimestep'))
                       },
                    + [v_userconstraint_LP_t(group_, s, f, t) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
                       + v_userconstraint_MIP_t(group_, s, f, t) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
                       ]
                      * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
                      * p_stepLength(t)            // Time step length dependent variable
                    ) // END sum(group_)
                ] // End variables

            ) // end sum(sft)

        + sum(group_
            $ {p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
               and sum(groupUc1234(group_, uc1, uc2, uc3, uc4), p_userconstraint(group_, uc1, uc2, uc3, uc4, 'sumOfTimesteps'))
               },
            + [v_userconstraint_LP(group_) $ p_userconstraint(group_, 'LP', '-', '-', '-', 'toVariable')
               + v_userconstraint_MIP(group_) $ p_userconstraint(group_, 'MIP', '-', '-', '-', 'toVariable')
               ]
              * p_userconstraint(group_uc, group_, '-', '-', '-', 'v_userconstraint')
            ) // END sum(group_)

        ] // end converting =G= to =L=

    =G=

    // converting =G= to =L= by multiplying LHS and RHS by -1 if lt
    [ +1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'gt'))
      -1 $ sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'lt'))
      ]
    * [
        // sum of all included sft
        + sum(sft(s, f, t)${not group_ucSftFiltered(group_uc)
                        or [group_ucSftFiltered(group_uc)
                            and sft_groupUc(group_uc, s, f, t)
                            ]
                        },

            // timestep probability and steplength
            + p_sft_probability(s, f, t) // Probability (weight coefficient) of (s, f, t)
            // Timeseries
            * [
                + sum(unit_timeseries(unit, param_unit) $ {p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')},
                    + ts_unit_(unit, param_unit, f, t)
                      * p_userconstraint(group_uc, unit, param_unit, '-', '-', 'ts_unit')
                    ) // END sum(unit_timeseries)

                + sum(gn_influxTs(grid, node) $ {p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')},
                    + ts_influx_(grid, node, f, t)
                      * p_userconstraint(group_uc, grid, node, '-', '-', 'ts_influx')
                      * p_stepLength(t)            // Time step length dependent parameter
                    ) // END sum(gn_influxTs)

                + sum(flowNode(flow, node) $ {p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')},
                    + ts_cf_(flow, node, f, t)
                      * p_userconstraint(group_uc, flow, node, '-', '-', 'ts_cf')
                    ) // END sum(flowNode)

                + sum(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)  $ {p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')},
                    + ts_node_(grid, node, param_gnBoundaryTypes, f, t)
                      * p_userconstraint(group_uc, grid, node, param_gnBoundaryTypes, '-', 'ts_node')
                    ) // END sum(gn_BoundaryType_ts)

                + sum(gn2n_timeseries(grid, node, node_, param_gnn)  $ {p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')},
                    + ts_gnn_(grid, node, node_, param_gnn, f, t)
                      * p_userconstraint(group_uc, grid, node, node_, param_gnn, 'ts_gnn')
                    ) // END sum(gn2n_timeseries)

                + sum(restypeDirectionGroup(restype, up_down, group_)  $ {p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')},
                    + ts_reserveDemand_(restype, up_down, group_, f, t)
                      * p_userconstraint(group_uc, restype, up_down, group_, '-', 'ts_reserveDemand')
                      * p_stepLength(t)            // Time step length dependent parameter
                    ) // END sum(gn2n_timeseries)

                + sum(param_policy $ {p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')},
                    + ts_groupPolicy_(group_uc, param_policy, t)
                      * p_userconstraint(group_uc, param_policy, '-', '-', '-', 'ts_groupPolicy')
                      * p_stepLength(t)            // Time step length dependent parameter
                    ) // END sum(param_policy)
                ] // End timeseries

            ) // end sum(sft)

        // Constant
        + p_userconstraint(group_uc, '-', '-', '-', '-', 'constant')

        // Storing the equation value to a variable when type is toVariable
        + [v_userconstraint_LP(group_uc) $ p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable')
           + v_userconstraint_MIP(group_uc) $ p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')
           ]${p_userconstraint(group_uc, 'LP', '-', '-', '-', 'toVariable') or p_userconstraint(group_uc, 'MIP', '-', '-', '-', 'toVariable')}
           * p_userconstraint(group_uc, '-', '-', '-', '-', 'toVariableMultiplier')

        ] // end converting =G= to =L=

    // Dummies to ensure feasibility. vq_userconstraintDec for both gt and lt as the equation type is =G=
    - vq_userconstraintDec(group_uc)
;


* --- nonanticipativity -------------------------------------------------------

// Nonanticipativity constraint for unit v_online by forcing online status
// in different forecast branches to be the same than in central forecast
q_nonanticipativity_online(usft_online(unit, sft(s, f, t_nonanticipativity(t))))
  $ { not f_realization(f)
      and not f_central(f)
      }
  ..

  // v_online in other than central forecast
  + v_online_LP(unit, s, f, t) $ usft_onlineLP(unit, s, f, t)
  + v_online_MIP(unit, s, f, t) $ usft_onlineMIP(unit, s, f, t)

  =E=

  // v_online in central forecast
  + v_online_LP(unit, s, f+df_central(f), t) $ usft_onlineLP(unit, s, f+df_central(f), t)
  + v_online_MIP(unit, s, f+df_central(f), t) $ usft_onlineMIP(unit, s, f+df_central(f), t)

;

// Nonanticipativity constraint for storage v_state by forcing the sum of v_gen, v_transfer,
// and v_spill in different forecast branches to be the same than in central forecast
q_nonanticipativity_state(gn_state(grid, node), sft(s, f, t_nonanticipativity(t)) )
  $ { not f_realization(f)
      and not f_central(f)
      }
  ..

  // sum(v_gen) in other than central forecast
  + sum(gnusft(grid, node, unit, s, f, t),
        + v_gen(grid, node, unit, s, f, t)
        )

  // sum(v_transfer) in other than central forecast
  + sum(gn2nsft_directional(grid, node, node_, s, f, t),
        v_transfer(grid, node, node_, s, f, t)
        )

  // sum(v_spill) in other than central forecast
  + v_spill(grid, node, s, f, t)$node_spill(node)


  =E=

  // sum(v_gen) in central forecast
  + sum(gnusft(grid, node, unit, s, f, t),
        + v_gen(grid, node, unit, s, f+df_central(f), t)
        )

  // sum(v_transfer) in central forecast
  + sum(gn2nsft_directional(grid, node, node_, s, f, t),
        v_transfer(grid, node, node_, s, f+df_central(f), t)
        )

  // sum(v_spill) in central forecast
  + v_spill(grid, node, s, f+df_central(f), t)$node_spill(node)

;



$ifthen.addConstr exist '%input_dir%/additional_constraints.inc'
   $$include '%input_dir%/additional_constraints.inc'
$endif.addConstr
