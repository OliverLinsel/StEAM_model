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
- Clear variables, equations, and ts_XX_ in order to save memory
- Read changes or additions through loop_changes.inc file
- Determine sft structure and displacements for the solve
- Active units, aggregations, ramps, and required displacements
- Active transfer links, aggregations, ramps, and required displacements


$offtext

* =============================================================================
* --- Clear variables, equations, and ts_XX_ in order to save memory ----------
* =============================================================================

* --- Variables ---------------------------------------------------------------

// Free Variables
Option clear = v_gen;
Option clear = v_genRampUp;
Option clear = v_genRampDown;
Option clear = v_transfer;
Option clear = v_transferRamp;
Option clear = v_state;
Option clear = v_statemax;
Option clear = v_statemin;

// Integer Variables
Option clear = v_startup_MIP;
Option clear = v_shutdown_MIP;
Option clear = v_online_MIP;
Option clear = v_invest_MIP;
Option clear = v_investTransfer_MIP;

// Binary Variables
Option clear = v_help_inc;

// SOS2 Variables
Option clear = v_sos2;

// Positive Variables
Option clear = v_startup_LP;
Option clear = v_shutdown_LP;
Option clear = v_genRampUpDown;
Option clear = v_gen_delay;
Option clear = v_spill;
Option clear = v_transferRightward;
Option clear = v_transferLeftward;
Option clear = v_reserve;
Option clear = v_resToMarkets;
Option clear = v_resTransferRightward;
Option clear = v_resTransferLeftward;
Option clear = v_investTransfer_LP;
Option clear = v_online_LP;
Option clear = v_invest_LP;
Option clear = v_gen_inc;
Option clear = v_userconstraint_LP_t;
Option clear = v_userconstraint_LP;
Option clear = v_userconstraint_MIP_t;
Option clear = v_userconstraint_MIP;

// Feasibility control
Option clear = v_stateSlack;
Option clear = vq_gen;
Option clear = vq_genRampUp;
Option clear = vq_genRampDown;
Option clear = vq_resDemand;
Option clear = vq_resMissing;
Option clear = vq_capacity;
Option clear = vq_unitConstraint;
Option clear = vq_userconstraintInc_t;
Option clear = vq_userconstraintDec_t;
Option clear = vq_userconstraintInc;
Option clear = vq_userconstraintDec;


* --- Equations ---------------------------------------------------------------

// Objective Function, Energy Balance, and Reserve demand
Option clear = q_obj;
Option clear = q_balance;
Option clear = q_resDemand;
Option clear = q_resDemandLargestInfeedUnit;
Option clear = q_rateOfChangeOfFrequencyUnit;
Option clear = q_rateOfChangeOfFrequencyTransfer;
Option clear = q_resDemandLargestInfeedTransfer;

// Unit Operation
Option clear = q_maxDownward;
Option clear = q_maxDownwardOfflineReserve;
Option clear = q_maxUpward;
Option clear = q_maxUpwardOfflineReserve;
Option clear = q_fixedFlow;
Option clear = q_reserveProvision;
Option clear = q_reserveProvisionOnline;
Option clear = q_startshut;
Option clear = q_startuptype;
Option clear = q_onlineLimit;
Option clear = q_onlineMinUptime;
Option clear = q_onlineCyclic;
Option clear = q_onlineOnStartUp;
Option clear = q_offlineAfterShutdown;
Option clear = q_genRampUp;
Option clear = q_genRampDown;
Option clear = q_rampUpLimit;
Option clear = q_rampDownLimit;
Option clear = q_rampUpDownPiecewise;
Option clear = q_rampSlack;
Option clear = q_conversionDirectInputOutput;
Option clear = q_conversionSOS2InputIntermediate;
Option clear = q_conversionSOS2Constraint;
Option clear = q_conversionSOS2IntermediateOutput;
Option clear = q_conversionIncHR;
Option clear = q_conversionIncHRMaxOutput;
Option clear = q_conversionIncHRBounds;
Option clear = q_conversionIncHR_help1;
Option clear = q_conversionIncHR_help2;
Option clear = q_unitEqualityConstraint;
Option clear = q_unitGreaterThanConstraint;
Option clear = q_unitLesserThanConstraint;

// Energy Transfer
Option clear = q_transfer;
Option clear = q_transferRightwardLimit;
Option clear = q_transferLeftwardLimit;
Option clear = q_resTransferLimitRightward;
Option clear = q_resTransferLimitLeftward;
Option clear = q_transferRamp;
Option clear = q_transferRampLimit1;
Option clear = q_transferRampLimit2;
Option clear = q_reserveProvisionRightward;
Option clear = q_reserveProvisionLeftward;
Option clear = q_transferTwoWayLimit1;
Option clear = q_transferTwoWayLimit2;

// State Variables
Option clear = q_stateUpwardSlack;
Option clear = q_stateDownwardSlack;
Option clear = q_stateUpwardLimit;
Option clear = q_stateDownwardLimit;
Option clear = q_boundStateMaxDiff;
Option clear = q_boundCyclic;

// Policy
Option clear = q_inertiaMin;
Option clear = q_instantaneousShareMax;
Option clear = q_constrainedOnlineMultiUnit;
Option clear = q_capacityMargin;
Option clear = q_constrainedCapMultiUnit;
Option clear = q_emissioncapNodeGroup;
Option clear = q_energyLimit;
Option clear = q_energyShareLimit;
Option clear = q_ReserveShareMax;
Option clear = q_userconstraintEq_eachTimestep;
Option clear = q_userconstraintGtLt_eachTimestep;
Option clear = q_nonanticipativity_online;
Option clear = q_nonanticipativity_state;

* --- Temporary Time Series ---------------------------------------------------

// Initialize temporary time series
// unit ts
Option clear = ts_unit_;
Option clear = ts_unitConstraint_;
Option clear = ts_unitConstraintNode_;
// node ts
Option clear = ts_influx_;
Option clear = ts_cf_;
Option clear = ts_node_;
Option clear = ts_price_;
Option clear = ts_priceNew_;
Option clear = ts_storageValue_;
// gnu ts
Option clear = ts_gnu_;
// gnn ts
Option clear = ts_gnn_;
// reserve ts
Option clear = ts_reserveDemand_;
Option clear = ts_reservePrice_;
// group ts
Option clear = ts_emissionPrice_;
Option clear = ts_emissionPriceNew_;
Option clear = ts_groupPolicy_;
// derived unit ts
Option clear = ts_vomCost_;
Option clear = ts_startupCost_;
Option clear = ts_vomCostNew_;
Option clear = ts_startupCostNew_;
Option clear = ts_effUnit_;
Option clear = ts_effGroupUnit_;
// derived gn ts
Option clear = ts_linkVomCost_;

* =============================================================================
* --- Read changes or additions through loop_changes.inc file -----------------
* =============================================================================
$ifthen.loopChanges exist '%input_dir%/loop_changes.inc'
   $$include '%input_dir%/loop_changes.inc'
$endif.loopChanges

* =============================================================================
* --- Determine sft structure and displacements for the solve -----------------
* =============================================================================

* --- Clear from previous solve -----------------------------------------------

// Initializing forecast-time structure sets
Option clear = p_stepLength;
Option clear = ft;
Option clear = sft;
Option clear = st;
Option clear = st_start, clear = st_end;

// Initialize the set of active t:s, counters and interval time steps
Option clear = t_active;
Option clear = t_active_effLevel;
Option clear = dt;
Option clear = dt_next;
Option clear = dt_active;
Option clear = tt_block;
tCounter = 1;


* --- Build non-aggregated sets with timestep dimensions in solve -------------

// Determine the time steps of the current solve
t_solveFirst = ord(t_solve);  // t_solveFirst: the start of the current solve, t0 used only for initial values

// Update tForecastNext
if(solveCount = 1 and mSettings(mSolve, 't_forecastJump'),
    tForecastNext(mSolve)
        ${ t_solveFirst >= tForecastNext(mSolve) }
        = t_solveFirst + mSettings(mSolve, 't_forecastJump');
else
    tForecastNext(mSolve)
        ${ t_solveFirst >= tForecastNext(mSolve) }
        = tForecastNext(mSolve) + mSettings(mSolve, 't_forecastJump');
);

// Calculate forecast length
currentForecastLength
    = max(  mSettings(mSolve, 't_forecastLengthUnchanging'),  // Unchanging forecast length would remain the same
            mSettings(mSolve, 't_forecastLengthDecreasesFrom') - [mSettings(mSolve, 't_forecastJump') - {tForecastNext(mSolve) - t_solveFirst}] // While decreasing forecast length has a fixed horizon point and thus gets shorter
            );   // Larger forecast horizon is selected

// t_solveLast: the end of the current solve
t_solveLast = t_solveFirst + mSettings(mSolve, 't_horizon');

// create a subset t_current that covers only t needed in this solve
Option clear = t_current;
t_current(t_full(t))
    ${  ord(t) >= t_solveFirst
        and ord (t) <= t_solveLast
        }
    = yes;

// Find time steps until the forecast horizon
option clear = tt_forecast;
tt_forecast(t_current(t))
    ${ ord(t) <= t_solveFirst + currentForecastLength }
    = yes;


* --- Build aggregated sets with forecast and timestep dimensions in solve ----

// Loop over the defined blocks of intervals to handle time step aggregation
loop(counter_intervals(counter),
    // Time steps within the current block
    option clear = tt;
    tt(t_current(t))
        ${ord(t) >= t_solveFirst + tCounter
          and ord(t) <= min(t_solveFirst
                            + mInterval(mSolve, 'lastStepInIntervalBlock', counter),
                            t_solveLast)
         } = yes;

    // Store the interval time steps for each interval block (counter)
    tt_block(counter, tt) = yes;

    // Initialize tInterval
    Option clear = tt_interval;

    // If stepsPerInterval equals one, simply use all the steps within the block
    if(mInterval(mSolve, 'stepsPerInterval', counter) = 1,
        // Include all time steps within the block
        tt_interval(tt(t)) = yes;

    // If stepsPerInterval exceeds 1 (stepsPerInterval < 1 not defined)
    elseif mInterval(mSolve, 'stepsPerInterval', counter) > 1,

        // Calculate the displacement required to reach the corresponding active time step from any time step
        dt_active(tt(t)) = - (mod(ord(t) - t_solveFirst - tCounter, mInterval(mSolve, 'stepsPerInterval', counter)));

        // Select the active time steps within the block
        tt_interval(tt(t))${ not dt_active(t) } = yes;

    ); // END ELSEIF intervalLenght

    // Calculate the interval length in hours
    p_stepLength(tt_interval(t))
      = sum(m, mInterval(mSolve, 'stepsPerInterval', counter) * mSettings(mSolve, 'stepLengthInHours'));


    // store the amount of interval steps to timestep displacement set
    dt_next(tt_interval(t)) = mInterval(mSolve, 'stepsPerInterval', counter);

    // Update tActive
    t_active(tt_interval) = yes;

    // Update the last active t. +1 because t000000 is the first index.
    t_solveLastActive = t_solveLast - mInterval(mSolve, 'stepsPerInterval', counter) + 1;


    // Determine the combinations of forecasts and intervals
    // Include the t_jump for the realization
    ft(f_active, tt_interval(t))
       ${ord(t) <= t_solveFirst + max(mSettings(mSolve, 't_jump'),
                                     min(mSettings(mSolve, 't_perfectForesight'),
                                         currentForecastLength))
         and mf_realization(mSolve, f_active)
        } = yes;

    // Include the full horizon for the central forecast
    ft(f_active, tt_interval(t))
      ${ord(t) > t_solveFirst + max(mSettings(mSolve, 't_jump'),
                                   min(mSettings(mSolve, 't_perfectForesight'),
                                       currentForecastLength))
        and (mf_central(mSolve, f_active)
             or mSettings(mSolve, 'forecasts') = 0)
       } = yes;

    // Include up to forecastLength for remaining forecasts
    ft(f_active, tt_interval(t))
      ${not mf_central(mSolve, f_active)
        and not mf_realization(mSolve, f_active)
        and ord(t) > t_solveFirst + max(mSettings(mSolve, 't_jump'),
                                       min(mSettings(mSolve, 't_perfectForesight'),
                                           currentForecastLength))
        and ord(t) <= t_solveFirst + currentForecastLength
       } = yes;

    // Update tCounter for the next block of intervals
    tCounter = mInterval(mSolve, 'lastStepInIntervalBlock', counter) + 1;

$iftheni.diag '%diag%' == yes
    // store temporary values within the loop to diagnostic result tables
    d_tByCounter(counter, t)${ ord(t) = t_solveFirst} = card(tt);
    d_tStepsByCounter(counter, t)${ ord(t) = t_solveFirst} = card(tt_interval);
$endif.diag

); // END loop(counter)


* --- Including historical timesteps and updating displacements ---------------

// Include the necessary amount of historical timesteps to the active time step set of the current solve
t_active(t_full(t)) ${ t_realizedNoReset(t)
                       and ord(t) <= t_solveFirst
                       and ord(t) > t_solveFirst + dt_historicalSteps // Strict inequality accounts for t_solvefirst being one step before the first ft step.
                       }
    = yes;


// Include the necessary amount of historical timesteps to the displacement timesteps sets
tmp = sum(t$ { ord(t) = t_solveFirst+1}, dt_next(t));
dt_next(t_full(t)) ${ t_realizedNoReset(t)
                      and ord(t) <= t_solveFirst
                      and ord(t) >= t_solveFirst + dt_historicalSteps
                      }
    = tmp;

// calculate dt from dt_next
dt(t + dt_next(t))$t_full(t) = -dt_next(t);

// remove dt_next from the last active t
dt_next(t_full(t))${ ord(t) = t_solveLastActive } = 0;


* --- Build aggregated sets with sample, forecast, and timestep dimension -----

// Loop over defined samples
loop(sf(s, f)$sum(m, msStart(mSolve, s)),
    sft(s, ft(f, t))${ord(t) > sum(m, msStart(mSolve, s))
                      and ord(t) <= sum(m, msEnd(mSolve, s))
                     } = yes;
);

// Active st in the solve
Options st < sft;

// Update probabilities
Option clear = p_sft_probability;
p_sft_probability(sft(s, f, t))
    = p_mfProbability(mSolve, f)
      / sum(f_$ft(f_, t),
            p_mfProbability(mSolve, f_)
            )
      * p_msProbability(mSolve, s)
      * p_msWeight(mSolve, s)
      ;


* --- Updated realized sft sets -----------------------------------------------

// Set of realized intervals in the current solve
Option clear = ft_realized;
ft_realized(ft(f_active, t))
    ${  mf_realization(mSolve, f_active)
        and ord(t) <= t_solveFirst + mSettings(mSolve, 't_jump')
        }
    = yes;

Option clear = sft_realized;
sft_realized(sft(s, ft_realized(f, t))) = yes;

Option t_realized < ft_realized;


* --- Updated forecast sft sets -----------------------------------------------

// clear previous values
option clear = t_nonanticipativity;

// check if nonanticipativity active and affected t in solve
if(sum(m, mSettings(m, 'nonanticipativity')) and card(f_active) > 1,
    t_nonanticipativity(t_active(t)) ${ord(t) <= [t_solveFirst
                                                  + max(mSettings(mSolve, 't_jump'),
                                                        min(mSettings(mSolve, 't_perfectForesight'),
                                                            currentForecastLength
                                                            )
                                                        )
                                                  + sum(m, mSettings(m, 'nonanticipativity'))
                                                  ]
                                       and not t_realized(t)
                                       and ord(t) > t_solveFirst
                                       }
    = yes;
); // END card(f_active)


* --- Update sets not reseted over solves -------------------------------------

// Update the set of realized intervals in the whole simulation so far
t_realizedNoReset(t_realized(t)) = yes;
ft_realizedNoReset(ft_realized(f, t)) = yes;
sft_realizedNoReset(sft_realized(s, f, t)) = yes;

// Update the parameter table of realized steplength of the whole simulation so far
p_stepLengthNoReset(t_realized(t)) = p_stepLength(t);



* --- Calculating starts and ends ---------------------------------------------

// First t in each f
Option clear = ft_start;
ft_start(f_realization, t_solve)
    = yes
;
// Last t in each f
Option clear = ft_lastSteps;
ft_lastSteps(ft(f, t))
    ${ not dt_next(t) }
    = yes
;

// Sample start and end intervals
st_start(st(s, t))${ [ord(t) - t_solveFirst = msStart(mSolve, s)] } = yes;
loop(s_active(s),
    loop(t_active(t)$[ord(t) - t_solveFirst = sum(m, msEnd(mSolve, s))],
        st_end(s, t + dt(t)) = yes;
    );
);
// If the last interval of a sample is in ft_lastSteps, the method above does not work
st_end(st(s, t))${ sum(f_active, ft_lastSteps(f_active, t))} = yes;



* --- pairing t_active and effLevels ---------------------------------------------

t_active_effLevel(t_active(t), effLevel)
    ${ ord(t) > 1  // excluding t000000
       and ord(t) >= t_solveFirst + mSettingsEff_start(mSolve, effLevel)
       and ord(t) <= t_solveFirst + mSettingsEff(mSolve, effLevel)
       }
    = yes;



* --- Calculating remaining displacements -------------------------------------

// Displacement from the first interval of a sample to the previous interval is always -1,
// except for stochastic samples
dt(t_active(t))
    ${ sum(ms(mSolve, s)$(not ms_central(mSolve, s)), st_start(s, t)) }
    = -1;

// Forecast index displacement between realized and forecasted intervals
df_noReset(f_active(f), t_active(t))${ ord(t) <= t_solveFirst + max(mSettings(mSolve, 't_jump'),
                                                          min(mSettings(mSolve, 't_perfectForesight'),
                                                              currentForecastLength))}
    = sum(mf_realization(mSolve, f_), ord(f_) - ord(f));

option clear=df;
df(f_active(f), t_active(t))${ ord(t) <= t_solveFirst + max(mSettings(mSolve, 't_jump'),
                                                        min(mSettings(mSolve, 't_perfectForesight'),
                                                        currentForecastLength)) }
    = sum(mf_realization(mSolve, f_), ord(f_) - ord(f));

// Forecast displacement between central and forecasted intervals at the end of forecast horizon
Option clear = df_central_t;
df_central_t(ft(f, t))${  mSettings(mSolve, 'boundForecastEnds')
                        and (ord(t) > t_solveFirst + currentForecastLength - p_stepLength(t) / mSettings(mSolve, 'stepLengthInHours'))
                        and ord(t) <= t_solveFirst + currentForecastLength
                        and not mf_realization(mSolve, f)
                        }
    = sum(mf_central(mSolve, f_), ord(f_) - ord(f));

// Forecast displacement between central and forecasted intervals
Option clear = df_central;
df_central(f_active(f)) $ {not mf_realization(mSolve, f)}
    = sum(mf_central(mSolve, f_), ord(f_) - ord(f));



* --- building sft_withStorageStarts ------------------------------------------

// include t's just before samples if st_start is in solve
// clear previous values
option clear = sft_withStorageStarts;

// Picking t just before samples if the first t of sample is in the solve
// dt to move one step before the start of the sample
sft_withStorageStarts(sf(s, f), t_active(t+dt(t)) )
    $ { st_start(s, t)
        and sft(s, f, t) }
    = yes;
// picking also full sft
sft_withStorageStarts(sft(s, f, t)) = yes;


* --- Reserve displacements and locking ---------------------------------------

// Forecast index displacement between realized and forecasted intervals, required for locking reserves ahead of (dispatch) time.
Option clear = df_reserves;
df_reserves(grid, node, restype, ft(f, t))
    ${  p_gnReserves(grid, node, restype, 'update_frequency')
        and p_gnReserves(grid, node, restype, 'gate_closure')
        and ord(t) <= t_solveFirst + p_gnReserves(grid, node, restype, 'gate_closure')
                                  + p_gnReserves(grid, node, restype, 'update_frequency')
                                  - mod(t_solveFirst - 1 + p_gnReserves(grid, node, restype, 'gate_closure')
                                                    + p_gnReserves(grid, node, restype, 'update_frequency')
                                                    - p_gnReserves(grid, node, restype, 'update_offset'),
                                    p_gnReserves(grid, node, restype, 'update_frequency'))
        }
    = sum(f_${ mf_realization(mSolve, f_) }, ord(f_) - ord(f)) + Eps; // The Eps ensures that checks to see if df_reserves exists return positive even if the displacement is zero.
Option clear = df_reservesGroup;
df_reservesGroup(groupRestype(group, restype), ft(f, t))
    ${  p_groupReserves(group, restype, 'update_frequency')
        and p_groupReserves(group, restype, 'gate_closure')
        and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'gate_closure')
                                  + p_groupReserves(group, restype, 'update_frequency')
                                  - mod(t_solveFirst - 1 + p_groupReserves(group, restype, 'gate_closure')
                                                    + p_groupReserves(group, restype, 'update_frequency')
                                                    - p_groupReserves(group, restype, 'update_offset'),
                                    p_groupReserves(group, restype, 'update_frequency'))
        }
    = sum(f_${ mf_realization(mSolve, f_) }, ord(f_) - ord(f)) + Eps; // The Eps ensures that checks to see if df_reservesGroup exists return positive even if the displacement is zero.

// Set of ft-steps where the reserves are locked due to previous commitment
Option clear = ft_reservesFixed;
ft_reservesFixed(groupRestype(group, restype), f_active(f), t_active(t))
    ${  mf_realization(mSolve, f)
        and not t_solveFirst = mSettings(mSolve, 't_start') // No reserves are locked on the first solve!
        and p_groupReserves(group, restype, 'update_frequency')
        and p_groupReserves(group, restype, 'gate_closure')
        and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'gate_closure')
                                  + p_groupReserves(group, restype, 'update_frequency')
                                  - mod(t_solveFirst - 1
                                          + p_groupReserves(group, restype, 'gate_closure')
                                          - mSettings(mSolve, 't_jump')
                                          + p_groupReserves(group, restype, 'update_frequency')
                                          - p_groupReserves(group, restype, 'update_offset'),
                                        p_groupReserves(group, restype, 'update_frequency'))
                                  - mSettings(mSolve, 't_jump')
        and not [   restypeReleasedForRealization(restype) // Free desired reserves for the to-be-realized time steps
                    and ft_realized(f, t)
                    ]
        }
    = yes;


* --- timestep circulation ----------------------------------------------------

// Form a temporary clone of t_current
option tt < t_current;
option clear = tt_aggregate;
option clear = tt_agg_circular;

// in case of 1 active sample
if(card(s_active)=1,
    // Group each full time step under each active time step for time series aggregation.
    tt_aggregate(t_current(t+dt_active(t)), tt(t))
        = yes;

     // Make alternative aggregation ordering
     tt_agg_circular(t_current(t), t_full(t_+dt_circular(t_)), tt(t_)) $= tt_aggregate(t, t_);
);

// in case of multiple active samples
if(card(s_active)>1,
    // Group each full time step under each active time step for time series aggregation.
    tt_aggregate(t_current(t+dt_active(t)), tt(t))$sum(s, st(s, t))
        = yes;

     // Make alternative aggregation ordering
     tt_agg_circular(t_current(t), t_full(t_+dt_circular(t_)), tt(t_)) $= tt_aggregate(t, t_)$sum(s, st(s, t));
);


* --- Updated sft sets for user constraints, including circulation ------------

// clear previous values
Option clear = sft_groupUc;

// Check if any user constraint has defined a limited set of sft or effLevels.
// Note: All sft and effLevels are on by default. If user declares any s, f, t, or effLevel, the undeclared of the same dimension are not included.
// E.g. p_userconstraint(group_uc, 't008760', '-', '-', '-', 'timestep') creates the constraint for all s, all f, but only for t008760.
// Declaring filters over multiple values of the same dimension and over multiple dimensions allows the selection of desired sft and effLevel combinations.
sft_groupUc(group_ucSftFiltered(group_uc), sft(s, f, t))
    $ { [not groupUcParamUserConstraint(group_uc, 'sample')
         or [groupUcParamUserConstraint(group_uc, 'sample')
             and p_userconstraint(group_uc, s, '-', '-', '-', 'sample')
             ]
         ]
        and
        [not groupUcParamUserConstraint(group_uc, 'forecast')
         or [groupUcParamUserConstraint(group_uc, 'forecast')
             and p_userconstraint(group_uc, f, '-', '-', '-', 'forecast')
             ]
         ]
        and
        [not groupUcParamUserConstraint(group_uc, 'timestep')
         or [groupUcParamUserConstraint(group_uc, 'timestep')
             // t in aggrageted t_
             and sum(tt_agg_circular(t, t_, t__), p_userconstraint(group_uc, t_, '-', '-', '-', 'timestep'))
             ]
         ]
        and
        [not groupUcParamUserConstraint(group_uc, 'effLevel')
         or [groupUcParamUserConstraint(group_uc, 'effLevel')
             // t in effLevel
             and sum(effLevel$p_userconstraint(group_uc, effLevel, '-', '-', '-', 'effLevel'), t_active_effLevel(t, effLevel))
             ]
         ]
       }
    = yes;



* =============================================================================
* --- Active units, aggregations, ramps, and required displacements -----------
* =============================================================================

* --- Units with capacities or investment option active on each ft ------------

// initialize usft set
Option clear = usft;
usft(unit, sft(s, f, t)) $ {p_unit(unit, 'isActive') }
    = yes;

// temporary unit set for units affected by becomeAvailable or becomeUnavailable
option clear = unit_tmp;
unit_tmp(unit)${p_unit(unit, 'becomeAvailable') or p_unit(unit, 'becomeUnavailable')} = yes;

// Units are not active before or after their lifetime
usft(unit_tmp(unit), sft(s, f, t))${   [ ord(t) < p_unit(unit, 'becomeAvailable') and p_unit(unit, 'becomeAvailable') ]
                                    or [ ord(t) >= p_unit(unit, 'becomeUnavailable') and p_unit(unit, 'becomeUnavailable') ]
                                    }
    = no;

// temporary unit set for checking maintenance break for units affected by becomeAvailable and becomeUnavailable
option clear = unit_tmp;
unit_tmp(unit)${p_unit(unit, 'becomeAvailable') and p_unit(unit, 'becomeUnavailable')} = yes;

// Unless before becomeUnavailable if becomeUnavailable < becomeAvailable (maintenance break case)
usft(unit_tmp(unit), sft(s, f, t))${[ord(t) < p_unit(unit, 'becomeUnavailable')]
                                    and [p_unit(unit, 'becomeUnavailable') < p_unit(unit, 'becomeAvailable')]
                                    }
    = yes;
// Unless after becomeAvailable if becomeUnavailable < becomeAvailable (maintenance break case)
usft(unit_tmp(unit), sft(s, f, t))${[ord(t) >= p_unit(unit, 'becomeAvailable')]
                                    and [p_unit(unit, 'becomeUnavailable') < p_unit(unit, 'becomeAvailable')]
                                    }
    = yes;

// Deactivating aggregated after lastStepNotAggregated
usft(unit_aggregated(unit), sft(s, f, t))${ ord(t) > t_solveFirst + p_unit(unit, 'lastStepNotAggregated')
                                            }
    = no;
// Deactivating aggregators before lastStepNotAggregated
usft(unit_aggregator(unit), sft(s, f, t))${ ord(t) <= t_solveFirst + p_unit(unit, 'lastStepNotAggregated')
                                            }
    = no;


* --- derivative sets from usft -----------------------------------------------

// reduced us(unit, s) set if unit is active in sample
option us < usft;

// Active (grid, node, unit) on each sft
Option clear = gnusft;
gnusft(gnu(grid, node, unit), sft(s, f, t))${ usft(unit, s, f, t)} = yes;

// Active unit that are capable to provide reserves in active sft
Option clear = gnusft_resCapable;
gnusft_resCapable(gnu_resCapable(restype, up_down, grid, node, unit), sft(s, f, t))
    $ {gnusft(grid, node, unit, s, f, t)
       and ord(t) <= t_solveFirst + p_gnReserves(grid, node, restype, 'reserve_length')
       }
    = yes;

// First ft:s for each aggregator unit
Option clear = usft_aggregator_first;
usft_aggregator_first(usft(unit_aggregator(unit), s, f, t))
    ${ord(t) <= t_solveFirst + p_unit(unit, 'lastStepNotAggregated') +1}
    = yes;

* --- units with ramp parameters ----------------------------------------------

// Active (grid, node, unit) on each ft step with ramp restrictions
Option clear = gnusft_ramp;

// for the first solve, filtering st_start away from ramp equations
option clear = sft_tmp;
if(solveCount = 1,
    sft_tmp(sft(s, f, t)) $ { not st_start(s, t)} = yes;
// otherwise use sft
else
    option sft_tmp < sft;
); // END if

// checking sft when v_genRampUp is needed
gnusft_ramp(gnusft(gnu_rampUp, sft_tmp(s, f, t) ))
    ${ sum(group_uc, p_userconstraint(group_uc, gnu_rampUp, '-', 'v_genRampUp'))           // if v_genRampUp is used in userconstraint
       or gnu_rampUpCost(gnu_rampUp)                                                       // if rampUpCost
       or sum(upwardSlack(slack), p_gnuBoundaryProperties(gnu_rampUp, slack, 'rampCost'))  // if rampCost is activated
       or [ p_gnu(gnu_rampUp, 'maxRampUp')                                                 // if maxRampUp given and
            and p_gnu(gnu_rampUp, 'maxRampUp') * 60 * p_stepLength(t) < 1]                 // maxRampUp speed in hour * stepLength is less than 100%
       }
    = yes;

// checking sft when v_genRampDown is needed
gnusft_ramp(gnusft(gnu_rampDown, sft_tmp(s, f, t) ))
    ${ sum(group_uc, p_userconstraint(group_uc, gnu_rampDown, '-', 'v_genRampDown'))            // if v_genRampDown is used in userconstraint
       or gnu_rampDownCost(gnu_rampDown)                                                        // if rampUpCost
       or sum(downwardSlack(slack), p_gnuBoundaryProperties(gnu_rampDown, slack, 'rampCost'))   // if rampCost is activated
       or [ p_gnu(gnu_rampDown, 'maxRampDown')                                                  // if maxRampUp given and
            and p_gnu(gnu_rampDown, 'maxRampDown') * 60 * p_stepLength(t) < 1]                  // maxRampUp speed in hour * stepLength is less than 100%
       }
    = yes;


* --- Defining unit efficiency groups etc. ------------------------------------

// Determine eff_usft, the used effGroup for each usft
Option clear = eff_usft;
loop(effLevel $ mSettingsEff(mSolve, effLevel),
    option clear = tt;
    tt(t_active(t)) $ t_active_effLevel(t, effLevel) = yes;
    eff_usft(effGroup, usft(unit, s, f, tt(t))) $ effLevelGroupUnit(effLevel, effGroup, unit) = yes;
);

// Units with online variables on each ft
Option clear = usft_online;
Option clear = usft_onlineLP;
Option clear = usft_onlineMIP;
Option clear = usft_onlineLP_withPrevious;
Option clear = usft_onlineMIP_withPrevious;

// Determine the intervals when units need to have online variables.
loop(effOnline(effSelector),
    usft_online(usft(unit, s, f, t))${ eff_usft(effOnline, unit, s, f, t) }
        = yes;
); // END loop(effOnline)
usft_onlineLP(usft(unit, s, f, t))${ eff_usft('directOnLP', unit, s, f, t) }
    = yes;
usft_onlineMIP(usft_online(unit, s, f, t)) = usft_online(unit, s, f, t) - usft_onlineLP(unit, s, f, t);

// Units with start-up and shutdown trajectories
Option clear = usft_startupTrajectory;
Option clear = usft_shutdownTrajectory;

// Determine the intervals when units need to follow start-up and shutdown trajectories.
loop(runUpCounter(unit, 'c000'), // Loop over units with meaningful run-ups
    usft_startupTrajectory(usft_online(unit, s, f, t))
       ${ ord(t) <= t_solveFirst + mSettings(mSolve, 't_trajectoryHorizon') }
       = yes;
); // END loop(runUpCounter)
loop(shutdownCounter(unit, 'c000'), // Loop over units with meaningful shutdowns
    usft_shutdownTrajectory(usft_online(unit, s, f, t))
       ${ ord(t) <= t_solveFirst + mSettings(mSolve, 't_trajectoryHorizon') }
       = yes;
); // END loop(shutdownCounter)


* --- Historical Unit LP and MIP information ----------------------------------

usft_onlineLP_withPrevious(usft_onlineLP(unit, s, f, t)) = yes;
usft_onlineMIP_withPrevious(usft_onlineMIP(unit, s, f, t)) = yes;

// Units with online variables on each active ft starting at t0
loop(ft_start(f, t_), // Check the uft_online used on the first time step of the current solve
    usft_onlineLP_withPrevious(unit, s, f, t_active(t)) // Include all historical t_active
        ${  usft_onlineLP(unit, s, f, t_+1) // Displace by one to reach the first current time step
            and ord(t) <= t_solveFirst // Include all historical t_active
            }
         = yes;
    usft_onlineMIP_withPrevious(unit, s, f, t_active(t)) // Include all historical t_active
        ${  usft_onlineMIP(unit, s, f, t_+1) // Displace by one to reach the first current time step
            and ord(t) <= t_solveFirst // Include all historical t_active
            }
        = yes;
); // END loop(ft_start)

// Historical Unit LP and MIP information for models with multiple samples
// If this is the very first solve
if(t_solveFirst = mSettings(mSolve, 't_start'),
    // Sample start intervals
    loop(st_start(s, t),
        usft_onlineLP_withPrevious(unit, s, f, t+dt(t)) // Displace by one to reach the time step just before the sample
            ${  usft_onlineLP(unit, s, f, t)
                }
             = yes;
        usft_onlineMIP_withPrevious(unit, s, f, t+dt(t)) // Displace by one to reach the time step just before the sample
            ${  usft_onlineMIP(unit, s, f, t)
                }
            = yes;
    ); // END loop(st_start)
); // END if(t_solveFirst)


* --- Displacements for start-up decisions ------------------------------------

// Calculate dt_toStartup: in case the unit becomes online in the current time interval,
// displacement needed to reach the time interval where the unit was started up
Option clear = dt_toStartup;
loop(runUpCounter(unit, 'c000'), // Loop over units with meaningful run-ups
    dt_toStartup(unit, t_active(t))$(ord(t) <= t_solveFirst + mSettings(mSolve, 't_trajectoryHorizon'))
        = - p_u_runUpTimeIntervalsCeil(unit) + dt_active(t - p_u_runUpTimeIntervalsCeil(unit));
); // END loop(runUpCounter)


* --- Displacements for shutdown decisions ------------------------------------

// Calculate dt_toShutdown: in case the generation of the unit becomes zero in
// the current time interval, displacement needed to reach the time interval where
// the shutdown decisions was made
Option clear = dt_toShutdown;
loop(shutdownCounter(unit, 'c000'), // Loop over units with meaningful shutdowns
    dt_toShutdown(unit, t_active(t))$(ord(t) <= t_solveFirst + mSettings(mSolve, 't_trajectoryHorizon'))
        = - p_u_shutdownTimeIntervalsCeil(unit) + dt_active(t - p_u_shutdownTimeIntervalsCeil(unit))
); // END loop(runUpCounter)



* =============================================================================
* --- Active transfer links, aggregations, ramps, and required displacements --
* =============================================================================

* --- Defining transfer link aggregations and ramps ---------------------------

// set for active transfer links
Option clear = gn2nsft_directional;
gn2nsft_directional(gn2n_directional(grid, node, node_), sft(s, f, t))
    = yes;

// set for active ramp constrained transfer links
Option clear = gn2nsft_directional_ramp;
gn2nsft_directional_ramp(gn2n_directional_ramp(grid, node, node_), sft(s, f, t))
    $ { [not st_start(s, t)${solveCount = 1}]                                     // if it is the first solve, apply from second t onwards
        and [p_gnn(grid, node, node_, 'rampLimit') * 60 * p_stepLength(t) < 2     // if ramp max ramp speed in hour * stepLength is less than 2 (from -cap to +cap)
             or sum(group_uc, p_userconstraint(group_uc, grid, node, node_, '-', 'v_transferRamp')) // if v_transferRamp is used in userconstraint
             ]
       }
    = yes;




* =============================================================================
* --- Mapping for different time indexes --------------------------------------
* =============================================================================

// if delays activated
if(sum(gnu, p_gnu(gnu, 'delay')),

* --- generation delays, preparations -----------------------------------------

    // clearing previous values
    Option clear = map_delay_gnutt;
    Option clear = p_delay_gnutt;

* --- mapping generation delays, current timesteps ----------------------------

    // filtering t in the current solve
    option tt < ft;
    option tt_ < ft;

    // mapping t in the current solve that get delayed to t_
    // calculating the number of shifted timesteps as delay (h) / stepLengthInHours (h/timestep)
    tt(t)${p_stepLength(t)>1} = no;
    map_delay_gnutt(gnu_delay(grid, node, unit), tt(t), tt_(t_))
        $ { tt_aggregate(t_, t + [p_gnu(grid, node, unit, 'delay')/mSettings(mSolve, 'stepLengthInHours')] )
            }
        = yes;

    // When stepLength > 1, including also the following t_, because t can be delayed over two t_
    // Note: this is valid assumption only if stepsPerInterval increase or remains the same when counter grows.
    // reducing stepLength over time could lead to t mapped over more than two t_
    option tt < ft;
    tt(t)${p_stepLength(t)=1} = no;
    map_delay_gnutt(gnu_delay, tt(t), tt_(t_))
        $ { tt_aggregate(t_, t + [p_gnu(gnu_delay, 'delay')/mSettings(mSolve, 'stepLengthInHours')] )
            or tt_aggregate(t_, t + [p_gnu(gnu_delay, 'delay')/mSettings(mSolve, 'stepLengthInHours') + dt_next(t)] )
            }
        = yes;

    // calculating how many timesteps from each t are delayd to each t_
    //   * t and t_ are timesteps in solve, aggregated or not depending on init files
    //   * t__ is aliased to t. t_current(t__) is full set of t covered by the current solve. This is a helper set used in mapping.
    //   * sum over tt_aggregate and if condition over another tt_aggregate checks all timesteps t__ in each aggragated t and
    //     maps them to all delayed timesteps (t__ + delay) in aggregated t_
    //   * delay parameter is in hours and converted to timesteps
    // Note: using tt__ calculated just above
    p_delay_gnutt(map_delay_gnutt(gnu_delay, t, t_))
        = + sum(tt_aggregate(t_, t_current(t__))
              $ { tt_aggregate(t, t__ - [p_gnu(gnu_delay, 'delay')/mSettings(mSolve, 'stepLengthInHours')] )
                  },
              1); // END sum(tt_aggregate)


* --- mapping generation delays, historical timesteps -------------------------

    // max number of required historical timesteps by any unit with delays
    tmp = smax(gnu_delay, p_gnu(gnu_delay, 'delay'))  // longest delay
          + mInterval(mSolve, 'stepsPerInterval', 'c000');  // number of times steps per interval from the first interval to make sure to include all necessary time steps

    // filtering required historical timesteps to tt and representing them as tt(t) in the equations below
    Option clear = tt;
    tt(t_realizedNoReset(t)) ${ ord(t) <= t_solveFirst        // Strict inequality because t_solveFirst is included in t_current and thus included in previous step
                                and ord(t) >= t_solveFirst - tmp // Strict inequality accounts for t_solvefirst being one step before the first ft step.
                                and ord(t) > 1     // excluding t000000
                                }
        = yes;

    // clear tt_aggregate_historical from values that are not a part of required historical t
    option t_t < tt_aggregate_historical;
    tt_aggregate_historical(t_t(t, t_)) $ {not tt(t)} = no;

    // filtering potential target timesteps in the current solve to tt_ and representing them as tt_(t_) in the equations below
    option clear = tt_;
    tt_(t_active(t_)) $ {[ord(t_) > t_solveFirst]
                         and [ord(t_) <= t_solvefirst + tmp]
                         } = yes;

    // picking t_current that are close enough to historical steps to be relevant to tt__ and representing them as tt__(t__) in the equations below
    // note: t_current contains also non-aggregated t_ that are needed for mapping
    option clear = tt__;
    tt__(t_current(t)) $ {ord(t) <= t_solvefirst + tmp} = yes;

    // expanding tt_aggregate_historical to cover current t_ and t__ to allow correct mapping of all historical t to current t_
    tt_aggregate_historical(tt_(t_), tt__(t__)) $ {tt_aggregate(t_, t__)} = yes;


    // mapping historical t that get delayed to t_ in the current solve
    map_delay_gnutt(gnu_delay(grid, node, unit), tt(t), tt_(t_))
        $ { tt_aggregate_historical(t_, t + [p_gnu(grid, node, unit, 'delay')/mSettings(mSolve, 'stepLengthInHours')] )
            or tt_aggregate_historical(t_, t + [p_gnu(grid, node, unit, 'delay')/mSettings(mSolve, 'stepLengthInHours')
                                                + mInterval(mSolve, 'stepsPerInterval', 'c000')] )
            }
        = yes;

    // calculating how many timesteps from each historical t are delayd to each current t_
    p_delay_gnutt(map_delay_gnutt(grid, node, unit, tt(t), tt_(t_)))
        = + sum(tt_aggregate_historical(t_, tt__(t__))
                  $ { tt_aggregate_historical(t, t__ - [p_gnu(grid, node, unit, 'delay')/mSettings(mSolve, 'stepLengthInHours')] )
                  },
              1); // END sum(tt_aggregate)

* --- removing delay mappings if delay parameter was zero ---------------------

    // clearing map_delay_gnutt if p_delay_gnutt is zero
    map_delay_gnutt(gnu_delay, t, t_)
        $ { not p_delay_gnutt(gnu_delay, t, t_)
            }
        = no;

); // END if(p_gnu(gnu, 'delay'))
