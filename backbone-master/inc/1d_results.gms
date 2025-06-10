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
* --- Model Results Arrays ----------------------------------------------------
* =============================================================================

Parameters

* --- Node Results ------------------------------------------------------------

    // required for model structure
    r_state_gnft(grid, node, f, t) "Node state at time step t"
    r_state_gnsft(grid, node, s, f, t) "Node state at time step t with sample dimension"

    // change in the storage state over the simulation
    r_stateChange_gn(grid, node) "Change in node state from the first t to the last t (MWh)"
    r_stateChangeValue_gn(grid, node) "Node average marginal value multiplied by the change in node state from the first t to the last t (MEUR)"
    r_stateChangeValue "Total value of state changes from the first t to the last t (MEUR)" / 0 /

    // State variable slack results
    r_stateSlack_gnft(slack, grid, node, f, t) "Node state slack at time step t (MWh, unless modified by energyStoredPerUnitOfState parameter)"
    r_stateSlack_gn(slack, grid, node) "Total node state slack (MWh, unless modified by energyStoredPerUnitOfState parameter)"

    // Full load cycles of storages
    r_state_fullCycles_gn(grid, node, input_output) "Calculated full load cycles of storages. Sum of unit input or output / storage capacity. Ignoring losses, influx, etc."

    // Spill results
    r_spill_gnft(grid, node, f, t) "Spill of energy from storage node during time interval (MWh)"
    r_spill_gn(grid, node) "Total spilled energy from gn over the simulation (MWh)"
    r_spill_g(grid) "Total spilled energy from gn over the simulation (MWh)"
    r_spill_gnShare(grid, node) "Total spilled energy gn/g share"

    // required for model structure
    r_transfer_gnnft(grid, from_node, to_node, f, t) "Energy transfer (MWh/h)"

    // Energy transfer results
    r_transferRightward_gnnft(grid, from_node, to_node, f, t) "Energy transfer from first node to second node (MW)"
    r_transferLeftward_gnnft(grid, to_node, from_node, f, t) "Energy transfer from second node to first node (MW)"
    r_transfer_gnn(grid, from_node, to_node) "Total amount of energy transferred between gnn over the simulation (MWh)"

    // Marginal value of energy results
    r_balance_marginalValue_gnft(grid, node, f, t) "Marginal values of the q_balance equation (EUR/MWh)"
    r_balance_marginalValue_gnAverage(grid, node) "Average of marginal values of the q_balance equation (EUR/MWh)"

    // Other node related results
    r_curtailments_gnft(grid, node, f, t) "Curtailed flow generation in node (MWh/h)"
    r_curtailments_gn(grid, node) "Total curtailed flow generation in node (MWh)"
    r_diffusion_gnnft(grid, node, node_, f, t) "Diffusion between nodes (MWh/h)"
    r_diffusion_gnn(grid, node, node_) "Total amount of energy diffused between nodes (MWh)"

* --- Energy Generation/Consumption Results -----------------------------------

    // required for model structure
    r_gen_gnuft(grid, node, unit, f, t) "Energy generation for a unit (MWh/h)"

    // Energy generation results
    r_gen_gnu(grid, node, unit) "Total energy generation and consumption in gnu over the simulation (MWh)"
    r_gen_gnft(grid, node, f, t) "energy generation and consumption for each gridnode (MWh/h)"
    r_gen_gn(grid, node) "Total energy generation and consumption in gn over the simulation (MWh)"
    r_gen_g(grid) "Total energy generation and consumption in g over the simulation (MWh)"
    r_gen_gnuShare(grid, node, unit) "Total energy generation and consumption gnu/gn share"
    r_gen_gnShare(grid, node) "Total energy generation and consumption gn/g share"

    // generation ramp results
    r_genRamp_gnuft(grid, node, unit, f, t) "Ramp of units that have active ramp constraints or ramp costs (MW/h)"

    // Approximate utilization rates
    r_gen_utilizationRate_gnu(grid, node, unit) "Approximate utilization rates of gnus over the simulation. Unit: percent of capacity. values: 0-1."

    // delayed generation
    r_gen_delay_gnuft(grid, node, unit, f, t_) "Unit energy generation after delays have been accounted (MWh/h)"

    // Energy generation results based on input, unittype, or group
    r_genByFuel_gnft(grid, node, *, f, t) "Energy generation to a node based on inputs from another node or flows (MWh/h). Excludes consumption from node."
    r_genByFuel_gn(grid, node, *) "Total energy generation in gn per input type over the simulation (MWh). Excludes consumption from node."
    r_genByFuel_g(grid, *) "Total energy generation in g per input type over the simulation (MWh). Excludes consumption from node."
    r_genByFuel_fuel(*) "Total overall energy generation per input type over the simulation (MWh). Excludes consumption from node."
    r_genByFuel_gnShare(grid, node, *) "Total energy generation in gn per input type as a share of total energy generation in gn. Excludes consumption from node."
    r_genByUnittype_gnft(grid, node, unittype, f, t) "Energy generation and consumption for each unittype (MWh/h)"
    r_genByUnittype_gn(grid, node, unittype) "Energy generation and consumption for each unittype in each node (MWh)"
    r_genByUnittype_g(grid, unittype) "Energy generation and consumption for each unittype in each grid (MWh)"
    r_genByGnuGroup_gn(grid, node, group) "Total energy generation and consumption in units that belong to gnuGroup (MWh)"

    // Energy consumption during startups
    r_gen_unitStartupConsumption_nuft(node, unit, f, t) "Energy consumption during start-up (MWh)"
    r_gen_unitStartupConsumption_nu(node, unit) "Sum of energy consumption during start-ups (MWh)"

* --- Unit Online, startup, and shutdown Result Symbols ------------------

    // required for model structure
    r_online_uft(unit, f, t) "Sub-units online"
    r_startup_uft(starttype, unit, f, t) "Sub-units started up"
    r_shutdown_uft(unit, f, t) "Sub-units shut down"

    // other online, startup, and shutdown results
    r_online_u(unit) "Total online sub-unit-hours of units over the simulation"
    r_online_perUnit_u(unit) "Total unit online hours per sub-unit over the simulation"
    r_startup_u(unit, starttype) "Number of sub-unit startups over the simulation"
    r_shutdown_u(unit) "Number of sub-unit shutdowns over the simulation"


* --- Investment Results ------------------------------------------------------

    // Invested unit count and capacity
    r_invest_unitCount_u(unit) "Number/amount of invested sub-units"
    r_invest_unitCapacity_gnu(grid, node, unit) "Total amount of invested capacity in units (MW)"
    r_invest_unitEnergyCost_gnu(grid, node, unit) "Total energy consumed by unit investments (MWh)"
    r_invest_transferCapacity_gnn(grid, from_node, to_node, t) "Amount of invested transfer link capacity (MW)"

* --- Emissions Results -------------------------------------------------------

    // emissions by activity type
    r_emission_operationEmissions_gnuft(grid, node, emission, unit, f, t) "Emissions during normal operation (tEmission)"
    r_emission_operationEmissions_gnu(grid, node, unit, emission) "gnu emissions during normal operation (tEmission)"
    r_emission_operationEmissions_nu(node, unit, emission) "node unit total emissions in normal operation (tEmission)"
    r_emission_startupEmissions_nuft(node, emission, unit, f, t) "Emissions from units during start-ups (tEmission)"
    r_emission_StartupEmissions_nu(node, unit, emission) "node unit total emissions in start-ups (tEmission)"
    r_emission_capacityEmissions_nu(node, unit, emission) "Emissions from fixed o&m emissions and investments (tEmission)"

    // Emission sums
    r_emissionByNodeGroup(emission, group) "Group total emissions (tEmission)"
    r_emission_nu(node, unit, emission) "node unit total emissions (tEmission)"
    r_emission_g(grid, emission) "grid total emissions (tEmission)"
    r_emission_n(node, emission) "node total emissions (tEmission)"
    r_emission_u(unit, emission) "unit total emissions (tEmission)"
    r_emission(emission) "Total emissions (tEmission)"

* --- Reserve Provision Results -----------------------------------------------

    // required for model structure
    r_reserve_gnuft(restype, up_down, grid, node, unit, f, t) "Unit capacity reserved for providing reserve of specific type (MW)"
    r_reserveTransferRightward_gnnft(restype, up_down, grid, from_node, to_node, f, t) "Electricity transmission capacity from the first node to the second node reserved for providing reserves (MW)"
    r_reserveTransferLeftward_gnnft(restype, up_down, grid, from_node, to_node, f, t) "Electricity transmission capacity from the second node to the first node reserved for providing reserves (MW)"
    r_reserveMarkets_ft(restype, up_down, group, f, t) "Reserve provided to reserve markets outside the modelled reserve balance (MW)"

    // Unit level reserve results
    r_reserve_gnu(restype, up_down, grid, node, unit) "Total gnu reserve provision over the simulation (MW*h)"
    r_reserve_gn(restype, up_down, grid, node) "Total gn reserve provision over the simulation (MW*h)"
    r_reserve_g(restype, up_down, grid) "Total grid reserve provision over the simulation (MW*h)"
    r_reserveByGroup_ft(restype, up_down, group, f, t) "Group sum of reserves of specific types (MW)"
    r_reserveByGroup(restype, up_down, group) "Total reserve provisions in groups over the simulation (MW*h)"
    r_reserve_gnuShare(restype, up_down, grid, node, unit) "Total gnu/group reserve provision share over the simulation"
    r_reserve2Reserve_gnuft(restype, up_down, grid, node, unit, restype, f, t) "Reserve provided for another reserve category (MW) (also included in r_reserve - this is just for debugging)"

    // Other reserve results
    r_reserve_marginalValue_ft(restype, up_down, group, f, t) "Marginal values of the q_resDemand equation"
    r_reserve_marginalValue_average(restype, up_down, group) "Annual average of marginal values of the q_resDemand equation"
    r_reserveDemand_largestInfeedUnit_ft(restype, up_down, group, f, t) "Reserve Demand from the loss of largest infeed unit"
    r_reserveTransferRightward_gnn(restype, up_down, grid, from_node, to_node) "Total electricity transmission capacity from the first node to the second node reserved for providing reserves (MW*h)"
    r_reserveTransferLeftward_gnn(restype, up_down, grid, from_node, to_node) "Total electricity transmission capacity from the second node to the first node reserved for providing reserves (MW*h)"
    r_reserveMarkets(restype, up_down, group) "Total reserve provided to reserve markets outside the modelled reserve balance (MW*h)"


* --- Group Results -----------------------------------------------------------

    // RoCoF
    r_stability_rocof_unit_ft(group, f, t) "Largest rate of change of frequency due to a unit failure"

    // userconstraints
    r_userconstraint_ft(group, f, t) "Value of r_userconstraint if the type of the userconstraint is 'toVariable'"
    r_userconstraint(group) "Total value of r_userconstraint_ft if the type of the userconstraint is 'toVariable'"

* --- Dummy Result Symbols ----------------------------------------------------

    // Results regarding solution feasibility
    r_qGen_gnft(inc_dec, grid, node, f, t) "Dummy energy generation (increase) or consumption (generation decrease) to ensure equation feasibility (MWh/h)"
    r_qGen_gn(inc_dec, grid, node) "Total dummy energy generation/consumption in gn over the simulation (MWh)."
    r_qGen_g(inc_dec, grid) "Total dummy energy generation/consumption in g over the simulation (MWh)."
    r_qGenRamp_gnuft(inc_dec, grid, node, unit, f, t) "Dummy rampUp (increase) or rampDown (decrease) to ensure equation feasibility (MW/h)"
    r_qGenRamp_gnu(inc_dec, grid, node, unit) "Total dummy rampUp (increase) or rampDown (decrease) over the simulation (MW/h)"
    r_qReserveDemand_ft(restype, up_down, group, f, t) "Dummy to decrease demand for a reserve (MW) before reserve commitment"
    r_qReserveDemand(restype, up_down, group) "Total dummy reserve provisions in the group over the simulation (MW*h)"
    r_qReserveMissing_ft(restype, up_down, group, f, t) "Dummy to decrease demand for a reserve (MW) after reserve commitment"
    r_qReserveMissing(restype, up_down, group) "Total dummy to decrease demand for a reserve in the group over the simulation (MW*h)"
    r_qCapacity_ft(grid, node, f, t) "Dummy capacity to ensure capacity margin equation feasibility (MW)"
    r_qUnitConstraint_uft(inc_dec, constraint, unit, f, t) "Dummy to ensure unit eq/gt/lt equation feasibility"
    r_qUnitConstraint_u(inc_dec, constraint, unit) "Total dummy to ensure unit eq/gt/lt equation feasibility"
    r_qUserconstraint_ft(inc_dec, group, f, t) "Dummy to ensure userconstraint equation feasibility"
    r_qUserconstraint(inc_dec, group) "total dummy to ensure userconstraint equation feasibility"


* --- Cost Results ------------------------------------------------------------

    // Total Objective Function
    r_cost_objectiveFunction_t(t) "Total accumulated value of the objective function over all solves (MEUR)"

    // Unit Cost Components
    r_cost_unitVOMCost_gnuft(grid, node, unit, f, t) "Variable O&M costs for energy input and outputs (MEUR)"
    r_cost_unitVOMCost_gnu(grid, node, unit) "Total gnu VOM costs over the simulation (MEUR)"
    r_cost_unitFuelEmissionCost_gnuft(grid, node, unit, f, t) "Unit fuel & emission costs for normal operation (MEUR)"
    r_cost_unitFuelEmissionCost_u(grid, node, unit) "Total unit fuel & emission costs over the simulation for normal operation (MEUR)"
    r_cost_unitStartupCost_uft(unit, f, t) "Unit startup VOM, fuel, & emission costs (MEUR)"
    r_cost_unitStartupCost_u(unit) "Total unit startup costs over the simulation (MEUR)"
    r_cost_unitShutdownCost_uft(unit, f, t) "Unit shutdown costs (MEUR)"
    r_cost_unitShutdownCost_u(unit) "Total unit shutdown costs over the simulation (MEUR)"
    r_cost_unitRampCost_gnuft(grid, node, unit, f, t) "Unit ramping costs (MEUR)"
    r_cost_unitRampCost_gnu(grid, node, unit) "Total unit ramping costs over the simulation (MEUR)"
    r_cost_unitFOMCost_gnu(grid, node, unit) "Total gnu fixed O&M costs over the simulation, existing and invested units (MEUR)"
    r_cost_unitInvestmentCost_gnu(grid, node, unit) "Total unit investment costs over the simulation (MEUR)"
    r_cost_unitCapacityEmissionCost_nu(node, unit) "Cost from unit FOM emissions and investment emissions (MEUR)"

    // Transfer Link Cost Components
    r_cost_linkVOMCost_gnnft(grid, node_, node, f, t) "Variable Transfer costs (MEUR)"
    r_cost_linkVOMCost_gnn(grid, node_, node) "Total Variable Transfer costs over the simulation (MEUR)"
    r_cost_linkNodeCost_gnnft(grid, node_, node, f, t) "Costs from buying/selling commodities, e.g. electricity, via transfer links (MEUR)"
    r_cost_linkNodeCost_gnn(grid, node_, node) "Total costs from buying/selling commodities, e.g. electricity, via transfer links over the simulation (MEUR)"
    r_cost_linkInvestmentCost_gnn(grid, from_node, to_node) "Total transfer link investment costs over the simulation (MEUR)"

    // Nodal Cost Components
    r_cost_stateSlackCost_gnt(grid, node, f, t) "Costs for states requiring slack (MEUR)"
    r_cost_stateSlackCost_gn(grid, node) "Total costs for state slacks over the simulation (MEUR)"

    // Reserve cost components
    r_cost_reserveMarkets_ft(restype, up_down, group, f, t) "Cost from reserves provided to reserve markets outside the modelled reserve balance (MEUR)"
    r_cost_reserveMarkets(restype, up_down, group) "Total cost from reserves provided to reserve markets outside the modelled reserve balance (MEUR)"

    // Other cost components
    r_cost_userconstraint_t(group, t) "Cost from userconstraint when using toVariable equation type and enabling 'cost' parameter (MEUR)"
    r_cost_userconstraint(group) "Total userconstraint costs over the simulation (MEUR)"

    // Realized System Operating Costs
    r_cost_realizedOperatingCost_gnft(grid, node, f, t) "Realized system operating costs in gn for each t (MEUR)"
    r_cost_realizedOperatingCost_gn(grid, node) "Total realized system operating costs in gn over the simulation (MEUR)"
    r_cost_realizedOperatingCost_g(grid) "Total realized system operating costs in g over the simulation (MEUR)"
    r_cost_realizedOperatingCost "Total realized system operating costs over the simulation: gn cost + userconstraint cost (MEUR)" / 0 /
    r_cost_realizedOperatingCost_gnShare(grid, node) "Total realized system operating cost gn/g shares over the simulation"
    r_cost_realizedNetOperatingCost_gn(grid, node) "Total realized system operating costs in gn over the simulation: gn cost - the increase in storage values (MEUR)"
    r_cost_realizedNetOperatingCost_g(grid) "Total realized system operating costs in g over the simulation: gn cost - the increase in storage values (MEUR)"
    r_cost_realizedNetOperatingCost "Total realized system operating costs over the simulation: gn cost + userconstraint cost - the increase in storage values (MEUR)" / 0 /

    // Realized System Costs
    r_cost_realizedCost_gn(grid, node) "Total realized system costs in gn over the simulation (MEUR)"
    r_cost_realizedCost_g(grid) "Total realized system costs in g over the simulation (MEUR)"
    r_cost_realizedCost "Total realized system costs over the simulation: gn cost + userconstraint cost (MEUR)" / 0 /
    r_cost_realizedCost_gnShare(grid, node) "Total realized system cost gn/g shares over the simulation"
    r_cost_realizedNetCost_gn(grid, node) "Total realized system costs in gn over the simulation: gn cost - the increase in storage values (MEUR)"
    r_cost_realizedNetCost_g(grid) "Total realized system costs in g over the simulation: gn cost - the increase in storage values (MEUR)"
    r_cost_realizedNetCost "Total realized system costs over the simulation: gn cost - the increase in storage values + userconstraint cost (MEUR)" / 0 /


    // Penalty costs
    r_cost_penalty_ft(f, t) "Total penalty costs in all dummy result tables for each t (MEUR). Note: Not included in total costs."
    r_cost_penalty "Total penalty costs in all dummy result tables over the simulation (MEUR). Note: Not included in total costs."

* --- Approximated profits ----------------------------------------------------

    r_transferValue_gnnft(grid, from_node, to_node, f, t) "Transfer marginal value (MEUR) = transfer (MWh/h) * balanceMarginal (EUR/MWh) * stepLength(h)"
    r_transferValue_gnn(grid, from_node, to_node) "Total transfer marginal value summed over the simulation (MEUR)"
    r_cost_storageValueChange_gn(grid, node) "Change in storage values over the simulation (MEUR)"
    r_unit_profit_u "Annual sum of unit specific costs and balance prices of inputs and outputs (MEUR). The sum approximates annual unit profits. Exludes reserves."

* --- Info, and Diagnostic Result Symbols -------------------------------------

    // Info Results
    r_info_solveStatus(t, solve_info) "Information about status of solves"
    // r_info_metadata // metadata written directly from r_info_metadata set
    r_info_mSettings(mSetting) "information about model settings"

; // END PARAMETER DECLARATION

Sets
    r_info_t_realized(t) "result table of realized t"
;

// Only include these if '--diag=yes' given as a command line argument
$iftheni.diag '%diag%' == yes
Parameters
    // model temporary structure diagnostics
    d_tByCounter(counter_large, t) "number of t aggregated by counter in each solve"
    d_tStepsByCounter(counter_large, t) "number of modelled time steps by counter in each solve"
    d_tStartp(t, t) "subset for t used to select timesteps for which results are printed in each solve"


    // unit performance and time series diagnostics
    d_eff(unit, f, t) "Efficiency of generation units using fuel"

    // userconstraint values when using 'sumOfTimesteps'
    d_userconstraint(group, t) "v_userconstraint values for each solve, t_solve as t index"

    // dummies for each solve
    d_qGen_gnftt(inc_dec, grid, node, f, t, t_) "vq_gen(t) for each solve (t_)"
    d_qGenRamp_gnuftt(inc_dec, grid, node, unit, f, t, t) "vq_genRampDown(t) ('decrease') and vq_genRampUp(t) ('increase') for each solve (t_)"
    d_qReserveDemand_ftt(restype, up_down, group, f, t, t) "vq_ReserveDemand(t) for each solve (t_)"
    d_qReserveMissing_ftt(restype, up_down, group, f, t, t) "vq_ReserveMissing(t) for each solve (t_)"
    d_qUnitConstraint_uftt(inc_dec, constraint, unit, f, t, t) "vq_unitConstraint(t) for each solve (t_)"
    d_qUserconstraint_ftt(inc_dec, group, f, t, t) "vq_userconstraint(t) for each solve (t_)"
;
$endif.diag

* --- Initialize a few of the results arrays, required by model structure -----

Option clear = r_cost_objectiveFunction_t;
Option clear = r_state_gnft;
Option clear = r_transfer_gnnft;
Option clear = r_gen_gnuft;
Option clear = r_online_uft;
Option clear = r_startup_uft;
Option clear = r_shutdown_uft;
Option clear = r_invest_unitCount_u;
Option clear = r_invest_transferCapacity_gnn;
Option clear = r_reserve_gnuft;
Option clear = r_reserveTransferRightward_gnnft;
Option clear = r_reserveTransferLeftward_gnnft;
Option clear = r_reserveDemand_largestInfeedUnit_ft;
Option clear = r_reserveMarkets_ft;
Option clear = r_qReserveDemand_ft;

