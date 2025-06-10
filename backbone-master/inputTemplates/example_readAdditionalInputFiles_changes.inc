* the model reads changes.inc after input data gdx and after 1e_scenchanges.gms
* changes.inc can be used for may uses, e.g. modifying input data or reading second input file


* ------------------------
* Reading mandatory additional input data excel, only selected input data tables
* ------------------------

// reads from predefined place and file %input_dir%/inputData2.xlsx
// proceeding only if additional input data excel exists
$ifthen exist '%input_dir%/inputData2.xlsx'

// Convert additional excel input
$call 'gdxxrw Input="%input_dir%/inputData2.xlsx" Output="%input_dir%/inputData2.gdx" index=index!A1'
$ife %system.errorlevel%>0 $abort gdxxrw failed!

    // load input data
    $$gdxin  '%input_dir%/inputData2.gdx'
    // this list contais only selected input data tables
    // Note that all items in this list must be included in the index table of the inputData2.xlsx
    $$loaddcm grid
    $$loaddcm node
    $$loaddcm flow
    $$loaddcm unittype
    $$loaddcm unit
    $$loaddcm unitUnittype
    $$loaddcm unit_fail
    $$loaddcm unitUnitEffLevel
    $$loaddcm effLevelGroupUnit
    $$loaddcm p_gn
    $$loaddcm p_gnn
    $$loaddcm p_gnu_io
    $$loaddcm p_gnuBoundaryProperties
    $$loaddcm p_unit

    $$gdxin
$endif



* ------------------------
* Reading optional additional input data excel, all input data tables
* ------------------------


$ifthen exist '%input_dir%/%input_file_excel2%'
    $$call 'gdxxrw Input="%input_dir%/%input_file_excel2%" Output="%input_dir%/inputData2.gdx" Index=index!A1'
$elseif set input_file_excel2
    $$abort 'Did not find *additional* input data excel from the given location, check path and spelling!'
$endif
$ife %system.errorlevel%>0 $abort gdxxrw failed! Check that your *additional* input Excel is valid and that your file path and file name are correct.

$ifthen exist '%input_dir%/inputData2.gdx'
  $$gdxin  '%input_dir%/inputData2.gdx'
    $$loaddcm grid
    $$loaddcm node
    $$loaddcm flow
    $$loaddcm unittype
    $$loaddcm unit
    $$loaddcm unitUnittype
    $$loaddcm unit_fail
    $$loaddcm unitUnitEffLevel
    $$loaddcm effLevelGroupUnit
    $$loaddcm group
    $$loaddcm p_gn
    $$loaddcm p_gnn
    $$loaddcm p_gnu_io
    $$loaddcm p_gnuBoundaryProperties
    $$loaddcm p_unit
    $$loaddcm ts_unit
    $$loaddcm p_unitConstraint
    $$loaddcm p_unitConstraintNode
    $$loaddcm restype
    $$loaddcm restypeDirection
    $$loaddcm restypeReleasedForRealization
    $$loaddcm restype_inertia
    $$loaddcm p_groupReserves
    $$loaddcm p_groupReserves3D
    $$loaddcm p_groupReserves4D
    $$loaddcm p_gnuReserves
    $$loaddcm p_gnnReserves
    $$loaddcm p_gnuRes2Res
    $$loaddcm ts_reserveDemand
    $$loaddcm p_gnBoundaryPropertiesForStates
    $$loaddcm p_uStartupfuel
    $$loaddcm flowUnit
    $$loaddcm emission
    $$loaddcm p_nEmission
    $$loaddcm ts_cf
    $$loaddcm ts_priceChange
    $$loaddcm ts_influx
    $$loaddcm ts_node
    $$loaddcm p_s_discountFactor
    $$loaddcm t_invest
    $$loaddcm utAvailabilityLimits
    $$loaddcm p_storageValue
    $$loaddcm ts_storageValue
    $$loaddcm uGroup
    $$loaddcm gnuGroup
    $$loaddcm gn2nGroup
    $$loaddcm gnGroup
    $$loaddcm sGroup
    $$loaddcm p_groupPolicy
    $$loaddcm p_groupPolicyEmission
    $$loaddcm p_groupPolicyUnit
    $$loaddcm gnss_bound
    $$loaddcm uss_bound
    $$loaddcm p_s_discountFactor
    $$loaddcm p_gnuEmission
    $$gdxin
$endif





