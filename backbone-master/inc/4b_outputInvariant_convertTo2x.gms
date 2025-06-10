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

* --- Defining 2.x result tables ----------------------------------------------

Parameters
* --- Node Results ------------------------------------------------------------

    // State variable results, required for model structure
    r_state(grid, node, f, t) "Node state at time step t"

    // State variable slack results
    r_stateSlack(grid, node, slack, f, t) "Note state slack at time step t (MWh, unless modified by energyStoredPerUnitOfState parameter)"

    // Spill results
    r_spill(grid, node, f, t) "Spill of energy from storage node during time interval (MWh)"
    r_gnTotalSpill(grid, node) "Total spilled energy from gn over the simulation (MWh)"
    r_gTotalSpill(grid) "Total spilled energy from gn over the simulation (MWh)"
    r_gnTotalSpillShare(grid, node) "Total spilled energy gn/g share"

    // r_transfer required for model structure
    r_transfer(grid, from_node, to_node, f, t) "Energy transfer (MW)"

    // Energy transfer results
    r_transferRightward(grid, from_node, to_node, f, t) "Energy transfer from first node to second node (MW)"
    r_transferLeftward(grid, to_node, from_node, f, t) "Energy transfer from second node to first node (MW)"
    r_gnnTotalTransfer(grid, from_node, to_node) "Total amount of energy transferred between gnn over the simulation (MWh)"

    // Marginal value of energy results
    r_balanceMarginal(grid, node, f, t) "Marginal values of the q_balance equation (EUR/MWh)"
    r_balanceMarginalAverage(grid, node) "Annual average of marginal values of the q_balance equation (EUR/MWh)"
    r_gnnTransferValue(grid, from_node, to_node, f, t) "Transfer marginal value (Me) = transfer (MW) * balanceMarginal (EUR/MWh)"
    r_gnnTotalTransferValue(grid, from_node, to_node) "Total ransfer marginal value summed over the simulation (MEUR)"

    // Other node related results
    r_gnCurtailments(grid, node, f, t) "Curtailed flow generation in node (MW)"
    r_gnTotalCurtailments(grid, node) "Total curtailed flow generation in node (MWh)"
    r_gnnDiffusion(grid, from_node, to_node, f, t) "Diffusion between nodes (MW)"
    r_gnnTotalDiffusion(grid, from_node, to_node) "Total amount of energy diffused between nodes (MWh)"

* --- Energy Generation/Consumption Results -----------------------------------

    // required for model structure
    r_gen(grid, node, unit, f, t) "Energy generation for a unit (MW)"

    // Energy generation results
    r_gnuTotalGen(grid, node, unit) "Total energy generation in gnu over the simulation (MWh)"
    r_gnGen(grid, node, f, t) "energy generation for each gridnode (MW)"
    r_gnTotalGen(grid, node) "Total energy generation in gn over the simulation (MWh)"
    r_gTotalGen(grid) "Total energy generation in g over the simulation (MWh)"
    r_gnuTotalGenShare(grid, node, unit) "Total energy generation gnu/gn share"
    r_gnTotalGenShare(grid, node) "Total energy generation gn/g share"

    // Approximate utilization rates
    r_gnuUtilizationRate(grid, node, unit) "Approximate utilization rates of gnus over the simulation (p.u.)"

    // Energy generation results based on input, unittype, or group
    r_genFuel(grid, node, *, f, t) "Energy output to a node based on inputs from another node or flows (MW)"
    r_gnTotalGenFuel(grid, node, *) "Total energy generation in gn per input type over the simulation (MWh)"
    r_gTotalGenFuel(grid, *) "Total energy generation in g per input type over the simulation (MWh)"
    r_totalGenFuel(*) "Total overall energy generation per input type over the simulation (MWh)"
    r_gnTotalGenFuelShare(grid, node, *) "Total energy generation in gn per input type as a share of total energy generation in gn"
    r_genUnittype(grid, node, unittype, f, t) "Energy generation for each unittype (MW)"
    r_gnuTotalGen_unittype(grid, node, unittype) "Energy generation for each unittype in each node (MWh)"
    r_gnTotalGenGnuGroup(grid, node, group) "gnTotalGen in units that belong to gnuGroup (MWh)"

    // energy consumption results
    r_gnConsumption(grid, node, f, t) "Consumption of energy in gn for each t (MWh)"
    r_gnTotalConsumption(grid, node) "Total consumption of energy in gn over the simulation (MWh)"
    r_gTotalConsumption(grid) "Total consumption of energy in g over the simulation (MWh)"
    r_gnTotalConsumptionShare(grid, node) "Total consumption gn/g share"
    r_nuStartupConsumption(node, unit, f, t) "Energy consumption during start-up (MWh)"

* --- Unit Online, startup, and shutdown Result Symbols -----------------------

    // required for model structure
    r_online(unit, f, t) "Sub-units online"
    r_startup(unit, starttype, f, t) "Sub-units started up"
    r_shutdown(unit, f, t) "Sub-units shut down"

    // other online, startup, and shutdown results
    r_uTotalOnline(unit) "Total online sub-unit-hours of units over the simulation"
    r_uTotalOnlinePerUnit(unit) "Total unit online hours per sub-unit over the simulation"
    r_uTotalStartup(unit, starttype) "Number of sub-unit startups over the simulation"
    r_uTotalShutdown(unit) "Number of sub-unit shutdowns over the simulation"

* --- Investment Results ------------------------------------------------------

    // Invested unit count and capacity
    r_invest(unit) "Number/amount of invested sub-units"
    r_investCapacity(grid, node, unit) "Total amount of invested capacity in units (MW)"
    r_investTransfer(grid, from_node, to_node, t) "Amount of invested transfer link capacity (MW)"

* --- Emissions Results -------------------------------------------------------

    // emissions by activity type
    r_emissions(grid, node, emission, unit, f, t) "Emissions during normal operation (tEmission)"
    r_nuTotalEmissionsOperation(node, unit, emission) "node unit total emissions in normal operation (tEmission)"
    r_emissionsStartup(node, emission, unit, f, t) "Emissions from units during start-ups (tEmission)"
    r_nuTotalEmissionsStartup(node, unit, emission) "node unit total emissions in start-ups (tEmission)"
    r_emissionsCapacity(node, unit, emission) "Emissions from investments and fixed annual operation and maintenance emissions (tEmission)"

    // Emission sums
    r_emissionsNodeGroupTotal(emission, group) "Group total emissions (tEmission)"
    r_nuTotalEmissions(node, unit, emission) "node unit total emissions (tEmission)"
    r_nTotalEmissions(node, emission) "node total emissions (tEmission)"
    r_uTotalEmissions(unit, emission) "unit total emissions (tEmission)"
    r_totalEmissions(emission) "Total emissions (tEmission)"

* --- Reserve Provision Results -----------------------------------------------

    // required for model structure
    r_reserve(restype, up_down, grid, node, unit, f, t) "Unit capacity reserved for providing reserve of specific type (MW)"
    r_resTransferRightward(restype, up_down, grid, from_node, to_node, f, t) "Electricity transmission capacity from the first node to the second node reserved for providing reserves (MW)"
    r_resTransferLeftward(restype, up_down, grid, from_node, to_node, f, t) "Electricity transmission capacity from the second node to the first node reserved for providing reserves (MW)"

    // Unit level reserve results
    r_gnuTotalReserve(restype, up_down, grid, node, unit) "Total gnu reserve provision over the simulation (MW*h)"
    r_gnTotalReserve(restype, up_down, grid, node) "Total gn reserve provision over the simulation (MW*h)"
    r_groupReserve(restype, up_down, group, f, t) "Group sum of reserves of specific types (MW)"
    r_groupTotalReserve(restype, up_down, group) "Total reserve provisions in groups over the simulation (MW*h)"
    r_gnuTotalReserveShare(restype, up_down, grid, node, unit) "Total gnu/group reserve provision share over the simulation"
    r_reserve2Reserve(restype, up_down, grid, node, unit, restype, f, t) "Reserve provided for another reserve category (MW) (also included in r_reserve - this is just for debugging)"

    // Other reserve results
    r_resDemandMarginal(restype, up_down, group, f, t) "Marginal values of the q_resDemand equation"
    r_resDemandMarginalAverage(restype, up_down, group) "Annual average of marginal values of the q_resDemand equation"
    r_resDemandLargestInfeedUnit(restype, up_down, group, f, t) "Reserve Demand from the loss of largest infeed unit"
    r_gnnTotalResTransferRightward(restype, up_down, grid, from_node, to_node) "Total electricity transmission capacity from the first node to the second node reserved for providing reserves (MW*h)"
    r_gnnTotalResTransferLeftward(restype, up_down, grid, from_node, to_node) "Total electricity transmission capacity from the second node to the first node reserved for providing reserves (MW*h)"

* --- Dummy Result Symbols --------------------------------------------------

    // Results regarding solution feasibility
    r_qGen(inc_dec, grid, node, f, t) "Dummy energy generation (increase) or consumption (generation decrease) to ensure equation feasibility (MW)"
    r_gnTotalqGen(inc_dec, grid, node) "Total dummy energy generation/consumption in gn over the simulation (MWh)."
    r_gTotalqGen(inc_dec, grid) "Total dummy energy generation/consumption in g over the simulation (MWh)."
    r_qResDemand(restype, up_down, group, f, t) "Dummy to decrease demand for a reserve (MW) before reserve commitment"
    r_qResMissing(restype, up_down, group, f, t) "Dummy to decrease demand for a reserve (MW) after reserve commitment"
    r_groupTotalqResDemand(restype, up_down, group) "Total dummy reserve provisions in the group over the simulation"
    r_qCapacity(grid, node, f, t) "Dummy capacity to ensure capacity margin equation feasibility (MW)"

* --- Cost Results ------------------------------------------------------------

    // Total Objective Function
    r_totalObj(t) "Total accumulated value of the objective function over all solves"

    // Unit Cost Components
    r_gnuVOMCost(grid, node, unit, f, t) "Variable O&M costs for energy input and outputs (MEUR)"
    r_gnuTotalVOMCost(grid, node, unit) "Total gnu VOM costs over the simulation (MEUR)"
    r_uFuelEmissionCost(grid, node, unit, f, t) "Unit fuel & emission costs for normal operation (MEUR)"
    r_uTotalFuelEmissionCost(grid, node, unit) "Total unit fuel & emission costs over the simulation for normal operation (MEUR)"
    r_uStartupCost(unit, f, t) "Unit startup VOM, fuel, & emission costs (MEUR)"
    r_uTotalStartupCost(unit) "Total unit startup costs over the simulation (MEUR)"
    r_uShutdownCost(unit, f, t) "Unit startup VOM, fuel, & emission costs (MEUR)"
    r_gnuFOMCost(grid, node, unit) "Total gnu fixed O&M costs over the simulation (MEUR)"
    r_gnuUnitInvestmentCost(grid, node, unit) "Total unit investment costs over the simulation (MEUR)"

    // Transfer Link Cost Components
    r_gnnVariableTransCost(grid, node_,node, f, t) "Variable Transfer costs (MEUR)"
    r_gnnTotalVariableTransCost(grid, node_, node) "Total Variable Transfer costs over the simulation (MEUR)"
    r_gnnLinkInvestmentCost(grid, from_node, to_node) "Total transfer link investment costs over the simulation (MEUR)"

    // Nodal Cost Components
    r_gnStateSlackCost(grid, node, f, t) "Costs for states requiring slack (MEUR)"
    r_gnTotalStateSlackCost(grid, node) "Total costs for state slacks over the simulation (MEUR)"
    r_gnStorageValueChange(grid, node) "Change in storage values over the simulation (MEUR)"

    // Realized System Operating Costs
    r_gnRealizedOperatingCost(grid, node, f, t) "Realized system operating costs in gn for each t (MEUR)"
    r_gnTotalRealizedOperatingCost(grid, node) "Total realized system operating costs in gn over the simulation (MEUR)"
    r_gTotalRealizedOperatingCost(grid) "Total realized system operating costs in g over the simulation (MEUR)"
    r_totalRealizedOperatingCost "Total realized system operating costs over the simulation (MEUR)"
    r_gnTotalRealizedOperatingCostShare(grid, node) "Total realized system operating cost gn/g shares over the simulation"
    r_gnTotalRealizedNetOperatingCost(grid, node) "Total realized system operating costs in gn over the simulation, minus the increase in storage values (MEUR)"
    r_gTotalRealizedNetOperatingCost(grid) "Total realized system operating costs in g over the simulation, minus the increase in storage values (MEUR)"
    r_totalRealizedNetOperatingCost "Total realized system operating costs over the simulation (MEUR)"

    // Realized System Costs
    r_gnTotalRealizedCost(grid, node) "Total realized system costs in gn over the simulation (MEUR)"
    r_gTotalRealizedCost(grid) "Total realized system costs in g over the simulation (MEUR)"
    r_totalRealizedCost "Total realized system costs over the simulation (MEUR)"
    r_gnTotalRealizedCostShare(grid, node) "Total realized system cost gn/g shares over the simulation"
    r_gnTotalRealizedNetCost(grid, node) "Total realized system costs in gn over the simulation, minus the increase in storage values (MEUR)"
    r_gTotalRealizedNetCost(grid) "Total realized system costs in g over the simulation, minus the increase in storage values (MEUR)"
    r_totalRealizedNetCost "Total realized system costs over the simulation (MEUR)"

* --- Info and diagnostic Result Symbols --------------------------------------------------

    // Info Results
    r_solveStatus(t, solve_info) "Information about status of solves"
    // metadata written directly from metadata set
    // mSettings written directly from init file

;



loop(m,

* --- Calculating consumption results for 2.x result table support ------------
* --- Energy consumption results ---------------------------------------

    // !!! NOTE !!! This is a bit of an approximation at the moment !!!!!!!!!!!!!!!
    r_gnConsumption(gn(grid, node), ft_realizedNoReset(f, t_startp(t)))
        = p_stepLengthNoReset(t)
            * [
                + min(ts_influx(grid, node, f, t), 0) // Not necessarily a good idea, as ts_influx contains energy gains as well...
                + sum(gnu_input(grid, node, unit),
                    + r_gen_gnuft(grid, node, unit, f, t)
                    ) // END sum(gnu_input)
                ];

    // Total consumption on each gn over the simulation
    r_gnTotalConsumption(gn(grid, node))
        = sum(sft_realizedNoReset(s, f, t_startp(t)),
            + r_gnConsumption(grid, node, f, t)
                * p_msProbability(m, s)
                * p_msWeight(m, s)
            );

    // Total consumption in each grid over the simulation
    r_gTotalConsumption(grid)
        = sum(gn(grid, node), r_gnTotalConsumption(grid, node));

    // Total consumption gn/g share
    r_gnTotalConsumptionShare(gn(grid, node))${ r_gTotalConsumption(grid) <> 0 }
        = r_gnTotalConsumption(grid, node) / r_gTotalConsumption(grid);

);



* --- Converting results to 2.x -----------------------------------------------

* --- Node Result Symbols -----------------------------------------------------


Option r_state <= r_state_gnft;

// State variable slack results
Option r_stateSlack <= r_stateSlack_gnft;

// spill results
Option r_spill <= r_spill_gnft;
Option r_gnTotalSpill <= r_spill_gn;
Option r_gTotalSpill <= r_spill_g;
Option r_gnTotalSpillShare <= r_spill_gnShare;


Option r_transfer <= r_transfer_gnnft;

// Energy transfer results
Option r_transferRightward <= r_transferRightward_gnnft;
Option r_transferLeftward <= r_transferLeftward_gnnft;
Option r_gnnTotalTransfer <= r_transfer_gnn;

// Marginal value of energy results
Option r_balanceMarginal <= r_balance_marginalValue_gnft;
Option r_balanceMarginalAverage <= r_balance_marginalValue_gnAverage;
Option r_gnnTransferValue <= r_transferValue_gnnft;
Option r_gnnTotalTransferValue <= r_transferValue_gnn;

// Other node related results
Option r_gnCurtailments <= r_curtailments_gnft;
Option r_gnTotalCurtailments <= r_curtailments_gn;
Option r_gnnDiffusion <= r_diffusion_gnnft;
Option r_gnnTotalDiffusion <= r_diffusion_gnn;

* --- Energy Generation/Consumption Result Symbols ----------------------------


Option r_gen <= r_gen_gnuft;

// Energy generation results
Option r_gnuTotalGen <= r_gen_gnu;
Option r_gnGen <= r_gen_gnft;
Option r_gnTotalGen <= r_gen_gn;
Option r_gTotalGen <= r_gen_g;
Option r_gnuTotalGenShare <= r_gen_gnuShare;
Option r_gnTotalGenShare <= r_gen_gnShare;

// Approximate utilization rates
Option r_gnuUtilizationRate <= r_gen_utilizationRate_gnu;

// Energy generation results based on input, unittype, or group
Option r_genFuel <= r_genByFuel_gnft;
Option r_gnTotalGenFuel <= r_genByFuel_gn;
Option r_gTotalGenFuel <= r_genByFuel_g;
Option r_totalGenFuel <= r_genByFuel_fuel;
Option r_gnTotalGenFuelShare <= r_genByFuel_gnShare;
Option r_genUnittype <= r_genByUnittype_gnft;
Option r_gnuTotalGen_unittype <= r_genByUnittype_gn;
Option r_gnTotalGenGnuGroup <= r_genByGnuGroup_gn;

// Energy consumption results
Option r_nuStartupConsumption <= r_gen_unitStartupConsumption_nuft;

* --- Unit Online, startup, and shutdown Result Symbols ----------------------------------------


Option r_online <= r_online_uft;
Option r_startup <= r_startup_uft;
Option r_shutdown <= r_shutdown_uft;

// other online, startup, and shutdown results
Option r_uTotalOnline <= r_online_u;
Option r_uTotalOnlinePerUnit <= r_online_perUnit_u;
Option r_uTotalStartup <= r_startup_u;
Option r_uTotalShutdown <= r_shutdown_u;

* --- Investment Result Symbols -----------------------------------------------

// Invested unit count and capacity
Option r_invest <= r_invest_unitCount_u;
Option r_investCapacity <= r_invest_unitCapacity_gnu;
Option r_investTransfer <= r_invest_transferCapacity_gnn;

* --- Emissions Results -----------------------------------------------

// emissions by activity type
Option r_emissions <= r_emission_operationEmissions_gnuft;
Option r_nuTotalEmissionsOperation <= r_emission_operationEmissions_nu;
Option r_emissionsStartup <= r_emission_startupEmissions_nuft;
Option r_nuTotalEmissionsStartup <= r_emission_StartupEmissions_nu;
Option r_emissionsCapacity <= r_emission_capacityEmissions_nu;

// Emission sum results
Option r_emissionsNodeGroupTotal <= r_emissionByNodeGroup;
Option r_nuTotalEmissions <= r_emission_nu;
Option r_nTotalEmissions <= r_emission_n;
Option r_uTotalEmissions <= r_emission_u;
Option r_totalEmissions <= r_emission;

* --- Reserve Result Symbols ----------------------------------------


Option r_reserve <= r_reserve_gnuft;
Option r_resTransferRightward <= r_reserveTransferRightward_gnnft;
Option r_resTransferLeftward <= r_reserveTransferLeftward_gnnft;

// Unit level reserve results
Option r_gnuTotalReserve <= r_reserve_gnu;
Option r_gnTotalReserve <= r_reserve_gn;
Option r_groupReserve <= r_reserveByGroup_ft;
Option r_groupTotalReserve <= r_reserveByGroup;
Option r_gnuTotalReserveShare <= r_reserve_gnuShare;
Option r_reserve2Reserve <= r_reserve2Reserve_gnuft;

// Other reserve results
Option r_resDemandMarginal <= r_reserve_marginalValue_ft;
Option r_resDemandMarginalAverage <= r_reserve_marginalValue_average;
Option r_resDemandLargestInfeedUnit <= r_reserveDemand_largestInfeedUnit_ft;
Option r_gnnTotalResTransferRightward <= r_reserveTransferRightward_gnn;
Option r_gnnTotalResTransferLeftward <= r_reserveTransferLeftward_gnn;

* --- Dummy Result Symbols ------------------------------------------

// Results regarding solution feasibility
Option r_qGen <= r_qGen_gnft;
Option r_gnTotalqGen <= r_qGen_gn;
Option r_gTotalqGen <= r_qGen_g;
Option r_qResDemand <= r_qReserveDemand_ft;
Option r_qResMissing <= r_qReserveMissing_ft;
Option r_groupTotalqResDemand <= r_qReserveDemand;
Option r_qCapacity <= r_qCapacity_ft;

* --- Cost Result Symbols -----------------------------------------------------

// Total Objective Function
Option r_totalObj <= r_cost_objectiveFunction_t;

// Unit Cost Components
Option r_gnuVOMCost <= r_cost_unitVOMCost_gnuft;
Option r_gnuTotalVOMCost <= r_cost_unitVOMCost_gnu;
Option r_uFuelEmissionCost <= r_cost_unitFuelEmissionCost_gnuft;
Option r_uTotalFuelEmissionCost <= r_cost_unitFuelEmissionCost_u;
Option r_uStartupCost <= r_cost_unitStartupCost_uft;
Option r_uTotalStartupCost <= r_cost_unitStartupCost_u;
*r_cost_unitShutdownCost_uft
Option r_gnuFOMCost <= r_cost_unitFOMCost_gnu;
Option r_gnuUnitInvestmentCost <= r_cost_unitInvestmentCost_gnu;

// Transfer Link Cost Components
Option r_gnnVariableTransCost <= r_cost_linkVOMCost_gnnft;
Option r_gnnTotalVariableTransCost <= r_cost_linkVOMCost_gnn;
Option r_gnnLinkInvestmentCost <= r_cost_linkInvestmentCost_gnn;

// Nodal Cost Components
Option r_gnStateSlackCost <= r_cost_stateSlackCost_gnt;
Option r_gnTotalStateSlackCost <= r_cost_stateSlackCost_gn;
Option r_gnStorageValueChange <= r_cost_storageValueChange_gn;

// Realized System Operating Costs
Option r_gnRealizedOperatingCost <= r_cost_realizedOperatingCost_gnft;
Option r_gnTotalRealizedOperatingCost <= r_cost_realizedOperatingCost_gn;
Option r_gTotalRealizedOperatingCost <= r_cost_realizedOperatingCost_g;
r_totalRealizedOperatingCost = r_cost_realizedOperatingCost;  // Dimensionless
Option r_gnTotalRealizedOperatingCostShare <= r_cost_realizedOperatingCost_gnShare;
Option r_gnTotalRealizedNetOperatingCost <= r_cost_realizedNetOperatingCost_gn;
Option r_gTotalRealizedNetOperatingCost <= r_cost_realizedNetOperatingCost_g;
r_totalRealizedNetOperatingCost = r_cost_realizedNetOperatingCost;  // Dimensionless

// Realized System Costs
Option r_gnTotalRealizedCost <= r_cost_realizedCost_gn;
Option r_gTotalRealizedCost <= r_cost_realizedCost_g;
r_totalRealizedCost = r_cost_realizedCost;  // Dimensionless
Option r_gnTotalRealizedCostShare <= r_cost_realizedCost_gnShare;
Option r_gnTotalRealizedNetCost <= r_cost_realizedNetCost_gn;
Option r_gTotalRealizedNetCost <= r_cost_realizedNetCost_g;
r_totalRealizedNetCost = r_cost_realizedNetCost;  // Dimensionless

* --- info, and Diagnostic Result Symbols ----------------------------

// Info results
Option r_solveStatus <= r_info_solveStatus;






