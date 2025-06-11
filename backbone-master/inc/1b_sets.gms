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

$onempty
Sets
* --- Geography ---------------------------------------------------------------
    // domains
    // note: (*) to guarantee that the domain checks for p_userconstraint in 1e work
    grid(*) "Forms of energy endogenously presented in the model"
    node(*) "Nodes maintain the energy balance or track exogenous commodities"
;
* Declaring aliases of node to allow from_node and to_node in set definitions
alias(node, from_node, to_node, node_, node__, node_input, node_output, node_fail, node_left, node_right);

Sets
    // temporary sets
    grid_tmp(grid) "temporary grid set for summing and filtering"
    node_tmp(node) "temporary node set for summing and filtering"
    node_tmp_(node) "another temporary node set"

    // classifications
    node_spill(node) "Nodes that can spill; used to remove v_spill variables where not relevant"
    node_superpos(node) "Nodes whose state is monitored in the z dimension using superpositioning of state" / /
    node_startupEnergyCost(node) "Nodes that have units with startup energy cost"
    node_invEnergyCost(node) "Nodes that have units with investment energy cost"

    // combinations
    gn(grid, node) "Grids and their nodes"
    gn_tmp(grid, node) "Temporary gn set for summing and filtering"
    gn_tmp_(grid, node) "Another temporary gn set for summing and filtering"
    gn_deactivated(grid, node) "Set of deactivated gn"
    gn_balance(grid, node) "Nodes that have balance equation enabled" / /
    gn_influx(grid, node) "nodes with influx"
    gn_influxTs(grid, node) "nodes with influx time series"
    gn_state(grid, node) "Nodes with a state variable"
    gn_stateSlack(grid, node) "Nodes with a state slack variable"
    gn_stateUpwardSlack(grid, node) "Nodes with a upward state slack variable"
    gn_stateDownwardSlack(grid, node) "Nodes with a downward state slack variable"
    gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes) "nodes with time series for boundaryTypes (ts_node)"
    gn_forecasts(*, node, timeseries) "A flag which (grid/flow/restype, node, timeseries) have forecast data. If not set, values are read from f_realization. Default value = yes."

* --- Emissions ---------------------------------------------------------------
    // domains
    emission "Emissions"
    // classifications and combinations
    emission_tmp(emission) "temporary set for summing emissions"
    emission_tmp_(emission) "another temporary set for summing emissions"

* --- Flows -------------------------------------------------------------------
    // domains
    // note: (*) to guarantee that the domain checks for p_userconstraint in 1e work
    flow(*) "Flow based energy resources (time series)"
    // classifications and combinations
    flowNode(flow, node) "Combinations of flows and nodes"
    flowNode_tmp(flow, node) "temporary set for summing (flow, node)"

* --- Energy generation and consumption ---------------------------------------
    // domains
    // note: (*) to guarantee that the domain checks for p_userconstraint in 1e work
    unit(*) "Set of generators, storages and loads"
    unittype "Unit technology types"
    // temporary sets for summing, filtering, etc
    unit_tmp(unit) "temporary set for summing units"
    unit_tmp_(unit) "another temporary set for summing units"
    // classifications
    unit_deactivated(unit) "Set of deactivated units"
    unit_forecasts(unit, timeseries) "A flag which (unit, timeseries) have forecast data. If not set, values are read from f_realization. Default value = yes."
    unit_fail(unit) "Units that might fail" / /
    unit_aggregator(unit) "Aggregator units aggragating several units"
    unit_aggregated(unit) "Units that are aggregated"
    unit_startCost(unit) "units that have start costs defined"
    unit_invest(unit) "Units with investments allowed"
    unit_investLP(unit) "Units with continuous investments allowed"
    unit_investMIP(unit) "Units with integer investments allowed"
    unit_resCapable(unit) "Units that are capable to provide any kind of reserve"
    unit_offlineRes(unit) "Units where offline reserve provision possible"
    unit_source(unit) "Units that are sources (no inputs)"
    unit_sink(unit) "Units that are sinks (no outputs)"
    // conversion type related
    unit_directOff(unit) "Units that are directOff in all effLevels. Includes flow units."
    unit_flow(unit) "Unit that depend directly on variable energy flows (RoR, solar PV, etc.)"
    unit_online(unit) "Units that have an online variable in the first active effLevel"
    unit_online_LP(unit) "Units that have an LP online variable in the first active effLevel"
    unit_online_MIP(unit) "Units that have an MIP online variable in the first active effLevel"
    unit_slope(unit) "Units with piecewise linear efficiency constraints"
    unit_section(unit) "Units with no load fuel use"
    unit_incHRAdditionalConstraints(unit) "Units that use the two additional incremental heat rate constraints"
    unit_minLoad(unit) "Units that have unit commitment restrictions (e.g. minimum power level)"


    // combinations
    unitUnittype(unit, unittype) "Link generation technologies to types for result tables" / /
    unitStarttype(unit, starttype) "Units with special startup properties"
    flowUnit(flow, unit) "Units linked to a certain energy flow time series" / /
    unitAggregator_unit(unit, unit) "Aggregate unit linked to aggregated units"
    unitUnitEffLevel(unit, unit, EffLevel) "Aggregator unit linked to aggreted units with a definition when to start the aggregation" / /
    unit_timeseries(unit, param_unit) "Units with time series enabled"
    unitConstraint(unit, constraint) "combinations of units and their eq/gt/lt constraints"
    unit_tsConstraint(unit, constraint) "combinations of units and their eq/gt/lt constraints if time series constraint"
    unit_tsConstraintNode(unit, constraint, node) "combinations of units, their eq/gt/lt constraints, and nodes"

* --- Groups ------------------------------------------------------------------
    // domains
    // note: (*) to guarantee that the domain checks for p_userconstraint in 1e work
    group(*) "A group of units, transfer links, nodes, etc."

    // classifications
    group_tmp(group) "temporary set for summing groups"
    group_tmp_(group) "another temporary set for summing groups"
    group_uc(group) "names that are used to define an user constraint"
    group_ucSftFiltered(group) "User constraints that are active only for certain sft. By default UCs apply to all modelled sft." / /

    // combinations
    uGroup(unit, group) "Units in particular groups" / /
    gnuGroup(grid, node, unit, group) "Combination of grids, nodes and units in particular groups" / /
    gn2nGroup(grid, node, node, group) "Transfer links in particular groups" / /
    gnGroup(grid, node, group) "Combination of grids and nodes in particular groups" / /
    emissionGroup(emission, group) "combinations of emissions and groups"
    group_forecasts(*, group, timeseries) "A flag which (emission, group, timeseries) have forecast data. If not set, values are read from f_realization. Default value = no"
    groupPolicyTimeseries(group, param_policy) "Combination of groups and policies that have time series" / /
    groupUc1234(group, *, *, *, *) "helper set for looping userconstraints" / /
    groupUcParamUserconstraint(group, param_userconstraint) "helper set for looping userconstraints" / /


* --- Sets bounding geography and units ---------------------------------------

    // node node connections
    gnn_tmp(grid, from_node, to_node) "temporary gnn set for summing and filtering"
    gnn_tmp_(grid, from_node, to_node) "another temporary gnn set for summing and filtering"
    gnn_deactivated(grid, node, node) "Set of deactivated gnn"
    gnn_state(grid, node, node) "Nodes with state variables interconnected via diffusion"
    gnn_boundState(grid, node, node) "Nodes with state variables bound by other nodes"

    // directional node-node connections (allowing only one direction of connection)
    gn2n(grid, node, node) "All (directional) transfer links between nodes in specific energy grids"
    gn2n_directional(grid, node, node) "Transfer links with positive rightward transfer and negative leftward transfer"
    gn2n_directional_investLP(grid, node, node) "Transfer links with with continuous investments allowed"
    gn2n_directional_investMIP(grid, node, node) "Transfer links with with integer investments allowed"
    gn2n_timeseries(grid, node, node, param_gnn) "Transfer links with time series enabled for certain parameters"
    gn2n_directional_ramp(grid, node, node) "Transfer links with ramp equations activated"
    gn2n_directional_vomCost(grid, node, node) "Transfer links with vom costs"

    // node unit connections
    nu(node, unit) "Units attached to particular nodes"
    nu_startup(node, unit) "Units consuming energy from particular nodes in start-up"

    // gnu classifications
    gnu(grid, node, unit) "Units in specific nodes of particular energy grids"
    gnu_tmp(grid, node, unit) "temporary table of (grid, node, unit) for easier if chekcs and looping"
    gnu_input(grid, node, unit) "Forms of energy the unit uses as endogenous inputs"
    gnu_output(grid, node, unit) "Forms of energy the unit uses as endogenous outputs"
    gnu_vomCost(grid, node, unit) "gnu with vomCosts"
    gnu_rampUp(grid, node, unit) "(grid, node, units) with rampUp constraints or costs"
    gnu_rampDown(grid, node, unit) "(grid, node, units) with rampDown constraints or costs"
    gnu_rampUpCost(grid, node, unit) "(grid, node, units) with rampUp costs"
    gnu_rampDownCost(grid, node, unit) "(grid, node, units) with rampDown costs"
    gnu_delay(grid, node, unit) "gnu with delays"
    gnu_timeseries(grid, node, unit, param_gnu) "(grid, node, units) with time series data in ts_gnu"
    gnu_deactivated(grid, node, unit) "set of deactivated gnu"
    gnu_cb(grid, node, unit) "set of gnu with p_gnu_io('cb') parameter"
    gnu_cv(grid, node, unit) "set of gnu with p_gnu_io('cv') parameter"
    gnu_eqConstrained(constraint, grid, node, unit) "eq_constraint applying for gnu"
    gnu_gtConstrained(constraint, grid, node, unit) "gt_constraint applying for gnu"
    gnu_ltConstrained(constraint, grid, node, unit) "lt_constraint applying for gnu"

    // combinations
    gn2gnu(grid, node, grid, node, unit) "Conversions between energy grids by specific units"

* --- Reserve types -----------------------------------------------------------
    // domains
    // note: (*) to guarantee that the domain checks for p_userconstraint in 1e work
    restype(*) "Reserve types"

    // classifications and combinations
    restypeDirection(restype, up_down) "Different combinations of reserve types and directions" / /
    restypeDirectionGridNode(restype, up_down, grid, node) "Nodes with up/down reserve requirements"
    resTypeDirectionGridNodeNode(restype, up_down, grid, node, node) "Node node connections that can transfer up/down reserves"
    restypeDirectionGroup(restype, up_down, group) "Groups with up/down reserve requirements"
    restypeDirectionGroup_tmp(restype, up_down, group) "Temporary set for groups with up/down reserve requirements"
    restypeDirectionGroup_tmp_(restype, up_down, group) "Temporary set for groups with up/down reserve requirements"
    restypeDirectionGridNodeGroup(restype, up_down, grid, node, group)
    gnu_resCapable(restype, up_down, grid, node, unit) "Units capable and available to provide particular up/down reserves"
    gnu_offlineResCapable(restype, grid, node, unit) "Units capable and available to provide offline reserves"
    restypeReleasedForRealization(restype) "Reserve types that are released for the realized time intervals" / /
    offlineRes (restype) "Reserve types where offline reserve provision possible"
    restype_inertia(restype) "Reserve types where the requirement can also be fulfilled with the inertia of synchronous machines" / /
    groupRestype(group, restype) "Groups with reserve requirements"
    mSettingsReservesInUse(mType, restype, up_down) "Reserves that are used in each model type"

* --- Background Infos for the Steam Model ------------------------------------
    s_countries "(KT) countries of subset_countries.csv"
    s_regions "(KT) regions of subset_countries.csv"
    s_terminals "(KT) terminals of transport_visualisation.xlsx"
    steam_subset_countries(s_countries, s_regions) "(KT) subset_countries.csv resulting in the regional configuration"
    s_scenario "(KT) scenario of scenario.csv"
    s_alternative "(KT) alternatives of scenario.csv"
    steam_scenarioAlternative(s_scenario, s_alternative) "(KT) scenarios.csv displaying the chosen scenario configuration"
    s_x_longitude "(KT) Geopandas Geometry exported as Point from transport_visualisation.xlsx"
    s_y_latitude "(KT) Geopandas Geometry exported as Point from transport_visualisation.xlsx"
    s_regional_WACC_avg "(KT) technological and regional average of the WACC"
    steam_coordinates_regions(s_regions, s_x_longitude, s_y_latitude) "(KT) coordinates of regions from transport_visualisation.xlsx"
    steam_WACC(s_regions, s_regional_WACC_avg) "(KT) assigning the average WACC to each region"
    steam_coordinates_terminals(s_terminals, s_x_longitude, s_y_latitude, s_regions) "(KT) coordinates of terminals assigned to their respective regions from transport_visualisation.xlsx"
    s_shipping_index "(KT) Index assigned to shipping routes points from start to finish"
    s_shipping_route "(KT) Shipping routes with origin and destination seperated by '___'"
    steam_coordinates_shipping(s_shipping_route, s_terminals, s_terminals, s_x_longitude, s_y_latitude, s_shipping_index) "(KT) Split linestrings of shipping connecting two terminals from transport_visualisation.xlsx"
    s_config_parameter "(KT) part of Steam model config"
    s_config_object "(KT) part of Steam model config"
    s_config_value "(KT) part of Steam model config"
    s_config_alternative "(KT) part of Steam model config"
    s_config_info "(KT) part of Steam model config"
    steam_model_config(s_config_parameter, s_config_object, s_config_value, s_config_alternative, s_config_info) "(KT) Steam model config sheet of MainInput.xlsx"
;
* --- Sets to define time, forecasts and samples ------------------------------

// Giving priority to %input_dir%/%input_file_debugGdx% to match possible input debug
// as closely as possible
$ifthen.timeSamples exist '%input_dir%/%input_file_debugGdx%'

    // initializing domains normally given in timeAndSamples.inc
    Sets
        s "Model samples" / s000 /
        f "Model forecasts" / f00 /
        t "Model time steps" / t000000 /
        z "periods for superpositioning of states (candidate periods)" /z000/
    ;

    // reading the remaining set members from debug gdx
    $$gdxin  '%input_dir%/%input_file_debugGdx%'
    $$loaddcm s
    $$loaddcm f
    $$loaddcm t
    $$loaddcm z
    $$gdxin

// Normally reading data from %input_dir%/timeAndSamples.inc
$elseif.timeSamples exist '%input_dir%/timeAndSamples.inc'
    Sets
        $$include '%input_dir%/timeAndSamples.inc'
    ;
// else abort
$else.timeSamples
    $$abort 'Did not find %input_dir%/timeAndSamples.inc. Check path and spelling!'
$endif.timeSamples

// declaring aliases of loaded s, f, and t domains
alias(s, s_, s__);
alias(f, f_, f__);
alias(t, t_, t__, t_solve);


Sets
* --- sets of m, s, or f for different equations, calculations, and filters
    m(mType) "model(s) in use"
    s_active(s) "Samples with non-zero probability in the current model solve"
    s_realized(s) "All s among realized sft (redundant if always equivalent to s)"
    f_active(f) "forecasts in the model to be solved next"
    f_realization(f) "realizing forecast"
    f_central(f) "central forecast"
    ff(f) "Temporary subset for forecasts used for calculations"
    ff_(f) "Temporary subset for forecasts used for calculations"

* --- sets of t for different equations, calculations, and filters
    t_start(t) "start t"
    t_startp(t) "Temporary subset for time steps used in results printing"
    t_full(t) "Full set of time steps in the current model"
    t_datalength(t) "Full set of time steps withing the datalength"
    t_current(t) "Set of time steps within the current solve horizon"
    t_active(t) "Set of active t:s within the current solve horizon, including necessary history"
    t_invest(t) "Time steps when investments can be made" / /
    t_realized(t) "Realized time steps in solve"
    t_realizedNoReset(t) "Realized time steps in all solves, no reset between solves"
    t_nonanticipativity(t) "first t's in the forecasts in the current solve that are bound by nonanticipativity"
    tt(t) "Temporary subset for time steps used for calculations"
    tt_(t) "Another temporary subset for time steps used for calculations"
    tt__(t) "Another temporary subset for time steps used for calculations"
    t_t(t, t_) "Temporary subset for time steps used for calculations"
    tt_block(counter_large, t) "Temporary time step subset for storing the time interval blocks"
    tt_interval(t) "Temporary time steps when forming the ft structure, current sample"
    tt_forecast(t) "Temporary subset for time steps used for forecast updating during solve loop"
    tt_aggregate(t, t) "Time steps included in each active time step for time series aggregation"
    tt_aggregate_historical(t, t_) "Time step aggreagation of realized historical time steps. Needed when modelling delays." / /
    tt_agg_circular(t, t, t) "Alternative aggregation ordering with embedded circulars"

* --- Combinations
    t_active_effLevel(t, effLevel) "Set of active t:s in defined effLevels"

* --- sets of msft for different equations, calculations, and filters
    mf(mType, f) "Forecasts present in the models"
    mf_realization(mType, f) "Realization of the forecasts"
    mf_central(mType, f) "Forecast that continues as sample(s) after the forecast horizon ends"
    ms(mType, s) "Samples present in the models"
    ms_initial(mType, s) "Sample that presents the realized/forecasted period"
    ms_central(mType, s) "Sample that continues the central forecast after the forecast horizon ends"
    ft(f, t) "Combination of forecasts and t:s in the current solve"
    ft_realized(f, t) "Realized ft"
    ft_realizedNoReset(f, t) "Full set of realized ft, no reset between solves"
    ft_reservesFixed(group, restype, f, t) "Forecast-time steps with reserves fixed due to commitments on a previous solve."
    ft_start(f, t) "Start point of the current model solve"
    ft_lastSteps(f, t) "Last interval of the current model solve"
    sf(s, f) "Combination of samples and forecasts in the models"
    st(s, t) "Combination of models samples and t's"
    st_start(s, t) "Start point of samples"
    st_end(s, t) "Last point of samples"
    sft(s, f, t) "Combination of samples, forecasts and t's in the current model solve"
    sft_tmp(s, f, t) "Temporary combination of samples, forecasts and t's for summing and filtering"
    sft_withStorageStarts(s, f, t) "Combination of samples, forecasts and t's in the current model solve including the t's just before samples"
    sft_realized(s, f, t) "Realized sft"
    sft_realizedNoReset(s, f, t) "Full set of realized sft, no reset between solves"
    sft_resdgn(restype, up_down, grid, node, s, f, t) "Temporary tuplet for reserves by restypeDirectionGridNode"
    sft_groupUc(group, s, f, t) "filtered sft set for user constraints that have active sft filtering"

* --- other sets for the model structure
    modelSolves(mType, t) "when different models are to be solved"
    gnss_bound(grid, node, s, s) "Bound the samples so that the node state at the last interval of the first sample equals the state at the first interval of the second sample" / /
    uss_bound(unit, s, s) "Bound the samples so that the unit online state at the last interval of the first sample equals the state at the first interval of the second sample" / /
    sGroup(s, group) "Samples in particular groups" / /

    mz(mType, z) "z periods in the models"
    zs(z, s) "relationship between the z-periods and samples"

    mTimeseries_loop_read(mType, timeseries) "Those time series that will be read between solves"

* --- counter sets used in several loops, time intervals, and trajectories
    counter(counter_large) "Counter set limited to needed amount of counters"
    counter_intervals(counter_large) "Counter set for intervals"
    cc(counter_large) "Temporary subset of counter used for calculations"
    unitCounter(unit, counter_large) "Counter used for restricting excessive looping over the counter set when defining unit startup/shutdown/online time restrictions"
    runUpCounter(unit, counter_large) "Counter used for unit run-up intervals"
    shutdownCounter(unit, counter_large) "Counter used for unit shutdown intervals"

* --- Sets used for the changing unit aggregation and efficiency approximations as well as unit lifetimes
    us(unit, s) "set of active units in sample s"
    usft(unit, s, f, t) "set of active units and active sft"
    usft_online(unit, s, f, t) "Units with any online and startup variables on intervals in active sft"
    usft_onlineLP(unit, s, f, t) "Units with LP online and startup variables on intervals in active sft"
    usft_onlineMIP(unit, s, f, t) "Units with MIP online and startup variables on intervals in active sft"
    usft_onlineLP_withPrevious(unit, s, f, t) "Units with LP online and startup variables on intervals, including t0, in active sft"
    usft_onlineMIP_withPrevious(unit, s, f, t) "Units with MIP online and startup variables on intervals, including t0, in active sft"
    usft_startupTrajectory(unit, s, f, t) "Units with start-up trajectories on intervals in active sft"
    usft_shutdownTrajectory(unit, s, f, t) "Units with shutdown trajectories on intervals in active sft"
    usft_aggregator_first(unit, s, f, t) "The first intervals when aggregator units are active in active sft"
    gnusft(grid, node, unit, s, f, t) "set of active gnu and active sft"
    gnusft_ramp(grid, node, unit, s, f, t) "(grid, node, units) with ramp constraints or costs in active sft"
    gnusft_rampCost(slack, grid, node, unit, s, f, t) "Units with ramp costs in active sft"
    gnusft_resCapable(restype, up_down, grid, node, unit, s, f, t) "Units capable and available to provide particular up/down reserves in active sft"

    uft_tmp(unit, f, t) "temporary uft set"
    gnuft_tmp(grid, node, unit, f, t) "temporary gnuft set"

    eff_usft(effSelector, unit, s, f, t) "Selecting conversion efficiency equations in active sft"
    effGroup(effSelector) "Group name for efficiency selector set, e.g. DirectOff and Lambda02"
    effGroupSelector(effSelector, effSelector) "Efficiency selectors included in efficiency groups, e.g. Lambda02 contains Lambda01 and Lambda02."
    effLevelGroupUnit(effLevel, effSelector, unit) "What efficiency selectors are in use for each unit at each efficiency representation level" / /
    effGroupSelectorUnit(effSelector, unit, effSelector) "Group name for efficiency selector set, e.g. Lambda02 contains Lambda01 and Lambda02"

    utAvailabilityLimits(unit, t, availabilityLimits) "Time step when the unit becomes available/unavailable, e.g. because of technical lifetime" / /

* --- Sets used for the changing transfer link aggregation and efficiency approximations as well as lifetimes
    gn2nsft_directional(grid, node, node, s, f, t) "Active transfer links in the solve"
    gn2nsft_directional_ramp(grid, node, node, s, f, t) "Active transfer links in the solve with ramp equations activated"

* --- Sets used to activate and modify forecast timeseries data

    ts_gnu_activeForecasts(grid, node, unit, param_gnu, f) "A flag which (grid, node, unit, param_gnu, f) is activated. If not set, values for forecast timeseries are read from f_realization. Default value = no." / /


* --- Mapping sets for different time indexes ---------------------------------

    map_delay_gnutt(grid, node, unit, t, t_) "Mapping of v_gen(t) to v_gen_delay(t_) in case of unit outputs with active delays"

* --- Sets used to reduce the amount of dummy variables -----------------------
    vqGenInc_gn(grid, node) "Nodes with state vq_gen('inc') variable" / /
    vqGenDec_gn(grid, node) "Nodes with state vq_gen('dec') variable" / /
    dropVqGenInc_gn(grid, node) "Nodes without state vq_gen('inc') variable" / /
    dropVqGenDec_gn(grid, node) "Nodes without state vq_gen('dec') variable" / /
    dropVqGenInc_gnt(grid, node, t) "Time step dependent set for nodes without state vq_gen('inc') variable" / /
    dropVqGenDec_gnt(grid, node, t) "Time step dependent set for nodes without state vq_gen('dec') variable" / /
    dropVqGenRamp_gnut(grid, node, unit, t) "Time step dependent set for gnu without vq_genRampUp and vq_genRampDown variables" / /
    dropVqResDemand(restype, up_down, group, t) "Time step dependent set for restypeDirectionGroups without vq_resDemand variable" / /
    dropVqResMissing(restype, up_down, group, t) "Time step dependent set for restypeDirectionGroups without vq_resMissing variable" / /
    dropVqUnitConstraint(unit, constraint, t) "Time step dependent set for unit constraints without vq_unitConstraint variable" / /
    dropVqUserconstraint(group, t) "Time step dependent set for userconstraints without vq_userconstraint variable" / /

;
$offempty

* --- Set for metadata --------------------------------------------------------

* Get current username
$ifthen %system.filesys% == 'MSNT'
$set username %sysenv.USERNAME%
$else
$set username %sysenv.USER%
$endif

* Create metadata
set metadata(*) /
   'User' '%username%'
   'Date' '%system.date%'
   'Time' '%system.time%'
   'GAMS version' '%system.gamsrelease%'
   'GAMS system' '%system.gstring%'
$ifthen exist 'version_git'
    $$include 'version_git';
$else
    $$include 'version';
$endif
/;
if(execError > 0, metadata('FAILED') = yes);



* Set initial values to avoid errors when checking if parameter contents have been loaded from input data
Option clear = modelSolves;
Option clear = ms;
Option clear = mf;
Option clear = mz;
Option clear = zs;
Option clear = mSettingsReservesInUse;


alias(m, mSolve);
alias(grid, grid_, grid__, grid_output);
alias(unit, unit_);

alias(flow, flow_);
alias(effSelector, effSelector_);
alias(effDirect, effDirect_);
alias(effDirectOff, effDirectOff_);
alias(effDirectOn, effDirectOn_);
alias(effLambda, effLambda_);
alias(lambda, lambda_, lambda__);
alias(op, op_, op__);
alias(hrop, hrop_, hrop__);
alias(eff, eff_, eff__);
alias(hr, hr_, hr__);
alias(effLevel, effLevel_);
alias(restype, restype_);
alias(group, group_);
alias(metadata, r_info_metadata);
alias(*, uc1, uc2, uc3, uc4)


// Only include these if '--rampSched=yes' given as a command line argument
$iftheni.rampSched '%rampSched%' == yes

$ifthen.exists exist 'inc/rampSched/sets_rampSched.gms'
  $$include 'inc/rampSched/sets_rampSched.gms'
$endif.exists

$endif.rampSched



