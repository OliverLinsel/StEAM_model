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
* --- Variable limits ---------------------------------------------------------
*
* =============================================================================


* =============================================================================
* --- Node State Boundaries ---------------------------------------------------
* =============================================================================

* -- upwardLimit and downwardLimit --------------------------------------------

// gnu_tmp for gnu that can increase gn upwardLimit
option clear = gnu_tmp;
gnu_tmp(grid, node, unit)
    $ { not unit_invest(unit)
        and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
        }
    = yes;

// Upper bound, constant
v_state.up(gn_state(grid, node), sft_withStorageStarts(s, f, t))
    ${ // if node has constant upwardLimit
       [p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')
        // or the upwardLimit is expanded by units with upperLimitCapacityRatio
        or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'upperLimitCapacityRatio'))
        ]
       // but not for nodes that have units whose invested capacity limits their state
       and not sum(gnu(grid, node, unit_invest(unit)), p_gnu(grid, node, unit, 'upperLimitCapacityRatio'))
       and not df_central_t(f, t)               // or (f, t) bound to central forecast
       and not node_superpos(node)              // or to superpositioned nodes
       and not gn_stateUpwardSlack(grid, node)  // or to nodes that have upward state slack activated
       }
    = + p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
        * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
      + [sum(gnu_tmp(grid, node, unit),
            + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                * p_gnu(grid, node, unit, 'unitSize')
                * p_unit(unit, 'unitCount')
            ) // END sum(gnu)
         ] $ sum(unit, gnu_tmp(grid, node, unit))
    ;
// Upper Bound, time series
v_state.up(gn_state(grid, node), sft_withStorageStarts(s, f, t))
    ${ p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeSeries')
       // but not for nodes that have units whose invested capacity limits their state
       and not sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'upperLimitCapacityRatio'))
       and not df_central_t(f, t)               // or (f, t) bound to central forecast
       and not node_superpos(node)              // or to superpositioned nodes
       and not gn_stateUpwardSlack(grid, node)  // or to nodes that have upward state slack activated
       }
    = + ts_node_(grid, node, 'upwardLimit', f, t)
        * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
      + [sum(gnu_tmp(grid, node, unit),
            + p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                * p_gnu(grid, node, unit, 'unitSize')
                * p_unit(unit, 'unitCount')
            ) // END sum(gnu)
         ] $ sum(unit, gnu_tmp(grid, node, unit))
       ;

// Lower bound, constant
v_state.lo(gn_state(grid, node), sft_withStorageStarts(s, f, t))
    ${ p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')
       and not df_central_t(f, t)
       and not node_superpos(node)
       and not gn_stateDownwardSlack(grid, node)
       }
       = p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'constant')
          * p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'multiplier');
// Lower bound, time series
v_state.lo(gn_state(grid, node), sft_withStorageStarts(s, f, t))
    ${ p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeSeries')
       and not df_central_t(f, t)
       and not node_superpos(node)
       and not gn_stateDownwardSlack(grid, node)
       }
       = ts_node_(grid, node, 'downwardLimit', f, t)
          * p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'multiplier');

* --- boundAll ----------------------------------------------------------------

// Bounding all t of the current solve if boundAll is enabled
loop(gn_state(grid, node)$p_gn(grid, node, 'boundAll'),
    // Fixed value, constant.  Time series will override when data available.
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundAll')
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
                                           and not df_central_t(f, t)
                                           and not node_superpos(node)
                                           }
        = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
    // Fixed value, time series
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundAll')
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries')
                                           and not df_central_t(f, t)
                                           and not node_superpos(node)
                                           }
        = ts_node_(grid, node, 'reference', f, t)
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
); // END loop(gn_state $ boundAll)

* --- boundEnd ----------------------------------------------------------------

// Bounding the last t of the current solve if boundEnd is enabled
loop(gn_state(grid, node)$p_gn(grid, node, 'boundEnd'),
    // BoundEnd to a constant value.  Time series will override when data available.
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundEnd')
                                           and ft_lastSteps(f, t)
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
                                           and not node_superpos(node)
                                           }
        = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
    // BoundEnd to a time series value
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundEnd')
                                           and ft_lastSteps(f, t)
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries')
                                           and not node_superpos(node)
                                           }
        = ts_node_(grid, node, 'reference', f, t)
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
); // END loop(gn_state $ boundEnd)

* --- boundStartOfSamples, boundEndOfSamples ----------------------------------

// Bounding the time step t-1 for of each sample to reference value if boundStartofSamples is enabled.
loop(gn_state(grid, node)$p_gn(grid, node, 'boundStartOfSamples'),
    // Constant values.
    v_state.fx(grid, node, s_active(s), f+df_noReset(f, t+dt(t)), t+dt(t))
        ${ p_gn(grid, node, 'boundStartOfSamples')
            and st_start(s, t)
            and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
            and not node_superpos(node)
            }
        = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
    // Time series
    v_state.fx(grid, node, s_active(s),  f+df_noReset(f, t+dt(t)), t+dt(t))
        ${ p_gn(grid, node, 'boundStartOfSamples')
            and st_start(s, t)
            and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries')
            and not node_superpos(node)
            }
        // calculating value as an average of included time steps in an aggregated timestep
        = ts_node_(grid, node, 'reference', f+df_noReset(f, t+dt(t)), t+dt(t))
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
); // END loop(gn_state $ boundStartOfSamples)

// Bounding the end time step of each sample to reference value if boundEndofSamples and constant reference values are enabled.
loop(gn_state(grid, node)$p_gn(grid, node, 'boundEndOfSamples'),
    // Time series will override when data available.
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundEndOfSamples')
                                           and sum(tt_agg_circular(t, t_, t__),  st_end(s, t_) )
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
                                           and not node_superpos(node)
                                           }
        = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
    // Bounding the end time step of each sample to reference value if boundEndofSamples and time series are enabled
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundEndOfSamples')
                                           and sum(tt_agg_circular(t, t_, t__),  st_end(s, t_) )
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries')
                                           and not node_superpos(node)
                                           }
        // calculating value as an average of included time steps in an aggregated timestep
        = ts_node_(grid, node, 'reference', f, t)
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
); // END loop(gn_state $ boundEndOfSamples)

* --- boundStartToEnd ---------------------------------------------------------

loop(gn_state(grid, node)$p_gn(grid, node, 'boundStartToEnd'),
    // BoundStartToEnd: bound the last interval in the horizon to the value just before the horizon if not the first solve
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundStartToEnd')
                                           and ft_lastSteps(f, t)
                                           and (solveCount > 1)
                                           and not node_superpos(node)
                                           }
        = sum(mf_realization(mSolve, f_),
            + r_state_gnft(grid, node, f_, t_solve)
            ) // END sum(mf_realization)
            ;
    if((solveCount = 1),
        // BoundStartToEnd: bound the last interval in the horizon to the reference value if first solve and constant reference. Time series will override when data available.
        v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundStartToEnd')
                                               and ft_lastSteps(f, t)
                                               and p_gn(grid, node, 'boundStart')
                                               and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
                                               and not node_superpos(node)
                                               }
            = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
                * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
        // BoundStartToEnd: bound the last interval in the horizon to the reference value if first solve and time series reference
        v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundStartToEnd')
                                               and ft_lastSteps(f, t)
                                               and p_gn(grid, node, 'boundStart')
                                               and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries') // !!! NOTE !!! The check fails if value is zero
                                               and not node_superpos(node)
                                               }
            // note: ts_node_ doesn't contain initial values so using raw data instead.
            // note: must use df_realization(f) when using the raw data from ts_node
            = ts_node(grid, node, 'reference', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t)
                * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
    ); // END if(solveCount = 1)
); // END loop(gn_state $ boundStartToEnd)

* --- boundSumOverInterval ----------------------------------------------------

loop(gn_state(grid, node)$p_gn(grid, node, 'boundSumOverInterval'),
    // BoundSumOverInterval: bound the interval to the (sum of) reference value if value exists and time series reference
    // note: ts_node_ averages values so using raw data instead.
    // note: must use df_realization(f) when using the raw data from ts_node
    v_state.fx(grid, node, sft(s, f, t))${ p_gn(grid, node, 'boundSumOverInterval')
                                           and sum(tt_agg_circular(t, t_, t__), ts_node(grid, node, 'reference', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_))
                                           and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries') // !!! NOTE !!! The check fails if value is zero
                                           and not node_superpos(node)
                                           }
        = sum(tt_agg_circular(t, t_, t__), ts_node(grid, node, 'reference', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_))
            * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
); // END loop(gn_state $ boundSumOverInterval)


* =============================================================================
* --- Node StateSlack Boundaries ----------------------------------------------
* =============================================================================

// state slack upper limit, constant
v_stateSlack.up(Slack, gn_stateSlack(grid, node), sft(s, f, t))
    $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
        }
    = + p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
         * p_gnBoundaryPropertiesForStates(grid, node, slack, 'multiplier')
;

// state slack upper limit, timeseries
v_stateSlack.up(slack, gn_stateSlack(grid, node), sft(s, f, t))
    $ { p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
        }
    = + ts_node_(grid, node, slack, f, t)
         * p_gnBoundaryPropertiesForStates(grid, node, slack, 'multiplier')
      ;


* =============================================================================
* --- Node State Boundaries, superposed nodes ---------------------------------
* =============================================================================

// Note that boundstart is handled further below; boundend, upwardLimit and downwardLimit are handled as equations
loop(node_superpos(node),

    // v_state for superpositioned states represents the intra-period state. It always starts from zero.
    loop(st_start(s, t),
        v_state.fx(gn_state(grid, node), s, f_active, t+dt(t)) = 0;
    );

    //add here other desired bounds for v_state_z
);


* =============================================================================
* --- Spilling of energy from the nodes----------------------------------------
* =============================================================================

// Max. & min. spilling, use constant value as base and overwrite with time series if desired
v_spill.lo(gn(grid, node_spill), sft(s, f, t))${    p_gnBoundaryPropertiesForStates(grid, node_spill, 'minSpill', 'constant')   }
    = p_gnBoundaryPropertiesForStates(grid, node_spill, 'minSpill', 'constant')
        * p_gnBoundaryPropertiesForStates(grid, node_spill, 'minSpill', 'multiplier');
v_spill.lo(gn(grid, node_spill), sft(s, f, t))${    p_gnBoundaryPropertiesForStates(grid, node_spill, 'minSpill', 'useTimeSeries') }
    = ts_node_(grid, node_spill, 'minSpill', f, t)
        * p_gnBoundaryPropertiesForStates(grid, node_spill, 'minSpill', 'multiplier');
v_spill.up(gn(grid, node_spill), sft(s, f, t))${    p_gnBoundaryPropertiesForStates(grid, node_spill, 'maxSpill', 'constant') }
    = p_gnBoundaryPropertiesForStates(grid, node_spill, 'maxSpill', 'constant')
        * p_gnBoundaryPropertiesForStates(grid, node_spill, 'maxSpill', 'multiplier');
v_spill.up(gn(grid, node_spill), sft(s, f, t))${    p_gnBoundaryPropertiesForStates(grid, node_spill, 'maxSpill', 'useTimeSeries')    }
    = ts_node_(grid, node_spill, 'maxSpill', f, t)
        * p_gnBoundaryPropertiesForStates(grid, node_spill, 'maxSpill', 'multiplier');

* =============================================================================
* --- Unit Related Variable Boundaries ----------------------------------------
* =============================================================================

* --- v_gen -------------------------------------------------------------------

// Constant max. energy generation if investments disabled
v_gen.up(gnusft(gnu_output(grid, node, unit), s, f, t))${not unit_flow(unit)
                                                         and not unit_invest(unit)
                                                         and p_gnu(grid, node, unit, 'capacity')
                                                         }
    = p_gnu(grid, node, unit, 'capacity')
        * [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
;

// Time series capacity factor based max. energy generation if investments disabled
v_gen.up(gnusft(gnu_output(grid, node, unit_flow), s, f, t))${ not unit_invest(unit_flow) }
    = sum(flow${    flowUnit(flow, unit_flow)
                    and nu(node, unit_flow)
                    },
        + ts_cf_(flow, node, f, t)
            * p_gnu(grid, node, unit_flow, 'capacity')
            * [
                + p_unit(unit_flow, 'availability')${not p_unit(unit_flow, 'useTimeseriesAvailability')}
                + ts_unit_(unit_flow, 'availability', f, t)${p_unit(unit_flow, 'useTimeseriesAvailability')}
                ]
      ) // END sum(flow)
;

// Maximum generation to zero for input nodes
v_gen.up(gnusft(gnu_input(grid, node, unit), s, f, t)) = 0;

// Min. generation to zero for output nodes
v_gen.lo(gnusft(gnu_output(grid, node, unit), s, f, t)) = 0;

// Constant max. consumption capacity if investments disabled
v_gen.lo(gnusft(gnu_input(grid, node, unit), s, f, t))${ not unit_flow(unit)
                                                         and not unit_invest(unit)
                                                         and p_gnu(grid, node, unit, 'capacity') }
    = - p_gnu(grid, node, unit, 'capacity')
        * [
            + p_unit(unit, 'availability')${not p_unit(unit, 'useTimeseriesAvailability')}
            + ts_unit_(unit, 'availability', f, t)${p_unit(unit, 'useTimeseriesAvailability')}
            ]
;

// Constant max. consumption capacity if investments disabled and no capacity in input data
v_gen.lo(gnusft(gnu_input(grid, node, unit), s, f, t))${ not unit_flow(unit)
                                                         and not unit_invest(unit)
                                                         and not p_gnu(grid, node, unit, 'capacity')}
    = - inf
;

// Time series capacity factor based max. consumption if investments disabled
v_gen.lo(gnusft(gnu_input(grid, node, unit_flow), s, f, t))${not (unit_investLP(unit_flow) or unit_investMIP(unit_flow))}
    = - sum(flow${  flowUnit(flow, unit_flow)
                    and nu(node, unit_flow)
                    },
          + ts_cf_(flow, node, f, t)
            * p_gnu(grid, node, unit_flow, 'capacity')
            * [
                + p_unit(unit_flow, 'availability')${not p_unit(unit_flow, 'useTimeseriesAvailability')}
                + ts_unit_(unit_flow, 'availability', f, t)${p_unit(unit_flow, 'useTimeseriesAvailability')}
                ]
      ) // END sum(flow)
;

// Max output is zero if the unit is sink
v_gen.up(gnusft(gnu_output(grid, node, unit_sink(unit)), s, f, t)) = 0;
// Max input is zero if the unit is source
v_gen.up(gnusft(gnu_input(grid, node, unit_source(unit)), s, f, t)) = 0;


// In the case of negative generation (currently only used for cooling equipment)
v_gen.lo(gnusft(gnu_output(grid, node, unit), s, f, t))${p_gnu(grid, node, unit, 'conversionCoeff') < 0   }
    = -p_gnu(grid, node, unit, 'capacity')
;
v_gen.up(gnusft(gnu_output(grid, node, unit), s, f, t))${p_gnu(grid, node, unit, 'conversionCoeff') < 0}
    = 0
;


* --- v_genRampUp, v_genRampDown ----------------------------------------------

// for the first solve, filtering st_start away from ramp equations
option clear = sft_tmp;
if(solveCount = 1,
    sft_tmp(sft(s, f, t)) $ { not st_start(s, t)} = yes;
// otherwise use sft
else
    option sft_tmp < sft;
); // END if

// Units without investment possibility, online variable, or possibility to provide reserves
v_genRampUp.up(gnusft_ramp(gnu_rampUp(grid, node, unit), sft_tmp(s, f, t) ))
    ${ p_gnu(grid, node, unit, 'maxRampUp')
       and not sum(restype, gnu_resCapable(restype, 'up', grid, node, unit))
       and not usft_online(unit, s, f, t)
       and not unit_invest(unit)
       }
 // Unit conversion from [p.u./min] to [MW/h]
 = p_gnu(grid, node, unit, 'capacity')
       * p_gnu(grid, node, unit, 'maxRampUp')
       * 60;
v_genRampDown.up(gnusft_ramp(gnu_rampDown(grid, node, unit), sft_tmp(s, f, t) ))
    ${ p_gnu(grid, node, unit, 'maxRampDown')
       and not sum(restype, gnu_resCapable(restype, 'down', grid, node, unit))
       and not usft_online(unit, s, f, t)
       and not unit_invest(unit)
       }
 // Unit conversion from [p.u./min] to [MW/h]
 = p_gnu(grid, node, unit, 'capacity')
       * p_gnu(grid, node, unit, 'maxRampDown')
       * 60;


* --- v_gen_delay -------------------------------------------------------------

// filtering (t, t_) that are in map_delay_gnutt
option t_t < map_delay_gnutt;

// v_gen_delay is zero if t_ is not in map_delay
v_gen_delay.up(gnu_delay(grid, node, unit),  sft(s, f, t_))
    $ { not sum(t_t(t, t_), map_delay_gnutt(grid, node, unit, t, t_)) }
    = 0;

* --- v_online, v_startup, v_shutdown -----------------------------------------

// v_online cannot exceed unit count if investments disabled
// LP variant
v_online_LP.up(usft_onlineLP(unit, s, f, t))${not unit_invest(unit) }
    = p_unit(unit, 'unitCount')
;
// MIP variant
v_online_MIP.up(usft_onlineMIP(unit, s, f, t))${not unit_invest(unit) }
    = p_unit(unit, 'unitCount')
;

// v_startup cannot exceed unitCount
v_startup_LP.up(starttype, usft_onlineLP(unit, s, f, t))
    ${  unitStarttype(unit, starttype)
        and not unit_invest(unit)
        }
    = p_unit(unit, 'unitCount');
v_startup_MIP.up(starttype, usft_onlineMIP(unit, s, f, t))
    ${  unitStarttype(unit, starttype)
        and not unit_invest(unit)
        }
    = p_unit(unit, 'unitCount');

// v_startup (hot/warm) is zero if previous stepLength is longer than controlled by startWarmAfterXhours/startColdAfterXhours
// note: The following limit the size of q_startuptype and thus have similar if conditions to that.
// v_startup_XX.up above handle also cold start and thus have different if criteria
v_startup_LP.up(starttypeConstrained(starttype), usft_onlineLP(unit, s, f, t))
    ${  unitStarttype(unit, starttype)
        and dt_starttypeUnit(starttype, unit) <= -dt(t)
        }
    = 0;
v_startup_MIP.up(starttypeConstrained(starttype), usft_onlineMIP(unit, s, f, t))
    ${  unitStarttype(unit, starttype)
        and dt_starttypeUnit(starttype, unit) <= -dt(t)
        }
    = 0;

// v_shutdown cannot exceed unitCount
v_shutdown_LP.up(usft_onlineLP(unit, s, f, t))
    ${  not unit_invest(unit)}
    = p_unit(unit, 'unitCount');
// v_shutdown cannot exceed unitCount
v_shutdown_MIP.up(usft_onlineMIP(unit, s, f, t))
    ${  not unit_invest(unit)}
    = p_unit(unit, 'unitCount');

//These might speed up, but they should be applied only to the new part of the horizon (should be explored)
*v_startup.l(unitStarttype(unit, starttype), f, t)${usft_online(unit, s, f, t) and  not unit_investLP(unit) } = 0;
*v_shutdown.l(unit, f, t)${sum(starttype, unitStarttype(unit, starttype)) and usft_online(unit, s, f, t) and  not unit_investLP(unit) } = 0;

*----------------------------------------------------------------------IC RAMP-------------------------------------------------------------------------------------------------------------------------------------
v_transferRamp.up(gn2nsft_directional_ramp(grid, node, node_, s, f, t))
  $ {p_gnn(grid, node, node_, 'rampLimit')
     and not p_gnn(grid, node, node_, 'transferCapInvLimit')
     and not p_gnn(grid, node_, node, 'transferCapInvLimit')
     }

 = +p_gnn(grid, node, node_, 'transferCap')
       * p_gnn(grid, node, node_, 'rampLimit')
       * [
           + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
           + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
         ]
       * 60; // Unit conversion from [p.u./min] to [MW/h]

v_transferRamp.lo(gn2nsft_directional_ramp(grid, node, node_, s, f, t))
  $ {p_gnn(grid, node, node_, 'rampLimit')
     and not p_gnn(grid, node, node_, 'transferCapInvLimit')
     and not p_gnn(grid, node_, node, 'transferCapInvLimit')
     }
 = -p_gnn(grid, node, node_, 'transferCap')
       * p_gnn(grid, node, node_, 'rampLimit')
       * [
           + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
           + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
         ]
       * 60; // Unit conversion from [p.u./min] to [MW/h]

*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


* --- Energy Transfer Boundaries ----------------------------------------------

// Restrictions on transferring energy between nodes without investments
// Total transfer variable restricted from both above and below (free variable)
v_transfer.up(gn2nsft_directional(grid, node, node_, s, f, t))${  not p_gnn(grid, node, node_, 'transferCapInvLimit') }
    = [
        + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
        + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
        ]
        * p_gnn(grid, node, node_, 'transferCap')
;
v_transfer.lo(gn2nsft_directional(grid, node, node_, s, f, t))${  not p_gnn(grid, node, node_, 'transferCapInvLimit') }
    = [
        - p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
        - ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
        ]
        * p_gnn(grid, node_, node, 'transferCap')
;
// Directional transfer variables only restricted from above (positive variables)
v_transferRightward.up(gn2nsft_directional(grid, node, node_, s, f, t))${ not p_gnn(grid, node, node_, 'transferCapInvLimit') }
    = [
        + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
        + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
        ]
        * p_gnn(grid, node, node_, 'transferCap')
;
v_transferLeftward.up(gn2nsft_directional(grid, node, node_, s, f, t))${  not p_gnn(grid, node, node_, 'transferCapInvLimit') }
    = [
        + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
        + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
        ]
        * p_gnn(grid, node_, node, 'transferCap')
;

* --- Reserve Provision Boundaries --------------------------------------------

// Loop over the forecasts to minimize confusion regarding the df_reserves forecast displacement
loop((restypeDirectionGridNode(restype, up_down, grid, node), sft(s, f, t))${ ord(t) <= t_solveFirst + p_gnReserves(grid, node, restype, 'reserve_length') },
    // Reserve provision limits without investments
    // Reserve provision limits based on resXX_range (or possibly available generation in case of unit_flow)
    v_reserve.up(gnu_resCapable(restype, up_down, grid, node, unit), s, f+df_reserves(grid, node, restype, f, t), t)
        ${  gnusft(grid, node, unit, s, f, t) // gnusft is not displaced by df_reserves, as the unit exists on normal ft.
            and not (unit_investLP(unit) or unit_investMIP(unit))
            and not sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                        ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                        )
            }
        = min ( p_gnuReserves(grid, node, unit, restype, up_down) * p_gnu(grid, node, unit, 'capacity'),  // Res_range limit
                v_gen.up(grid, node, unit, s, f, t) - v_gen.lo(grid, node, unit, s, f, t) // Generator + consuming unit available unit_elec. output delta
                )${not gnu_offlineResCapable(restype, grid, node, unit)} // END min
            + p_gnuReserves(grid, node, unit, restype, up_down)${gnu_offlineResCapable(restype, grid, node, unit)}
              * p_gnu(grid, node, unit, 'capacity')
    ;

    // Reserve transfer upper bounds based on input p_nnReserves data, if investments are disabled
    v_resTransferRightward.up(restypeDirectionGridNodeNode(restype, up_down, grid, node, node_), s, f+df_reserves(grid, node, restype, f, t), t)
        ${  not p_gnn(grid, node, node_, 'transferCapInvLimit')
            and gn2n_directional(grid, node, node_)
            and not [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                            ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                            )  // This set contains the combination of reserve types and time intervals that should be fixed
                        or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                           ft_reservesFixed(group, restype, f+df_reserves(grid, node_, restype, f, t), t)
                           ) // Commit reserve transfer as long as either end commits.
                        ]
            }
        = [
            + p_gnn(grid, node, node_, 'availability')${not gn2n_timeseries(grid, node, node_, 'availability')}
            + ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'availability')}
            ]
            * p_gnn(grid, node, node_, 'transferCap')
            * p_gnnReserves(grid, node, node_, restype, up_down);

    v_resTransferLeftward.up(restypeDirectionGridNodeNode(restype, up_down, grid, node, node_), s, f+df_reserves(grid, node, restype, f, t), t)
        ${  not p_gnn(grid, node, node_, 'transferCapInvLimit')
            and gn2n_directional(grid, node, node_)
            and not [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                            ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                            )  // This set contains the combination of reserve types and time intervals that should be fixed
                        or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                               ft_reservesFixed(group, restype, f+df_reserves(grid, node_, restype, f, t), t)
                               ) // Commit reserve transfer as long as either end commits.
                        ]
            }
        = [
            + p_gnn(grid, node_, node, 'availability')${not gn2n_timeseries(grid, node_, node, 'availability')}
            + ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node_, node, 'availability')}
            ]
            * p_gnn(grid, node_, node, 'transferCap')
            * p_gnnReserves(grid, node_, node, restype, up_down);

    // Fix non-flow unit reserves at the gate closure of reserves
    v_reserve.fx(gnu_resCapable(restype, up_down, grid, node, unit), s, f+df_reserves(grid, node, restype, f, t), t)
        $ { sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                )  // This set contains the combination of reserve types and time intervals that should be fixed based on previous solves
            and not unit_flow(unit) // NOTE! Units using flows can change their reserve (they might not have as much available in real time as they had bid)
            }
      = r_reserve_gnuft(restype, up_down, grid, node, unit, f+df_reserves(grid, node, restype, f, t), t);

    // Fix reserve provision to reserve markets at the gate closure of reserves
    v_resToMarkets.fx(restype, up_down, group, s, f+df_reserves(grid, node, restype, f, t), t)
        $ { ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t) }  // This set contains the combination of reserve types and time intervals that should be fixed
      = r_reserveMarkets_ft(restype, up_down, group, f+df_reservesGroup(group, restype, f, t), t);

    // Fix transfer of reserves at the gate closure of reserves, LOWER BOUND ONLY!
    v_resTransferRightward.fx(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        $ { gn2n_directional(grid, node, node_)
            and [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                        ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                        )  // This set contains the combination of reserve types and time intervals that should be fixed
                    or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                           ft_reservesFixed(group, restype, f+df_reserves(grid, node_, restype, f, t), t)
                           ) // Commit reserve transfer as long as either end commits.
                    ]
          }
      = r_reserveTransferRightward_gnnft(restype, up_down, grid, node, node_, f+df_reserves(grid, node, restype, f, t), t);

    v_resTransferLeftward.fx(restype, up_down, grid, node, node_, s, f+df_reserves(grid, node, restype, f, t), t)
        $ { gn2n_directional(grid, node, node_)
            and [   sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group),
                        ft_reservesFixed(group, restype, f+df_reserves(grid, node, restype, f, t), t)
                        )  // This set contains the combination of reserve types and time intervals that should be fixed
                    or sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node_, group),
                           ft_reservesFixed(group, restype, f+df_reserves(grid, node_, restype, f, t), t)
                           ) // Commit reserve transfer as long as either end commits.
                    ]
          }
      = r_reserveTransferLeftward_gnnft(restype, up_down, grid, node, node_, f+df_reserves(grid, node, restype, f, t), t);

    // Fix slack variable for reserves that is used before the reserves need to be locked (vq_resMissing is used after this)
    vq_resDemand.fx(restype, up_down, group, s, f+df_reserves(grid, node, restype, f, t), t)
        $ { ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t) // This set contains the combination of reserve types and time intervals that should be fixed
            and not dropVqResDemand(restype, up_down, group, t)}
      = r_qReserveDemand_ft(restype, up_down, group, f+df_reservesGroup(group, restype, f, t), t);

); // END loop(restypeDirectionGridNode, sft)

* --- Investment Variable Boundaries ------------------------------------------

// Unit Investments
// LP variant
v_invest_LP.up(unit)${    unit_investLP(unit) }
    = p_unit(unit, 'maxUnitCount')
;
v_invest_LP.lo(unit)${    unit_investLP(unit) }
    = p_unit(unit, 'minUnitCount')
;
// MIP variant
v_invest_MIP.up(unit)${   unit_investMIP(unit)    }
    = p_unit(unit, 'maxUnitCount')
;
v_invest_MIP.lo(unit)${   unit_investMIP(unit)    }
    = p_unit(unit, 'minUnitCount')
;

// Transfer Capacity Investments
// LP investments
v_investTransfer_LP.up(gn2n_directional(grid, from_node, to_node), t_invest)${ gn2n_directional_investLP(grid, from_node, to_node) }
    = p_gnn(grid, from_node, to_node, 'transferCapInvLimit')
;
// MIP investments
v_investTransfer_MIP.up(gn2n_directional(grid, from_node, to_node), t_invest)${ gn2n_directional_investMIP(grid, from_node, to_node) }
    = p_gnn(grid, from_node, to_node, 'transferCapInvLimit')
        / p_gnn(grid, from_node, to_node, 'unitSize')
;


* =============================================================================
* --- Bounds for the first (and last) interval --------------------------------
* =============================================================================

// Loop over the start intervals
loop((ft_start(f, t), ms_initial(mSolve, s)),

    // If this is the very first solve, set various initial bounds
    if(t_solveFirst = mSettings(mSolve, 't_start'),

        // state limits for nodes that have state variable and are not superposed nodes
        loop(gn_state(grid, node) $ {not node_superpos(node)},

            // First solve, state variables (only if boundStart flag is true)
            v_state.fx(grid, node, s, f, t)${ p_gn(grid, node, 'boundStart') }
                = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
                    * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');

            // Time series form boundary
            v_state.fx(grid, node, s, f, t)${ p_gn(grid, node, 'boundStart')
                                                        and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries') // !!! NOTE !!! The check fails if value is zero
                                                        }
                = ts_node(grid, node, 'reference', f, t) // NOTE!!! ts_node_ doesn't contain initial values so using raw data instead.
                    * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
        ); //end loop(gn_state)


        // Initial online status for units
        v_online_LP.fx(unit, s, f, t)
            ${p_unit(unit, 'useInitialOnlineStatus')
              and usft_onlineLP(unit, s, f, t+1)}  //sets online status for one time step before the first solve
            = p_unit(unit, 'initialOnlineStatus');
        v_online_MIP.fx(unit, s, f, t)
            ${p_unit(unit, 'useInitialOnlineStatus')
              and usft_onlineMIP(unit, s, f, t+1)}
            = p_unit(unit, 'initialOnlineStatus');

        // v_online cannot exceed unit count if not using initial online status
        // LP variant
        v_online_LP.up(unit, s, f, t)
            ${not unit_invest(unit)
              and usft_onlineLP(unit, s, f, t+1)
              and not p_unit(unit, 'useInitialOnlineStatus')}
            = p_unit(unit, 'unitCount');

        // MIP variant
        v_online_MIP.up(unit, s, f, t)
            ${not unit_invest(unit)
              and usft_onlineMIP(unit, s, f, t+1)
              and not p_unit(unit, 'useInitialOnlineStatus')}
            = p_unit(unit, 'unitCount');

        // Initial generation for units
        v_gen.fx(gnu(grid, node, unit), s, f, t)${p_gnu(grid, node, unit, 'useInitialGeneration')}
            = p_gnu(grid, node, unit, 'initialGeneration');

        // Startup and shutdown variables are not applicable at the first time step
        v_startup_LP.fx(starttype, unit_online_LP(unit), s, f, t)$unitStarttype(unit, starttype) = 0;
        v_startup_MIP.fx(starttype, unit_online_MIP(unit), s, f, t)$unitStarttype(unit, starttype) = 0;
        v_shutdown_LP.fx(unit_online_LP, s, f, t) = 0;
        v_shutdown_MIP.fx(unit_online_MIP, s, f, t) = 0;

    else // For all other solves than first one, fix the initial state values based on previous results.

        //TBC: should there be something here for superposed states?

        // State and online variable initial values for the subsequent solves
        v_state.fx(gn_state(grid, node), s, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')))
            = r_state_gnft(grid, node, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')));

        // Generation initial value (needed at least for ramp constraints)
        v_gen.fx(gnu(grid, node, unit), s, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')))
            = r_gen_gnuft(grid, node, unit, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')));

        // Transfer initial value (needed at least for ramp constraints)
        v_transfer.fx(gn2n(grid, from_node, to_node), s, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')))
            = r_transfer_gnnft(grid, from_node, to_node, f, t + (1 - mInterval(mSolve, 'stepsPerInterval', 'c000')));


    ); // END if(t_solveFirst)
) // END loop(ft_start, ms)
;

// If this is the very first solve, set various initial bounds for the superposed node states
if(t_solveFirst = mSettings(mSolve, 't_start'),
    // state limits for normal (not superposed) nodes
    loop(node_superpos(node),
        loop(mz(mSolve, z)$(ord(z) eq 1),
            // First solve, fix start value of state variables (only if boundStart flag is true)
            v_state_z.fx(gn_state(grid, node), z)${ p_gn(grid, node, 'boundStart')
                                                    and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useConstant')
                                                    }
                = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
                        * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
            ) //END loop mz
        ) //END loop node_superpos
); //END if(t_solveFirst)

* =============================================================================
* --- Fix previously realized start-ups, shutdowns, and online states ---------
* =============================================================================

// Needed for modelling hot and warm start-ups, minimum uptimes and downtimes, and run-up and shutdown phases.
if( t_solveFirst <> mSettings(mSolve, 't_start'), // Avoid rewriting the fixes on the first solve handled above
    // Units that have a LP online variable on the first effLevel. Applies also following v_startup and v_online.
    v_startup_LP.fx(starttype, unit_online_LP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${ (ord(t) <= t_solveFirst) // Only fix previously realized time steps
           and unitStarttype(unit, starttype) }
        = r_startup_uft(starttype, unit, f, t);

    // Units that have a MIP online variable on the first effLevel. Applies also following v_startup and v_online.
    v_startup_MIP.fx(starttype, unit_online_MIP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${ (ord(t) <= t_solveFirst) // Only fix previously realized time steps
           and unitStarttype(unit, starttype) }
        = r_startup_uft(starttype, unit, f, t);

    v_shutdown_LP.fx(unit_online_LP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${  ord(t) <= t_solveFirst } // Only fix previously realized time steps
        = r_shutdown_uft(unit, f, t);

    v_shutdown_MIP.fx(unit_online_MIP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${  ord(t) <= t_solveFirst } // Only fix previously realized time steps
        = r_shutdown_uft(unit, f, t);

    v_online_LP.fx(unit_online_LP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${  ord(t) <= t_solveFirst // Only fix previously realized time steps
            }
        = r_online_uft(unit, f, t);

    v_online_MIP.fx(unit_online_MIP(unit), sft_realizedNoReset(s, f, t_active(t)))
        ${  ord(t) <= t_solveFirst // Only fix previously realized time steps
            }
        = r_online_uft(unit, f, t);
); // END if


* =============================================================================
* --- Fix previously realized generation when modelling delays ----------------
* =============================================================================

// fixing necessary historical generation from the second solve onwards
if(solveCount > 1 and card(gnu_delay) > 0,

    // clearing temporary set for timesteps
    Option clear = tt;

    // max number of required historical timesteps for any gnu_delay
    tmp = smax(gnu_delay, p_gnu(gnu_delay, 'delay'))        // longest delay
          + mInterval(mSolve, 'stepsPerInterval', 'c000');  // number of times steps per interval from the first interval to make sure to include all necessary time steps

    // set of required historical timesteps
    tt(t_realizedNoReset(t) ) ${ ord(t) <= t_solveFirst          // including t_solveFirst
                                 and ord(t) > t_solveFirst - tmp // Strict inequality accounts for t_solvefirst being one step before the first ft step.
                                 and ord(t) > 1                  // excluding t000000
                                 }
        = yes;

    // fixing historical v_gen to previous results
    v_gen.fx(gnu_delay(grid, node, unit), sft_realizedNoReset(s, f, tt(t)) )
        $ {ord(t) > [t_solveFirst
                    - max(p_gnu(gnu_delay, 'delay'), mInterval(mSolve, 'stepsPerInterval', 'c000')) ] // gnu_delay specific max
           }
        = r_gen_gnuft(grid, node, unit, f, t);

); // END if(solveCount > 1)


* =============================================================================
* --- Fix previously realized investment results ------------------------------
* =============================================================================

v_invest_LP.fx(unit_investLP(unit))${ p_unit(unit, 'becomeAvailable') <= t_solveFirst }
    = r_invest_unitCount_u(unit);
v_invest_MIP.fx(unit_investMIP(unit))${ p_unit(unit, 'becomeAvailable') <= t_solveFirst }
    = r_invest_unitCount_u(unit);
v_investTransfer_LP.fx(gn2n_directional(grid, node, node_), t_invest(t))${    not p_gnn(grid, node, node_, 'investMIP')
                                                                              and p_gnn(grid, node, node_, 'transferCapInvLimit')
                                                                              and ord(t) <= t_solveFirst
                                                                              }
    = r_invest_transferCapacity_gnn(grid, node, node_, t);
v_investTransfer_MIP.fx(gn2n_directional(grid, node, node_), t_invest(t))${   p_gnn(grid, node, node_, 'investMIP')
                                                                              and p_gnn(grid, node, node_, 'transferCapInvLimit')
                                                                              and ord(t) <= t_solveFirst
                                                                              }
    = r_invest_transferCapacity_gnn(grid, node, node_, t)
          / p_gnn(grid, node, node_, 'unitSize');



* =============================================================================
* --- Read additional user given changes in loop phase ------------------------
* =============================================================================


$ifthen.loopChanges exist '%input_dir%/changes_loop.inc'
    $$include '%input_dir%/changes_loop.inc'  // reading changes to looping phase if file exists
$endif.loopChanges



