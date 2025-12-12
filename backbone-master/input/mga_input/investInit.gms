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

//test for modeling horizon through MainInput.xlsx:                 //while this works fine starting in the middle of the data via model_date.csv makes all units unavailable atm... should be configured dynamically as well if need be ## to do ##
//$call gdxxrw.exe ..\PythonScripts\TEMP\MainInput.xlsx output=bb_model_date.gdx index=bb_index!
//Scalar steam_model_duration;
//Scalar steam_model_start;
//$gdxin bb_model_date.gdx
//$load steam_model_duration
//$load steam_model_start
//$gdxin

sGroup('s000','fuelGroup') = yes; // this connects our (time) sample to the fuelGroup which is handling the CO2 emissionCap parameter

* =============================================================================
* --- Model Definition - Invest -----------------------------------------------
* =============================================================================

if (mType('invest'),
    m('invest') = yes; // Definition, that the model exists by its name

* --- Define Key Execution Parameters in Time Indeces -------------------------

    // Define simulation start and end time indeces
    mSettings('invest', 't_start') = 1;  // First time step to be solved, 1 corresponds to t000001 (t000000 will then be used for initial status of dynamic variables)
    mSettings('invest', 't_end') = 8760+1; // Last time step to be included in the solve (may solve and output more time steps in case t_jump does not match)

    // Define simulation horizon and moving horizon optimization "speed"
    mSettings('invest', 't_horizon') = 8760+1;    // How many active time steps the solve contains (aggregation of time steps does not impact this, unless the aggregation does not match)
    mSettings('invest', 't_jump') = 8760+1;          // How many time steps the model rolls forward between each solve

    // Define 168 of data for proper circulation
    mSettings('invest', 'dataLength') = 8760;
* =============================================================================
* --- Model Time Structure ----------------------------------------------------
* =============================================================================

* --- Define Samples ----------------------------------------------------------

* --- Define Samples ----------------------------------------------------------

    // Number of samples used by the model
    mSettings('invest', 'samples') = 3;

    // Define Initial and Central samples
    ms_initial('invest', 's000') = yes;
    ms_central('invest', 's000') = yes;

    // Define time span of samples
	msStart('invest', 's000') = 7561;
	msEnd('invest', 's000') = 7729;
	msStart('invest', 's001') = 1177;
	msEnd('invest', 's001') = 1345;
	msStart('invest', 's002') = 3697;
	msEnd('invest', 's002') = 3865;


    // Define the probability (weight) of samples
    p_msProbability('invest', s) = 0;
	p_msProbability('invest', 's000') = 1;
	p_msProbability('invest', 's001') = 1;
	p_msProbability('invest', 's002') = 1;

    p_msWeight('invest', s) = 0;
	p_msWeight('invest', 's000') = 15.142857;
	p_msWeight('invest', 's001') = 16.000000;
	p_msWeight('invest', 's002') = 21.000000;

    p_msAnnuityWeight('invest', s) = 0;
    p_msAnnuityWeight('invest', 's000') = 2544.000000/8760;
    p_msAnnuityWeight('invest', 's001') = 2688.000000/8760;
    p_msAnnuityWeight('invest', 's002') = 3528.000000/8760;

* --- Define Time Step Intervals ----------------------------------------------

    // Define the duration of a single time-step in hours
    mSettings('invest', 'stepLengthInHours') = 1;

    // Define the time step intervals in time-steps
    mInterval('invest', 'stepsPerInterval', 'c000') = 1;
    mInterval('invest', 'lastStepInIntervalBlock', 'c000') = 8760+1;

* --- z-structure for superpositioned nodes ----------------------------------

    // number of candidate periods in model
    // please provide this data
    mSettings('invest', 'candidate_periods') = 53;//0;

    // add the candidate periods to model
    // no need to touch this part
    mz('invest', z) = no;
    loop(z$(ord(z) <= mSettings('invest', 'candidate_periods') ),
       mz('invest', z) = yes;
    );

    // Mapping between typical periods (=samples) and the candidate periods (z).
    // Assumption is that candidate periods start from z000 and form a continuous
    // sequence.
    // please provide this data
    zs(z,s) = no;
    //zs('z000','s000') = yes;
    //zs('z001','s000') = yes;
    //zs('z002','s001') = yes;
    //zs('z003','s001') = yes;
    //zs('z004','s002') = yes;
    //zs('z005','s003') = yes;
    //zs('z006','s004') = yes;
    //zs('z007','s002') = yes;
    //zs('z008','s002') = yes;
    //zs('z009','s004') = yes;
    
	zs('z000','s001') = yes;
	zs('z001','s001') = yes;
	zs('z002','s001') = yes;
	zs('z003','s001') = yes;
	zs('z004','s001') = yes;
	zs('z005','s001') = yes;
	zs('z006','s001') = yes;
	zs('z007','s001') = yes;
	zs('z008','s001') = yes;
	zs('z009','s001') = yes;
	zs('z010','s001') = yes;
	zs('z011','s001') = yes;
	zs('z012','s001') = yes;
	zs('z013','s001') = yes;
	zs('z014','s001') = yes;
	zs('z015','s001') = yes;
	zs('z016','s002') = yes;
	zs('z017','s002') = yes;
	zs('z018','s002') = yes;
	zs('z019','s002') = yes;
	zs('z020','s002') = yes;
	zs('z021','s002') = yes;
	zs('z022','s002') = yes;
	zs('z023','s002') = yes;
	zs('z024','s002') = yes;
	zs('z025','s002') = yes;
	zs('z026','s002') = yes;
	zs('z027','s002') = yes;
	zs('z028','s002') = yes;
	zs('z029','s002') = yes;
	zs('z030','s002') = yes;
	zs('z031','s002') = yes;
	zs('z032','s002') = yes;
	zs('z033','s002') = yes;
	zs('z034','s002') = yes;
	zs('z035','s002') = yes;
	zs('z036','s002') = yes;
	zs('z037','s000') = yes;
	zs('z038','s000') = yes;
	zs('z039','s000') = yes;
	zs('z040','s000') = yes;
	zs('z041','s000') = yes;
	zs('z042','s000') = yes;
	zs('z043','s000') = yes;
	zs('z044','s000') = yes;
	zs('z045','s000') = yes;
	zs('z046','s000') = yes;
	zs('z047','s000') = yes;
	zs('z048','s000') = yes;
	zs('z049','s000') = yes;
	zs('z050','s000') = yes;
	zs('z051','s000') = yes;
	zs('z052','s000') = yes;

    

    // Make H2 nodes-state nodes
    //loop(gn('h2',node),
    //    gn_state('h2', node) = yes;
    //    p_gn('h2', node, 'energyStoredPerUnitOfState') = 1;
    //    p_gn('h2', node, 'nodeBalance') = 1;
    //);
    

    // Cyclic condition for short term storage (atm all nodes with states) (for single sample)
    loop(s$(ord(s) <= mSettings('invest', 'samples')),
        gnss_bound(gn_state(grid, node),s , s ) =yes;
        sGroup(s,'fuelGroup') = yes; // this connects our (time) sample to the fuelGroup which is handling the CO2 emissionCap parameter

    );

    // Cyclic condition for long term storage (H2, Hydro) (for complete modeling horizon)
    //loop(gn(grid,node)${sameas(grid, 'hydro') or sameas(grid, 'pumped') or sameas(grid, 'H2')},
    //gnss_bound(grid,node,'s000','s001') = yes;
    //gnss_bound(grid,node,'s001','s002') = yes;
    //gnss_bound(grid,node,'s002','s003') = yes;
    //gnss_bound(grid,node,'s003','s004') = yes;
    //gnss_bound(grid,node,'s004','s005') = yes;
    //gnss_bound(grid,node,'s005','s006') = yes;
    //gnss_bound(grid,node,'s006','s000') = yes;

*    gnss_bound(grid,node,'s006','s007') = yes;
*    gnss_bound(grid,node,'s007','s000') = yes;
//);

    node_superpos(node ) =no;
    //Superposition state for all nodes with states
    loop(gn_state(grid, node),      // unclear if superpositioning in general is needed or how it impacts performance and results
        node_superpos(node ) =yes;
    );

    
    
    
    loop(gnu_output(grid, node, unit),
        if(p_gnu_io(grid, node, unit, 'input', 'conversionCoeff')  = 0.0001,
           p_gnu_io(grid, node, unit, 'input', 'conversionCoeff') = Eps;
          ) ;
        if(p_gnu_io(grid, node, unit, 'output', 'capacity')  = 0.0001,
           p_gnu_io(grid, node, unit, 'output', 'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'capacity')  = 0.0001,
           p_gnu(grid, node, unit,'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'conversionCoeff')  = 0.0001,
           p_gnu(grid, node, unit,'conversionCoeff') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'InvCosts')  = 0.0001,
           p_gnu(grid, node, unit,'InvCosts') = Eps;
          ) ;

    );
    loop(gnu_input(grid, node, unit),
        if(p_gnu_io(grid, node, unit, 'input', 'conversionCoeff')  = 0.0001,
           p_gnu_io(grid, node, unit, 'input', 'conversionCoeff') = Eps;
          ) ;
        if(p_gnu_io(grid, node, unit, 'output', 'capacity')  = 0.0001,
           p_gnu_io(grid, node, unit, 'output', 'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'capacity')  = 0.0001,
           p_gnu(grid, node, unit,'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'conversionCoeff')  = 0.0001,
           p_gnu(grid, node, unit,'conversionCoeff') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'InvCosts')  = 0.0001,
           p_gnu(grid, node, unit,'InvCosts') = Eps;
          ) ;
          
    );
$ontext
loop() for ## quick fix nuclear no invest

bb_dim_1_relationship_dtype_str.loc[((bb_dim_1_relationship_dtype_str['Object names'].str.contains('Nuclear')) & \
                                     (bb_dim_1_relationship_dtype_str['Parameter names'] == 'maxUnitCount')), 'Parameter values'] = eps
bb_dim_2_p_groupPolicyEmission = pd.DataFrame({
    'Relationship class names':'group__emission',
    'Object class names 1':'group',
    'Object class names 2':'emission',
    'Object names 1':'fuelGroup',
    'Object names 2':df_CO2_melt['Regional_emissions_budget'],
    'Parameter names':'emissionCap',
    'Alternative names':df_CO2_melt['Alternative names'],
    'Parameter values':df_CO2_melt['Parameter_value']})

bb_dim_2_p_groupPolicyEmission.loc[bb_dim_2_p_groupPolicyEmission['Parameter values'] ==0,'Parameter values'] = eps
$offtext

* =============================================================================
* --- Model Forecast Structure ------------------------------------------------
* =============================================================================

    // Define the number of forecasts used by the model
    mSettings('invest', 'forecasts') = 0;

    // Define forecast properties and features
    mSettings('invest', 't_forecastStart') = 0;                // At which time step the first forecast is available ( 1 = t000001 )
    mSettings('invest', 't_forecastLengthUnchanging') = 0;     // Length of forecasts in time steps - this does not decrease when the solve moves forward (requires forecast data that is longer than the horizon at first)
    mSettings('invest', 't_forecastLengthDecreasesFrom') = 0;  // Length of forecasts in time steps - this decreases when the solve moves forward until the new forecast data is read (then extends back to full 168)
    mSettings('invest', 't_forecastJump') = 0;                 // How many time steps before new forecast is available

    // Define Realized and Central forecasts
    mf_realization('invest', f) = no;
    mf_realization('invest', 'f00') = yes;
    mf_central('invest', f) = no;
    mf_central('invest', 'f00') = yes;

    // Define forecast probabilities (weights)
    p_mfProbability('invest', f) = 0;
    p_mfProbability(mf_realization('invest', f)) = 1;

    // Define active model features
    active('invest', 'storageValue') = yes;

* =============================================================================
* --- Model Features ----------------------------------------------------------
* =============================================================================

* --- Define Reserve Properties -----------------------------------------------

    // Lenght of reserve horizon
    mSettingsReservesInUse('invest', resType, up_down) = no;
    // Lenght of reserve horizon
    //mSettingsReservesInUse('invest', 'primary', 'up') = no;
    //mSettingsReservesInUse('invest', 'primary', 'down') = no;
    //mSettingsReservesInUse('invest', 'secondary', 'up') = no;
    //mSettingsReservesInUse('invest', 'secondary', 'down') = no;
    //mSettingsReservesInUse('invest', 'tertiary', 'up') = no;
    //mSettingsReservesInUse('invest', 'tertiary', 'down') = no;

* --- Define Unit Approximations ----------------------------------------------

    // Define the last time step for each unit aggregation and efficiency level (3a_periodicInit.gms ensures that there is a effLevel until t_horizon)
    mSettingsEff('invest', 'level1') = inf;

    // Define the horizon when start-up and shutdown trajectories are considered
    mSettings('invest', 't_trajectoryHorizon') = 0;

* --- Define output settings for results --------------------------------------

    // Define the 168 of the initialization period. Results outputting starts after the period. Uses ord(t) > t_start + t_initializationPeriod in the code.
    mSettings('invest', 't_initializationPeriod') = 0;  // r_state_gnft and r_online_uft are stored also for the last step in the initialization period, i.e. ord(t) = t_start + t_initializationPeriod

* --- Define the use of additional constraints for units with incremental heat rates

    // How to use q_conversionIncHR_help1 and q_conversionIncHR_help2
    mSettings('invest', 'incHRAdditionalConstraints') = 0;
    // 0 = use the constraints but only for units with non-convex fuel use
    // 1 = use the constraints for all units represented using incremental heat rates

* --- Control the solver ------------------------------------------------------

    // Control the use of advanced basis
    mSettings('invest', 'loadPoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve
    mSettings('invest', 'savePoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve

); // END if(mType)


