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
    mSettings('schedule', 't_end') = 8736; // Last time step to be included in the solve (may solve and output more time steps in case t_jump does not match)


    // Define simulation horizon and moving horizon optimization "speed"
    mSettings('schedule', 't_horizon') = 8736;    // How many active time steps the solve contains (aggregation of time steps does not impact this, unless the aggregation does not match)
    mSettings('schedule', 't_jump') = 24;          // How many time steps the model rolls forward between each solve

    // Define length of data for proper circulation
    mSettings('schedule', 'dataLength') = 8736;

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

* 1 day hour-by-hour
    // Define the time step intervals in time-steps
    mInterval('schedule', 'stepsPerInterval', 'c000') = 1;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c000') = 60;
    mInterval('schedule', 'stepsPerInterval', 'c001') = 3;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c001') = 72;
    mInterval('schedule', 'stepsPerInterval', 'c002') = 6;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c002') = 96;
    mInterval('schedule', 'stepsPerInterval', 'c003') = 40;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c003') = 336;
    mInterval('schedule', 'stepsPerInterval', 'c004') = 96;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c004') = 720;
    mInterval('schedule', 'stepsPerInterval', 'c005') = 334;
    mInterval('schedule', 'lastStepInIntervalBlock', 'c005') = mSettings('schedule', 't_horizon');






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


* --- Activate specific model features ----------------------------------------

    active('schedule', 'storageValue') = yes;

* --- Define Reserve Properties -----------------------------------------------

    // Define whether reserves are used in the model
    mSettingsReservesInUse('schedule', restype, 'up') = yes;
    mSettingsReservesInUse('schedule', restype, 'down') = no;

* --- Define Unit Approximations ----------------------------------------------

    // Define the last time step for each unit aggregation and efficiency level (3a_periodicInit.gms ensures that there is a effLevel until t_horizon)
    mSettingsEff('schedule', 'level1') = 24;
    mSettingsEff('schedule', 'level2') = mInterval('schedule', 'lastStepInIntervalBlock', 'c002');
    mSettingsEff('schedule', 'level3') = mInterval('schedule', 'lastStepInIntervalBlock', 'c004');

* --- Control the solver ------------------------------------------------------

    // Control the use of advanced basis
    mSettings('schedule', 'loadPoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve
    mSettings('schedule', 'savePoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve




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




); // END if(mType)

* Updating cyclic storage boundary constraints
* H2 does not have boundStart and boundStartToEnd anymore ;)
* EVs and buildings already have boundStart
* Batteries do not have boundStart or boundStartToEnd
gnss_bound(grid, node, s, s_) = no;
node_superpos(node ) =no;
*p_gn(gn('H2', node), 'boundStart') = 0;
*gnss_bound(gn('hydro', node), 's000', 's000') = yes;
*gnss_bound(gn('pumped', node), 's000', 's000') = yes;
*gnss_bound(gn('H2', node), 's000', 's000') = yes;
*p_gn(gn('hydro', node), 'boundStartToEnd') = 1;
*p_gn(gn('pumped', node), 'boundStartToEnd') = 1;
*p_gn(gn('H2', node), 'boundStartToEnd') = 1;
