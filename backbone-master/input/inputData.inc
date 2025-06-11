
$gdxIn C:\Users\oliver\Documents\RUB\01_Projekte\StEAM\Programme\StEAM_model\backbone-master\input/inputData.gdx
$onEmpty
$offEolCom
$eolCom !!

Set emission(*) ;
$loadDC emission

Set flow(*) ;
$loadDC flow

Set grid(*) ;
$loadDC grid

Set group(*) ;
$loadDC group

Set node(*) ;
$loadDC node

Set restype(*) ;
$loadDC restype

Set unit(*) ;
$loadDC unit

Set unittype(*) ; !!empty
$loadDC unittype !!empty

Set flowUnit(*,*) ;
$loadDC flowUnit

Set restypeDirection(*,*) ; !!empty
$loadDC restypeDirection !!empty

Set uGroup(*,*) ;
$loadDC uGroup

Set unitUnittype(*,*) ; !!empty
$loadDC unitUnittype !!empty

Set effLevelGroupUnit(*,*,*) ;
$loadDC effLevelGroupUnit

Set gnGroup(*,*,*) ;
$loadDC gnGroup

Set unitUnitEffLevel(*,*,*) ; !!empty
$loadDC unitUnitEffLevel !!empty

Set gn2nGroup(*,*,*,*) ; !!empty
$loadDC gn2nGroup !!empty

Set gnuGroup(*,*,*,*) ; !!empty
$loadDC gnuGroup !!empty

Parameter p_unit(*,*) ;
$loadDC p_unit

Parameter p_s_discountFactor(*) ; !!empty
$loadDC p_s_discountFactor !!empty

Parameter p_groupPolicy(*,*) ; !!empty
$loadDC p_groupPolicy !!empty

Parameter p_gn(*,*,*) ;
$loadDC p_gn

Parameter p_gnn(*,*,*,*) ;
$loadDC p_gnn

Parameter p_gnu_io(*,*,*,*,*) ;
$loadDC p_gnu_io

Parameter p_gnuBoundaryProperties(*,*,*,*,*) ; !!empty
$loadDC p_gnuBoundaryProperties !!empty

Parameter p_unitConstraint(*,*) ; !!empty
$loadDC p_unitConstraint !!empty

Parameter p_unitConstraintNode(*,*,*) ;
$loadDC p_unitConstraintNode

Parameter p_groupReserves(*,*,*) ; !!empty
$loadDC p_groupReserves !!empty

Parameter p_groupReserves3D(*,*,*,*) ; !!empty
$loadDC p_groupReserves3D !!empty

Parameter p_groupReserves4D(*,*,*,*,*) ; !!empty
$loadDC p_groupReserves4D !!empty

Parameter p_gnuReserves(*,*,*,*,*) ; !!empty
$loadDC p_gnuReserves !!empty

Parameter p_gnnReserves(*,*,*,*,*) ; !!empty
$loadDC p_gnnReserves !!empty

Parameter p_gnuRes2Res(*,*,*,*,*,*) ; !!empty
$loadDC p_gnuRes2Res !!empty

Parameter p_gnBoundaryPropertiesForStates(*,*,*,*) ;
$loadDC p_gnBoundaryPropertiesForStates

Parameter p_uStartupFuel(*,*,*) ; !!empty
$loadDC p_uStartupFuel !!empty

Parameter p_nEmission(*,*) ;
$loadDC p_nEmission

Parameter p_storageValue(*,*) ; !!empty
$loadDC p_storageValue !!empty

Parameter p_groupPolicyUnit(*,*,*) ;
$loadDC p_groupPolicyUnit

Parameter ts_unit(*,*,*,*) ; !!empty
$loadDC ts_unit !!empty

Parameter ts_reserveDemand(*,*,*,*,*) ; !!empty
$loadDC ts_reserveDemand !!empty

Parameter ts_cf(*,*,*,*) ;
$loadDC ts_cf

Parameter ts_price(*,*) ; !!empty
$loadDC ts_price !!empty

Parameter ts_priceChange(*,*) ;
$loadDC ts_priceChange

Parameter ts_influx(*,*,*,*) ;
$loadDC ts_influx

Parameter ts_node(*,*,*,*,*) ; !!empty
$loadDC ts_node !!empty

Parameter ts_gnn(*,*,*,*,*,*) ; !!empty
$loadDC ts_gnn !!empty

Parameter ts_storageValue(*,*,*,*) ; !!empty
$loadDC ts_storageValue !!empty

Set t_invest(*) ;
$loadDC t_invest

Set sGroup(*,*) ; !!empty
$loadDC sGroup !!empty

Set uss_bound(*,*,*) ; !!empty
$loadDC uss_bound !!empty

Set gnss_bound(*,*,*,*) ; !!empty
$loadDC gnss_bound !!empty

Parameter utAvailabilityLimits(*,*,*) ;
$loadDC utAvailabilityLimits

Set unit_fail(*) ; !!empty
$loadDC unit_fail !!empty

Set restypeReleasedForRealization(*) ; !!empty
$loadDC restypeReleasedForRealization !!empty

Set restype_inertia(*) ; !!empty
$loadDC restype_inertia !!empty

Parameter p_gnuEmission(*,*,*,*,*) ; !!empty
$loadDC p_gnuEmission !!empty

Parameter ts_emissionPriceChange(*,*,*) ; !!empty
$loadDC ts_emissionPriceChange !!empty

Parameter p_groupPolicyEmission(*,*,*) ;
$loadDC p_groupPolicyEmission

Set s_config_info(*) ;
$loadDC s_config_info

Set s_config_alternative(*) ;
$loadDC s_config_alternative

Set s_config_value(*) ;
$loadDC s_config_value

Set s_config_parameter(*) ;
$loadDC s_config_parameter

Set s_config_object(*) ;
$loadDC s_config_object

Set s_countries(*) ;
$loadDC s_countries

Set s_regions(*) ;
$loadDC s_regions

Set s_scenario(*) ;
$loadDC s_scenario

Set s_alternative(*) ;
$loadDC s_alternative

Set steam_subset_countries(*,*) ;
$loadDC steam_subset_countries

Set steam_model_config(*,*,*,*,*) ;
$loadDC steam_model_config

Set steam_scenarioAlternative(*,*) ;
$loadDC steam_scenarioAlternative

$offEmpty
