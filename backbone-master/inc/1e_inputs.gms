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

Table of Contents
- Load input data
    - input gdx
    - other default sources
- Preliminary adjustments and preprocess checks to data
    - timeseries
    - nodes and link
    - units
- Active unit, gnu, gnn, and gn
- Unit Related Sets & Parameters
- Node related Sets & Parameters
- Node price Related Sets & Parameters
- Emission related Sets & Parameters
- Reserves Sets & Parameters
- Policy related Sets & Parameters
- Postprocess checks to data
- User constraint checks
- Default values


$offtext

* =============================================================================
* --- Load Input Data, input gdx ----------------------------------------------
* =============================================================================

// if input file debug gdx is set, skip most of the input data
$if set input_file_debugGdx $goto input_debugGdx


* --- optional: translating input excel to gdx --------------------------------

* If input_file excel has been set in the command line arguments, then Gdxxrw will be run to convert the Excel into a GDX file
*   using the sheet defined by input_excel_index command line argument (default: 'INDEX').
$ifthen exist '%input_dir%/%input_file_excel%'
    $$call 'gdxxrw Input="%input_dir%/%input_file_excel%" Output="%input_dir%/%input_file_gdx%" Index=%input_excel_index%! %input_excel_checkdate%'
$elseif exist '%input_file_excel%'
    $$call 'gdxxrw Input="%input_file_excel%" Output="%input_dir%/%input_file_gdx%" Index=%input_excel_index%! %input_excel_checkdate%'
$elseif set input_file_excel
    $$abort 'Did not find input data excel from the given location, check path and spelling!'
$endif
$ife %system.errorlevel%>0 $abort gdxxrw failed! Check that your input Excel is valid and that your file path and file name are correct.


* --- locating input data gdx ------------------------------------------------

* setting path for input data gdx and inc files created when reading the data
* default assumptions input_dir = ./input,  input_file_gdx = inputData.gdx
* if %input_dir%/%input_file_gdx% exists
*        option --input_dir specifies alternative input directory. Can be relative reference. See backbone.gms
*        option --input_file_gdx specifies alternative input gdx name. See backbone.gms
*        input data inc files created to same folder
* else if %input_file_gdx% exists
*        --input_file_gdx= nameOfInputFile.gdx for input_file_gdx in ./input
*        --input_file_gdx=ABSOLUTE/PATH/nameOfInputFile.gdx for input_file_gdx not in input_dir
*        input data inc files created to ./input folder
* else go to no_input_gdx label

$ifthen exist '%input_dir%/%input_file_gdx%'
    $$setglobal inputDataGdx '%input_dir%/%input_file_gdx%'
    $$setglobal inputDataInc '%input_dir%/inputData.inc'
    $$setglobal inputDataInc_ '%input_dir%/inputData_.inc'
$elseif exist '%input_file_gdx%'
    $$setglobal inputDataGdx '%input_file_gdx%'
    $$setglobal inputDataInc 'input/inputData.inc'
    $$setglobal inputDataInc_ 'input/inputData_.inc'
$else
    if(%warnings%=1,
        put log '!!! Warning: No input data file found. Skipping reading input data gdx.' /;
        put log '!!! Warning: Will crash the model if alternative data is not given via 1e_scenChanges.gms or changes.inc' /;
    );
    $$goto no_input_gdx
$endif


* --- importing data from the input data gdx ----------------------------------

* the new way to read input data breaks the model if input data gdx contains tables not predefined.
* Reading definitions for user given additional sets and parameters in the input data gdx.
$ifthen.addParams exist '%input_dir%/additionalSetsAndParameters.inc'
   $$include '%input_dir%/additionalSetsAndParameters.inc'
$endif.addParams

* Importing domains from the input data gdx.
* These can be empty, but must be given in the input data gdx.
* Domains can be supplemented in scen changes or in changes.inc.
$gdxin '%inputDataGdx%'
* Following three must contain values
$loaddcm grid
$loaddcm node
$loaddcm unit
* The rest must be included, but can be empty
$loaddcm emission
$loaddcm flow
$loaddcm unittype
$loaddcm restype
$loaddcm group
$gdxin

* In addition to domains, there is a current minimum dataset for any meaningful model.
* Following data tables must be included either in input data gdx or in data given
* in scen changes or changes.inc
*       p_unit
*       p_gn
*       p_gnu_io
*       effLevelGroupUnit
*       ts_influx (or other data table creating the energy demand)


* ---  Reading all other data present in the input data gdx.  -------------

* setting quote mark for unix or windows (MSNT)
$ SET QTE "'"
$ IFI %SYSTEM.FILESYS%==MSNT $SET QTE '"'

* query checking which data tables exists and writes the list to file inputDataInc
$hiddencall gdxdump "%inputDataGdx%"  NODATA > "%inputDataInc%"
* Using sed to convert gdxdump output to a format that can be imported to backbone
* This does the following:
*    /^[$]/!d; - deletes any line that does not start with a dollar sign.
*    /^\$LOADDC add_/Id; - drops any line starting with "$LOADDC add_". I for case insensitivity.
*    s/\$LOAD.. /\$LOADDCM /I - replaces occurrences of $LOAD followed by any two characters with $LOADDCM. I for case insensitivity.
*    %QTE% set unix/windows quetos around the SED command
$hiddencall sed %QTE%/^[$]/!d;  /^\$LOADDC add_/Id; s/\$LOAD.. /\$LOADDCM /I%QTE%  "%inputDataInc%" > "%inputDataInc_%"
* importing data from the input data gdx as specified by the %inputDataInc_%
$INCLUDE %inputDataInc_%
* closing the input file
$gdxin


* checking system error stage, aborting if input data import failed
$if NOT errorfree put log "!!! Error on importing input data";
$if NOT errorfree put log "!!! Abort: Reading input data gdx failed!" /;
$if NOT errorfree $abort Reading input data gdx failed. Please check detailed error messages from backbone.lst


* =============================================================================
* --- Load Input Data, other default sources ----------------------------------
* =============================================================================

* Reading data from alternative sources in following priority and order:
*  - 1e_scenchanges.inc unless debug gdx has been set
*  - read debug gdx file if set
*  - read %changes_inc%
*
* If input data existed, scenChanges and %changes_inc% can be used
* to modify given data, e.g. when using multiple input files or running
* alternative scenarios.
*
* Input from debug gdx is fully alternative route for
* reading the input data and is designed to help when debugging model runs from
* other modellers.


* jumping to here if no input gdx.
$label no_input_gdx

// Read changes to inputdata through gdx files (e.g. node2.gdx, unit2.gdx, unit3.gdx)
$include 'inc/1e_scenChanges.gms'

* checking system error stage, aborting if input data import failed
$if NOT errorfree put log "!!! Error when processing 1e_ScenChanges.inc";
$if NOT errorfree put log "!!! Abort: Reading 1e_scenChanges.inc failed!" /;
$if NOT errorfree $abort Reading 1e_scenChanges.inc  failed. Please check detailed error messages from backbone.lst


* jumping to here if reading data from existing debug gdx file
$label input_debugGdx

$ifthen.input_file_debugGdx set input_file_debugGdx
* Reading a fixed set of parameters and sets from a debug file.
* This list containts tables required by all versions
* by default, input_dir = input, input_file_debugGdx = ''

$ifthen.fileExists exist '%input_dir%/%input_file_debugGdx%'
    // load inputs
    $$gdxin  '%input_dir%/%input_file_debugGdx%'
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
    $$loaddcm ts_gnn
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
    $$loaddcm ts_price
    $$loaddcm ts_emissionPrice
    // priceChange data should not be imported because previous model has already processed it
    //$$loaddcm ts_priceChange
    //$$loaddcm ts_emissionPriceChange
    // instead import p_price, p_emissionPrice, p_vomCost, p_startupCost
    $$loaddcm p_price
    $$loaddcm p_emissionPrice
    $$loaddcm p_vomCost
    $$loaddcm p_startupCost
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
    $$loaddcm p_groupPolicyUnit
    $$loaddcm p_groupPolicyEmission
    $$loaddcm gnss_bound
    $$loaddcm uss_bound
    $$loaddcm m
    $$loaddcm mSettings
    $$loaddcm mInterval
    $$loaddcm ms_initial
    $$loaddcm ms_central
    $$loaddcm msStart
    $$loaddcm msEnd
    $$loaddcm p_msProbability
    $$loaddcm p_msWeight
    $$loaddcm p_msAnnuityWeight
    $$loaddcm mz
    $$loaddcm zs
    $$loaddcm gn_forecasts
    $$loaddcm unit_forecasts
    $$loaddcm mf_realization
    $$loaddcm mf_central
    $$loaddcm p_mfProbability
    // search key: activeFeatures
    $$loaddcm active
    $$loaddcm mSettingsReservesInUse
    $$loaddcm mSettingsEff
    $$loaddcm p_roundingTs
    $$loaddcm p_roundingParam
    $$loaddcm node_superpos
    $$loaddcm s_countries
    $$loaddcm s_regions
    $$loaddcm steam_subset_countries
    $$loaddcm s_scenario
    $$loaddcm s_alternative
    $$loaddcm steam_scenarioAlternative
    $$loaddcm s_regional_WACC_avg
    $$loaddcm steam_WACC
    $$loaddcm s_config_parameter
    $$loaddcm s_config_object
    $$loaddcm s_config_value
    $$loaddcm s_config_alternative
    $$loaddcm s_config_info
    $$loaddcm steam_model_config
    $$loaddcm s_node
    $$loaddcm s_terminal
    $$loaddcm s_shipping
    $$loaddcm s_terminal
    $$loaddcm s_terminal_connection
    //$$loaddcm s_regions_n
    //$$loaddcm s_alternative_n
    //$$loaddcm s_x_n
    //$$loaddcm s_y_n
    //$$loaddcm s_geometry_n
    //$$loaddcm s_list_of_countries_n
    //$$loaddcm s_WACC_n
    //$$loaddcm steam_geo_nodes
    //$$loaddcm s_h2_node1_p
    //$$loaddcm s_h2_node2_p
    //$$loaddcm s_commodity_p
    //$$loaddcm s_alternative_p
    //$$loaddcm s_geometry_p
    //$$loaddcm steam_geo_pipelines
    //$$loaddcm s_terminal_name_t
    //$$loaddcm s_node_t
    //$$loaddcm s_commodity_t
    //$$loaddcm s_con_terminal_name_t
    //$$loaddcm s_unit_name_trans_t
    //$$loaddcm s_unit_name_retrans_t
    //$$loaddcm s_region_t
    //$$loaddcm s_alternative_t
    //$$loaddcm s_y_t
    //$$loaddcm s_x_t
    //$$loaddcm s_geometry_t
    //$$loaddcm steam_geo_terminals
    //$$loaddcm s_terminal_name_tc
    //$$loaddcm s_Regions_tc
    //$$loaddcm s_node1_tc
    //$$loaddcm s_node2_tc
    //$$loaddcm s_alternative_tc
    //$$loaddcm s_geometry_tc
    //$$loaddcm steam_geo_terminals_con
    //$$loaddcm s_name_s
    //$$loaddcm s_origin_s
    //$$loaddcm s_destination_s
    //$$loaddcm s_alternative_s
    //$$loaddcm s_geometry_s
    //$$loaddcm steam_geo_shipping
    
    $$gdxin
$endif.debugGdx_v39

// loading new input tables in v3.10
$ifthene.debugGdx_v310 %debugGdx_ver%>3.09
    $$gdxin  '%input_dir%/%input_file_debugGdx%'
    $$loaddcm p_userconstraint
    $$gdxin
$endif.debugGdx_v310

// loading new input tables in v3.11
$ifthene.debugGdx_v311 %debugGdx_ver%>3.10
    $$gdxin  '%input_dir%/%input_file_debugGdx%'
    $$loaddcm ts_gnu_io
    $$loaddcm ts_gnu_circulationRules
    $$loaddcm ts_gnu_activeForecasts
    $$loaddcm ts_gnu_forecastImprovement
    $$gdxin
$endif.debugGdx_v311

// loading new input tables in v3.11
$ifthene.debugGdx_v312 %debugGdx_ver%>3.11
    $$gdxin  '%input_dir%/%input_file_debugGdx%'
    $$loaddcm p_scaling_restype
    $$gdxin
$endif.debugGdx_v312


* checking system error stage, aborting if input data import failed
$if NOT errorfree put log "!!! Error when reading input data from debug gdx";
$if NOT errorfree put log "!!! Abort: Reading debug gdx failed!" /;
$if NOT errorfree $abort Reading debug gdx failed. Please check detailed error messages from backbone.lst

$endif.input_file_debugGdx


* Reads changes or additions from %input_dir%/%changes_inc% file.
* by default, input_dir = input, changes_inc = changes.inc
$ifthen.changesInc exist '%input_dir%/%changes_inc%'
   $$include '%input_dir%/%changes_inc%'
$elseIf.changesInc exist '%changes_inc%'
   $$include '%changes_inc%'
$elseIf.changesInc NOT %changes_inc%=='changes.inc' put log "!!! Changes_inc has a custom value, but the file was not found from input_dir or from direct location. Check Spelling. " /;
$endif.changesInc


* checking system error stage, aborting if input data import failed
$if NOT errorfree put log "!!! Error when reading changes.inc";
$if NOT errorfree put log "!!! Abort: Reading changes.inc failed!" /;
$if NOT errorfree $abort Reading changes.inc failed. Please check detailed error messages from backbone.lst




* --- Checking if there is necessary input data to proceed --------------------

* the list is not a complete requirement, but instead checks three central parameter tables that should have data in every model
$if not defined p_unit $abort 'Mandatory input data missing (p_unit), check inputData.gdx or alternative sources of input data'
$if not defined p_gn $abort 'Mandatory input data missing (p_gn), check inputData.gdx or alternative sources of input data'
$if not defined p_gnu_io $abort 'Mandatory input data missing (p_gnu_io), check inputData.gdx or alternative sources of input data'


* =============================================================================
* --- Preliminary adjustments and checks to data, timeseries ------------------
* =============================================================================

* --- summing vertical ts input to default ones -------------------------------

// ts_influx_vert
$ifthen defined ts_influx_vert
// temporary node set of nodes in ts_influx_vert and ts_influx
option node_tmp < ts_influx_vert;
option node_tmp_ < ts_influx;

// checking that only one source of influx data for each node
loop(node_tmp(node),
    if(sum(node_tmp_(node), 1),
        put log '!!! Error on node ' node.tl:0 /;
        put log '!!! Abort: ts_inlux and ts_influx_vert defined for the same node!' /;
        abort "ts_inlux and ts_influx_vert defined for the same node!"
    );
);

// Adding vertical ts data to default
ts_influx(grid, node_tmp(node), f, t) = ts_influx(grid, node, f, t) + ts_influx_vert(t, grid, node, f);
$endif


// ts_cf_vert
$ifthen defined ts_cf_vert
// temporary node set of nodes in ts_cf_vert
option node_tmp < ts_cf_vert;
option node_tmp_ < ts_cf;

// checking that only one source of cf data each node
loop(node_tmp(node),
    if(sum(node_tmp_(node), 1),
        put log '!!! Error on node ' node.tl:0 /;
        put log '!!! Abort: ts_cf and ts_cf_vert defined for the same node!' /;
        abort "ts_cf and ts_cf_vert defined for the same node!"
    );
);

// Adding vertical ts data to default
ts_cf(flow, node_temp(node), f, t) = ts_cf(flow, node, f, t) + ts_cf_vert(t, flow, node, f);
$endif


* =============================================================================
* --- Preliminary adjustments and checks to node data -------------------------
* =============================================================================

// Check that nodes aren't assigned to multiple grids in p_gn
option gn_tmp < p_gn;
loop(node $ {sum(gn_tmp(grid, node), 1) > 1},
        put log '!!! Error occurred on node ' node.tl:0 '  in p_gn' /;
        loop(gn_tmp(grid, node),
               put log '!!! Error occurred on grid ' grid.tl:0 ' in p_gn' /;
        );
        put log '!!! Abort: Nodes cannot be assigned to multiple grids!' /;
        abort "Nodes cannot be assigned to multiple grids!"
); // END loop(node)

// Check that nodes aren't assigned to multiple grids in p_gnu_io
option gn_tmp < p_gnu_io;
loop(node $ {sum(gn_tmp(grid, node), 1) > 1},
        put log '!!! Error occurred on node ' node.tl:0 ' in p_gnu_io' /;
        loop(gn_tmp(grid, node),
               put log '!!! Error occurred on grid ' grid.tl:0 ' in p_gnu_io' /;
        );
        put log '!!! Abort: Nodes cannot be assigned to multiple grids!' /;
        abort "Nodes cannot be assigned to multiple grids!"
); // END loop(node)


* =============================================================================
* --- Preliminary adjustments and checks link data ----------------------------
* =============================================================================

// Silently replacing 'Eps' with 0 in p_gnn transferCap, transferLoss
p_gnn(grid, from_node, to_node, 'transferCap')
    $ {p_gnn(grid, from_node, to_node, 'transferCap')
       and p_gnn(grid, from_node, to_node, 'transferCap')=0
       }
    = 0;
p_gnn(grid, from_node, to_node, 'transferLoss')
    $ {p_gnn(grid, from_node, to_node, 'transferLoss')
       and p_gnn(grid, from_node, to_node, 'transferLoss')=0
       }
    = 0;


* =============================================================================
* --- Preliminary adjustments and checks to data, units -----------------------
* =============================================================================

// check and warn if unit does not have data in p_unit
option unit_tmp < p_unit;
loop(unit
    $ {%warnings%=1
       and not unit_tmp(unit)
       },
    put log "Warning: Unit " unit.tl:0 " does not have any data in p_unit" /;
    );

// check and warn if all units have zero availability
if({%warnings%=1
    and [sum(unit, p_unit(unit, 'availability')) = 0]
    and [sum(unit, p_unit(unit, 'useTimeseriesAvailability')) = 0]
    },
    put log "Warning: All units have p_unit(unit, 'availability') = 0 and p_unit(unit, 'useTimeseriesAvailability') = 0. Check the data." /;
);


* --- flow units --------------------------------------------------------------

// List units with flows/commodities
unit_flow(unit)${ sum(flow, flowUnit(flow, unit)) }
    = yes;

// Few checks on flow unit input data
// Remove effLevelGroupUnit data from flow units
effLevelGroupUnit(effLevel, effSelector, unit_flow(unit)) = no;

// Remove conversionCoeffs from flow units
p_gnu_io(grid, node, unit_flow(unit), input_output, 'conversionCoeff') = 0;

// Remove effXX and opXX from flow units
p_unit(unit_flow(unit), eff) = 0;
p_unit(unit_flow(unit), op) = 0;


* --- clearing eps values -----------------------------------------------------

// Replacing 'Eps' with 0 in p_gnu_io unitSize and notify
tmp = card(p_gnu_io);
p_gnu_io(grid, node, unit, input_output, 'unitSize')
      $ {p_gnu_io(grid, node, unit, input_output, 'unitSize')
         and p_gnu_io(grid, node, unit, input_output, 'unitSize') = 0
         }
      = 0;
if(%warnings%=1 and tmp > card(p_gnu_io),
    put log "Note: Replacing 'Eps' values with 0 in p_gnu_io('unitSize')" /;
);
// Silently replacing 'Eps' with 0 in p_unit unitCount, opXX
p_unit(unit, 'unitCount')
    $ { p_unit(unit, 'unitCount') and p_unit(unit, 'unitCount') = 0
        }
    = 0;
p_unit(unit, op)
    $ { p_unit(unit, op) and p_unit(unit, op) = 0
        }
    = 0;


* =============================================================================
* --- Active unit, gnu, gnn, and gn -------------------------------------------
* =============================================================================

* --- Active units ------------------------------------------------------------

// if p_unit('isActive') is not set to any unit, assume 1 unless availability is constant zero
if(sum(unit, p_unit(unit, 'isActive'))=0,
    // Set 'isActive' = 1 for all units that have availability > 0 or ts_availability
    p_unit(unit, 'isActive')
        ${ p_unit(unit, 'availability')
           or p_unit(unit, 'useTimeseriesAvailability')
           }
        = 1;
); // END if

// drop data from deactivated units in p_unit
p_unit(unit, param_unit)
    ${ p_unit(unit, 'isActive') = 0 } = 0;

// deactivated units
option unit_tmp_ < p_unit;
unit_deactivated(unit) $ {not unit_tmp_(unit) } = yes;

// Warn if all units get deactivated
if(%warnings% = 1 and card(unit_deactivated) = card(unit_tmp_),
    put log "Warning: Automatic processing deactivated all units. Check p_unit('availability') and p_unit('isActive')." /;
);

// drop data from other relevant input data tables
// ts_unit
ts_unit(unit_deactivated(unit), param_unit, f, t)  = 0;
// utAvailabilityLimits
utAvailabilityLimits(unit_deactivated(unit), t, availabilityLimits) = 0;
// effLevelGroupUnit
effLevelGroupUnit(efflevel, effselector, unit_deactivated(unit)) = no;
// unitUnitEffLevel
unitUnitEffLevel(unit_deactivated(unit), unit_, effLevel) = no;
unitUnitEffLevel(unit_, unit_deactivated(unit), effLevel) = no;
// p_unitConstraint
p_unitConstraint(unit_deactivated(unit), constraint) = 0;
// p_unitConstraintNode
p_unitConstraintNode(unit_deactivated(unit), constraint, node) = 0;

// print amount of deactivated units
if(%warnings%=1 and card(unit_deactivated)>0,
    tmp = card(unit_deactivated);
    put log 'Note: Input data preprocessing deactivated ' tmp:0:0 ' units and removed related data from p_unit, ts_unit, utAvailabilityLimits, effLevelGroupUnit, etc. See unit_deactivated from debug file.' /;
);


* --- Active gnu --------------------------------------------------------------

// if p_gnu_io('isActive') is not set to any gnu, assume that all gnu are active, unless unit deactivated
if(sum((grid, node, unit, input_output), p_gnu_io(grid, node, unit, input_output, 'isActive'))=0,
    // Set of active gnu
    gnu(grid, node, unit)
        ${ sum((input_output, param_gnu), abs(p_gnu_io(grid, node, unit, input_output, param_gnu)) )>0
           and p_unit(unit, 'isActive') }
        = yes;

    // Set 'isActive' = 1 for all active gnu
    p_gnu_io(gnu, 'input', 'isActive')
        ${ sum(param_gnu, abs(p_gnu_io(gnu, 'input', param_gnu)) )>0 }
        = 1;
    p_gnu_io(gnu, 'output', 'isActive')
        ${ sum(param_gnu, abs(p_gnu_io(gnu, 'output', param_gnu)) )>0 }
        = 1;

// if any p_gnu_io('isActive') values are declared, use only those, unless unit deactivated
else
    // Set of active gnu
    gnu(grid, node, unit)
        ${ sum((input_output, param_gnu), abs(p_gnu_io(grid, node, unit, input_output, param_gnu)) )>0
           and sum(input_output, p_gnu_io(grid, node, unit, input_output, 'isActive'))<>0
           and p_unit(unit, 'isActive') }
        = yes;

); // END if

// Separation of gnu into inputs and outputs
gnu_output(gnu)${ sum(param_gnu, abs(p_gnu_io(gnu, 'output', param_gnu)) )>0 } = yes;
gnu_input(gnu)${ sum(param_gnu, abs(p_gnu_io(gnu, 'input', param_gnu)) )>0 } = yes;

// pick values from p_gnu_io to p_gnu used in the calculations
p_gnu(gnu, param_gnu) = sum(input_output, p_gnu_io(gnu, input_output, param_gnu));

// list deactivated gnu
option gnu_tmp < p_gnu_io;
gnu_deactivated(grid, node, unit) $ {gnu_tmp(grid, node, unit) and not gnu(grid, node, unit) } = yes;

// print amount of deactivated gnu
if(%warnings% = 1 and card(gnu_deactivated)>0,
    tmp = card(gnu_deactivated);
    put log 'Note: Input data preprocessing deactivated ' tmp:0:0 ' gnu(grid, node, unit) and did not process their p_gnu_io data. See gnu_deactivated from debug file.' /;
);


* --- Active gnn and gn -------------------------------------------------------

// if p_gnn('isActive') is not set to any gnn, assume default values
if(sum((grid, from_node, to_node), p_gnn(grid, from_node, to_node, 'isActive'))=0,
    // Set 'isActive' = 1 for all p_gnn that have availability > 0 or ts_availability
    p_gnn(grid, from_node, to_node, 'isActive')
        $ { sum(param_gnn,  abs(p_gnn(grid, from_node, to_node, param_gnn))>0 ) }
        = 1;
); // END if

// (grid, node) that has influx time series or constant influx
option gn_influxTs < ts_influx;
gn_influx(grid, node)
    ${ p_gn(grid, node, 'influx')
       or gn_influxTs(grid, node)
       }
    = yes;

// if p_gn('isActive') is not set to any gn, assume 1 if gn has active p_gnn, active p_gnu, or influx
if(sum((grid, node), p_gn(grid, node, 'isActive'))=0,
    // Set 'isActive' = 1 for all p_gn
    p_gn(grid, node, 'isActive')
        ${ sum(param_gn, abs(p_gn(grid, node, param_gn)) )>0
           and [sum(node_, p_gnn(grid, node, node_, 'isActive')) > 0
                or sum(node_, p_gnn(grid, node_, node, 'isActive')) > 0
                or sum(unit, p_gnu(grid, node, unit, 'isActive')) > 0
                or gn_influx(grid, node)
                ]
           }
        = 1;
); // END if

// list original gn
option gn_tmp < p_gn;

// drop data from deactivated gn in p_gn
p_gn(grid, node, param_gn) ${ p_gn(grid, node, 'isActive') = 0 } = 0;

// list deactivated gn
option gn_tmp_ < p_gn;
gn_deactivated(grid, node) $ {gn_tmp(grid, node) and not gn_tmp_(grid, node) } = yes;

// drop corresponding data also in
// p_gnBoundaryPropertiesForStates
p_gnBoundaryPropertiesForStates(gn_deactivated(grid, node), param_gnBoundaryTypes, param_gnBoundaryProperties)  = 0;
// ts_node
ts_node(gn_deactivated(grid, node), param_gnBoundaryTypes, f, t)  = 0;

// print amount of deactivated gn
if(%warnings% = 1 and card(gn_deactivated)>0,
    tmp = card(gn_deactivated);
    put log 'Note: Input data preprocessing deactivated ' tmp:0:0 ' gn(grid, node) and removed related data from p_gn, p_gnBoundaryPropertiesForStates, and ts_node. See gn_deactivated from debug file.' /;
);


// deactivate p_gnn to and from deactivated gn.
// note: This case does not activate automatically, but can occur due to user given values.
p_gnn(grid, from_node, to_node, 'isActive')
    $ { gn_deactivated(grid, from_node)
        or gn_deactivated(grid, to_node)
        }
    = 0;

// list original gnn
option gnn_tmp < p_gnn;

// drop p_gnn data from deactivated links
p_gnn(grid, from_node, to_node, param_gnn)
        ${ p_gnn(grid, from_node, to_node, 'isActive') = 0 }
        = 0;

// list deactivated gnn
option gnn_tmp_ < p_gnn;
gnn_deactivated(grid, from_node, to_node) $ {gnn_tmp(grid, from_node, to_node) and not gnn_tmp_(grid, from_node, to_node) } = yes;

// print amount of deactivated gnn
if(%warnings% = 1 and card(gnn_deactivated)>0,
    tmp = card(gnn_deactivated);
    put log 'Note: Input data preprocessing deactivated ' tmp:0:0 ' gnn(grid, from_node, to_node) and removed their data from p_gnn. See gnn_deactivated from debug file.' /;
);


* =============================================================================
* --- Unit Related Sets & Parameters ------------------------------------------
* =============================================================================

* --- Unit classifications ----------------------------------------------------

// Units connecting gn-gn pairs
gn2gnu(grid, node_input, grid_, node_output, unit)${    gnu_input(grid, node_input, unit)
                                                        and gnu_output(grid_, node_output, unit)
                                                        }
    = yes;

// Units with investment variables
unit_invest(unit) $ { p_unit(unit, 'maxUnitCount') } = yes;

unit_investLP(unit)${ not p_unit(unit, 'investMIP')
                      and unit_invest(unit)
                      }
    = yes;
unit_investMIP(unit)${ p_unit(unit, 'investMIP')
                       and unit_invest(unit)
                       }
    = yes;

// units that are directOff in every effLevel
unit_directOff(unit) $ { [sum(effLevelGroupUnit(effLevel, 'directOff', unit), 1)
                          =  sum(effLevelGroupUnit(effLevel, effSelector, unit), 1)]
                         or [sum(effLevelGroupUnit(effLevel, effSelector, unit), 1) = 0]
                         }
    = yes;


// Units with minimum load requirements
unit_minLoad(unit)${ not unit_deactivated(unit)
                     and not unit_directOff(unit)
                     and p_unit(unit, 'op00') > 0 // If the first defined operating point is between 0 and 1
                     and p_unit(unit, 'op00') < 1
                     // and if unit has online variable, then unit is considered to have minload
                     and sum(effLevel, sum(effOnline, effLevelGroupUnit(effLevel, effOnline, unit)))
                     }
    = yes;

// sources and sinks
unit_source(unit)${p_unit(unit, 'isSource')=1} = yes;
unit_sink(unit)${p_unit(unit, 'isSink')=1} = yes;


* --- Unit related sets -------------------------------------------------------

// Set of nu combinations
option nu < gnu;

// Set of unit time series parameters
option unit_timeseries < ts_unit;
// Deactivating if user did not declare that unit should use the specific time series
unit_timeseries(unit, eff)${ not p_unit(unit, 'useTimeseries') }
    = no;
unit_timeseries(unit, 'availability')${ not p_unit(unit, 'useTimeseriesAvailability') }
    = no;


// Units with special startup properties
// All units can cold start (default start category)
unitStarttype(unit, 'cold') $ {not unit_directOff(unit) }
    = yes;

// Units with parameters regarding hot/warm starts
unitStarttype(unit, starttypeConstrained)${ p_unit(unit, 'startWarmAfterXhours')
                                            or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startCostHot'))
                                            or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsHot'))
                                            or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startCostWarm'))
                                            or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsWarm'))
                                            or p_unit(unit, 'startColdAfterXhours')
                                            and not unit_directOff(unit)
                                            }
    = yes;
// Units consuming energy from particular nodes in start-up
nu_startup(node, unit)$ { p_uStartupfuel(unit, node, 'fixedFuelFraction')
                          and not unit_directOff(unit) }
    = yes;


* --- Unit Related Parameters -------------------------------------------------

// Assume values for critical unit related parameters, if not provided by input data
// If the unit does not have efficiency set, it is 1. Except flow units.
p_unit(unit, 'eff00')${ p_unit(unit, 'isActive')
                        and not unit_flow(unit)
                        and not p_unit(unit, 'eff00') and not p_unit(unit, 'eff01') and not p_unit(unit, 'eff02')}
    = 1;

// Define unit count if empty, except for units with investments allowed.
// if only one active gnu, defined capacity, and defined unitSize: unitCount = capacity / unitSize
p_unit(unit, 'unitCount')${ p_unit(unit, 'isActive')
                            and not p_unit(unit, 'unitCount')
                            and not unit_invest(unit)
                            and [sum(gnu(grid, node, unit), 1) = 1]
                            and [sum((grid, node), p_gnu(grid, node, unit, 'unitSize')) > 0]
                            and [sum((grid, node), p_gnu(grid, node, unit, 'capacity')) > 0]
                            }
    = sum((grid, node), p_gnu(grid, node, unit, 'capacity'))
      / sum((grid, node), p_gnu(grid, node, unit, 'unitSize'));
// if at least one active gnu (has data in p_gnu) with defined capacity: unitCount = 1
p_unit(unit, 'unitCount')${ p_unit(unit, 'isActive')
                            and not p_unit(unit, 'unitCount')
                            and not unit_invest(unit)
                            and [sum((grid, node), p_gnu(grid, node, unit, 'capacity')) > 0]
                            }
    = 1;

// If gnu does not have unitSize, but has capacity and and unit has unitCount,
// calculate gnu unitSize
p_gnu(gnu(grid, node, unit), 'unitSize')
    ${  not p_gnu(grid, node, unit, 'unitSize')
        and [p_gnu(grid, node, unit, 'capacity') > 0]
        and p_unit(unit, 'unitCount')
        }
    = p_gnu(grid, node, unit, 'capacity') / p_unit(unit, 'unitCount');

// Determine unit startup parameters based on data
// Hot startup parameters
p_uNonoperational(unitStarttype(unit, 'hot'), 'min')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = p_unit(unit, 'minShutdownHours');
p_uNonoperational(unitStarttype(unit, 'hot'), 'max')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = p_unit(unit, 'startWarmAfterXhours');
p_uStartup(unitStarttype(unit, 'hot'), 'cost')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startCostHot'));
p_uStartup(unitStarttype(unit, 'hot'), 'consumption')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startFuelConsHot'));

// Warm startup parameters
p_uNonoperational(unitStarttype(unit, 'warm'), 'min')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = p_unit(unit, 'startWarmAfterXhours');
p_uNonoperational(unitStarttype(unit, 'warm'), 'max')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = p_unit(unit, 'startColdAfterXhours');
p_uStartup(unitStarttype(unit, 'warm'), 'cost')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startCostWarm'));
p_uStartup(unitStarttype(unit, 'warm'), 'consumption')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startFuelConsWarm'));

// Cold startup parameters
p_uNonoperational(unitStarttype(unit, 'cold'), 'min')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = p_unit(unit, 'startColdAfterXhours');
p_uStartup(unit, 'cold', 'cost')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startCostCold'));
p_uStartup(unit, 'cold', 'consumption')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'startFuelConsCold'));

// Start-up fuel consumption per fuel
p_unStartup(unit, node, starttype)
    $ { p_uStartupfuel(unit, node, 'fixedFuelFraction')
        and not unit_directOff(unit)
        and not unit_flow(unit)}
    = p_uStartup(unit, starttype, 'consumption')
        * p_uStartupfuel(unit, node, 'fixedFuelFraction');

//shutdown cost parameters
p_uShutdown(unit, 'cost')
    $ { not unit_directOff(unit) and not unit_flow(unit)}
    = sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')
        * p_gnu(grid, node, unit, 'shutdownCost'));

// Unit lifetime
loop(utAvailabilityLimits(unit, t, availabilityLimits),
    p_unit(unit, availabilityLimits) = ord(t)
); // END loop(ut)




* =============================================================================
* --- Node related Sets & Parameters ------------------------------------------
* =============================================================================

* --- Node Connectivity -------------------------------------------------------

// Node pairs connected via transfer links
gn2n(grid, from_node, to_node)${ p_gnn(grid, from_node, to_node, 'isActive')
                                 and [p_gnn(grid, from_node, to_node, 'transferCap')
                                      or p_gnn(grid, from_node, to_node, 'transferLoss')
                                      or p_gnn(grid, from_node, to_node, 'transferCapInvLimit')
                                      or p_gnn(grid, from_node, to_node, 'portion_of_transfer_to_reserve')
                                      ]
                                 }
    = yes;

// Node pairs with relatively bound states
gnn_boundState(grid, node, node_)${ p_gnn(grid, node, node_, 'boundStateMaxDiff') }
    = yes;

// Node pairs connected via energy diffusion
gnn_state(grid, node, node_)${  p_gnn(grid, node, node_, 'diffCoeff')
                                or gnn_boundState(grid, node, node_)
                                }
    = yes;

// Generate the set for transfer links where the order of the first node must be smaller than the order of the second node
Option clear = gn2n_directional;
gn2n_directional(gn2n(grid, node, node_))${ ord(node) < ord(node_) }
    = yes;
gn2n_directional(gn2n(grid, node, node_))${ ord(node) > ord(node_)
                                            and not gn2n(grid, node_, node)
                                            }
    = yes;

// Set for transfer links with investment possibility
Option clear = gn2n_directional_investLP;
Option clear = gn2n_directional_investMIP;
gn2n_directional_investLP(gn2n_directional(grid, node, node_))${ [p_gnn(grid, node, node_, 'transferCapInvLimit')
                                                                     or p_gnn(grid, node_, node, 'transferCapInvLimit')]
                                                                 and [not p_gnn(grid, node, node_, 'investMIP')
                                                                     and not p_gnn(grid, node_, node, 'investMIP')]
                                                                 }
    = yes;
gn2n_directional_investMIP(gn2n_directional(grid, node, node_))${ [p_gnn(grid, node, node_, 'transferCapInvLimit')
                                                                     or p_gnn(grid, node_, node, 'transferCapInvLimit')]
                                                                 and [p_gnn(grid, node, node_, 'investMIP')
                                                                     or p_gnn(grid, node_, node, 'investMIP')]
                                                                 }
    = yes;

// set for transfer links with ramp equations activated
gn2n_directional_ramp(gn2n_directional(grid, from_node, to_node))
    $  {p_gnn(grid, from_node, to_node, 'rampLimit')
        or p_gnn(grid, to_node, from_node, 'rampLimit')
        or sum(group, p_userconstraint(group, grid, from_node, to_node, '-', 'v_transferRamp'))
        }
    = yes;

// copying 'rampLimit' from (node_, node) if (node, node_) is empty
loop(gn2n_directional_ramp(grid, from_node, to_node)
    $ { not p_gnn(grid, from_node, to_node, 'rampLimit')
        and p_gnn(grid, to_node, from_node, 'rampLimit')
        },
    // scaling rampLimit to->from by capacities to calculate equal from->to rampLimit
    p_gnn(grid, from_node, to_node, 'rampLimit') =
    p_gnn(grid, to_node, from_node, 'rampLimit')        // rampLimit to->from
    / p_gnn(grid, to_node, from_node, 'transferCap')    // capacity to->from
    * p_gnn(grid, from_node, to_node, 'transferCap');   // capacity from->to
); // END loop(gn2n_directional_ramp)


* --- Time series parameters for node-node connections ------------------------

// Transfer links with time series enabled for certain parameters
gn2n_timeseries(grid, node, node_, 'availability')${p_gnn(grid, node, node_, 'useTimeseriesAvailability')}
    = yes;
gn2n_timeseries(grid, node, node_, 'transferLoss')${p_gnn(grid, node, node_, 'useTimeseriesLoss')}
    = yes;


* --- Node Classifications ----------------------------------------------------

// States with slack variables
gn_stateSlack(grid, node)
    ${ sum((slack, useConstantOrTimeSeries), p_gnBoundaryPropertiesForStates(grid, node, slack, useConstantOrTimeSeries)) }
    = yes;
gn_stateUpwardSlack(gn_stateSlack(grid, node))
    ${ sum((upwardSlack, useConstantOrTimeSeries), p_gnBoundaryPropertiesForStates(grid, node, upwardSlack, useConstantOrTimeSeries)) }
    = yes;
gn_stateDownwardSlack(grid, node)
    ${ sum((downwardSlack, useConstantOrTimeSeries), p_gnBoundaryPropertiesForStates(grid, node, downwardSlack, useConstantOrTimeSeries)) }
    = yes;

// Nodes with states
gn_state(grid, node)${  gn_stateSlack(grid, node)
                        or p_gn(grid, node, 'energyStoredPerUnitOfState')
                        or sum((stateLimits, useConstantOrTimeSeries), p_gnBoundaryPropertiesForStates(grid, node, stateLimits, useConstantOrTimeSeries))
                        or sum(useConstantOrTimeSeries, p_gnBoundaryPropertiesForStates(grid, node, 'reference', useConstantOrTimeSeries))
                        }
    = yes;

// Existing grid-node pairs
gn(grid, node)${    sum(unit, gnu(grid, node, unit))
                    or gn_influx(grid, node)
                    or gn_state(grid, node)
                    or p_gn(grid, node, 'isActive')
                    or sum(node_, gn2n(grid, node, node_))
                    or sum(node_, gn2n(grid, node_, node))
                    or sum(node_, gnn_state(grid, node, node_))
                    or sum(node_, gnn_state(grid, node_, node))
                    }
    = yes;

gn_balance(grid, node) $ {not p_gn(grid, node, 'boundAll')
                          and p_gn(grid, node, 'nodeBalance') }
    = yes;

// Nodes with spill permitted
node_spill(node)${ sum((grid, spillLimits), p_gnBoundaryPropertiesForStates(grid, node, spillLimits, 'useTimeseries'))
                   or [sum((grid, spillLimits), p_gnBoundaryPropertiesForStates(grid, node, spillLimits, 'useConstant'))
                       and sum((grid, spillLimits), p_gnBoundaryPropertiesForStates(grid, node, spillLimits, 'constant')) > 0
                       ]
                   }
    = yes;

// Nodes that have units with investment energy cost
node_invEnergyCost(node)${sum((grid, unit), p_gnu(grid, node, unit, 'invEnergyCost'))<>0}
    = yes;

// Nodes that have units with startup energy cost
option node_startupEnergyCost < nu_startup;

// Nodes with flows
option flowNode < ts_cf;
flowNode(flow, node)${ not sum(grid, gn(grid, node))
                       }
    = no;

// Nodes with balance and time series for boundary properties activated
gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)
    ${p_gn(grid, node, 'nodeBalance')
      and p_gnBoundaryPropertiesForStates(grid, node, param_gnBoundaryTypes, 'useTimeseries')
      }
    = yes;


* --- Node parameters ---------------------------------------------------------

// Assume values for critical node related parameters, if not provided by input data
// Boundary multiplier
p_gnBoundaryPropertiesForStates(gn(grid, node), param_gnBoundaryTypes, 'multiplier')${  not p_gnBoundaryPropertiesForStates(grid, node, param_gnBoundaryTypes, 'multiplier')
                                                                                        and sum(param_gnBoundaryProperties, p_gnBoundaryPropertiesForStates(grid, node, param_gnBoundaryTypes, param_gnBoundaryProperties))
    } = 1; // If multiplier has not been set, set it to 1 by default


* =============================================================================
* --- Node price Related Sets & Parameters ------------------------------------
* =============================================================================

* --- check that data is given either in old or new input tables --------------

tmp = card(ts_price) + card(ts_priceChange) + card(ts_emissionPrice) + card(ts_emissionPriceChange);
tmp_ = card(ts_priceNew) + card(ts_priceChangeNew) + card(ts_emissionPriceNew) + card(ts_emissionPriceChangeNew);

if( tmp>0 and tmp_>0,
    put log '!!! Error occurred on price and/or emission price input data' /;
    put log '!!! Abort: The old and new price input tables cannot be used simultaneously' /;
    abort "Must choose between (ts_price, ts_priceChange, ts_emissionPrice, ts_emissionPriceChange) and (ts_priceNew, ts_priceChangeNew, ts_emissionPriceNew, ts_emissionPriceChangeNew)! "
); // END if


* --- ts_price and ts_priceChange ---------------------------------------------

// checking nodes that have price data in two optional input data tables
option node_tmp < ts_price;
option node_tmp_ < ts_priceChange;

// Abort of input data for prices are given both ts_price and ts_priceChange
loop(node_tmp(node)$node_tmp_(node),
    put log '!!! Error occurred on ', node.tl:0 /;
    put log '!!! Abort: Node ', node.tl:0, ' has both ts_price and ts_priceChange' /;
    abort "Only ts_price or ts_priceChange can be given to a node"
);  // END loop(node)

// Process node prices depending on 'ts_price' if usePrice flag activated
loop(node_tmp(node) $ { sum(grid, p_gn(grid, node, 'usePrice'))},

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_price(node, t) } = yes;

    // If only up to a single value
    if({sum(tt, 1) <= 1 },
        p_price(node, 'useConstant') = 1; // Use a constant for node prices
        p_price(node, 'price') = sum(tt, ts_price(node, tt)) // Determine the price as the only value in the time series

    // If multiple values found, use time series. Values already given in input data.
    else
        p_price(node, 'useTimeSeries') = 1;
      ); // END if(sum(tt_))
); // END loop(node)

// Process node prices depending on 'ts_priceChange' if usePrice flag activated
loop(node_tmp_(node)$ { sum(grid, p_gn(grid, node, 'usePrice'))},

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_priceChange(node, t) } = yes;

    // If only up to a single value
    if({sum(tt, 1) <= 1 },
        p_price(node, 'useConstant') = 1; // Use a constant for node prices
        p_price(node, 'price') = sum(tt, ts_priceChange(node, tt)) // Determine the price as the only value in the time series

    // If multiple values found, use time series. Values processed in 3a_periodicInit
    else
        p_price(node, 'useTimeSeries') = 1;
      ); // END if(sum(tt_))
); // END loop(node)


* --- ts_priceNew and ts_priceChangeNew ---------------------------------------

// checking nodes that have price data in two optional input data tables
option node_tmp < ts_priceNew;
option node_tmp_ < ts_priceChangeNew;

// temporary sets for f that has price data
Option ff < ts_priceNew;
Option ff_ < ts_priceChangeNew;

// Abort of input data for prices are given both ts_priceNew and ts_priceChangeNew
loop(node_tmp(node)$node_tmp_(node),
    put log '!!! Error occurred on ', node.tl:0 /;
    put log '!!! Abort: Node ', node.tl:0, ' has both ts_priceNew and ts_priceChangeNew' /;
    abort "Only ts_priceNew or ts_priceChangeNew can be given to a node"
);  // END loop(node)

// Process node prices depending on 'ts_priceNew' if usePrice flag activated
loop((node_tmp(node), ff(f)) $ { sum(grid, p_gn(grid, node, 'usePrice'))
                                 },

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_priceNew(node, f, t) } = yes;

    // processing only if (node, f) combination has data
    if(sum(tt, abs(ts_priceNew(node, f, tt))>0),
        // If only up to a single value
        if({sum(tt, 1) <= 1 },
            p_priceNew(node, f, 'useConstant') = 1; // Use a constant for node prices
            p_priceNew(node, f, 'price') = sum(tt, ts_priceNew(node, f, tt)) // Determine the price as the only value in the time series

        // If multiple values found, use time series. Values already given in input data.
        else
            p_priceNew(node, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt, 1))
    ); // END(if(sum(tt, ts_priceNew))
); // END loop(node)

// Process node prices depending on 'ts_priceChange' if usePrice flag activated
loop((node_tmp_(node), ff_(f))$ { sum(grid, p_gn(grid, node, 'usePrice'))},

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_priceChangeNew(node, f, t) } = yes;

    // processing only if (node, f) combination has data
    if(sum(tt, abs(ts_priceChangeNew(node, f, tt))>0),
        // If only up to a single value
        if({sum(tt, 1) <= 1 },
            p_priceNew(node, f, 'useConstant') = 1; // Use a constant for node prices
            p_priceNew(node, f, 'price') = sum(tt, ts_priceChangeNew(node, f, tt)) // Determine the price as the only value in the time series

        // If multiple values found, use time series. Values processed in 3a_periodicInit
        else
            p_priceNew(node, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt, 1))
    ); // END(if(sum(tt, ts_priceChangeNew))
); // END loop(node)





* =============================================================================
* --- gnu related Sets & Parameters -------------------------------------------
* =============================================================================

// Set of gnu time series parameters
option gnu_timeseries < ts_gnu_io;
// excluding deactivated gnu
gnu_timeseries(gnu_deactivated(grid, node, unit), param_gnu) = no;

// gnu with delays
gnu_delay(gnu) $ p_gnu(gnu, 'delay') = yes;



* --- cb and cv, checks and classifications -----------------------------------

// temporary set for units that have unitconstraints. Calculated before the loop.
option unit_tmp < p_unitConstraintNode;
// check that unit does not have any previous unitConstraints
loop(unit
    $ { sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'cb'))
        and unit_tmp(unit)
        },
    put log "!!! Error occured on unit '" unit.tl:0"'" /;
    put log "!!! Abort: Units with p_gnu_io('cb') cannot have any data in p_unitConstraintNode. Enter all data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
    abort "Units with p_gnu_io('cb') cannot have any data in p_unitConstraintNode. Enter all data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
); // END loop(unit)

// loop units that have p_gnu('cb') for any of the outputs
loop(unit $ sum(gnu_output(grid, node, unit), p_gnu(grid, node, unit, 'cb')),

    // check that unit has exactly two outputs
    if(sum(gnu_output(grid, node, unit), 1) <> 2,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cb') must have exactly two outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cb') must have exactly two outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // check that only one of the outputs have 'cb'
    option clear = gnu_tmp;
    gnu_tmp(gnu_output(grid, node, unit))
        $ p_gnu_io(grid, node, unit, 'output', 'cb')
        = yes;
    if(card(gnu_tmp) > 1,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cb') can have 'cb' for only one of the outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cb') can have 'cb' for only one of the outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // flag gnu as gnu_cb
    gnu_cb(gnu_tmp(grid, node, unit)) = yes;

    // check that cb is positive
    loop(gnu_cb(grid, node, unit)
          $ { p_gnu(grid, node, unit, 'cb')
              and not [p_gnu(grid, node, unit, 'cb') > 0]
              },
        put log "!!! Error occured on grid, node, unit ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
        put log "!!! Abort: p_gnu_io('cb') Must be positive number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "p_gnu_io('cb') Must be positive number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

); // END loop(unit $ p_gnu('output', 'cb') )


// loop units that have p_gnu('cv') for any of the outputs
loop(unit $ sum(gnu_output(grid, node, unit), p_gnu(grid, node, unit, 'cv')),

    // check that only one of the outputs have 'cv'
    option clear = gnu_tmp;
    gnu_tmp(gnu_output(grid, node, unit))
        $ p_gnu_io(grid, node, unit, 'output', 'cv')
        = yes;
    if(card(gnu_tmp) > 1,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cv') can have 'cv' for only one of the outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cv') can have 'cv' for only one of the outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // flag gnu as gnu_cv
    gnu_cv(gnu_tmp(grid, node, unit)) = yes;

    // check that cv is negative
    loop(gnu_cv(grid, node, unit)
          $ { p_gnu(grid, node, unit, 'cv')
              and not [p_gnu(grid, node, unit, 'cv') < 0]
              },
        put log "!!! Error occured on grid, node, unit ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
        put log "!!! Abort: p_gnu_io('cv') Must be negative number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "p_gnu_io('cv') Must be negative number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // check that unit has gnu_cb for the same output gnu
    if( sum(gnu_cb(gnu_cv(grid, node, unit)), 1) = 0,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cv') must have p_gnu_io(gnu, 'output, 'cb') for the same gnu. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cv') must have p_gnu_io(gnu, 'output, 'cb') for the same gnu. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // Check that output with cv has capacity defined
    loop(gnu_cv(grid, node, unit) $ {p_gnu(grid, node, unit, 'capacity') = 0},
        put log "!!! Error occured on gnu ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cv') must have defined 'capacity' for all inputs and outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cv') must have defined 'capacity' for both outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // Check that all inputs have capacity defined
    loop(gnu_input(grid, node, unit) $ {p_gnu(grid, node, unit, 'capacity') = 0},
        put log "!!! Error occured on gnu ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cv') must have defined 'capacity' for all inputs and outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cv') must have defined 'capacity' for both outputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // Check that input conversionCoeff = 1
    loop(gnu_input(grid, node, unit) $ {p_gnu(grid, node, unit, 'conversionCoeff') <> 1},
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'output, 'cv') must have p_gnu_io(gnu, 'input, 'conversionCoeff') = 1 for all input gnu. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'output, 'cv') must have p_gnu_io(gnu, 'input, 'conversionCoeff') = 1 for all input gnu. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    ); // END loop(gnu_input)

); // END loop(unit $ p_gnu('output', 'cv') )


// loop units that have p_gnu('cb') for any of the inputs
loop(unit $ sum(gnu_input(grid, node, unit), p_gnu(grid, node, unit, 'cb')),

    // check that unit has exactly two inputs
    if(sum(gnu_input(grid, node, unit), 1) <> 2,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'input, 'cb') must have exactly two inputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'input, 'cb') must have exactly two inputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // check that only one of the inputs have 'cb'
    option clear = gnu_tmp;
    gnu_tmp(gnu_input(grid, node, unit))
        $ p_gnu_io(grid, node, unit, 'input', 'cb')
        = yes;
    if(card(gnu_tmp) > 1,
        put log "!!! Error occured on unit '" unit.tl:0"'" /;
        put log "!!! Abort: Units with p_gnu_io(gnu, 'input, 'cb') can have 'cb' for only one of the inputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "Units with p_gnu_io(gnu, 'input, 'cb') can have 'cb' for only one of the inputs. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

    // flag gnu as gnu_cb
    gnu_cb(gnu_tmp(grid, node, unit)) = yes;

    // check that cb is positive
    loop(gnu_cb(grid, node, unit)
          $ { p_gnu(grid, node, unit, 'cb')
              and not [p_gnu(grid, node, unit, 'cb') > 0]
              },
        put log "!!! Error occured on grid, node, unit ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
        put log "!!! Abort: p_gnu_io('cb') Must be positive number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
        abort "p_gnu_io('cb') Must be positive number. Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
    );

); // END loop(unit $ p_gnu('input', 'cb') )


// check that units do not have  p_gnu('cv') for inputs
loop(gnu_input(grid, node, unit) $ p_gnu(grid, node, unit, 'cv'),
    put log "!!! Error occured on grid, node, unit ('" grid.tl:0"', '" node.tl:0"', '" unit.tl:0"')" /;
    put log "!!! Abort: Input gnu cannot have p_gnu_io('cv'). Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations !!!" /;
    abort "Input gnu cannot have p_gnu_io('cv'). Enter data to p_unitConstraint and unitConstraintNode manually for non-default configurations."
);

* --- cb and cv equations for outputs -----------------------------------------

// loop units with output gnu in gnu_cb
loop(unit $ sum(gnu_output(grid, node, unit), gnu_cb(grid, node, unit)),

    // classify node_tmp as the main output for cb and node_tmp_ as a secondary output
    // note: previously checked that unit has exactly two outputs and that cv is for the same gnu than cv
    option clear = node_tmp;
    node_tmp(node)
        $ {nu(node, unit)
           and sum(grid, gnu_output(grid, node, unit))
           and sum(grid, gnu_cb(grid, node, unit))
           }
        = yes;
    option clear = node_tmp_;
    node_tmp_(node)
        $ {nu(node, unit)
           and sum(grid, gnu_output(grid, node, unit))
           and not sum(grid, gnu_cb(grid, node, unit))
           }
        = yes;

    // set p_unitConstraintNode for node_tmp (1) and node_tmp_ (1 / 'cb')
    // e.g. power (main output) to heat (secondary output) with
    // ratio 0.5 (1 electricity, 2 heat) -> cb = 0.5

    // using 'gt1' if cv has been defined
    if(sum(gnu_output(grid, node, unit), gnu_cv(grid, node, unit)),
        p_unitConstraintNode(unit, 'gt1', node_tmp)
            = 1;
        p_unitConstraintNode(unit, 'gt1', node_tmp_)
            = -1 * sum( (grid, node_tmp), p_gnu(grid, node_tmp, unit, 'cb') );
    // and eq1 if cv has not been defined
    else
        p_unitConstraintNode(unit, 'eq1', node_tmp)
            = 1;
        p_unitConstraintNode(unit, 'eq1', node_tmp_)
            = -1 * sum( (grid, node_tmp), p_gnu(grid, node_tmp, unit, 'cb') );
    ); // END if

    // pick max. efficiency to tmp to avoid repeated looping
    tmp = smax(eff, p_unit(unit, eff));

    //  if unit (cb/cv main node) has cv defined, recalculate conversionCoeff for main output
    // capacity input * efficiency / capacity main output
    p_gnu(gnu_cv(grid, node_tmp, unit), 'conversionCoeff')
        = sum(gnu_input(grid_, node_, unit), p_gnu(grid_, node_, unit, 'capacity'))
            * tmp
            / p_gnu(grid, node_tmp, unit, 'capacity');

    // calculate cv unit max secondary output by calculating where cv and cb will cross
    // gen_1st < cap_1st + cv * gen_2nd
    // gen_1st > cb * gen_2nd
    // -> max gen_2nd = cap_1st / (cb - cv)
    tmp_ = sum(gnu_output(grid, node_tmp, unit), p_gnu(grid, node_tmp, unit, 'capacity'))
           / [sum(gnu_output(grid, node_tmp, unit), p_gnu(grid, node_tmp, unit, 'cb'))
              - sum(gnu_output(grid, node_tmp, unit), p_gnu(grid, node_tmp, unit, 'cv'))
              ];

    // pick gnu_ouput to gnu_tmp to allow more summing over another gnu_output
    option gnu_tmp < gnu_output;

    // if unit (cb/cv main node) has cv defined, recalculate conversionCoeff for secondary output:
    // [capacity input * efficiency
    //  - max gen_2nd * cb * conversionCoeff_1st]
    // / max gen_2nd
    p_gnu(gnu_output(grid, node_tmp_, unit), 'conversionCoeff')
        $ { sum(gnu_tmp(grid_, node_tmp, unit), gnu_cv(grid_, node_tmp, unit)) }
        = [sum(gnu_input(grid_, node_, unit), p_gnu(grid_, node_, unit, 'capacity'))
             * tmp
           - tmp_
             * sum(gnu_tmp(grid_, node_tmp, unit), p_gnu(grid_, node_tmp, unit, 'cb'))
             * sum(gnu_tmp(grid_, node_tmp, unit), p_gnu(grid_, node_tmp, unit, 'conversionCoeff'))
           ] / tmp_;


); // END loop(units that have p_gnu('output', 'cb') )


* --- cb for inputs -----------------------------------------------------------


// loop units with input gnu in gnu_cb
loop(unit $ sum(gnu_input(grid, node, unit), gnu_cb(grid, node, unit)),

    // classify node_tmp as the main input for cb and node_tmp_ as a secondary input
    // note: previously checked that unit has exactly two inputs
    option clear = node_tmp;
    node_tmp(node)
        $ {nu(node, unit)
           and sum(grid, gnu_input(grid, node, unit))
           and sum(grid, gnu_cb(grid, node, unit))
           }
        = yes;
    option clear = node_tmp_;
    node_tmp_(node)
        $ {nu(node, unit)
           and sum(grid, gnu_input(grid, node, unit))
           and not sum(grid, gnu_cb(grid, node, unit))
           }
        = yes;

    // set p_unitConstraintNode for node_tmp (1) and node_tmp_ (1 / 'cb')
    // e.g. power (main output) to heat (secondary output) with
    // ratio 0.5 (1 electricity, 2 heat) -> cb = 0.5
    // Note: using 'eq2' to allow simultaneous use with output 'cb'
    p_unitConstraintNode(unit, 'eq2', node_tmp)
        = 1;
    p_unitConstraintNode(unit, 'eq2', node_tmp_)
        = -1 * sum( (grid, node_tmp), p_gnu(grid, node_tmp, unit, 'cb') );

); // END loop(units that have p_gnu('output', 'cb') )



* --- Constraint Related Sets and Parameters ----------------------------------

// checking that data for the same (unit, constraint) is not given in two sources
loop((unit, constraint) $ {p_unitConstraint(unit, constraint)
                           and sum(param_constraint, p_unitConstraintNew(unit, constraint, param_constraint))
                           },
    put log '!!! Error occurred on unit ' unit.tl:0 ', constraint' constraint.tl:0 /;
    put log '!!! Abort: Data for the same (unit, constraint) is given in both p_unitConstraint and p_unitConstraintNew!' /;
    abort "Data for each (unit, constraint) should be given either p_unitConstraint or p_unitConstraintNew!"
    );  // END loop(unit, constraint)

// summing p_unitConstraint to p_unitConstraintNew('constant')
p_unitConstraintNew(unit, constraint, 'constant')${p_unitConstraint(unit, constraint)<>0}
    = p_unitConstraint(unit, constraint);

// assuming p_unitConstraintNew('onlineMultiplier') = 1 if no data given
p_unitConstraintNew(unit, constraint, 'onlineMultiplier')
    $ {p_unitConstraintNew(unit, constraint, 'constant')
       and not p_unitConstraintNew(unit, constraint, 'onlineMultiplier')}
    = 1;

// form a set of units, their eq/gt/lt constraints, and nodes
option unit_tsConstraintNode < ts_unitConstraintNode;

// form a set of units and their eq/gt/lt constraints
option unit_tsConstraint < ts_unitConstraint;
unitConstraint(unit, constraint)$ { unit_tsConstraint(unit, constraint)
                                    or sum(param_constraint, abs(p_unitConstraintNew(unit, constraint, param_constraint))<>0)
                                    or sum(node, abs(p_unitConstraintNode(unit, constraint, node)))
                                    or sum(node, unit_tsConstraintNode(unit, constraint, node)) }
    = yes;

// Filtering (constraint, gnu) combinations
gnu_eqConstrained(eq_constraint, grid, node, unit) $ { p_unitConstraintNode(unit, eq_constraint, node)
                                                       and gnu(grid, node, unit) }
    = yes;

gnu_gtConstrained(gt_constraint, grid, node, unit) $ { p_unitConstraintNode(unit, gt_constraint, node)
                                                       and gnu(grid, node, unit) }
    = yes;

gnu_ltConstrained(lt_constraint, grid, node, unit) $ { p_unitConstraintNode(unit, lt_constraint, node)
                                                       and gnu(grid, node, unit) }
    = yes;



* =============================================================================
* --- Emission related Sets & Parameters --------------------------------------
* =============================================================================

* --- ts_emissionPrice and ts_emissionPriceChange -----------------------------

// checking emissions and groups that have price data in two optional input data tables
Option emission_tmp < ts_emissionPrice;
Option emission_tmp_ < ts_emissionPriceChange;
Option group_tmp < ts_emissionPrice;
Option group_tmp_ < ts_emissionPriceChange;

// Abort if input data for prices are given both ts_emissionPrice and ts_emissionPriceChange
loop((emission, group) $ {emission_tmp(emission)
                          and emission_tmp_(emission)
                          and group_tmp(group)
                          and group_tmp_(group)
                          },
    put log '!!! Error occurred on emissionGroup(' emission.tl:0 ', ' group.tl:0, ')' /;
    put log '!!! Abort: emissionGroup(' emission.tl:0 ', ' group.tl:0, ') has both ts_emissionPrice and ts_emissionPriceChange' /;
    abort "Only ts_emissionPrice or ts_emissionPriceChange can be given to an emission"
); // END loop(emission)

// populating emissionGroup.
emissionGroup(emission, group)${ [emission_tmp(emission) and group_tmp(group)]
                                 or [emission_tmp_(emission) and group_tmp_(group)]
                                 or p_groupPolicyEmission(group, 'emissionCap', emission)
                               }
    = yes;

// emissionGroup prices from ts_emissionPrice
loop(emissionGroup(emission_tmp(emission), group),

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_emissionPrice(emission, group, t) } = yes;

    // If only up to a single value
    if(sum(tt, 1) <= 1,
        p_emissionPrice(emission, group, 'useConstant') = 1; // Use a constant for node prices
        p_emissionPrice(emission, group, 'price') = sum(tt, ts_emissionPrice(emission, group, tt)) // Determine the price as the only value in the time series
    // If multiple values found, use time series. Values already given in input data.
    else
        p_emissionPrice(emission, group, 'useTimeSeries') = 1;
    ); // END if(sum(tt))
); // END loop(emissionGroup)

// emissionGroup prices from ts_emissionPriceChange
loop(emissionGroup(emission_tmp_(emission), group),

    // Find the steps with changing node prices
    option clear = tt;
    tt(t)${ ts_emissionPriceChange(emission, group, t) } = yes;

    // If only up to a single value
    if(sum(tt, 1) <= 1,
        p_emissionPrice(emission, group, 'useConstant') = 1; // Use a constant for node prices
        p_emissionPrice(emission, group, 'price') = sum(tt, ts_emissionPriceChange(emission, group, tt)) // Determine the price as the only value in the time series
    // If multiple values found, use time series. Values processed in 3a_periodicInit
    else
        p_emissionPrice(emission, group, 'useTimeSeries') = 1;
    ); // END if(sum(tt))
); // END loop(emissionGroup)


* --- ts_emissionPriceNew and ts_emissionPriceChangeNew ---------------------

// checking emissions and groups that have price data in two optional input data tables
Option emission_tmp < ts_emissionPriceNew;
Option emission_tmp_ < ts_emissionPriceChangeNew;
Option group_tmp < ts_emissionPriceNew;
Option group_tmp_ < ts_emissionPriceChangeNew;

// temporary sets for f that has price data
Option ff < ts_emissionPriceNew;
Option ff_ < ts_emissionPriceChangeNew;

// Abort if input data for prices are given both ts_emissionPriceNew and ts_emissionPriceChangeNew
loop((emission, group) $ {emission_tmp(emission)
                          and emission_tmp_(emission)
                          and group_tmp(group)
                          and group_tmp_(group)
                          },
    put log '!!! Error occurred on emissionGroup(' emission.tl:0 ', ' group.tl:0, ')' /;
    put log '!!! Abort: emissionGroup(' emission.tl:0 ', ' group.tl:0, ') has both ts_emissionPriceNew and ts_emissionPriceChangeNew' /;
    abort "Only ts_emissionPriceNew or ts_emissionPriceChangeNew can be given to an emissionGroup"
); // END loop(emission)

// populating emissionGroup.
emissionGroup(emission, group)${ [emission_tmp(emission) and group_tmp(group)]
                                 or [emission_tmp_(emission) and group_tmp_(group)]
                                 or p_groupPolicyEmission(group, 'emissionCap', emission)
                               }
    = yes;

// emissionGroup prices from ts_emissionPriceNew
loop((emissionGroup(emission_tmp(emission), group), ff(f)),

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_emissionPriceNew(emission, group, f, t) } = yes;

    // processing only if (emission, group, f) combination has data
    if(sum(tt, abs(ts_emissionPriceNew(emission, group, f, tt))>0),
        // If only up to a single value
        if(sum(tt, 1) <= 1,
            p_emissionPriceNew(emission, group, f, 'useConstant') = 1; // Use a constant for node prices
            p_emissionPriceNew(emission, group, f, 'price') = sum(tt, ts_emissionPriceNew(emission, group, f, tt)) // Determine the price as the only value in the time series
        // If multiple values found, use time series. Values already given in input data.
        else
            p_emissionPriceNew(emission, group, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt))
    ); // END(if(sum(tt, ts_emissionPriceNew))
); // END loop(emissionGroup)

// emissionGroup prices from ts_emissionPriceChangeNew
loop((emissionGroup(emission_tmp_(emission), group), ff(f)),

    // Find the steps with changing node prices
    option clear = tt;
    tt(t)${ ts_emissionPriceChangeNew(emission, group, f, t) } = yes;

    // processing only if (emission, group, f) combination has data
    if(sum(tt, abs(ts_emissionPriceChangeNew(emission, group, f, tt))>0),
        // If only up to a single value
        if(sum(tt, 1) <= 1,
            p_emissionPriceNew(emission, group, f, 'useConstant') = 1; // Use a constant for node prices
            p_emissionPriceNew(emission, group, f, 'price') = sum(tt, ts_emissionPriceChangeNew(emission, group, f, tt)) // Determine the price as the only value in the time series
        // If multiple values found, use time series. Values processed in 3a_periodicInit
        else
            p_emissionPriceNew(emission, group, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt))
    ); // END(if(sum(tt, ts_emissionPriceChangeNew))
); // END loop(emissionGroup)


* =============================================================================
* --- Reserves Sets & Parameters ----------------------------------------------
* =============================================================================
// NOTE! Reserves can be disabled through the model settings file.
// The sets are disabled in "3a_periodicInit.gms" accordingly.

* --- Correct values for critical reserve related parameters - Part 1 ---------

// Reserve activation duration assumed to be 1 hour if not provided in data
p_groupReserves(group, restype, 'reserve_activation_duration')
    ${  not p_groupReserves(group, restype, 'reserve_activation_duration')
        and p_groupReserves(group, restype, 'reserve_length')
        }
    = 1;
// Reserve reactivation time assumed to be 1 hour if not provided in data
p_groupReserves(group, restype, 'reserve_reactivation_time')
    ${  not p_groupReserves(group, restype, 'reserve_reactivation_time')
        and p_groupReserves(group, restype, 'reserve_length')
        }
    = 1;

* --- Copy reserve data and create necessary sets -----------------------------

// Copy data from p_groupReserves to p_gnReserves
p_gnReserves(grid, node, restype, param_policy) =
    sum(gnGroup(grid, node, group)${sum(restype_, p_groupReserves(group, restype_, 'reserve_length'))},
        p_groupReserves(group, restype, param_policy)
    );

// Units with reserve provision capabilities
gnu_resCapable(restypeDirection(restype, up_down), gnu(grid, node, unit))
    $ { p_gnuReserves(grid, node, unit, restype, up_down)
      }
  = yes;

// Units with reserve provision capabilities
option unit_resCapable < gnu_resCapable;

// Units with offline reserve provision capabilities
gnu_offlineResCapable(restype, gnu(grid, node, unit))
    $ { p_gnuReserves(grid, node, unit, restype, 'offlineReserveCapability')
      }
  = yes;

// Restypes with offline reserve provision possibility
offlineRes(restype)
    $ {sum(gnu(grid, node, unit),  p_gnuReserves(grid, node, unit, restype, 'offlineReserveCapability'))
      }
  = yes;

// Units with offline reserve provision possibility
unit_offlineRes(unit)
    $ {sum((gn(grid, node), restype),  p_gnuReserves(grid, node, unit, restype, 'offlineReserveCapability'))
      }
  = yes;

// Node-node connections with reserve transfer capabilities
restypeDirectionGridNodeNode(restypeDirection(restype, up_down), gn2n(grid, node, node_))
    $ { p_gnnReserves(grid, node, node_, restype, up_down)
      }
  = yes;

// Nodes with reserve requirements, units capable of providing reserves, or reserve capable connections
restypeDirectionGridNode(restypeDirection(restype, up_down), gn(grid, node))
    $ { p_gnReserves(grid, node, restype, up_down)
        or p_gnReserves(grid, node, restype, 'useTimeSeries')
        or sum(gnu(grid, node, unit), p_gnuReserves(grid, node, unit, restype, 'portion_of_infeed_to_reserve'))
        or sum(gnu(grid, node, unit), gnu_resCapable(restype, up_down, grid, node, unit))
        or sum(gn2n(grid, node, to_node), restypeDirectionGridNodeNode(restype, up_down, grid, node, to_node))
      }
  = yes;

// Groups with reserve requirements
restypeDirectionGroup(restypeDirection(restype, up_down), group)
    $ { p_groupReserves(group, restype, 'reserve_length')
      }
  = yes;
restypeDirectionGridNodeGroup(restypeDirection(restype, up_down), gnGroup(grid, node, group))
    $ { p_groupReserves(group, restype, 'reserve_length')
      }
  = yes;

* --- Correct values for critical reserve related parameters - Part 2 ---------

// Reserve reliability assumed to be perfect if not provided in data
p_gnuReserves(gnu(grid, node, unit), restype, 'reserveReliability')
    ${  not p_gnuReserves(grid, node, unit, restype, 'reserveReliability')
        and sum(up_down, gnu_resCapable(restype, up_down, grid, node, unit))
        }
    = 1;

// Reserve provision overlap decreases the capacity of the overlapping category
loop(restype,
p_gnuReserves(gnu(grid, node, unit), restype, up_down)
    ${ gnu_resCapable(restype, up_down, grid, node, unit) }
    = p_gnuReserves(grid, node, unit, restype, up_down)
        - sum(restype_${ p_gnuRes2Res(grid, node, unit, restype_, up_down, restype) },
            + p_gnuReserves(grid, node, unit, restype_, up_down)
                * p_gnuRes2Res(grid, node, unit, restype_, up_down, restype)
        ); // END sum(restype_)
);


* --- reserve price data ------------------------------------------------------

// temporary sets for (restype, up_down, group) that has price data
Option restypeDirectionGroup_tmp < ts_reservePrice;
Option restypeDirectionGroup_tmp_ < ts_reservePriceChange;

// temporary sets for f that has price data
Option ff < ts_reservePrice;
Option ff_ < ts_reservePriceChange;

// Process restypeDirectionGroup that has data in 'ts_reservePrice'
loop((restypeDirectionGroup_tmp(restype, up_down, group), ff(f))
       $ {p_groupReserves(group, restype, 'usePrice')
       },

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_reservePrice(restype, up_down, group, f, t) } = yes;

    // processing only if (restype, up_down, group, f) combination has data
    if(sum(tt, abs(ts_reservePrice(restype, up_down, group, f, tt))>0),
        // If only up to a single value
        if(sum(tt, 1) <= 1,
            p_reservePrice(restype, up_down, group, f, 'useConstant') = 1; // Use a constant for node prices
            p_reservePrice(restype, up_down, group, f, 'price') = sum(tt, ts_reservePrice(restype, up_down, group, f, tt)) // Determine the price as the only value in the time series
        // If multiple values found, use time series. Values already given in input data.
        else
            p_reservePrice(restype, up_down, group, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt))
    ); // END(if(sum(tt, ts_reservePrice))
); // END loop(restype, up_down, group, f)

// Process reserve prices depending on 'ts_reservePriceChange'
loop((restypeDirectionGroup_tmp_(restype, up_down, group), ff_(f))
       $ {p_groupReserves(group, restype, 'usePrice')
       },

    // Find time steps for the current node
    option clear = tt;
    tt(t)${ ts_reservePrice(restype, up_down, group, f, t) } = yes;

    // processing only if (restype, up_down, group, f) combination has data
    if(sum(tt, abs(ts_reservePrice(restype, up_down, group, f, tt))>0),
        // If only up to a single value
        if(sum(tt, 1) <= 1,
            p_reservePrice(restype, up_down, group, f, 'useConstant') = 1; // Use a constant for node prices
            p_reservePrice(restype, up_down, group, f, 'price') = sum(tt, ts_reservePriceChange(restype, up_down, group, f, tt)) // Determine the price as the only value in the time series
        // If multiple values found, use time series. Values processed in 3a_periodicInit
        else
            p_reservePrice(restype, up_down, group, f, 'useTimeSeries') = 1;
        ); // END if(sum(tt))
    ); // END(if(sum(tt, ts_reservePrice))
); // END loop(emissionGroup)

// Abort of input data for prices are given both ts_reservePrice and ts_reservePriceChange
loop(restypeDirectionGroup_tmp(restype, up_down, group)$restypeDirectionGroup_tmp_(restype, up_down, group),
    put log '!!! Error occurred on restype ', restype.tl:0 ', up_down: ' up_down.tl:0 'group: ' group.tl:0 /;
    put log '!!! Abort: There is data in both ts_reservePrice and ts_reservePriceChange' /;
    abort "Only ts_reservePrice or ts_reservePriceChange can be given to a (restype, up_down, group)"
);


* =============================================================================
* --- Policy related Sets & Parameters ----------------------------------------
* =============================================================================

// Filling a set of (group, param_policy) if there is series data
option groupPolicyTimeseries < ts_groupPolicy;

// filtering groups that are used to define an user constraint
// Note: This picks values only from the group dimension and not from uc1...4 dimensions
option group_uc < p_userConstraint;

// populating the helper set of userconstraint contents
// note: sums must be over abs(p_userconstraint) to avoid bugs when giving e.g. -1 to one multiplier and 1 to other
groupUc1234(group_uc, uc1, uc2, uc3, uc4)
    $ { sum(param_userconstraint, abs(p_userconstraint(group_uc, uc1, uc2, uc3, uc4, param_userconstraint))) }
    = yes;

groupUcParamUserconstraint(group_uc, param_userconstraint)
    $ { sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), abs(p_userconstraint(group_uc, uc1, uc2, uc3, uc4, param_userconstraint))) }
    = yes;

// checking which UC are sft filtered
group_ucSftFiltered(group_uc)
    $ {sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'sample'))
       or sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'forecast'))
       or sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'timestep'))
       or sum(groupUc1234(group_uc, uc1, uc2, uc3, uc4), p_userconstraint(group_uc, uc1, uc2, uc3, uc4, 'effLevel'))
       }
    = yes;


* =============================================================================
* --- Postprocess data checks -------------------------------------------------
* =============================================================================

* --- NODES -------------------------------------------------------------------

* --- Check node balance and node price related data --------------------------

// Give a warning if nodeBalance and usePrice are false for active gn
loop(gn(grid, node) $ {%warnings%=1
                       and not p_gn(grid, node, 'nodeBalance')
                       and not p_gn(grid, node, 'usePrice')
                       and p_gn(grid, node, 'isActive')
                       },
    put log "!!! Warning: p_gn(" grid.tl:0 ", " node.tl:0 ") does not have nodeBalance or usePrice activated in p_gn" /;
); // END loop(grid, node)

// Give a warning if nodeBalance and usePrice are true
loop(gn(grid, node) $ {%warnings%=1
                       and p_gn(grid, node, 'nodeBalance')
                       and p_gn(grid, node, 'usePrice')
                       },
    put log "!!! Warning: p_gn(" grid.tl:0 ", " node.tl:0 ") has both nodeBalance and usePrice activated in p_gn" /;
); // END loop(grid, node)

// Notify if usePrice is true but there is no price data
tmp = 0;   // resetting counter
loop(gn(grid, node) $ {%warnings%=1
                       and p_gn(grid, node, 'usePrice')
                       and not [p_price(node, 'useConstant')
                                or p_price(node, 'useTimeSeries')
                                or sum(f, p_priceNew(node, f, 'useConstant'))
                                or sum(f, p_priceNew(node, f, 'useTimeSeries'))
                                ]
                       },
    tmp = tmp + 1;
); // END loop(grid, node)

if(%warnings%=1 and tmp > 0,
    put log "Note: p_gn has " tmp:0:0 " node(s) with usePrice activated, but no price data was not found from p_gn or price timeseries." /;
); // END if

// Give a warning if price node has influx
loop(gn(grid, node) $ {%warnings%=1
                       and p_gn(grid, node, 'usePrice')
                       and gn_influx(grid, node)
                       },
    put log "!!! Warning: p_gn(" grid.tl:0 ", " node.tl:0 ") has usePrice and influx. Influx will have no effect." /;
); // END loop(grid, node)


* --- State boundary limits ---------------------------------------------------

// warning if node with state does not have downwardLimit
loop(gn_state(grid, node)
    $ {%warnings%=1
       and [not p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useTimeseries')
            and not p_gnBoundaryPropertiesForStates(grid, node, 'downwardLimit', 'useConstant')]
        },
        put log "!!! Warning: gn("grid.tl:0 ", " node.tl:0 ") has p_gn(grid, node, 'energyStoredPerUnitOfState')=TRUE, but the node does not have downwardLimit. This allows unlimited energy from the storage." /;
); // END loop(gn_state)

// warning if node with state does not have upwardLimit
loop(gn_state(grid, node)
    $ {%warnings%=1
       and [not p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useTimeseries')
            and not p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'useConstant')
            and sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'upperLimitCapacityRatio')) = 0
            ]
        },
        put log "!!! Warning: gn("grid.tl:0 ", " node.tl:0 ") has been flagged as state node in p_gn(grid, node, 'energyStoredPerUnitOfState'), but does not have upwardLimit or any unit with p_gnu_io('upperLimitCapacityRatio'). This allows unlimited energy storage." /;
); // END loop(gn_state)


* --- State boundary slacks ---------------------------------------------------

// abort if node has state slack, but no state
loop(gn(grid, node)
    $ { gn_stateSlack(grid, node)
        and not gn_state(grid, node)
        },
    put log "!!! Abort: gn("grid.tl:0 ", " node.tl:0 ") has state slacks in p_gnBoundaryPropertiesForStates, but is not defined to be a state node in p_gn(grid, node, 'energyStoredPerUnitOfState')." /;
    abort "Node must have p_gn('nodeBalance') to be able to use state slacks!"
); // END Loop(gn)

// warning if state slack has both useConstant and useTimeseries
loop((gn_stateSlack(grid, node), slack)
    $ { %warnings%=1
        and p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
        and p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeseries')
        },
    put log "!!! Warning: slack " slack.tl:0 " for gn("grid.tl:0 ", " node.tl:0 ") in p_gnBoundaryPropertiesForStates, has both useConstant and useTimeseries." /;
); // END Loop(gn_stateSlack)

// warning if node has state slack, but no slackcost
loop((gn_stateSlack(grid, node), slack)
    $ { %warnings%=1
        and [p_gnBoundaryPropertiesForStates(grid, node, slack, 'constant')
             or p_gnBoundaryPropertiesForStates(grid, node, slack, 'useTimeseries')]
        and not p_gnBoundaryPropertiesForStates(grid, node, slack, 'slackCost')
        },
    put log "!!! Warning: gn("grid.tl:0 ", " node.tl:0 ") has slack " slack.tl:0 " in p_gnBoundaryPropertiesForStates, but does not have corresponding slack cost." /;
); // END Loop(gn_stateSlack)


* --- Transfers between nodes -------------------------------------------------

// Check if the bidirectional transfer parameter exists
loop((grid, node, node_)${%warnings%=1 and p_gnn(grid, node, node_, 'transferCapBidirectional')},
        put log "!!! Warning: p_gnn('transferCapBidirectional') is an uncomplete feature. Use p_gnn('transferCap') instead." /;
);

// check and warn if all transfer links have zero availability
if({%warnings% = 1
    and [sum(gn2n(grid, from_node, to_node), p_gnn(grid, from_node, to_node, 'transferCap')) > 0]
    and [sum(gn2n(grid, from_node, to_node), p_gnn(grid, from_node, to_node, 'availability')) = 0]
    and [sum(gn2n(grid, from_node, to_node), p_gnn(grid, from_node, to_node, 'useTimeseriesAvailability')) = 0]
    },
    put log "Warning: All transfer links have p_gnn('availability') = 0 and p_gnn('useTimeseriesAvailability') = 0. Check the data." /;
);


// Check for conflicting transfer ramp limits (MW)
loop(gn2n_directional(grid, node, node_)
    $ { %warnings%=1
        and [round(p_gnn(grid, node, node_, 'rampLimit')*p_gnn(grid, node, node_, 'transferCap'), 10)
             <> round(sum(grid_, p_gnn(grid_, node_, node, 'rampLimit')*p_gnn(grid_, node_, node, 'transferCap')), 10)
             ]
        },
        put log 'Note: ' node.tl:0 '-' node_.tl:0 ' rampLimit * transfCapacity is not equal to different directions. Will use values from '  node.tl:0 ' to ' node_.tl:0 '.' /;
);

// Check that transferLoss is < 1
loop(gn2n(grid, node, node_)
    $ { p_gnn(grid, node, node_, 'transferLoss') >= 1 },
        put log '!!! Abort: ' node.tl:0 ' -> ' node_.tl:0 ' transferLoss is equal or higher than 1. Use values below 1 for losses.' /;
        abort "Transferloss must be below 1!"
);


* --- UNITS -------------------------------------------------------------------

* --- check existance ---------------------------------------------------------

// warn if unit doesn't have unit type
loop(unit $ {%warnings% = 1
             and sum(unitUnittype(unit, unitType), 1) = 0
             },
    put log "!!! Warning: unit " unit.tl:0 " does not have unittype. Check unitUnittype from input data." /;
); // END loop(unit)


* --- Check input and output topology -----------------------------------------

// warn if active conversion units does not have input
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and not unit_source(unit)
             and sum(gnu_input(grid, node, unit), 1) = 0
             },
    put log "'!!! Warning: unit " unit.tl:0 " is a conversion unit, but does not have any inputs. Add input(s) or active 'isSource' at p_unit."/;
); // END loop(unit)

// warn if active source units have input
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and unit_source(unit)
             and sum(gnu_input(grid, node, unit), 1) > 0
             },
    put log "'!!! Warning: unit " unit.tl:0 " is a souce unit, but it has inputs."/;
); // END loop(unit)

// warn if active conversion units does not have output
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and not unit_sink(unit)
             and sum(gnu_output(grid, node, unit), 1) = 0
             },
    put log "'!!! Warning: unit " unit.tl:0 " is a conversion unit, but does not have any outputs. Add output(s) or active 'isSink' at p_unit."/;
); // END loop(unit)

// warn if active sink units have output
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and unit_sink(unit)
             and sum(gnu_output(grid, node, unit), 1) > 0
             },
    put log "'!!! Warning: unit " unit.tl:0 " is a sink unit, but has outputs."/;
); // END loop(unit)

// warn if flow units have multiple inputs and/or outputs
loop(unit_flow(unit) $ {%warnings%=1
                        and sum(gnu(grid, node, unit), 1) > 1
                        },
    put log '!!! Warning: flow unit ' unit.tl:0 'is assigned to multiple nodes'/;
); // END loop(unit_flow)


* --- check capacity, unitSize, and unitCount ---------------------------------

// Abort if negative values
// gnu must have zero or positive capacity
loop(gnu(grid, node, unit)$ {p_gnu(grid, node, unit, 'capacity') < 0},
    put log '!!! Error on unit ' unit.tl:0 /;
    put log '!!! Abort: p_gnu_io(' grid.tl:0', ' node.tl:0, ', ' unit.tl:0 ') has negative capacity.' /;
    abort "All gnu capacities must be empty or positive!"
); // END loop(gnu, input_output)

// gnu must have zero or positive unitSize
loop(gnu(grid, node, unit)$ {p_gnu(grid, node, unit, 'unitSize') < 0},
    put log '!!! Error on unit ' unit.tl:0 /;
    put log '!!! Abort: p_gnu_io(' grid.tl:0', ' node.tl:0, ', ' unit.tl:0 ') has negative unitSize.' /;
    abort "All gnu unitSizes must be empty or positive!"
); // END loop(gnu, input_output)

// unit must have zero or positive unitSize
loop(unit$ {p_unit(unit, 'unitCount') < 0},
    put log '!!! Error on unit ' unit.tl:0 /;
    put log '!!! Abort: p_unit(' unit.tl:0 ') has negative unitCount.' /;
    abort "All unitCounts must be empty or positive!"
); // END loop(unit)

// warn if active non-flow unit has zero conversionCoeff for every gnu
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and [sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'conversionCoeff')) = 0]
             },
    put log "!!! Warning: unit '"unit.tl:0"' has zero p_gnu_io('conversionCoeff') for every gnu, check the data"/;
); // END loop(unit)

// Initializing unit_tmp to avoid subsequential warnings from following categories
option clear = unit_tmp;

// warn if active unit has zero capacity and unitCount
loop(unit $ {%warnings%=1
             and p_unit(unit, 'isActive')
             and not unit_flow(unit)
             and [sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'capacity')) = 0]
             and p_unit(unit, 'unitCount')
             },
    put log "!!! Warning: unit '" unit.tl:0 "' has zero p_gnu_io('capacity') for every gnu, but higher than zero unitCount in p_unit, check the data"/;
    // log units to unit_tmp to avoid repeated warning on following step
    unit_tmp(unit) = yes;
); // END loop(unit)

// Warn if active unit has zero capacity while it is not an investment unit,
// a flow unit, or not bound by unitConstraint or userconstraint 3rd dimension used for v_gen
loop(unit $ { %warnings%=1
              and not unit_tmp(unit)   // not in unit_tmp for units that already received the previous warning
              and p_unit(unit, 'isActive')
              and [sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'capacity')) = 0]
              and not unit_invest(unit)
              and not unit_flow(unit)
              and not sum(constraint, unitConstraint(unit, constraint))
              and not sum[(groupUcParamUserconstraint(group, param_userconstraint), gn(grid, node)),
                            p_userconstraint(group, grid, node, unit, '-', param_userconstraint)]
              },
    put log "!!! Warning: unit '" unit.tl:0 "' has zero p_gnu_io('capacity') for every gnu and it is not an investment unit, a flow unit, bound by unitConstraint or userconstraint. Check the data"/;
    // log units to unit_tmp to avoid repeated warning on following step
    unit_tmp(unit) = yes;
); // END loop(unit)

// checking if capacity <> unitSize * unitCount. Rounding to 10 decimals.
loop(gnu(grid, node, unit) $ {%warnings%=1
                              and not unit_tmp(unit)   // not in unit_tmp for units that already received the previous warning
                              and not unit_invest(unit)
                              and [p_gnu(grid, node, unit, 'capacity') > 0] // must have capacity
                              and [p_gnu(grid, node, unit, 'unitSize') > 0] // must have unitSize
                              and p_unit(unit, 'unitCount')                 // must have unitCount
                              and [round(p_gnu(grid, node, unit, 'capacity'), 10)
                                   <> round(p_gnu(grid, node, unit, 'unitSize')
                                      * p_unit(unit, 'unitCount'), 10)
                                   ]
                              },
    put log "!!! Warning: Unit '" unit.tl:0 "' has capacity <> unitSize * unitCount for (grid, node) ('" grid.tl:0 "', '" node.tl:0 "'), check input data. " /;
); // END loop(gnu, input_output)


* --- Check upperLimitCapacityRatio -------------------------------------------

// check that units with upperLimitCapacityRatio have unitSize
loop(gnu(grid, node, unit) $ {%warnings%=1
                              and not unit_deactivated(unit)
                              and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                              and p_gnu(grid, node, unit, 'unitSize') = 0
                              },
    put log "!!! Warning: Grid, node, unit ('" grid.tl:0 "', '" node.tl:0 "', '" unit.tl:0 "') has p_gnu('upperLimitCapacityRatio'), but no p_gnu('unitSize'). The upperLimitCapacityRatio will not have any impact. " /;
); // END loop(gnu)

// check that non-invest units with upperLimitCapacityRatio have unitCount
loop(gnu(grid, node, unit) $ {%warnings%=1
                              and not unit_deactivated(unit)
                              and not unit_invest(unit)
                              and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                              and p_unit(unit, 'unitCount') = 0
                              },
    put log "!!! Warning: Grid, node, unit ('" grid.tl:0 "', '" node.tl:0 "', '" unit.tl:0 "') has p_gnu('upperLimitCapacityRatio'), but is not in investment unit and has no p_unit('unitCount'). The upperLimitCapacityRatio will not have any impact. " /;
); // END loop(gnu)

// check that non-invest units with upperLimitCapacityRatio have capacity
loop(gnu(grid, node, unit) $ {%warnings%=1
                              and not unit_deactivated(unit)
                              and not unit_invest(unit)
                              and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
                              and p_gnu(grid, node, unit, 'unitSize') = 0
                              },
    put log "!!! Warning: Grid, node, unit ('" grid.tl:0 "', '" node.tl:0 "', '" unit.tl:0 "') has p_gnu('upperLimitCapacityRatio'), but is not in investment unit and has no p_gnu('capacity'). The upperLimitCapacityRatio will not have any impact. " /;
); // END loop(gnu)


* --- Check the integrity of efficiency approximation related data ------------

// check that single effLevel does not have multiple effSelectors
loop((effLevel, unit)$sum(effSelector, effLevelGroupUnit(effLevel, effSelector, unit)),
    if(sum(effLevelGroupUnit(effLevel, effSelector, unit), 1) > 1,
        put log '!!! Error on unit ' unit.tl:0, ', effLevel ' effLevel.tl:0 /;
        put log '!!! Abort: unit has two effSelectors for the same effLevel !' /;
        abort "Each effLevel can have only one effSelector (directOff, directOnLP, etc)!"
    ); // END if
); // END loop(effLevel, unit)

* --- Check startup and shutdown related data ---------------------------------

// Notify if directOff unit have startcost defined
option clear = unit_tmp;
unit_tmp(unit) $ { sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startCostCold'))
                   and unit_directOff(unit)
                   }
    = yes;

if(%warnings%=1 and card(unit_tmp)>0,
    tmp = card(unit_tmp);
    put log "Note: " tmp:0:0 " directOff units have p_gnu_io('startCostCold') defined, but directOff disables start cost calculations" /;
); // END if

// Warn if unit has startcost defined, but not unitSize
loop(gnu(grid, node, unit)$ {%warnings%=1
                             and p_gnu(grid, node, unit, 'startCostCold')
                             and not p_gnu(grid, node, unit, 'unitSize')
                             and not unit_directOff(unit)
                             },
    put log "!!! Warning: There is p_gnu_io("grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", 'startCostCold') defined, but matching 'unitSize' is zero. This disables start cost calculations" /;
); // END loop(unit)

// unit is not directOff and has startFuelConsCold, startfuelConsWarm, or startFuelConsHot defined, but
loop(unit $ {%warnings%=1
             and not unit_directOff(unit)
             and[sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsCold'))
                 or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsWarm'))
                 or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsHot'))
                 ]
             },
    // no unitSize
    if(sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'unitSize')) = 0,
        put log "!!! Warning: unit " unit.tl:0, " has start fuel consumption, but p_gnu_io('unitSize') is zero. This disables start fuel calculations." /;
    );
    // no p_uStartupfuel
    if(sum(node, p_uStartupfuel(unit, node, 'fixedFuelFraction')) = 0,
        put log '!!! Warning: unit ', unit.tl:0, ' has start fuel consumption, but no data in p_uStartupfuel. This disables start fuel calculations.' /;
    );
); // END loop(unit)

// startup fuel fraction must be 1
loop( unit${sum(starttype$p_uStartup(unit, starttype, 'consumption'), 1)},
    if(sum(node, p_uStartupfuel(unit, node, 'fixedFuelFraction')) <> 1,
        put log '!!! Error occurred on unit ' unit.tl:0 /;
        put log '!!! Abort: The sum of fixedFuelFraction over start-up fuels needs to be one for all units using start-up fuels!' /;
        abort "The sum of 'fixedFuelFraction' over start-up fuels needs to be one for all units using start-up fuels!"
    ); // END if
); // END loop(unit)

// Notify if directOff unit has p_uStartupfuel(unit, node, 'fixedFuelFraction') or p_gnu_io startFuelConsCold, startfuelConsWarm, or startFuelConsHot
unit_tmp(unit) $ {unit_directOff(unit)
                  and [sum(node, p_uStartupfuel(unit, node, 'fixedFuelFraction'))
                       or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsCold'))
                       or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsWarm'))
                       or sum(gnu(grid, node, unit), p_gnu(grid, node, unit, 'startFuelConsHot'))
                       ]
                  }
    = yes;

tmp = card(unit_tmp);
if(%warnings%=1 and tmp > 0,
    put log "Note: " tmp:0:0 " directOff units have data in p_uStartupfuel and/or p_gnu_io('startFuelConsCold/Hot/Warm'), but directoff disables start fuel calculations" /;
);

// check that minShutdownHours <= startWarmAfterXhours <= startColdAfterXhours
loop( unitStarttype(unit, starttypeConstrained),
    if(p_unit(unit, 'minShutdownHours') > p_unit(unit, 'startWarmAfterXhours')
        or p_unit(unit, 'startWarmAfterXhours') > p_unit(unit, 'startColdAfterXhours'),
        put log '!!! Error occurred on unit ', unit.tl:0 /;
        put log '!!! Abort: Units should have p_unit(unit, minShutdownHours) <= p_unit(unit, startWarmAfterXhours) <= p_unit(unit, startColdAfterXhours)!' /;
        abort "Units should have p_unit(unit, 'minShutdownHours') <= p_unit(unit, 'startWarmAfterXhours') <= p_unit(unit, 'startColdAfterXhours')!"
    );
);

* --- Check ramp related data -------------------------------------------------

// check that each rampCost has rampLimit
loop((slack, gnu(grid, node, unit))
    $ { p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
        and not p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')
        },
        put log "!!! Warning: p_gnuBoundaryProperties(" grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", " slack.tl:0 ") has 'rampCost', but no 'rampLimit'. This will set the ramp to zero." /;
); // END loop(slack, gnu)

// check that each rampLimit has rampCost
loop((slack, gnu(grid, node, unit))
    $ { not p_gnuBoundaryProperties(grid, node, unit, slack, 'rampCost')
        and p_gnuBoundaryProperties(grid, node, unit, slack, 'rampLimit')
        },
        put log "!!! Warning: p_gnuBoundaryProperties(" grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", " slack.tl:0 ") has 'rampLimit', but no 'rampCost'. This will limit disable rampLmit equations." /;
); // END loop(slack, gnu)


* --- Check delay related data ------------------------------------------------

// check that delay is for output node
loop(gnu(grid, node, unit)
    $ { gnu_delay(gnu)
        and gnu_input(gnu)
        },
        put log "!!! Error occurred on p_gnu_io(", grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", 'delay')" /;
        put log "!!! Abort: Units can have delays only for unit outputs" /;
        abort "Units can have delays only for unit outputs, check values in p_gnu_io('delay')"
); // END loop(gnu)

// check that gnu with delay does not also produce reserves
loop(gnu(grid, node, unit)
    $ { gnu_delay(gnu)
        and sum((restype, up_down), gnu_rescapable(restype, up_down, gnu))
        },
        put log "!!! Error occurred on gnu(", grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ")" /;
        put log "!!! Abort: gnu producing reserves cannot can have delays, check p_gnuReserves" /;
        abort "gnu producing reserves cannot can have delays, check p_gnuReserves"
); // END loop(gnu)


* --- Check unit constraint data ----------------------------------------------

// abort if unitConstraint has only one node and no constant
loop(unitConstraint(unit, constraint),
    //clear tmp
    tmp = 0;

    // check if 'constant' in p_unitConstraintNew
    if(p_unitConstraintNew(unit, constraint, 'constant')<>0 or unit_tsConstraint(unit, constraint),
        tmp = 1;
    ); // END if

    // nodes defined in p_unitConstraintNode or as time series
    option clear = node_tmp;
    node_tmp(node)${p_unitConstraintNode(unit, constraint, node)<>0
                    or unit_tsConstraintNode(unit, constraint, node)
                    }
        = yes;

    // sum constants and nodes
    tmp = tmp + sum(node_tmp, 1);

    if(tmp < 2,
        put log '!!! Error occurred on unit ' unit.tl:0 ' constraint ' constraint.tl:0 /;
        put log '!!! Abort: Each unitConstraint should have one or more nodes and a constant or two or more nodes!' /;
        abort "Each unitConstraint should have one or more nodes and a constant or two or more nodes!"
    ); // END if(tmp)
); // END loop(unitConstraint)


* --- Check unit availability limits data -------------------------------------

// t given in utAvailabilityLimits
option tt < utAvailabilityLimits;
option unit_tmp < utAvailabilityLimits;

// check if unit has multiple becomeAvailable
loop(unit_tmp(unit) $  { %warnings%=1 and sum(utAvailabilityLimits(unit, tt, 'becomeAvailable'), 1)>1 },
    put log "!!! Error occurred on unit ", unit.tl:0, ", 'becomeAvailable' parameters" /;
    put log "!!! Warning: utAvailabilitylimits can have only one 'becomeAvailable' per unit" /;
); // END loop(unit_tmp)

// check if unit has multiple becomeUnavailable
loop(unit_tmp(unit) $  { %warnings%=1 and sum(utAvailabilityLimits(unit, tt, 'becomeUnavailable'), 1)>1 },
    put log "!!! Error occurred on unit ", unit.tl:0, ", 'becomeUnavailable' parameters" /;
    put log "!!! Warning: utAvailabilitylimits can have only one 'becomeUnavailable' per unit" /;
); // END loop(unit_tmp)

* --- Check investment related data -------------------------------------------

// Check that units with LP investment possibility have unitSize
loop( unit_investLP(unit) $ {not sum(gnu(grid, node, unit), abs(p_gnu(grid, node, unit, 'unitSize'))) },
    put log '!!! Error occurred on unit ', unit.tl:0 /;
    put log '!!! Abort: Unit is listed as an investment option but it has no unitSize!' /;
    abort "All units with investment possibility should have 'unitSize' in p_gnu!"
); // END loop(unit_investLP)

// Check that units with MIP investment possibility have unitSize
loop( unit_investMIP(unit) $ {not sum(gnu(grid, node, unit), abs(p_gnu(grid, node, unit, 'unitSize'))) },
    put log '!!! Error occurred on unit ', unit.tl:0 /;
    put log '!!! Abort: Unit is listed as an investment option but it has no unitSize!' /;
    abort "All units with investment possibility should have 'unitSize' in p_gnu!"
); // END loop(unit_investMIP)


* --- EMISSIONS ---------------------------------------------------------------
* --- Check emission related data ---------------------------------------------

// check there are nodes in gnGroup, if giving emission price data
loop((emission, group) $ { %warnings%=1
                           and [ p_emissionPrice(emission, group, 'useConstant')
                                 or p_emissionPrice(emission, group, 'useTimeseries')
                                 ]
                           and sum(gn$gnGroup(gn, group), 1) = 0
                           },
    put log '!!! Warning: emissionGroup(' emission.tl:0 ',' group.tl:0 ') has price data, but no nodes in gnGroup. The price will not be included to equations.' /;
); // END loop(emission, group)

// check there are nodes in gnGroup, if giving emission price data
loop((emission, group) $ { %warnings%=1
                           and [sum(f, p_emissionPriceNew(emission, group, f, 'useConstant'))
                                or sum(f, p_emissionPriceNew(emission, group, f, 'useTimeseries'))
                                ]
                           and not sum(gn, gnGroup(gn, group))
                           },
    put log '!!! Warning: emissionGroup(' emission.tl:0 ',' group.tl:0 ') has price data, but no nodes in gnGroup. The price will not be included to equations.' /;
); // END loop(emission, group)

// filter gnu in p_gnuEmission
option gnu_tmp < p_gnuEmission;

// check that nodes in gnu_tmp are in gnGroup
loop(gnu_tmp(grid, node, unit) $ {%warnings%=1 and not sum(group, gnGroup(grid, node, group))
                            },
    put log '!!! Warning: gnu(' grid.tl:0 ',' node.tl:0 ', ' unit.tl:0 ') has p_gnuEmission data, but no nodes in gnGroup. The price will not be included to equations.' /;
); // END loop(emission, group)

// checking there is invEmissionFactor for gnu, if using invEmissions
loop(gnu_tmp(grid, node, unit) $ { %warnings%=1 },
    loop(emission$p_gnuEmission(grid, node, unit, emission, 'invEmissions'),
        if(not p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor'),
           put log '!!! Warning: (grid, node, unit, emission) (', grid.tl:0 ,',', node.tl:0 ,',', unit.tl:0 ,',', emission.tl:0 ,',', ') has invEmissions>0, but invEmissionsFactor is empty. Assuming 1.' /;
           p_gnuEmission(grid, node, unit, emission, 'invEmissionsFactor') = 1;
        ); // END if
    ); // END loop(emission)
); // END loop(gnu_tmp)


* --- RESERVES ----------------------------------------------------------------
* --- Check reserve related data ----------------------------------------------

loop( restypeDirectionGroup(restype, up_down, group),
    // Check that reserve_length is long enough for proper commitment of reserves
    if(p_groupReserves(group, restype, 'reserve_length') < p_groupReserves(group, restype, 'update_frequency') + p_groupReserves(group, restype, 'gate_closure'),
        put log '!!! Error occurred on group ', group.tl:0 /;
        put log '!!! Abort: The reserve_length parameter should be longer than update_frequency + gate_closure to fix the reserves properly!' /;
        abort "The 'reserve_length' parameter should be longer than 'update_frequency' + 'gate_closure' to fix the reserves properly!"
    ); // END if
    // Check that the duration of reserve activation is less than the reserve reactivation time
    if(p_groupReserves(group, restype, 'reserve_reactivation_time') < p_groupReserves(group, restype, 'reserve_activation_duration'),
        put log '!!! Error occurred on group ', group.tl:0 /;
        put log '!!! Abort: The reserve_reactivation_time should be greater than or equal to the reserve_activation_duration!' /;
        abort "The reserve_reactivation_time should be greater than or equal to the reserve_activation_duration!"
    ); // END if
); // END loop(restypeDirectionGroup)

loop( restypeDirectionGridNode(restype, up_down, grid, node),
    // Check for each restype that a node does not belong to multiple groups
    if(sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group), 1) > 1,
        put log '!!! Error occurred on node ', node.tl:0 /;
        put log '!!! Abort: For each reserve type, a node can belong to at maximum one reserve node group!' /;
        abort "For each reserve type, a node can belong to at maximum one reserve node group!"
    ); // END if
    // Check if there are units/interconnections connected to a node that does not belong to any restypeDirectionGroup
    if(sum(restypeDirectionGridNodeGroup(restype, up_down, grid, node, group), 1) < 1,
        put log '!!! Error occurred on node ', node.tl:0 /;
        put log '!!! Abort: A node with reserve provision/transfer capability has to belong to a reserve node group!' /;
        abort "A node with reserve provision/transfer capability has to belong to a reserve node group!"
    ); // END if
); // END loop(restypeDirectionGridNode)

// Check that reserve overlaps are possible
loop( (gnu(grid, node, unit), restypeDirection(restype, up_down))$ {p_gnuReserves(grid, node, unit, restype, up_down) < 0},
    put log '!!! Error occurred on unit ', unit.tl:0 /;
    put log '!!! Abort: Overlapping reserve capacities in p_gnuRes2Res can result in excess reserve production!' /;
    abort "Overlapping reserve capacities in p_gnuRes2Res can result in excess reserve production!"
); // END loop((gnu,restypeDirection))



* --- GROUPS ------------------------------------------------------------------



* --- TIME SERIES -------------------------------------------------------------

// check if using ts_gnu_io for param_gnu that does not have functionalities
loop(param_gnu $ {sum(gnu, gnu_timeseries(gnu, param_gnu))
                  and not sameAs(param_gnu, 'vomCosts')
                  },
    put log "!!! Warning: ts_gnu_io has data for " param_gnu.tl:0 ", but that does not currently have active functionalities in the code."
);


* =============================================================================
* --- USER CONSTRAINT checks --------------------------------------------------
* =============================================================================

// clearing tmp
tmp = 0;


* --- v_state, v_spill --------------------------------------------------------

// Loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'v_state')
        or SameAs(param_userconstraint, 'v_spill')
        },

    // check 1st dimension (grid)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (grid, node, '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 2nd dimension (node)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (grid, node, '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 3rd dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension. '" uc3.tl:0 "' should be '-' for " param_userconstraint.tl:0 " multiplier: (grid, node, '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension. '" uc4.tl:0 "' should be '-' for " param_userconstraint.tl:0 " multiplier: (grid, node, '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check that gn is an actual gn pair
    loop((grid, node)
        $ {p_userconstraint(group, grid, node, '-', '-', param_userconstraint)
           and not [gn(grid, node) or gn_deactivated(grid, node)]
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') tries to use " param_userconstraint.tl:0 " for (grid, node): ('" grid.tl:0 "', '" node.tl:0 "') but that combination is not an actual gn pair, see p_gn from input data." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(grid, node)

    // check that gn for v_state  is an active gn pair
    loop(gn_deactivated(grid, node)
        $ {%warnings% = 1
           and p_userconstraint(group, grid, node, '-', '-', param_userconstraint)
           },
        put log "Note: p_userconstraint('" group.tl:0 "') tries to use " param_userconstraint.tl:0 " for (grid, node): ('" grid.tl:0 "', '" node.tl:0 "') for a deactivated gn pair. It will not be used in the equation." /;
    ); // END loop(grid, node)

    // check that gn for v_state has state variable
    loop(gn(grid, node)
        $ {sameAs(param_userconstraint, 'v_state')       // needed to limit only to one v_xx
           and p_userconstraint(group, grid, node, '-', '-', 'v_state')
           and not gn_state(gn)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use v_state for (grid, node): ('" grid.tl:0 "', '" node.tl:0 "') but that combination cannot store energy, see p_gn('energyStoredPerUnitOfState')." /;
    ); // END loop(gn)

    // check that gn for v_spill has spilling activate
    loop(gn(grid, node)
        $ {sameAs(param_userconstraint, 'v_spill')       // needed to limit only to one v_xx
           and p_userconstraint(group, grid, node, '-', '-', 'v_spill')
           and not node_spill(node)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use v_spill for (grid, node): ('" grid.tl:0 "', '" node.tl:0 "') but that combination does not have spillage activate, see p_gnBoundaryPropertiesForStates('maxSpill/minSpill')." /;
    ); // END loop(gn)

); // END loop(groupUcParamUserConstraint)



* --- v_transfer, v_transferLeftward, v_transferrightward, v_transferRamp -----

// Loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'v_transfer')
        or SameAs(param_userconstraint, 'v_transferLeftward')
        or SameAs(param_userconstraint, 'v_transferRightward')
        or SameAs(param_userconstraint, 'v_transferRamp')
        or SameAs(param_userconstraint, 'v_investTransfer')
        },

    // check 1st dimension (grid)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' or wrong domains for " param_userconstraint.tl:0 ": (grid, from_node, to_node, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 2nd dimension (from_node)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of from_node): '" uc2.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " (grid, from_node, to_node, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 3rd dimension (to_node)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not node(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (name of to_node): '" uc3.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " (grid, from_node, to_node, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension: '" uc4.tl:0 "' should be '-' when giving multiplier for " param_userconstraint.tl:0 " (grid, from_node, to_node, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos / dimension errors
    ); // END loop(groupUc1234)

    // check that multipliers are for actual transfer links
    loop((grid, from_node, to_node)
        $ {p_userconstraint(group, grid, from_node, to_node, '-', param_userconstraint)
           and not [gn2n(grid, from_node, to_node)
                    or gnn_deactivated(grid, from_node, to_node)]
           },
        put log "!!! Abort: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " from_node.tl:0 ", " to_node.tl:0 ", '-', '" param_userconstraint.tl:0 "') is not a transfer connection.  See p_gnn from input data." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(grid, from_node, to_node)

    // check that multipliers are for active gn2n
    loop(gnn_deactivated(grid, from_node, to_node)
        $ {%warnings% = 1
           and p_userconstraint(group, gnn_deactivated, '-', param_userconstraint)
           },
        put log "Note: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " from_node.tl:0 ", " to_node.tl:0 ", '-', '" param_userconstraint.tl:0 "') is for a deactive transfer link. It will not be used in the equation." /;
    ); // END loop(grid, from_node, to_node)

    // check that dimensions for multipliers for are in the same order than in gn2n_directional
    loop(gn2n(grid, from_node, to_node)
        $ {p_userconstraint(group, gn2n, '-', param_userconstraint)
           and not gn2n_directional(gn2n)
           },
        put log "!!! Abort: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " from_node.tl:0 ", " to_node.tl:0 ", '-', '" param_userconstraint.tl:0 "') is a transfer connection, but the order of nodes is different" /;
        put log "than in the first appearance in the p_gnn in input data. Try reversing the order of the nodes or check the correct from gn2n_direction in the debug file." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(gn2n)

    // check that multipliers for v_investTransfer are for transfer link with active investment options
    loop(gn2n_directional(grid, from_node, to_node)
        $ {%warnings% = 1
           and sameAs(param_userconstraint, 'v_investTransfer')       // needed to limit only to one v_xx
           and p_userconstraint(group, gn2n_directional, '-', 'v_investTransfer')
           and not [gn2n_directional_investLP(gn2n_directional)
                    or gn2n_directional_investMIP(gn2n_directional)
                    ]
           },
        put log "!!! Warning: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " from_node.tl:0 ", " to_node.tl:0 ", '-', 'v_investTransfer') is for transfer link that has no investment variable. It will not be used in the equation." /;
    ); // END loop(gn2n)

); // END loop(groupUcParamUserConstraint)


* --- v_gen, v_genRampUp, v_genRampDown, v_gen_delay --------------------------

// Loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'v_gen')
        or SameAs(param_userconstraint, 'v_genRampUp')
        or SameAs(param_userconstraint, 'v_genRampDown')
        or SameAs(param_userconstraint, 'v_gen_delay')
        },

    // check 1st dimension (grid)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (grid, node, unit, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (node)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (grid, node, unit, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension (unit)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not unit(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (name of unit): '" uc3.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (grid, node, unit, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs('-', uc4)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension: '" uc4.tl:0 "' should be '-' for " param_userconstraint.tl:0 " multiplier: (grid, node, unit, '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check that given (grid, node, unit) is a gnu combination in input data
    loop((grid, node, unit)
        $ {p_userconstraint(group, grid, node, unit, '-', param_userconstraint)
           and not gnu(grid, node, unit)
           and not gnu_deactivated(grid, node, unit)
           },
        put log "!!! Abort: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", '-', '" param_userconstraint.tl:0 "') is not a gnu(grid, unit, node).  See p_gnu_io and/or gnu from debug.gdx." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(grid, node, unit)

    // check that given (grid, node, unit) is an active gnu
    loop(gnu_deactivated(grid, node, unit)
        $ {%warnings% = 1
           and p_userconstraint(group, grid, node, unit, '-', param_userconstraint)
           },
        put log "Note: p_userconstraint(" group.tl:0 ", " grid.tl:0 ", " node.tl:0 ", " unit.tl:0 ", '-', '" param_userconstraint.tl:0 "') is for a deactivated gnu(grid, unit, node). This will not be used in the equation." /;
    ); // END loop(gnu_deactivated)

); // END loop(groupUcParamUserConstraint)


* --- v_online, v_invest ------------------------------------------------------

// Loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'v_online')
        or SameAs(param_userconstraint, 'v_startup')
        or SameAs(param_userconstraint, 'v_shutdown')
        or SameAs(param_userconstraint, 'v_invest')
        },

    // check 1st dimension (unit)
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and  not unit(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of unit): '" uc1.tl:0 "' or wrong domains for " param_userconstraint.tl:0 " multiplier: (unit, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension ('-') except v_startup
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(param_userconstraint, 'v_startup')
           and not sameAs(uc2, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension: '" uc2.tl:0 "'. It should be '-' in " param_userconstraint.tl:0 " multiplier: (unit, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension ('-' or starttype) for v_startup
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {sameAs(param_userconstraint, 'v_startup')       // needed to limit only to one v_xx
           and p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_startup')
           and not [sameAs(uc2, '-')
                    or sameAs(uc2, 'hot')
                    or sameAs(uc2, 'warm')
                    or sameAs(uc2, 'cold')
                    ]
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension: '" uc2.tl:0 "' in v_startup multiplier. It should be either -, hot, warm, or cold. When using '-', equations sum all starttypes." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension: '" uc3.tl:0 "'. It should be '-' in " param_userconstraint.tl:0 " multiplier: (unit, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension: '" uc4.tl:0 "'. It should be '-' in " param_userconstraint.tl:0 " multiplier: (unit, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check that unit is an active unit
    loop(unit_deactivated(unit)
        $ {%warnings% = 1
           and p_userconstraint(group, unit, '-', '-', '-', param_userconstraint)
           },
        put log "Note: p_userconstraint(" group.tl:0 ", " unit.tl:0 ", '-', '-', '-', '" param_userconstraint.tl:0 "') is for a deactivated unit. This will not be used in the equations." /;
    ); // END loop(gnu_deactivated)

    // check if the unit is online unit (v_online, v_startup, and v_shutdown)
    // in 3a_periodicInit.gms


    // check if specific starttype is enabled
    loop((unit, starttype)
        $ {%warnings% = 1
           and sameAs(param_userconstraint, 'v_startup')      // needed to limit only to one v_xx
           and p_userconstraint(group, unit, starttype, '-', '-', 'v_startup')
           and not unitStarttype(unit, starttype)
           },
        put log "!!! Warning: " starttype.tl:0 " is not an active starttype for unit " unit.tl:0 ", see parameters in p_gnu. This will not be used in p_userconstraint(" group.tl:0 ", " unit.tl:0 ", '" starttype.tl:0 "', '-', '-', 'v_startup')" /;
    ); // END loop(unit, starttype)

    // check if the unit is invest unit
    loop(unit
        $ {%warnings% = 1
           and sameAs(param_userconstraint, 'v_invest')      // needed to limit only to one v_xx
           and p_userconstraint(group, unit, '-', '-', '-', 'v_invest')
           and not unit_invest(unit)
           and not unit_deactivated(unit)
           },
        put log "!!! Warning: p_userconstraint(" group.tl:0 ", " unit.tl:0 ", '-', '-', '-', 'v_invest') is not an unit with active investment possibilities. This will not be used in the equations. See p_unit and p_gnu." /;
    ); // END loop(grid, node, unit)

); // END loop(groupUcParamUserConstraint)



* --- v_reserve ---------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'v_reserve'),

    // check 1st dimension (restype) when giving multiplier to v_reserve
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_reserve')
           and  not restype(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of restype): '" uc1.tl:0 "' in v_reserve multiplier: (restype, up_down, node, unit)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (up_down) when giving multiplier to v_reserve
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_reserve')
           and not [sameAs(uc2, 'up') or sameAs(uc2, 'down')]
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension: '" uc2.tl:0 "' in v_reserve multiplier: (restype, up_down, node, unit). The text should be 'up' or 'down'. " /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension (node) when giving multiplier to v_reserve
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_reserve')
           and  not node(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (name of node): '" uc3.tl:0 "' in v_reserve multiplier: (restype, up_down, node, unit)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 4th dimension (unit) when giving multiplier to v_reserve
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_reserve')
           and  not unit(uc4)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension (name of unit): '" uc4.tl:0 "' in v_reserve multiplier: (restype, up_down, node, unit)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check that unit is capable to procuce reserves
    loop((restype, up_down, node, unit)
        $ {p_userconstraint(group, restype, up_down, node, unit, 'v_reserve')
           and not restypeDirection(restype, up_down)
           },
        put log "!!! Abort: p_userconstraint(" group.tl:0 ", " restype.tl:0 ", " up_down.tl:0 ", " node.tl:0 ", ", unit.tl:0 ", 'v_reserve') is defined for restypeDirection that does not exist, see debug file." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(restype, up_down, node, unit)

    // check that unit is capable to procuce reserves
    loop((restype, up_down, node, unit)
        $ {%warnings%=1
           and p_userconstraint(group, restype, up_down, node, unit, 'v_reserve')
           and not sum(grid, gnu_resCapable(restype, up_down, grid, node, unit))
           },
        put log "!!! Warning: p_userconstraint(" group.tl:0 ", " restype.tl:0 ", " up_down.tl:0 ", " node.tl:0 ", ", unit.tl:0 ", 'v_reserve') cannot produce reserves, see gnu_resCapable from debug file. This will not be used in the equation." /;
    ); // END loop(restype, up_down, node, unit)

); // END loop(groupUcParamUserConstraint)

* --- v_userconstraint --------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'v_userconstraint'),

    // check 1st dimension (group) when giving multiplier to v_userconstraint
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_userconstraint')
           and  not group_(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension: '" uc1.tl:0 "' in v_userconstraint multiplier: (group, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check that 1st dimension is group_uc
    loop(groupUc1234(group, group_, uc2, uc3, uc4)
        $ {p_userconstraint(group, group_, uc2, uc3, uc4, 'v_userconstraint')
           and  not group_uc(group_)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') refers to group: '" group_.tl:0 "' in v_userconstraint multiplier: (group, '-', '-', '-'), but that group is not an user constraint group." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check that 1st dimension is other group_uc
    loop(groupUc1234(group, group_, uc2, uc3, uc4)
        $ {p_userconstraint(group, group_, uc2, uc3, uc4, 'v_userconstraint')
           and sameAs(group, group_)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') refers to itself in v_userconstraint multiplier: (group, '-', '-', '-'). Use v_userconstraint from other userconstraints." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension ('-') when giving multiplier to v_userconstraint
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_userconstraint')
           and not sameAs(uc2, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension: '" uc2.tl:0 "' and it should be '-' as in v_userconstraint multiplier: (group, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension ('-') when giving multiplier to v_userconstraint
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_userconstraint')
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension: '" uc3.tl:0 "' and it should be '-' as in v_userconstraint multiplier: (group, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 4th dimension ('-') when giving multiplier to v_userconstraint
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'v_userconstraint')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension: '" uc4.tl:0 "' and it should be '-' as in v_userconstraint multiplier: (group, '-', '-', '-')." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_unit -----------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_unit'),

    // check 1st dimension (unit) when giving multiplier to ts_unit
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_unit')
           and  not unit(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of unit): '" uc1.tl:0 "' in ts_unit multiplier: (unit, param_unit, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (param_unit) when giving multiplier to ts_unit
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_unit')
           and not param_unit(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (param_unit): '" uc2.tl:0 "' in ts_unit multiplier: (unit, param_unit, -, -). See 'inc/1a_definitions.gms for the full list of allowed param_unit values.'" /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if ts_unit has data for declared (unit, param_unit) combination
    loop(groupUc1234(group, unit, param_unit, uc3, uc4)
        $ {p_userconstraint(group, unit, param_unit, uc3, uc4, 'ts_unit')
           and not unit_timeseries(unit, param_unit)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use ts_unit('" unit.tl:0 "', '" param_unit.tl:0 "'), but there is no matching data in ts_unit.'" /;
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_unit')
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension ('-'): '" uc3.tl:0 "' in ts_unit multiplier: (unit, param_unit, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_unit')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension ('-'): '" uc4.tl:0 "' in ts_unit multiplier: (unit, param_unit, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_influx -----------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_influx'),

    // check 1st dimension (unit) when giving multiplier to ts_influx
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_influx')
           and  not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' in ts_influx multiplier: (grid, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (param_unit) when giving multiplier to ts_influx
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_influx')
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' in ts_influx multiplier: (grid, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if ts_influx has data for declared (grid, node) combination
    loop(groupUc1234(group, grid, node, uc3, uc4)
        $ {p_userconstraint(group, grid, node, uc3, uc4, 'ts_influx')
           and not gn_influxTs(grid, node)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use ts_influx('" grid.tl:0 "', '" node.tl:0 "'), but there is no matching data in ts_influx." /;
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_influx')
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension ('-'): '" uc3.tl:0 "' in ts_influx multiplier: (grid, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_influx')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension ('-'): '" uc4.tl:0 "' in ts_influx multiplier: (grid, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_cf -------------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_cf'),

    // check 1st dimension (flow) when giving multiplier to ts_cf
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_cf')
           and  not flow(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of flow): '" uc1.tl:0 "' in ts_cf multiplier: (flow, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (param_unit) when giving multiplier to ts_cf
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_cf')
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' in ts_cf multiplier: (flow, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if (flow, node) combination is actual flowNode
    loop(groupUc1234(group, flow, node, uc3, uc4)
        $ {p_userconstraint(group, flow, node, uc3, uc4, 'ts_cf')
           and not flowNode(flow, node)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use ts_cf('" flow.tl:0 "', '" node.tl:0 "'), but that is not an actual (flow, node) pair in ts_cf.'" /;
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_cf')
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension ('-'): '" uc3.tl:0 "' in ts_cf multiplier: (flow, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_cf')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension ('-'): '" uc4.tl:0 "' in ts_cf multiplier: (flow, node, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_node -----------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_node'),

    // check 1st dimension (grid) when giving multiplier to ts_node
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_node')
           and  not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' in ts_node multiplier: (grid, node, param_gnBoundaryTypes, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (node) when giving multiplier to ts_node
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_node')
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' in ts_node multiplier: (grid, node, param_gnBoundaryTypes, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension (param_gnBoundaryTypes) when giving multiplier to ts_node
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_node')
           and not param_gnBoundaryTypes(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (param_gnBoundaryTypes): '" uc3.tl:0 "' in ts_node multiplier: (grid, node, param_gnBoundaryTypes, -). See 'inc/1a_definitions.gms' for the full list of allowed param_gnBoundaryTypes values." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if (grid, node, param_gnBoundaryTypes) combination has data in ts_node
    loop(groupUc1234(group, grid, node, param_gnBoundaryTypes, uc4)
        $ {p_userconstraint(group, grid, node, param_gnBoundaryTypes, uc4, 'ts_node')
           and not gn_BoundaryType_ts(grid, node, param_gnBoundaryTypes)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use ts_node('" grid.tl:0 "', '" node.tl:0 "', '" param_gnBoundaryTypes.tl:0 "'), but there is no matching data in ts_node. " /;
    ); // END loop(groupUc1234)

    // if typo in 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_node')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension ('-'): '" uc4.tl:0 "' in ts_node multiplier: (grid, node, param_gnBoundaryTypes, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_gnn ------------------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_gnn'),

    // check 1st dimension (grid) when giving multiplier to ts_gnn
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_gnn')
           and  not grid(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of grid): '" uc1.tl:0 "' in ts_gnn multiplier: (grid, node, node, param_gnn)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (node) when giving multiplier to ts_gnn
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_gnn')
           and not node(uc2)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (name of node): '" uc2.tl:0 "' in ts_gnn multiplier: (grid, node, node, param_gnn)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension (node) when giving multiplier to ts_gnn
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_gnn')
           and not node(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (name of node): '" uc3.tl:0 "' in ts_gnn multiplier: (grid, node, node, param_gnn)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension (param_gnn) when giving multiplier to ts_gnn
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_gnn')
           and not param_gnn(uc4)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension (param_gnn): '" uc4.tl:0 "' in ts_gnn multiplier: (grid, node, node, param_gnn). See 'inc/1a_definitions.gms' for the full list of allowed param_gnn values." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if (grid, node, node_, param_gnn) combination has data in ts_gnn
    loop(groupUc1234(group, grid, node, node_, param_gnn)
        $ {p_userconstraint(group, grid, node, node_, param_gnn, 'ts_gnn')
           and not gn2n_timeseries(grid, node, node_, param_gnn)
           },
        put log "!!! Warning: p_userconstraint('" group.tl:0 "') tries to use ts_node('" grid.tl:0 "', '" node.tl:0 "', '" node_.tl:0 "', '" param_gnn.tl:0 "'), but there is no matching data in ts_gnn. " /;
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_reserveDemand --------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_reserveDemand'),

    // check 1st dimension (restype) when giving multiplier to ts_reserveDemand
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_reserveDemand ')
           and  not restype(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of restype): '" uc1.tl:0 "' in ts_reserveDemand multiplier: (restype, up_down, group, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 2nd dimension (up_down) when giving multiplier to ts_reserveDemand
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_reserveDemand ')
           and not [sameAs(uc2, 'up') or sameAs(uc2, 'down')]
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension (up / down): '" uc2.tl:0 "' in ts_reserveDemand multiplier: (restype, up_down, group, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 3rd dimension (group) when giving multiplier to ts_reserveDemand
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_reserveDemand ')
           and not group_(uc3)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension (name of group): '" uc3.tl:0 "' in ts_reserveDemand multiplier: (restype, up_down, group, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // that group is not group_uc
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_reserveDemand ')
           and not sameAs(uc3, group)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') 3rd dimension (name of group) in ts_reserveDemand multiplier: (restype, up_down, group, -) cannot be the same than the name of the user constraint." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check if (restype, up_down, group_) combination has data in ts_reserveDemand
    loop(groupUc1234(group, restype, up_down, group_, '-')
        $ {p_userconstraint(group, restype, up_down, group_, '-', 'ts_reserveDemand ')
           and not restypeDirectionGroup(restype, up_down, group_)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') tries to use ts_reserveDemand('" restype.tl:0 "', '" up_down.tl:0 "', '" group_.tl:0 "', '-'), but that combination has not been declared in p_groupReserves. " /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension ('-')
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_reserveDemand ')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension ('-'): '" uc4.tl:0 "' in ts_reserveDemand multiplier: (restype, up_down, group, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- ts_groupPolicy ----------------------------------------------------------

// loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), 'ts_groupPolicy'),

    // if typo in 1st dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_groupPolicy')
           and  not param_policy(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension of the constant: '" uc1.tl:0 "' should be defined param_policy, see 'inc/1a_definitions.gms'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 2nd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_groupPolicy')
           and not sameAs(uc2, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension of the constant: '" uc2.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_groupPolicy')
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension of the constant: '" uc3.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'ts_groupPolicy')
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension of the constant: '" uc4.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

); // END loop(groupUcParamUserConstraint)

* --- constant, equation type, new variable, penalty, method ------------------

// Loop relevant user constraint groups
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'constant')
        or SameAs(param_userconstraint, 'eq')
        or SameAs(param_userconstraint, 'gt')
        or SameAs(param_userconstraint, 'lt')
        or SameAs(param_userconstraint, 'toVariable')
        or SameAs(param_userconstraint, 'toVariableMultiplier')
        or SameAs(param_userconstraint, 'cost')
        or SameAs(param_userconstraint, 'penalty')
        or SameAs(param_userconstraint, 'eachTimestep')
        or SameAs(param_userconstraint, 'sumOfTimesteps')
        },

    // check that dimensions are '-'
    // if typo in 1st dimension. Should be '-' except with 'toVariable'
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc1, '-')
           and not sameAs(param_userconstraint, 'toVariable')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc1.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if type is 'toVariable', check that 1st dimension is -/LP/MIP,
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'toVariable')
           and not [ sameAs(uc1, '-')
                     or sameAs(uc1, 'LP')
                     or sameAs(uc1, 'MIP')
                     ]
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension of the " param_userconstraint.tl:0 "('-/LP/MIP', '-', '-', '-'). '" uc1.tl:0 "' should be '-/LP/MIP'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 2nd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc2, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc2.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc3.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc4.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // assume LP if using 'toVariable' and LP/MIP has not been defined
    // clear temporary group set
    option clear = group_tmp;
    // if type is 'toVariable', check if LP/MIP has not been specified
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'toVariable')
           and sameAs(uc1, '-')
           },
        put log "!!! Note: p_userconstraint('" group.tl:0 "') has not defined LP/MIP. " param_userconstraint.tl:0 "should have 'LP' or 'MIP' as the first dimension. Assuming LP." /;
        group_tmp(group) = yes;
    ); // END loop(groupUc1234)
    // update values in p_userconstraint and groupUc1234
    // Note: groupUc1234(group, '-', '-', '-', '-') is not cleared, because at least method needs it
    loop(group_tmp,
        p_userconstraint(group_tmp, '-', '-', '-', '-', 'toVariable') = no;
        p_userconstraint(group_tmp, 'LP', '-', '-', '-', 'toVariable') = yes;
        groupUc1234(group, 'LP', '-', '-', '-') = yes;
    ); // END loop(group_tmp)

    // assume 1 if using 'toVariable' and toVariableMultiplier has not been defined
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, 'toVariable')
           and not p_userconstraint(group, '-', '-', '-', '-', 'toVariableMultiplier')
           },
        p_userconstraint(group, '-', '-', '-', '-', 'toVariableMultiplier') = 1;
    ); // END loop(groupUc1234)

    // check that if 'cost' is used, 'toVariable' is activated
    if( {sameAs(param_userconstraint, 'cost')      // needed to limit only to one param
         and p_userconstraint(group, '-', '-', '-', '-', 'cost')
         and not [p_userconstraint(group, 'LP', '-', '-', '-', 'toVariable')
                  or p_userconstraint(group, 'MIP', '-', '-', '-', 'toVariable')
                  ]
         },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') tries to give cost parameter, but 'toVariable' is not activated. Add toVariable to this userconstraint." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)


); // END loop(groupUcParamUserConstraint)


// abort if following have other values than TRUE (-1)
loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'eq')
        or SameAs(param_userconstraint, 'gt')
        or SameAs(param_userconstraint, 'lt')
        or SameAs(param_userconstraint, 'toVariable')
        or SameAs(param_userconstraint, 'eachTimestep')
        or SameAs(param_userconstraint, 'sumOfTimesteps')
        },
    if(p_userconstraint(group, '-', '-', '-', '-', param_userconstraint)
       and p_userconstraint(group, '-', '-', '-', '-', param_userconstraint)<>-1,
         put log "!!! Abort: p_userconstraint('" group.tl:0 "') parameter (" param_userconstraint.tl:0 ") has other value than 'TRUE'. Note: -1 is also accepted as GAMS translates 'TRUE' to -1." /;
         tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END if
); // END loop(groupUcParamUserConstraint)


// Check that every userconstraint has valid definition of equation type and method
loop(group_uc(group),

    // check that equation type has been declared
    if([sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'eq'), 1)
         + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'gt'), 1)
         + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'lt'), 1)
         ] = 0,
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') must have an equation type (eq/gt/lt)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END if

    // abort if multiple equation types has been declared
    if([sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'eq'), 1)
         + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'gt'), 1)
         + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'lt'), 1)
         ] > 1,
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') cannot have multiple equation types (eg/gt/lt)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END if

    // abort if multiple methods has been declared
    if([sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'eachTimestep'), 1)
         + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'sumOfTimesteps'), 1)
         ] > 1,
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') cannot have multiple methods (eachTimestep/sumOfTimesteps)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END if

    // assume 'eachTimestep' if method has not been declared
    // note: if condition within sum of ones to handle situations where e.g. 'gt' is flagged TRUE (-1 in GAMS), and eq = 1.
    if([sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'eachTimestep'), 1)
        + sum(groupUc1234(group, uc1, uc2, uc3, uc4)$p_userconstraint(group, uc1, uc2, uc3, uc4, 'sumOfTimesteps'), 1)
        ] = 0,
        p_userconstraint(group, '-', '-', '-', '-', 'eachTimestep') = -1;
    ); // END if

); // END loop(groupUcParamUserConstraint)


* --- sft filtering --------------------------------------------------------

loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'sample')
        or SameAs(param_userconstraint, 'forecast')
        or SameAs(param_userconstraint, 'timestep')
        or SameAs(param_userconstraint, 'effLevel')
        },

    // check 1st dimension (sample) when filtering samples
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and SameAs(param_userconstraint, 'sample')
           and  not s(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of sample): '" uc1.tl:0 "' in sample filtering: (s, -, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 1st dimension (forecast) when filtering forecasts
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and SameAs(param_userconstraint, 'forecast')
           and  not f(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of forecast): '" uc1.tl:0 "' in forecast filtering: (f, -, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 1st dimension (timestep) when filtering timesteps
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and SameAs(param_userconstraint, 'timestep')
           and  not t(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of timestep): '" uc1.tl:0 "' in timestep filtering: (t, -, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // check 1st dimension (level) when filtering effLevels
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and SameAs(param_userconstraint, 'effLevel')
           and  not effLevel(uc1)
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 1st dimension (name of effLevel): '" uc1.tl:0 "' in effLevel filtering: (effLevel, -, -, -)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 2nd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc2, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 2nd dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc2.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 3rd dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc3, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 3rd dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc3.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // if typo in 4th dimension
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and not sameAs(uc4, '-')
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') has typo in the 4th dimension of the " param_userconstraint.tl:0 "('-', '-', '-', '-'). '" uc4.tl:0 "' should be '-'." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(groupUc1234)

    // abort if other values than -1
    loop(groupUc1234(group, uc1, uc2, uc3, uc4)
        $ {p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint)
           and p_userconstraint(group, uc1, uc2, uc3, uc4, param_userconstraint) <> -1
           },
        put log "!!! Abort: p_userconstraint('" group.tl:0 "') filtering for " param_userconstraint.tl:0 ": " uc1.tl:0 "has other value than 'TRUE' (-1 is also accepted as GAMS translates 'TRUE' to -1)." /;
        tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
    ); // END loop(s)

    // warning if not active s, f, or t in 3a_periodicInit

); // END loop(groupUcParamUserConstraint)


* --- Aborting if trying to use LP, MIP, - in param_uc (5th dimension of UC) --

loop(groupUcParamUserConstraint(group_uc(group), param_userconstraint)
    $ { SameAs(param_userconstraint, 'LP')
        or SameAs(param_userconstraint, 'MIP')
        or SameAs(param_userconstraint, '-')
        },
    put log "!!! Abort: p_userconstraint('" group.tl:0 "') tries to use " param_userconstraint.tl:0 " as user constraint parameter. '-' is allowed sometimes in dimensions 1-4. 'LP' and 'MIP' are allowed sometimes in dimension 1." /;
    put log "!!! Check userconstraint documentation and cheat sheet for correct use." /;
    tmp = tmp +1;   // increasing tmp counter instead of direct abort call to list all typos
); // END loop(groupUcParamUserConstraint)


* --- Checking error state and aborting if necessary --------------------------

// Aborting the model run after looping all group_uc if errors in domain checks
if(tmp > 0,
    abort "Fail in p_userconstraint domain checks, see backbone.log for more details!"
);





* =============================================================================
* --- Default values  ---------------------------------------------------------
* =============================================================================

* using certain default values when not running from debug gdx file.

$ifthen.input_file_debugGdx not set input_file_debugGdx

    // By default all units use forecasts for all time series
    unit_forecasts(unit, 'ts_unit') = yes;
    unit_forecasts(unit, 'ts_unitConstraint') = yes;
    unit_forecasts(unit, 'ts_unitConstraintNode') = yes;
    // ts_vomCost and ts_startupCost activated through ts_price and ts_emissionPrice

    // By default all nodes use forecasts for all time series
    gn_forecasts(gn, timeseries) = yes;
    gn_forecasts(flowNode, 'ts_cf') = yes;

    // By default all restypes use forecasts for all time series
    gn_forecasts(restype, node, 'ts_reserveDemand') = yes;
    gn_forecasts(restype, node, 'ts_reservePrice') = yes;

    // To guarantee backwards compatibility, do not activate group forecasts by default
    option clear = group_forecasts;

    // To guarantee backwards compatibility, do not activate group forecasts by default
    option clear = ts_gnu_activeForecasts;

    // By default the last v_state and v_online in f02,f03,... are bound to f01
    mSettings(mType, 'boundForecastEnds') = 1;

    // default scaling factors
    p_scaling = 1;
    p_scaling_obj = 1;
    p_scaling_n(node) = 1;
    p_scaling_nn(node, node_)${sum(grid, p_gnn(grid, node, node_, 'isActive'))} = 1;
    p_scaling_u(unit) = 1;


$endif.input_file_debugGdx
