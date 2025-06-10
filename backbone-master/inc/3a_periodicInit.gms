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

Contents
 - Preliminary adjustments and checks requiring info from initFile
 - Scaling factors
 - Generate model structure from input data and model definition files
 - Reducing the amount of dummy variables
 - Initialize Unit Efficiency Approximations
 - Initialize Unit Startup and Shutdown Counters
 - Converting Price Data to Price Change Data
 - Price, Emission Price, VomCosts, and Startup Costs
 - Price, Emission Price, VomCosts, and Startup Costs - New Method
 - Alternative time series circulation rules
 - Model Parameter Validity Checks

$offtext


* =============================================================================
* --- Preliminary adjustments and checks requiring info from initFile ---------
* =============================================================================

* --- model type --------------------------------------------------------------

// Abort model run if more than one model type is defined - unsupported at the moment
if(sum(m$mType(m), 1) > 1,
    abort "Backbone does not currently support more than one model type - you have defined more than one m";
);

// clear 'boundForecastEnds' from unused mType
mSettings(mType, 'boundForecastEnds')$(not mSolve(mType)) = 0;


* --- Forecasts ---------------------------------------------------------------

// setting realized forecast
mf_realization(m, 'f00') = yes;


* --- effLevel expansion if possible ------------------------------------------

// drop effLevelGroupUnit data not required by init file
effLevelGroupUnit(effLevel, effSelector, unit)
    ${ not sum(m, mSettingsEff(m, effLevel)) }
    = no;

// units that have at least one effLevel definition
option unit_tmp < effLevelGroupUnit;
// assuming directOff as default conversion type if none given
effLevelGroupUnit(effLevel, 'directOff', unit)
    $ { not unit_deactivated(unit)            // is active unit
        and sum(m, mSettingsEff(m, effLevel)) // is active effLevel
        and not unit_tmp(unit) // unit not originally present in effLevelGroupUnit
        and not unit_flow(unit) // excluding flow units
        }
    = yes;

// Find the largest effLevel used in the data
tmp = smax(effLevelGroupUnit(effLevel, effSelector, unit), ord(effLevel));
// Expand the effLevelGroupUnit when possible, abort if impossible
loop(effLevel${ ord(effLevel)<=tmp },
    effLevelGroupUnit(effLevel, effSelector, unit)
        ${not sum(effLevelGroupUnit(effLevel, effSelector_, unit), 1)}
        = effLevelGroupUnit(effLevel - 1, effSelector, unit) // Expand previous (effLevel, effSelector) when applicable
    loop(unit${not unit_flow(unit) and not unit_deactivated(unit)},
        If(not sum(effLevelGroupUnit(effLevel, effSelector, unit), 1),
            put log '!!! Error on unit ' unit.tl:0 /;
            put log '!!! Abort: Insufficient effLevelGroupUnit definitions!' /;
            abort "Insufficient effLevelGroupUnit definitions!"
            ); // END if
        ); // END loop(unit)
    ); // END loop(effLevel)


* --- Units that need ramp equations ------------------------------------------

// gnu affected by rampUpCost
gnu_rampUpCost(gnu)
    ${p_gnu(gnu, 'rampUpCost')                                                     // if gnu has rampUpCost
      or sum(upwardSlack(slack), p_gnuBoundaryProperties(gnu, slack, 'rampCost'))   // if piecewise rampUpCost is activated
      }
    = yes;

// gnu affected by maxRampUp, rampUpCost, or userconstraint('v_genRampUp')
gnu_rampUp(gnu(grid, node, unit))
    ${not unit_deactivated(unit)
      and not unit_flow(unit)
      and [[p_gnu(grid, node, unit, 'maxRampUp')                                                            // if maxRampUp given and
            and p_gnu(grid, node, unit, 'maxRampUp') * 60 * sum(m, mSettings(m, 'stepLengthInHours'))  < 1  // maxRampUp/hour * stepLengthInHours is less than 100%
            ]
           or gnu_rampUpCost(grid, node, unit)                                                              // if rampUpCost
           or sum(group, p_userconstraint(group, grid, node, unit, '-', 'v_genRampUp'))                     // if v_genRampUp is used in userconstraint
           ]
      }
    = yes;

// gnu affected by rampDownCost
gnu_rampDownCost(gnu)
    ${p_gnu(gnu, 'rampDownCost')                                                     // if gnu has rampDownCost
      or sum(downwardSlack(slack), p_gnuBoundaryProperties(gnu, slack, 'rampCost')) // if piecewise rampDownCost is activated
      }
    = yes;

// gnu affected by maxRampDown, rampDownCost, or userconstraint('v_genRampDown')
gnu_rampDown(gnu(grid, node, unit))
    ${not unit_deactivated(unit)
      and not unit_flow(unit)
      and [[p_gnu(grid, node, unit, 'maxRampDown')                                                             // if maxRampDown given and
            and p_gnu(grid, node, unit, 'maxRampDown') * 60 * sum(m, mSettings(m, 'stepLengthInHours'))  < 1   // maxRampDown/hour * stepLengthInHours is less than 100%
            ]
           or gnu_rampDownCost(grid, node, unit)                                                               // if rampDownCost
           or sum(group, p_userconstraint(group, grid, node, unit, '-', 'v_genRampDown'))                      // if v_genRampDown is used in userconstraint
           ]
      }
    = yes;


* --- Disable reserves according to model definition --------------------------

loop(m,

    // Disable group reserve requirements
    restypeDirectionGroup(restype, up_down, group)
        ${  not mSettingsReservesInUse(m, restype, up_down)
            }
        = no;
    groupRestype(group, restype) = sum(up_down, restypeDirectionGroup(restype, up_down, group));
    restypeDirectionGridNodeGroup(restype, up_down, grid, node, group)
        ${  not mSettingsReservesInUse(m, restype, up_down)
            }
        = no;

    // Disable node reserve requirements
    restypeDirectionGridNode(restype, up_down, grid, node)
        ${  not mSettingsReservesInUse(m, restype, up_down)
            }
        = no;

    // Disable node-node reserve connections
    restypeDirectionGridNodeNode(restype, up_down, grid, node, node_)
        ${  not mSettingsReservesInUse(m, restype, up_down)
            }
      = no;

    // Disable reserve provision capability from units
    gnu_resCapable(restype, up_down, grid, node, unit)
        ${  not mSettingsReservesInUse(m, restype, up_down)
            }
      = no;
); // END loop(m)


* --- Using default value for reserves update frequency -----------------------

loop(m,
    p_groupReserves(group, restype, 'update_frequency')${  not p_groupReserves(group, restype, 'update_frequency')
                                                           and sum(up_down, restypeDirectionGroup(restype, up_down, group))  }
        = mSettings(m, 't_jump');
    p_gnReserves(grid, node, restype, 'update_frequency')${  not p_gnReserves(grid, node, restype, 'update_frequency')
                                                             and sum(up_down, restypeDirectionGridNode(restype, up_down, grid, node))  }
        = mSettings(m, 't_jump');
);


* --- Penalty Values ----------------------------------------------------------

// Reading penalty values first from debug gdx,
// then command line option %penalty%,
// finally assuming 1e4 or 1e6 for invest model if no other data available.

$ifthen set input_file_debugGdx
    $$gdxin '%input_dir%/%input_file_debugGdx%'
    $$loadr PENALTY
    $$loadr PENALTY_BALANCE
    $$gdxin
$elseif set penalty
    PENALTY=%penalty%;
$else
    // assuming default penalty 1e4 if no data from previous steps
    PENALTY=1e4;

    // Giving 100x higher default penalty for the invest runs as
    // capacity expansion is more likely to have dummies than schedule
    if (mSolve('invest'),
        PENALTY = 1e6;
    );

$endif

// Calculating PENALTY_BALANCE unless alreay read from input debug file
$ifthen not set input_file_debugGdx
    // PENALTY_BALANCE is either user given gn specific data or PENALTY
    PENALTY_BALANCE(gn(grid, node)) = p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'constant')
                                      + PENALTY${not p_gnBoundaryPropertiesForStates(grid, node, 'balancePenalty', 'useConstant')};
$endif


*Calculating other penalty values
BIG_M = PENALTY * 10;
PENALTY_GENRAMP(gnu_rampUp(grid, node, unit)) = 0.9*PENALTY;
PENALTY_GENRAMP(gnu_rampDown(grid, node, unit)) = 0.9*PENALTY;
PENALTY_RES(restypeDirection(restype, up_down)) = 0.9*PENALTY;
PENALTY_RES_MISSING(restypeDirection(restype, up_down)) = 0.7*PENALTY;
PENALTY_CAPACITY(gn(grid, node)) = 0.8*PENALTY;


PENALTY_UC(group_uc)
= p_userconstraint(group_uc, '-', '-', '-', '-', 'penalty')
  + PENALTY${not p_userconstraint(group_uc, '-', '-', '-', '-', 'penalty')};




* --- Rounding parameters -----------------------------------------------------

// automatic rounding rules
if(sum(m, mSettings(m, 'automaticRoundings'))= 1,

    // variable costs with precision of 0,01 EUR
    if(p_roundingParam('p_VomCost')=0, p_roundingParam('p_VomCost') = 2; );
    if(p_roundingParam('p_linkVomCost')=0, p_roundingParam('p_linkVomCost') = 2; );
    if(p_roundingParam('p_reservePrice')=0, p_roundingParam('p_reservePrice') = 2; );
    if(p_roundingTs('ts_vomCost_')=0, p_roundingTs('ts_vomCost_') = 2; );
    if(p_roundingTs('ts_linkVomCost_')=0, p_roundingTs('ts_linkVomCost_') = 2; );
    if(p_roundingTs('ts_reservePrice_')=0, p_roundingTs('ts_reservePrice_') = 2; );

    // startup costs and storage value with precision of 0,1 EUR
    if(p_roundingParam('p_startupCost')=0, p_roundingParam('p_startupCost') = 1; );
    if(p_roundingTs('ts_startupCost_')=0, p_roundingTs('ts_startupCost_') = 1; );
    if(p_roundingTs('ts_storageValue_')=0, p_roundingTs('ts_storageValue_') = 1; );

    // influx, reserve demand, and storage limits with precision of 0,01
    if(p_roundingTs('ts_influx_')=0, p_roundingTs('ts_influx_') = 2; );
    if(p_roundingTs('ts_reserveDemand_')=0, p_roundingTs('ts_reserveDemand_') = 2; );
    if(p_roundingTs('ts_node_')=0, p_roundingTs('ts_node_') = 2; );

    // unit cf and transmission availability factors with precision of 0,00001
    if(p_roundingTs('ts_cf_')=0, p_roundingTs('ts_cf_') = 5; );
    if(p_roundingTs('ts_gnn_')=0, p_roundingTs('ts_gnn_') = 5; );

    // ts_unit_ not rounded by default, because efficiency time series should not be rounded.
    // Users can activate ts_unit rounding separately after testing the impact on results

); // END if('automaticRoundings')


* --- Reducing the amount of dummy variables ----------------------------------

// pointing general rule to more specific ones unless more specific ones are already given
loop(m,
    if(mSettings(m, 'reducedDummies')>= 1,
        // vq_gen
        if(not mSettings(m, 'reducedVqGen'),
            mSettings(m, 'reducedVqGen') = mSettings(m, 'reducedDummies');
        );
        if(not mSettings(m, 'reducedVqGenRamp'),
            mSettings(m, 'reducedVqGenRamp') = mSettings(m, 'reducedDummies');
        );
        // vq_resDemand
        if(not mSettings(m, 'reducedVqResDemand'),
            mSettings(m, 'reducedVqResDemand') = mSettings(m, 'reducedDummies');
        );
        // vq_resMissing
        if(not mSettings(m, 'reducedVqResMissing'),
            mSettings(m, 'reducedVqResMissing') = mSettings(m, 'reducedDummies');
        );
        // vq_unitConstraint
        if(not mSettings(m, 'reducedVqUnitConstraint'),
            mSettings(m, 'reducedVqUnitConstraint') = mSettings(m, 'reducedDummies');
        );
        // vq_userconstraint
        if(not mSettings(m, 'reducedVqUserconstraint'),
            mSettings(m, 'reducedVqUserconstraint') = mSettings(m, 'reducedDummies');
        );
    ); // END if(mSettings('reducedDummies'))
); // END loop(m)


* =============================================================================
* --- Scaling factors ---------------------------------------------------------
* =============================================================================

// pick scaling method to tmp
tmp = sum(m, mSettings(m, 'scalingMethod'));

// default scaling factor
if(tmp > 0,
    tmp_= 10**(tmp);

* --- nodes -------------------------------------------------------------------
    // tmp_ by default
    p_scaling_n(node) = tmp_;

    // f and t in ts_node and ts_influx for faster calculation of node specific scaling factors
    if(tmp > 0,
        // f and t in ts_node
        option ff < ts_node;
        option tt < ts_node;

        // f and t in ts_influx
        option ff_ < ts_influx;
        option tt_ < ts_influx;
    );

    // Adjusting scaling factors for storages
    // loop gn_state if scalingMethod is set, check the highest upwardLimits, increase scalingFactor if 100x the current factor
    loop(gn(grid, node)
        ${gn_state(grid, node)
          or gn_influx(grid, node)
          },

        // largest storage upward limit
        tmp__ = + [p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
                    * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
                    ] $ p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')
                + [smax((ff, tt), ts_node(grid, node, 'upwardLimit', ff, tt))
                    * p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'multiplier')
                    ] $ p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeseries');

        // Increased scaling factor for very large (100x) storages
        if((tmp__ > 100 * tmp_),
            p_scaling_n(node) = tmp_ * 10;
        ); // END if

    ); // END loop(gn)

* --- units -------------------------------------------------------------------
    // tmp_ by default
    p_scaling_u(unit)
        ${sum(node, nu(node, unit))} = tmp_; // is active unit

    // Decrease scaling factor for units
    // if flow unit, due to common multiplication with small ts_cf factors
    p_scaling_u(unit)
        ${sum(node, nu(node, unit))  // is active unit
          and unit_flow(unit)}       // is flow unit
        = tmp_ / 10;

    // Increase scaling factor for units
    // if unitSize much larger than applied scaling factor
    p_scaling_u(unit)
        ${not unit_flow(unit)
          and smax(gn, p_gnu(gn, unit, 'unitsize')) > tmp_ * 100
          }
        = tmp_ * 10;

* --- transfer links, etc -----------------------------------------------------

    // transfer links
    p_scaling_nn(node, node_)
        $sum(grid, p_gnn(grid, node, node_, 'isActive'))
        = tmp_;

    // scaling factor for objective
    p_scaling_obj = tmp_;

    // general scaling factor
    p_scaling = tmp_;

);  // end if(tmp)


* =============================================================================
* --- Generate model structure from input data and model definition files -----
* =============================================================================

// Initialize various sets
Option clear = t_full;
Option clear = f_active;

// Loop over m
loop(m,

* --- Time Steps within Model Horizon -----------------------------------------

    // the first t for faster if checks
    t_start(t)${ ord(t) = mSettings(m, 't_start') } = yes;

    // Determine the full set of timesteps to be considered by the defined simulation
    // from t000000 -> 1
    // to the beginning of last solve including horizon -> t_end - t_jump + t_horizon
    t_full(t)${ ord(t) <= 1 + mSettings(m, 't_end') - mSettings(m, 't_jump')  + mSettings(m, 't_horizon')    // +1 because ord(t000001)=2
                }
        = yes;
    if(mSettings(m, 't_jump') > mSettings(m, 't_end'),
        mSettings(m, 't_jump') = mSettings(m, 't_end');
        put log "!!! t_jump was larger than t_end. t_jump was decreased to t_end."/
    );
    if(mod(mSettings(m, 't_end') - mSettings(m, 't_start') + 1, mSettings(m, 't_jump')) > 0,
        tmp = mSettings(m, 't_end');
        tmp_ = mSettings(m, 't_start');
        tmp__ = mSettings(m, 't_jump');
        put log "!!! Abort: [t_end (" tmp:0:0 ") - t_start (" tmp_:0:0 ") + 1] is not divisible by t_jump (" tmp__:0:0 ")" /;
        abort "(t_end - t_start + 1) is not divisible by t_jump";
    );

    // Determine maximum data length, if not provided in the model definition file.
    if(not mSettings(m, 'dataLength'),
        // raise warning
        if(%warnings%=1,
            put log 'Note: mSettings(m, dataLength) is not defined, calculating dataLength based on ts_influx, ts_node, and ts_cf.' /;
        );

        // Calculate the length of the time series data based on ts_influx, ts_node, and ts_cf
        option tt < ts_influx; // t in ts_influx
        option tt_ < ts_node;  // t in ts_node

        // combining
        tt(t_full(t))$tt_(t) = yes;

        option tt_ < ts_cf;  // t in ts_cf

        // combining
        tt(t_full(t))$tt_(t) = yes;

        // Find the maximum ord(t) defined in time series data.
        tmp = smax(tt(t_full(t)), ord(t));
        tmp = tmp - 1; // reduce by one to account for t000000

        // printing the found value, setting it to mSettings(m, 'dataLength')
        if(%warnings%=1,
            put log "      Setting mSettings(m, 'dataLength') to " tmp:0:0 /;
        );
        mSettings(m, 'dataLength') = tmp;
    ); // END if(mSettings(dataLength))

    // Determine the full set of timesteps within datalength
    t_datalength(t_full(t))${ ord(t) >= mSettings(m, 't_start')+1
                and ord(t) <= mSettings(m, 'dataLength')+1
                }
        = yes;

    // Circular displacement of time index for data loop
    tmp = mSettings(m, 'dataLength')+1;
    dt_circular(t_full(t))${ ord(t) > tmp }
        = - (tmp - 1) // (tmp - 1) used in order to not circulate initial values at t000000
            * floor(ord(t) / (tmp));


* --- Samples and Forecasts ---------------------------------------------------
$ontext
    // Check that forecast length is feasible
    if(mSettings(m, 't_forecastLength') > mSettings(m, 't_horizon'),
        abort "t_forecastLength should be less than or equal to t_horizon";
    );
$offtext

    // Set the time for the next available forecast.
    tForecastNext(m) = mSettings(m, 't_forecastStart');

    // Select samples for the model
    if (not sum(s, ms(m, s)),  // unless they have been provided as input
        ms(m, s)$(ord(s) <= mSettings(m, 'samples')) = yes;
    );

    // Set active samples and sample length in hours
    loop(ms(m, s),
        s_active(s) = yes;
        p_sLengthInHours(s) = (msEnd(m, s) - msStart(m, s))* mSettings(m, 'stepLengthInHours');
    );

    // Select forecasts in use for the models
    if (not sum(f, mf(m, f)),  // unless they have been provided as input
        mf(m, f)$(ord(f) <= 1 + mSettings(m, 'forecasts')) = yes;  // realization needs one f, therefore 1 + number of forecasts
    );

    // Select the forecasts included in the modes to be solved
    f_active(f)${mf(m,f) and p_mfProbability(m, f)}
        = yes;

    // if only one active forecast, deactive forecasts
    if(card(f_active)=1,
        option clear = unit_forecasts;
        option clear = gn_forecasts;
    ); // END if

    // initializing realization and central forecasts
    option f_realization < mf_realization;
    option f_central < mf_central;

    // Displacement to reach the realized forecast
    Option clear = df_realization;
    loop(mf_realization(m, f_),
        df_realization(f_active(f)) = ord(f_) - ord(f);
    );

    // Select combinations of models, samples and forecasts to be solved
    sf(s_active(s), f_active(f))$mf(m, f) = yes;

    // Initial values included into realized time steps
    sft_realizedNoReset(s, f, t_start(t))${ sf(s, f) and mf_realization(m, f) } = yes;
    option ft_realizedNoReset < sft_realizedNoReset;
    option t_realizedNoReset < sft_realizedNoReset;

    // Check the modelSolves for preset patterns for model solve timings
    // If not found, then use mSettings to set the model solve timings
    if(sum(modelSolves(m, t_full(t)), 1) = 0,
        t_skip_counter = 0;
        loop(t_full(t)${ ord(t) = mSettings(m, 't_start') + mSettings(m, 't_jump') * t_skip_counter
                        and ord(t) <= mSettings(m, 't_end')
                        },
            modelSolves(m, t) = yes;

            // Increase the t_skip counter
            t_skip_counter = t_skip_counter + 1;
        );
    );


* --- Counters needed by the model --------------------------------------------

    tmp = 0;

    loop(unit${ p_unit(unit,'op00')
                and ( p_unit(unit, 'rampSpeedToMinLoad')
                      or p_unit(unit, 'rampSpeedFromMinLoad')
                      or p_unit(unit, 'minShutdownHours')
                      or p_unit(unit, 'minOperationHours')
                      or p_unit(unit, 'startColdAfterXhours')
                     )
               },
        tmp = max(tmp,  p_unit(unit, 'minOperationHours'));
        tmp = max(tmp,  ceil(p_unit(unit, 'minShutdownHours') / mSettings(m, 'stepLengthInHours'))
                        + ceil([p_unit(unit,'op00') / (p_unit(unit, 'rampSpeedToMinLoad') * 60) ] / mSettings(m, 'stepLengthInHours') ) $ p_unit(unit, 'rampSpeedToMinLoad')  // NOTE! Check this
                        + ceil([p_unit(unit,'op00') / (p_unit(unit, 'rampSpeedFromMinLoad') * 60) ] / mSettings(m, 'stepLengthInHours') ) $ p_unit(unit, 'rampSpeedFromMinLoad')// NOTE! Check this
                    );
        tmp = max(tmp,  p_unit(unit, 'startColdAfterXhours'));
    );


*    counter(counter_large) = yes;

    counter(counter_large) $ { sum(mSolve, mInterval(mSolve, 'lastStepInIntervalBlock', counter_large))
                               or (ord(counter_large) <= tmp)
                             }
    = yes;


    // Determine the set of active interval counters (or blocks of intervals)
    counter_intervals(counter)${ mInterval(m, 'stepsPerInterval', counter) }
        = yes;


* --- Interval checks ---------------------------------------------------------

    // setting tmp to 1 for comparison of interval block order
    tmp = 1;

    // Check whether the defined intervals are feasible
    loop(counter_intervals(counter_large),
        // check if intervals are defined in order
        if(ord(counter_large) <> tmp,
            put log "!!! Error occurred on interval block ", counter_large.tl:0 /;
            put log "!!! Abort: Interval counters are not defined in order, check mInterval from scheduleInit/investInit."
            abort "Interval counters are not defined in order, check mInterval from scheduleInit/investInit.";
        );   // END if
        // increasing tmp by 1
        tmp = tmp + 1;

        // check that each interval block has 'lastStepInIntervalBlock' defined
        if(mInterval(m, 'lastStepInIntervalBlock', counter_large) < 1,
            put log "!!! Error occurred on interval block ", counter_large.tl:0 /;
            put log '!!! Abort: lastStepInIntervalBlock is not defined! Check mInterval from scheduleInit/investInit.' /;
            abort "stepsPerInterval < 1 is not defined!";
        );  // END IF lastStepInIntervalBlock

        // check if interval length is divisible by step per interval
        if(mod(mInterval(m, 'lastStepInIntervalBlock', counter_large) - mInterval(m, 'lastStepInIntervalBlock', counter_large-1), mInterval(m, 'stepsPerInterval', counter_large)),
            put log "!!! Error occurred on interval block ", counter_large.tl:0 /;
            put log "!!! Abort: stepsPerInterval is not evenly divisible within the interval! Check mInterval from scheduleInit/investInit."
            abort "stepsPerInterval is not evenly divisible within the interval";
        );   // END if

        // Abort if stepsPerInterval is less than one
        if(mInterval(m, 'stepsPerInterval', counter_large) < 1,
            put log "!!! Error occurred on interval block ", counter_large.tl:0 /;
            put log '!!! Abort: stepsPerInterval is not defined! Check mInterval from scheduleInit/investInit.' /;
            abort "stepsPerInterval is not defined!";
        );  // END IF stepsPerInterval
    );

); // END loop(m)


* =============================================================================
* --- Reducing the amount of vqGen --------------------------------------------
* =============================================================================

// filtering nodes where the amount of vqGens can be reduced if mSettings(m, 'reducedVqGen') >= 1
if(sum(m, mSettings(m, 'reducedVqGen')) >= 1,
    // vq_gen(inc_dec) needs to be generated for gn with node balance and

    // negative or positive influx
    loop(gn_balance(grid, node) $ gn_influx(grid, node),
        vqGenInc_gn(grid, node)
            ${gn_influxTs(grid, node)
              and smin( (f_active(f), t_dataLength(t)), ts_influx(grid, node, f, t)) < 0 }
            = yes;

        vqGenInc_gn(grid, node)
            ${not gn_influxTs(grid, node)
              and p_gn(grid, node, 'influx') < 0 }
            = yes;

        vqGenDec_gn(grid, node)
            ${gn_influxTs(grid, node)
              and smax( (f_active(f), t_dataLength(t)), ts_influx(grid, node, f, t)) > 0 }
            = yes;

        vqGenDec_gn(grid, node)
            ${not gn_influxTs(grid, node)
              and p_gn(grid, node, 'influx') > 0 }
            = yes;

    ); // END loop(grid, node)

    // fixed flow units as input or output
    vqGenInc_gn(gn_balance(grid, node)) $
        {sum(gnu_input(grid, node, unit), p_unit(unit, 'fixedFlow') * p_gnu(grid, node, unit, 'capacity'))
         or sum(gnu_input(grid, node, unit), p_unit(unit, 'fixedFlow') * p_gnu(grid, node, unit, 'unitSize'))
         }
        = yes;
    vqGenDec_gn(gn_balance(grid, node)) $
        {sum(gnu_output(grid, node, unit), p_unit(unit, 'fixedFlow') * p_gnu(grid, node, unit, 'capacity'))
         or sum(gnu_output(grid, node, unit), p_unit(unit, 'fixedFlow') * p_gnu(grid, node, unit, 'unitSize'))
         }
        = yes;

$ontext
    // MIP, incHR, or lambda units as input or output
    vqGenInc_gn(gn_balance(grid, node)) $
        {sum( (effLevel, gnu_input(grid, node, unit)), effLevelGroupUnit(effLevel, 'directOnMIP', unit) )
         or sum( (effLevel, gnu_input(grid, node, unit)), effLevelGroupUnit(effLevel, 'incHR', unit) )
         or sum( (effLevel, gnu_input(grid, node, unit)), effLevelGroupUnit(effLevel, 'lambda01', unit) )
         }
        = yes;
    vqGenDec_gn(gn_balance(grid, node)) $
        {sum( (effLevel, gnu_output(grid, node, unit)), effLevelGroupUnit(effLevel, 'directOnMIP', unit) )
         or sum( (effLevel, gnu_output(grid, node, unit)), effLevelGroupUnit(effLevel, 'incHR', unit) )
         or sum( (effLevel, gnu_output(grid, node, unit)), effLevelGroupUnit(effLevel, 'lambda01', unit) )
         }
        = yes;
$offtext

    // downwardLimit or upwardLimit time series
    vqGenInc_gn(gn_balance(grid, node)) $
        {p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeSeries')
         }
        = yes;
    vqGenDec_gn(gn_balance(grid, node)) $
        {p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeSeries')
         }
        = yes;

    // boundSumOverInterval or boundStartToEnd
    vqGenInc_gn(gn_balance(grid, node)) $
        {p_gn(grid, node, 'boundSumOverInterval')
         or p_gn(grid, node, 'boundStartToEnd')
         }
        = yes;
    vqGenDec_gn(gn_balance(grid, node)) $
        {p_gn(grid, node, 'boundSumOverInterval')
         or p_gn(grid, node, 'boundStartToEnd')
         }
        = yes;

    // creating dropVqGen_gn sets from vqGen_gn sets
    dropVqGenInc_gn(gn_balance(grid, node)) $ {not vqGenInc_gn(grid, node)} = yes;
    dropVqGenDec_gn(gn_balance(grid, node)) $ {not vqGenDec_gn(grid, node)} = yes;

); // END if(mSettings('reducedVqGen'))


* =============================================================================
* --- Initialize Unit Efficiency Approximations -------------------------------
* =============================================================================

loop(m,

* --- Unit Aggregation --------------------------------------------------------

    unitAggregator_unit(unit, unit_)$sum(effLevel$(mSettingsEff(m, effLevel)), unitUnitEffLevel(unit, unit_, effLevel)) = yes;

    // Define unit aggregation sets
    unit_aggregator(unit)${ sum(unit_, unitAggregator_unit(unit, unit_)) }
        = yes; // Set of aggregator units
    unit_aggregated(unit)${ sum(unit_, unitAggregator_unit(unit_, unit)) }
        = yes; // Set of aggregated units

    // Process data for unit aggregations
    // Aggregate output as the sum of capacity
    p_gnu(grid, node, unit_aggregator(unit), 'capacity')
        = sum(unit_$unitAggregator_unit(unit, unit_),
            + p_gnu(grid, node, unit_, 'capacity')
            );

* --- Calculate 'lastStepNotAggregated' for aggregated units and aggregator units ---

    loop(effLevel$mSettingsEff(m, effLevel),
        loop(effLevel_${mSettingsEff(m, effLevel_) and ord(effLevel_) < ord(effLevel)},
            p_unit(unit_aggregated(unit), 'lastStepNotAggregated')${ sum(unit_,unitUnitEffLevel(unit_, unit, effLevel)) }
                = mSettingsEff(m, effLevel_);
            p_unit(unit_aggregator(unit), 'lastStepNotAggregated')${ sum(unit_,unitUnitEffLevel(unit, unit_, effLevel)) }
                = mSettingsEff(m, effLevel_);
        );
    );
);

* --- Ensure that efficiency levels extend to the end of the model horizon and do not go beyond ---

loop(m,
    // First check how many efficiency levels there are and cut levels going beyond the t_horizon
    tmp = 0;
    loop(effLevel$mSettingsEff(m, effLevel),
        continueLoop = ord(effLevel);
        // Check if the level extends to the end of the t_horizon
        if (mSettingsEff(m, effLevel) = mSettings(m, 't_horizon'),
            tmp = 1;
        );
        if (mSettingsEff(m, effLevel) > mSettings(m, 't_horizon'),
            // Cut the first level going beyond the t_horizon (if the previous levels did not extend to the t_horizon)
            if (tmp = 0,
                mSettingsEff(m, effLevel) = mSettings(m, 't_horizon');
                tmp = 1;
                put log 'Note: The length of the last effLevel is longer than t_horizon. Setting mSettingsEff(', m.tl:0, ', ', effLevel.tl:0, ') to ', mSettings(m, 't_horizon'):0:0 /;
            // Remove other levels going beyond the t_horizon
            else
                mSettingsEff(m, effLevel) = no;
                put log '!!! Warning: Removing mSettingsEff(', m.tl:0, ', ', effLevel.tl:0, '), because it starts after the t_horizon' /;
            );
        );
    );
    // Ensure that that the last active level extends to the end of the t_horizon
    if ( tmp = 0,
        mSettingsEff(m, effLevel)${ord(effLevel) = continueLoop} = mSettings(m, 't_horizon');
        put log 'Note: The last active effLevel does not reach to the end of the t_horizon. Setting mSettingsEff(', m.tl:0, ', level', continueLoop, ') to ', mSettings(m, 't_horizon'):0:0 /;
    );
    // Remove effLevels with same end time step (keep the last one)
    loop(effLevel$mSettingsEff(m, effLevel),
        loop(effLevel_${mSettingsEff(m, effLevel_) and ord(effLevel) <> ord(effLevel_)},
            if (mSettingsEff(m, effLevel_) = mSettingsEff(m, effLevel),
                mSettingsEff(m, effLevel) = no;
                put log '!!! Removed mSettingsEff(', m.tl:0, ', ', effLevel.tl:0, ')' /;
            );
        );
    );
    // Store the first time step of the effLevel
    loop(effLevel$mSettingsEff(m, effLevel),
        loop(effLevel_${mSettingsEff(m, effLevel_) and ord(effLevel_) < ord(effLevel)},
            mSettingsEff_start(m, effLevel) = mSettingsEff(m, effLevel_) + 1;
        );
    );
);

* --- Units with online variables in the first active effLevel  ---------------

loop(m,
    continueLoop = 0;
    loop(effLevel$mSettingsEff(m, effLevel),
        continueLoop = continueLoop + 1;
        if (continueLoop = 1,
            unit_online(unit)${ sum(effSelector$effOnline(effSelector), effLevelGroupUnit(effLevel, effSelector, unit)) }
                = yes;
            unit_online_LP(unit)${ sum(effSelector, effLevelGroupUnit(effLevel, 'directOnLP', unit)) }
                = yes;
            unit_online_MIP(unit) = unit_online(unit) - unit_online_LP(unit);
        );
    );
);

* --- Parse through effLevelGroupUnit and convert selected effSelectors into sets representing those selections

// Loop over effLevelGroupUnit(DirectOff)
loop(effLevelGroupUnit(effLevel, effSelector, unit)${sum(m, mSettingsEff(m, effLevel)) and effDirectOff(effSelector)},
    effGroupSelectorUnit(effDirectOff(effSelector), unit, effSelector) = yes;
); // END loop(effLevelGroupUnit)

// Loop over effLevelGroupUnit(DirectOn)
loop(effLevelGroupUnit(effLevel, effSelector, unit)${sum(m, mSettingsEff(m, effLevel)) and effDirectOn(effSelector)},
    effGroupSelectorUnit(effDirectOn(effSelector), unit, effSelector) = yes;
); // END loop(effLevelGroupUnit)

// Loop over effLevelGroupUnit(IncHR)
loop(effLevelGroupUnit(effLevel, effSelector, unit)${sum(m, mSettingsEff(m, effLevel)) and effIncHR(effSelector)},
    effGroupSelectorUnit(effIncHR(effSelector), unit, effSelector) = yes;
); // END loop(effLevelGroupUnit)

// Loop over effLevelGroupUnit(Lambda)
loop(effLevelGroupUnit(effLevel, effSelector, unit)${sum(m, mSettingsEff(m, effLevel)) and effLambda(effSelector)},
    loop(effLambda_${ord(effLambda_) <= ord(effSelector)},
        effGroupSelectorUnit(effLambda(effSelector), unit, effLambda_) = yes;
        ); // END loop(effLambda_)
); // END loop(effLevelGroupUnit)

// populating effGroup and effGroupSelector based on previous loops
option effGroup<effGroupSelectorUnit;
option effGroupSelector<effGroupSelectorUnit;


* --- Check that online unit efficiency approximations have sufficient data ----

loop(unit_online(unit),
    // Check that directOnLP and directOnMIP units have least one opXX or hrXX defined
    if(sum(op, p_unit(unit, op)) + sum(hr, p_unit(unit, hr))= 0,
          put log '!!! Error occurred on unit ' unit.tl:0 /; // Display unit that causes error
          put log '!!! Abort: Units with online variable, e.g. DirectOnLP and DirectOnMIP, require opXX (or hrXX) parameters! Check data in p_unit.' /;
          abort "Units with online variable, e.g. DirectOnLP and DirectOnMIP, require opXX (or hrXX) parameters! Check data in p_unit.";
       ); // END if(op + hr)

    // Check that directOnLP and directOnMIP units have least two effXX defined
    if(sum(eff$p_unit(unit, eff), 1) < 2,
          put log '!!! Error occurred on unit ' unit.tl:0 /; // Display unit that causes error
          put log '!!! Abort: Units with online variable, e.g. DirectOnLP and DirectOnMIP, require two efficiency definitions (effXX)! Check data in p_unit.' /;
          abort "Units with online variable, e.g. DirectOnLP and DirectOnMIP, require two efficiency definitions (effXX)! Check data in p_unit.";
       ); // END if(eff > 2)

    // check that 'eff's are defined in order
    count = 1; // reset count
    loop(eff $ p_unit(unit, eff),
        if(count <> ord(eff),
            put log '!!! Error occurred on unit: ' unit.tl:0 ', eff: ' eff.tl:0 /; // Display unit and effXX that causes error
            put log '!!! Abort: Units with online variable, e.g. DirectOnLP and DirectOnMIP, require that param_unit effXX must be defined in order starting from eff00! Check data in p_unit.' /;
            abort "Units with online variable, e.g. DirectOnLP and DirectOnMIP, require that param_unit effXX must be defined in order starting from eff00! Check data in p_unit.";
        ); // END if (count <> eff)
        count= count+1;
    ); // END loop(op)

    // check that 'eff's have matching opXX from eff01 onwards
    loop(eff $ {p_unit(unit, eff) and ord(eff) > 1},
        if(not sum(op $ {p_unit(unit, op) and (ord(op) = ord(eff))}, 1),
            put log '!!! Error occurred on unit: ' unit.tl:0 ', eff: ' eff.tl:0 /; // Display unit and effXX that causes error
            put log '!!! Abort: Units with online variable, e.g. DirectOnLP and DirectOnMIP, must have matching opXX to definex effXX from eff01 onwards! Check data in p_unit.' /;
            abort "Units with online variable, e.g. DirectOnLP and DirectOnMIP, must have matching opXX to defined effXX from eff01 onwards! Check data in p_unit.";
        ); // END if (effXX <-> opXX)
    ); // END loop(eff)

); // END loop(unit_online)

* --- Loop over effGroupSelectorUnit to generate efficiency approximation parameters for units

// Parameters for direct conversion units without online variables
loop(effGroupSelectorUnit(effDirectOff(effSelector), unit, effSelector_),
    p_effUnit(effSelector, unit, effSelector, 'lb') = 0; // No min load for the DirectOff approximation
    p_effUnit(effSelector, unit, effSelector, 'op') = smax(op, p_unit(unit, op)); // Maximum operating point
    p_effUnit(effSelector, unit, effSelector, 'slope') = 1 / smax(eff${p_unit(unit, eff)}, p_unit(unit, eff)); // Uses maximum found (nonzero) efficiency.
    p_effUnit(effSelector, unit, effSelector, 'section') = 0; // No section for the DirectOff approximation
); // END loop(effGroupSelectorUnit)

// Parameters for direct conversion units with online variables
loop(effGroupSelectorUnit(effDirectOn(effSelector), unit, effSelector_),

    // Determine the last operating point in use for the unit
    Option clear = opCount;
    loop(op${   p_unit(unit, op)    },
        opCount = ord(op);
    ); // END loop(op)

    p_effUnit(effSelector, unit, effSelector_, 'lb') = p_unit(unit, 'op00'); // op00 contains the minimum load of the unit
    p_effUnit(effSelector, unit, effSelector_, 'op') = smax(op, p_unit(unit, op)); // Maximum load determined by the largest 'op' parameter found in data
    loop(op__$(ord(op__) = opCount), // Find the maximum defined 'op'.
        loop(eff__${ord(eff__) = ord(op__)}, // ...  and the corresponding 'eff'.

            // If the minimum operating point is at zero, then the section and slope are calculated with the assumption that the efficiency curve crosses at opFirstCross
            if(p_unit(unit, 'op00') = 0,

                // Heat rate at the cross between real efficiency curve and approximated efficiency curve
                // !!! NOTE !!! It is advised not to define opFirstCross as any of the op points to avoid accidental division by zero!
                heat_rate = 1 / [
                                + p_unit(unit, 'eff00')
                                    * [ p_unit(unit, op__) - p_unit(unit, 'opFirstCross') ]
                                    / [ p_unit(unit, op__) - p_unit(unit, 'op00') ]
                                + p_unit(unit, eff__)
                                    * [ p_unit(unit, 'opFirstCross') - p_unit(unit, 'op00') ]
                                    / [ p_unit(unit, op__) - p_unit(unit, 'op00') ]
                                ];

                // Unless section has been defined, it is calculated based on the opFirstCross
                p_effGroupUnit(effSelector, unit, 'section') = p_unit(unit, 'section');
                p_effGroupUnit(effSelector, unit, 'section')${ not p_effGroupUnit(effSelector, unit, 'section') }
                    = p_unit(unit, 'opFirstCross')
                        * ( heat_rate - 1 / p_unit(unit, eff__) )
                        / ( p_unit(unit, op__) - p_unit(unit, 'op00') );
                p_effUnit(effSelector, unit, effSelector_, 'slope')
                    = 1 / p_unit(unit, eff__)
                        - p_effGroupUnit(effSelector, unit, 'section') / p_unit(unit, op__);

            // If the minimum operating point is above zero, then the approximate efficiency curve crosses the real efficiency curve at minimum and maximum.
            else
                // Calculating the slope based on the first nonzero and the last defined data points.
                p_effUnit(effSelector, unit, effSelector_, 'slope')
                    = (p_unit(unit, op__) / p_unit(unit, eff__) - p_unit(unit, 'op00') / p_unit(unit, 'eff00'))
                        / (p_unit(unit, op__) - p_unit(unit, 'op00'));

                // Calculating the section based on the slope and the last defined point.
                p_effGroupUnit(effSelector, unit, 'section')
                    = ( 1 / p_unit(unit, eff__) - p_effUnit(effSelector, unit, effSelector_, 'slope') )
                        * p_unit(unit, op__);
            ); // END if(p_unit)
        ); // END loop(eff__)
    ); // END loop(op__)
); // END loop(effGroupSelectorUnit)


// Calculate lambdas
loop(effGroupSelectorUnit(effLambda(effSelector), unit, effSelector_),

    // Determine the last operating point in use for the unit
    Option clear = opCount;
    loop(op${   p_unit(unit, op)    },
        opCount = ord(op);
    ); // END loop(op)

    p_effUnit(effSelector, unit, effSelector_, 'lb') = p_unit(unit, 'op00'); // op00 contains the min load of the unit

    // Calculate the relative location of the operating point in the lambdas
    tmp_op = p_unit(unit, 'op00')
                + (ord(effSelector_)-1) / (ord(effSelector) - 1)
                    * (smax(op, p_unit(unit, op)) - p_unit(unit, 'op00'));
    p_effUnit(effSelector, unit, effSelector_, 'op') = tmp_op; // Copy the operating point to the p_effUnit

    // tmp_op falls between two p_unit defined operating points or then it is equal to one of them
    loop((op_, op__)${  (   [tmp_op > p_unit(unit, op_) and tmp_op < p_unit(unit, op__) and ord(op_) = ord(op__) - 1]
                            or [p_unit(unit, op_) = tmp_op and ord(op_) = ord(op__)]
                            )
                        and ord(op__) <= opCount
                        },
        // Find the corresponding efficiencies
        loop((eff_, eff__)${    ord(op_) = ord(eff_)
                                and ord(op__) = ord(eff__)
                                },
            // Calculate the distance between the operating points (zero if the points are the same)
            tmp_dist = p_unit(unit, op__) - p_unit(unit, op_);

            // If the operating points are not the same
            if (tmp_dist,
                // Heat rate is a weighted average of the heat rates at the p_unit operating points
                heat_rate = 1 / [
                                + p_unit(unit, eff_) * [ p_unit(unit, op__) - tmp_op ] / tmp_dist
                                + p_unit(unit, eff__) * [ tmp_op - p_unit(unit, op_) ] / tmp_dist
                                ];

            // If the operating point is the same, the the heat rate can be used directly
            else
                heat_rate = 1 / p_unit(unit, eff_);
            ); // END if(tmp_dist)

            // Special considerations for the first lambda
            if (ord(effSelector_) = 1,
                // If the min. load of the unit is not zero or the section has been pre-defined, then section is copied directly from the unit properties
                if(p_unit(unit, 'op00') or p_unit(unit, 'section'),
                    p_effGroupUnit(effSelector, unit, 'section') = p_unit(unit, 'section');

                // Calculate section based on the opFirstCross, which has been calculated into p_effUnit(effLambda, unit, effLambda_, 'op')
                else
                    p_effGroupUnit(effSelector, unit, 'section')
                        = p_unit(unit, 'opFirstCross')
                            * ( heat_rate - 1 / p_unit(unit, 'eff01') )
                            / ( p_unit(unit, 'op01') - tmp_op );
                ); // END if(p_unit)
            ); // END if(ord(effSelector))

            // Calculate the slope
            p_effUnit(effSelector, unit, effSelector_, 'slope')
                = heat_rate - p_effGroupUnit(effSelector, unit, 'section') / [tmp_op + 1${not tmp_op}];
        ); // END loop(eff_,eff__)
    ); // END loop(op_,op__)
); // END loop(effGroupSelectorUnit)

// Parameters for incremental heat rates
loop(effGroupSelectorUnit(effIncHR(effSelector), unit, effSelector_),

    p_effUnit(effSelector, unit, effSelector, 'lb') = p_unit(unit, 'hrop00'); // hrop00 contains the minimum load of the unit
    p_effUnit(effSelector, unit, effSelector, 'op') = smax(hrop, p_unit(unit, hrop)); // Maximum operating point
    p_effUnit(effSelector, unit, effSelector, 'slope') = 1 / smax(eff${p_unit(unit, eff)}, p_unit(unit, eff)); // Uses maximum found (nonzero) efficiency.
    p_effUnit(effSelector, unit, effSelector, 'section') = p_unit(unit, 'hrsection'); // pre-defined

    // Whether to use q_conversionIncHR_help1 and q_conversionIncHR_help2 or not
    loop(m,
        loop(hr${p_unit(unit, hr)},
            if (mSettings(m, 'incHRAdditionalConstraints') = 0,
                if (p_unit(unit, hr) < p_unit(unit, hr-1),
                    unit_incHRAdditionalConstraints(unit) = yes;
                ); // END if(hr)
            else
                unit_incHRAdditionalConstraints(unit) = yes;
            ); // END if(incHRAdditionalConstraints)
        ); // END loop(hr)
    ); // END loop(m)
); // END loop(effGroupSelectorUnit)

// Calculate unit wide parameters for each efficiency group
loop(effLevelGroupUnit(effLevel, effGroup, unit)${sum(m, mSettingsEff(m, effLevel))},
    p_effGroupUnit(effGroup, unit, 'op') = smax(effGroupSelectorUnit(effGroup, unit, effSelector), p_effUnit(effGroup, unit, effSelector, 'op'));
    p_effGroupUnit(effGroup, unit, 'lb') = smin(effGroupSelectorUnit(effGroup, unit, effSelector), p_effUnit(effGroup, unit, effSelector, 'lb'));
    p_effGroupUnit(effGroup, unit, 'slope') = smin(effGroupSelectorUnit(effGroup, unit, effSelector), p_effUnit(effGroup, unit, effSelector, 'slope'));
); // END loop(effLevelGroupUnit)


* --- Clear number precision errors -------------------------------------------

// clear 'section' below 1e-10
p_effGroupUnit(effSelector, unit, 'section')${p_effGroupUnit(effSelector, unit, 'section') < 1e-10} = 0;


* --- Form a set of units with no load fuel use -------------------------------

// needs to be moved to 3c when ts_effUnit_ is expanded to cover section
unit_section(unit)$sum(effGroup, p_effGroupUnit(effGroup, unit, 'section')) = yes;


* =============================================================================
* --- Initialize Unit Startup and Shutdown Counters ---------------------------
* =============================================================================

* --- Unit Start-up Generation Levels -----------------------------------------

loop(m,
    loop(unit$(p_unit(unit, 'rampSpeedToMinLoad') and p_unit(unit,'op00')),

        // Calculate time intervals needed for the run-up phase
        tmp = [ p_unit(unit,'op00') / (p_unit(unit, 'rampSpeedToMinLoad') * 60) ] / mSettings(m, 'stepLengthInHours');
        p_u_runUpTimeIntervals(unit) = tmp;
        p_u_runUpTimeIntervalsCeil(unit) = ceil(p_u_runUpTimeIntervals(unit));
        runUpCounter(unit, counter(counter_large)) // Store the required number of run-up intervals for each unit
            ${ ord(counter_large) <= p_u_runUpTimeIntervalsCeil(unit) }
            = yes;
        dt_trajectory(counter(counter_large))
            ${ runUpCounter(unit, counter_large) }
            = - ord(counter_large) + 1; // Runup starts immediately at v_startup

        // Calculate minimum output during the run-up phase; partial intervals calculated using weighted averaging with min load
        p_uCounter_runUpMin(runUpCounter(unit, counter(counter_large)))
            = + p_unit(unit, 'rampSpeedToMinLoad')
                * ( + min(ord(counter_large), p_u_runUpTimeIntervals(unit)) // Location on ramp
                    - 0.5 * min(p_u_runUpTimeIntervals(unit) - ord(counter_large) + 1, 1) // Average ramp section
                    )
                * min(p_u_runUpTimeIntervals(unit) - ord(counter_large) + 1, 1) // Portion of time interval spent ramping
                * mSettings(m, 'stepLengthInHours') // Ramp length in hours
                * 60 // unit conversion from [p.u./min] to [p.u./h]
              + p_unit(unit, 'op00')${ not runUpCounter(unit, counter_large+1) } // Time potentially spent at min load during the last run-up interval
                * ( p_u_runUpTimeIntervalsCeil(unit) - p_u_runUpTimeIntervals(unit) );

        // Maximum output on the last run-up interval can be higher, otherwise the same as minimum.
        p_uCounter_runUpMax(runUpCounter(unit, counter(counter_large)))
            = p_uCounter_runUpMin(unit, counter_large);
        p_uCounter_runUpMax(runUpCounter(unit, counter_large))${ not runUpCounter(unit, counter_large+1) }
            = p_uCounter_runUpMax(unit, counter_large)
                + ( 1 - p_uCounter_runUpMax(unit, counter_large) )
                    * ( p_u_runUpTimeIntervalsCeil(unit) - p_u_runUpTimeIntervals(unit) );

        // Minimum ramp speed in the last interval for the run-up to min. load (p.u./min)
        p_u_minRampSpeedInLastRunUpInterval(unit)
            = p_unit(unit, 'rampSpeedToMinLoad')
                * ( p_u_runUpTimeIntervals(unit) * (p_u_runUpTimeIntervalsCeil(unit) - 0.5 * p_u_runUpTimeIntervals(unit))
                    - 0.5 * p_u_runUpTimeIntervalsCeil(unit) * p_u_runUpTimeIntervalsCeil(unit) + 1
                    );

    ); // END loop(unit)
); // END loop(m)

* --- Unit Shutdown Generation Levels -----------------------------------------

loop(m,
    loop(unit$(p_unit(unit, 'rampSpeedFromMinLoad') and p_unit(unit,'op00')),
        // Calculate time intervals needed for the shutdown phase
        tmp = [ p_unit(unit,'op00') / (p_unit(unit, 'rampSpeedFromMinLoad') * 60) ] / mSettings(m, 'stepLengthInHours');
        p_u_shutdownTimeIntervals(unit) = tmp;
        p_u_shutdownTimeIntervalsCeil(unit) = ceil(p_u_shutdownTimeIntervals(unit));
        shutdownCounter(unit, counter(counter_large)) // Store the required number of shutdown intervals for each unit
            ${ ord(counter_large) <= p_u_shutDownTimeIntervalsCeil(unit)}
            = yes;
        dt_trajectory(counter(counter_large))
            ${ shutdownCounter(unit, counter_large) }
            = - ord(counter_large) + 1; // Shutdown starts immediately at v_shutdown

        // Calculate minimum output during the shutdown phase; partial intervals calculated using weighted average with zero load
        p_uCounter_shutdownMin(shutdownCounter(unit, counter(counter_large)))
            = + p_unit(unit, 'rampSpeedFromMinLoad')
                * ( min(p_u_shutdownTimeIntervalsCeil(unit) - ord(counter_large) + 1, p_u_shutdownTimeIntervals(unit)) // Location on ramp
                    - 0.5 * min(p_u_shutdownTimeIntervals(unit) - p_u_shutdownTimeIntervalsCeil(unit) + ord(counter_large), 1) // Average ramp section
                    )
                * min(p_u_shutdownTimeIntervals(unit) - p_u_shutdownTimeIntervalsCeil(unit) + ord(counter_large), 1) // Portion of time interval spent ramping
                * mSettings(m, 'stepLengthInHours') // Ramp length in hours
                * 60 // unit conversion from [p.u./min] to [p.u./h]
              + p_unit(unit, 'op00')${ not shutdownCounter(unit, counter_large-1) } // Time potentially spent at min load on the first shutdown interval
                * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) );

        // Maximum output on the first shutdown interval can be higher, otherwise the same as minimum.
        p_uCounter_shutdownMax(shutdownCounter(unit, counter(counter_large)))
            = p_uCounter_shutdownMin(unit, counter_large);
        p_uCounter_shutdownMax(shutdownCounter(unit, counter(counter_large)))${ not shutdownCounter(unit, counter_large-1) }
            = p_uCounter_shutdownMax(unit, counter_large)
                + ( 1 - p_uCounter_shutdownMax(unit, counter_large) )
                    * ( p_u_shutdownTimeIntervalsCeil(unit) - p_u_shutdownTimeIntervals(unit) );

        // Minimum ramp speed in the first interval for the shutdown from min. load (p.u./min)
        p_u_minRampSpeedInFirstShutdownInterval(unit)
            = p_unit(unit, 'rampSpeedFromMinLoad')
                * ( p_u_shutdownTimeIntervals(unit) * (p_u_shutdownTimeIntervalsCeil(unit) - 0.5 * p_u_shutdownTimeIntervals(unit))
                    - 0.5 * p_u_shutdownTimeIntervalsCeil(unit) * p_u_shutdownTimeIntervalsCeil(unit) + 1
                    );

    ); // END loop(unit)
); // END loop(m)

* --- Unit Starttype, Downtime and Uptime Counters ----------------------------

// starttype
// filtering units in that have time delays for specific start type. This clears the set before.
option unit_tmp < p_uNonoperational;

// Loop over filterd units in the model
loop(effLevelGroupUnit(effLevel, effOnline(effGroup), unit_tmp(unit))${sum(m, mSettingsEff(m, effLevel))},
    // Loop over the constrained start types
    loop(starttypeConstrained(starttype),
        // Find the time step displacements needed to define the start-up time frame
        Option clear = cc;
        cc(counter(counter_large))${   ord(counter_large) <= p_uNonoperational(unit, starttype, 'max') / sum(m, mSettings(m, 'stepLengthInHours'))
                        and ord(counter_large) > p_uNonoperational(unit, starttype, 'min') / sum(m, mSettings(m, 'stepLengthInHours'))
                        }
            = yes;
        unitCounter(unit, cc(counter)) = yes;
        dt_starttypeUnitCounter(starttype, unit, cc(counter_large)) = - ord(counter_large);
    ); // END loop(starttypeConstrained)
); // END loop(effLevelGroupUnit)

// filtering units with downtime requirements
option clear=unit_tmp;
unit_tmp(unit) $ {p_unit(unit, 'minShutdownHours')
                  or p_u_runUpTimeIntervals(unit)
                  or p_u_shutdownTimeIntervals(unit) }
= yes;

// dropping unrequired hot/warm starttypes from units
unitStarttype(unit, 'hot') $ {not sum(counter, dt_starttypeUnitCounter('hot', unit, counter))} = no;
unitStarttype(unit, 'warm') $ {not sum(counter, dt_starttypeUnitCounter('warm', unit, counter))} = no;

// for each (unit, start-up type), the number of time steps after a shutdown at which the start-up type changes to the next one
dt_starttypeUnit(starttypeConstrained, unit) = -smin(counter, dt_starttypeUnitCounter(starttypeConstrained, unit, counter));



// Downtime
// Loop over units with downtime requirements in the model
loop(effLevelGroupUnit(effLevel, effOnline(effGroup), unit_tmp(unit))${sum(m, mSettingsEff(m, effLevel))},
    // Find the time step displacements needed to define the downtime requirements (include run-up phase and shutdown phase)
    Option clear = cc;
    cc(counter_large)${   ord(counter_large) <= ceil(p_unit(unit, 'minShutdownHours') / sum(m, mSettings(m, 'stepLengthInHours')) )
                                                + ceil(p_u_runUpTimeIntervals(unit)) // NOTE! Check this
                                                + ceil(p_u_shutdownTimeIntervals(unit)) // NOTE! Check this
                    }
        = yes;
    unitCounter(unit, cc(counter_large)) = yes;
    dt_downtimeUnitCounter(unit, cc(counter_large)) = - ord(counter_large);
); // END loop(effLevelGroupUnit)

// Uptime
// Loop over units with uptime requirements in the model
loop(effLevelGroupUnit(effLevel, effOnline(effGroup), unit_online(unit))${sum(m, mSettingsEff(m, effLevel)) and p_unit(unit, 'minOperationHours')},
    // Find the time step displacements needed to define the uptime requirements
    Option clear = cc;
    cc(counter_large)${ ord(counter_large) <= ceil(p_unit(unit, 'minOperationHours') / sum(m, mSettings(m, 'stepLengthInHours')) )}
        = yes;
    unitCounter(unit, cc(counter_large)) = yes;
    dt_uptimeUnitCounter(unit, cc(counter_large)) = - ord(counter_large);
); // END loop(effLevelGroupUnit)

// Initialize dt_historicalSteps based on the first model interval
dt_historicalSteps = sum(m, -mInterval(m, 'stepsPerInterval', 'c000'));

// Estimate the maximum amount of history required for the model (very rough estimate atm, just sums all possible delays together)
loop(unit_online(unit),
    dt_historicalSteps = min( dt_historicalSteps, // dt operators have negative values, thus use min instead of max
                              smin((starttype, unitCounter(unit, counter)), dt_starttypeUnitCounter(starttype, unit, counter))
                              + smin(unitCounter(unit, counter), dt_downtimeUnitCounter(unit, counter))
                              + smin(unitCounter(unit, counter), dt_uptimeUnitCounter(unit, counter))
                              - p_u_runUpTimeIntervalsCeil(unit) // NOTE! p_u_runUpTimeIntervalsCeil is positive, whereas all dt operators are negative
                              - p_u_shutdownTimeIntervalsCeil(unit) // NOTE! p_u_shutdownTimeIntervalsCeil is positive, whereas all dt operators are negative
                              );
); // END loop(unit_online)


* =============================================================================
* --- Converting Price Change data to Price Data ------------------------------
* =============================================================================

// calculated here instead 1e_inputs because t_datalength is initiated in 3a_periodicInit
// selecting smallest t within datalength
tmp_ = smin(t_datalength(t), ord(t));


// ts_priceChange
// filtering nodes with priceChange data
option node_tmp < ts_priceChange;

// converting price change data to price data
loop(node_tmp(node)$p_price(node, 'useTimeSeries'),
    // Find time steps for the current node
    Option clear = tt;
    tt(t)$ts_priceChange(node, t) = yes;
    // initial value
    tmp = sum(tt(t)$(ord(t) < tmp_),
              ts_priceChange(node, t)
          );
    // consecutive values
    loop(t_datalength(t),
        tmp = tmp + ts_priceChange(node, t);
        ts_price(node, t) = tmp;
    );
); // END loop(node)


// ts_priceChangeNew
// filtering nodes and in with priceChange data
option node_tmp < ts_priceChangeNew;
option ff < ts_priceChangeNew;

// converting price change data to price data
loop((node_tmp(node), ff(f))$p_priceNew(node, f, 'useTimeSeries'),
    // Find time steps for the current node
    Option clear = tt;
    tt(t)$ts_priceChangeNew(node, f, t) = yes;
    // initial value
    tmp = sum(tt(t)$(ord(t) < tmp_),
              ts_priceChangeNew(node, f, t)
          );
    // consecutive values
    loop(t_datalength(t),
        tmp = tmp + ts_priceChangeNew(node, f, t);
        ts_priceNew(node, f, t) = tmp;
    );
); // END loop(node)


// ts_emissionPriceChange
// filtering emissions in emissionPriceChange data
option emission_tmp_ < ts_emissionPriceChange;

// converting price change data to price data
loop(emissionGroup(emission_tmp_(emission), group)$p_emissionPrice(emission, group, 'useTimeSeries'),
    // Find time steps for the current emission group
    Option clear = tt;
    tt(t)$ts_emissionPriceChange(emission, group, t) = yes;
    // initial value
    tmp = sum(tt(t)$(ord(t) < tmp_),
              ts_emissionPriceChange(emission, group, t)
          );
    // consecutive values
    loop(t_datalength(t),
        tmp = tmp + ts_emissionPriceChange(emission, group, t);
        ts_emissionPrice(emission, group, t) = tmp;
    );
); // END loop(groupEmission)

// calculating the average of ts_emissionPrice if fomEmissions or invEmissions are also used
// Calculate realized timesteps in the simulation
tt(t_full(t))${ ord(t) >= sum(m, mSettings(m, 't_start')) + 1
                and ord(t) <= sum(m, mSettings(m, 't_end')) + 1
                }
        = yes;
loop(emissionGroup(emission, group)${ p_emissionPrice(emission, group, 'useTimeSeries')
                                      and [sum(gnu, p_gnuEmission(gnu, emission, 'fomEmissions'))
                                           or sum(gnu, p_gnuEmission(gnu, emission, 'invEmissions'))]
                                      },
    p_emissionPrice(emission, group, 'average') = sum(tt(t), ts_emissionPrice(emission, group, t))/card(tt);
);


// ts_emissionPriceChangeNew
// filtering emissions and forecasts in emissionPriceChangeNew data
option emission_tmp_ < ts_emissionPriceChangeNew;
option ff_ < ts_emissionPriceChangeNew;

// converting price change data to price data
loop((emissionGroup(emission_tmp_(emission), group), ff_(f))$p_emissionPriceNew(emission, group, f, 'useTimeSeries'),
    // Find time steps for the current emission group
    Option clear = tt;
    tt(t)$ts_emissionPriceChangeNew(emission, group, f, t) = yes;
    // initial value
    tmp = sum(tt(t)$(ord(t) < tmp_),
              ts_emissionPriceChangeNew(emission, group, f, t)
          );
    // consecutive values
    loop(t_datalength(t),
        tmp = tmp + ts_emissionPriceChangeNew(emission, group, f, t);
        ts_emissionPriceNew(emission, group, f, t) = tmp;
    );
); // END loop(groupEmission)

// calculating the average of ts_emissionPriceNew if fomEmissions or invEmissions are also used
// Calculate realized timesteps in the simulation
tt(t_full(t))${ ord(t) >= sum(m, mSettings(m, 't_start')) + 1
                and ord(t) <= sum(m, mSettings(m, 't_end')) + 1
                }
        = yes;
option ff < ts_emissionPriceNew;

loop((emissionGroup(emission, group), ff(f))${ p_emissionPriceNew(emission, group, f, 'useTimeSeries')
                                               and [sum(gnu, p_gnuEmission(gnu, emission, 'fomEmissions'))
                                                    or sum(gnu, p_gnuEmission(gnu, emission, 'invEmissions'))]
                                               },
    p_emissionPriceNew(emission, group, f, 'average') = sum(tt(t), ts_emissionPriceNew(emission, group, f, t))/card(tt);
);


// ts_reservePriceChange
// filtering reserves and forecasts in restypeDirectionGroup data
Option restypeDirectionGroup_tmp_ < ts_reservePriceChange;
Option ff < ts_reservePriceChange;

// converting price change data to price data
loop((restypeDirectionGroup_tmp_(restype, up_down, group), ff(f))$p_reservePrice(restype, up_down, group, f, 'useTimeSeries'),
    // Find time steps for the current restypeDirectionGroup
    Option clear = tt;
    tt(t)$ ts_reservePriceChange(restype, up_down, group, f, t) = yes;
    // initial value
    tmp = sum(tt(t)$(ord(t) < tmp_),
              ts_reservePriceChange(restype, up_down, group, f, t)
          );
    // consecutive values
    loop(t_datalength(t),
        tmp = tmp + ts_reservePriceChange(restype, up_down, group, f, t);
        ts_reservePrice(restype, up_down, group, f, t) = tmp;
    );
); // END loop(groupEmission)

// expand p_reservePrice to active f, if not gn_forecasts(grid, node, 'ts_priceNew')
p_reservePrice(restype, up_down, group, f_active(f), param_price) ${not sum(gnGroup(grid, node, group), gn_forecasts(grid, node, 'ts_priceNew'))
                                                                    and p_reservePrice(restype, up_down, group, f+[df_realization(f)], param_price)
                                                                    }
   = p_reservePrice(restype, up_down, group, f+[df_realization(f)], param_price);

// rounding if defined
p_reservePrice(restype, up_down, group, f, param_price)
    $ {p_roundingParam('p_reservePrice') and p_reservePrice(restype, up_down, group, f, param_price)}
    = round(p_reservePrice(restype, up_down, group, f, param_price), p_roundingParam('p_reservePrice'))
;



* =============================================================================
* --- Price, Emission Price, VomCosts, and Startup Costs - New Method ---------
* =============================================================================

// check if using old price and emissionPrice input timeseries
if(card(ts_priceNew) + card(ts_priceChangeNew) + card(ts_emissionPriceNew) + card(ts_emissionPriceChangeNew) > 0,

* --- p_priceNew, p_emissionPriceNew ------------------------------------------

    // expand p_priceNew to active f, if not gn_forecasts(grid, node, 'ts_priceNew')
    p_priceNew(node, f_active(f), param_price) ${not sum(grid, gn_forecasts(grid, node, 'ts_priceNew'))
                                                 and p_priceNew(node, f+[df_realization(f)], param_price)
                                                 and not f_realization(f)
                                                 }
        = p_priceNew(node, f+[df_realization(f)], param_price);

    // expand p_emissionPriceNew to active f, if not group_forecasts(emission, group, 'ts_emissionPriceNew')
    p_emissionPriceNew(emission, group, f, param_price) ${not group_forecasts(emission, group, 'ts_emissionPriceNew')
                                                          and p_emissionPriceNew(emission, group, f+[df_realization(f)], param_price)
                                                          and not f_realization(f)
                                                          }
        = p_emissionPriceNew(emission, group, f+[df_realization(f)], param_price);


* --- p_vomCostNew, p_startupCostNew ------------------------------------------

    // p_vomCostNew
    // Decide between static or time series pricing

    // if timeseries vomCosts
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'useTimeSeries')$gnu_timeseries(grid, node, unit, 'vomCosts') = -1;

    // if timeseries prices for gnu
    // Possible forecast displacement already calculated in p_priceNew and p_emissionPriceNew
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'useTimeSeries')
        ${p_priceNew(node, f, 'useTimeSeries')
          } = -1;

    // if timeseries for fuel emissions
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'useTimeSeries')
        ${sum(emissionGroup(emission, group)${p_nEmission(node, emission) and gnGroup(grid, node, group)},
              p_emissionPriceNew(emission, group, f, 'useTimeSeries')
              ) // END sum(emissionGroup)
          } = -1;

    // if timeseries for LCA emissions
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'useTimeSeries')
        ${sum(emissionGroup(emission, group)${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)},
              p_emissionPriceNew(emission, group, f, 'useTimeSeries')
              ) // END sum(emissionGroup)
          } = -1;

    // otherwise constant
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'useConstant')
        ${not p_vomCostNew(grid, node, unit, f, 'useTimeSeries')
          } = -1;

    // p_vomcostsNew when constant prices. Includes O&M cost, fuel cost and emission cost (EUR/MWh)
    // Note: ts_vomCostNew calculated in 3c_inputsLoop.gms
    p_vomCostNew(gnu(grid, node, unit), f_active(f), 'price')$p_vomCostNew(grid, node, unit, f, 'useConstant')
            // gnu specific cost (vomCost). Always a cost (positive) if input or output.
          = + p_gnu(grid, node, unit, 'vomCosts')

            // gnu specific emission cost (e.g. process related LCA emission). Always a cost if input or output.
            + sum(emissionGroup(emission, group)${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)},
                 + p_gnuEmission(grid, node, unit, emission, 'vomEmissions') // t/MWh
                 * p_emissionPriceNew(emission, group, f, 'price')
                 ) // end sum(emissiongroup)

            // gn specific cost (fuel price). Cost when input but income when output.
            + (p_priceNew(node, f, 'price')

                // gn specific emission cost (e.g. CO2 allowance price from fuel emissions). Cost when input but income when output.
                + sum(emissionGroup(emission, group)${p_nEmission(node, emission) and gnGroup(grid, node, group)},
                    + p_nEmission(node, emission)  // t/MWh
                    * p_emissionPriceNew(emission, group, f, 'price')
                    ) // end sum(emissiongroup)
                )
            // converting gn specific costs negative if output
            * (+1$gnu_input(grid, node, unit)
               -1$gnu_output(grid, node, unit)
              )
    ;

    // rounding p_vomCostNew if defined
    p_vomCostNew(grid, node, unit, f, param_price)
        $ {p_roundingParam('p_vomCost') and p_vomCostNew(grid, node, unit, f, param_price)}
        = round(p_vomCostNew(grid, node, unit, f, param_price), p_roundingParam('p_vomCost'))
    ;

    // clearing flag to use p_vomCostNew if cost is zero
    p_vomCostNew(gnu, f, 'useConstant') $ { p_vomCostNew(gnu, f, 'useConstant') and (p_vomCostNew(gnu, f, 'price')= 0) }
         =0;

    // p_startupCostNew
    // looping to decide if using static or time series pricing
    // Possible forecast displacement already calculated in p_priceNew and p_emissionPriceNew
    loop(nu_startup(node, unit),
        p_startupCostNew(unit, starttype, f_active(f), 'useTimeSeries')${p_priceNew(node, f, 'useTimeSeries') and unitStarttype(unit, starttype)} = -1;
        p_startupCostNew(unit, starttype, f_active(f), 'useTimeSeries')${sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                                                                         p_emissionPriceNew(emission, group, f, 'useTimeSeries'))
                                                                         } = -1;
    ); // end loop(nu_startup)

    // Using constant if not using time series
    p_startupCostNew(unitStarttype(unit, starttype), f_active(f), 'useConstant')${not p_startupCostNew(unit, starttype, f, 'useTimeSeries')
                                                                        and not [p_startupCost(unit, starttype, 'useConstant')
                                                                                 or p_startupCost(unit, starttype, 'useTimeSeries')]
                                                                        } = -1;

    // static startup cost that includes startup cost, fuel cost and emission cost (EUR/MW)
    p_startupCostNew(unit, starttype, f_active(f), 'price')$p_startupCostNew(unit, starttype, f, 'useConstant')
        = p_uStartup(unit, starttype, 'cost') // EUR/start-up
        // Start-up fuel and emission costs
        + sum(nu_startup(node, unit),
             + p_unStartup(unit, node, starttype) // MWh/start-up
             * [
                  // Fuel costs
                  + p_priceNew(node, f, 'price') // EUR/MWh
                  // Emission costs
                  + sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                       + p_nEmission(node, emission) // t/MWh
                       * p_emissionPriceNew(emission, group, f, 'price')
                    ) // end sum(emissionGroup)

               ] // END * p_unStartup
             ) // END sum(nu_startup)
    ;

    // rounding p_startupCostNew if defined
    p_startupCostNew(unit, starttype, f, param_price)
        $ {p_roundingParam('p_startupCost') and p_startupCostNew(unit, starttype, f, param_price)}
        = round(p_startupCostNew(unit, starttype, f, param_price), p_roundingParam('p_startupCost'))
    ;

    // clearing flag to use p_startupCostNew if cost is zero
    p_startupCostNew(unit, starttype, f, 'useConstant') $ {p_startupCostNew(unit, starttype, f, 'useConstant')
                                                           and (p_startupCostNew(unit, starttype, f, 'price') = 0) }
    = 0;


    // mapping units that have startup costs, either constant or time series
    // p_startupCost has info that unit uses time series and thus this convers both cases
    Option unit_startCost < p_startupCostNew;

// END if(new price and emissionPrice input tables)

else
* =============================================================================
* --- Price, Emission Price, VomCosts, and Startup Costs ----------------------
* =============================================================================

    // else, use old price and emissionPrice input tables.
    // Note: captures also a case where user gives only e.g. p_gnu_io('vomCosts')


* --- p_vomCost, p_startupCost ------------------------------------------------

    // p_vomCost

    // Decide between static or time series pricing
    // if timeseries vomCosts
    p_vomCost(gnu(grid, node, unit), 'useTimeSeries')$gnu_timeseries(grid, node, unit, 'vomCosts') = -1;
    // if timeseries prices for gnu
    p_vomCost(gnu(grid, node, unit), 'useTimeSeries')$p_price(node, 'useTimeSeries') = -1;

    // if timeseries for fuel emissions
    p_vomCost(gnu(grid, node, unit), 'useTimeSeries')${sum(emissionGroup(emission, group)
                                                           ${p_nEmission(node, emission) and gnGroup(grid, node, group)},
                                                           p_emissionPrice(emission, group, 'useTimeSeries')
                                                           ) // END sum(emissionGroup)
                                                       } = -1;

    // if timeseries for LCA emissions
    p_vomCost(gnu(grid, node, unit), 'useTimeSeries')${sum(emissionGroup(emission, group)
                                                           ${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)},
                                                           p_emissionPrice(emission, group, 'useTimeSeries')
                                                           ) // END sum(emissionGroup)
                                                       } = -1;

    // otherwise constant
    p_vomCost(gnu(grid, node, unit), 'useConstant')${not p_vomCost(grid, node, unit, 'useTimeSeries')
                                                     } = -1;

    // p_vomcosts when constant prices. Includes O&M cost, fuel cost and emission cost (EUR/MWh)
    // Note: ts_vomCost calculated in 3c_inputsLoop.gms
    p_vomCost(gnu(grid, node, unit), 'price')$p_vomCost(grid, node, unit, 'useConstant')
            // gnu specific cost (vomCost). Always a cost (positive) if input or output.
          = + p_gnu(grid, node, unit, 'vomCosts')

            // gnu specific emission cost (e.g. process related LCA emission). Always a cost if input or output.
            + sum(emissionGroup(emission, group)${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)},
                 + p_gnuEmission(grid, node, unit, emission, 'vomEmissions') // t/MWh
                 * p_emissionPrice(emission, group, 'price')
                 ) // end sum(emissiongroup)

            // gn specific cost (fuel price). Cost when input but income when output.
            + (p_price(node, 'price')

                // gn specific emission cost (e.g. CO2 allowance price from fuel emissions). Cost when input but income when output.
                + sum(emissionGroup(emission, group)${p_nEmission(node, emission) and gnGroup(grid, node, group)},
                     + p_nEmission(node, emission)  // t/MWh
                     * p_emissionPrice(emission, group, 'price')
                     ) // end sum(emissiongroup)
            )
            // converting gn specific costs negative if output
            * (+1$gnu_input(grid, node, unit)
               -1$gnu_output(grid, node, unit)
              )
    ;

    // rounding p_vomCost if defined
    p_vomCost(grid, node, unit, param_price)
        $ {p_roundingParam('p_vomCost') and p_vomCost(grid, node, unit, param_price)}
        = round(p_vomCost(grid, node, unit, param_price), p_roundingParam('p_vomCost'))
    ;

    // clearing flag to use p_vomCost if cost is zero
    p_vomCost(gnu, 'useConstant') $ { p_vomCost(gnu, 'useConstant') and (p_vomCost(gnu, 'price')= 0) }
        =0;

    // p_startupCost
    // looping to decide if using static or time series pricing
    loop(nu_startup(node, unit),
        p_startupCost(unit, starttype, 'useTimeSeries')${p_price(node, 'useTimeSeries') and unitStarttype(unit, starttype)} = -1;
        p_startupCost(unit, starttype, 'useTimeSeries')${sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                                                             p_emissionPrice(emission, group, 'useTimeSeries'))
                                                             } = -1;
    ); // end loop(nu_startup)

    // Using constant if not using time series
    p_startupCost(unitStarttype(unit, starttype), 'useConstant')${not p_startupCost(unit, starttype, 'useTimeSeries')} = -1;

    // static startup cost that includes startup cost, fuel cost and emission cost (EUR/MW)
    p_startupCost(unit, starttype, 'price')$p_startupCost(unit, starttype, 'useConstant')
        = p_uStartup(unit, starttype, 'cost') // EUR/start-up
        // Start-up fuel and emission costs
        + sum(nu_startup(node, unit),
             + p_unStartup(unit, node, starttype) // MWh/start-up
             * [
                  // Fuel costs
                  + p_price(node, 'price') // EUR/MWh
                  // Emission costs
                  + sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                       + p_nEmission(node, emission) // t/MWh
                       * p_emissionPrice(emission, group, 'price')
                    ) // end sum(emissionGroup)

               ] // END * p_unStartup
             ) // END sum(nu_startup)
    ;

    // rounding p_startupCost if defined
    p_startupCost(unit, starttype, param_price)
        $ {p_roundingParam('p_startupCost') and p_startupCost(unit, starttype, param_price)}
        = round(p_startupCost(unit, starttype, param_price), p_roundingParam('p_startupCost'))
    ;

    // clearing flag to use p_startupCost if cost is zero
    p_startupCost(unit, starttype, 'useConstant') $ {p_startupCost(unit, starttype, 'useConstant')
                                                     and (p_startupCost(unit, starttype, 'price') = 0) }
    = 0;

    // mapping units that have startup costs, either constant or time series
    // p_startupCost has info that unit uses time series and thus this convers both cases
    Option unit_startCost < p_startupCost;


); // END else(old price and emissionPrice input ts, or no price and emissionPrice input ts)





// populating gnu_vomCost.
// Note: This is done outside the above sections to make sure gnu_vomCost is
// generated e.g. when running from debug file
gnu_vomCost(gnu)
    $ { p_vomCost(gnu, 'useConstant')
        or p_vomCost(gnu, 'useTimeseries')
        or sum(f_active(f), p_vomCostNew(gnu, f, 'useConstant'))
        or sum(f_active(f), p_vomCostNew(gnu, f, 'useTimeseries'))
        }
        =yes;


* --- p_linkVomCost, ts_linkVomCost ------------------------------------------

// p_linkVomCost
// Decide between static or time series pricing
// Possible forecast displacement already calculated in p_priceNew
p_linkVomCost(gn2n(grid, node, node_), f_active(f), 'useTimeSeries')
    ${p_price(node, 'useTimeSeries')
      or p_price(node_, 'useTimeSeries')
      or p_priceNew(node, f, 'useTimeSeries')
      or p_priceNew(node_, f, 'useTimeSeries')
      or [gn2n_timeseries(grid, node_, node, 'transferLoss')
          and [p_price(node, 'useConstant')
               or p_price(node_, 'useConstant')
               or p_priceNew(node, f, 'useConstant')
               or p_priceNew(node_, f, 'useConstant')
               ]
          ]
      } = -1;

p_linkVomCost(gn2n(grid, node, node_), f_active(f), 'useConstant')
    ${not p_linkVomCost(grid, node, node_, f, 'useTimeSeries')
      } = -1;

// p_linkVomCost when constant prices. Includes O&M cost and fuel cost (EUR/MWh), but not transfer losses
p_linkVomCost(gn2n(grid, node, node_), f_active(f), 'price')$p_linkVomCost(grid, node, node_, f, 'useConstant')
    = // vomCost for transfer links in between of two balance nodes
      + p_gnn(grid, node, node_, 'variableTransCost')${ gn_balance(grid, node) and gn_balance(grid, node_) }

      // When buying (price node is node)
      + [ // Cost of bought energy
          + p_price(node, 'price')          // EUR/MWh, time series.
          + p_priceNew(node, f, 'price')    // EUR/MWh, time series, new format. Possible forecast displacement already calculated.
          ] $ {not gn_balance(grid, node) and gn_balance(grid, node_) }
      + // When selling (price node is node_)
        [ // transfer link vom cost (EUR/MWh). Always a cost (positive), but accounted only for seller.
          + p_gnn(grid, node, node_, 'variableTransCost')$gn_balance(grid, node)

          // Income from sold energy
          - p_price(node_, 'price')          // EUR/MWh, time series.
          - p_priceNew(node_, f, 'price')    // EUR/MWh, time series, new format. Possible forecast displacement already calculated.
          ]
        * [ // Assuming that seller accounts for costs related to transfer losses
            + 1
            - p_gnn(grid, node, node_, 'transferLoss')${not gn2n_timeseries(grid, node, node_, 'transferLoss')}
            ] $ {gn_balance(grid, node) and not gn_balance(grid, node_) }

;

// rounding p_linkVomCost if defined
p_linkVomCost(grid, node, node_, f, param_price)
    $ {p_roundingParam('p_linkVomCost') and p_linkVomCost(grid, node, node_, f, param_price)}
    = round(p_linkVomCost(grid, node, node_, f, param_price), p_roundingParam('p_linkVomCost'))
;

// clearing flag to use p_linkVomCost if cost is zero
p_linkVomCost(gn2n, f_active(f), 'useConstant')
    $ { p_linkVomCost(gn2n, f, 'useConstant')
        and (p_linkVomCost(gn2n, f, 'price')= 0) }
     =0;

// set of gn2n_directional with vom costs
gn2n_directional_vomCost(gn2n_directional(grid, node, node_))
    $ {sum(f_active(f), p_linkVomCost(grid, node, node_, f, 'useConstant'))
       or sum(f_active(f), p_linkVomCost(grid, node_, node, f, 'useConstant'))
       or sum(f_active(f), p_linkVomCost(grid, node, node_, f, 'useTimeseries'))
       or sum(f_active(f), p_linkVomCost(grid, node_, node, f, 'useTimeseries'))
       }
    = yes;


* =============================================================================
* --- Alternative time series circulation rules -------------------------------
* =============================================================================

// There are two variants: gn_tsCirculation for node specific time series and
// unit_tsCirculation for unit specific time series.
//
// 'interpolateStepChange' calculates a linear interpolation
// of the level changes between the end and the start of the time series.
//
// The method always starts from datalength + 1 and is applied for 'length' amount of time steps
//
// Index for the last time step of the data: (t+tsCirculation('start') - ord(t)) points
// all values to tsCirculation('start')-1 that is the given data point in input data.
//
// Index for the first time step of the circulated data: (t+tsCirculation('start')+1 - ord(t))
// would point all values to tsCirculation('start'), but there is no data
// as it is outside dataLength. Thus (t+tsCirculation('start')+1 - ord(t) - dataLength) is used.
// It can be shortened to tsCirculation('start')+1 - dataLength = 2. Note: Ord(t000001)=2
//


// excecute following lines of code only if unit_tsCirculation is given in input data
$ifthen.unit_tsCirculation defined unit_tsCirculation

* --- unit_tsCirculation, checks to parameters ---------------------------

// checking if unit_tsCirculation('interpolateStepChange') is actived
if(sum((timeseries, unit, f_active), unit_tsCirculation(timeseries, unit, f_active, 'interpolateStepChange', 'isActive')),

    // check input parameters of all input rows, calculate the start and end
    loop((timeseries, unit, f_active(f))$unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'isActive'),

        tmp = unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! unit_tsCirculation(" timeseries.tl:0 ", " unit.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each unit in unit_tsCirculation('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each unit_tsCirculation('interpolateStepChange') needs 'length' parameter!";
            );

        // warn about recalculation if giving start
        if(%warnings%=1 and unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'start'),
            put log "!!! Unit_tsCirculation(" timeseries.tl:0 ", " unit.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'start' parameter." /;
            put log "Warning: recalculating unit_tsCirculation('start') based on mSettings('dataLength') and unit_tsCirculation('length') parameter."
            );

        // warn about recalculation if giving end
        if(%warnings%=1 and unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'end'),
            put log "!!! Unit_tsCirculation(" timeseries.tl:0 ", " unit.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'end' parameter." /;
            put log "Warning: recalculating unit_tsCirculation('end') based on mSettings('dataLength') and unit_tsCirculation('length') parameter."
            );

        unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        unit_tsCirculation(timeseries, unit, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

    ); // END loop(timeseries, unit, f)
); // END if('interpolateStepChange')


* --- unit_tsCirculation, calculating ts adjustments ---------------------

// ts_unit
if(sum((unit, f_active), unit_tsCirculation('ts_unit', unit, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_unit
    if(%warnings%=1 and card(ts_unit)=0,
        put log "!!! Warning: unit_tsCirculation('ts_unit', 'interpolateStepChange') defined, but no data in ts_unit!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((unit, f_active), unit_tsCirculation('ts_unit', unit, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_unit_circularAdjustment(unit, param_unit, f_active(f), tt(t))
        $ {unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_unit(unit, param_unit, f, t+[unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_unit(unit, param_unit, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'end')+1
             - unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'start'))
    ;
); // END if(unit_tsCirculation('ts_unit', 'interpolateStepChange'))

// ts_unitConstraint
if(sum((unit, f_active), unit_tsCirculation('ts_unitConstraint', unit, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_unit
    if(%warnings%=1 and card(ts_unitConstraint)=0,
        put log "!!! Warning: unit_tsCirculation('ts_unitConstraint', 'interpolateStepChange') defined, but no data in ts_unitConstraint!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((unit, f_active), unit_tsCirculation('ts_unitConstraint', unit, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_unitConstraint_circularAdjustment(unit, constraint, param_constraint, f_active(f), tt(t))
        $ {unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_unitConstraint(unit, constraint, param_constraint, f, t+[unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_unitConstraint(unit, constraint, param_constraint, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'end')+1
             - unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'start'))
    ;
); // END if(unit_tsCirculation('ts_unitConstraint', 'interpolateStepChange'))

// ts_unitConstraintNode
if(sum((unit, f_active), unit_tsCirculation('ts_unitConstraintNode', unit, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_unit
    if(%warnings%=1 and card(ts_unitConstraintNode)=0,
        put log "!!! Warning: unit_tsCirculation('ts_unitConstraintNode', 'interpolateStepChange') defined, but no data in ts_unitConstraintNode!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((unit, f_active), unit_tsCirculation('ts_unitConstraintNode', unit, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_unitConstraintNode_circularAdjustment(unit, constraint, node, f_active(f), tt(t))
        $ {unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_unitConstraintNode(unit, constraint, node, f, t+[unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_unitConstraintNode(unit, constraint, node, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'end')+1
             - unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'start'))
    ;
); // END if(unit_tsCirculation('ts_unitConstraintNode', 'interpolateStepChange'))


* --- check that not trying to use for inactive features ----------------------

// ts_vomCost
if(%warnings%=1 and sum((unit, f_active), unit_tsCirculation('ts_vomCost', unit, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: unit_tsCirculation('ts_vomCost', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew and ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by moving to new price data input and using gn_tsCirculation('ts_priceNew', 'interpolateStepChange') or group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);

// ts_vomCostNew
if(%warnings%=1 and sum((unit, f_active), unit_tsCirculation('ts_vomCostNew', unit, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: unit_tsCirculation('ts_vomCostNew', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew and ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by using gn_tsCirculation('ts_priceNew', 'interpolateStepChange') or group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);

// ts_startupCost
if(%warnings%=1 and sum((unit, f_active), unit_tsCirculation('ts_startupCost', unit, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: unit_tsCirculation('ts_startupCost', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew and ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by moving to new price data input and using gn_tsCirculation('ts_priceNew', 'interpolateStepChange') or group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);

// ts_startupCostNew
if(%warnings%=1 and sum((unit, f_active), unit_tsCirculation('ts_startupCostNew', unit, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: unit_tsCirculation('ts_startupCostNew', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew and ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by using gn_tsCirculation('ts_priceNew', 'interpolateStepChange') or group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);




$endif.unit_tsCirculation


// excecute following lines of code only if gn_tsCirculation is given in input data
$ifthen.gn_tsCirculation defined gn_tsCirculation

* --- gn_tsCirculation, checks to parameters ----------------------------------

// checking if gn_tsCirculation('interpolateStepChange') is actived for gn
if(sum((timeseries, gn, f_active), gn_tsCirculation(timeseries, gn, f_active, 'interpolateStepChange', 'isActive')),

    // check parameters of all input rows
    loop((timeseries, gn(grid, node), f_active(f))$gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'isActive'),

        tmp = gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " grid.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each gn in gn_tsCirculation('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each gn_tsCirculation('interpolateStepChange') needs 'length' parameter!";
            );

        // warn about recalculation if giving start
        if(%warnings%=1 and gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'start'),
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " grid.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'start' parameter." /;
            put log "Warning: recalculating gn_tsCirculation('start') based on mSettings('dataLength') and gn_tsCirculation('length') parameter."
            );

        // warn about recalculation if giving end
        if(%warnings%=1 and gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'end'),
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " grid.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'end' parameter." /;
            put log "Warning: recalculating gn_tsCirculation('end') based on mSettings('dataLength') and gn_tsCirculation('length') parameter."
            );

        gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        gn_tsCirculation(timeseries, grid, node, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

     ); // END loop(timeseries, gn, f)
); // END if('interpolateStepChange')

// checking if gn_tsCirculation('interpolateStepChange') is actived for flowNode
if(sum((timeseries, flowNode, f_active), gn_tsCirculation(timeseries, flowNode, f_active, 'interpolateStepChange', 'isActive')),

    // check parameters of all input rows
    loop((timeseries, flowNode(flow, node), f_active(f))$gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'isActive'),

        tmp = gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " flow.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each gn in gn_tsCirculation('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each gn_tsCirculation('interpolateStepChange') needs 'length' parameter!";
            );

        // warn about recalculation if giving start
        if(%warnings%=1 and gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'start'),
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " flow.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'start' parameter." /;
            put log "Warning: recalculating gn_tsCirculation('start') based on mSettings('dataLength') and gn_tsCirculation('length') parameter."
            );

        // warn about recalculation if giving end
        if(%warnings%=1 and gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'end'),
            put log "!!! gn_tsCirculation(" timeseries.tl:0 ", " flow.tl:0 ", " node.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'end' parameter." /;
            put log "Warning: recalculating gn_tsCirculation('end') based on mSettings('dataLength') and gn_tsCirculation('length') parameter."
            );

        gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        gn_tsCirculation(timeseries, flow, node, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

     ); // END loop(timeseries, flowNode, f)
); // END if('interpolateStepChange')

* --- gn_tsCirculation, calculating ts adjustments -----------------------

// ts_influx
if(sum((gn, f_active), gn_tsCirculation('ts_influx', gn, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_influx
    if(%warnings%=1 and card(ts_influx)=0,
        put log "!!! Warning: gn_tsCirculation('ts_influx', 'interpolateStepChange') defined, but no data in ts_influx!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_influx', flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((gn, f_active), gn_tsCirculation('ts_influx', gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_influx_circularAdjustment(gn(grid, node), f_active(f), tt(t))
        $ {gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_influx(grid, node, f, t+[gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_influx(grid, node, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'end')+1
             - gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'start'))
    ;
); // END if(gn_tsCirculation('ts_influx', 'interpolateStepChange'))

// ts_cf
if(sum((flowNode, f_active), gn_tsCirculation('ts_cf', flowNode, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_cf
    if(%warnings%=1 and card(ts_cf)=0,
        put log "!!! Warning: gn_tsCirculation('ts_cf', 'interpolateStepChange') defined, but no data in ts_cf!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_cf, flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((flowNode, f_active), gn_tsCirculation('ts_cf', flowNode, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_cf_circularAdjustment(flowNode(flow, node), f_active(f), tt(t))
        $ {gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_cf(flow, node, f, t+[gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_cf(flow, node, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'end')+1
             - gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'start'))
    ;
); // END if(gn_tsCirculation('ts_cf', 'interpolateStepChange'))

// ts_node
if(sum((gn, f_active), gn_tsCirculation('ts_node', gn, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_node
    if(%warnings%=1 and card(ts_node)=0,
        put log "!!! Warning: gn_tsCirculation('ts_node', 'interpolateStepChange') defined, but no data in ts_node!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_node', flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((gn, f_active), gn_tsCirculation('ts_node', gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_node_circularAdjustment(gn(grid, node), param_gnBoundaryTypes, f_active(f), tt(t))
        $ {gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_node(grid, node, param_gnBoundaryTypes, f, t+[gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_node(grid, node, param_gnBoundaryTypes, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'end')+1
             - gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'start'))
    ;
); // END if(gn_tsCirculation('ts_node', 'interpolateStepChange'))

// ts_gnn
if(sum((gn, f_active), gn_tsCirculation('ts_gnn', gn, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_gnn
    if(%warnings%=1 and card(ts_gnn)=0,
        put log "!!! Warning: gn_tsCirculation('ts_gnn', 'interpolateStepChange') defined, but no data in ts_gnn!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_gnn', flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((gn, f_active), gn_tsCirculation('ts_gnn', gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_gnn_circularAdjustment(gn2n_timeseries(grid, node, node_, param_gnn), f_active(f), tt(t))
        $ {gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_gnn(grid, node, node_, param_gnn, f, t+[gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_gnn(grid, node, node_, param_gnn, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'end')+1
             - gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'start'))
    ;
); // END if(gn_tsCirculation('ts_gnn', 'interpolateStepChange'))

// ts_priceNew
if(sum((gn, f_active), gn_tsCirculation('ts_priceNew', gn, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_priceNew
    if(%warnings%=1 and card(ts_priceNew)=0,
        put log "!!! Warning: gn_tsCirculation('ts_priceNew', 'interpolateStepChange') defined, but no data in ts_priceNew!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_priceNew', flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((gn, f_active), gn_tsCirculation('ts_priceNew', gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_priceNew_circularAdjustment(node, f_active(f), tt(t))
        $ {sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'isActive'))
           and (ord(t) > sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'start')) )
           and (ord(t) <= sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'end')) )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_priceNew(node, f, t+[sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'start')) - ord(t)] )
              - ts_priceNew(node, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'end'))+1
             - ord(t))
          / (sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'end'))+1
             - sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'start')) )
    ;
); // END if(gn_tsCirculation('ts_priceNew', 'interpolateStepChange'))

// ts_storageValue
if(sum((gn, f_active), gn_tsCirculation('ts_storageValue', gn, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_storageValue
    if(%warnings%=1 and card(ts_storageValue)=0,
        put log "!!! Warning: gn_tsCirculation('ts_storageValue', 'interpolateStepChange') defined, but no data in ts_storageValue!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation('ts_storageValue', flow, node, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((gn, f_active), gn_tsCirculation('ts_storageValue', gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_storageValue_circularAdjustment(grid, node, f_active(f), tt(t))
        $ {gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_storageValue(grid, node, f, t+[gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_storageValue(grid, node, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from gn_tsCirculation('start') to gn_tsCirculation('end')
          * (gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'end')+1
             - gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'start'))
    ;
); // END if(gn_tsCirculation('ts_storageValue', 'interpolateStepChange'))


* --- check that not trying to use for inactive features ----------------------

// ts_price
if(%warnings%=1 and sum((gn, f_active), gn_tsCirculation('ts_price', gn, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: gn_tsCirculation('ts_price', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew!" /;
    put log "!!! Activate the feature by moving to new price data input and using gn_tsCirculation('ts_priceNew', 'interpolateStepChange')" /;
);

// ts_linkVomCost
if(%warnings%=1 and sum((gn, f_active), gn_tsCirculation('ts_linkVomCost', gn, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: gn_tsCirculation('ts_linkVomCost', 'interpolateStepChange') defined, but the feature is enabled only for ts_priceNew and ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by moving to new price data input and using gn_tsCirculation('ts_priceNew', 'interpolateStepChange') or group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);

$endif.gn_tsCirculation


// excecute following lines if ts_gnu_circulationRules has data
if(card(ts_gnu_circulationRules) > 0,

    // check length, calculate start and stop
    loop((gnu(grid, node, unit), param_gnu, f_active(f))$ts_gnu_circulationRules(gnu, param_gnu, f, 'interpolateStepChange', 'isActive'),

        tmp = ts_gnu_CirculationRules(gnu, param_gnu, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! ts_gnu_circulationRules(" grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", " param_gnu.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each ts_gnu_circulationRules('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each ts_gnu_circulationRules('interpolateStepChange') needs 'length' parameter!";
            );

        reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

     ); // END loop(timeseries, restypeDirectionGroup, f)

); // END if(ts_gnu_CirculationRules)


// excecute following lines of code only if group_tsCirculation is given in input data
$ifthen.reserve_tsCirculation defined reserve_tsCirculation

* --- reserve_tsCirculation, checks to parameters -----------------------------

// checking if reserve_tsCirculation('interpolateStepChange') is actived
if(sum((timeseries, restypeDirectionGroup, f_active), reserve_tsCirculation(timeseries, restypeDirectionGroup, f_active, 'interpolateStepChange', 'isActive')),

    // check parameters of all input rows
    loop((timeseries, restypeDirectionGroup(restype, up_down, group), f_active(f))$reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'isActive'),

        tmp = reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! reserve_tsCirculation(" timeseries.tl:0 ", " restype.tl:0 ", " up_down.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each restypeDirectionGroup in reserve_tsCirculation('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each reserve_tsCirculation('interpolateStepChange') needs 'length' parameter!";
            );

        // warn about recalculation if giving start
        if(%warnings%=1 and reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'start'),
            put log "!!! reserve_tsCirculation(" timeseries.tl:0 ", " restype.tl:0 ", " up_down.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'start' parameter." /;
            put log "Warning: recalculating reserve_tsCirculation('start') based on mSettings('dataLength') and reserve_tsCirculation('length') parameter."
            );

        // warn about recalculation if giving end
        if(%warnings%=1 and reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'end'),
            put log "!!! reserve_tsCirculation(" timeseries.tl:0 ", " restype.tl:0 ", " up_down.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'end' parameter." /;
            put log "Warning: recalculating reserve_tsCirculation('end') based on mSettings('dataLength') and reserve_tsCirculation('length') parameter."
            );

        reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        reserve_tsCirculation(timeseries, restype, up_down, group, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

     ); // END loop(timeseries, restypeDirectionGroup, f)
); // END if('interpolateStepChange')


* --- reserve_tsCirculation, calculating ts adjustments -----------------------

// ts_reserveDemand
if(sum((restypeDirectionGroup, f_active), reserve_tsCirculation('ts_reserveDemand', restypeDirectionGroup, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_reserveDemand
    if(%warnings%=1 and card(ts_reserveDemand)=0,
        put log "!!! Warning: reserve_tsCirculation('ts_reserveDemand', 'interpolateStepChange') defined, but no data in ts_reserveDemand!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum reserve_tsCirculation('ts_reserveDemand', restypeDirectionGroup, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((restypeDirectionGroup, f_active), reserve_tsCirculation('ts_reserveDemand', restypeDirectionGroup, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_reserveDemand_circularAdjustment(restypeDirectionGroup(restype, up_down, group), f_active(f), tt(t))
        $ {reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_reserveDemand(restype, up_down, group, f, t+[reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_reserveDemand(restype, up_down, group, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from reserve_tsCirculation('start') to reserve_tsCirculation('end')
          * (reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'end')+1
             - reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'start'))
    ;
); // END if(reserve_tsCirculation('ts_reserveDemand', 'interpolateStepChange'))

// ts_reservePrice
if(sum((restypeDirectionGroup, f_active), reserve_tsCirculation('ts_reservePrice', restypeDirectionGroup, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_reservePrice
    if(%warnings%=1 and card(ts_reservePrice)=0,
        put log "!!! Warning: reserve_tsCirculation('ts_reservePrice', 'interpolateStepChange') defined, but no data in ts_reservePrice!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((restypeDirectionGroup, f_active), reserve_tsCirculation('ts_reservePrice', restypeDirectionGroup, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_reservePrice_circularAdjustment(restypeDirectionGroup(restype, up_down, group), f_active(f), tt(t))
        $ {reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_reservePrice(restype, up_down, group, f, t+[reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_reservePrice(restype, up_down, group, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from reserve_tsCirculation('start') to reserve_tsCirculation('end')
          * (reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'end')+1
             - reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'start'))
    ;
); // END if(reserve_tsCirculation('ts_reservePrice', 'interpolateStepChange'))

$endif.reserve_tsCirculation


// group_tsCirculation


// excecute following lines of code only if group_tsCirculation is given in input data
$ifthen.group_tsCirculation defined group_tsCirculation

* --- reserve_tsCirculation, checks to parameters -----------------------------

// checking if reserve_tsCirculation('interpolateStepChange') is actived
if(sum((timeseries, emissionGroup, f_active), group_tsCirculation(timeseries, emissionGroup, f_active, 'interpolateStepChange', 'isActive')),

    // check parameters of all input rows
    loop((timeseries, emissionGroup(emission, group), f_active(f))$group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'isActive'),

        tmp = group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'length');
        tmp_ = sum(m, mSettings(m, 'datalength'));

        // abort if no 'length'
        if(tmp=0,
            put log "!!! group_tsCirculation(" timeseries.tl:0 ", " emission.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') does not have 'length' parameter" /;
            put log "!!! Abort: each emissionGroup in group_tsCirculation('interpolateStepChange') needs 'length' parameter!" /;
            abort "Each group_tsCirculation('interpolateStepChange') needs 'length' parameter!";
            );

        // warn about recalculation if giving start
        if(%warnings%=1 and group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'start'),
            put log "!!! group_tsCirculation(" timeseries.tl:0 ", " emission.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'start' parameter." /;
            put log "Warning: recalculating group_tsCirculation('start') based on mSettings('dataLength') and group_tsCirculation('length') parameter."
            );

        // warn about recalculation if giving end
        if(%warnings%=1 and group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'end'),
            put log "!!! group_tsCirculation(" timeseries.tl:0 ", " emission.tl:0 ", " group.tl:0 ", " f.tl:0 ", 'interpolateStepChange') has 'end' parameter." /;
            put log "Warning: recalculating group_tsCirculation('end') based on mSettings('dataLength') and group_tsCirculation('length') parameter."
            );

        group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'start') = tmp_ + 1;
        group_tsCirculation(timeseries, emission, group, f, 'interpolateStepChange', 'end') = tmp_ + 1 + tmp;

     ); // END loop(timeseries, emissionGroup, f)
); // END if('interpolateStepChange')

* --- group_tsCirculation, calculating ts adjustments -----------------------

// ts_emissionPriceNew
if(sum((emissionGroup, f_active), group_tsCirculation('ts_emissionPriceNew', emissionGroup, f_active, 'interpolateStepChange', 'isActive')),

    // Warning if no data in ts_emissionPriceNew
    if(%warnings%=1 and card(ts_emissionPrice)=0,
        put log "!!! Warning: group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange') defined, but no data in ts_emissionPriceNew!" /;
    );

    // filtering t that are larger than dataLength and smaller than maximum group_tsCirculation('ts_emissionPriceNew', restype, up_down, group, f, 'interpolateStepChange', 'end')
    option clear = tt;
    tmp = smax((emissionGroup, f_active), group_tsCirculation('ts_emissionPriceNew', emissionGroup, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > sum(m, mSettings(m, 'dataLength')) )
                    and (ord(t) <= tmp)
                    } = yes;

    // calculating the adjustment to circular data
    ts_emissionPriceNew_circularAdjustment(emissionGroup(emission, group), f_active(f), tt(t))
        $ {group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'isActive')
           and (ord(t) > group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'start') )
           and (ord(t) <= group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'end') )
           }
        = // the step change = value of the last time - value of the first time step
          + [ ts_emissionPriceNew(emission, group, f, t+[group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'start') - ord(t)] )
              - ts_emissionPriceNew(emission, group, f, t+[2 - ord(t)] )
              ]
          // linearly decreasing factor from group_tsCirculation('start') to group_tsCirculation('end')
          * (group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'end')+1
             - ord(t))
          / (group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'end')+1
             - group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'start'))
    ;
); // END if(group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange'))


* --- check that not trying to use for inactive features ----------------------

// ts_emissionprice
if(%warnings%=1 and sum((emissionGroup, f_active), group_tsCirculation('ts_emissionPrice', emissionGroup, f_active, 'interpolateStepChange', 'isActive')),
    put log "!!! Warning: group_tsCirculation('ts_emissionPrice', 'interpolateStepChange') defined, but the feature is enabled only for ts_emissionPriceNew!" /;
    put log "!!! Activate the feature by moving to new price data input and using group_tsCirculation('ts_emissionPriceNew', 'interpolateStepChange')" /;
);

$endif.group_tsCirculation


* =============================================================================
* --- Model Parameter Validity Checks -----------------------------------------
* =============================================================================

loop(m, // Not ideal, but multi-model functionality is not yet implemented


* --- MODEL STRUCTURE ---------------------------------------------------------
* --- check that model settings are for correct model type --------------------

// warn user if settings has been given to unactive model types
// mSettings
loop((mType, mSetting) $ { %warnings%=1 and mSettings(mType, mSetting) and not m(mType) },
        put log "!!! Warning: mSettings(" mType.tl:0 ", " mSetting.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, mSetting)

// mSettingsEff
loop((mType, effLevel) $ { %warnings%=1 and mSettingsEff(mtype, effLevel) and not m(mType) },
        put log "!!! Warning: mSettingsEff(" mType.tl:0 ", " effLevel.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, effLevel)

// mInterval
loop((mType, mSetting, counter_large) $ { %warnings%=1 and mInterval(mType, mSetting, counter_large) and not m(mType) },
        put log "!!! Warning: mInterval(" mType.tl:0 ", " mSetting.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, mSetting)

// ms_initial
loop((mType, s_active(s)) $ { %warnings%=1 and ms_initial(mType, s) and not m(mType) },
        put log "!!! Warning: ms_initial(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// ms_central
loop((mType, s_active(s)) $ { %warnings%=1 and ms_central(mType, s) and not m(mType) },
        put log "!!! Warning: ms_central(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// msStart
loop((mType, s_active(s)) $ { %warnings%=1 and msStart(mType, s) and not m(mType) },
        put log "!!! Warning: msStart(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// msEnd
loop((mType, s_active(s)) $ { %warnings%=1 and msEnd(mType, s) and not m(mType) },
        put log "!!! Warning: msEnd(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// p_msProbability
loop((mType, s_active(s)) $ { %warnings%=1 and p_msProbability(mType, s) and not m(mType) },
        put log "!!! Warning: p_msProbability(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// p_msWeight
loop((mType, s_active(s)) $ { %warnings%=1 and p_msWeight(mType, s) and not m(mType) },
        put log "!!! Warning: p_msWeight(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// p_msAnnuityWeight
loop((mType, s_active(s)) $ { %warnings%=1 and p_msAnnuityWeight(mType, s) and not m(mType) },
        put log "!!! Warning: p_msAnnuityWeight(" mType.tl:0 ", " s.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, s)

// mf_realization
loop((mType, f_active(f)) $ { %warnings%=1 and mf_realization(mType, f) and not m(mType) },
        put log "!!! Warning: mf_realization(" mType.tl:0 ", " f.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, f)

// mf_central
loop((mType, f_active(f)) $ { %warnings%=1 and mf_central(mType, f) and not m(mType) },
        put log "!!! Warning: mf_central(" mType.tl:0 ", " f.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, f)

// p_mfProbability
loop((mType, f_active(f)) $ { %warnings%=1 and p_mfProbability(mType, f) and not m(mType) },
        put log "!!! Warning: p_mfProbability(" mType.tl:0 ", " f.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, f)

// mSettingsReservesInUse
loop((mType, restype, up_down) $ { %warnings%=1 and mSettingsReservesInUse(mType, restype, up_down) and not m(mType) },
        put log "!!! Warning: mSettingsReservesInUse(" mType.tl:0 ", " restype.tl:0  ", " up_down.tl:0 ") is defined, but " mType.tl:0 " is not active model type." /;
); // loop (mType, f)


* --- SAMPLES -----------------------------------------------------------------
* --- sample structure and parameters -----------------------------------------
    // Check that at least one sample is active
    if(card(s_active) = 0,
            put log '!!! Error occurred in modelsInit' /;
            put log '!!! Abort: Number of active samples is zero' /;
            abort "A working backbone model needs at least one active sample. See input/scheduleInit.gms or input/investInit.gms!"
    );

    // Check that the discount factor > 0
    tmp = 0;  // resetting counter
    loop(s_active(s) $ {not p_s_discountFactor(s)},
        p_s_discountFactor(s) = 1;
        tmp = tmp + 1;
    );

    // Notifying user if assumed discountFactors for samples
    if(%warnings% = 1 and tmp > 0,
        put log "Note: Input data had " tmp:0:0 " sample(s) without data for discount weights. Assuming p_s_discountFactor = 1 for each sample. Use 'Eps' if wanting to actually set zero." /;
    );

* --- FORECASTS ---------------------------------------------------------------
* --- forecast structure ------------------------------------------------------

    // Abort if perfect foresight not longer than forecast length
    if(mSettings(m, 't_perfectForesight')
       > max(mSettings(m, 't_forecastLengthUnchanging'),
             mSettings(m, 't_forecastLengthDecreasesFrom')),
        put log "!!! Error in model ", m.tl:0 /;
        put log "!!! Abort: t_perfectForesight > max(t_forecastLengthUnchanging, t_forecastLengthDecreasesFrom)"/;
        abort "Period of perfect foresight cannot be longer than forecast horizon";
    );

    // Abort if multiple central forecasts
    if(sum(mf_central(m, f), 1)>1,
        put log "!!! Error in model ", m.tl:0 /;
        put log "!!! Abort: There are multiple central forecasts defined"/;
        abort "Model can have only one central forecast";
    );

    // warn if central forecast = f00 while using forecasts
    if(%warnings%=1 and mf_central(m, 'f00') and card(f_active)>1,
        put log "!!! Defined model has forecasts, but the central forecast is f00" /;
        put log "!!! Warning: Check the forecast structure. Typically central forecast should be other than f00." /;
    );

    // warn if no forecasts are activated while using forecasts
    if(%warnings%=1 and [(card(gn_forecasts) + card(unit_forecasts)=0)] and [card(f_active)>1],
        put log "!!! Defined model has forecasts, but not any active forecast time series in gn_forecasts or unit_forecasts" /;
        put log "!!! Warning: Check the forecast structure. Forecasts should be activated with some forecast data."/;
    );

    // warn if central forecast > f00 if not using forecasts
    if(%warnings%=1 and not mf_central(m, 'f00') and card(f_active)=1,
        put log "!!! The central forecast should be f00 while the model does not have forecasts" /;
        put log "!!! Warning: Check the forecast structure. Central forecast should be f00 when not using forecasts." /;
    );

    // warn if forecasts active, but no forecastLength
    if(%warnings%=1 and mSettings(m, 'forecasts')>1 and (mSettings(m, 't_forecastLengthUnchanging') + mSettings(m, 't_forecastLengthDecreasesFrom'))=0,
        put log "!!! Defined model has more than one forecast, but the currentForecastLength = 0" /;
        put log "!!! Warning: Check the forecast structure. Forecasts need either 't_forecastLengthUnchanging' or 't_forecastLengthDecreasesFrom' when using more than one forecast." /;
    );

    // note if nonanticipativy active, but no forecasts or just one forecast
    if(%warnings%=1 and mSettings(m, 'nonanticipativity') and card(f_active)<3,
        put log "!!! Note: Defined model has activated forecast nonanticipativity in mSettings(m, 'nonanticipativity'), but there are less than two forecasts. This option will have no effect." /;
    );


* --- unit_forecasts ----------------------------------------------------------

    // warn if unit_forecasts activated for time series, but no data in ts
    // ts_unit
    loop((unit, f_active(f))$ {%warnings%=1
                               and card(f_active)>1
                               and unit_forecasts(unit, 'ts_unit')
                               },
        if(sum((param_unit, t_datalength(t)), ts_unit(unit, param_unit, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for unit_forecasts(" unit.tl:0 ", ts_unit), but no data for forecast " f.tl:0 " in ts_unit" /;
        ); // END if
    ); // END loop(unit, f)

    // ts_unitConstraint
    loop((unit, f_active(f))$ {%warnings%=1
                               and card(f_active)>1
                               and unit_forecasts(unit, 'ts_unitConstraint')
                               },
        if(sum((constraint, param_constraint, t_datalength(t)), ts_unitConstraint(unit, constraint, param_constraint, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for unit_forecasts(" unit.tl:0 ", ts_unitConstraint), but no data for forecast " f.tl:0 " in ts_unitConstraint" /;
        ); // END if
    ); // END loop(unit, f)

    // ts_unitConstraintNode
    loop((unit, f_active(f))$ {%warnings%=1
                               and card(f_active)>1
                               and unit_forecasts(unit, 'ts_unitConstraintNode')
                               },
        if(sum((constraint, node, t_datalength(t)), ts_unitConstraintNode(unit, constraint, node, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for unit_forecasts(" unit.tl:0 ", ts_unitConstraintNode), but no data for forecast " f.tl:0 " in ts_unitConstraintNode" /;
        ); // END if
    ); // END loop(unit, f)

* --- gn_forecasts ------------------------------------------------------------

    // warn if gn_forecasts activated for group
    loop((group, timeseries) $ {sum(node, gn_forecasts(group, node, timeseries)) },
        put log "!!! Error in model forecasts. gn_forecasts are activated for " group.tl:0 ", " timeseries.tl:0 /;
        put log "!!! Abort: gn_forecast should be activated (grid, node), (flow, node), or (restype, node), but not for groups." /;
        abort "Abort: gn_forecast should be activated (grid, node), (flow, node), or (restype, node), but not for groups.";
    ); // END loop(group, timeseries)

    // warn if gn_forecasts activated for time series, but no corresponding gn
    // ts_influx
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_influx') and not gn(grid, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_influx), but (grid, node) pair does not exist." /;
    ); // END loop
    // ts_cf
    loop((flow, node) $ {%warnings%=1 and gn_forecasts(flow, node, 'ts_cf') and not flowNode(flow, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" flow.tl:0 ", " node.tl:0 ", ts_cf), but (flow, node) pair does not exist." /;
    ); // END loop
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_cf')},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_cf), but (grid, node) pair cannot have ts_cf." /;
    ); // END loop
    // ts_node
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_node') and not gn(grid, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_node), but (grid, node) pair does not exist." /;
    ); // END loop
    // ts_gnn
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_gnn') and not gn(grid, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_gnn), but (grid, node) pair does not exist." /;
    ); // END loop
    // ts_price
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_priceNew') and not gn(grid, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_priceNew), but (grid, node) pair does not exist." /;
    ); // END loop
    loop((grid, node) $ {%warnings%=1 and gn_forecasts(grid, node, 'ts_storageValue') and not gn(grid, node)},
        put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_storageValue), but (grid, node) pair does not exist." /;
    ); // END loop

    // warn if gn_forecasts activated for time series, but no data in ts
    // ts_influx
    loop((gn(grid, node), f_active(f))$ {%warnings%=1
                                         and card(f_active)>1
                                         and gn_forecasts(grid, node, 'ts_influx')
                                         },
        if(sum(t_datalength(t), ts_influx(grid, node, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_influx), but no data for forecast " f.tl:0 " in ts_influx" /;
        ); // END if
    ); // END loop(grid, node, f)

    // ts_cf
    loop((flowNode(flow, node), f_active(f))$ {%warnings%=1
                                               and card(f_active)>1
                                               and gn_forecasts(flow, node, 'ts_cf')
                                               },
        if(sum(t_datalength(t), ts_cf(flow, node, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(" flow.tl:0 ", " node.tl:0 ", ts_cf), but no data for forecast " f.tl:0 " in ts_cf" /;
        ); // END if
    ); // END loop(flow, node, f)

    // ts_node
    loop((gn(grid, node), f_active(f))$ {%warnings%=1
                                         and card(f_active)>1
                                         and gn_forecasts(grid, node, 'ts_node')
                                         },
        if(sum((param_gnBoundaryTypes, t_datalength(t)), ts_node(grid, node, param_gnBoundaryTypes, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_node), but no data for forecast " f.tl:0 " in ts_node" /;
        ); // END if
    ); // END loop(grid, node, f)

    // ts_gnn
    loop((gn(grid, node), f_active(f))$ {%warnings%=1
                                         and card(f_active)>1
                                         and gn_forecasts(grid, node, 'ts_gnn')
                                         },
        if(sum((node_, param_gnn, t_datalength(t)), ts_gnn(grid, node, node_, param_gnn, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_gnn), but no data for forecast " f.tl:0 " in ts_gnn" /;
        ); // END if
    ); // END loop(grid, node, f)

    // ts_priceNew
    if({%warnings%=1 and card(f_active)>1 and sum(gn, gn_forecasts(gn, 'ts_priceNew'))},
        option tt < ts_priceChangeNew;
        option tt_ < ts_priceNew;
    );
    loop((gn(grid, node), f_active(f))$ {%warnings%=1
                                         and card(f_active)>1
                                         and gn_forecasts(grid, node, 'ts_priceNew')
                                         },
        if(sum(tt(t), ts_priceChangeNew(node, f, t)) = 0,
            if(sum(tt_(t), ts_priceNew(node, f, t)) = 0,
                put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_priceNew), but no data for forecast " f.tl:0 " in ts_priceNew or ts_priceChangeNew" /;
            ); // END if(ts_priceNew = 0)
        ); // END if(ts_priceChangeNew = 0)
    ); // END loop(grid, node, f)

    // ts_storageValue
    loop((gn(grid, node), f_active(f))$ {%warnings%=1
                                         and card(f_active)>1
                                         and gn_forecasts(grid, node, 'ts_storageValue')
                                         },
        if(sum(t_datalength(t), ts_storageValue(grid, node, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(" grid.tl:0 ", " node.tl:0 ", ts_storageValue), but no data for forecast " f.tl:0 " in ts_storageValue" /;
        ); // END if
    ); // END loop(grid, node, f)

    // warn if trying to activate forecasts that do not have any coded features
    // ts_price
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_price'))
             or sum(gn, gn_forecasts(gn, 'ts_price'))
             ],
        put log "!!! Error in model 'ts_price' forecasts " /;
        put log "!!! Abort: ts_price forecasts are activated through ts_priceNew forecasts"/;
        abort "Abort: forecast should be activated to gn_forecasts('ts_priceNew')";
    ); // END if

    // warning if gn_forecasts activated for reserves, but reserve_length <= t_jump
    loop((restype, group) $ {%warnings%=1
                             and card(f_active)>1
                             and sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reserveDemand'))
                             and [p_groupReserves(group, restype, 'reserve_length') <= mSettings(m, 't_jump')]
                             },
            put log "!!! Warning: gn_forecasts('ts_reserveDemand') is activated for restype: " restype.tl:0 ", but reserve_length is shorter or equal to mSettings('t_jump'). These forecasts will not be active." /;
    ); // END loop(restype, node)
    loop((restype, group) $ {%warnings%=1
                             and card(f_active)>1
                             and sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reservePrice'))
                             and [p_groupReserves(group, restype, 'reserve_length') <= mSettings(m, 't_jump')]
                             },
            put log "!!! Warning: gn_forecasts('ts_reserveDemand') is activated for restype: " restype.tl:0 ", but reserve_length is shorter or equal to mSettings('t_jump'). These forecasts will not be active." /;
    ); // END loop(restype, node)

* --- group_forecasts ---------------------------------------------------------

    // warn if group_forecasts activated for time series, but no corresponding data
    // ts_reserveDemand
    // note: currently under gn_forecasts
    loop((group, f_active(f))$ {%warnings%=1
                                and card(f_active)>1
                                and sum(gnGroup(grid, node, group), gn_forecasts(grid, node, 'ts_reserveDemand'))
                                },
        if(sum((restype, up_down, t_datalength(t)), ts_reserveDemand(restype, up_down, group, f, t)) = 0,
            put log "!!! Warning: Forecasts activated for gn_forecasts(ts_reserveDemand), but no data for forecast " f.tl:0 " in ts_reserveDemand" /;
        ); // END if
    ); // END loop(group, f)

    // ts_reservePrice
    // note: currently under gn_forecasts
    if({card(f_active)>1 and sum(gn, gn_forecasts(gn, 'ts_reservePrice'))},
        option tt < ts_reservePriceChange;
        option tt_ < ts_reservePrice;
    );
    loop((group, f_active(f))$ {%warnings%=1
                                and card(f_active)>1
                                and sum(gnGroup(grid, node, group), gn_forecasts(grid, node, 'ts_reservePrice'))
                                },
        if(sum((restype, up_down, tt(t)), ts_reservePriceChange(restype, up_down, group, f, t)) = 0,
            if(sum((restype, up_down, tt_(t)), ts_reservePrice(restype, up_down, group, f, t)) = 0,
                put log "!!! Warning: Forecasts activated for gn_forecasts(ts_reservePrice), but no data for forecast " f.tl:0 " in ts_reservePrice or ts_reservePriceChange" /;
            ); // END if('useConstant')
        ); // END if('useTimeseries')
    ); // END loop(group, f)

    // ts_emissionPriceNew
    if({card(f_active)>1 and sum((emission, group), group_forecasts(emission, group, 'ts_emissionPriceNew'))},
        option tt < ts_emissionPriceChangeNew;
        option tt_ < ts_emissionPriceNew;
    );
    loop((emission, group, f_active(f))$ {%warnings%=1
                                          and card(f_active)>1
                                          and group_forecasts(emission, group, 'ts_emissionPriceNew')
                                          },
        if(sum(tt(t), ts_emissionPriceChangeNew(emission, group, f, t)) = 0,
            if(sum(tt_(t), ts_emissionPriceNew(emission, group, f, t)) = 0,
                put log "!!! Warning: Forecasts activated for group_forecasts(" emission.tl:0 ", " group.tl:0 ", ts_emissionPriceNew), but no data for forecast " f.tl:0 " in ts_emissionPriceNew or ts_emissionPriceChangeNew" /;
            ); // END if('useConstant')
        ); // END if('useTimeseries')
    ); // END loop(grid, node, f)

    // warn if trying to activate forecasts that do not have any coded features
    // ts_emissionPrice
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_emissionPrice'))
             or sum(gn, gn_forecasts(gn, 'ts_emissionPrice'))
             or sum((emission, group), group_forecasts(emission, group, 'ts_emissionPrice'))
             ],
        put log "!!! Error in model 'ts_emissionPriceNew' forecasts " /;
        put log "!!! Abort: ts_emissionPriceNew forecasts are activated through ts_emissionPriceNew forecasts"/;
        abort "Abort: forecast should be activated to group_forecasts('ts_emissionPriceNew')";
    ); // END if

    // ts_groupPolicy
    if( {%warnings%=1
         and card(f_active)>1
         and sum((param_policy, group), group_forecasts(param_policy, group, 'ts_groupPolicy'))
         },
        put log "!!! Warning: group_forecasts(param_policy, group, 'ts_groupPolicy') activated in the init file, but this feature is not yet active."/;
        put log "!!! Warning: group_forecasts('ts_groupPolicy') does not have any impact."/;
    ); // END if

* --- warn if trying to activate forecasts that do not have any features ------

    // ts_vomCost
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_vomCost'))
             or sum(gn, gn_forecasts(gn, 'ts_vomCost'))
             ],
        put log "!!! Error in model 'ts_vomCost' forecasts " /;
        put log "!!! Abort: ts_vomCost forecasts are activated through ts_price and ts_emissionPrice forecasts"/;
        abort "Abort: forecast should be activated by moving to new price input tables and using gn_forecasts('ts_price') and/or to group_forecasts('ts_emissionPrice')";
    ); // END if

    // ts_vomCost, ts_vomCostNew
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_vomCostNew'))
             or sum(gn, gn_forecasts(gn, 'ts_vomCostNew'))
             ],
        put log "!!! Error in model 'ts_vomCostNew' forecasts " /;
        put log "!!! Abort: ts_vomCostNew forecasts are activated through ts_price and ts_emissionPrice forecasts"/;
        abort "Abort: forecast should be activated to gn_forecasts('ts_price') and/or to group_forecasts('ts_emissionPrice')";
    ); // END if

    // ts_startupCost
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_startupCost'))
             or sum(gn, gn_forecasts(gn, 'ts_startupCost'))
             ],
        put log "!!! Error in model 'ts_startupCost' forecasts " /;
        put log "!!! Abort: ts_startupCost forecasts are activated through ts_price and ts_emissionPrice forecasts"/;
        abort "Abort: forecast should be activated by moving to new price input tables and using gn_forecasts('ts_price') and/or to group_forecasts('ts_emissionPrice')";
    ); // END if

    // ts_startupCostNew
    if( card(f_active)>1
        and [sum(unit, unit_forecasts(unit, 'ts_startupCostNew'))
             or sum(gn, gn_forecasts(gn, 'ts_startupCostNew'))
             ],
        put log "!!! Error in model 'ts_startupCostNew' forecasts " /;
        put log "!!! Abort: ts_startupCostNew forecasts are activated through ts_price and ts_emissionPrice forecasts"/;
        abort "Abort: forecast should be activated to gn_forecasts('ts_price') and/or to group_forecasts('ts_emissionPrice')";
    ); // END if

* --- Check improveForecastNew parameters -------------------------------------

    // that t_improveForecastNew is larger than t_jump and perfect foresight
    if( %warnings%=1
        and mSettings(m, 't_improveForecastNew') > 0
        and (mSettings(m, 't_improveForecastNew') <= mSettings(m, 't_jump')
             or(mSettings(m, 't_improveForecastNew') <= mSettings(m, 't_perfectForesight'))
             ),
        put log '!!! Warning: mSettings(t_improveForecastNew) is smaller than or equal to t_jump/t_perfectForesight, it will have no effect' /;
    ); // END if

    // check p_u_improveForecastNew
    if(%warnings%=1 and card(p_u_improveForecastNew)>0,

        // warn if values in p_u_improveForecastNew are smaller than t_jump and perfect foresight
        tmp = smin((unit, timeseries_)$p_u_improveForecastNew(unit, timeseries_), p_u_improveForecastNew(unit, timeseries_));
        if( tmp <= mSettings(m, 't_jump')
            or(tmp <= mSettings(m, 't_perfectForesight')),
            put log '!!! Warning: p_u_improveForecastNew has smaller than or equal value(s) to t_jump/t_perfectForesight, those will have no effect' /;
        );

        // warn if giving values to
        // ts_vomCost_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_vomCost_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_vomCost_') does not have functionalities. Use p_u_improveForecastNew('ts_vomCostNew_') instead. " /;
        );
        // ts_startupCost_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_startupCost_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_startupCost_') does not have functionalities. Use p_u_improveForecastNew('ts_startupCostNew_') instead.  " /;
        );
        // ts_vomCostNew_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_vomCostNew_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_vomCostNew_') does not have functionalities. Use p_u_improveForecastNew('ts_vomCostNew_') instead. " /;
        );
        // ts_startupCostNew_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_startupCostNew_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_startupCostNew_') does not have functionalities. Use p_u_improveForecastNew('ts_startupCostNew_') instead.  " /;
        );
        // ts_effUnit_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_effUnit_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_effUnit_') is not allowed and does not have functionalities " /;
        );
        // ts_effGroupUnit_
        if(sum(unit, p_u_improveForecastNew(unit, 'ts_effGroupUnit_'))> 0,
            put log "!!! Warning: p_u_improveForecastNew('ts_effGroupUnit_') is not allowed and does not have functionalities " /;
        );

    ); // END if(%warnings%=1 and card(p_u_improveForecastNew))

    // check p_gn_improveForecastNew
    if(%warnings%=1 and card(p_gn_improveForecastNew)>0,

        // warn if values in p_gn_improveForecastNew are smaller than t_jump and perfect foresight
        tmp = smin((grid, node, timeseries_)$p_gn_improveForecastNew(grid, node, timeseries_), p_gn_improveForecastNew(grid, node, timeseries_));
        if( tmp <= mSettings(m, 't_jump')
            or(tmp <= mSettings(m, 't_perfectForesight')),
            put log '!!! Warning: p_gn_improveForecastNew has smaller than or equal value(s) to t_jump/t_perfectForesight, those will have no effect' /;
        );

        // warn if giving values to
        // ts_price_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_price_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_price_') does not have functionalities. Use p_gn_improveForecastNew('ts_priceNew_') instead." /;
        );
        // ts_emissionPrice_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_emissionPrice_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_emissionPrice_') does not have functionalities. Use p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );
        // ts_vomCost_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_vomCost_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_vomCost_') does not have functionalities. Use p_gn_improveForecastNew('ts_priceNew_') and/or p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );
        // ts_startupCost_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_startupCost_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_startupCost_') does not have functionalities. Use p_gn_improveForecastNew('ts_priceNew_') and/or p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );
        // ts_startupCostNew_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_startupCostNew_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_startupCostNew_') does not have functionalities. Use p_gn_improveForecastNew('ts_priceNew_') and/or p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );
        // ts_linkVomCost_
        if(sum((grid, node), p_gn_improveForecastNew(grid, node, 'ts_linkVomCost_'))> 0,
            put log "!!! Warning: p_gn_improveForecastNew('ts_linkVomCost_') does not have functionalities. Use p_gn_improveForecastNew('ts_priceNew_') and/or p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );
    ); // END if(%warnings%=1 and card(p_gn_improveForecastNew) )


    // check ts_gnu_forecastImprovement
    if(%warnings%=1 and card(ts_gnu_forecastImprovement)>0,

        option gnu_tmp < ts_gnu_forecastImprovement; // gnu_tmp to reduce looping

        // if for f_realization
        loop((gnu_tmp(grid, node, unit), param_gnu, f_active(f))
            $ { ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f)
                and f_realization(f)
                },
            put log "!!! Warning: ts_gnu_forecastImprovement(" grid.tl:0 ", "  node.tl:0 ", "  unit.tl:0 ", " param_gnu.tl:0 ", " f.tl:0 ") is for a realized forecast. This improvement parameter will not have an effect. Typically f00 is realized forecast, but it depends on data." /;
        );

        // if for f that is not active
        loop((gnu_tmp(grid, node, unit), param_gnu, f_active(f))
            $ { ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f)
                and not ts_gnu_activeForecasts(gnu_tmp, param_gnu, f)
                },
            put log "!!! Warning: ts_gnu_forecastImprovement(" grid.tl:0 ", "  node.tl:0 ", "  unit.tl:0 ", " param_gnu.tl:0 ", " f.tl:0 ") is for a forecast that is not active, see ts_gnu_activeForecasts. This improvement parameter will not have an effect." /;
        );

        // if shorter values than t_jump
        loop((gnu_tmp(grid, node, unit), param_gnu, f_active(f))
            $ { ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f)
                and ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f) < mSettings(m, 't_jump')
                },
            put log "!!! Warning: ts_gnu_forecastImprovement(" grid.tl:0 ", "  node.tl:0 ", "  unit.tl:0 ", " param_gnu.tl:0 ", " f.tl:0 ") has smaller than or equal value to t_jump. This improvement parameter will not have an effect." /;
        );

        // if shorter values than t_perfectForesight
        loop((gnu_tmp(grid, node, unit), param_gnu, f_active(f))
            $ { ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f)
                and ts_gnu_forecastImprovement(gnu_tmp, param_gnu, f) < mSettings(m, 't_perfectForesight')
                },
            put log "!!! Warning: ts_gnu_forecastImprovement(" grid.tl:0 ", "  node.tl:0 ", "  unit.tl:0 ", " param_gnu.tl:0 ", " f.tl:0 ") has smaller than or equal value to t_perfectForesight. This improvement parameter will not have an effect." /;
        );
    ); // END if(%warnings%=1 and card(p_group_improveForecastNew) )


    // check p_group_improveForecastNew
    if(%warnings%=1 and card(p_group_improveForecastNew)>0,

        // warn if values in p_group_improveForecastNew are smaller than t_jump and perfect foresight
        tmp = smin((emissionGroup, timeseries_)$p_group_improveForecastNew(emissionGroup, timeseries_), p_group_improveForecastNew(emissionGroup, timeseries_));
        if( tmp <= mSettings(m, 't_jump')
            or(tmp <= mSettings(m, 't_perfectForesight')),
            put log '!!! Warning: p_group_improveForecastNew has smaller than or equal value(s) to t_jump/t_perfectForesight, those will have no effect' /;
        ); // END loop

        // warn if giving values to
        // ts_emissionPrice_
        if(sum((emissionGroup), p_group_improveForecastNew(emissionGroup, 'ts_emissionPrice_'))> 0,
            put log "!!! Warning: p_group_improveForecastNew('ts_emissionPrice_') does not have functionalities. Use p_group_improveForecastNew('ts_emissionPriceNew_') instead." /;
        );

    ); // END if(%warnings%=1 and card(p_gn_improveForecastNew) )



* --- TIME STEPS --------------------------------------------------------------
* --- structure and parameters ------------------------------------------------

    // Check if schedule model has necessary time steps included in the ms.
    // In the case of single sample schedule model, the sample needs to cover from start to start+end+horizon
    if(%warnings%=1
       and card(ms)=1
       and m('schedule'),
       // warn if sample starts after t_start
       if(sum(s, msStart(m, s)) > (mSettings(m, 't_start') ),
           put log '!!! Warning: The start of sample is larger than t_start. Some hours will not be modelled.' /;
       );
       // warn if sample does not span over the hours that should be modelled
       if(sum(s, msEnd(m, s)) < (mSettings(m, 't_start') + mSettings(m, 't_end') + mSettings(m, 't_horizon') ),
           put log '!!! Warning: The end of sample is less than t_start + t_end + t_horizon. Some hours will not be modelled.' /;
       );
    ); // END if(%warnings%=1 and card(ms))

    // Check if time intervals are aggregated before 't_trajectoryHorizon'
    if (%warnings%=1
        and [mInterval(m, 'lastStepInIntervalBlock', 'c000') < mSettings(m, 't_trajectoryHorizon')
             or (mInterval(m, 'stepsPerInterval', 'c000') > 1 and mSettings(m, 't_trajectoryHorizon') > 0)],
        put log '!!! Warning: Trajectories used on aggregated time steps! This could result in significant distortion of the trajectories.' /;
    ); // END if()

    // Check if 't_trajectoryHorizon' is long enough
    if (mSettings(m, 't_trajectoryHorizon') ne 0
        and [mSettings(m, 't_trajectoryHorizon') < mSettings(m, 't_jump') + smax(unit, p_u_runUpTimeIntervalsCeil(unit))
             or mSettings(m, 't_trajectoryHorizon') < mSettings(m, 't_jump') + smax(unit, p_u_shutdownTimeIntervalsCeil(unit)) ],
        put log '!!! Abort: t_trajectoryHorizon should be at least as long as t+jump + max trajectory.';
        abort "t_trajectoryHorizon should be at least as long as t+jump + max trajectory. This may lead to infeasibilities";
    ); // END if()

    // Check that the first interval block is compatible with 't_jump' in the schedule model
    if(sameas(m, 'schedule'),
        if (mod(mSettings(m, 't_jump'), mInterval(m, 'stepsPerInterval', 'c000')) <> 0,
            put log '!!! Abort: t_jump should be divisible by the first interval!' /;
            abort "'t_jump' should be divisible by the first interval!";
        ); // END if()

        if (mInterval(m, 'lastStepInIntervalBlock', 'c000') < mSettings(m, 't_jump'),
            put log '!!! Abort: The first interval block should not be shorter than t_jump!' /;
            abort "The first interval block should not be shorter than 't_jump'!";
        ); // END if()
    ); // END if

    // if ts_unit has longer time series than defined in datalength
    option tt < ts_unit;
    tmp = mSettings(m, 'datalength');
    if(%warnings%=1 and card(tt) > mSettings(m, 'datalength'),
        put log "!!! Warning: ts_unit has more time steps than mSettings('datalength'). Data points after t" tmp:0:0 " will not be used." /;
    ); // END if

    // if ts_influx has longer time series than defined in datalength
    option tt < ts_influx;
    tmp = mSettings(m, 'datalength');
    if(%warnings%=1 and card(tt) > mSettings(m, 'datalength'),
        put log "!!! Warning: ts_influx has more time steps than mSettings('datalength'). Data points after t" tmp:0:0 " will not be used." /;
    ); // END if

    // if ts_cf has longer time series than defined in datalength
    option tt < ts_cf;
    tmp = mSettings(m, 'datalength');
    if(%warnings%=1 and card(tt) > mSettings(m, 'datalength'),
        put log "!!! Warning: ts_cf has for more time steps than mSettings('datalength'). Data points after t" tmp:0:0 " will not be used." /;
    ); // END if

    // if ts_node has longer time series than defined in datalength
    option tt < ts_node;
    tmp = mSettings(m, 'datalength');
    if(%warnings%=1 and card(tt) > mSettings(m, 'datalength'),
        put log "!!! Warning: ts_node has for more time steps than mSettings('datalength'). Data points after t" tmp:0:0 " will not be used." /;
    ); // END if

    // if timeAndSamples.inc have less t than needed by the start of the last solve + t_horizon
    if(card(t) < mSettings(m, 't_end') - mSettings(m, 't_jump') + mSettings(m, 't_horizon'),
        tmp = mSettings(m, 't_end') - mSettings(m, 't_jump') + mSettings(m, 't_horizon');
        put log "!!! Abort: the timeAndSamples.inc does not have enough t to cover the last solve! For this model, at least " tmp:0:0 " timesteps are needed" /;
        abort "The timeAndSamples.inc should have large enough t set to cover at least mSettings('t_end') - mSettings('t_jump') + mSettings('t_horizon')!";
    ); // END if


* --- NODES -------------------------------------------------------------------
* --- checking ts_cf is between [0-1] -----------------------------------------

    // nodes in ts_cf
    option flowNode_tmp < ts_cf;
    // t in ts_cf
    option tt < ts_cf;

    // check which (flow, node) has values below 0 or above 1
    loop(flowNode_tmp(flow, node) $ {%warnings%=1},
        // checking if below 0
        if(smin((f_active, tt),ts_cf(flow, node, f_active, tt))<0,
            // printing a warning that ts_cf has values below 0
            put log '!!! Warning: ts_cf(', flow.tl:0, ', ', node.tl:0, ') has values below 0.' /;
        ); // END if(min < 0)
        // checking if above 1
        if(smax((f_active, tt),ts_cf(flow, node, f_active, tt))>1,
            // printing a warning that ts_cf has values above 1
            put log '!!! Warning: ts_cf(', flow.tl:0, ', ', node.tl:0, ') has values above 1.' /;
        ); // END if(max > 1)
    ); // END loop(flowNode_tmp)



* --- UNITS -------------------------------------------------------------------
* --- effLevels ---------------------------------------------------------------

    // Check that there aren't more effLevels defined than exist in data
    if(card(unit) > card(unit_flow),
        if( smax(effLevel, ord(effLevel)${mSettingsEff(m, effLevel)}) > smax(effLevelGroupUnit(effLevel, effSelector, unit), ord(effLevel)),
            put log '!!! Error occurred on mSettingsEff' /;
            put log '!!! Abort: There are insufficient effLevels in the effLevelGroupUnit data for all the defined mSettingsEff!' /;
            abort "There are insufficient effLevels in the effLevelGroupUnit data for all the defined mSettingsEff!";
        ); // END if(smax)
    ); // END if(other units than flow units defined)


* --- Check the integrity of efficiency approximation related data ------------

// check op definitions
loop( unit_online(unit),

    Option clear = count; // Initialize the previous op to zero
    loop(op $ p_unit(unit, op), // loop op points for each unit

        // Check that 'op' is defined correctly (zero or positive and increasing)
        if (p_unit(unit, op) + 1${not p_unit(unit, op)} <= count,
            put log '!!! Error occurred on unit ' unit.tl:0 /; // Display unit that causes error
            put log '!!! Abort: param_unit op must be defined as zero or positive and increasing for online units!' /;
            abort "param_unit 'op's must be defined as zero or positive and increasing for online units!";
        ); // END if(p_unit)
        count = p_unit(unit, op);

        // Check that if unit has opXX defined, there is matching effXX
        if(sum(eff, p_unit(unit, eff)${ord(eff) = ord(op)}) = 0,
           put log '!!! Error occurred on unit ' unit.tl:0 /; // Display unit that causes error
           put log '!!! Abort: online unit ', unit.tl:0, ' has ', op.tl:0, ' defined, but empty matching eff parameter'  /;
           abort "Each online unit opXX requires mathcing effXX";
        ); // END sum(eff)

    ); // END loop(op)
); // END loop(unit)

* --- Check investment related data -------------------------------------------

    // Check that the investment decisions (LP variant) are not by accident fixed to zero in 3d_setVariableLimits.gms
    loop( unit_investLP(unit),
        if(p_unit(unit, 'becomeAvailable') <= mSettings(m, 't_start'),
            put log '!!! Error occurred on unit ', unit.tl:0 /;
            put log "!!! Abort: Unit with investment possibility should not become available before t_start! Check utAvailabilityLimits(unit, t, 'becomeAvailable')." /;
            abort "The 'utAvailabilityLimits(unit, t, 'becomeAvailable')' should correspond to a timestep in the model without the initial timestep!"
        ); // END if
    ); // END loop(unit_investLP)

    // Check that the investment decisions (MIP variant) are not by accident fixed to zero in 3d_setVariableLimits.gms
    loop( unit_investMIP(unit),
        if(p_unit(unit, 'becomeAvailable') <= mSettings(m, 't_start'),
            put log '!!! Error occurred on unit ', unit.tl:0 /;
            put log '!!! Abort: Unit with investment possibility should not become available before t_start!' /;
            abort "The 'utAvailabilityLimits(unit, t, 'becomeAvailable')' should correspond to a timestep in the model without the initial timestep!"
        ); // END if
    ); // END loop(unit_investMIP)


* --- RESERVES ----------------------------------------------------------------
* --- Reserve structure checks ------------------------------------------------

    loop(restypeDirectionGroup(restype, up_down, group),
        // Check that 'update_frequency' is longer than 't_jump'
        if(p_groupReserves(group, restype, 'update_frequency') < mSettings(m, 't_jump'),
            put log '!!! Error occurred on p_groupReserves ' group.tl:0 ',' restype.tl:0 /;
            put log '!!! Abort: The update_frequency parameter should be longer than or equal to t_jump!' /;
            abort "The 'update_frequency' parameter should be longer than or equal to 't_jump'!";
        ); // END if('update_frequency' < 't_jump')

        // Check that 'update_frequency' is divisible by 't_jump'
        if(mod(p_groupReserves(group, restype, 'update_frequency'), mSettings(m, 't_jump')) <> 0,
            put log '!!! Error occurred on p_groupReserves ' group.tl:0 ',' restype.tl:0 /;
            put log '!!! Abort: The update_frequency parameter should be divisible by t_jump!' /;
            abort "The 'update_frequency' parameter should be divisible by 't_jump'!";
        ); // END if(mod('update_frequency'))

        // Check if the first interval is long enough for proper commitment of reserves in the schedule model
        if(sameas(m, 'schedule'),
            if(mInterval(m, 'lastStepInIntervalBlock', 'c000') < p_groupReserves(group, restype, 'update_frequency') + p_groupReserves(group, restype, 'gate_closure'),
                put log '!!! Error occurred on p_groupReserves ' group.tl:0 ',' restype.tl:0 /;
                put log '!!! Abort: The first interval block should not be shorter than update_frequency + gate_closure for proper commitment of reserves!' /;
                abort "The first interval block should not be shorter than 'update_frequency' + 'gate_closure' for proper commitment of reserves!";
            ); // END if
        ); // END if
    ); // END loop(restypeDirectionGroup)



* --- POLICIES ----------------------------------------------------------------

    // warn if directOff unit has constrainedOnlineMultiplier
    loop(unit $ {%warnings%=1 and sum(group, p_groupPolicyUnit(group, 'constrainedOnlineMultiplier', unit)) },
        if(sum(effLevel, effLevelGroupUnit(effLevel, 'directOff', unit)),
            put log "!!! Warning: unit " unit.tl:0 " has directOff effLevels. ConstrainedOnlineMultiplier does not have any effect in those cases as the unit does not have online variable."  /;
        ); // END if('directOff')
    ); // END loop(unit)

    // q_energyLimit
    // check if p_groupPolicy(group, 'energyMax') or p_groupPolicy(group, 'energyMin') are active,
    // but no sGroup(s, group)
    loop(group $ {%warnings%=1
                  and [p_groupPolicy(group, 'energyMax') or p_groupPolicy(group, 'energyMin')]
                  and not sum(s, sGroup(s, group))
                  },

        put log "!!! Warning: group ", group.tl:0, " has p_groupPolicy('energyMin') or p_groupPolicy('energyMax') but no samples in sGroup(s, group)." /;
    );

    // but no gnuGroup(grid, node, unit, group)
    loop(group $ {%warnings%=1
                  and [p_groupPolicy(group, 'energyMax') or p_groupPolicy(group, 'energyMin')]
                  and not sum(gnu, gnuGroup(gnu, group))
                  },

        put log "!!! Warning: group ", group.tl:0, " has p_groupPolicy('energyMin') or p_groupPolicy('energyMax') but no data in gnuGroup(grid, node, unit, group)." /;
    );


* --- USER CONSTRAINTS --------------------------------------------------------

    // loop groups that define user constraints
    loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
        $ { SameAs(param_userconstraint, 'v_online')
            or SameAs(param_userconstraint, 'v_startup')
            or SameAs(param_userconstraint, 'v_shutdown')
            },
        // check that unit is online unit
        loop(unit
            $ {%warnings%=1
               and p_userconstraint(group, unit, '-', '-', '-', param_userconstraint)
               and not unit_online(unit)
               and not unit_deactivated(unit)
               },
            put log "!!! Warning: unit in p_userconstraint('" group.tl:0 ", "unit.tl:0 "', '-', '-', '-', '" param_userconstraint.tl:0 "') is not online unit and thus not included in equations. See effLevelGroupUnit from input data." /;
        ); // END loop(unit)
    ); // END loop(groupUcParamUserConstraint)

    loop(groupUcParamUserConstraint(group_uc(group), 'sample'),
        // check that sample is an active sample
        loop(s
            $ {%warnings%=1
               and p_userconstraint(group, s, '-', '-', '-', 'sample')
               and not s_active(s)
               },
            put log "!!! Warning: sample in p_userconstraint('" group.tl:0 ", "s.tl:0 "', '-', '-', '-', 'sample') is not an active sample and does not have an effect. Check modelInit file and s_active from debug.gdx." /;
        ); // END loop(s)
    ); // END loop(groupUcParamUserConstraint)

    loop(groupUcParamUserConstraint(group_uc(group), 'forecast'),
        // check that forecast is an active forecast
        loop(f
            $ {%warnings%=1
               and p_userconstraint(group, f, '-', '-', '-', 'forecast')
               and not f_active(f)
               },
            put log "!!! Warning: forecast in p_userconstraint('" group.tl:0 ", "f.tl:0 "', '-', '-', '-', 'forecast') is not an active forecast and does not have an effect. Check modelInit file and f_active debug.gdx." /;
        ); // END loop(f)
    ); // END loop(groupUcParamUserConstraint)

    loop(groupUcParamUserConstraint(group_uc(group), 'timestep'),

        // filtering t in p_userconstraint for more efficient looping
        option clear = tt;
        tt(t)$p_userconstraint(group, t, '-', '-', '-', 'timestep') = yes;

        // check that timestep is an active timestep
        loop(tt
            $ {%warnings%=1
               and not t_full(tt)
               },
            put log "!!! Warning: timestep in p_userconstraint('" group.tl:0 ", "tt.tl:0 "', '-', '-', '-', 'timestep') is outside the modelled t's and does not have an effect. Check modelInit file and t_full from debug.gdx." /;
        ); // END loop(unit)
    ); // END loop(groupUcParamUserConstraint)


); // END loop(m)



* --- ROUNDINGS ---------------------------------------------------------------

// parameters
if(%warnings%=1 and p_roundingParam('p_vomCostNew'),
    put log "!!! Warning: use p_roundingParam('p_vomCost') instead of p_roundingParam('p_vomCostNew')" /;
);
if(%warnings%=1 and p_roundingParam('p_startupCostNew'),
    put log "!!! Warning: use p_roundingParam('p_startupCost') instead of p_roundingParam('p_startupCostNew')" /;
);
if(%warnings%=1 and p_roundingParam('p_emissionPrice'),
    put log "!!! Warning: use p_roundingParam('p_vomCost') and/or p_roundingParam('p_startupCost') instead of p_roundingParam('p_emissionPrice')" /;
);
if(%warnings%=1 and p_roundingParam('p_emissionPriceNew'),
    put log "!!! Warning: use p_roundingParam('p_vomCost') and/or p_roundingParam('p_startupCost') instead of p_roundingParam('p_emissionPriceNew')" /;
);

// timeseries
if(%warnings%=1 and p_roundingTs('ts_unitConstraintNode_'),
    put log "!!! Warning: input data had p_roundingTs('ts_unitConstraint_'). Automatic rounding of constraints and efficiency approximations is not recommended and those features are deactivated." /;
);
if(%warnings%=1 and p_roundingTs('ts_unitConstraintNode_'),
    put log "!!! Warning: input data had p_roundingTs('ts_unitConstraintNode_'). Automatic rounding of constraints and efficiency approximations is not recommended and those features are deactivated." /;
);
if(%warnings%=1 and p_roundingTs('ts_startupCostNew_'),
    put log "!!! Warning: use p_roundingTs('ts_startupCost_') instead of p_roundingTs('ts_startupCostNew_')" /;
);
if(%warnings%=1 and p_roundingTs('ts_groupPolicy_'),
    put log "!!! Warning: input data had p_roundingTs('ts_groupPolicy_'). Automatic rounding of constraints and efficiency approximations is not recommended and those features are deactivated." /;
);
if(%warnings%=1 and p_roundingTs('ts_effUnit_'),
    put log "!!! Warning: input data had p_roundingTs('ts_effUnit_'). Automatic rounding of constraints and efficiency approximations is not recommended and those features are deactivated." /;
);
if(%warnings%=1 and p_roundingTs('ts_effGroupUnit_'),
    put log "!!! Warning: input data had p_roundingTs('ts_effGroupUnit_'). Automatic rounding of constraints and efficiency approximations is not recommended and those features are deactivated." /;
);
