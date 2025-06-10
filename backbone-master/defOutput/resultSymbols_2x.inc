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
* --- Results Symbols Included in Output --------------------------------------
* =============================================================================

* --- Node Result Symbols -----------------------------------------------------

// r_state required for model structure !!!!!!!!!!!
r_state

// State variable slack results
r_stateSlack

// spill results
r_spill
r_gnTotalSpill
r_gTotalSpill
r_gnTotalSpillShare

// r_transfer required for model structure !!!!!!!!!!!
r_transfer

// Energy transfer results
r_transferRightward
r_transferLeftward
r_gnnTotalTransfer

// Marginal value of energy results
r_balanceMarginal
r_balanceMarginalAverage
r_gnnTransferValue
r_gnnTotalTransferValue

// Other node related results
r_gnCurtailments
r_gnTotalCurtailments
r_gnnDiffusion
r_gnnTotalDiffusion

* --- Energy Generation/Consumption Result Symbols ----------------------------

// r_gen required for model structure !!!!!!!!!!!
r_gen

// Energy generation results
r_gnuTotalGen
r_gnGen
r_gnTotalGen
r_gTotalGen
r_gnuTotalGenShare
r_gnTotalGenShare

// Approximate utilization rates
r_gnuUtilizationRate

// Energy generation results based on input, unittype, or group
r_genFuel
r_gnTotalGenFuel
r_gTotalGenFuel
r_totalGenFuel
r_gnTotalGenFuelShare
r_genUnittype
r_gnuTotalGen_unittype
r_gnTotalGenGnuGroup

// Energy consumption results
r_gnConsumption
r_gnTotalConsumption
r_gTotalConsumption
r_gnTotalConsumptionShare
r_nuStartupConsumption

* --- Unit Online, startup, and shutdown Result Symbols ----------------------------------------

// Online, startup, and shutdown results required for model structure !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
r_online
r_startup
r_shutdown

// other online, startup, and shutdown results
r_uTotalOnline
r_uTotalOnlinePerUnit
r_uTotalStartup
r_uTotalShutdown

* --- Investment Result Symbols -----------------------------------------------

// Invested unit count and capacity
r_invest
r_investCapacity
r_investTransfer

* --- Emissions Results -----------------------------------------------

// emissions by activity type
r_emissions
r_nuTotalEmissionsOperation
r_emissionsStartup
r_nuTotalEmissionsStartup
r_emissionsCapacity

// Emission sum results
r_emissionsNodeGroupTotal
r_nuTotalEmissions
r_nTotalEmissions
r_uTotalEmissions
r_totalEmissions

* --- Reserve Result Symbols ----------------------------------------

// Reserve provision results required for model structure !!!!!!!!!!!!!!!!!!!!!
r_reserve
r_resTransferRightward
r_resTransferLeftward

// Unit level reserve results
r_gnuTotalReserve
r_gnTotalReserve
r_groupReserve
r_groupTotalReserve
r_gnuTotalReserveShare
r_reserve2Reserve

// Other reserve results
r_resDemandMarginal
r_resDemandMarginalAverage
r_resDemandLargestInfeedUnit
r_gnnTotalResTransferRightward
r_gnnTotalResTransferLeftward

* --- Dummy Result Symbols ----------------------------

// Results regarding solution feasibility
r_qGen
r_gnTotalqGen
r_gTotalqGen
r_qResDemand
r_qResMissing
r_groupTotalqResDemand
r_qCapacity

* --- Cost Result Symbols -----------------------------------------------------

// Total Objective Function
r_totalObj

// Unit Cost Components
r_gnuVOMCost
r_gnuTotalVOMCost
r_uFuelEmissionCost
r_uTotalFuelEmissionCost
r_uStartupCost
r_uTotalStartupCost
//r_uShutdownCost
r_gnuFOMCost
r_gnuUnitInvestmentCost

// Transfer Link Cost Components
r_gnnVariableTransCost
r_gnnTotalVariableTransCost
r_gnnLinkInvestmentCost

// Nodal Cost Components
r_gnStateSlackCost
r_gnTotalStateSlackCost
r_gnStorageValueChange

// Realized System Operating Costs
r_gnRealizedOperatingCost
r_gnTotalRealizedOperatingCost
r_gTotalRealizedOperatingCost
r_totalRealizedOperatingCost
r_gnTotalRealizedOperatingCostShare
r_gnTotalRealizedNetOperatingCost
r_gTotalRealizedNetOperatingCost
r_totalRealizedNetOperatingCost

// Realized System Costs
r_gnTotalRealizedCost
r_gTotalRealizedCost
r_totalRealizedCost
r_gnTotalRealizedCostShare
r_gnTotalRealizedNetCost
r_gTotalRealizedNetCost
r_totalRealizedNetCost

* --- Info and Diagnostic Result Symbols ----------------------------

// Info results
r_solveStatus
metadata
mSettings
t_realizedNoReset = t

// Diagnostics
$iftheni.diag '%diag%' == yes
// model structure
d_tByCounter
d_tStepsByCounter

// units and nodes
d_eff

// dummies
d_qGen_gnftt
d_qReserveDemand_ftt
d_qReserveMissing_ftt
d_qUnitConstraint_uftt

$endif.diag


