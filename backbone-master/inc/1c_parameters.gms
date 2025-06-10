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

Table of Contents:
 - Counters and Temporary Scalars
 - Node, Unit, Reserve, and Group parameters
 - Sample, Forecast, and Time Step Parameters and Scalars
 - Model feature parameters
 - Time series
 - Penalty Definitions

$offtext


* =============================================================================
* --- Counters and Temporary Scalars ------------------------------------------
* =============================================================================

Scalars
* initiating scalars with / x / where x is value'

    // internal counters
    count "General counter scalar"
    tCounter "counter for t" /0/
    opCount "Counting the number of valid operating points in the unit data"
    solveCount /0/
    t_solveFirst "counter (ord) for the first t in the solve"
    t_solveLast "counter for the last t in the solve"
    t_solveLastActive "counter for the last active t in the solve"
    dt_historicalSteps "Necessary amount of historical timesteps for each solve"
    continueLoop "Helper to stop the looping early"

    // temporary scalars
    tmp "General temporary parameter"
    tmp_ "General temporary parameter"
    tmp__ "General temporary parameter"
    tmp4 "General temporary parameter"
    tmp_dist "Temporary parameter for calculating the distance between operating points"
    tmp_op "Temporary parameter for operating point"
    heat_rate "Heat rate temporary parameter"

    // scaling scalars
    p_scaling_obj "Objective function scaling factor"
    p_scaling "General scaling factor"
;


* =============================================================================
* --- Node, Unit, Reserve, and Group parameters -------------------------------
* =============================================================================

* initiating optional input data tables with empty / /
$onempty

Parameters

* --- Unit parameters ---------------------------------------------------------
    // unit data
    p_unit(unit, param_unit) "Unit data where energy type does not matter"
    p_effUnit(effSelector, unit, effSelector, param_eff) "Data for piece-wise linear efficiency blocks"
    p_effGroupUnit(effSelector, unit, param_eff) "Unit data specific to a efficiency group (e.g. left border of the unit)"

    // gnu data
    p_gnu(grid, node, unit, param_gnu) "Unit data where energy type matters. Automatically calculated from input data p_gnu_io."
    p_gnu_io(grid, node, unit, input_output, param_gnu) "Unit data where energy type matters"
    p_gnuBoundaryProperties(grid, node, unit, slack, param_gnuBoundaryProperties) "Properties for unit boundaries where energy type matters" / /
    p_gnuEmission(grid, node, unit, emission, param_gnuEmission) "unit data of emission factors for investments, maintenance, and energy" / /

    // unit constraints
    p_unitConstraint(unit, constraint) "Constant for constraints (eq1-9, gt1-9, lt1-9) between inputs and/or outputs. Each unit have their own (eq1-9, gt1-9, lt1-9)." / /
    p_unitConstraintNew(unit, constraint, param_constraint) "Parameters for constraints (eq1-9, gt1-9, lt1-9) between inputs and/or outputs. Each unit have their own (eq1-9, gt1-9, lt1-9)." / /
    p_unitConstraintNode(unit, constraint, node) "Coefficients for constraints (eq1-9, gt1-9, lt1-9) between inputs and/or outputs" / /

    // startup and shutdown parameters
    p_uStartup(unit, starttype, cost_consumption) "Startup cost and fuel consumption"
    p_uStartupfuel(unit, node, param_unitStartupfuel) "Parameters for startup fuels" / /
    p_unStartup(unit, node, starttype) "Consumption during the start-up (MWh/start-up)"
    p_uShutdown(unit, cost_consumption) "Shutdown cost per unit"
    p_uNonoperational(unit, starttype, min_max) "Non-operational time after being shut down before start up"

    // startup and shutdown trajectories
    // unused: remove for 4.x
    p_u_maxOutputInLastRunUpInterval(unit) "Maximum output in the last interval for the run-up to min. load (p.u.)"
    // unused: remove for 4.x
    p_u_maxRampSpeedInLastRunUpInterval(unit) "Maximum ramp speed in the last interval for the run-up to min. load (p.u.)"
    p_u_runUpTimeIntervals(unit)       "Time steps required for the run-up phase"
    p_u_runUpTimeIntervalsCeil(unit)   "Ceiling of time steps required for the run-up phase"
    p_uCounter_runUpMin(unit, counter_large) "Minimum output for the time steps where the unit is being started up to the minimum load (minimum output in the last interval). Unit: percent of capacity. values: 0-1. Default = empty."
    p_uCounter_runUpMax(unit, counter_large) "Maximum output for the time steps where the unit is being started up to the minimum load (minimum output in the last interval).  Unit: percent of capacity. values: 0-1. Default = empty."
    // unused: remove for 4.x
    p_u_maxOutputInFirstShutdownInterval(unit) "Maximum output in the first interval for the shutdown from min. load (p.u.)"
    p_u_shutdownTimeIntervals(unit)     "Time steps required for the shutdown phase"
    p_u_shutdownTimeIntervalsCeil(unit) "Floor of time steps required for the shutdown phase"
    p_uCounter_shutdownMin(unit, counter_large) "Minimum output for the time steps where the unit is being shut down from the minimum load (minimum output in the first interval). Unit: percent of capacity. values: 0-1. Default = empty."
    p_uCounter_shutdownMax(unit, counter_large) "Maximum output for the time steps where the unit is being shut down from the minimum load (minimum output in the first interval).  Unit: percent of capacity. values: 0-1. Default = empty."
    p_u_minRampSpeedInLastRunUpInterval(unit) "Minimum ramp speed in the last interval for the run-up to min. load. Unit: percent of capacity / min. values: 0-1. Default = 0."
    p_u_minRampSpeedInFirstShutdownInterval(unit) "Minimum ramp speed in the fist interval for the shutdown from min. load. Unit: percent of capacity / min. values: 0-1. Default = 0."


* --- Node parameters --------------------------------------------------------
    // node properties, node connections
    p_gn(grid, node, param_gn)         "Properties for energy nodes"
    p_nEmission(node, emission)        "Emission content (tEmission/MWh)" / /
    p_storageValue(grid, node)         "Constant value of stored something at the end of a time step (EUR/<v_state_unit>)" / /
    p_gnBoundaryPropertiesForStates(grid, node, param_gnBoundaryTypes, param_gnBoundaryProperties) "Properties of different state boundaries and limits" / /
    p_gnn(grid, from_node, to_node, param_gnn) "Data for interconnections between energy nodes" / /


* --- reserve parameters --------------------------------------------------------
    // reserve properties, reserve connections
    p_gnReserves(grid, node, restype, param_policy) "Data defining the reserve rules in each node"
    p_gnuReserves(grid, node, unit, restype, param_policy) "Reserve provision data for units" / /
    p_gnnReserves(grid, from_node, to_node, restype, up_down) "Reserve provision data for node node connections" / /
    p_gnuRes2Res(grid, node, unit, restype, up_down, restype) "The first type of reserve can be used also in the second reserve category (with a possible multiplier)" / /


* --- group parameters --------------------------------------------------------
    // group policies
    p_groupPolicy(group, param_policy) "Two-dimensional policy data for groups" / /
    p_groupPolicyUnit(group, param_policy, unit) "Three-dimensional policy data for groups and units" / /
    p_groupPolicyEmission(group, param_policy, emission) "Three-dimensional policy data for groups and emissions" / /

    // group reserves
    p_groupReserves(group, restype, param_policy) "Data defining the reserve rules in each node group" / /
    p_groupReserves3D(group, restype, up_down, param_policy) "Reserve policy in each node group separately for each reserve type and direction" / /
    p_groupReserves4D(group, restype, up_down, group, param_policy) "Reserve policy in each node group separately for each reserve type and direction, also linking to another group" / /


* --- other parameters --------------------------------------------------------
    // generic userconstraint
    p_userconstraint(group, *, *, *, *, param_userconstraint) "User defined generic constraints" / /

;
$offempty


* =============================================================================
* --- Sample, Forecast, and Time Step Parameters and Scalars ------------------
* =============================================================================

Scalars
    // sample related scalars
    p_sWeightSum "Sum of sample weights"

    // time step related scalars
    tRealizedLast "counter (ord) for the last realized t in the solve"
    currentForecastLength "Length of the forecast in the curren solve, minimum of unchanging and decreasing forecast lengths"
;

* initiating optional input data tables with empty / /
$onempty
Parameters

    // starts and ends
    msStart(mType, s) "Start point of samples: first time step in the sample"
    msEnd(mType, s) "End point of samples: first time step not in the sample"
    tForecastNext(mType) "When the next forecast will be available (ord time)"

    // probabilities, weights, and discount factors
    p_msProbability(mType, s) "Probability of samples (0-1)"
    p_mfProbability(mType, f) "Probability of forecast (0-1)"
    p_sft_probability(s, f, t) "Probability of sft (0-1)"
    p_msWeight(mType, s) "msWeight describes how many times the samples are repeated in order to get the (typically) annual results. Values: (0-1). See modelsInit templates for further info."
    p_msAnnuityWeight(mType, s) "msAnnuityWeight defines the weight of samples in the calculation of fixed costs. Values: (0-1). Sum over year should be 1. See modelsInit templates for further info."
    p_s_discountFactor(s) "Discount factor for samples for objective function. Allows multiyear modelling." / /

    // lengths in hours
    p_sLengthInHours(s) "Sample length in hours"
    p_stepLength(t) "Length of an interval in hours"
    p_stepLengthNoReset(t) "Length of an interval in hours - includes also lengths of previously realized intervals"

    // Time displacement arrays
    dt(t) "Displacement needed to reach the previous time interval (in time steps)"
    dt_circular(t) "Circular t displacement if the time series data is not long enough to cover the model horizon"
    dt_next(t) "Displacement needed to reach the next time interval (in time steps)"
    dt_active(t) "Displacement needed to reach the corresponding active time interval from any time interval (in time steps)"
    dt_toStartup(unit, t) "Displacement from the current time interval to the time interval where the unit was started up in case online variable changes from 0 to 1 (in time steps)"
    dt_toShutdown(unit, t) "Displacement from the current time interval to the time interval where the shutdown phase began in case generation becomes 0 (in time steps)"
    dt_starttypeUnitCounter(starttype, unit, counter_large) "Displacement needed to account for starttype constraints (in time steps)"
    dt_starttypeUnit(starttype, unit) "Displacement needed to account for starttype constraints"
    dt_downtimeUnitCounter(unit, counter_large) "Displacement needed to account for downtime constraints (in time steps)"
    dt_uptimeUnitCounter(unit, counter_large) "Displacement needed to account for uptime constraints (in time steps)"
    dt_trajectory(counter_large) "Run-up/shutdown trajectory time index displacement"

    // Forecast displacement arrays
    df_realization(f) "Displacement needed to reach the realized forecast"
    df(f, t) "Time dependent displacement needed to reach the realized forecast on the current time step"
    df_noReset(f, t) "Time dependent displacement needed to reach the realized forecast on the current time step. Not reseted between solves."
    df_central(f) "Displacement needed to reach the central forecast"
    df_central_t(f, t) "Time dependent displacement needed to reach the central forecast - this is needed when the forecast tree gets reduced in dynamic equations"
    df_reserves(grid, node, restype, f, t) "Time dependent forecast index displacement needed to reach the realized forecast when committing reserves"
    df_reservesGroup(group, restype, f, t) "Time dependent forecast index displacement needed to reach the realized forecast when committing reserves"

    // Temporary foreast displacement arrays
    ddf(f) "Temporary forecast displacement array"
    ddf_(f) "Temporary forecast displacement array"

    // Scaling
    p_scaling_n(node) "Scaling factor for nodes"
    p_scaling_u(unit) "Scaling factor for nu"
    p_scaling_nn(from_node, to_node) "Scaling factor for nn"
    p_scaling_restype(restype) "Scaling factor for restype. Currently not used"

;




* =============================================================================
* --- Model feature parameters ------------------------------------------------
* =============================================================================

Parameters

    // Price and Cost Parameters
    p_price(node, param_price)         "Commodity price parameters" / /
    p_emissionPrice(emission, group, param_price) "emission price parameters (EUR/tEmission)" / /
    p_vomCost(grid, node, unit, param_price) "Calculated static O&M cost for units that includes O&M costs, fuel costs, and emission costs (EUR/MWh)" / /
    p_linkVomCost(grid, from_node, to_node, f, param_price) "Calculated static O&M cost for transfer links including  O&M costs and node costs/profits, e.g. sold electricity (EUR/MWh)." / /
    p_startupCost(unit, starttype, param_price) "Calculated static startup cost that includes startup costs, fuel costs, and emission costs (EUR/MW)"  / /
    p_priceNew(node, f, param_price)         "Commodity price parameters" / /
    p_emissionPriceNew(emission, group, f, param_price) "emission price parameters (EUR/tEmission)" / /
    p_vomCostNew(grid, node, unit, f, param_price) "Calculated static O&M cost that includes O&M costs, fuel costs, and emission costs (EUR/MWh)" / /
    p_startupCostNew(unit, starttype, f, param_price) "Calculated static startup cost that includes startup costs, fuel costs, and emission costs (EUR/MW)" / /
    p_reservePrice(restype, up_down, group, f, param_price) "Calculated reserve price that includes selling reserves to markets (EUR/MW)" / /

    // Roundings
    p_roundingTs(timeseries_) "precision of decimals to which ts_XX_ will be rounded, e.g. 4. Values [1-9]. Default = 0 = off." / /
    p_roundingParam(params) "precision of decimals to which param table will be rounded, e.g. 4. Values [1-9]. Default = 0 = off." / /

    // Forecast Improvements
    p_u_improveForecastNew(unit, timeseries_) "Number of time steps ahead of time that the forecast is improved on each solve for each (unit, timeseries)." / /
    p_gn_improveForecastNew(*, *, timeseries_) "Number of time steps ahead of time that the forecast is improved on each solve for each (grid/flow/restype, node, timeseries)." / /
    ts_gnu_forecastImprovement(grid, node, unit, param_gnu, f) "Number of time steps ahead of time that the ts_gnu forecast is improved on each solve for each (grid, node, unit, param_gnu, f)." / /
    p_group_improveForecastNew(*, group, timeseries_) "Number of time steps ahead of time that the forecast is improved on each solve for each (emission, group, timeseries)." / /


    // ts Circulation Rules
    unit_tsCirculation(timeseries, unit, f, tsCirculationRules, tsCirculationParams) "tsCirculation settings defining unit ts data (ts_unit, ts_unitConstraint, ts_unitConstraintNode) circulation."
    gn_tsCirculation(timeseries, *, node, f, tsCirculationRules, tsCirculationParams) "tsCirculation settings defining gn ts data (ts_influx, ts_cf, ts_node, ts_gnn, ts_priceNew, ts_storageValue) circulation. * for grid/flow"
    ts_gnu_circulationRules(grid, node, unit, param_gnu, f, tsCirculationRules, tsCirculationParams) "tsCirculation settings defining ts_gnu_io circulation."  / /
    reserve_tsCirculation(timeseries, restype, up_down, group, f, tsCirculationRules, tsCirculationParams) "tsCirculation settings defining reserve ts data (ts_reserveDemand, ts_reservePrice) circulation."
    group_tsCirculation(timeseries, *, group, f, tsCirculationRules, tsCirculationParams) "tsCirculation settings defining group ts data (ts_emissionPrice) circulation. * for emission."

;

* =============================================================================
* --- Time series --------------------------------------------------------------
* =============================================================================

Parameters

* --- Input Data ts and cost ts derived from input data -----------------------

    // Unit time series
    ts_unit(unit, param_unit, f, t) "Time dependent unit data, where energy type doesn't matter" / /
    ts_unitConstraint(unit, constraint, param_constraint, f, t) "Time series constant for constraints (eq1-9, gt1-9, lt1-9) between inputs and/or outputs" / /
    ts_unitConstraintNode(unit, constraint, node, f, t) "Time series (unit, node) coefficients for constraints (eq1-9, gt1-9, lt1-9) between inputs and/or outputs" / /

    // Node time series
    ts_influx(grid, node, f, t) "External power inflow/outflow during a time step (MWh/h)" / /
    ts_cf(flow, node, f, t) "Available capacity factor time series. Unit: percent of capacity. values: 0-1. Default = 0." / /
    ts_node(grid, node, param_gnBoundaryTypes, f, t) "Time series for node constraints (<v_state_unit>) or balance penalty cost (EUR / <v_state_unit>)" / /
    ts_price(node, t) "Commodity price (EUR/MWh). Values are read directly from input data or calculated from ts_priceChange. Can use both, but only one option for each node allowed." / /
    ts_priceChange(node, t) "Initial commodity price and consequent changes in commodity price (EUR/MWh)" / /
    ts_priceNew(node, f, t) "Commodity price (EUR/MWh). Values are read directly from input data or calculated from ts_priceChange. Can use both, but only one option for each node allowed." / /
    ts_priceChangeNew(node, f, t) "Initial commodity price and consequent changes in commodity price (EUR/MWh)" / /
    ts_storageValue(grid, node, f, t) "Time series of storage value at the end of a time step (EUR/<v_state_unit>)" / /

    // gnu timeseries
    ts_gnu_io(grid, node, unit, input_output, param_gnu, f, t) Time dependent gnu data (unit depending on parameter)" / /

    // gnn timeseries
    ts_gnn(grid, from_node, to_node, param_gnn, f, t) "Time dependent interconnection data (unit depending on parameter)" / /

    // Alternatives for giving time series data vertically
    ts_influx_vert(t, grid, node, f) "Vertical input variant of ts_influx (MWh/h)"
    ts_cf_vert(t, flow, node, f) "Vertical input variant of ts_cf. Unit: percent of capacity. values: 0-1. Default = 0."

    // Reserve time series
    ts_reserveDemand(restype, up_down, group, f, t) "Reserve demand in region in the time step (MW)" / /
    ts_reservePrice(restype, up_down, group, f, t) "Reserve price in region in the time step (EUR/MW)" / /
    ts_reservePriceChange(restype, up_down, group, f, t) "Initial reserve price and consequent changes in the price (EUR/MWh)" / /

    // Group time series
    ts_emissionPrice(emission, group, t) "Emission group price time series (EUR/tEmission)" / /
    ts_emissionPriceChange(emission, group, t) "Initial emission group price and consequent changes in price (EUR/tEmission)" / /
    ts_emissionPriceNew(emission, group, f, t) "Emission group price time series (EUR/tEmission)" / /
    ts_emissionPriceChangeNew(emission, group, f, t) "Initial emission group price and consequent changes in price (EUR/tEmission)" / /
    ts_groupPolicy(group, param_policy, t) "Two-dimensional time-dependent policy data for groups" / /


* --- Processed Time series for the Solve -------------------------------------

    // processed unit time series used in solve
    ts_unit_(unit, param_unit, f, t) "ts_unit values processed for solve including time step aggregation if required"
    ts_unitConstraint_(unit, constraint, param_constraint, f, t) "ts_unitConstraint values processed for solve including time step aggregation if required (coefficient of constraint)"
    ts_unitConstraintNode_(unit, constraint, node, f, t) "ts_unitConstraintNode values processed for solve including time step aggregation if required (coefficient of constraint)"

    // Processed node time series used in solve
    ts_influx_(grid, node, f, t) "ts_influx values processed for solve including time step aggregation if required (MWh/h)"
    ts_cf_(flow, node, f, t) "ts_cf values processed for solve including time step aggregation if required (p.u.)"
    ts_node_(grid, node, param_gnBoundaryTypes, f, t) "ts_node values processed for solve including time step aggregation if required (unit depending on parameter)"
    ts_price_(node, t) "ts_price values processed for solve including time step aggregation if required (EUR/MWh)"
    ts_priceNew_(node, f, t) "ts_priceNew values processed for solve including time step aggregation if required (EUR/MWh)"
    ts_storageValue_(grid, node, f, t) "ts_storageValue values processed for solve including time step aggregation if required (EUR/<v_state_unit>)"

    // Processed gnu time series used in solve
    ts_gnu_(grid, node, unit, param_gnu, f, t) "ts_gnu values processed for solve including time step aggregation if required (unit depending on parameter)"

    // Processed gnn time series used in solve
    ts_gnn_(grid, from_node, to_node, param_gnn, f, t) "ts_gnn values processed for solve including time step aggregation if required (unit depending on parameter)"

    // Processed reserve time series used in solve
    ts_reserveDemand_(restype, up_down, group, f, t) "ts_reserveDemand values processed for solve including time step aggregation if required (MW)"
    ts_reservePrice_(restype, up_down, group, f, t) "ts_reservePrice values processed for solve including time step aggregation if required (EUR/MWh)"

    // Processed group time series used in solve
    ts_emissionPrice_(emission, group, t) "ts_emissionPrice values processed for solve including time step aggregation if required (EUR/tEmission)" / /
    ts_emissionPriceNew_(emission, group, f, t) "ts_emissionPriceNew values processed for solve including time step aggregation if required (EUR/tEmission)" / /
    ts_groupPolicy_(group, param_policy, t) "Two-dimensional time-dependent policy data for groups processed for solve including time step aggregation if required"

    // derived unit time series used in solve
    ts_vomCost_(grid, node, unit, t) "unit variable operational costs including vomCosts, fuel costs, and emission costs for solve including time step aggregation if required (EUR/MWh)" / /
    ts_startupCost_(unit, starttype, t) "unit startup costs including direct startup costs, fuel costs, and emission costs for solve including time step aggregation if required (EUR/MW)"
    ts_vomCostNew_(grid, node, unit, f, t) "unit variable operational costs including vomCosts, fuel costs, and emission costs for solve including time step aggregation if required, new method with f dimension (EUR/MWh)" / /
    ts_startupCostNew_(unit, starttype, f, t) "unit startup costs including direct startup costs, fuel costs, and emission costs for solve including time step aggregation if required, new method with f dimension (EUR/MW)"
    ts_effUnit_(effSelector, unit, effSelector, param_eff, f, t) "Calculated time dependent data for piece-wise linear efficiency blocks for solve including time step aggregation if required "
    ts_effGroupUnit_(effSelector, unit, param_eff, f, t) "Calculated time dependent unit data specific to a efficiency group (e.g. left border of the unit) for solve including time step aggregation if required "

    // derived gn time series used in solve
    ts_linkVomCost_(grid, node, node, f, t) "ts_linkVomCost_ includes transfer link O&M cost and node costs/profits, e.g. sold electricity (EUR/MWh). Values are processed for solve including time step aggregation if required."

* --- Other ts Parameters -----------------------------------------------------

    // ts storages used for updating data in inputsLoop.gms
    ts_unit_update(unit, param_unit, f, t)
    ts_influx_update(grid, node, f, t)
    ts_cf_update(flow, node, f, t)
    ts_node_update(grid, node, param_gnBoundaryTypes, f, t)
    ts_gnn_update(grid, node, node, param_gnn, f, t)
    ts_reserveDemand_update(restype, up_down, group, f, t)

    // circular adjustment to unit time series
    ts_unit_circularAdjustment(unit, param_unit, f, t) "Calculated additional ts_unit values used in adjusting circulation of data" / /
    ts_unitConstraint_circularAdjustment(unit, constraint, param_constraint, f, t) "Calculated additional ts_unitConstraint values used in adjusting circulation of data" / /
    ts_unitConstraintNode_circularAdjustment(unit, constraint, node, f, t) "Calculated additional ts_unitConstraint values used in adjusting circulation of data" / /

    // circular adjustment to node time series
    ts_influx_circularAdjustment(grid, node, f, t) "Calculated additional ts_influx values used in adjusting circulation of data" / /
    ts_cf_circularAdjustment(flow, node, f, t) "Calculated additional ts_cf values used in adjusting circulation of data" / /
    ts_node_circularAdjustment(grid, node, param_gnBoundaryTypes, f, t) "Calculated additional ts_node values used in adjusting circulation of data" / /
    ts_gnn_circularAdjustment(grid, node, node, param_gnn, f, t) "Calculated additional ts_gnn values used in adjusting circulation of data" / /
    ts_priceNew_circularAdjustment(node, f, t) "Calculated additional ts_priceNew values used in adjusting circulation of data" / /
    ts_storageValue_circularAdjustment(grid, node, f, t) "Calculated additional ts_storageValues values used in adjusting circulation of data" / /

    // ts_gnu
    ts_gnu_circularAdjustment(grid, node, unit, param_gnu, f, t) "Calculated additional ts_gnu values used in adjusting circulation of data" / /

    // circular adjustment to reserve time series
    ts_reserveDemand_circularAdjustment(restype, up_down, group, f, t) "Calculated additional ts_reserveDemand values used in adjusting circulation of data" / /
    ts_reservePrice_circularAdjustment(restype, up_down, group, f, t) "Calculated additional ts_reservePrice values used in adjusting circulation of data" / /

    // circular adjustment to group time series
    ts_emissionPriceNew_circularAdjustment(emission, group, f, t) "Calculated additional ts_emissionPriceNew values used in adjusting circulation of data" / /

;
$offempty

* =============================================================================
* --- Mapping parameters for different time indexes ---------------------------
* =============================================================================

Parameters
    p_delay_gnutt(grid, node, unit, t, t_) "portion of v_gen(t) converted to v_gen_delay(t_). Sum over each t is stepLength(t) and sum over each t_ is stepLength(t_)."
;


* =============================================================================
* --- Penalty Definitions -----------------------------------------------------
* =============================================================================

Scalars
    PENALTY "Default equation violation penalty"
    BIG_M "A large number used together with with binary variables in some equations"
;

Parameters
    PENALTY_BALANCE(grid, node) "Penalty on violating energy balance equation (EUR/MWh)"
    PENALTY_GENRAMP(grid, node, unit) "Penalty on violating ramp limits (EUR/(MW/h))"
    PENALTY_RES(restype, up_down) "Penalty on violating a reserve (EUR/MW)"
    PENALTY_RES_MISSING(restype, up_down) "Penalty on violating a reserve (EUR/MW)"
    PENALTY_CAPACITY(grid, node) "Penalty on violating capacity margin eq. (EUR/MW/h)"
    PENALTY_UC(group) "Penalty on violating userconstraint (EUR/unit of userconstraint)"
;


