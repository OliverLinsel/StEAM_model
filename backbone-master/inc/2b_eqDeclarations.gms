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
* --- Equation Declarations ---------------------------------------------------
* =============================================================================

equations
    // Objective Function
    q_obj "Objective function"

    // Energy Balance, and Reserve demand
    q_balance(grid, node, s, f, t) "Energy demand must be satisfied at each node"
    q_resDemand(restype, up_down, group, s, f, t) "Procurement for each reserve type is greater than demand"
    q_resDemandLargestInfeedUnit(restype, up_down, group, unit, s, f, t) "N-1 reserve for units"
    q_rateOfChangeOfFrequencyUnit(group, unit, s, f, t) "N-1 unit contingency with ROCOF"
    q_rateOfChangeOfFrequencyTransfer(group, grid, node, node, s, f, t) "N-1 transmission line contingency with ROCOF"
    q_resDemandLargestInfeedTransfer(restype, up_down, group, grid, node, node, s, f, t) "N-1 up/down reserve for transmission lines"

    // Unit Operation
    q_maxDownward(grid, node, unit, s, f, t) "Downward commitments (v_gen and online v_reserve) will not undercut minimum (online) production capacity (+) or maximum (online) consumption capacity (-)"
    q_maxDownwardOfflineReserve(grid, node, unit, s, f, t) "Downward commitments (v_gen and all v_reserve) will not undercut zero production (+) or maximum consumption capacity (-)"
    q_maxUpward(grid, node, unit, s, f, t) "Upward commitments (v_gen and online v_reserve) will not exceed maximum (online) production capacity (+) or minimum (online) consumption capacity (-)"
    q_maxUpwardOfflineReserve(grid, node, unit, s, f, t) "Upward commitments (v_gen and all v_reserve) will not exceed maximum production capacity (+) or zero consumption (-)"
    q_fixedFlow(grid, node, unit, s, f, t) "V_gen is fixed to flow-based value, multiplied by availability and capacity"
    q_reserveProvision(restype, up_down, grid, node, unit, s, f, t) "Reserve provision limited for units with investment possibility"
    q_reserveProvisionOnline(restype, up_down, grid, node, unit, s, f, t) "Reserve provision limited for units that are not capable of providing offline reserve"
    q_startshut(unit, s, f, t) "Online capacity now minus online capacity in the previous interval is equal to started up minus shut down capacity"
    q_startuptype(starttype, unit, s, f, t) "Startup type depends on the time the unit has been non-operational"
    q_onlineOnStartUp(unit, s, f, t) "Unit must be online after starting up"
    q_offlineAfterShutdown(unit, s, f, t) "Unit must be offline after shutting down"
    q_onlineLimit(unit, s, f, t) "Number of online units limited for units with startup constraints, minimum down time, or investment possibility"
    q_onlineMinUptime(unit, s, f, t) "Number of online units constrained for units with minimum up time"
    q_onlineCyclic(unit, s, s) "Cyclic online state bound for the first and the last states of samples"
    q_genRampUp(grid, node, unit, s, f, t) "Records upward ramps of units with upward ramp restricitions or costs"
    q_genRampDown(grid, node, unit, s, f, t) "Records downward ramps of units with downward ramp restricitions or costs"
    q_rampUpLimit(grid, node, unit, s, f, t) "Up ramping limited for units"
    q_rampDownLimit(grid, node, unit, s, f, t) "Down ramping limited for units"
    q_rampUpDownPiecewise(grid, node, unit, s, f, t) "Ramping separated into possibly several upward and downward parts (for different cost levels)"
    q_rampSlack(slack, grid, node, unit, s, f, t) "Upward and downward ramps constrained by slack boundaries (for different cost levels)"
    q_genDelay(grid, node, unit, s, f, t) "Equation converting v_gen to v_gen_delay for units with active delays"
    q_conversionDirectInputOutput(effSelector, unit, s, f, t) "Direct conversion of inputs to outputs (no piece-wise linear part-load efficiencies)"
    q_conversionSOS2InputIntermediate(effSelector, unit, s, f, t)   "Intermediate output when using SOS2 variable based part-load piece-wise linearization"
    q_conversionSOS2Constraint(effSelector, unit, s, f, t)          "Sum of v_sos2 has to equal v_online"
    q_conversionSOS2IntermediateOutput(effSelector, unit, s, f, t)  "Output is forced equal with v_sos2 output"
    q_conversionIncHR(effSelector, unit, s, f, t)  "Conversion of inputs to outputs for incremental heat rates"
    q_conversionIncHRMaxOutput(grid, node, effSelector, unit, s, f, t)  "Max output level"
    q_conversionIncHRBounds(grid, node, hr, effSelector, unit, s, f, t) "Heat rate bounds"
    q_conversionIncHR_help1(grid, node, hr, effSelector, unit, s, f, t) "Helper equation 1 to ensure that the first heat rate segments are used first"
    q_conversionIncHR_help2(grid, node, hr, effSelector, unit, s, f, t) "Helper equation 2 to ensure that the first heat rate segments are used first"
    q_unitEqualityConstraint(eq_constraint, unit, s, f, t) "Fixing the ratio between unit inputs and/or outputs"
    q_unitGreaterThanConstraint(gt_constraint, unit, s, f, t) "Lower limit for the ratio between unit inputs and/or outputs"
    q_unitLesserThanConstraint(lt_constraint, unit, s, f, t) "Upper limit for the ratio between unit inputs and/or outputs"

    // Energy Transfer
    q_transfer(grid, node, node, s, f, t) "Rightward and leftward transfer must match the total transfer"
    q_transferRightwardLimit(grid, node, node, s, f, t) "Transfer of energy and capacity reservations to the rightward direction are less than the transfer capacity"
    q_transferLeftwardLimit(grid, node, node, s, f, t) "Transfer of energy and capacity reservations to the leftward direction are less than the transfer capacity"
    q_transferRamp(grid, node, node, s, f, t) "Record the ramps of transfers with ramp restrictions"
    q_transferRampLimit1(grid, node, node, s, f, t) "Limiting transfer ramp rates, direction 1"
    q_transferRampLimit2(grid, node, node, s, f, t) "Limiting transfer ramp rates, direction 2"
    q_resTransferLimitRightward(grid, node, node, s, f, t) "Transfer of energy and capacity reservations are less than the transfer capacity to the rightward direction"
    q_resTransferLimitLeftward(grid, node, node, s, f, t) "Transfer of energy and capacity reservations are less than the transfer capacity to the leftward direction"
    q_reserveProvisionRightward(restype, up_down, grid, node, node, s, f, t) "Rightward reserve provision limited - needed for links with investment possibility"
    q_reserveProvisionLeftward(restype, up_down, grid, node, node, s, f, t) "Leftward reserve provision limited - needed for links with investment possibility"
    q_transferTwoWayLimit1(grid, node, node, s, f, t) "Limiting transfer in both directions, option 1"
    q_transferTwoWayLimit2(grid, node, node, s, f, t) "Limiting transfer in both directions, option 2"

    // State
    q_stateUpwardSlack(grid, node, s, f, t) "State upward slack variable greater than the difference between v_state and upwardLimit"
    q_stateDownwardSlack(grid, node, s, f, t) "State downward slack variable greater than the difference between downwardLimit and v_state"
    q_stateUpwardLimit(grid, node, s, f, t) "Limit the commitments of a node with a state variable to the available headrooms"
    q_stateDownwardLimit(grid, node, s, f, t) "Limit the commitments of a node with a state variable to the available headrooms"
    q_boundStateMaxDiff(grid, node, node, s, f, t) "Node state variables bounded by other nodes (maximum state difference)"
    q_boundCyclic(grid, node, s, s) "Cyclic node state bound for the first and the last states of samples"

    // superpositioned state
    q_superposBoundEnd(grid, node, mType)
    q_superposInter(grid, node, mType,z)
    q_superposStateMax(grid, node, s, f, t)
    q_superposStateMin(grid, node, s, f, t)
    q_superposStateUpwardLimit(grid, node, mType, z)
    q_superposStateDownwardLimit(grid, node, mType, z)

    // Policy
    q_inertiaMin(restype, up_down, group, s, f, t) "Minimum inertia in a group of nodes"
    q_instantaneousShareMax(group, s, f, t) "Maximum instantaneous share of generation and controlled import from a group of units and links"
    q_constrainedOnlineMultiUnit(group, s, f, t) "Constrained number of online units for a group of units"
    q_capacityMargin(grid, node, s, f, t) "There needs to be enough capacity to cover energy demand plus a margin"
    q_constrainedCapMultiUnit(group) "Constrained unit number ratios and sums for a group of units"
    q_emissioncapNodeGroup(group, emission) "Limit for emissions in a specific group of nodes, gnGroup, during specified time steps, sGroup"
    q_energyLimit(group, min_max) "Limited energy production or consumption from a group of units"
    q_energyShareLimit(group, min_max) "Limited share of energy production from a group of units"
    q_ReserveShareMax(group, restype, up_down, group, s, f, t) "Maximum reserve share of a group of units"
    q_userconstraintEq_eachTimestep(group, s, f, t) "Generic user constraint for equality constraints and 'toVariable' equation type, timestep specific"
    q_userconstraintGtLt_eachTimestep(group, s, f, t) "Generic user constraint for gt and lt constraints, timestep specific"
    q_userconstraintEq_sumOfTimesteps(group) "Generic user constraint for equality constraints and 'toVariable' equation type, sum of time steps"
    q_userconstraintGtLt_sumOfTimesteps(group) "Generic user constraint for gt and lt constraints, sum of time steps"
    q_nonanticipativity_online(unit, s, f, t) "Non-anticipativity constraint for unit v_online"
    q_nonanticipativity_state(grid, node, s, f, t) "Non-anticipativity constraint for storage v_state by summing v_gen, v_transfer, and v_spill"

;
