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
$offtext

* =============================================================================
* --- Model Definition - Schedule ---------------------------------------------
* =============================================================================

if (mType('schedule'),
    m('schedule') = yes; // Definition, that the model exists by its name

* --- Define Key Execution Parameters in Time Indeces -------------------------

    // Define simulation start and end time indeces
    mSettings('schedule', 't_start') = 1;  // First time step to be solved, 1 corresponds to t000001 (t000000 will then be used for initial status of dynamic variables)
    mSettings('schedule', 't_end') = 24*365; // Last time step to be included in the solve (may solve and output more time steps in case t_jump does not match)


    // Define simulation horizon and moving horizon optimization "speed"
    mSettings('schedule', 't_horizon') = 8760;    // How many active time steps the solve contains (aggregation of time steps does not impact this, unless the aggregation does not match)
    mSettings('schedule', 't_jump') = 8760;          // How many time steps the model rolls forward between each solve

    // Define length of data for proper circulation
    mSettings('schedule', 'dataLength') = 8760;

* =============================================================================
* --- Model Time Structure ----------------------------------------------------
* =============================================================================

* --- Define Samples ----------------------------------------------------------

    // Number of samples used by the model
    mSettings('schedule', 'samples') = 1;

    // Define Initial and Central samples
    ms_initial('schedule', 's000') = yes;
    ms_central('schedule', 's000') = yes;

    // Define time span of samples
    msStart('schedule', 's000') = 1;
    msEnd('schedule', 's000') = msStart('schedule', 's000') + mSettings('schedule', 't_end') + mSettings('schedule', 't_horizon');

    // Define the probability (weight) of samples
    p_msProbability('schedule', s) = 0;
    p_msProbability('schedule', 's000') = 1;
    p_msWeight('schedule', s) = 0;
    p_msWeight('schedule', 's000') = 1;
    p_msAnnuityWeight('schedule', s) = 0;
    p_msAnnuityWeight('schedule', 's000') = 1;



* --- Define Time Step Intervals ----------------------------------------------

    // Define the duration of a single time-step in hours
    mSettings('schedule', 'stepLengthInHours') = 1;

    // Define the time step intervals in time-steps
    // example: 1 day hour-by-hour, aggregated time steps in the horizon
    mInterval('schedule', 'stepsPerInterval', 'c000') = 1;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c000') = mSettings('schedule', 't_horizon');


* =============================================================================
* --- Model Forecast Structure ------------------------------------------------
* =============================================================================

    // Define the number of forecasts used by the model
    mSettings('schedule', 'forecasts') = 0;

    // Define Realized and Central forecasts
    mf_realization('schedule', 'f00') = yes;
    mf_central('schedule', 'f00') = yes;

    // Define forecast probabilities (weights)
    p_mfProbability('schedule', f) = 0;
    p_mfProbability(mf_realization('schedule', f)) = 1;

    p_s_discountFactor('s000') = 1;

* =============================================================================
* --- Model Features ----------------------------------------------------------
* =============================================================================
    // Define active model features

* --- Storage value -----------------------------------------------------------

    active('schedule', 'storageValue') = no;

* --- Define Reserve Properties -----------------------------------------------

    // Define whether reserves are used in the model
    mSettingsReservesInUse('schedule', restype, up_down) = no;


* --- Define Unit Approximations ----------------------------------------------

    // Define the last time step for each unit aggregation and efficiency level (3a_periodicInit.gms ensures that there is a effLevel until t_horizon)
    mSettingsEff('schedule', 'level1') = mInterval('schedule', 'lastStepInIntervalBlock', 'c000');



* --- z-structure for superpositioned nodes ----------------------------------

    // add the candidate periods to model
    // no need to touch this part
    // The set is mainly used in the 'invest' model
    mz('schedule', z) = no;

    // Mapping between typical periods (=samples) and the candidate periods (z).
    // Assumption is that candidate periods start from z000 and form a continuous
    // sequence.
    // The set is mainly used in the 'invest' model
    zs(z,s) = no;


* =============================================================================
* --- Solver Features ---------------------------------------------------------
* =============================================================================

* --- Control the solver ------------------------------------------------------

    // Control the use of advanced basis
    mSettings('schedule', 'loadPoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve
    mSettings('schedule', 'savePoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve


* --- solver speed improvements ------------------------------------------------------
    //available from v3.9 onwards

    // Option to reduce the amount of dummy variables. 0 = off = default. 1 = automatic for unrequired dummies. 
    // Values 2... remove also possibly needed dummies from N first hours (time steps) of the solve.
    // Using value that ar larger than t_horizon drops all dummy variables from the solve. 
    // Impacts vq_gen, vq_reserveDemand, vq_resMissing, vq_unitConstraint, and vq_userconstraint   
    // NOTE: Should be used only with well behaving models
    // NOTE: this changes the shape of the problem and there are typically differences in the decimals of the solutions
    // NOTE: It is the best to keep 0 here when editing and updating the model and drop the dummies only when running a stable model.      
    mSettings('schedule', 'reducedDummies') = 0;  
                       
    // Scaling the model with a factor of 10^N. 0 = off = default. Accepted values 1-6.                                         
    // This option might improve the model behaviour in case the model has "infeasibilities after unscaling" issue.
    // It also might improve the solve time of well behaving model, but this is model specific and the option might also slow the model.
    mSettings('schedule', 'scalingMethod') = 0; 

    // Automatic rounding of cost parameters, ts_influx, ts_node, ts_cf, ts_gnn, and ts_reserveDemand. 0 = off = default. 1 = on. 
    mSettings('schedule', 'automaticRoundings') = 1; 

); // END if(mType)
