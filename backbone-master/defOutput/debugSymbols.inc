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

* --- sets ------------------------------------------------------------------------
* --- sets of m, s, or f for different equations, calculations, and filters
m
s_active
s_realized
f_active
f_realization
f_central

* --- sets of t for different filters equations, calculations, and filters
t_start
t_startp
t_full
t_datalength
t_current
t_active
t_invest
t_realized
t_realizedNoReset
t_nonanticipativity
tt
tt_
tt__
t_t
tt_block
tt_interval
tt_forecast
tt_aggregate
tt_aggregate_historical
tt_agg_circular

* --- sets of f, s for different equations, calculations, and filters
ff
ff_

* --- sets of msft for different equations, calculations, and filters
mf
mf_realization
mf_central
ms
ms_initial
ms_central
ft
ft_realized
ft_realizedNoReset
ft_reservesFixed
ft_start
ft_lastSteps
sf
st
st_start
st_end
sft
sft_realized
sft_realizedNoReset
sft_resdgn

* --- other sets for the model structure
modelSolves
gnss_bound
uss_bound

mz
zs

* --- counter sets used in several loops, time intervals, and trajectories
counter
counter_intervals
cc

* --- Sets used for the changing unit aggregation and efficiency approximations as well as unit lifetimes
us
usft
usft_online
usft_onlineLP
usft_onlineMIP
usft_onlineLP_withPrevious
usft_onlineMIP_withPrevious
usft_startupTrajectory
usft_shutdownTrajectory
usft_aggregator_first
gnusft
gnusft_ramp

eff_usft
effGroup
effGroupSelector
effLevelGroupUnit
effGroupSelectorUnit

mSettingsReservesInUse
unitCounter
runUpCounter
shutdownCounter
utAvailabilityLimits

* --- Sets used for the changing transfer link aggregation and efficiency approximations as well as lifetimes
gn2n
gn2n_directional
gn2n_directional_investLP
gn2n_directional_investMIP
gn2n_timeseries
gn2nGroup

gn2nsft_directional
gn2nsft_directional_ramp

* --- Sets used for grouping of units, transfer links, nodes, etc.
uGroup
gnuGroup
gn2nGroup
gnGroup
sGroup
emissionGroup
groupPolicyTimeseries

* --- Sets used to activate and modify forecast timeseries data
ts_gnu_activeForecasts

* --- Mapping sets for different time indexes
map_delay_gnutt

* --- Set of timeseries that will be read from files between solves
mTimeseries_loop_read


* --- Parameters ------------------------------------------------------------------------------

// scalars for temporal structure
solveCount
t_solveFirst
t_solveLast
t_solveLastActive
dt_historicalSteps
currentForecastLength
tRealizedLast

// nodes and connections
p_gn
p_gnBoundaryPropertiesForStates
p_storageValue
p_gnn
p_gnu
p_gnu_io
p_gnuBoundaryProperties
p_unit
p_unitConstraint
p_unitConstraintNew
p_unitConstraintNode
p_gnReserves
p_gnuReserves
p_gnnReserves
p_gnuRes2Res
p_nEmission
p_gnuEmission
p_uStartupfuel
p_unStartup
p_effUnit
p_effGroupUnit
p_uNonoperational

// trajectories
p_uStartup
p_u_runUpTimeIntervals
p_u_runUpTimeIntervalsCeil
p_uCounter_runUpMin
p_uCounter_runUpMax
p_u_maxOutputInFirstShutdownInterval
p_uShutdown
p_u_shutdownTimeIntervals
p_u_shutdownTimeIntervalsCeil
p_uCounter_shutdownMin
p_uCounter_shutdownMax
p_u_minRampSpeedInLastRunUpInterval
p_u_minRampSpeedInFirstShutdownInterval

// groups
p_groupPolicy
p_groupPolicyUnit
p_groupPolicyEmission
p_groupReserves
p_groupReserves3D
p_groupReserves4D

// probability
p_msWeight
p_msAnnuityWeight
p_msProbability
p_mfProbability
p_sft_probability

// Other time dependent parameters
p_stepLength
p_stepLengthNoReset
p_s_discountFactor
p_sLengthInHours

// Probability scalars
p_sWeightSum


* --- Model structure

// Time displacement arrays
dt
dt_circular
dt_next
dt_active
dt_toStartup
dt_toShutdown
dt_starttypeUnitCounter
dt_downtimeUnitCounter
dt_uptimeUnitCounter
dt_trajectory

// Forecast displacement arrays
df_realization
df
df_noReset
df_central
df_reserves
df_reservesGroup

// Other
tForecastNext
msStart
msEnd

p_roundingTs
p_roundingParam



* --- time series data and stochastic data parameters

// original input data
// Unit specific time series
ts_unit
ts_unitConstraint
ts_unitConstraintNode

// Node specific times series
ts_influx
ts_cf
ts_node
ts_gnn
ts_storageValue
ts_price
ts_priceChange
ts_priceNew
ts_priceChangeNew

// alternatives for giving timeseries data vertically via gdxxrw. Not declared by default.
ts_influx_vert
ts_cf_vert

// reserve specific time series
ts_reserveDemand
ts_reservePrice
ts_reservePriceChange

// emission specific time series
ts_emissionPrice
ts_emissionPriceChange
ts_emissionPriceNew
ts_emissionPriceChangeNew

// policy specific time series
ts_groupPolicy


// forecast improvement parameters
p_u_improveForecastNew
p_gn_improveForecastNew


// derived parameters
// static cost parameters calculated based on input data
p_price
p_emissionPrice
p_vomCost
p_startupCost
p_priceNew
p_emissionPriceNew
p_vomCostNew
p_startupCostNew
p_reservePrice

// processed unit specific timeseries used in solve
ts_unit_
ts_unitConstraint_
ts_unitConstraintNode_
ts_vomCost_
ts_startupCost_
ts_vomCostNew_
ts_startupCostNew_
ts_effUnit_
ts_effGroupUnit_

// Processed node specific times series used in solve
ts_influx_
ts_cf_
ts_node_
ts_gnn_
ts_storageValue_

// Processed reserve specific times series used in solve
ts_reserveDemand_
ts_reservePrice_

// Processed group specific times series used in solve
ts_groupPolicy_

// ts storages used for updating data in inputsLoop.gms
ts_unit_update
ts_influx_update
ts_cf_update
ts_reserveDemand_update
ts_node_update
ts_gnn_update

// ts circulation rules
unit_tsCirculation
gn_tsCirculation
reserve_tsCirculation

// circulation adjustment to unit time series
ts_unit_circularAdjustment
ts_unitConstraint_circularAdjustment
ts_unitConstraintNode_circularAdjustment

// circulation adjustment to node time series
ts_influx_circularAdjustment
ts_cf_circularAdjustment
ts_node_circularAdjustment
ts_gnn_circularAdjustment
ts_priceNew_circularAdjustment
ts_storageValue_circularAdjustment

// ts_gnu
ts_gnu_circularAdjustment

// circulation adjustment to reserve time series
ts_reserveDemand_circularAdjustment
ts_reservePrice_circularAdjustment

// circular adjustment to group time series
ts_emissionPriceNew_circularAdjustment


* --- Mapping parameters for different time indexes
p_delay_gnutt


* --- Penalty Definitions -----------------------------------------------------

BIG_M
PENALTY_BALANCE
PENALTY_RES
PENALTY_RES_MISSING
PENALTY_CAPACITY



* --- Variables ------------------------------------------------------------------------------

// free variables
v_obj
v_gen
v_genRamp
v_transfer
v_transferRamp
v_state
v_stateMax
v_stateMin
v_state_z

// integer variable
v_startup_MIP
v_shutdown_MIP
v_online_MIP
v_invest_MIP
v_investTransfer_MIP

// binary variables
v_help_inc

// sos2 variables
v_sos2

// positive variables
v_startup_LP
v_shutdown_LP
v_genRampUpDown
v_gen_delay
v_spill
v_transferRightward
v_transferLeftward
v_resTransferRightward
v_resTransferLeftward
v_reserve
v_resToMarkets
v_investTransfer_LP
v_online_LP
v_invest_LP
v_gen_inc

// (positive) dummy variables
v_stateSlack
vq_gen
vq_genRamp
vq_resDemand
vq_resMissing
vq_capacity
vq_unitConstraint
vq_userconstraintInc_t
vq_userconstraintDec_t
vq_userconstraintInc
vq_userconstraintDec


* --- Equations -------------------------------------------------------------------------------

// Objective Function, Energy Balance, and Reserve demand
q_obj
q_balance
q_resDemand
q_resDemandLargestInfeedUnit
q_rateOfChangeOfFrequencyUnit
q_rateOfChangeOfFrequencyTransfer
q_resDemandLargestInfeedTransfer

// Unit Operation
q_maxDownward
q_maxDownwardOfflineReserve
q_maxUpward
q_maxUpwardOfflineReserve
q_fixedFlow
q_reserveProvision
q_reserveProvisionOnline
q_startshut
q_startuptype
q_onlineOnStartUp
q_offlineAfterShutDown
q_onlineLimit
q_onlineMinUptime
q_onlineCyclic
q_genRamp
q_rampUpLimit
q_rampDownLimit
q_rampUpDownPiecewise
q_rampSlack
q_genDelay
q_conversionDirectInputOutput
q_conversionSOS2InputIntermediate
q_conversionSOS2Constraint
q_conversionSOS2IntermediateOutput
q_conversionIncHR
q_conversionIncHRMaxOutput
q_conversionIncHRBounds
q_conversionIncHR_help1
q_conversionIncHR_help2
q_unitEqualityConstraint
q_unitGreaterThanConstraint
q_unitLesserThanConstraint

// Energy Transfer
q_transfer
q_transferRightwardLimit
q_transferLeftwardLimit
q_transferRamp
q_transferRampLimit1
q_transferRampLimit2
q_resTransferLimitRightward
q_resTransferLimitLeftward
q_reserveProvisionRightward
q_reserveProvisionLeftward
q_transferTwoWayLimit1
q_transferTwoWayLimit2

// State
q_stateUpwardSlack
q_stateDownwardSlack
q_stateUpwardLimit
q_stateDownwardLimit
q_boundStateMaxDiff
q_boundCyclic

// superpositioned state
q_superposBoundEnd
q_superposInter
q_superposStateMax
q_superposStateMin
q_superposStateUpwardLimit
q_superposStateDownwardLimit

// Policy
q_inertiaMin
q_instantaneousShareMax
q_constrainedOnlineMultiUnit
q_capacityMargin
q_constrainedCapMultiUnit
q_emissioncapNodeGroup
q_energyLimit
q_energyShareLimit
q_ReserveShareMax
q_userconstraintEq_eachTimestep
q_userconstraintGtLt_eachTimestep
q_userconstraintEq_sumOfTimesteps
q_userconstraintGtLt_sumOfTimesteps
q_nonanticipativity_online
q_nonanticipativity_state
