$title Backbone
$ontext
Backbone - chronological energy systems model
Copyright (C) 2016 - 2024  VTT Technical Research Centre of Finland

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

For further information, see https://gitlab.vtt.fi/backbone/backbone/-/wikis/home

==========================================================================
Created by:
    Juha Kiviluoma
    Erkka Rinne
    Topi Rasku
    Niina Helisto
    Dana Kirchem
    Ran Li
    Ciara O'Dwyer
    Jussi Ikaheimo
    Tomi J. Lindroos
    Eric Harrison

This is a GAMS implementation of the Backbone energy system modelling framework
[1]. Features include:
- Based on Stochastic Model Predictive Control method [2].
- Time steps (t) can vary in length.
- Short term forecast stochasticity (f) and longer term statistical uncertainty (s).


GAMS command line arguments

--changes_inc=<filename>
    Filename of additional changes to the input data. Defaults to 'changes.inc'.
    Backbone tries to read the file first from %input_dir%/%changes_inc%. If it does not
    exist, then from %changes_inc% directly. The model warns if custom defined changes_inc
    was not found from either location. The model aborts if there are errors when
    reading the file.

--debug=[0|1|2]
    Set level of debugging information. Default is 0 when no extra information is
    saved or displayded. At level 1, file 'debug.gdx' containing all GAMS symbols
    is written at the end of execution. At level 2, debug information is written
    for each solve separately.

--diag=[yes|'']
    Switch diagnostics on. Writes some additional diagnostic results in
    'results.gdx' about data updates and efficiency approximations.
    Default value ''.

--input_dir=<path>
    Directory to read input from. Defaults to './input'.
    Path can be absolute, e.g. 'C:/backbone/myModel'
    or relative, e.g. ./myModel

--init_file=<filename>
    Filename of the init file used in temp_modelsInit.gms. Often replaced with
    hard coded value when users create their own modelsInit files.
    Default 'scheduleInit.gms'

--input_file_gdx=<filename.gdx>
    Filename of the GDX input file. Defaults to 'inputData.gdx'.
    --input_file_gdx=myInputData.gdx reads the file from input_dir
    --input_file_gdx='c:/myModel/myInputData.gdx' read a specific file from a specific folder
    Note: when used with input_file_excel, the created gdx file is always stored in input_dir

--input_file_excel=<filename>
    Filename of the Excel input file. If this filename is given, the GDX input
    file is generated from this file using Gdxxrw.

--input_excel_index=<spreadsheet name>
    Used with input_file_excel: the spreadsheet where the options and symbols
    are read. Defaults to 'INDEX'.

--input_excel_checkdate=checkDate
    Used with input_file_excel: write GDX file only if the input file is more
    recent than the GDX file (value = checkDate). Disabled by default (value = '').

--input_file_debugGdx_v38=<filename>
    Filename of the debug.gdx as input file from Backbone version 3.8. If this filename
    is given, all input is read from a debug file and other sources except %changes_inc%
    are skipped. Produces otherwise the same model run than in the original
    debug file, but does not necessarily have the same 1_options.gms, cplex.opt,
    2c_alternative_objective.gms, or other possible additional constraints.
    Disabled by default (value = '').

--input_file_debugGdx_v39=<filename> As above, but for Backbone v3.9

--input_file_debugGdx_v310=<filename> As above, but for Backbone v3.10

--input_file_debugGdx_v311=<filename> As above, but for Backbone v3.11

--onlyPresolve=[yes|'']
    Do not solve the model, just do preliminary input data processing.
    For testing purposes. Not compatible with resultsVer2x option
    Default value ''.

--output_dir=<path>
    Directory to write output to. Defaults to './output'.

--output_file=<filename.gdx>
    Filename of the results file. Defaults to 'results.gdx'

--penalty=<value>
    Changes the value of the penalty cost. Default penalty value is 10e4 for
    schedule and building models and 10e6 for invest models if not provided.

--rampSched==[yes|'']
    If activated, runs inc/rampSched/sets_rampSched.gms if exists.
    Default value ''.
    note: rampSched is not fully functional in 3.x. This is temporary solution
    before removing or fixing it.

--resultsVer2x=TRUE
    Flag to use backbone 2.x result tables. Default value ''

--small_results_file==[yes|'']
    If activated, clears time series results from the results.gdx significantly
    decreasing the file size.
    Default value ''.

--warnings==[0|1]
    By default the warnings are on [1]. This includes some automatic adjustments
    to input data and checking the data going to model. Checks can spring either an
    abort or a warning. When warnings are turned off [0], the model still does the
    automatic input data adjustments but does not warn about those, skips all warning
    checks, but still runs the checks that could abort the model run.


References
----------
[1] N. Helist et al., Backbone---An Adaptable Energy Systems Modelling Framework,
    Energies, vol. 12, no. 17, p. 3388, Sep. 2019. Available at:
    https://dx.doi.org/10.3390/en12173388.
[2] K. Nolde, M. Uhr, and M. Morari, Medium term scheduling of a hydro-thermal
    system using stochastic model predictive control,  Automatica, vol. 44,
    no. 6, pp. 15851594, Jun. 2008.

==========================================================================
$offtext

* Check current GAMS version
$ife %system.gamsversion%<240 $abort GAMS distribution 24.0 or later required!

* Set default debugging level
$if not set debug $setglobal debug 0

* Default values for input and output dir as well as input data GDX file and index sheet when importing data from Excel file
* When reading an Excel file, you can opt to read the file only if the Gdxxrw detects changes by using 'checkDate' for
*   input_excel_checkdate. It is off by default, since there has been some problems with it.
$if not set changes_inc $setglobal changes_inc 'changes.inc'
$if not set init_file $setglobal init_file 'scheduleInit.gms'
$if not set input_dir $setglobal input_dir 'input'
$if not set input_file_gdx $setglobal input_file_gdx 'inputData.gdx'
$if not set input_excel_index $setglobal input_excel_index 'INDEX'
$if not set input_excel_checkdate $setglobal input_excel_checkdate ''
$if not set output_dir $setglobal output_dir 'output'
$if not set output_file $setglobal output_file 'results.gdx'
* note: rampSched is not fully functional in 3.x. This is temporary solution before removing or fixing it.
$if not set rampSched $setglobal rampSched ''
$if not set small_results_file $setglobal small_results_file ''
$if not set warnings $setglobal warnings '1'

*Different debugGdx versions
$if set input_file_debugGdx_v38 $setglobal input_file_debugGdx %input_file_debugGdx_v38%
$if set input_file_debugGdx_v38 $setglobal debugGdx_ver 3.08
$if set input_file_debugGdx_v39 $setglobal input_file_debugGdx %input_file_debugGdx_v39%
$if set input_file_debugGdx_v39 $setglobal debugGdx_ver 3.09
$if set input_file_debugGdx_v310 $setglobal input_file_debugGdx %input_file_debugGdx_v310%
$if set input_file_debugGdx_v310 $setglobal debugGdx_ver 3.10
$if set input_file_debugGdx_v311 $setglobal input_file_debugGdx %input_file_debugGdx_v311%
$if set input_file_debugGdx_v311 $setglobal debugGdx_ver 3.11

* Make sure input dir exists
$ifthen.inputDir not dexist '%input_dir%'
    $$put log "!!! Abort: Did not find input directory " %input_dir% ", check path and spelling!"
    $$abort "Did not find input directory, check path and spelling!"
$endif.inputDir

* Make sure output dir exists
$if not dexist '%output_dir%' $call 'mkdir "%output_dir%"'

* Make sure input_file_debugGdx exists
$ifthen.runFromDebug set input_file_debugGdx
$ifthen.fileExists exist '%input_dir%/%input_file_debugGdx%'
$else.fileExists
    $$put log "!!! Abort: User has requested to run the model from '"%input_dir%/%input_file_debugGdx%"', but the file was not found. Check path and spelling!"
    $$abort "Did not find input debug gdx from input directory, check path and spelling!"
$endif.fileExists
$endif.runFromDebug


* Activate end of line comments and set comment character to '//'
$oneolcom
$eolcom //

* Output file streams
Files log /''/, gdx /''/, f_info /'%output_dir%/info.txt'/;


* if not running from debug gdx
$ifthen.runFromDebug set input_file_debugGdx
$else.runFromDebug
* Include options file to control the solver (if it does not exist, uses defaults)
$ifthen.options exist '%input_dir%/1_options.gms'
    $$include '%input_dir%/1_options.gms';
$elseif.options %warnings% == 1
    put log "!!! Warning: 1_options.gms was not found from the input folder." /;
$endif.options
$endif.runFromDebug


* === Definitions, sets, parameters and input data=============================
$include 'inc/1a_definitions.gms'   // Definitions for possible model settings
$include 'inc/1b_sets.gms'          // Set definitions used by the models
* 1b_sets reads %input_dir%/timeAndSamples.inc if exists
* 1b_sets reads inc/rampSched/sets_rampSched.gms if --rampSched==yes and the file exists
* note: rampSched is not fully functional in 3.x. This is temporary solution before removing or fixing it.
$include 'inc/1c_parameters.gms'    // Parameter definitions used by the models
$include 'inc/1d_results.gms'       // Parameter definitions for model results
$include 'inc/1e_inputs.gms'        // Load input data
* 1e_inputs converts %input_dir%/%input_file_excel% or %input_file_excel%  to %input_dir%/%input_file_gdx%
* input_dir%/additionalSetsAndParameters.inc if exist
* 1e_inputs reads %input_dir%/%input_file_gdx% or %input_file_gdx%
* 1e_inputs reads also following files:
*      - inc/1e_scenChanges.gms,
*      - %input_dir%/%changes_inc% if exist


* === Variables and equations =================================================
$include 'inc/2a_variables.gms'                         // Define variables for the models
$include 'inc/2b_eqDeclarations.gms'                    // Equation declarations
$ifthen.altObj exist '%input_dir%/2c_alternative_objective.gms' // Objective function - either the default or an alternative from input files
    $$include '%input_dir%/2c_alternative_objective.gms';
$else.altObj
    $$include 'inc/2c_objective.gms'
$endif.altObj
$include 'inc/2d_constraints.gms'                       // Define constraint equations for the models
    // 2d reads additional file '%input_dir%/additional_constraints.inc' if exists
$ifthen.addConst exist '%input_dir%/2e_additional_constraints.gms'
   $$include '%input_dir%/2e_additional_constraints.gms'      // Define additional constraints from the input data
$endif.addConst


* === Model definition files ==================================================

$ifthen.debugGdx not set input_file_debugGdx
    // Load model input parameters, unless input file debug gdx is set
    // ModelsInit normally calls another init file, e.g. '%input_dir%/scheduleInit.gms' or '%input_dir%/investInit.gms'
    // In addition, it allows making adjustments after variables and constraints are created.
    $$include '%input_dir%/modelsInit.gms'
$endif.debugGdx

// load default model definitions and possible additional definitions from %input_dir%/[schedule/buildings/invest]_additional_constraints.gms'
$include 'defModels/schedule.gms'
$include 'defModels/building.gms'
$include 'defModels/invest.gms'


* === Simulation ==============================================================
// Macro for checking solve and model status
$macro checkSolveStatus(mdl) \
    if(mdl.solveStat > 3 or not (mdl.modelStat = 1 or mdl.modelStat = 8), \
        execError = execError + 1 \
    )

// Setting up the simulation
$include 'inc/3a_periodicInit.gms'  // Initialize modelling loop
loop(modelSolves(mSolve, t_solve)$(execError = 0),
    solveCount = solveCount + 1;
    $$include 'inc/3b_periodicLoop.gms'         // Update modelling loop
    $$include 'inc/3c_inputsLoop.gms'           // Read input data that is updated within the loop
    $$include 'inc/3d_setVariableLimits.gms'    // Set new variable limits (.lo and .up)
    // 3d reads additional file '%input_dir%/changes_loop.inc' if exists

// Running the simulation and printing primary result tables, except when --onlyPresolve=yes
$iftheni.onlyPresolve not %onlyPresolve% == 'yes'
    $$include 'inc/3e_solve.gms'                // Solve model(s)
    $$include 'inc/3f_afterSolve.gms'           // Post-processing variables after the solve
    $$include 'inc/4a_outputVariant.gms'        // Store results from the loop
    // 4a reads additional file '%input_dir%/additional_outputVariants.inc' if exists
$endif.onlyPresolve

// if --debug=2, debug file is written for each solve
$ifthene.debug %debug%>1
        putclose gdx;
        put_utility 'gdxout' / '%output_dir%/' mSolve.tl:0 '-' t_solve.tl:0 '.gdx';
            execute_unload
            $$include defOutput/debugSymbols.inc
        ;
$endif.debug
);

$if exist '%input_dir%/3z_modelsClose.gms' $include '%input_dir%/3z_modelsClose.gms';

* === Output ==================================================================


$iftheni.onlyPresolve not %onlyPresolve% == 'yes'
    // calculating remaining result tables
    $$include 'inc/4b_outputInvariant.gms'


* converting results to 2.x format if user given option is '2x'
$if set resultsVer2x $include 'inc/4b_outputInvariant_convertTo2x.gms'
* selecting correct set of result symbols
$if set resultsVer2x $setglobal resultSymbols 'resultSymbols_2x.inc'
$if not set resultsVer2x $setglobal resultSymbols 'resultSymbols.inc'

$include 'inc/4c_outputQuickFile.gms'

* Post-process results
$if exist '%input_dir%/4d_postProcess.gms' $include '%input_dir%/4d_postProcess.gms'

$ifthen.addResults exist '%input_dir%/additionalResultSymbols.inc'
   execute_unload '%output_dir%/%output_file%',
     $$include 'defOutput/%resultSymbols%'//,
     $$include '%input_dir%/additionalResultSymbols.inc'
   ;
$else.addResults
   execute_unload '%output_dir%/%output_file%',
     $$include 'defOutput/%resultSymbols%'//,
   ;
$endif.addResults
$endif.onlyPresolve

$ife %debug%>0
execute_unload '%output_dir%/debug.gdx';
if(execError,
   putclose log "!!! Errors encountered: " execError:0:0/;
   abort "FAILED";
);
* === THE END =================================================================
