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
* --- Model Definition - invest ---------------------------------------------
* =============================================================================

if (mType('invest'),
    m('invest') = yes; // Definition, that the model exists by its name

* --- Define Key Execution Parameters in Time Indeces -------------------------

    // Define simulation start and end time indeces
    mSettings('invest', 't_start') = 1;  // First time step to be solved, 1 corresponds to t000001 (t000000 will then be used for initial status of dynamic variables)
    mSettings('invest', 't_end') = 24*16+1; // Last time step to be included in the solve (may solve and output more time steps in case t_jump does not match)

    // Define simulation horizon and moving horizon optimization "speed"
    mSettings('invest', 't_horizon') = 24*16+1;    // How many active time steps the solve contains (aggregation of time steps does not impact this, unless the aggregation does not match)
    mSettings('invest', 't_jump') = 24*16+1;          // How many time steps the model rolls forward between each solve

    // Define 24 of data for proper circulation
    mSettings('invest', 'dataLength') = 24*16;

* =============================================================================
* --- Model Time Structure ----------------------------------------------------
* =============================================================================

* --- Define Samples ----------------------------------------------------------

    // Number of samples used by the model
    mSettings('invest', 'samples') = 16;

    // Define Initial and Central samples
    ms_initial('invest', 's000') = yes;
    ms_central('invest', 's000') = yes;

    // Define time span of samples
	msStart('invest', 's000') = 744;
	msEnd('invest', 's000') = 775)
	msStart('invest', 's001') = 2928;
	msEnd('invest', 's001') = 3050)
	msStart('invest', 's002') = 5856;
	msEnd('invest', 's002') = 6100)
	msStart('invest', 's003') = 7320;
	msEnd('invest', 's003') = 7625)
	msStart('invest', 's004') = 8736;
	msEnd('invest', 's004') = 9100)


    // Define the probability (weight) of samples
    p_msProbability('invest', s) = 0;
	p_msProbability('invest', 's000') = 1;
	p_msProbability('invest', 's001') = 1;
	p_msProbability('invest', 's002') = 1;
	p_msProbability('invest', 's003') = 1;
	p_msProbability('invest', 's004') = 1;

    p_msWeight('invest', s) = 0;
	p_msWeight('invest', 's000') = 91;
	p_msWeight('invest', 's001') = 91;
	p_msWeight('invest', 's002') = 91;
	p_msWeight('invest', 's003') = 91;
	p_msWeight('invest', 's004') = 1;

    p_msAnnuityWeight('invest', s) = 0;
    p_msAnnuityWeight('invest', 's000') = 2184/8760;
    p_msAnnuityWeight('invest', 's001') = 2184/8760;
    p_msAnnuityWeight('invest', 's002') = 2184/8760;
    p_msAnnuityWeight('invest', 's003') = 2184/8760;
    p_msAnnuityWeight('invest', 's004') = 24/8760;


* --- Define Time Step Intervals ----------------------------------------------

    // Define the duration of a single time-step in hours
    mSettings('invest', 'stepLengthInHours') = 1;

    // Define the time step intervals in time-steps
    mInterval('invest', 'stepsPerInterval', 'c000') = 1;
    mInterval('invest', 'lastStepInIntervalBlock', 'c000') = 24*16+1;
    
* --- z-structure for superpositioned nodes ----------------------------------

    mz('invest', z) = no;
    zs(z,s) = no;


* =============================================================================
* --- Model Forecast Structure ------------------------------------------------
* =============================================================================

    // Define the number of forecasts used by the model
    mSettings('invest', 'forecasts') = 1;

    // Define Realized and Central forecasts
    mf_realization('invest', f) = no;
    mf_realization('invest', 'f00') = yes;
    mf_central('invest', f) = no;
    mf_central('invest', 'f00') = yes;

    // Define forecast probabilities (weights)
    p_mfProbability('invest', f) = 0;
    p_mfProbability(mf_realization('invest', f)) = 1;



* =============================================================================
* --- Model Features ----------------------------------------------------------
* =============================================================================

* --- Define Reserve Properties -----------------------------------------------

    // Define whether reserves are used in the model
    mSettingsReservesInUse('invest', 'primary', 'up') = no;
    mSettingsReservesInUse('invest', 'primary', 'down') = no;
    mSettingsReservesInUse('invest', 'secondary', 'up') = no;
    mSettingsReservesInUse('invest', 'secondary', 'down') = no;
    mSettingsReservesInUse('invest', 'tertiary', 'up') = no;
    mSettingsReservesInUse('invest', 'tertiary', 'down') = no;

* --- Define Unit Approximations ----------------------------------------------

    // Define the last time step for each unit aggregation and efficiency level (3a_periodicInit.gms ensures that there is a effLevel until t_horizon)
    mSettingsEff('invest', 'level1') = 24;
    mSettingsEff('invest', 'level2') = Inf;

* --- Control the solver ------------------------------------------------------

    // Control the use of advanced basis
    mSettings('invest', 'loadPoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve
    mSettings('invest', 'savePoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve

); // END if(mType)
