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

*============================================================================
*----------Define sets and parameters for import-----------------------------
*============================================================================
Sets
    grid                                          "Forms of energy endogenously presented in the model"
    node                                          "Nodes maintain the energy balance or track exogenous commodities"
    emission                                      "Emissions"
    fuel                                          "Fuels"
    flow                                          "Flow based energy resources (time series)"
    unit                                          "Set of generators, storages and loads"
    group                                         "A group of units, transfer links, nodes, etc."
    restype                                       "Reserve types"
    unittype                                      "Unit technology types"

    restypeDirection(*, *)                        "Different combinations of reserve types and directions"
    restypeReleasedForRealization(*)              "Reserve types that are released for the realized time intervals"
    flowUnit(*, *)                                "Units or storages linked to a certain energy flow time series"
    gn2nGroup(*,*,*,*)                            "Transfer links in particular groups"
    gnGroup(*,*,*)                                "Combination of grids and nodes in particular groups"
    gngnu_constrainedOutputRatio(*,*,*,*,*)       "Units with a constrained ratio between two different grids of output (e.g. extraction)"
    gngnu_fixedOutputRatio(*,*,*,*,*)             "Units with a fixed ratio between two different grids of output (e.g. backpressure)"
    gnss_bound(*,*, *, *)                         "Bound the samples so that the node state at the last interval of the first sample equals the state at the first interval of the second sample"
    gnuGroup(*,*,*,*)                             "Combination of grids, nodes and units in particular groups"
    unitUnittype(*,*)                             "Link generation technologies to types"
    t_invest(*)                                   "Time steps when investments can be made"
    uGroup(*,*)                                   "Units in particular groups"
    uFuel(*,*,*)                                  "Units linked with fuels"
    effLevelGroupUnit(*,*,*)                      "What efficiency selectors are in use for each unit at each efficiency representation level"
    unitUnitEffLevel(*,*,*)                       "Aggregator unit linke to aggreted units with a definition when to start the aggregation"
    unit_fail(*)                                  "Units that might fail"
    uss_bound(*, *, *)                            "Bound the samples so that the unit online state at the last interval of the first sample equals the state at the first interval of the second sample"
    s_countries                               "(KT) countries of subset_countries.csv"
    s_regions                                 "(KT) regions of subset_countries.csv"
    steam_subset_countries(*,*)                   "(KT) subset_countries.csv resulting in the regional configuration"
    s_scenario                                "(KT) scenario of scenario.csv"
    s_alternative                             "(KT) alternatives of scenario.csv"
    steam_scenarioAlternative(*,*)                "(KT) scenarios.csv displaying the chosen scenario configuration"
    s_regional_WACC_avg                             "(KT) technological and regional average of the WACC"
    steam_WACC(*,*)                               "(KT) assigning the average WACC to each region"
    s_shipping_index                                "(KT) Index assigned to shipping routes points from start to finish"
    s_shipping_route                          "(KT) Shipping routes with origin and destination seperated by '___'"
    s_config_parameter                              "(KT) part of Steam model config"
    s_config_object                                 "(KT) part of Steam model config"
    s_config_value                                  "(KT) part of Steam model config"
    s_config_alternative                            "(KT) part of Steam model config"
    s_config_info                                   "(KT) part of Steam model config"
    steam_model_config(*,*,*,*,*)                 "(KT) Steam model config sheet of MainInput.xlsx"
    s_node                                   "(OL) data for transport visualization"
    s_pipeline                                   "(OL) data for transport visualization"
    s_terminal                                   "(OL) data for transport visualization"
    s_terminal_connection                                   "(OL) data for transport visualization"
    s_shipping                                   "(OL) data for transport visualization"
    //s_regions_n                                   "(OL) data for transport visualization"
    //s_alternative_n                               "(OL) data for transport visualization"
    //s_x_n                                         "(OL) data for transport visualization"
    //s_y_n                                         "(OL) data for transport visualization"
    //s_geometry_n                                  "(OL) data for transport visualization"
    //s_list_of_countries_n                         "(OL) data for transport visualization"
    //s_WACC_n                                      "(OL) data for transport visualization"
    //steam_geo_nodes(*,*,*,*,*,*,*)            "(OL) data for transport visualization"
    //steam_geo_pipelines(*,*,*,*,*,*)            "(OL) data for transport visualization"
    //steam_geo_terminals(*,*,*,*,*,*,*,*,*,*,*)      "(OL) data for transport visualization"
    //steam_geo_terminals_con(*,*,*,*,*,*)        "(OL) data for transport visualization"
    //steam_geo_shipping(*,*,*,*,*)               "(OL) data for transport visualization"

;
Parameters
    p_fuelEmission(*,*)                           "Fuel emission content"
    p_gn(*,*,*)                                   "Properties for energy nodes"
    p_gnBoundaryPropertiesForStates(*,*,*,*)      "Properties of different state boundaries and limits"
    p_gnPolicy(*,*,*,*)                           "Policy data for grid, node"
    p_gnn(*,*,*,*)                                "Data for interconnections between energy nodes"
    p_gnu(*,*,*,*)                                "Unit data where energy type matters"
    p_gnuBoundaryProperties(*,*,*,*,*)            "Properties for unit boundaries where energy type matters"
    p_groupPolicy(*,*)                            "Two-dimensional policy data for groups"
    p_groupPolicy3D(*,*,*)                        "Three-dimensional policy data for groups"
    p_nReserves(*,*,*)                            "Data defining the reserve rules in each node"
    p_nuReserves(*,*,*,*)                         "Reserve provision data for units"
    p_nnReserves(*,*,*,*)                         "Reserve provision data for node node connections"
    p_nuRes2Res(*,*,*,*,*)                        "The first type of reserve can be used also in the second reserve category (with a possible multiplier)"
    p_storageValue(*,*,*)                         "Value of stored something at the end of a time step"
    p_uFuel(*,*,*,*)                              "Parameters interacting between units and fuels"
    p_unit(*,*)                                   "Unit data where energy type does not matter"
    ts_cf(*,*,*,*)                                "Available capacity factor time series (p.u.)"
    ts_fuelPriceChange(*,*)                       "Initial fuel price and consequent changes in fuel price (EUR/MWh)"
    ts_influx(*,*,*,*)                            "External power inflow/outflow during a time step (MWh/h)"
    ts_node(*,*,*,*,*)                            "Fix the states of a node according to time series form exogenous input ([v_state])"
    ts_reserveDemand(*,*,*,*,*)                   "Mean reserve demand in region in the time step (MW)"
    ts_unit(*,*,*,*)                              "Time dependent unit data, where energy type doesn't matter"
;

Sets
    restype_inertia(*)                            "Reserve types where the requirement can also be fulfilled with the inertia of synchronous machines"
    sGroup(*,*)                                   "Samples in particular groups"
    utAvailabilityLimits(*,*,*)                   "Time step when the unit becomes available/unavailable, e.g. because of technical lifetime"
;

Parameters
    p_groupReserves(*,*,*)                        "Data defining the reserve rules in each node group"
    p_groupReserves3D(*,*,*,*)                    "Reserve policy in each node group separately for each reserve type and direction"
    p_groupReserves4D(*,*,*,*,*)                  "Reserve policy in each node group separately for each reserve type and direction, also linking to another group"
    p_gnuReserves(*,*,*,*,*)                      "Reserve provision data for units"
    p_gnnReserves(*,*,*,*,*)                      "Reserve provision data for node node connections"
    p_gnuRes2Res(*,*,*,*,*,*)                     "The first type of reserve can be used also in the second reserve category (with a possible multiplier)"
    p_s_discountFactor(*)                         "Discount factor for samples when using a multi-year horizon"
    ts_storageValue(*,*,*,*)                      "Mean value of ts_storageValue"
;
*============================================================================
*----------Import data from .gdx---------------------------------------------
*============================================================================

$Gdxin 'conversion/%input_name%.gdx'
$loaddcm grid
$loaddc  node
$loaddc  emission
$loaddc  fuel
$loaddc  flow
$loaddc  unit
$loaddc  group
$loaddc  restype
$loaddc  unittype
$loaddc  restypeDirection
$loaddc  restypeReleasedForRealization
$loaddc  flowUnit
$loaddc  gn2nGroup
$loaddc  gnGroup
$loaddc  gngnu_constrainedOutputRatio
$loaddc  gngnu_fixedOutputRatio
$loaddc  gnss_bound
$loaddc  gnuGroup
$loaddc  unitUnittype
$loaddc  t_invest
$loaddc  uGroup
$loaddc  uFuel
$loaddc  effLevelGroupUnit
$loaddc  unitUnitEffLevel
$loaddc  unit_fail
$loaddc  uss_bound
$loaddc  p_fuelEmission
$loaddc  p_gn
$loaddc  p_gnBoundaryPropertiesForStates
*$loaddc  p_gnPolicy
$loaddc  p_gnn
$loaddc  p_gnu
$loaddc  p_gnuBoundaryProperties
$loaddc  p_groupPolicy
$loaddc  p_groupPolicy3D
$loaddc  p_nReserves
$loaddc  p_nuReserves
$loaddc  p_nnReserves
$loaddc  p_nuRes2Res
$loaddc  p_storageValue
$loaddc  p_uFuel
$loaddc  p_unit
$loaddc  ts_cf
$loaddc  ts_fuelPriceChange
$loaddc  ts_influx
$loaddc  ts_node
$loaddc  ts_reserveDemand
$loaddc  ts_unit
$loaddc  s_countries
$loaddc  s_regions
$loaddc  steam_subset_countries
$loaddc  s_scenario
$loaddc  s_alternative
$loaddc  steam_scenarioAlternative
$loaddc  s_regional_WACC_avg
$loaddc  steam_WACC
$loaddc  s_config_parameter
$loaddc  s_config_object
$loaddc  s_config_value
$loaddc  s_config_alternative
$loaddc  s_config_info
$loaddc  steam_model_config
$loaddc  s_node
$loaddc  s_terminal
$loaddc  s_pipeline
$loaddc  s_terminal_connection
$loaddc  s_shipping
* $loaddc  s_regions_n
* $loaddc  s_alternative_n
* $loaddc  s_x_n
* $loaddc  s_y_n
* $loaddc  s_geometry_n
* $loaddc  s_list_of_countries_n
* $loaddc  s_WACC_n
* $loaddc  steam_geo_nodes
* $loaddc  s_name_p
* $loaddc  s_h2_node1_p
* $loaddc  s_h2_node2_p
* $loaddc  s_commodity_p
* $loaddc  s_alternative_p
* $loaddc  s_geometry_p
* $loaddc  steam_geo_pipelines
* $loaddc  s_terminal_name_t
* $loaddc  s_node_t
* $loaddc  s_commodity_t
* $loaddc  s_con_terminal_name_t
* $loaddc  s_unit_name_trans_t
* $loaddc  s_unit_name_retrans_t
* $loaddc  s_region_t
* $loaddc  s_alternative_t
* $loaddc  s_y_t
* $loaddc  s_x_t
* $loaddc  s_geometry_t
* $loaddc  steam_geo_terminals
* $loaddc  s_terminal_name_tc
* $loaddc  s_Regions_tc
* $loaddc  s_node1_tc
* $loaddc  s_node2_tc
* $loaddc  s_alternative_tc
* $loaddc  s_geometry_tc
* $loaddc  steam_geo_terminals_con
* $loaddc  s_name_s
* $loaddc  s_origin_s
* $loaddc  s_destination_s
* $loaddc  s_alternative_s
* $loaddc  s_geometry_s
* $loaddc  steam_geo_shipping

*============================================================================
*----------Necessary or intermediary sets and parameters---------------------
*============================================================================
Sets
     input_output                            "Designating nodes as either inputs or outputs"
     / input, output /
     param_gnu                               "Set of possible data parameters for grid, node, unit" /
         capacity                            "Maximum capacity (MW)"
         conversionCoeff                     "Coefficient for conversion equation (multiplies each input or output when summing v_gen from multiple inputs/outputs)"
         useInitialGeneration                "A flag to indicate whether to fix generation for the first time step (binary)"
         initialGeneration                   "Initial generation/consumption of the unit in the first time step (MW)"
         maxRampUp                           "Speed to ramp up (p.u./min)"
         maxRampDown                         "Speed to ramp down (p.u./min)"
         upperLimitCapacityRatio             "Ratio of the upper limit of the node state and the unit capacity investment ([v_state]/MW)"
         unitSize                            "Input/Output capacity of one subunit for integer investments (MW)"
         invCosts                            "Investment costs (EUR/MW)"
         annuity                             "Investment annuity factor"
         fomCosts                            "Fixed operation and maintenance costs (EUR/MW/a)"
         vomCosts                            "Variable operation and maintenance costs (EUR/MWh)"
         inertia                             "Inertia of the unit (s)"
         unitSizeMVA                         "Generator MVA rating of one subunit (MVA)"
         availabilityCapacityMargin          "Availability of the unit in the capacity margin equation (p.u.). If zero, v_gen is used. Currently used only for output capacity."
     /
     param_gn                                "Possible parameters for grid, node" /
           nodeBalance                       "A flag to decide whether node balance constraint is to be used"
           selfDischargeLoss                 "Self discharge rate of the node (MW/[v_state])"
           energyStoredPerUnitOfState        "A possible unit conversion if v_state uses something else than MWh (MWh/[v_state])"
           boundStart                        "A flag to bound the first t in the run using reference constant or time series"
           boundStartAndEnd                  "A flag that both start and end are bound using reference constant or time series"
           boundEnd                          "A flag to bound last t in each solve based on the reference constant or time series"
           boundAll                          "A flag to bound the state to the reference in all time steps"
           boundStartToEnd                   "Force the last states to equal the first state"
           capacityMargin                    "Capacity margin used in invest mode (MW)"
           storageValueUseTimeSeries         "A flag to determine whether to use time series form `storageValue`"
     /
     param_fuel                              "Parameters for fuels" /
           main                              "Main fuel of the unit - unless input fuels defined as grids"
           startup                           "Startup fuel of the unit, if exists. Can be the same as main fuel - consumption using startupFuelCons"
     /
     param_unit                              "Set of possible data parameters for units" /
         unitCount                           "Number of subunits if aggregated"
         outputCapacityTotal                 "Output capacity of the unit, calculated by summing all the outputs together by default, unless defined in data"
         unitOutputCapacityTotal             "Output capacity of the unit, calculated by summing all the subunit output sizes together by default"
         availability                        "Availability of given energy conversion technology (p.u.)"
         useInitialOnlineStatus              "A flag to fix the online status of a unit for the first time step (binary)"
         initialOnlineStatus                 "Initial online status of the unit in the first time step (0-1)"
         startCostCold                       "Variable start-up costs for cold starts excluding fuel costs (EUR/MW)"
         startCostWarm                       "Variable start-up costs for warm starts excluding fuel costs (EUR/MW)"
         startCostHot                        "Variable start-up costs for hot starts excluding fuel costs (EUR/MW)"
         startFuelConsCold                   "Consumption of start-up fuel per cold subunit started up (MWh_fuel/MW)"
         startFuelConsWarm                   "Consumption of start-up fuel per warm subunit started up (MWh_fuel/MW)"
         startFuelConsHot                    "Consumption of start-up fuel per hot subunit started up (MWh_fuel/MW)"
         startColdAfterXhours                "Offline hours after which the start-up will be a cold start (h)"
         startWarmAfterXhours                "Offline hours after which the start-up will be a warm start (h)"
         shutdownCost                        "Cost of shutting down the unit"
         rampSpeedToMinLoad                  "Ramping speed from start-up to minimum load (p.u./min)"
         rampSpeedFromMinLoad                "Ramping speed from shutdown decision to zero load (p.u./min)"
         minOperationHours                   "Minimum operation time (h), prevents shutdown after startup until the defined amount of time has passed"
         minShutdownHours                    "Minimum shut down time (h), prevents starting up again after the defined amount of time has passed"
         eff00 * eff12                       "Efficiency of the unit to convert input to output/intermediate product"
         opFirstCross                        "The operating point where the real efficiency curve and approximated efficiency curve cross"
         op00 * op12                         "Right border of the efficiency point"
         hr00 * hr12                         "Incremental heat rates (GJ/MWh)"
         hrop00 * hrop12                     "Right border of the incremental heat rates"
         section                             "Possibility to define a no load fuel use for units with zero minimum output"
         hrsection                           "no load fuel use to be defined when using incremental heat rates"
         level1 * level9                     "Level of simplification in the part-load efficiency representation"
         useTimeseries                       "A flag to use time series form input for unit parameters whenever possible"
         investMIP                           "A flag to make integer investment instead of continous investment"
         maxUnitCount                        "Maximum number of units when making integer investments"
         minUnitCount                        "Minimum number of units when making integer investments"
         lastStepNotAggregated               "Last time step when the unit is not yet aggregated - calculated in inputsLoop.gms for units that have aggregation"
         becomeAvailable                     "The relative position of the time step when the unit becomes available (calculated from ut(unit, t, start_end))"
         becomeUnavailable                   "The relative position of the time step when the unit becomes unavailable (calculated from ut(unit, t, start_end))"
     /

    commodity(*)                             "Commodities that can be bought or sold exogenous to model"
       / set.fuel /
    grid_2                                   "New grid"
       / set.grid, fuel /
    node_2                                   "New node"
       / set.node, set.fuel /
;

alias(node,node_);
alias(grid,grid_);

Parameters
     p_gnu_io(*,*,*,*,*)                     "Unit data where energy type matters"
     p_uStartupfuel(*,*,*)                   "Parameters for startup fuels"
     p_gn_2(*,*,*)                           "New p_gn"
     p_unit_2(*,*)                           "New p_unit"
     p_gnPolicy(*,*,*,*)                     "Emission tax"
     p_unitConstraint(*,*)                   "Unit fixed constraint"
     p_unitConstraintNode(*,*,*)             "Unit node Constraint"
     p_gngnuf(*,*,*,*,*)                     "Extra Table for gngnu_fixed domain"
     p_gngnuc(*,*,*,*,*)                     "Extra Table for gngnu_constrained domain"
;
*============================================================================
*----------Transformation----------------------------------------------------
*============================================================================

* Making Copy of p_gn (Eps set for fuels so that fuels included into table
*----------------------------------------------------------------------------
p_gn_2(grid,node,param_gn)
     = p_gn(grid,node,param_gn);
p_gn_2(grid,node,'nodeBalance')
     $(p_gn_2(grid,node,'energyStoredPerUnitOfState')) = YES;
p_gn_2('fuel',commodity,'selfDischargeLoss') = Eps;

* Making copy of p_unit
*----------------------------------------------------------------------------
p_unit_2(unit,param_unit)
     = p_unit(unit,param_unit);

* Emission cost must be created here
*----------------------------------------------------------------------------
p_gnPolicy('fuel',commodity,'emissionTax','CO2')
     $(p_fuelEmission(commodity,'CO2')>0) = 30;

* p_gnu_io: setting conversionCoeff to 1 for fuels (commodities)
*----------------------------------------------------------------------------
p_gnu_io('fuel',commodity,unit,'input','conversionCoeff')
     $(p_uFuel(unit,'main',commodity,'maxFuelCons')>0) = 1;

* p_gnu_io: Setting capacity from maxCons and maxGen
*----------------------------------------------------------------------------
p_gnu_io(grid,node,unit,'input','capacity')
     = p_gnu(grid,node,unit,'maxCons');
p_gnu_io(grid,node,unit,'output','capacity')
     = p_gnu(grid,node,unit,'maxGen');

* p_gnu_io: setting conversioCoeff to 1 for non-fuel inputs and outputs
*----------------------------------------------------------------------------
p_gnu_io(grid,node,unit,'input','conversionCoeff')
     $(p_gnu(grid,node,unit,'maxCons')>0) = 1;
p_gnu_io(grid,node,unit,'output','conversionCoeff')
     $(p_gnu(grid,node,unit,'maxGen')>0) = 1;
p_gnu_io(grid,node,unit,'output','vomCosts')
     $(p_gnu(grid,node,unit,'maxGen')>0)
     = p_unit(unit,'omCosts');

*p_gnu_io: fixing unitsize and unitsizegen
*----------------------------------------------------------------------------
p_gnu_io(grid,node,unit,'input','unitsize')
     = p_gnu(grid,node,unit,'unitSizeCons');
p_gnu_io(grid,node,unit,'output','unitsize')
     = p_gnu(grid,node,unit,'unitSizeGen');

* Extraction of p_uStartupfuel
*----------------------------------------------------------------------------
p_uStartupfuel(unit,commodity,'fixedFuelFraction')
     = p_uFuel(unit,'startup',commodity,'fixedFuelFraction');

* Creating intermediate tables for gngnu-sets and setting value to 1
*----------------------------------------------------------------------------
p_gngnuf(gngnu_fixedOutputRatio(grid,node,grid_,node_,unit))=1;
p_gngnuc(gngnu_constrainedOutputRatio(grid,node,grid_,node_,unit))=1;

* Creating p_unitConstraint and setting to Eps
*----------------------------------------------------------------------------
p_unitConstraint(unit,'eq1')
     = sum((grid,node,grid_,node_),p_gngnuf(grid,node,grid_,node_,unit))*Eps;
p_unitConstraint(unit,'gt1')
     = sum((grid,node,grid_,node_),p_gngnuc(grid,node,grid_,node_,unit))*Eps;

* Setting p_unitConstraint LHS to (+1) and RHS to (-1)
*----------------------------------------------------------------------------
p_unitConstraintNode(unit,'eq1',node)
     = sum((grid,grid_,node_),p_gngnuf(grid,node,grid_,node_,unit))
      -sum((grid,node_,grid_),p_gngnuf(grid,node_,grid_,node,unit));
p_unitConstraintNode(unit,'gt1',node)
     = -sum((grid,grid_,node_),p_gngnuc(grid,node,grid_,node_,unit))
       +sum((grid,node_,grid_),p_gngnuc(grid,node_,grid_,node,unit));

* Getting conversionFactors to p_unitConstraintNode
*----------------------------------------------------------------------------
p_unitConstraintNode(unit,'eq1',node)
     = (p_unitConstraintNode(unit,'eq1',node)
       /(sum(grid,p_gnu(grid,node,unit,'conversionFactor'))))
       $(sum(grid,p_gnu(grid,node,unit,'conversionFactor'))<>0);
p_unitConstraintNode(unit,'gt1',node)
     = (p_unitConstraintNode(unit,'gt1',node)
       /(sum(grid,p_gnu(grid,node,unit,'conversionFactor'))))
       $(sum(grid,p_gnu(grid,node,unit,'conversionFactor'))<>0);

*============================================================================
*----------Export to gdx-----------------------------------------------------
*============================================================================
execute_unload 'conversion/%output_name%.gdx', grid_2=grid
                                               node_2=node
                                               flow
                                               unittype
                                               unit
                                               unitUnittype
                                               unit_fail
                                               commodity
                                               unitUnitEffLevel
                                               effLevelGroupUnit
                                               group
                                               p_gn_2=p_gn
                                               p_gnn
                                               p_gnu_io
                                               p_gnuBoundaryProperties
                                               p_unit_2=p_unit
                                               ts_unit
                                               p_unitConstraint
                                               p_unitConstraintNode
                                               restype
                                               restypeDirection
                                               restypeReleasedForRealization
                                               restype_inertia
                                               p_groupReserves
                                               p_groupReserves3D
                                               p_groupReserves4D
                                               p_gnuReserves
                                               p_gnnReserves
                                               p_gnuRes2Res
                                               ts_reserveDemand
                                               p_gnBoundaryPropertiesForStates
                                               p_gnPolicy
                                               p_uStartupfuel
                                               flowUnit
                                               emission
                                               p_fuelEmission=p_nEmission
                                               ts_cf
                                               ts_fuelPriceChange=ts_priceChange
                                               ts_influx
                                               ts_node
                                               p_s_discountFactor
                                               t_invest
                                               utAvailabilityLimits
                                               p_storageValue
                                               ts_storageValue
                                               uGroup
                                               gnuGroup
                                               gn2nGroup
                                               gnGroup
                                               sGroup
                                               p_groupPolicy
                                               p_groupPolicy3D
                                               gnss_bound
                                               uss_bound
                                               s_countries
                                               s_regions
                                               steam_subset_countries
                                               s_scenario
                                               s_alternative
                                               steam_scenarioAlternative
                                               steam_WACC
                                               s_config_parameter
                                               s_config_object
                                               s_config_value
                                               s_config_alternative
                                               s_config_info
                                               steam_model_config
                                               s_node
                                               s_pipeline
                                               s_terminal
                                               s_terminal_connection
                                               s_shipping
                                               //s_regions_n
                                               //s_alternative_n
                                               //s_x_n
                                               //s_y_n
                                               //s_geometry_n
                                               //s_list_of_countries_n
                                               //s_WACC_n
                                               //steam_geo_nodes
                                               //s_name_p
                                               //s_h2_node1_p
                                               //s_h2_node2_p
                                               //s_commodity_p
                                               //s_alternative_p
                                               //s_geometry_p
                                               //steam_geo_pipelines
                                               //s_terminal_name_t
                                               //s_node_t
                                               //s_commodity_t
                                               //s_con_terminal_name_t
                                               //s_unit_name_trans_t
                                               //s_unit_name_retrans_t
                                               //s_region_t
                                               //s_alternative_t
                                               //s_y_t
                                               //s_x_t
                                               //s_geometry_t
                                               //steam_geo_terminals
                                               //s_terminal_name_tc
                                               //s_Regions_tc
                                               //s_node1_tc
                                               //s_node2_tc
                                               //s_alternative_tc
                                               //s_geometry_tc
                                               //steam_geo_terminals_con
                                               //s_name_s
                                               //s_origin_s
                                               //s_destination_s
                                               //s_alternative_s
                                               //s_geometry_s
                                               //steam_geo_shipping
                                               ;
*============================================================================
*----------END-----------------------------------------------------
*============================================================================

