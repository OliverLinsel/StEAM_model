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
- Loop read new data to time series
- Forecast improvement, old method
- Aggregate time series data for defined time intervals
- Process circular adjustments
- Improving forecast times series, new method
- Checking ts_XX_ limits if using circular data improvement
- Derived unit and cost time series
- Rounding time series
- Reducing the amount of dummy variables
- Print info from looping progress

$offtext


* =============================================================================
* --- Loop read new data to time series ---------------------------------------
* =============================================================================

// executing this section only if mTimeseries_loop_read is defined in the input data
$ifthen.mTimeseries_loop_read defined mTimeseries_loop_read

if (t_solveFirst = tForecastNext(mSolve) - mSettings(mSolve, 't_forecastJump'), // tForecastNext updated already in periodicLoop!

    // Update ts_unit
    if (mTimeseries_loop_read(mSolve, 'ts_unit'),
        put_utility 'gdxin' / '%input_dir%/ts_unit/' t_solve.tl:0 '.gdx';
        execute_load ts_unit_update=ts_unit;
        ts_unit(unit_timeseries(unit, param_unit), f_active(f), tt_forecast(t)) // Only update if time series enabled for the unit
            ${not mf_realization(mSolve, f) // Realization not updated
              and (mSettings(mSolve, 'onlyExistingForecasts')
                   -> ts_unit_update(unit, param_unit, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_unit_update(unit, param_unit, f, t);

    // Refreshing units with time series data enabled
    unit_timeseries(unit, param_unit)${ p_unit(unit, 'useTimeseries') or p_unit(unit, 'useTimeseriesAvailability') }
        = yes;

    ); // END if('ts_unit')

    // Update ts_influx
    if (mTimeseries_loop_read(mSolve, 'ts_influx'),
        put_utility 'gdxin' / '%input_dir%/ts_influx/' t_solve.tl:0 '.gdx';
        execute_load ts_influx_update=ts_influx;
        ts_influx(gn_influx(grid, node), f_active(f), tt_forecast(t))
            ${  not mf_realization(mSolve, f) // Realization not updated
                and (mSettings(mSolve, 'onlyExistingForecasts')
                     -> ts_influx_update(grid, node, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_influx_update(grid, node, f, t);
    ); // END if('ts_influx')

    // Update ts_cf
    if (mTimeseries_loop_read(mSolve, 'ts_cf'),
        put_utility 'gdxin' / '%input_dir%/ts_cf/' t_solve.tl:0 '.gdx';
        execute_load ts_cf_update=ts_cf;
        ts_cf(flowNode(flow, node), f_active(f), tt_forecast(t))
            ${  not mf_realization(mSolve, f) // Realization not updated
                and (mSettings(mSolve, 'onlyExistingForecasts')
                     -> ts_cf_update(flow, node, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_cf_update(flow, node, f, t);
    ); // END if('ts_cf')

    // Update ts_reserveDemand
    if (mTimeseries_loop_read(mSolve, 'ts_reserveDemand'),
        put_utility 'gdxin' / '%input_dir%/ts_reserveDemand/' t_solve.tl:0 '.gdx';
        execute_load ts_reserveDemand_update=ts_reserveDemand;
        ts_reserveDemand(restypeDirectionGroup(restype, up_down, group), f_active(f), tt_forecast(t))
            ${  not mf_realization(mSolve, f) // Realization not updated
                and (mSettings(mSolve, 'onlyExistingForecasts')
                     -> ts_reserveDemand_update(restype, up_down, group, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_reserveDemand_update(restype, up_down, group, f, t);
    ); // END if('ts_reserveDemand')

    // Update ts_node
    if (mTimeseries_loop_read(mSolve, 'ts_node'),
        put_utility 'gdxin' / '%input_dir%/ts_node/' t_solve.tl:0 '.gdx';
        execute_load ts_node_update=ts_node;
        ts_node(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), f_active(f), tt_forecast(t))
            ${  not mf_realization(mSolve, f) // Realization not updated
                and (mSettings(mSolve, 'onlyExistingForecasts')
                     -> ts_node_update(grid, node, param_gnBoundaryTypes, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_node_update(grid, node, param_gnBoundaryTypes, f, t);

    // Refreshing nodes with balance and time series for boundary properties activated
    gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)
        ${p_gn(grid, node, 'nodeBalance')
          and p_gnBoundaryPropertiesForStates(grid, node, param_gnBoundaryTypes, 'useTimeseries')
          }
        = yes;

    ); // END if('ts_node')

    // Update ts_gnn
    if (mTimeseries_loop_read(mSolve, 'ts_gnn'),
        put_utility 'gdxin' / '%input_dir%/ts_gnn/' t_solve.tl:0 '.gdx';
        execute_load ts_gnn_update=ts_gnn;
        ts_gnn(gn2n_timeseries(grid, node, node_, param_gnn), f_active(f), tt_forecast(t)) // Only update if time series enabled
            ${  not mf_realization(mSolve, f) // Realization not updated
                and (mSettings(mSolve, 'onlyExistingForecasts')
                     -> ts_gnn_update(grid, node, node_, param_gnn, f, t)) // Update only existing values (zeroes need to be EPS)
                }
            = ts_gnn_update(grid, node, node_, param_gnn, f, t);

    // Updating transfer links with time series enabled for certain parameters
    gn2n_timeseries(grid, node, node_, 'availability')${p_gnn(grid, node, node_, 'useTimeseriesAvailability')}
        = yes;
    gn2n_timeseries(grid, node, node_, 'transferLoss')${p_gnn(grid, node, node_, 'useTimeseriesLoss')}
        = yes;

    ); // END if('ts_gnn')

); // END if(tForecastNext)

$endif.mTimeseries_loop_read

* =============================================================================
* --- Forecast improvement, old method ----------------------------------------
* =============================================================================

if(mSettings(mSolve, 't_improveForecast'),
* Linear improvement of the central forecast towards the realized forecast,
* while preserving the difference between the central forecast and the
* remaining forecasts

    // Determine the set of improved time steps
    option clear = tt;
    tt(tt_forecast(t))
        ${ ord(t) <= t_solveFirst + mSettings(mSolve, 't_improveForecast') }
        = yes;

    // Temporary forecast displacement to reach the central forecast
    option clear = ddf;
    ddf(f_active(f))
        ${ not mf_central(mSolve, f) }
        = sum(mf_central(mSolve, f_), ord(f_) - ord(f));

    // Temporary forecast displacement to reach the realized forecast
    option clear = ddf_;
    ddf_(f_active(f))
        ${ not mf_realization(mSolve, f) }
        = sum(mf_realization(mSolve, f_), ord(f_) - ord(f));

* --- Calculate the other forecasts relative to the central one ---------------

    loop(f_active(f)${ not mf_realization(mSolve, f) and not mf_central(mSolve, f) },
        // ts_unit
        ts_unit(unit_timeseries(unit, param_unit), f, tt(t))// Only update for units with time series enabled
            = ts_unit(unit, param_unit, f, t) - ts_unit(unit, param_unit, f+ddf(f), t);
        // ts_unitConstraintNode
        ts_unitConstraintNode(unit_tsConstraintNode(unit, constraint, node), f, tt(t))
            = ts_unitConstraintNode(unit, constraint, node, f, t) - ts_unitConstraintNode(unit, constraint, node, f+ddf(f), t);
        // ts_influx
        ts_influx(gn_influx(grid, node), f, tt(t))
            = ts_influx(grid, node, f, t) - ts_influx(grid, node, f+ddf(f), t);
        // ts_cf
        ts_cf(flowNode(flow, node), f, tt(t))
            = ts_cf(flow, node, f, t) - ts_cf(flow, node, f+ddf(f), t);
        // ts_reserveDemand
        ts_reserveDemand(restypeDirectionGroup(restype, up_down, group), f, tt(t))
            = ts_reserveDemand(restype, up_down, group, f, t) - ts_reserveDemand(restype, up_down, group, f+ddf(f), t);
        // ts_node
        ts_node(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), f, tt(t))
            = ts_node(grid, node, param_gnBoundaryTypes, f, t) - ts_node(grid, node, param_gnBoundaryTypes, f+ddf(f), t);
        // ts_gnn
        ts_gnn(gn2n_timeseries(grid, node, node_, param_gnn), f, tt(t)) // Only update if time series enabled
            = ts_gnn(grid, node, node_, param_gnn, f, t) - ts_gnn(grid, node, node_, param_gnn, f+ddf(f), t);
    ); // END loop(f_active)

* --- Linear improvement of the central forecast ------------------------------

    loop(mf_central(mSolve, f),
        // ts_unit
        ts_unit(unit_timeseries(unit, param_unit), f, tt(t)) // Only update for units with time series enabled
            = [ + (ord(t) - t_solveFirst)
                    * ts_unit(unit, param_unit, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_unit(unit, param_unit, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_unitConstraintNode
        ts_unitConstraintNode(unit_tsConstraintNode(unit, constraint, node), f, tt(t))
            = [ + (ord(t) - t_solveFirst)
                    * ts_unitConstraintNode(unit, constraint, node, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_unitConstraintNode(unit, constraint, node, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_influx
        ts_influx(gn_influx(grid, node), f, tt(t))
            = [ + (ord(t) - t_solveFirst)
                    * ts_influx(grid, node, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_influx(grid, node, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_cf
        ts_cf(flowNode(flow, node), f, tt(t))
            = [ + (ord(t) - t_solveFirst)
                    * ts_cf(flow, node, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_cf(flow, node, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_reserveDemand
        ts_reserveDemand(restypeDirectionGroup(restype, up_down, group), f, tt(t))
            = [ + (ord(t) - t_solveFirst)
                    * ts_reserveDemand(restype, up_down, group, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_reserveDemand(restype, up_down, group, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_node
        ts_node(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), f, tt(t))
            = [ + (ord(t) - t_solveFirst)
                    * ts_node(grid, node, param_gnBoundaryTypes, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_node(grid, node, param_gnBoundaryTypes, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
        // ts_gnn
        ts_gnn(gn2n_timeseries(grid, node, node_, param_gnn), f, tt(t)) // Only update if time series enabled
            = [ + (ord(t) - t_solveFirst)
                    * ts_gnn(grid, node, node_, param_gnn, f, t)
                + (t_solveFirst - ord(t) + mSettings(mSolve, 't_improveForecast'))
                    * ts_gnn(grid, node, node_, param_gnn, f+ddf_(f), t)
                ] / mSettings(mSolve, 't_improveForecast');
    ); // END loop(mf_central)

* --- Recalculate the other forecasts based on the improved central forecast --

    loop(f_active(f)${ not mf_realization(mSolve, f) and not mf_central(mSolve, f) },
        // ts_unit
        ts_unit(unit_timeseries(unit, param_unit), f, tt(t)) // Only update for units with time series enabled
            = ts_unit(unit, param_unit, f, t) + ts_unit(unit, param_unit, f+ddf(f), t);
        // ts_influx
        ts_influx(gn_influx(grid, node), f, tt(t))
            = ts_influx(grid, node, f, t) + ts_influx(grid, node, f+ddf(f), t);
        // ts_cf
        ts_cf(flowNode(flow, node), f, tt(t))
            = max(min(ts_cf(flow, node, f, t) + ts_cf(flow, node, f+ddf(f), t), 1), 0); // Ensure that capacity factor forecasts remain between 0-1
        // ts_reserveDemand
        ts_reserveDemand(restypeDirectionGroup(restype, up_down, group), f, tt(t))
            = max(ts_reserveDemand(restype, up_down, group, f, t) + ts_reserveDemand(restype, up_down, group, f+ddf(f), t), 0); // Ensure that reserve demand forecasts remains positive
       // ts_node
        ts_node(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), f, tt(t))
            = ts_node(grid, node, param_gnBoundaryTypes, f, t) + ts_node(grid, node, param_gnBoundaryTypes, f+ddf(f), t);
        // ts_gnn
        ts_gnn(gn2n_timeseries(grid, node, node_, param_gnn), f, tt(t)) // Only update if time series enabled
            = ts_gnn(grid, node, node_, param_gnn, f, t) + ts_gnn(grid, node, node_, param_gnn, f+ddf(f), t);
    ); // END loop(f_active)

); // END if(t_improveForecast)


* =============================================================================
* --- Aggregate time series data for defined time intervals -------------------
* =============================================================================

// Loop over the defined blocks of intervals
loop(counter_intervals(counter),

    // Retrieve interval block time steps
    option clear = tt_interval;
    tt_interval(t_active(t)) $ tt_block(counter, t) = yes;

* --- unit specific time series -----------------------------------------------
    // ts_unit_ for active t in solve including aggregated time steps
    ts_unit_(unit_timeseries(unit, param_unit), ft(f, tt_interval(t)))
        = sum(tt_agg_circular(t, t_, t__),
            ts_unit(unit, param_unit, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unit'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_unitConstraint_ for active t in solve including aggregated time steps
    ts_unitConstraint_(unit_tsConstraint(unit, constraint), param_constraint, ft(f, tt_interval(t)))
        = sum(tt_agg_circular(t, t_, t__),
            ts_unitConstraint(unit, constraint, param_constraint, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unitConstraint'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_unitConstraintNode_ for active t in solve including aggregated time steps
    ts_unitConstraintNode_(unit_tsConstraintNode(unit, constraint, node), ft(f, tt_interval(t)))
        = sum(tt_agg_circular(t, t_, t__),
            ts_unitConstraintNode(unit, constraint, node, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unitConstraintNode'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

* --- gn specific time series -------------------------------------------------
    // ts_influx_ for active t in solve including aggregated time steps
    ts_influx_(gn_influx(grid, node), ft(f, tt_interval(t)))
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_influx(grid, node, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_influx'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_cf_ for active t in solve including aggregated time steps
    ts_cf_(flowNode(flow, node), ft(f, tt_interval(t)))
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_cf(flow, node, f +[df_realization(f)$(not gn_forecasts(flow, node, 'ts_cf'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_node_ for active t in solve including aggregated time steps
    ts_node_(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), ft(f, tt_interval(t)))
        = (
            // Use average if not a limit type or slack
            + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
                  ts_node(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                ) // END sum(tt_agg_circular)
                / mInterval(mSolve, 'stepsPerInterval', counter)
            )${ not (sameas(param_gnBoundaryTypes, 'upwardLimit')
                     or sameas(param_gnBoundaryTypes, 'downwardLimit')
                     or slack(param_gnBoundaryTypes)) }

          // Use maximum for lower limit
          + smax(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
                ts_node(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                ) // END smax
                $sameas(param_gnBoundaryTypes, 'downwardLimit')

          // Use minimum for upper limit and slacks
          + smin(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
                ts_node(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                ) // END smin
                $(sameas(param_gnBoundaryTypes, 'upwardLimit') or slack(param_gnBoundaryTypes))
    ;

    // ts_price_ for active t in solve including aggregated time steps
    ts_price_(node, tt_interval(t))
        ${p_price(node, 'useTimeSeries')}
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_price(node, t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_priceNew_ for active t in solve including aggregated time steps
    ts_priceNew_(node, ft(f, tt_interval(t)))
        ${p_priceNew(node, f, 'useTimeSeries')}
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_priceNew(node, f +[df_realization(f)$(not sum(grid, gn_forecasts(grid, node, 'ts_priceNew')))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_storageValue_ for active t in solve including aggregated time steps
    ts_storageValue_(gn_state(grid, node), ft(f, tt_interval(t)))${ p_gn(grid, node, 'storageValueUseTimeSeries') }
        = sum(tt_agg_circular(t, t_, t__),
            ts_storageValue(grid, node, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_storageValue'))], t_)
            ) // END sum(tt_agg_circular)
            / mInterval(mSolve, 'stepsPerInterval', counter);


* --- gnu time series ---------------------------------------------------------

    // ts_gnu_ for active t in solve including aggregated time steps
    ts_gnu_(gnu_timeseries(grid, node, unit, param_gnu), ft(f, tt_interval(t)))
        = + sum(tt_agg_circular(t, t_, t__), ts_gnu_io(grid, node, unit, 'input', param_gnu, f +[df_realization(f)$(not ts_gnu_activeForecasts(grid, node, unit, param_gnu, f))], t_)
               ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter)
          + sum(tt_agg_circular(t, t_, t__), ts_gnu_io(grid, node, unit, 'output', param_gnu, f +[df_realization(f)$(not ts_gnu_activeForecasts(grid, node, unit, param_gnu, f))], t_)
               ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);


* --- gnn time series ---------------------------------------------------------

    // ts_gnn_ for active t in solve including aggregated time steps
    ts_gnn_(gn2n_timeseries(grid, node, node_, param_gnn), ft(f, tt_interval(t)))
        = sum(tt_agg_circular(t, t_, t__), ts_gnn(grid, node, node_, param_gnn, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t_)
             ) // END sum(tt_agg_circular)
            / mInterval(mSolve, 'stepsPerInterval', counter);


* --- reserve specific time series --------------------------------------------
    // ts_reserveDemand_ for active t in solve including aggregated time steps
    // Reserves relevant only until reserve_length
    ts_reserveDemand_(restypeDirectionGroup(restype, up_down, group), ft(f, tt_interval(t)))
      ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')}
        = sum(tt_agg_circular(t, t_, t__),
            ts_reserveDemand(restype, up_down, group,
                             f +[df_realization(f)${not sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reserveDemand'))}], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_reservePrice_ for active t in solve including aggregated time steps
    // Reserves relevant only until reserve_length
    ts_reservePrice_(restypeDirectionGroup(restype, up_down, group), ft(f, tt_interval(t)))
      ${ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')
        and p_groupReserves(group, restype, 'usePrice')
        and p_reservePrice(restype, up_down, group, f, 'useTimeSeries') }
        = sum(tt_agg_circular(t, t_, t__),
            ts_reservePrice(restype, up_down, group,
                             f +[df_realization(f)${not sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reservePrice'))}], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);


* --- group specific time series ----------------------------------------------

    // ts_emissionPrice
    ts_emissionPrice_(emissionGroup(emission, group), tt_interval(t))
        ${p_emissionPrice(emission, group, 'useTimeSeries')}
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_emissionPrice(emission, group, t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_emissionPriceNew
    ts_emissionPriceNew_(emissionGroup(emission, group), ft(f, tt_interval(t)))
        ${p_emissionPriceNew(emission, group, f, 'useTimeSeries')}
        = + sum(tt_agg_circular(t, t_, t__), // circular average of input data, including aggregation if in use
              ts_emissionPriceNew(emission, group, f +[df_realization(f)$(not group_forecasts(emission, group, 'ts_emissionPriceNew'))], t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

    // ts_groupPolicy_ for active t in solve including aggregated time steps
    // note: same values for each forecast
    ts_groupPolicy_(group, param_policy, tt_interval(t))
        ${ groupPolicyTimeseries(group, param_policy) }
        = sum(tt_agg_circular(t, t_, t__),
            ts_groupPolicy(group, param_policy, t_)
              ) // END sum(tt_agg_circular)
              / mInterval(mSolve, 'stepsPerInterval', counter);

); // END loop(counter)



* =============================================================================
* --- Process circular adjustments --------------------------------------------
* =============================================================================

// excecute following lines of code only if unit_tsCirculation is given in input data
$ifthen.unit_tsCirculation defined unit_tsCirculation

// checking if unit_tsCirculation('interpolateStepChange') is actived
if(sum((timeseries, unit, f_active), unit_tsCirculation(timeseries, unit, f_active, 'interpolateStepChange', 'isActive')),

    // filtering t that are larger than dataLength and smaller than maximum unit_tsCirculation(timeseries, unit, f, 'end')
    option clear = tt;
    tmp =  smax((timeseries, unit, f_active), unit_tsCirculation(timeseries, unit, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > mSettings(mSolve, 'dataLength') )
                    and (ord(t) <= tmp)
                    } = yes;

    // ts_unit
    ts_unit_(unit_timeseries(unit, param_unit), ft(f, tt(t)))
        $unit_tsCirculation('ts_unit', unit, f, 'interpolateStepChange', 'isActive')
        = ts_unit_(unit, param_unit, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_unit_circularAdjustment(unit, param_unit, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unit'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_unitConstraint
    ts_unitConstraint_(unit_tsConstraint(unit, constraint), param_constraint, ft(f, tt(t)))
        $unit_tsCirculation('ts_unitConstraint', unit, f, 'interpolateStepChange', 'isActive')
        = ts_unitConstraint_(unit, constraint, param_constraint, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_unitConstraint_circularAdjustment(unit, constraint, param_constraint, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unitConstraint'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_unitConstraintNode
    ts_unitConstraintNode_(unit_tsConstraintNode(unit, constraint, node), ft(f, tt(t)))
        $unit_tsCirculation('ts_unitConstraintNode', unit, f, 'interpolateStepChange', 'isActive')
        = ts_unitConstraintNode_(unit, constraint, node, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_unitConstraintNode_circularAdjustment(unit, constraint, node, f +[df_realization(f)$(not unit_forecasts(unit, 'ts_unitConstraintNode'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

); // END if(unit_tsCirculation('interpolateStepChange')

$endif.unit_tsCirculation


// excecute following lines of code only if gn_tsCirculation is given in input data
$ifthen.gn_tsCirculation defined gn_tsCirculation

// checking if gn_tsCirculation('interpolateStepChange') is actived
if(sum((timeseries, gn, f_active), gn_tsCirculation(timeseries, gn, f_active, 'interpolateStepChange', 'isActive')),

    // filtering t that are larger than dataLength and smaller than maximum gn_tsCirculation(timeseries, grid/flow, node, f, 'end')
    option clear = tt;
    tmp =  smax((timeseries, gn, f_active), gn_tsCirculation(timeseries, gn, f_active, 'interpolateStepChange', 'end'));
    tt(t_full(t))$ {(ord(t) > mSettings(mSolve, 'dataLength') )
                    and (ord(t) <= tmp)
                    } = yes;

    // ts_influx
    ts_influx_(gn_influx(grid, node), ft(f, tt(t)))
        $gn_tsCirculation('ts_influx', grid, node, f, 'interpolateStepChange', 'isActive')
        = ts_influx_(grid, node, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_influx_circularAdjustment(grid, node, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_influx'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_cf
    ts_cf_(flowNode(flow, node), ft(f, tt(t)))
        $gn_tsCirculation('ts_cf', flow, node, f, 'interpolateStepChange', 'isActive')
        = ts_cf_(flow, node, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_cf_circularAdjustment(flow, node, f +[df_realization(f)$(not gn_forecasts(flow, node, 'ts_cf'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_node
    ts_node_(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), ft(f, tt(t)))
        $gn_tsCirculation('ts_node', grid, node, f, 'interpolateStepChange', 'isActive')
        = + (
             // Use average if not a limit type or slack
             ts_node_(grid, node, param_gnBoundaryTypes, f, t) // previously calculated ts_XX_ values
             + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
                 ts_node_circularAdjustment(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                 ) // END sum(tt_aggregate)
                 / p_stepLength(t)
             )${ not (sameas(param_gnBoundaryTypes, 'upwardLimit')
                      or sameas(param_gnBoundaryTypes, 'downwardLimit')
                      or slack(param_gnBoundaryTypes)) }

          // Use maximum for lower limit
          + (ts_node_(grid, node, param_gnBoundaryTypes, f, t) // previously calculated ts_XX_ values
             + smax(tt_aggregate(t, t_), // maximum of circular adjustment if in use, including aggregation if in use
                  ts_node_circularAdjustment(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                  )
             )$ sameas(param_gnBoundaryTypes, 'downwardLimit')

          // Use minimum for upper limit and slacks
          + (ts_node_(grid, node, param_gnBoundaryTypes, f, t) // previously calculated ts_XX_ values
             + smin(tt_aggregate(t, t_), // minimum of circular adjustment if in use, including aggregation if in use
                 ts_node_circularAdjustment(grid, node, param_gnBoundaryTypes, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_node'))], t_)
                 )
             )$ {sameas(param_gnBoundaryTypes, 'upwardLimit') or slack(param_gnBoundaryTypes)}
    ;

    // ts_gnn
    ts_gnn_(gn2n_timeseries(grid, node, node_, param_gnn), ft(f, tt(t)))
        $gn_tsCirculation('ts_gnn', grid, node, f, 'interpolateStepChange', 'isActive')
        = ts_gnn_(grid, node, node_, param_gnn, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_gnn_circularAdjustment(grid, node, node_, param_gnn, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_priceNew
    ts_priceNew_(node, ft(f, tt(t)))
        ${sum(grid, gn_tsCirculation('ts_priceNew', grid, node, f, 'interpolateStepChange', 'isActive')) }
        = ts_priceNew_(node, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_priceNew_circularAdjustment(node, f +[df_realization(f)$(not sum(grid, gn_forecasts(grid, node, 'ts_priceNew')))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

    // ts_storageValue
    ts_storageValue_(gn_state(grid, node), ft(f, tt(t)))
        $gn_tsCirculation('ts_storageValue', grid, node, f, 'interpolateStepChange', 'isActive')
        = ts_storageValue_(grid, node, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_storageValue_circularAdjustment(grid, node, f +[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t_)
              ) // END sum(tt_aggregate)
              / p_stepLength(t);

); // END if(gn_tsCirculation('interpolateStepChange')

$endif.gn_tsCirculation


// excecute following lines of code only if gn_tsCirculation is given in input data
$ifthen.reserve_tsCirculation defined reserve_tsCirculation

    // ts_reserveDemand
    ts_reserveDemand_(restypeDirectionGroup(restype, up_down, group), ft(f, tt(t)))
      ${reserve_tsCirculation('ts_reserveDemand', restype, up_down, group, f, 'interpolateStepChange', 'isActive')
        and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')}
        = ts_reserveDemand_(restype, up_down, group, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_reserveDemand(restype, up_down, group,
                               f +[df_realization(f)${not sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reserveDemand'))}], t_)
              )
              / p_stepLength(t);

    // ts_reservePrice
    ts_reservePrice_(restypeDirectionGroup(restype, up_down, group), ft(f, tt(t)))
      ${reserve_tsCirculation('ts_reservePrice', restype, up_down, group, f, 'interpolateStepChange', 'isActive')
        and ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length')}
        = ts_reservePrice_(restype, up_down, group, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_reservePrice(restype, up_down, group,
                               f +[df_realization(f)${not sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reservePrice'))}], t_)
              )
              / p_stepLength(t);

$endif.reserve_tsCirculation

// excecute following lines of code only if gn_tsCirculation is given in input data
$ifthen.group_tsCirculation defined group_tsCirculation

    // ts_emissionPrice
    ts_emissionPriceNew_(emissionGroup(emission, group), ft(f, tt(t)))
      ${group_tsCirculation('ts_emissionPriceNew', emission, group, f, 'interpolateStepChange', 'isActive')}
        = ts_emissionPriceNew_(emission, group, f, t) // previously calculated ts_XX_ values
          + sum(tt_aggregate(t, t_), // average of circular adjustment if in use, including aggregation if in use
              ts_emissionPriceNew(emission, group,
                               f +[df_realization(f)$(not group_forecasts(emission, group, 'ts_emissionPriceNew'))], t_)
              )
              / p_stepLength(t);

$endif.group_tsCirculation

* =============================================================================
* --- Improving forecast times series, new method -----------------------------
* =============================================================================
* Linear improvement of forecasts towards the realized forecast

// excecute the this section if user gives data to any of these three places
if({mSettings(mSolve, 't_improveForecastNew')
    or card(p_gn_improveForecastNew)>0
    or card(p_u_improveForecastNew)>0
    or card(p_group_improveForecastNew)>0
    },

    // Determine the set of time steps where to apply the improvement
    option clear = tt;
    tt(tt_forecast(t))
        ${ t_active(t)
           and not t_realizedNoReset(t)
           and not t_start(t)}
        = yes;

    // looping interval counters as formulas need to sum over the original time series
    // and divide the sum by the number of steps in interval.
    loop(counter_intervals(counter),

        // Retrieve interval block time steps
        option clear = tt_interval;
        tt_interval(tt(t)) = tt_block(counter, t) ;

        // the structure of each ts_XX_ is following
        // ts_XX_(dimensions) limited to sft(s, f, t) and tt(t)
        // if not f_realization and forecasts are activated
        //  = (factor1 * forecast value) + [factor2 * (realized value + circular adjustment if used)]
        // where forecast value is previously calculated ts_XX_
        //       realized value is summed from ts_XX
        //       factor1 is linearly increasing weigth (ord(t) - t_solveFirst) / improvedSteps
        //       factor2 is linearly decreasing weigth (t_solveFirst - ord(t) + improvedSteps) / improvedSteps
        // where improvedSteps is primarily specific input value, e.g. p_gn_improveForecastNew(grid, node, 'ts_influx_')
        //                        and secondarily generic mSettings(mSolve, 't_improveForecastNew')


* --- unit time series --------------------------------------------------------

        // ts_unit_
        ts_unit_(unit_timeseries(unit, param_unit), ft(f, tt_interval(t)) )
            $ { unit_forecasts(unit, 'ts_unit') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unit_')}
                               + p_u_improveForecastNew(unit, 'ts_unit_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                     * ts_unit_(unit, param_unit, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unit_')}
                     + p_u_improveForecastNew(unit, 'ts_unit_')
                     )
                     * [sum(tt_agg_circular(t, t_, t__), ts_unit(unit, param_unit, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_unit_circularAdjustment(unit, param_unit, f+df_realization(f), t_))]
                     / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unit_')}
                   + p_u_improveForecastNew(unit, 'ts_unit_')
                   ] ;

        // ts_unitConstraint_
        ts_unitConstraint_(unit_tsConstraint(unit, constraint), param_constraint, ft(f, tt_interval(t)))
            $ { unit_forecasts(unit, 'ts_unitConstraint') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraint_')}
                               + p_u_improveForecastNew(unit, 'ts_unitConstraint_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                     * ts_unitConstraint_(unit, constraint, param_constraint, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraint_')}
                     + p_u_improveForecastNew(unit, 'ts_unitConstraint_')
                     )
                     * [sum(tt_agg_circular(t, t_, t__), ts_unitConstraint(unit, constraint, param_constraint, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_unitConstraint_circularAdjustment(unit, constraint, param_constraint, f+df_realization(f), t_))]
                     / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraint_')}
                   + p_u_improveForecastNew(unit, 'ts_unitConstraint_')
                   ] ;

        // ts_unitConstraintNode_
        ts_unitConstraintNode_(unit_tsConstraintNode(unit, constraint, node), ft(f, tt_interval(t)))
            $ { unit_forecasts(unit, 'ts_unitConstraintNode') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraintNode_')}
                               + p_u_improveForecastNew(unit, 'ts_unitConstraintNode_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                     * ts_unitConstraintNode_(unit, constraint, node, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraintNode_')}
                     + p_u_improveForecastNew(unit, 'ts_unitConstraintNode_')
                     )
                     * [sum(tt_agg_circular(t, t_, t__), ts_unitConstraintNode(unit, constraint, node, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_unitConstraintNode_circularAdjustment(unit, constraint, node, f+df_realization(f), t_))]
                     / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_u_improveForecastNew(unit, 'ts_unitConstraintNode_')}
                   + p_u_improveForecastNew(unit, 'ts_unitConstraintNode_')
                   ] ;

* --- gn time series ----------------------------------------------------------
        // ts_influx_
        ts_influx_(gn_influx(grid, node), ft(f, tt_interval(t)) )
            $ { gn_forecasts(grid, node, 'ts_influx') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_influx_')}
                               + p_gn_improveForecastNew(grid, node, 'ts_influx_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                     * ts_influx_(grid, node, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_influx_')}
                     + p_gn_improveForecastNew(grid, node, 'ts_influx_')
                     )
                     * [sum(tt_agg_circular(t, t_, t__), ts_influx(grid, node, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_influx_circularAdjustment(grid, node, f+df_realization(f), t_)) ]
                     / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_influx_')}
                   + p_gn_improveForecastNew(grid, node, 'ts_influx_')
                   ] ;

        // ts_cf_
        ts_cf_(flowNode(flow, node), ft(f, tt_interval(t)) )
            $ { gn_forecasts(flow, node, 'ts_cf') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(flow, node, 'ts_cf_')}
                               + p_gn_improveForecastNew(flow, node, 'ts_cf_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_cf_(flow, node, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(flow, node, 'ts_cf_')}
                     + p_gn_improveForecastNew(flow, node, 'ts_cf_')
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_cf(flow, node, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_cf_circularAdjustment(flow, node, f+df_realization(f), t_)) ]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(flow, node, 'ts_cf_')}
                   + p_gn_improveForecastNew(flow, node, 'ts_cf_')
                   ] ;

        // ts_node_
        ts_node_(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), ft(f, tt_interval(t)) )
            $ { gn_forecasts(grid, node, 'ts_node') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_node_')}
                               + p_gn_improveForecastNew(grid, node, 'ts_node_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_node_(grid, node, param_gnBoundaryTypes, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_node_')}
                     + p_gn_improveForecastNew(grid, node, 'ts_node_')
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_node(grid, node, param_gnBoundaryTypes, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_node_circularAdjustment(grid, node, param_gnBoundaryTypes, f+df_realization(f), t_)) ]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_node_')}
                   + p_gn_improveForecastNew(grid, node, 'ts_node_')
                   ] ;

        // ts_priceNew
        ts_priceNew_(node, ft(f, tt_interval(t)) )
            $ { sum(grid, gn_forecasts(grid, node, 'ts_priceNew')) // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_')) }
                               + sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_')) ]
                }
            = [ + (ord(t) - t_solveFirst)
                     * ts_priceNew_(node, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_')) }
                     + sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_'))
                     )
                     * [sum(tt_agg_circular(t, t_, t__), ts_priceNew(node, f+df_realization(f), t_))
                        + sum(tt_aggregate(t, t_), ts_priceNew_circularAdjustment(node, f+df_realization(f), t_)) ]
                     / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_')) }
                   + sum(grid, p_gn_improveForecastNew(grid, node, 'ts_priceNew_'))
                   ] ;

        // ts_storagevalue_
        ts_storageValue_(gn_state(grid, node), ft(f, tt_interval(t)))
            $ { gn_forecasts(grid, node, 'ts_storageValue') // if ts_XX has forecasts
                and p_gn(grid, node, 'storageValueUseTimeSeries')
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_storageValue_')}
                               + p_gn_improveForecastNew(grid, node, 'ts_storageValue_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_storageValue_(grid, node, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_storageValue_')}
                     + p_gn_improveForecastNew(grid, node, 'ts_storageValue_')
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_storageValue(grid, node, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_storageValue_circularAdjustment(grid, node, f+df_realization(f), t_))]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_storageValue_')}
                   + p_gn_improveForecastNew(grid, node, 'ts_storageValue_')
                   ] ;

* --- gnn time series ---------------------------------------------------------

        // ts_gnn_
        ts_gnn_(gn2n_timeseries(grid, node, node_, param_gnn), ft(f, tt_interval(t)) )
            $ { gn_forecasts(grid, node, 'ts_gnn') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_gnn_')}
                               + p_gn_improveForecastNew(grid, node, 'ts_gnn_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_gnn_(grid, node, node_, param_gnn, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_gnn_')}
                     + p_gn_improveForecastNew(grid, node, 'ts_gnn_')
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_gnn(grid, node, node_, param_gnn, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_gnn_circularAdjustment(grid, node, node_, param_gnn, f+df_realization(f), t_))]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_gn_improveForecastNew(grid, node, 'ts_gnn_')}
                   + p_gn_improveForecastNew(grid, node, 'ts_gnn_')
                   ] ;

* --- gnu time series ---------------------------------------------------------

        // ts_gnu_
        ts_gnu_(gnu_timeseries(grid, node, unit, param_gnu), ft(f, tt_interval(t)) )
            $ { ts_gnu_activeForecasts(grid, node, unit, param_gnu, f) // if forecasts activated
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not sum(f_active(f), ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f))}
                               + ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f) ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_gnu_(grid, node, unit, param_gnu, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not sum(f_active(f), ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f))}
                     + ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f)
                     )
                    * [sum(tt_agg_circular(t, t_, t__), sum(input_output, ts_gnu_io(grid, node, unit, input_output, param_gnu, f+df_realization(f), t_)))
                       + sum(tt_aggregate(t, t_), ts_gnu_circularAdjustment(grid, node, unit, param_gnu, f+df_realization(f), t_))]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not sum(f_active(f), ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f))}
                   + ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f)
                   ] ;


* --- reserve time series -----------------------------------------------------

        // ts_reserveDemand_
        ts_reserveDemand_(restypeDirectionGroup(restype, up_down, group), ft(f, tt_interval(t)) )
            $ { sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reserveDemand')) // if ts_XX has forecasts
                and not f_realization(f)
                and (ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length'))
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_'))}
                               + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_')) ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_reserveDemand_(restype, up_down, group, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_'))}
                     + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_'))
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_reserveDemand(restype, up_down, group, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_reserveDemand_circularAdjustment(restype, up_down, group, f+df_realization(f), t_)) ]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_'))}
                   + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reserveDemand_'))
                   ] ;

        // ts_reservePrice_
        ts_reservePrice_(restypeDirectionGroup(restype, up_down, group), ft(f, tt_interval(t)) )
            $ { sum(gnGroup(grid, node, group), gn_forecasts(restype, node, 'ts_reservePrice')) // if ts_XX has forecasts
                and not f_realization(f)
                and (ord(t) <= t_solveFirst + p_groupReserves(group, restype, 'reserve_length'))
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_'))}
                               + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_')) ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_reservePrice_(restype, up_down, group, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_'))}
                     + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_'))
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_reservePrice(restype, up_down, group, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_reservePrice_circularAdjustment(restype, up_down, group, f+df_realization(f), t_)) ]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_'))}
                   + sum(gnGroup(grid, node, group), p_gn_improveForecastNew(restype, node, 'ts_reservePrice_'))
                   ] ;

* --- group time series -------------------------------------------------------
        // ts_emissionPriceNew_
        ts_emissionPriceNew_(emissionGroup(emission, group), ft(f, tt_interval(t)) )
            $ { group_forecasts(emission, group, 'ts_emissionPriceNew') // if ts_XX has forecasts
                and not f_realization(f)
                and [ord(t) <= t_solveFirst
                               + mSettings(mSolve, 't_improveForecastNew')${not p_group_improveForecastNew(emission, group, 'ts_reservePrice_')}
                               + p_group_improveForecastNew(emission, group, 'ts_emissionPriceNew_') ]
                }
            = [ + (ord(t) - t_solveFirst)
                    * ts_emissionPriceNew_(emission, group, f, t)
                + (t_solveFirst
                     - ord(t)
                     + mSettings(mSolve, 't_improveForecastNew')${not p_group_improveForecastNew(emission, group, 'ts_emissionPriceNew_')}
                     + p_group_improveForecastNew(emission, group, 'ts_emissionPriceNew_')
                     )
                    * [sum(tt_agg_circular(t, t_, t__), ts_emissionPriceNew(emission, group, f+df_realization(f), t_))
                       + sum(tt_aggregate(t, t_), ts_emissionPriceNew_circularAdjustment(emission, group, f+df_realization(f), t_)) ]
                    / mInterval(mSolve, 'stepsPerInterval', counter)
                ]
                / [+ mSettings(mSolve, 't_improveForecastNew')${not p_group_improveForecastNew(emission, group, 'ts_emissionPriceNew_')}
                   + p_group_improveForecastNew(emission, group, 'ts_emissionPriceNew_')
                   ] ;

        // ts_groupPolicy_


* --- derived unit time series ---------------------------------------
        // no forecast improvement for derived ts_XX_ as those are calculated for each solve separately

    ); // END loop(counter_intervals)

); // END if(t_improveForecastNew)



* =============================================================================
* --- Checking ts_XX_ limits if using circular data improvement ---------------
* =============================================================================

// excecute following lines of code only if gn_tsCirculation is given in input data
$ifthen.gn_tsCirculation defined gn_tsCirculation

if(sum((flowNode(flow, node), f_active), gn_tsCirculation('ts_cf', flow, node, f_active, 'interpolateStepChange', 'isActive')),

    // Ensure that capacity factor forecasts remain between 0-1
    ts_cf_(flowNode(flow, node), ft(f, t))
        = max(min(ts_cf_(flow, node, f, t), 1), 0);

); // if gn_tsCirculation('ts_cf', 'interpolateStepChange')

$endif.gn_tsCirculation



* =============================================================================
* --- Derived unit and cost time series ---------------------------------------
* =============================================================================


* --- Process other unit time series data -----------------------------------

// Calculate time series form parameters for units using direct input output conversion without online variable
// Always constant 'lb', 'rb', and 'section', so need only to define 'slope'.
loop(effGroupSelectorUnit(effDirectOff, unit, effDirectOff_)
    $ { p_unit(unit, 'useTimeseries') },
    ts_effUnit_(effDirectOff, unit, effDirectOff_, 'slope', ft(f, t))
        ${ sum(eff, ts_unit_(unit, eff, f, t)) } // NOTE!!! Averages the slope over all available data.
        = sum(eff${ts_unit_(unit, eff, f, t)}, 1 / ts_unit_(unit, eff, f, t))
            / sum(eff${ts_unit_(unit, eff, f, t)}, 1);
); // END loop(effGroupSelectorUnit)

// NOTE! Using the same methodology for the directOn and lambda approximations in time series form might require looping over ft(f, t) to find the min and max 'eff' and 'rb'
// Alternatively, one might require that the 'rb' is defined in a similar structure, so that the max 'rb' is located in the same index for all ft(f, t)

// NOTE! does not have +df_realization in the f index

// Calculate unit wide parameters for each efficiency group
loop(effLevelGroupUnit(effLevel, effGroup, unit)${  mSettingsEff(mSolve, effLevel)
                                                    and p_unit(unit, 'useTimeseries')
                                                    },
    ts_effGroupUnit_(effGroup, unit, 'lb', ft(f, t))${   sum(effSelector, ts_effUnit_(effGroup, unit, effSelector, 'lb', f, t))}
        = smin(effSelector${effGroupSelectorUnit(effGroup, unit, effSelector)}, ts_effUnit_(effGroup, unit, effSelector, 'lb', f, t));
    ts_effGroupUnit_(effGroup, unit, 'slope', ft(f, t))${sum(effSelector, ts_effUnit_(effGroup, unit, effSelector, 'slope', f, t))}
        = smin(effSelector$effGroupSelectorUnit(effGroup, unit, effSelector), ts_effUnit_(effGroup, unit, effSelector, 'slope', f, t)); // Uses maximum efficiency for the group
); // END loop(effLevelGroupUnit)



* --- ts_vomCost, ts_startupCost ----------------------------------------------

if(card(p_vomCost) > 0,

    // t in ft
    option tt < ft;

    // ts_vomCost_
    //   = gnu vom costs
    //     + gnu emission costs
    //     + gn costs
    //     + gn emission costs
    ts_vomCost_(gnu_vomCost(grid, node, unit), tt(t))
        ${p_vomCost(grid, node, unit, 'useTimeseries')
          and sum(sf, usft(unit, sf, t))}
        = // gnu specific vomCosts (EUR/MWh). Always a cost (positive) for all inputs or outputs.
          + p_gnu(grid, node, unit, 'vomCosts') $ {not gnu_timeseries(grid, node, unit, 'vomCosts')}    // EUR/MWh
          + sum(f_realization(f), ts_gnu_(grid, node, unit, 'vomCosts', f, t)) $ {gnu_timeseries(grid, node, unit, 'vomCosts')}    // EUR/MWh

          // gnu specific emission cost (e.g. process related LCA emission). Always a cost regardless if from input or output.
          + sum(emissionGroup(emission, group)${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)}, // EUR/MWh
              + p_gnuEmission(grid, node, unit, emission, 'vomEmissions')                                         // tCO2/MWh
                  * ( + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant') // EUR/tCO2, constant
                      + ts_emissionPrice_(emission, group, t)$p_emissionPrice(emission, group, 'useTimeSeries')   // EUR/tCO2, time series
                      )
              ) // end sum(emissiongroup)

          // gn specific costs (EUR/MWh). Cost (positive) when input but income (negative) when output.
          // converting gn specific costs negative if output -> income
          + [+1$gnu_input(grid, node, unit)
             -1$gnu_output(grid, node, unit)
             ] // END changing sings for input/output
             * [ // gn specific node cost, e.g. fuel price (EUR/MWh). Cost when input but income when output.
                 + p_price(node, 'price')${p_price(node, 'useConstant')}  // EUR/MWh, constant
                 + ts_price_(node, t)${p_price(node, 'useTimeSeries')}    // EUR/MWh, time series

                 // gn specific emission cost, e.g. CO2 allowance price from fuel emissions. Cost when from input but income when from output.
                 + sum(emissionGroup(emission, group)${p_nEmission(node, emission) and gnGroup(grid, node, group)},   // EUR/MWh
                      + p_nEmission(node, emission)  // t/MWh                                                          // tCO2/MWh
                        * [ + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')  // EUR/tCO2, constant
                            + ts_emissionPrice_(emission, group, t)$p_emissionPrice(emission, group, 'useTimeSeries')    // EUR/tCO2, time series
                            ]
                      ) // end sum(emissiongroup)
                 ]; // END * gn specific costs

    // ts_startupCost
    ts_startupCost_(unit, starttype, tt(t))
        ${p_startupCost(unit, starttype, 'useTimeSeries')
          and sum(sf, usft(unit, sf, t))}
      = + p_uStartup(unit, starttype, 'cost') // EUR/start-up
        // Start-up fuel and emission costs
        + sum(nu_startup(node, unit),
            + p_unStartup(unit, node, starttype) // MWh/start-up
              * [
                  // Fuel costs
                  + p_price(node, 'price')$p_price(node, 'useConstant') // EUR/MWh
                  + ts_price_(node, t)$p_price(node, 'useTimeseries')    // EUR/MWh
                  // Emission costs
                  // node specific emission prices
                  + sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                     + p_nEmission(node, emission) // t/MWh
                     * ( + p_emissionPrice(emission, group, 'price')$p_emissionPrice(emission, group, 'useConstant')
                         + ts_emissionPrice_(emission, group, t)$p_emissionPrice(emission, group, 'useTimeSeries')
                       )
                    ) // end sum(emissionGroup)
                ] // END * p_unStartup
          ); // END sum(nu_startup)

); // END if(card(p_vomCost))


* --- ts_vomCostNew, ts_startupCostNew ----------------------------------------

if(card(p_vomCostNew) > 0,

    // ts_vomCostNew_
    // note: forecast spesific
    //   = gnu vom costs
    //     + gnu emission costs
    //     + gn costs
    //     + gn emission costs
    ts_vomCostNew_(gnu_vomCost(grid, node, unit), ft(f, t) )
        ${p_vomCostNew(grid, node, unit, f, 'useTimeseries')
          and sum(s, usft(unit, s, f, t))}
        = // gnu specific cost (EUR/MWh). Always a cost (positive) for all inputs or outputs.
            // gnu specific vomCosts
            + p_gnu(grid, node, unit, 'vomCosts') $ {not gnu_timeseries(grid, node, unit, 'vomCosts')}    // EUR/MWh
            + ts_gnu_(grid, node, unit, 'vomCosts', f, t) $ {gnu_timeseries(grid, node, unit, 'vomCosts')}    // EUR/MWh

            // gnu specific emission cost (e.g. process related LCA emission). Always a cost regardless if from input or output.
            + sum(emissionGroup(emission, group)${p_gnuEmission(grid, node, unit, emission, 'vomEmissions') and gnGroup(grid, node, group)}, // EUR/MWh
                + p_gnuEmission(grid, node, unit, emission, 'vomEmissions')                                         // tCO2/MWh
                    * ( + p_emissionPriceNew(emission, group, f, 'price') // EUR/tCO2, constant. Possible forecast displacement already calculated in previous steps.
                            $p_emissionPriceNew(emission, group, f, 'useConstant')
                        + ts_emissionPriceNew_(emission, group, f, t) // EUR/tCO2, time series. Possible forecast displacement already calculated in previous steps.
                            $p_emissionPriceNew(emission, group, f, 'useTimeSeries')
                        )
                ) // end sum(emissiongroup)
            // END * gnu specific costs

        // gn specific costs (EUR/MWh). Cost (positive) when input but income (negative) when output.
          // converting gn specific costs negative if output -> income
          + (+1$gnu_input(grid, node, unit)
             -1$gnu_output(grid, node, unit)
             ) // END changing sings for input/output

          * ( // gn specific node cost, e.g. fuel price or sold electricity (EUR/MWh). Cost when input but income when output.
              + p_priceNew(node, f, 'price') // EUR/MWh, constant. Possible forecast displacement already calculated in previous steps.
                  ${p_priceNew(node, f, 'useConstant')}
              + ts_priceNew_(node, f, t)  // EUR/MWh, time series. Possible forecast displacement already calculated in previous steps.
                  ${p_priceNew(node, f, 'useTimeSeries')}

              // gn specific emission cost, e.g. CO2 allowance price from fuel emissions. Cost when from input but income when from output.
              + sum(emissionGroup(emission, group)${p_nEmission(node, emission) and gnGroup(grid, node, group)},   // EUR/MWh
                  + p_nEmission(node, emission)  // t/MWh                                                          // tCO2/MWh
                  * ( + p_emissionPriceNew(emission, group, f, 'price')  // EUR/tCO2, constant. Possible forecast displacement already calculated in previous steps.
                          $p_emissionPriceNew(emission, group, f, 'useConstant')
                      + ts_emissionPriceNew_(emission, group, f, t)    // EUR/tCO2, time series. Possible forecast displacement already calculated in previous steps.
                          $p_emissionPriceNew(emission, group, f, 'useTimeSeries')
                     )
                  ) // end sum(emissiongroup)
            ); // END * gn specific costs

    // ts_startupCostNew
    // note: forecast spesific
    ts_startupCostNew_(unitStarttype(unit, starttype), ft(f, t) )
        ${p_startupCostNew(unit, starttype, f, 'useTimeSeries')
          and sum(s, usft(unit, s, f, t))}
      = + p_uStartup(unit, starttype, 'cost') // EUR/start-up
        // Start-up fuel and emission costs
        + sum(nu_startup(node, unit),
            + p_unStartup(unit, node, starttype) // MWh/start-up
              * [
                  // Fuel costs
                  + p_priceNew(node, f, 'price') // EUR/MWh, constant. Possible forecast displacement already calculated in previous steps.
                      $p_priceNew(node, f, 'useConstant')
                  + ts_priceNew_(node, f, t)  // EUR/MWh, time series. Possible forecast displacement already calculated in previous steps.
                      $p_priceNew(node, f, 'useTimeseries')
                  // Emission costs
                  // node specific emission prices
                  + sum(emissionGroup(emission, group)$p_nEmission(node, emission),
                     + p_nEmission(node, emission) // t/MWh
                     * ( + p_emissionPriceNew(emission, group, f, 'price') // EUR/tCO2, constant. Possible forecast displacement already calculated in previous steps.
                             $p_emissionPriceNew(emission, group, f, 'useConstant')
                         + ts_emissionPriceNew_(emission, group, f, t) // EUR/tCO2, time series. Possible forecast displacement already calculated in previous steps.
                             $p_emissionPriceNew(emission, group, f, 'useTimeSeries')
                       )
                    ) // end sum(emissionGroup)
                ] // END * p_unStartup
          ); // END sum(nu_startup)

); // END if(card(p_vomCostNew))

* --- ts_linkVomCost ----------------------------------------------------------

// ts_linkVomCost = gnn vomCosts + gn costs, including losses
ts_linkVomCost_(gn2n(grid, node, node_), ft(f, t) )
    ${p_linkVomCost(grid, node, node_, f, 'useTimeseries')}
    = // vomCost for transfer links in between of two balance nodes
      + p_gnn(grid, node, node_, 'variableTransCost')${ gn_balance(grid, node) and gn_balance(grid, node_) }

      // When buying (node is price node, node_ is balance node)
      + [ // Cost of bought energy
          + ts_price_(node, t)          // EUR/MWh, time series.
          + ts_priceNew_(node, f, t)    // EUR/MWh, time series, new format. Possible forecast displacement already calculated.
          ] $ {not gn_balance(grid, node) and gn_balance(grid, node_) }
      + // When selling (node is balance node, node_ is price node)
        [ // transfer link vom cost (EUR/MWh). Always a cost (positive), but accounted only for seller.
          + p_gnn(grid, node, node_, 'variableTransCost')$gn_balance(grid, node)

          // Income from sold energy
          - ts_price_(node_, t)          // EUR/MWh, time series.
          - ts_priceNew_(node_, f, t)    // EUR/MWh, time series, new format. Possible forecast displacement already calculated.
          ] $ {gn_balance(grid, node) and not gn_balance(grid, node_) }
        * [ // Assuming that seller accounts for costs related to transfer losses
            + 1
            - p_gnn(grid, node, node_, 'transferLoss')${not gn2n_timeseries(grid, node, node_, 'transferLoss')}
            - ts_gnn_(grid, node, node_, 'transferLoss', f+[df_realization(f)$(not gn_forecasts(grid, node, 'ts_gnn'))], t)${gn2n_timeseries(grid, node, node_, 'transferLoss')}
            ]
;


* =============================================================================
* --- Rounding time series ----------------------------------------------------
* =============================================================================

// Rounding long floats can improve the compile speed slightly (less numbers to handle)
// and makes the model easier for solver to handle (less ticks per solve).

* --- unit time series --------------------------------------------------------
ts_unit_(unit_timeseries(unit, param_unit), ft(f, t))
    $ {p_roundingTs('ts_unit_') and ts_unit_(unit, param_unit, f, t) }
    = round(ts_unit_(unit, param_unit, f, t), p_roundingTs('ts_unit_'))
;
ts_vomCost_(gnu(grid, node, unit), t_active(t))
    $ {p_roundingTs('ts_vomCost_') and ts_vomCost_(grid, node, unit, t) }
    = round(ts_vomCost_(grid, node, unit, t), p_roundingTs('ts_vomCost_'))
;
ts_vomCostNew_(gnu(grid, node, unit), ft(f, t))
    $ {p_roundingTs('ts_vomCost_') and ts_vomCostNew_(grid, node, unit, f, t) }
    = round(ts_vomCostNew_(grid, node, unit, f, t), p_roundingTs('ts_vomCost_'))
;
if(%warnings%=1 and p_roundingTs('ts_vomCostNew_'),
    put log "!!! Warning: use p_roundingTs('ts_vomCost_') instead of p_roundingTs('ts_vomCostNew_')" /;
);
ts_startupCost_(unit, starttype, t_active(t))
    $ {p_roundingTs('ts_startupCost_') and ts_startupCost_(unit, starttype, t) }
    = round(ts_startupCost_(unit, starttype, t), p_roundingTs('ts_startupCost_'))
;
ts_startupCostNew_(unit, starttype, ft(f, t))
    $ {p_roundingTs('ts_startupCost_') and ts_startupCostNew_(unit, starttype, f, t) }
    = round(ts_startupCostNew_(unit, starttype, f, t), p_roundingTs('ts_startupCost_'))
;

* --- gn time series ----------------------------------------------------------
ts_influx_(gn_influx(grid, node), ft(f, t))
    $ {p_roundingTs('ts_influx_') and ts_influx_(grid, node, f, t) }
    = round(ts_influx_(grid, node, f, t), p_roundingTs('ts_influx_'))
;
ts_cf_(flownode(flow, node), ft(f, t))
    $ {p_roundingTs('ts_cf_') and ts_cf_(flow, node, f, t) }
    = round(ts_cf_(flow, node, f, t), p_roundingTs('ts_cf_'))
;
ts_node_(gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes), ft(f, t))
    $ {p_roundingTs('ts_node_') and ts_node_(grid, node, param_gnBoundaryTypes, f, t) }
    = round(ts_node_(grid, node, param_gnBoundaryTypes, f, t), p_roundingTs('ts_node_'))
;
ts_gnn_(gn2n_timeseries(grid, node, node_, param_gnn), ft(f, t))
    $ {p_roundingTs('ts_gnn_') and ts_gnn_(grid, node, node_, param_gnn, f, t) }
    = round(ts_gnn_(grid, node, node_, param_gnn, f, t), p_roundingTs('ts_gnn_'))
;
ts_linkVomCost_(gn2n(grid, node, node_), ft(f, t))
    $ {p_roundingTs('ts_linkVomCost_') and ts_linkVomCost_(grid, node, node_, f, t) }
    = round(ts_linkVomCost_(grid, node, node_, f, t), p_roundingTs('ts_linkVomCost_'))
;
ts_storageValue_(gn_state(grid, node), ft(f, t))
    $ {p_roundingTs('ts_storageValue_') and ts_storageValue_(grid, node, f, t) }
    = round(ts_storageValue_(grid, node, f, t), p_roundingTs('ts_storageValue_'))
;

* --- group time series -------------------------------------------------------
ts_reserveDemand_(restypeDirectionGroup(restype, up_down, group), ft(f, t))
    $ {p_roundingTs('ts_reserveDemand_') and ts_reserveDemand_(restype, up_down, group, f, t) }
    = round(ts_reserveDemand_(restype, up_down, group, f, t), p_roundingTs('ts_reserveDemand_'))
;
ts_reservePrice_(restypeDirectionGroup(restype, up_down, group), ft(f, t))
    $ {p_roundingTs('ts_reservePrice_') and ts_reservePrice_(restype, up_down, group, f, t) }
    = round(ts_reservePrice_(restype, up_down, group, f, t), p_roundingTs('ts_reservePrice_'))
;


* =============================================================================
* --- Reducing the amount of dummy variables ----------------------------------
* =============================================================================

// filtering (grid, node, t) where vq_gen will be dropped if mSettings(m, 'reducedVqGen') >= 2
if(mSettings(mSolve, 'reducedVqGen') >= 2,

    // clear from previous solve
    option clear = dropVqGenInc_gnt;
    option clear = dropVqGenDec_gnt;

    // if not dropVqGen_gn (vqGen would be generated), but ord(t) < t_solveFirst + reducedAmountOfVqGen
    dropVqGenInc_gnt(gn_balance(grid, node), t_active(t))
        ${not dropVqGenInc_gn(grid, node)
          and not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqGen') }
        = yes;
    dropVqGenDec_gnt(gn_balance(grid, node), t_active(t))
        ${not dropVqGenDec_gn(grid, node)
          and not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqGen') }
        = yes;

); // END if(mSettings('reducedVqGen'))


// filtering (gnu_rampUp, t) and (gnu_rampDown, t) where vq_genRampUp and vq_genRampDown will be dropped
if(mSettings(mSolve, 'reducedVqGenRamp') >= 2,

    // clear from previous solve
    option clear = dropVqGenRamp_gnut;

    // not generating rampUp dummies for the hours between t_solveFirst and reducedVqGenRamp
    dropVqGenRamp_gnut(gnu_rampUp(grid, node, unit), t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqGenRamp') }
        = yes;

    // not generating rampDown dummies for the hours between t_solveFirst and reducedVqGenRamp
    dropVqGenRamp_gnut(gnu_rampDown(grid, node, unit), t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqGenRamp') }
        = yes;

); // END if(mSettings('reducedVqResDemand'))


// filtering (restype, up_down, group, t) where vq_resDemand will be dropped if mSettings(m, 'reducedVqResDemand') >= 2
if(mSettings(mSolve, 'reducedVqResDemand') >= 2,

    // clear from previous solve
    option clear = dropVqResDemand;

    // if ord(t) < t_solveFirst + reducedAmountOfVqResDemand
    dropVqResDemand(restypeDirectionGroup(restype, up_down, group), t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqResDemand') }
        = yes;

); // END if(mSettings('reducedVqResDemand'))

// filtering (restype, up_down, group, t) where vq_resMissing will be dropped if mSettings(m, 'reducedVqResMissing') >= 2
if(mSettings(mSolve, 'reducedVqResMissing') >= 2,

    // clear from previous solve
    option clear = dropVqResMissing;

    // if ord(t) < t_solveFirst + reducedAmountOfVqResDemand
    dropVqResMissing(restypeDirectionGroup(restype, up_down, group), t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqResMissing')
          and sum(f, ft_reservesFixed(group, restype, f+df_reservesGroup(group, restype, f, t), t))
          }
        = yes;

); // END if(mSettings('reducedVqResMissing'))

// filtering (unit, constraint, t) where vq_unitConstraint will be dropped if mSettings(m, 'reducedVqUnitConstraint') >= 2
if(mSettings(mSolve, 'reducedVqUnitConstraint') >= 2,

    // clear from previous solve
    option clear = dropVqUnitConstraint;

    // if ord(t) < t_solveFirst + reducedAmountOfVqResDemand
    dropVqUnitConstraint(UnitConstraint(Unit, constraint), t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqUnitConstraint')
          and [p_unitConstraintNew(unit, constraint, 'constant')<>0
               or sum(f, ts_unitConstraint_(unit, constraint, 'constant', f+df_central_t(f, t), t))
               ]
          }
        = yes;

); // END if(mSettings('reducedVqUnitConstraint'))


// filtering (group_uc, t) where vq_userconstraint will be dropped if mSettings(m, 'reducedVqUserconstraint') >= 2
if(mSettings(mSolve, 'reducedVqUserconstraint') >= 2,

    // clear from previous solve
    option clear = dropVqUserconstraint;

    // if ord(t) < t_solveFirst + reducedAmountOfVqResDemand
    dropVqUserconstraint(group_uc, t_active(t))
        ${not t_start(t)
          and ord(t) <= t_solveFirst + mSettings(mSolve, 'reducedVqUserconstraint')
          }
        = yes;

); // END if(mSettings('reducedVqUnitConstraint'))



* =============================================================================
* --- Print info from looping progress ----------------------------------------
* =============================================================================

tmp = round([mSettings(mSolve, 't_end') - mSettings(mSolve, 't_start')] / mSettings(mSolve, 't_jump'), 0);

put log 'ord t_solve: ';
put log t_solveFirst:0:0 /;
put log 'solve count : '
put log solveCount:0:0 '/' tmp:0:0 /;

putclose log;
