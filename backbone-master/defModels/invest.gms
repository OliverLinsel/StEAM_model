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
* --- Invest Model Equations --------------------------------------------------
* =============================================================================

Model invest /
    q_obj
    q_balance
    q_resDemand
    q_resDemandLargestInfeedUnit // Use with extra caution if there are several sub-units
    q_rateOfChangeOfFrequencyUnit // Use with extra caution if there are several sub-units
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
    q_genRampUp
    q_genRampDown
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

    // State Variables
    q_stateUpwardSlack
    q_stateDownwardSlack
    q_stateUpwardLimit
    q_stateDownwardLimit
    q_boundStateMaxDiff
    q_boundCyclic

    // superpositioned state variables
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
    q_userconstraintEq_sumOfTimeSteps
    q_userconstraintGtLt_sumOfTimeSteps
    q_nonanticipativity_online
    q_nonanticipativity_state

$ifthen.invAddConst exist '%input_dir%/invest_additional_constraints.gms'
   $$include '%input_dir%/invest_additional_constraints.gms'      // Declare additional constraints from the input data
$endif.invAddConst
/;
