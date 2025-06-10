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
* --- Scaling variables and equations -----------------------------------------
* =============================================================================


// Scaling factors for node
if(smax(node, p_scaling_n(node)) > 1,

    // v_state
    v_state.scale(gn_state(grid, node), sft(s, f, t))${p_scaling_n(node) > 1} = p_scaling_n(node);
    // v_state t000000
    v_state.scale(gn_state(grid, node), sf(s, f), t_active(t))
        ${p_scaling_n(node) > 1
          and f_realization(f)
          and ord(t) = t_solveFirst}
        = p_scaling_n(node);

    // Scaling state slack
    v_stateSlack.scale(slack, gn_stateSlack(grid, node), sft(s, f, t))
        ${ [ p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
             or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeSeries')
             ]
           and not df_central_t(f, t)
           }
        = p_scaling_n(node);

    // scaling for q_balance by the stepLength
    q_balance.scale(gn_balance(grid, node), sft(s, f, t)) = p_stepLength(t);

); // END if(p_scaling_n)

// Scaling factors for unit
if(smax(unit, p_scaling_u(unit)) > 1,

    // v_gen
    v_gen.scale(gnusft(grid, node, unit, s, f, t))${p_scaling_u(unit) > 1} = p_scaling_u(unit);


    // q_conversionDirectInputOutput with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_conversionDirectInputOutput.scale(eff_usft(effDirect(effGroup), unit, s, f, t))
        ${p_scaling_u(unit) > 1 }
        = p_scaling_u(unit)/10;

    // q_maxUpward with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_maxUpward.scale(gnusft(grid, node, unit, s, f, t))
        ${p_scaling_u(unit) > 1
           and [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
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
           } = p_scaling_u(unit)/10;

    // q_maxDownward with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_maxDownward.scale(gnusft(grid, node, unit, s, f, t))
        ${p_scaling_u(unit) > 1
          and [p_gnu(grid, node, unit, 'capacity') or p_gnu(grid, node, unit, 'unitSize')]
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
           } = p_scaling_u(unit)/10;

    // unit constraints
    q_unitEqualityConstraint.scale(eq_constraint, usft(unit, s, f, t))
        ${p_scaling_u(unit) > 1
          and unitConstraint(unit, eq_constraint)
          } = p_scaling_u(unit)/10;
    q_unitGreaterThanConstraint.scale(gt_constraint, usft(unit, s, f, t))
        ${p_scaling_u(unit) > 1
          and unitConstraint(unit, gt_constraint)
          } = p_scaling_u(unit)/10;
    q_unitLesserThanConstraint.scale(lt_constraint, usft(unit, s, f, t))
        ${p_scaling_u(unit) > 1
          and unitConstraint(unit, lt_constraint)
          } = p_scaling_u(unit)/10;


    // v_gen_delay
    v_gen_delay.scale(gnusft(gnu_delay(grid, node, unit), s, f, t))${p_scaling_u(unit) > 1} = p_scaling_u(unit);

    // q_genDelay with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_genDelay.scale(gnu_delay(grid, node, unit), sft(s, f, t_))
        $ { sum(t_full(t), map_delay_gnutt(grid, node, unit, t, t_))
            } = 10**floor(log10(p_stepLength(t_)));

    // downscaling q_energyLimit
    q_energyLimit.scale(group, min_max)
        ${  p_scaling > 1
            and  [(sameas(min_max, 'max') and p_groupPolicy(group, 'energyMax'))
                   or (sameas(min_max, 'min') and p_groupPolicy(group, 'energyMin'))
                   ]
            } = 10;


); // END if(p_scaling_u)

// Scaling factors for transfer
if(smax(gn2n(grid, node, node_), p_scaling_nn(node, node_)) > 1,

    // v_transfer
    v_transfer.scale(gn2nsft_directional(grid, node, node_, s, f, t))
        = p_scaling_nn(node, node_);
    v_transferLeftward.scale(gn2nsft_directional(grid, node, node_, s, f, t))
        = p_scaling_nn(node, node_);
    v_transferRightward.scale(gn2nsft_directional(grid, node, node_, s, f, t))
        = p_scaling_nn(node, node_);

    // q_transferTwoWayLimit1 with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_transferTwoWayLimit1.scale(gn2nsft_directional(grid, node, node_, s, f, t))
        ${not p_gnn(grid, node, node_, 'transferCapInvLimit')
          and (((p_gnn(grid, node, node_, 'availability')>0) and not gn2n_timeseries(grid, node, node_, 'availability'))
              or ((ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node, node_, 'availability')))
          and (((p_gnn(grid, node_, node, 'availability')>0) and not gn2n_timeseries(grid, node_, node, 'availability'))
              or ((ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node_, node, 'availability')))
          and p_gnn(grid, node, node_, 'transferCap')
          and p_gnn(grid, node_, node, 'transferCap')
          }
        = 1/p_scaling;

    // q_transferTwoWayLimit2 with conditionals as in the equation to avoid unnecessary scaling multipliers
    q_transferTwoWayLimit2.scale(gn2nsft_directional(grid, node, node_, s, f, t))
        ${p_gnn(grid, node, node_, 'transferCapInvLimit')
          and p_gnn(grid, node, node_, 'transferCap') = p_gnn(grid, node_, node, 'transferCap')
          and (((p_gnn(grid, node, node_, 'availability')>0) and not gn2n_timeseries(grid, node, node_, 'availability'))
              or ((ts_gnn_(grid, node, node_, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node, node_, 'availability')))
          and (((p_gnn(grid, node_, node, 'availability')>0) and not gn2n_timeseries(grid, node_, node, 'availability'))
              or ((ts_gnn_(grid, node_, node, 'availability', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)>0) and gn2n_timeseries(grid, node_, node, 'availability')))
          }
        = 1/p_scaling;

); // END if(p_scaling_nn)


// Scaling factor for the object
if(p_scaling_obj > 1,
    v_obj.scale = p_scaling_obj;
); // END if(p_scaling_obj)



* =============================================================================
* --- Controlling the use of previous solutions to have a first guess ---------
* =============================================================================
* 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve

    if (mSettings(mSolve, 'loadPoint') = 1 and solveCount > 1,
        put_utility 'gdxin' / mSolve.tl:0 '_p.gdx';
        execute_loadpoint;
    elseif mSettings(mSolve, 'loadPoint') = 2,
        put_utility 'gdxin' / mSolve.tl:0 '_p' solveCount:0:0 '.gdx';
        execute_loadpoint;
    elseif mSettings(mSolve, 'loadPoint') = 3 and solveCount = 1,
        put_utility 'gdxin' / mSolve.tl:0 '_p.gdx';
        execute_loadpoint;
    );

    if (mSettings(mSolve, 'savePoint') = 1,
        option savepoint = 1;
    elseif mSettings(mSolve, 'savePoint') = 2,
        option savepoint = 2;
    elseif mSettings(mSolve, 'savePoint') = 3 and solveCount = 1,
        option savepoint = 1;
    elseif mSettings(mSolve, 'savePoint') = 3 and solveCount > 1,
        option savepoint = 0;
    );


* =============================================================================
* --- Solve Commands ----------------------------------------------------------
* =============================================================================

    if (mSolve('schedule'),
        schedule.holdfixed = 1; // Enable holdfixed, which makes the GAMS compiler convert fixed variables into parameters for the solver.
        schedule.OptFile = 1;
        schedule.scaleopt = 1;
        solve schedule using mip minimizing v_obj;
        checkSolveStatus(schedule);
    ); // END IF SCHEDULE

    if (mSolve('building'),
        building.holdfixed = 1;
        building.OptFile = 1;
        building.scaleopt = 1;
        solve building using mip minimizing v_obj;
        checkSolveStatus(building);
    ); // END IF BUILDING

    if (mSolve('invest'),
        invest.holdfixed = 1; // Enable holdfixed, which makes the GAMS compiler convert fixed variables into parameters for the solver.
        invest.OptFile = 1;
        invest.scaleopt = 1;
        solve invest using mip minimizing v_obj;
        checkSolveStatus(invest);
    ); // END IF INVEST



