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
* --- Model Related Set Definitions -------------------------------------------
* =============================================================================

Sets

* --- Model Related Selections ------------------------------------------------

    mType "model types in the Backbone" /
        building,
        invest,
        schedule
        /

    mSetting "setting categories for models" /

        // General Time Structure
        t_start "First time step for the start of simulation, e.g. t000001"
        t_jump "Number of time steps realized with each solve"
        t_horizon "Length of the simulation horizon in time steps (central forecast)"
        t_end "Last time step of the simulation"
        loadPoint "Load advanced basis; 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve"
        savePoint "Save advanced basis; 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve"
        lastStepInIntervalBlock "Last time step in the block of intervals with the same length"
        stepsPerInterval "Number of time steps aggregated within interval"
        stepLengthInHours "Length of a time step in hours"

        // Samples and Forecasts
        samples "Number of active samples"
        forecasts "Number of active forecasts"
        t_forecastLengthUnchanging "Length of forecasts in time steps - this does not decrease when the solve moves forward"
        t_forecastLengthDecreasesFrom "Length of forecasts in time steps - this decreases when the solve moves forward until the new forecast data is read and then extends back to full length"
        t_forecastStart "At which time step the first forecast is available ( 1 = t000001 )"
        t_forecastJump "Number of time steps between each update of the forecasts"
        t_improveForecast "Number of time steps ahead of time on which the forecast is improved on each solve"
        t_improveForecastNew "Number of time steps ahead of time on which the aggregated forecast is improved on each solve. Does not edit original data."
        t_perfectForesight "Number of time steps for which realized data is used instead of forecasts. Note: always covers at least t_jump."
        onlyExistingForecasts "Use only existing forecast values when reading updated forecasts. Note: zero values need to be saved as Eps in the gdx file."
        candidate_periods "Number of candidate periods which are mapped to typical periods"
        boundForecastEnds "0/1 parameter if last v_state and v_online in f02,f03,... are bound to f01"

        // Features
        t_trajectoryHorizon "Length of the horizon when start-up and shutdown trajectories are considered (in time steps)"
        t_initializationPeriod "Number of time steps in the beginning of the simulation which are solved but the results of which are not stored"
        dataLength "The maximum number of time steps in any input data time series (recommended for correctly circulating data)"
        incHRAdditionalConstraints "Method to include the two additional constraints for incremental heat rates"
                                   // 0 = include for units with non-convex fuel use, 1 = include for all units
        scalingMethod "Method for scaling the model. Values [0-4] signifying the scaling of 10^value, e.g. 2 = 100x scaling. Default = 0 = no scaling."
        automaticRoundings "A predefined set of rounding rules that are applied unless user have manually set alternative values. Default = 0 = off. 1 = on."
        reducedDummies "Method to reduce the amount of generated dummy variables. Can be tried with well behaving models. Default = 0 = off. 1 = removing estimated unrequired directions. values 2=> removing all from first x hours."
        reducedVqGen "Method to reduce the amount of generated vq_gen variables. Can be tried with well behaving models. Default = 0 = off. 1 = removing estimated unrequired directions. values 2=> removing all from first x hours."
        reducedVqGenRamp "Method to reduce the amount of generated vq_genRampUp and vq_genRampDown variables. Can be tried with well behaving models. Default = 0 = off. Values 2=> removing all from first x hours."
        reducedVqResDemand "Method to reduce the amount of generated vq_ResDemand variables. Can be tried with well behaving models. Default = 0 = off. Values 2=> removing all from first x hours."
        reducedVqResMissing "Method to reduce the amount of generated vq_ResMissing variables. Can be tried with well behaving models. Default = 0 = off. Values 2=> removing all from first x hours."
        reducedVqUnitConstraint "Method to reduce the amount of generated vq_Unitconstraint variables. Can be tried with well behaving models. Default = 0 = off. Values 2=> removing all from first x hours."
        reducedVqUserconstraint "Method to reduce the amount of generated vq_Userconstraint variables. Can be tried with well behaving models. Default = 0 = off. Values 2=> removing all from first x hours."
        nonanticipativity "Method to set states and v_online of the first timestep(s) of different non-realized forecasts to be equal. Default = 0 = off. Values 1=> applying nonanticipativity to first x hours of the forecast. Calculated from the timestamp of aggregated hours."
        /

    solve_info "Containers for solve information" /
        modelStat "Status of the model after solve"
        solveStat "Status of the solve"
        totalTime "Total time of solve"
        solverTime "Solver time of solve"
        iterations "Number of iteration"
        nodes "Number of nodes in the solve"
        numEqu "Number of equations in the solve"
        numDVar "Number of discrete variables in the solve"
        numVar "Number of variables in the solve"
        numNZ "Number of non-zero entries in the solve matrix"
        sumInfes "Sum of infeasibilities"
        objEst "Estimate for the best possible objective value"
        objVal "Objective value"
        /

* --- Efficiency Approximation Related Sets -----------------------------------

    // Efficiency Levels and Categories
    effLevel "Pre-defined levels for efficiency representation that can start from t_solve + x"
        / level1*level9 /
    effSelector "Select equations and lambdas/slope for efficiency calculations"
        / lambda01*lambda12, directOff, directOnLP, directOnMIP , incHR/ // NOTE! Lambdas required first!
    effDirect(effSelector) "Using direct input to output equation"
        / directOff, directOnLP, directOnMIP /
    effDirectOff(effSelector) "Using direct input to output equation without online variable, i.e. constant efficiency"
        / directOff /
    effDirectOn(effSelector) "Using direct input to output equation with online variable"
        / directOnLP, directOnMIP /
    effLambda(effSelector) "Lambdas in use for part-load efficiency representation"
        / lambda01*lambda12 /
    effIncHR(effSelector) "Using incremental heat rate equation"
        / incHR /
    effOnline(effSelector) "Efficiency selectors that use online variables"
        / directOnLP, directOnMIP, lambda01*lambda12 ,incHR / // IMPORTANT! Online variables are generated based on this, so keep it up to date!

* --- General and Directional Sets --------------------------------------------

    // General Counter
    counter_large "General counter set"
        /c000*c999/
    // Directional Sets
    input_output "Designating nodes as either inputs or outputs"
        / input, output /
    inc_dec "Increase or decrease in dummy, or slack variables"
        / increase, decrease /
    min_max "Minimum and maximum"
        / min, max /
    // constraints
    constraint "Possible names for constraints"
        / eq1*eq9, gt1*gt9, lt1*lt9 /
    eq_constraint(constraint) "Equality constraints"
        / eq1*eq9 /
    gt_constraint(constraint) "Greater than constraints"
        / gt1*gt9 /
    lt_constraint(constraint) "Lesser than constraints"
        / lt1*lt9 /

* --- Model Feature Sets ------------------------------------------------------

    // Unit Startup Related Sets
    starttype "Startup types" /
        hot "Hot start"
        warm "Warm start"
        cold "Cold start"
        /
    starttypeConstrained(starttype) "Startup types with constrained maximum non-opearational time"
        / hot, warm /
    cost_consumption "Startup cost or startup fuel consumption"
        / cost, consumption /

    // Other Features
    feature "Set of optional model features" /
        storageValue     "Use storage value instead of fixed control"
         /

* --- Set to declare parameters for further processing ------------------------
    params "Names of parameters for further processing" /
        p_vomCost
        p_vomCostNew
        p_startupCost
        p_startupCostNew
        p_linkVomCost
        p_emissionPrice
        p_emissionPriceNew
        p_reservePrice
        /

* --- Set to declare time series that will be read between solves -------------
    // priceChange time series are aggreaged to price time series and not listed here
    timeseries "Names of input data time series (ts_XX)" /
        // unit time series
        ts_unit
        ts_unitConstraint
        ts_unitConstraintNode
        // gn time series
        ts_influx
        ts_cf
        ts_node
        ts_gnn
        ts_price
        ts_priceNew
        ts_storageValue
        // reserve time series
        ts_reserveDemand
        ts_reservePrice
        // group time series
        ts_emissionPrice
        ts_emissionPriceNew
        ts_groupPolicy

        // derived unit time series
        ts_vomCost
        ts_vomCostNew
        ts_startupCost
        ts_startupCostNew
        // derived gn time series
        ts_linkVomCost
        /

* --- Set to declare time series are processed for each solve -----------------
    // processing includes filtering, aggregation, improved forecasts, etc.
    timeseries_ "Names of time series processed for solve (ts_XX_)" /
        // unit time series
        ts_unit_
        ts_unitConstraint_
        ts_unitConstraintNode_
        // gn time series
        ts_influx_
        ts_cf_
        ts_node_
        ts_gnn_
        ts_price_
        ts_priceNew_
        ts_storageValue_
        // reserve time series
        ts_reserveDemand_
        ts_reservePrice_
        // group time series
        ts_emissionPrice_
        ts_emissionPriceNew_
        ts_groupPolicy_
        // derived unit time series
        ts_vomCost_
        ts_startupCost_
        ts_vomCostNew_
        ts_startupCostNew_
        ts_effUnit_
        ts_effGroupUnit_
        // derived gn time series
        ts_linkVomCost_

        /

; // END Sets

* =============================================================================
* --- Model Parameter Definitions ---------------------------------------------
* =============================================================================

* --- Numeric Model Parameters ------------------------------------------------

// General model parameter arrays
Parameter
*    settings(mSetting)
    mSettings(mType, mSetting) "Model settings array"
    mSettingsEff(mtype, effLevel) "Model efficiency approximation array"
    mSettingsEff_start(mtype, effLevel) "The first time step of the efficiency level - mSettingsEff is the last"
    mInterval(mType, mSetting, counter_large) "Model interval array"
    t_skip_counter "Numerical counter for solve time steps"
;

// Features
// search key: activeFeatures
Set active(mType, feature) "Set membership tells active model features";
option clear = active;

* =============================================================================
* --- Parameter Set Definitions -----------------------------------------------
* =============================================================================

Sets

* --- Parameter Data Related Sets ---------------------------------------------

* Parameter units are given in brackets after the names to help users.
* These default units are not strict limits and some can be modified easily and some with little care.
* One example of alternative units is the currency. Default unit says EUR, but it can be any currency unit.
* Also MW of generation and MWh of storages can be used to model e.g. tons of emissions without
* changing any code, but in this case the modeller must be careful to not mix up units.

param_gn  "Possible parameters for grid, node" /
    isActive           "Flag if gn is active. By default = 1. Value 0 = off."
    nodeBalance        "A flag to decide whether node balance constraint is to be used and price option disabled (empty or 1)"
    usePrice           "A flag to decide if node has prices activated and balance deactivated (empty or 1). Must choose either balance or price."
    selfDischargeLoss  "Self discharge rate of the node. Unit: percent of [v_state] / hour. Values: 0-1. Default = 0."
    energyStoredPerUnitOfState "A possible unit conversion if v_state uses something else than MWh (MWh/[v_state])"
    boundStart         "A flag to bound the first t in the run using reference constant or time series (empty or 1)"
    boundStartOfSamples  "A flag to bound the first t of each sample using reference constant or time series (empty or 1)"
    boundStartAndEnd   "A flag that both start and end are bound using reference constant or time series (empty or 1)"
    boundStartToEnd    "A flag to force the last states of solve to equal the first state (empty or 1). Works only when solveCount > 1, e.g. in schedule run."
    boundEnd           "A flag to bound last t in each solve based on the reference constant or time series (empty or 1)"
    boundEndOfSamples  "A flag to bound the last t of each sample using reference constant or time series (empty or 1)"
    boundAll           "A flag to bound the state to the reference in all time steps (empty or 1)"
    boundSumOverInterval "A flag to bound the state to (the sum of) the nonzero reference (empty or 1)"
*    forecastLength "Length of forecasts in use for the node (hours). After this, the node will use the central forecast."  // NOT IMPLEMENTED
    capacityMargin     "Capacity margin used in invest mode (MW)"
    storageValueUseTimeSeries "A flag to determine whether to use `storageValue` time series (empty or 1)"
    influx             "Constant value influx (MWh/h). Time serie influx is used instead if user gives both."
/

param_gnBoundaryTypes "Types of boundaries that can be set for a node with balance" /
    upwardLimit      "Absolute maximum state of the node (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    downwardLimit    "Absolute minimum energy in the node (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    upwardSlack01*upwardSlack20 "A threshold after which a specific cost co-efficient is applied (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    downwardSlack01*downwardSlack20 "A threshold after which a specific cost co-efficient is applied (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    reference        "Reference value for a state that can be used to bound a state (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    maxSpill         "Maximum spill rate from the node (MWh/h, unless modified by energyStoredPerUnitOfState parameter)"
    minSpill         "Minimum spill rate from the node (MWh/h, unless modified by energyStoredPerUnitOfState parameter)"
    balancePenalty   "Penalty value for violating the energy balance of that particular node (EUR/MWh, unless modified by energyStoredPerUnitOfState parameter). Can be interpretated as the energy price in certain settings."
/

param_gnBoundaryProperties "Properties that can be set for the different boundaries" /
    useTimeSeries    "A flag to use time series to set state bounds and limits (empty or 1)"
    useConstant      "A flag to use constant to set state bounds and limits (empty or 1)"
*    deltaFromReference "The constant or the time series indicate how much the boundary deviates from reference (instead of being an absolute number)"  // NOT IMPLEMENTED
    constant         "A constant value for the boundary or the reference (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    slackCost        "The cost of exceeding the slack boundary (EUR/MWh, unless modified by energyStoredPerUnitOfState parameter)"
    multiplier       "A multiplier to change the value of either constant or time series (default 1)"
/

param_gnn "Set of possible data parameters for grid, from_node, to_node (nodal interconnections)" /
    isActive         "Flag if gnn is active. By default = 1, unless capacity or availability is constant zero. Value 0 = off."
    transferCap      "Transfer capacity limits (MW)"
    transferCapBidirectional "Total bidirectional transfer capacity limit (MW)"
    transferLoss     "Transfer losses. Unit: percent of [v_trasnfer]. Values: 0-1. Default = 0."
    diffCoeff        "Coefficients for energy diffusion between nodes. Unit: percent of [v_state]. Values: 0-1. Default = 0."
    diffLosses       "Coefficient for diffusion losses between nodes. Unit: percent of diffusion. Values: 0-1. Default = 0."
    boundStateMaxDiff "Maximum difference of node state pairs ([v_state])"
    transferCapInvLimit "Capacity limit for investments (MW)"
    investMIP        "A flag to make integer investment instead of continuous investment (empty or 1). Used with param_gnn unitSize."
    unitSize         "Size of one link for integer investments (MW)"
    invCost          "Investment cost (EUR/MW)"
    annuityFactor    "Investment annuityFactor used to multiply investment cost for annualization of costs (0-1)"
    portion_of_transfer_to_reserve "Portion of the infeed from the unit that needs to be available as reserve if the unit fails (0-1)"
    rampLimit        "Maximum ramp speed of transfer link. Unit: percent of capacity / min. Values: 0-2. Default = 0. NOTE: does not apply to reserve tranfer at the moment."
    variableTransCost "Variable cost applied to transfers (EUR/MWh)"
    availability     "Availability of the interconnection. Unit: percent of capacity. Values: 0-1. Default = 0."
    useTimeseriesAvailability "A flag to use time series form input for availability (empty or 1)"
    useTimeseriesLoss "A flag to use time series form input for transferLoss (empty or 1)"
/

param_gnu "Set of possible data parameters for grid, node, unit" /
    isActive      "A flag if gnu combination is active. By default = 1. Value 0 = off."
    capacity      "Maximum capacity (MW)"
    conversionCoeff "Coefficient for conversion equation (float). Multiplies each input or output when summing v_gen from multiple inputs/outputs."
    useInitialGeneration     "A flag to indicate whether to fix generation for the first time step (empty or 1)"
    initialGeneration        "Initial generation/consumption of the unit in the first time step (MW)"
    maxRampUp     "Maximum speed to ramp up. Unit: percent of capacity / min. values: 0-1. Default = 1."
    maxRampDown   "Maximum speed to ramp down. Unit: percent of capacity / min. values: 0-1. Default = 1."
    rampUpCost    "Wear and tear cost of ramping up the generation (EUR/MWh)."
    rampDownCost  "Wear and tear cost of ramping down the generation (EUR/MWh)."
    upperLimitCapacityRatio  "Ratio of the upper limit of the node state and the unit capacity (existing + investment) ([v_state]/MW)"
    unitSize      "Input/Output capacity of one subunit for integer investments (MW)"
    invCosts      "Investment costs (EUR/MW)"
    annuityFactor "Investment annuityFactor used to multiply investment cost for annualization of costs (0-1)"
    invEnergyCost "Investment energy cost (MWh/MW). Consumes energy from input/output node."
    fomCosts      "Fixed operation and maintenance costs (EUR/MW/a)"
    vomCosts      "Variable operation and maintenance costs (EUR/MWh)"
    inertia       "Inertia of the unit (s)"
    unitSizeMVA   "Generator MVA rating of one subunit (MVA)"
    availabilityCapacityMargin  "Availability of the unit in the capacity margin equation. Unit: percent of capacity. values: 0-1. Default = 0. If zero, v_gen is used."
    startCostCold "Variable start-up costs for cold starts excluding fuel costs (EUR/MW)"
    startCostWarm "Variable start-up costs for warm starts excluding fuel costs (EUR/MW)"
    startCostHot  "Variable start-up costs for hot starts excluding fuel costs (EUR/MW)"
    startFuelConsCold "Consumption of start-up fuel per cold subunit started up (MWh_fuel/MW)"
    startFuelConsWarm "Consumption of start-up fuel per warm subunit started up (MWh_fuel/MW)"
    startFuelConsHot "Consumption of start-up fuel per hot subunit started up (MWh_fuel/MW)"
    shutdownCost  "Cost of shutting down the unit (EUR/MW)"
    delay         "Delay of output (hours)"
    cb            "Fixed ratio of two input or outputs, unless modified by cv. Requires that nodes are not already impacted by unitConstraints."
    cv            "Extraction ratio of two input or outputs. Requires that nodes are not already impacted by unitConstraints."
/

* Emissions in model typically include CO2 measured in tonnes of CO2 (tCO2).
* Same equations can be used to model multiple emissions and the unit in parameters and equations is generic (tEmission).
* In addition, equations apply also for modelling other environmental impacts (pollutants, land-use, or material demand), and
* economic side products (green certificates, guarantees of origin, etc).
param_gnuEmission "Properties that can be set for emissions from operation, capacity, and investments" /
    vomEmissions  "Emissions from variable operation and maintenance (tEmission/MWh)"
    fomEmissions  "Emissions from fixed operation and maintenance (tEmission/MW/a)"
    invEmissions  "Emissions from capacity investments (tEmission/MW)"
    invEmissionsFactor "Factor used to multiply investment emissions to divide them over multiple years (0-1). Default 1."
    // not implemented, but could be expanded to
    //startEmissionsCold
    //startEmissionsWarm
    //startEmissionsHot
    //shutdownEmissions
/

param_gnuBoundaryProperties "Properties that can be set for the different boundaries" /
    rampLimit     "Maximum ramp speed of unit Unit: percent of capacity / min. values: 0-1. Default = 1."
    rampCost      "Piecewise cost of ramping up (upwardSlack) or down (downwardSlack) the generation of gnu (EUR/MW). Note: Needs to be paired with 'rampLimit'"
/

param_unit "Set of possible data parameters for units" /
    isActive           "A flag if unit is active. By default = 1, unless availability is constant zero. Value 0 = off."
    isSource           "A flag if unit has only outputs. Not required for a flow unit."
    isSink             "A flag if unit has only inputs. Not required for a flow unit."
    unitCount          "Number of subunits if aggregated (integer). Default 1."
    // unused: remove for 4.x
    outputCapacityTotal  "Total output capacity of the unit (MW). Automatically calculated by summing all the outputs together by default, unless defined in data."
    // unused: remove for 4.x
    unitOutputCapacityTotal "Total output capacity of the unit (MW). Automatically calculated by summing all the subunit output sizes together by default."
    availability         "Availability of given energy conversion technology. Unit: percent of capacity. values: 0-1. Default = 0."
    useInitialOnlineStatus   "A flag to fix the online status of a unit for the first time step (empty or 1)"
    initialOnlineStatus      "Initial online status of the unit in the first time step (0-1)"
    startColdAfterXhours "Offline hours after which the start-up will be a cold start (h)"
    startWarmAfterXhours "Offline hours after which the start-up will be a warm start (h)"
    rampSpeedToMinLoad   "Ramping speed from start-up to minimum load Unit: percent of capacity / min. values: 0-1. Default = 1."
    rampSpeedFromMinLoad "Ramping speed from shutdown decision to zero load. Unit: percent of capacity / min. values: 0-1. Default = 1."
    minOperationHours    "Minimum operation time (h), prevents shutdown after startup until the defined amount of time has passed"
    minShutdownHours     "Minimum shut down time (h), prevents starting up again after the defined amount of time has passed"
*    resTimelim    "How long should a storage be able to provide reserve (h)"  // NOT IMPLEMENTED
    eff00 * eff12 "Efficiency of the unit to convert input to output/intermediate product (positive float)"
    opFirstCross  "The operating point where the real efficiency curve and approximated efficiency curve cross"
    op00 * op12   "Right border of the efficiency point (0-1)"
    hr00 * hr12   "Incremental heat rates (GJ/MWh)"
    hrop00 * hrop12   "Right border of the incremental heat rates"
    section       "Possibility to define a no load fuel use for units with zero minimum output"
    hrsection     "no load fuel use to be defined when using incremental heat rates"
    useTimeseries             "A flag to use efficiency time series form input for unit parameters whenever possible (empty or 1)"
    useTimeseriesAvailability "A flag to use availability time series form input for unit parameters whenever possible (empty or 1)"
    investMIP     "A flag to make integer investment instead of continous investment (empty or 1)"
    maxUnitCount  "Maximum number of units when making integer investments (positive integer)"
    minUnitCount  "Minimum number of units when making integer investments (positive integer)"
    fixedFlow     "A flag to fix the production or consumption of the unit based on availability, flow, and capacity (empty or 1)"
    // Calculated based on other input data
    lastStepNotAggregated "Last time step when the unit is not yet aggregated - calculated in inputsLoop.gms for units that have aggregation"
    becomeAvailable       "Time step when the unit becomes available (t). After this the unit and its equations are added to the solve."
    becomeUnavailable     "Time step when the unit becomes unavailable (t). After this the unit and its equations are removed from the solve."
/

param_eff "Parameters used for unit efficiency approximations" /
    lb      "Minimum load of the unit"
    op      "Maximum load of the unit, or the operating point of the SOS2 variable in the piecewise linear heat rate approximation (lambda)"
    section "Operational heat rate of the unit, or the SOS2 variable in the piecewise linear heat rate approximation (lambda)"
    slope   "Heat rate parameter representing no-load fuel consumption"
/

param_price "Parameters for node prices" /
    price         "Value when using constant price (EUR/MWh)"
    useConstant   "Automatically generated flag to use constant price data (empty or 1)"
    useTimeSeries "Automatically generated flag to use time series price data (empty or 1)"
    average       "Average value of time series in active t (EUR/MWh). Used as helper parameter to avoid repeated calculations."
/

param_unitStartupfuel "Parameters for startup fuel limits in units" /
    fixedFuelFraction "Fixed share of a fuel in the consumption mix (0-1). The sums of start fuels of a unit must be 1."   //only for start-up fuels
/

param_constraint "Parameters used with eq/gt/lt constraints" /
    constant      "constant term on the RHS of equations"
    onlineMultiplier "multiplier applied to unit v_online"
/

param_policy "Set of possible data parameters for groups or grid, node, regulation" /
    emissionCap    "Emission limit (tonne)"
    instantaneousShareMax "Maximum instantaneous share of generation and import from a particular group of units and transfer links (0-1)"
    energyMax      "Maximum energy production or consumption from particular grid-node-units over particular samples (MWh)"
    energyMin      "Minimum energy production or consumption from particular grid-node-units over particular samples (MWh)"
    energyShareMax "Maximum share of energy production from particular grid-node-units over particular samples (0-1)"
    energyShareMin "Minimum share of energy production from particular grid-node-units over particular samples (0-1)"
    constrainedCapMultiplier "Multiplier a(i) for unit investments in equation Sum(i, a(i)*v_invest(i)) <= b"
    constrainedCapTotalMax "Total maximum b for unit investments in equation Sum(i, a(i)*v_invest(i)) <= b"
    constrainedOnlineMultiplier "Multiplier a(i) for online units in equation Sum(i, a(i)*v_online(i)) <= b"
    constrainedOnlineTotalMax "Total maximum b for online units in equation Sum(i, a(i)*v_online(i)) <= b"
    ROCOF          "Maximum rate of change of frequency (Hz/s)"
    defaultFrequency "Nominal frequency in the system (Hz)"
    staticInertia  "A flag to indicate static inertia constraint should be implemented (empty or 1) - q_inertiaMin"
    dynamicInertia "A flag to indicate dynamic inertia constraint should be implemented (empty or 1) - q_rateOfChangeOfFrequencyUnit/Transfer"
    // Reserve related parameters. Could be moved to their own parameter set?
    update_frequency "Frequency of updating reserve contributions (number of timesteps)"
    update_offset  "Optional offset for delaying the reserve update frequency (number of timesteps)"
    gate_closure   "Number of timesteps ahead of dispatch that reserves are fixed (positive integer)"
    useTimeSeries  "Flag for using time series data (empty or 1)"
    reserve_length "Length of reserve horizon (number of timesteps)"
    reserve_activation_duration "How long the reserve should be provided once activated (h)"
    reserve_reactivation_time "How soon the unit providing reserve needs to be able to reactivate after the start of the previous activation (h)"
    reserveReliability "Reliability parameter of reserve provisions"
    reserve_increase_ratio "Unit output is multiplied by this factor to get the increase in reserve demand.  Unit: percent of capacity. values: 0-1. Default = 0."
    portion_of_infeed_to_reserve "Proportion of the generation of a tripping unit that needs to be covered by reserves from other units. Unit: percent of capacity. values: 0-1. Default = 0."
    offlineReserveCapability "Proportion of an offline unit which can contribute to a category of reserve. Unit: percent of capacity. values: 0-1. Default = 0."
    ReserveShareMax "Maximum reserve share of a group of units"
    LossOfTrans     "A flag to tell that N-1 reserve is needed due to a possibility that an interconnector to/from the node group fails (empty or 1)"
    up              "Upward direction, e.g. for reserve provisions"
    down            "Downward direction, e.g. for reserve provisions"
    usePrice        "A flag to decide if market link is added to reserve balance equation (empty or 1). Default = 0."
    userConstraintRHS  "Timeseries format RHS parameter for user defined generic constraints"
/

param_userconstraint "Set of names used with user constraints" /
    // LHS: variables
    v_state
    v_spill
    v_transfer
    v_transferLeftward
    v_transferRightward
    v_transferRamp
    v_investTransfer
    v_gen
*    v_genRamp
    v_genRampUp
    v_genRampDown
    v_gen_delay
    v_online
    v_startup
    v_shutdown
    v_invest
    v_reserve
    v_userconstraint
    // RHS: Timeseries
    ts_unit
    ts_influx
    ts_cf
    ts_node
    ts_gnn
    ts_reserveDemand
    ts_groupPolicy
    // RHS: Other
    constant
    // Equation types
    eq
    gt
    lt
    // Creating a new variable
    toVariable
    toVariableMultiplier
    cost
    // Methods
    eachTimestep
    sumOfTimesteps
    // penalties
    penalty
    // sft filtering
    sample
    forecast
    timestep
    effLevel
    // additional definitions for the 1st dimension of 'toVariable' parameter
    LP
    MIP
    // '-' is needed to make '-' a part of sameAs set if not given in input data. Quoted that GAMS would not confuse it to minus sign.
    '-'
/

tsCirculationRules "Set of possible circulation rules" /
    loopUntilDataLength    "Looping too short time series unit data length"  // not implemented yet
    interpolateStepChange  "Linear interpolation of the level changes between the end and the start of the time series."
/

tsCirculationParams "Set of possible circulation rules" /
    isActive  "If tsCirculation rule is applied. Default = 0 = off. 1 = on."
    length    "For hour many time steps (hours) the feature is applied."
    start     "The first timestep when tsCirculation rule is applied. Note: automatic calculation, not an input parameter."
    end       "The last timestep when tsCirculation rule is applied. Note: automatic calculation, not an input parameter."
/

* --- Efficiency Approximation Related Sets -----------------------------------

// Efficiency Approximation related Counters
op(param_unit) "Operating points in the efficiency curves, also functions as index for data points"
        /op00*op12/ // IMPORTANT! Has to equal the same param_unit!
eff(param_unit) "Effiency for the corresponding operating point ('op') in the efficiency curves, also used for data indexing"
        /eff00*eff12/ // IMPORTANT! Has to equal the same param_unit!
lambda "Lambda approximation indeces"
        /lambda01*lambda12/ // IMPORTANT! Has to equal effLambda!
hrop(param_unit) "Operating points in the incremental heat rate curves, also functions as index for data points"
        /hrop00*hrop12/ // IMPORTANT! Has to equal the same param_unit!
hr(param_unit) "Heat rate for the corresponding operating point ('hrop') in the heat rate curves, also used for data indexing"
        /hr00*hr12/ // IMPORTANT! Has to equal the same param_unit!

* --- Counters and Directional Sets -------------------------------------------

// Slack categories
slack(param_gnBoundaryTypes) "Categories for slack variables"
       / upwardSlack01*upwardSlack20, downwardSlack01*downwardSlack20 /
upwardSlack(param_gnBoundaryTypes) "Set of upward slacks"
       / upwardSlack01*upwardSlack20 /
downwardSlack(param_gnBoundaryTypes) "Set of downward slacks"
       / downwardSlack01*downwardSlack20 /

// Flags for boundaries
stateLimits(param_gnBoundaryTypes) "set of upward and downward state limits"
       / upwardLimit, downwardLimit /
spillLimits(param_gnBoundaryTypes) "set of upward and downward state limits"
       / maxSpill, minSpill /
useConstantOrTimeSeries(param_gnBoundaryProperties) "useTimeSeries and useConstant property together"
       / useTimeSeries, useConstant /

// Directional sets that are subsets of others
up_down(param_policy) "Direction set used by some variables, e.g. reserve provisions and generation ramps"
       / up, down /
availabilityLimits(param_unit) "Start and end, e.g. of unit lifetime"
       / becomeAvailable, becomeUnavailable /

; // END parameter set declarations
