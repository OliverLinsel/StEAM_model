# Changelog
All notable changes to this project will be documented in this file.

## unversioned

### Added
- node balance plotter python tool, BB_nodeBalance.py
- instructions for the node balance plotter, BB_nodeBalance_readme.md
- p_gnu('cb') for a quick and easy way to define fixed ratio between two outputs and/or two inputs
- p_gnu('cv') for a quick and easy way to define flexible operation area between two outputs
- adding p_gnu_io('rampUpCost) and p_gnu_io('rampDownCost) for flat ramp costs
- r_state_gnsft with additional s dimension compared to default r_state_gnft
- effLevel filtering to userconstraints
- p_gnn('diffLosses') for modelling specific cases with diffusion losses

### Changed
- providing unique names to parameter and result table dimensions: (node, node) -> (from_node, to_node)
- Splitting v_genRamp to v_genRampUp and v_genRampDown
- clarifying the old ramp cost equations in comments as piecewise ramp cost equations.
- allowing easier inserting of additional input data: skipping automatic loading of input data tables starting with 'add_' prefix. 
- simplifying input data structure
  * assuming directOff as default effLevel of units
  * removing the need to declare empty mz and zs sets in init files
  * removing the need to declare empty mSettingsReservesInUse set in init files
- Removing plot_generator.py

### Fixed
- Storage states were not always bound by upwardLimit and downwardLimit just before the samples 
- Automatically clearing Eps values from p_unit('op') fields 
- Fixing a crash related to aggregator and aggregated units
- rolling solve count in the model log, when starting the rolling solve later than t000001
- multiple smaller issues when running different models from debug file
- Improved logic to assess p_unit('unitCount'): not giving automatically unitCount = 1, if sum of gnu capacities is zero
- operational costs in case of no fuel or emission prices, only vomCosts
- r_diffusion_gnn was not calculated in certain cases
- aggregating slack timeseries with minimum method

### Performance
- Slightly faster compilation due to 
    * stricter filtering of units that require ramp equations
    * more efficient building of eff_usft

### Warnings, aborts, and notifications
- Improved warnings for easier debugging of certain cases
  * Adding a warning if all units in the model have zero availability
  * Adding a warning if all units in the model get deactivated 
  * Adding a warning if all transfer links in the model have zero availability
  * Adding a warning if unit does not have capacity and is not flow unit, investment unit, or bound by unitConstraint or userconstraints
  * adding a warning if unit has zero conversionCoeff for every gnu

- Handling certain warnings better to avoid unnecessary warningns:
  * not warning about missing 1_options.gms when running from debug file
  * handling a warning about capacity <> unitSize * unitCount better with certain input data combinations
  * removing an unnecessary warning about missing upwardLimit in case of investment model with unit defining upwardLimit with p_gnu('upperLimitCapacityRatio')
  * avoiding multiple warnings with different messages if unit has zero capacity, but positive unitcount

- Downgrading warnings to notifications due to improved model fuctionalities:
  * downgrading an abort of partial transfer ramplimit data to a notification
  * downgrading warning of missing datalength to a notification
  * replacing a warning about Eps in p_gnn('transferCap') to a silent replacement with 0

- Downgrading notifications to silent assumptions
  * replacing a notification about Eps in p_unit('unitCount') to a silent replacement with 0
  * Now silently removing flow unit data from effLevelGroupUnit, p_gnu_io('conversionCoeff'), p_unit('eff'), and p_unit('op')





## 3.11.0 - 2025-02-04

### Added
- adding unit output delays p_gnu_io('delay')
- adding sink and source units p_unit('isSink') and p_unit('isSource')
- userconstraint improvements
    - v_spill, v_startup, v_shutdown, v_gen_delay to userconstraints
    - adding an option for custom penalty values for userconstraints
    - adding an option to create MIP variables with user constraints
    - adding toVariableMultiplier for broader use cases of new variables
    - allowing toVariable userconstraints with all constraint types (EQ/GT/LT). Equation type needs to be defined as EQ to maintain the functionalities of 'toVariable' in v3.10 userconstraints.
- Improved ramp results, unit ramp dummies, and ramp diagnostics
    - r_genRamp result table for units with ramp constraints or ramp costs
    - r_cost_unitRampCost for units with ramp costs     
    - vq_genRamp, a new dummy for unit generation ramp constraints and related results table r_qGenRamp
    - diagnostic table d_qGenRamp for more detailed debugging  
    - minor improvement in solver behaviour with gen ramps
- ts_gnu_io for timeseries format vomCosts
- two new result tables (r_cost_penalty and r_cost_penalty_ft) showing the sum cost of all dummies
- adding parameter to run the model from debug.gdx for v3.11 --input_file_debugGdx_v311=<filename>
- allowing a custom location of changes_inc. The backbone will try to read first %input_dir%/%changes_inc%, then %changes_inc% directly

### Changed
- finalizing unfinished state slacks
    - state slack now allows a limited violation of storage states in defined steps (upwardSlack01..20, downwardSlack01..20)
    - each step should be associated with a cost (slackCost)
    - slacks can be defined as constants or timeseries. Cost of each step is constant.
    - previous q_stateSlack is split to q_stateUpwardSlack and q_stateDownwardSlack
- using 'upperLimitCapacityRatio' also from existing capacity

### Fixed
- removed steplength multiplication from unit rampCost in objective. Bug was added when rewriting the objective function for v3.9. 
- slightly improved compilation time of q_obj by reducing unnecessary looping 
- multiple fixes to result tables
    - cost result tables now calculate correctly in case of aggregated realized hours and summer-to-summer runs
    - aligning that existing unit fomCost calculations in result tables work as in objective function
    - fixing unit vomCost results tables in case of activated roundings and vomcosts below the rounding precision
    - handling a possible div by zero when calculating r_gen_utilization rate
    - fixing that r_userconstraint result tables were not always generated
    - fixing that userconstraint dummy result tables was not generated in case of decrease dummies with sumOfTimesteps method
    - Correcting the units in the description of some cost result tables (MW x h -> MEUR)
    - Skip reading 2.x results if doing only input data processing (--onlyPresolve=yes)
    - removing tiny values (smaller than 1e-10) from hourly results tables: r_balance_marginalValue, r_gen, r_spill, and r_reserve
    - removing tiny values (smaller than 1e-9) from annual result tables: generation sums e.g. r_gen_g
    - removing potential Eps values from results tables in cases with investment candidates that were not invested in to
- increased control over which type of dummy variables are reduced. Now e.g. "mSettings('schedule', 'reducedVqGen') = Eps;" works as expected.
- aligning that sumOfTimesteps userconstraints handle aggregated timesteps as other functions in the model
- equations requiring historical values, eg. minimum online time and maximum ramps, did not work after the initialization period
- avoiding to generating unnecessary ramp equations on the first timestep when t_start is larger than sample start

### Warnings, aborts, and notifications
- New warnings and checks
    - adding a warning if a unit has zero capacity in p_gnu, but still has unitCount in p_unit
    - adding warnings if giving impartial unit ramp cost data
    - warning and deactivating a unit if the unit does not have any data in p_unit 
    - warning if unit does not have a unittype
    - adding stricter checks of userconstraint input when parameter, e.g. the equation type, should have value 'TRUE'
- removing unintentional warnings in several cases
    - removed an unnecessary warning in case of single sample investment model not covering t_start
    - checking several warnings about if using forecasts and X only when there are active forecasts
- downgrading certain warnings to notifications 
    - in the end of the model run about dummies if user has set custom penalty values lower than the default penalty value
    - if node has usePrice activated, but no price data
    - if there is no data for sample discount weight and the model uses default assumption of 1
- clarified certain warnings
    - clarified warnings if ts_influx or ts_cf has more hours than mSettings('datalength')
    - clarified warning if timeAndSamples.inc have less t than needed by model settings

### Documentation, clarification
- Reorganizing 4a_outputVariant.gms, adding table of contents, and improving comments
- uploading Backbone logos and installation instructions to images folder


## 3.10.1 - 2024-09-24

### Added
- v_investTransfer to userconstraints
- new result table of userconstraint costs
- nonanticipativity option when running the model with forecasts

### Fixed
- adding userconstraint costs to total cost results tables


## 3.10.0 - 2024-09-19

### Added
- user-defined generic userconstraints
  - works with following variables: v_state, v_transfer, v_transferLeftward, v_transferRightward, v_transferRamp, v_gen, v_online, v_invest, v_reserve, v_userconstraint
  - works with following input time series: ts_unit, ts_influx, ts_cf, ts_node, ts_gnn, ts_reserveDemand, ts_groupPolicy
  - multiple equation types: eq, gt, lt, toVariable 
  - possibility to add cost component when using toVariable equation type
  - allowing filtering of sft (sample, forecast, timestep) to control when userconstraint is applied
  - two possible methods: eachTimestep, sumOfTimesteps
  - new dummy variables for userconstraints
  - new results tables of dummies (r_qUserconstraint) and of v_userconstraint values when choosing equation type toVariable (r_userconstraint)
- option to run the model with silent warnings (--warnings=0)
- constant influx p_gn('influx')
- diagnostic result tables for dummy variables in solve horizons
- a result table approximating unit profits - r_unit_profit_u
- a result table calculating full load cycles of storages - r_state_fullCycles_gn

### Changed
- Now directOnLP and directOnMIP units can have zero op00
- Moving example files from the input folder to inputTemplates folder
- removed diagnostic result tables for input time series (ts_cf, ts_influx, ts_node)
- renamed diagnostic result tables d_ttAmount -> d_tByCounter, and d_ttIntervalAmount -> d_tStepsByCounter
- replacing input_file_debugGdx with input_file_debugGdx_v38, input_file_debugGdx_v39, and input_file_debugGdx_v310 
- Using also ts_cf to calculate mSettings(m, 'datalength') if not given in input data
- updating automatic scaling to improve the clarity of code and access new scaling features
- Stricter filtering of start variables to generate less equations
- Transfer losses not increasing price when buying from a price node. Making symmetrical assumption that seller is responsible for losses.
- r_balance_marginalValue_gnAverage does not include dummy values when calculating the average

### Fixed
- improved automatic calculation of missing unit count in case of existing flow units
- correctly clearing Eps in unitSize
- Several divByZero with scaling when defining transmission line only to one direction
- deactivating unit deactivates the gnu also if these gnu are specifically declared active
- result tables r_stateChange and r_stateChangeValue 
- r_gen_utilizationRate is now positive also for consumption
- clearing rounding errors from r_curtailments
- bug with spaces in input or output data paths
- bug in loop reading ts_unit data
- fixing r_curtailments result table when using ts_cf roundings
- updating the logic of an automatic checking of t_end and t_jump to allow summer-to-summer invest runs
- utilization result table now works also with multiyear runs
- defining ramp costs without maxRampUp/maxRampDown now correctly activates ramp equations
- not generating spill variables if maxSpill/minSpill is Eps
- not generating investment energy cost equations if cost is Eps

### Warnings, aborts, and notifications
- Showing a warning at the end of the model run if the results have dummies
- improved checking on the validity of gn pairs
- warning if trying to give influx for a price node
- adding a warning if 1_options.gms was not found from the input folder
- added an abort if interval blocks are not defined in order
- added an abort if an interval block does not have 'lastStepInIntervalBlock' defined
- added and abort if directOnLP or directOnMIP unit has less than two effXX defined
- added and abort if directOnLP or directOnMIP unit has effXX defined without opXX from eff01 onwards
- removing possible unnecessary warning of different transfer connection ramp speeds due to rounding precision
- removed unnecessary warning about not covering all data in ts_influx if mSettings(m, 'datalength') was not given
- added a warning if storage does not have downwardLimit defined
- added an abort if input directory does not exist
- Downgrading multiple directOff, flow unit, and effLevel related warnings to notifications 
- Suppress unintentional warnings when model definition files contain $if conditionals


## 3.9.1 - 2024-04-24

### Added
- new result table r_stateChange_gn showing the change in node states (MWh) from the first t to the last t
- new result table r_stateChangeValue_gn showing average marginal value of the node multiplied by state change
- new result table r_stateChangeValue showing the sum of state change

### Changed
- automatically deactivating links to/from deactivated nodes

### Fixed
- a case where nodes had a mixture of constant and time series prices with and without price forecasts
- forecast displacement when calculating vomCosts with node price time series
- now isActive = Eps actually deactivates gn, gnn, gnu, or unit
- divByZero with scaling when defining a transfer connection to only one direction
- a case where a node with influx was automatically deactivated
- a case where certain active nodes were not included to gn that is a central set used to generate the model

### Warnings and aborts
- abort and instructions to check backbone.lst if Backbone fails reading input data gdx
- abort and instructions to check backbone.lst if Backbone fails reading changes.inc
- a warning that p_gnn('transferCapBidirectional') is an uncomplete feature and p_gnn('transferCap') should be used instead


## 3.9 - 2024-04-24

### Added - new features
- interpolation of time series between circulated ts data 
- option to sell reserves to external reserve markets
- reserve price time series as input data
- result tables of reserves sold to reserve markets
- transfer links can sell commodities, e.g. electricity to other nodes
- active flags for p_gn, p_gnn, p_gnu_io, p_unit
- unit lesser than constraints lt1...lt9
- option to create min/fixed/max generation dconstraints for units 
- ts_unitConstraint for time series format min/fixed/max generation constraints
- p_unitConstraintNew that has more features than p_unitConstraint
- option to cplex.opt template to print full model equations to backbone.lp file
- option for user given output variants (%input_dir%/additional_outputVariants.inc) for new result tables that need values directly from model variables instead of other result tables
- opt file for cbc solver

### Speed improvements
- an option to reduce the amount of generated dummy variables (vq_gen, vq_resDemand, vq_resMissing, vq_unitConstraint)
- Automatically dropping data from deactivated gn, gnn, gnu, and unit
- Automatically dropping effLevel data if init file does not use those effLevels
- an option to scale the input data
- an option for automatic parameter and time series roundings
- rewriting objective function for improved performance and clarity
- not creating q_resTransferLimitRightward and q_resTransferLimitLeftward for transfer investments unless they can transfer reserves

### Changed
- objective function is not scaled by million by default. Result tables do not change to maintain backward compatibility.
- relaxed checks for unitConstraintNode: can define only one node for constraint if defining also a lt/fx/gt constant
- relaxed checks for unitConstraintNode: can define both constant and time series for same nodes. Time series get priority.
- enabled q_emissioncapNodeGroup, q_energyLimit, and q_energyShareLimit in schedule model template
- Allowing emission price for one emission in multiple groups

### Fixed
- Removed a warning about t_improveForecastNew length when not using the feature
- upper bounds of v_startup and v_online at t0 before the first solve
- fixed an issue with numerical precision when calculating unit efficiency parameters
- t_full now covers also the last hour of the horizon
- t_full now covers also the first hours of timeseries if starting the modelling from the middle of the year
- t_forecastLengthDecreasesFrom now works correctly if starting the modelling from the middle of the year
- not expanding effLevel unnecessarily unless init file uses those effLevels
- q_resDemand now uses ts_reserveDemand_ instead of ts_reserveDemand
- boundSumOverInterval in certain cases when using forecasts
- fixed an issue with forecasts when providing input data only for f0 and using smaller forecast length than horizon
- Now warning only once when defining transfer link 'rampLimit' to a connection with different capacities to different directions
- added identifier tags to if/ifthen functions which read user input files to remove GAMS warning on nested untagged if/ifthen statements

### Quality of life updates
- info about of deactivated gn, gnn, gnu, and unit in model solve screen and in debug file
- Automatically replacing Eps in transferCap with zero (=empty) to avoid a crashes
- Automatically replacing Eps in unitSize with zero (=empty) to avoid a crashes
- forecasts are not activated if only f00 exists
- node_superpos(node) is automatically declared empty and user can remove this from modelInit files or give data there as before

### Warnings and aborts
- checks and aborts for negative unit capacity, unit size, or unit count
- check and abort if unit has multiple efficiency selectors (directOff, directOnLP, etc) for a single effLevel
- an abort in cases where online unit has op00 = op01
- multiple checks and warnings about start cost and start fuel consumption parameters
- reducing a warning about directOff start costs to a notification
- a warning of cases where user gives more than one 'becomeAvailable' or 'becomeUnavailable' for one unit
- a warning if conversion unit does not have inputs or outputs
- a warning if using constrainedOnlineMultiplier with directOff unit
- a warning if model has forecasts defined, but no forecasts are activated
- warning if activating gn_forecasts for gn that does not exist
- a warning if central forecast = f00 while using forecasts
- a warning if central forecast > f00 while not using forecasts
- an abort if multiple central forecasts
- a warning if there is more than one forecast, but they do not have 't_forecastLengthUnchanging' or 't_forecastLengthDecreasesFrom'
- warnings if forecasts activated in unit_forecasts, gn_forecasts, group_forecasts and no matching data
- warnings if trying to use p_gn_improveForecastNew with price time series
- abort if trying to declare gn_forecast for a group
- a warning if trying to activate reserve forecasts, but reserve length is shorter or equal to t_jump
- warning if there are model settings for inactive model types
- an abort if timeAndSamples.inc does no have enough t to cover the last solve (t_end - t_jump + t_horizon) 
- checks if sGroup and gnuGroup have data when using p_groupPolicy('energyMin') or p_groupPolicy('energyMax’)
- an abort if unitConstraint does not have one or more nodes and a constant or two or more nodes
- a warning if there is emission price data, but not corresponding gnGroup defined
- a warning if there is p_gnuEmission('vomEmissions') data, but not corresponding gnGroup defined
- a warning if ts_influx or ts_cf have longer time series than defined in datalength
- abort if transfer losses are 1 or higher

### Documentation
- Cleaning code: Reorganizing and adding table of contents to 1c, 1e, 2c, 3a, 3b, 3c
- Updating solver speed improvement features to scheduleInit and investInit examples
- updated forecast parameter explanations in template files and in the code
- Improved explanations of ramp rates and availabilities in 1a_definitions.gms
- an example of user given output variants, temp_objectiveCostFt_ in 'input' folder


## 3.8.1 - 2024-01-10

### Added
- roundings for the remaining ts_XX_:  ts_vomCost_, ts_startupCost_, ts_effUnit_, ts_effGroupUnit_
- new warnings when giving too short improveForecastNew parameters

### Changed

### Fixed
- fixing a bug in improveForecastNew
- updated debugSymbols.inc to fix the debug=2 option
- t_realizedNoReset now follows the same logic than ft_realizedNoReset and sft_realizedNoReset


## 3.8 - 2024-01-08

### Added - new features
- new feature improveForecastNew
- grid,node specific and unit specific parameters for improveForecastNew
- new feature for not binding the ends of forecasts
- option to round time series ts_XX_ to given precision, p_roundingTs
- option to round parameter tables to given precision, p_roundingParam
- an option to run the model from an input debug file
- new results tables: r_invest_unitEnergyCost_gnu, r_gen_unitStartupConsumption_nuft
- new feature boundSumOverInterval to bound the interval to the (sum of) reference value if value exists

### Added - quality of life updates
- loosening opXX checks for directOff units: Now using highest given value or assuming 1 if no op values.
- new command line option small_results_file to save disk space with a large number of runs
- improved scripting: %changes_inc%
- improved scripting: %init_file%
- a warning if ts_cf has values below 0 or above 1
- a warning if (grid, node, unit) capacity <> unitSize * unitCount.
- a warning if schedule run's sample does not cover all the modelled hours and the horizon
- plot_generator.py warns the user only when files will actually be overwritten

### Changed
- downgrading an abort to a warning if flow unit is assigned to multiple nodes
- rampSched is behind a new command line option. Temporary solution before removing of fixing rampSched.

### Fixed - improved speed
- reducing model generation time by simplifying sums when generating objective function 
- not creating unnecessary penalty parameters
- stricter filtering of following constraints: balance, directConversion, unit gt, and unit eq
- stricter filtering tt_aggregate and tt_agg_circular in case of multiple samples
- clearing df(f, t) between solves. Adding df_noReset.
- cleaning code: reducing m dimension from multiple equations, sets, and parameters
- cleaning code: first halves of the objective function and emission cap equation
- cleaning code: adding s dimension to ts_unit_, ts_effUnit_, and ts_effGroupUnit_

### Fixed - minor bugs
- fixing a rare div by zero in r_genByFuel_gnShare
- clearing Eps values from invest and marginalValue results
- r_curtailments now covers only generation
- curtailment sum over simulation did not consider stepLength and sample weights
- gnu set was not generated for specific unit input data combinations
- p_groupPolicyEmission and ts_emissionPriceChange now correctly exported from Spine database


## 3.7 - 2023-10-31

### Added
- an abort for empty opXX defined in input data if there is higher opXX or matching effXX
- python script (plot_generator.py) for automatic result figure drawing 
- option to give vertical influx and cf data in excel (ts_influx_vert and ts_cf_vert)
- git hooks for version control of git commits, creates version_git file
- new results table r_genByUnittype_g, r_emission_g, r_reserve_g
- note that genByFuel results ignore consumption from the node
- r_info_solveStatus for building models

### Changed
- gitignore now contains all folders except the ones in repository
- version file now manually generated when publishing a new major version
- cleaned unused scalars from model code
- clarifying code: replacing tmp_dt parameter with dt_historicalSteps

### Fixed
- result table genByFuel in case of multifuel units
- result table genByFuel_gnShare
- minor speed improvements with internal sets and parameters: usft, ts_vomCost, certain results tables
- minor speed improvements by splitting and compacting long loops


## 3.6 - 2023-09-19

### Added
- input data sheet ts_groupPolicy for time series constraint
- time series based maximum online status
- result table on Rate Of Change Of Frequency (ROCOF)
- an error message and abort if input data excel, input data gdx, or timeAndSamples.inc not found

### Changed
- giving different default penalty values for schedule (10e4) and invest (10e6)
- rounding MIP online, startup, and shutdown values in result tables
- improved the example of reading additional input files
- updated changes_loop template to use new tt_agg_circular
- cleaning code: replacing remaining tt_aggcircular with the new version
- reading default model definition files after modelsInit
- stricter node and unit loopings for minor speed improvement and clarifying the code
- Automatically reducing the number of internal counters based on input data

### Fixed
- reverting remaining selfDischargeLoss updates from previous patch
- a crash related to non-rounded MIP startup or MIP shutdown values


## 3.5 - 2023-08-24

### Added
- Investment energy cost parameter
- Adding an abort + warning if there are zero active samples in the init file
- explanations and clarifications to vomCost calculations in the code
- A warning if flow unit has efficiency levels defined and automatically removing these
- A warning and abort if unit with online variable does not have any op (or hr) parameters defined
- A warning and abort if unit has op parameters defined, but no matching eff values
- A warning if flow unit has op, eff, or conversionCoeff parameters defined, and automatically removing these
- A warning and abort if flow unit is assigned to multiple grids or nodes

### Changed
- edits to temp_4d_postProcess_invest2schedule.gms
- increasing default penalty to 10e6 for improved default behavior in investment cases
- changed command line option dummy to onlyPresolve
- unifying Abort messages to follow similar structure
- cleaning code: removing internal variables ss, ds, ds_state
- cleaning code: removing unused sets
- cleaning code: removing unused parameters

### Fixed
- Fixing a bug with data recycling with constant hourly time resolution.
- Fixing model sets defining the last t in investment model runs
- Fixed curtailment results in case unitSize is different to 1
- Checking the GAMS version earlier in the code to avoid crash in certain cases
- sum of capacity dependent emissions in emission cap equation
- fixed dummy command line option
- updating debug symbols
- improved storage state calculation between samples when using cyclic bounds and selfDischargeLosses
- boundStartOfSamples now fixes the time step one before the start of the sample similarly to other storage logic


## 3.4 - 2022-12-21

### Added

- Add `ts_price` equivalent to Spine datastore template.
- Option to declare which units use forecast data

### Changed

- updated scheduleInit template with 3 forecasts

### Fixed

- Fixing a bug with data recycling with constant hourly time resolution.
- Minor tweaks to Spine exporter settings to avoid erronous data export.
- removed old unused sections of code from 3c_inputsLoop
- Aligning the behaviour of 3.x with 2.x in case of 3 or more forecasts


## 3.3 - 2022-12-15

### Added
- new user input file changes_loop.inc that is read at the end of each loop compile phase
- file `input/temp_changes_loop.inc` demonstrating the use

### Changed
- updating temp_4d_postProcess_invest2schedule.gms

### Fixed
- capacity margin equation in case of flow unit inputs
- bound start and end of samples in certain cases with aggregated time steps


## 3.2 - 2022-12-13

### Added
- template file temp_changes_readSecondInputFile.inc
- adding a mod folder for mods delivered with the main backbone model

### Changed
- renaming tSolve t_solve
- defining t_startp only over t_full instead of t
- improved efficiency of ts_vomCost_ and ts_startupCost_ by avoiding repeated sums

### Fixed
- updated result table naming in an example of new result table


## 3.1 - 2022-12-07

### Added

### Changed
- improving looping and if conditions to avoid unnecessary calculations in investment runs
- replacing uft sets with usft sets for faster investment runs
- renaming startp set to t_startp
- renaming 3.x result tables. New names: r_gen_utilizationRate_gnu, r_gen_unitStartupConsumption_nu
- aligned unitConstraint (e.g. CHP units with constraint heat/elec ratio) behaviour with 2.x

### Fixed


## 3.0 - 2022-12-01

### Added- option to use availabilityCapacityMargin for input units
- emission factors for invested capacity, fixed o&m, and variable o&m for units
- time series for emission costs
- option to bound storage states at the beginning and/or end of samples
- template to activate barrier algorithm in cplex.opt (cplex_templateBarrier.opt)
- template to remove scaling in cplex.opt (cplex_templateNoScaling.opt)
- timeseries based unit node constraints
- option to add user defined parameters and sets in additionalSetsAndParameters.inc

### Removed - possibly requiring changes in input or result processing - see conversion guide from 2.x to 3.x 
- removed scenarios set including related equations and parameters
- removed unavailability parameter. Availability timeseries covers those functions from now on.
- removed unfinished features of reading new data during loop for ts_effUnit, ts_effGroupUnit, ts_priceChange, ts_price 
- removing option to read params.inc for additional parameters. New file additionalSetsAndParameters.inc replaces.
- removing consumption result tables as those are part of generation tables. 

### Changed - requiring input data changes - see conversion guide from 2.x to 3.x 
- Shutdown costs, start costs and start fuel consumptions to p_gnu_io
- converting input data emission factor from kg/MWh to t/MWh
- replaced emissionTax parameter with ts_emissionPrice and ts_emissionPriceChange 
- changed parameter name annuity to annuityFactor for clarification
- adding transfer rampLimit equations, removing old unfinished ICramp equations
- if input data gdx contains additional sets and parameters, those have to be defined in additionalSetsAndParameters.inc

### Changed - not requiring input data changes
- emissions bound to outputs (e.g. P2X) are included in equations as negative emissions
- combined result tables for emissions from input and emissions from outputs
- emissions bound to outputs (e.g. P2X) are included in result tables as negative emissions
- moving metadata to 1b_sets to allow expanding it with user given metadata
- update `tools/bb_data_template.json` for 3.x input data.

### Changed - Quality of Life improvements
- making most of the input data tables optional. Listing mandatory ones in 1e_inputs
- updated result table names with an improved logic
- added an option to use old 2.x result tables instead
- adding example how to add new result tables (temp_4d_postProcess_newResultsTable.gms and temp_additionalResultSymbols.inc)
- adding explanations and clarifications to paramater, set, and variable descriptions
- adding if checks and absolute path option for input data excel
- assuming default discount factor of 1 if not given in input data
- added option to use ts_price and/or ts_priceChange
- added option to use ts_emissionPrice and/or ts_emissionPriceChange
- added a warning that directOff deactivates startCosts
- New results tables: invested capacity, total emissions of emission groups, total diffusion between nodes, hourly curtailments, total curtailments
- adding number of completed and remaining solves between loops
- renamed suft(effSelector, unit, f, t)  to eff_uft to avoid confusions with samples 
- Automatic formatting and of `tools/bb_data_template.json` data structure.
- clearing Eps values from result table r_state
- moving example files, e.g. 1_options_temp.gms, to their default folders
- adding example file temp_additionalSetsAndParameters.inc
- adding example file temp_changes.inc
- stricter domains for `tools/exporttobb.json` .gdx exporter.

### Changed - efficiency improvements
- improving the speed of timeseries looping (ts_cf_, ts_gnn_) in between of solves
- improved memory size and speed of timeseries looping (ts_vomCost_, ts_startupCost_)
- improved the speed of ts_price calculation
- separated units with constant and variable startupCost to improve efficiency
- improved efficiency of ts_node looping
- deactivating minimum online and offline equations when timestep is longer than required minimum time 
- not applying unit ramp rates if allowed ramp up/down is more than 1 in time step.
- not applying transfer ramp rates if allowed ramp is more than 2 in time step.
- separated gnu with constant and variable vomCost to improve efficiency
- replacing gnuft with gnusft to reduce model size
- not applying energy balance dummy if node does not have energy balance
- improving ts_node looping efficiency
- improving ts_storageValue looping efficiency
- reducing result table calculation duration

### Fixed
- fixing div by zero in twoWayTransfer limits with 0 availability
- `scheduleInit.gms` is no longer required by `spineToolbox.json`.
- `tools/bb_data_template.json` and `tools/exporttobb.json` updated to match new input data requirements.
- correcting sample weights in objective function for transfer vomCosts
- fixing crash with diag option
- investments to existing storage units is now possible
- fixing div by 0 error in r_gnuUtilizationRate if unit has no unit size
- fixed shutdown variable at the beginning of solve for MIP units
- fixed multiplying unit ramping costs and transfer variable cost by stepLength in objective function
- fixing a case where ts_node was not looped for all included values
- Existing unit fixed operation and maintenance costs (fomCosts) are now included in the objective function
- Adding flow units to all generation by fuel result tables
- fixing calculation of share result tables
- finished partially completed shutdown cost result tables


## 2.2 - 2022-03-24
### Added
- option for user to add additional result symbols as input data
- unit availability time series

### Changed
- decreased default penalty value from 10e9 to 10e4 to improve solver default behavior
- changed emissions from output result table to print negative numbers signifying emissions bound to manufactured product
- solver time and total time separately to r_solveStatus

### Fixed
- during the first solve, boundStartToEnd now fixes the end value to boundstart if available, otherwise unbound
- resetting also minUnitCount in postProcess template
- efficiency timeseries looping corrected


## 2.1 - 2022-01-24
### Added
- two new result tables (gnGen, groupReserves) for easier graph drawing and debugging
- fixed flow units to model must-run production or consumption units

### Changed
- result table r_gen_gnUnittype renamed to r_gnuTotalGen_unittype. Original was not actively used in master branch.
- updated the order of generation result tables in 4b_outputInvariants

### Fixed
- changing sum over gnu_output to gnu in totalVOMcost, genUnittype, and gnuUtilizationRate
- p_gnReserves for one node with more than one independend reserves 
- Aggregated units not working with maintenance breaks
- Summing of reserve results


## 2.0 - 2022-01-05
### Added
- Result parameters for start-up energy consumption and start-up emissions
- Result parameter for realized diffusions
- Result tables for average marginal values (generation, reserves)
- Result tables for annual reserve results (gn, resTransfer)
- Two additional constraints to make transfer constraints tighter
- New set for the m, s, f, t combinations including the previous sample

### Changed
- Replaced commodity set with a parameter usePrice and updated results calculation related to it
- Replaced q_energyMax, q_energyShareMax and q_energyShareMin with q_energyLimit and q_energyShareLimit
- Removing Eps values from r_reserve results table
- Allow solver resource or iteration limit interrupt if the solution is feasible

### Fixed
- Including start-up fuel consumption in q_balance
- Updated start-up cost and start-up emission calculation
- output_dir command line argument was missing quotes in the code and directories with space did not work 
- Sceanario smoothing in certain special cases


## 1.5 - 2021-10-05
### Added
- Additional conditions in the objective function to avoid summing empty sets
- Possibility to model maintenance break with `utAvailalability` limits

### Changed
- Speedups

### Fixed 
- Templates for time and sample sets as well as model definitions files
- N-1 reserve equation did not include last hour of day/solve
- Setting the default update_frequency for reserve types
- Better control of reserve-related assignments


## 1.4 - 2021-06-29
- Time series for transmission availability and losses
- More versatile reading of input files. Translating input Excel to input GDX supported inside Backbone 1e_inputs.gms

## 1.3.3 - 2021-04-14
- Transfer can have additional 'variable' costs (costs per MWh transferred)
- Reserve activation duration and reactivation time included (in state constraints)
- Raise execution error if solver did not finish normally
- Updated the selection of unit efficiency approximation levels
- Additional result outputs

## 1.3.2 - 2021-01-19
- Moving from p_groupPolicy3D to separate p_groupPolicyUnit and p_groupPolicyEmission

## 1.3.1 - 2021-01-19
- Maximum (and minimum) limit to sum of energy inputs/outputs of selected group of units
- Additional result outputs concerning emissions

## 1.3 - 2020-10-21
- Static inertia requirement can be fulfilled by both rotational inertia of machines and certain reserve products
- Dynamic generation portfolios aka pathway modelling aka multi-year simulations with discounted costs enabled
- Parameters p_gnPolicy and p_groupPolicy3D replaced with p_groupPolicyEmission and p_groupPolicyUnit

## 1.2.2 - 2020-06-09
- Clean up, minor bug fixes and more results outputs

## 1.2.1 - 2019-11-26
### Fixed
- Fixed a possible division by zero in the calculation of r_gnuUtilizationRate
- Updated debugSymbols.inc and 1e_scenChanges.gms to match with the current naming of sets and parameters

### Changed
- Changed variable O&M costs from p_unit(unit, 'omCosts') to p_gnu(grid, node, unit, 'vomCosts')

## 1.2 - 2019-11-12

### Added
- Dynamic inertia requirements based on loss of unit and loss of export/import (ROCOF constraints)
- N-1 reserve requirement for transfer links
- A separate parameter to tell whether units can provide offline reserve (non-spinning reserve)
- Maximum share of reserve provision from a group of units
- All input files, including *inputData.gdx*, are optional
- Enabling different combinations of LP and MIP online and invest variables
- Separate availability parameter for output units in the capacity margin constraint
- Parameter `gn_forecasts(*, node, timeseries)` to tell which nodes and timeseries use forecasts

### Changed 
- Reserve requirements are now based on groups (previously node based)
- Changed the v_startup (and v_shutdown) variables into integers to improve the performance online approximations
- Updated tool definitions for Sceleton Titan and Spine Toolbox
- The program will now stop looping in case of execution errors
- Scenario reduction is done based on total available energy
- Maintain original scenario labels after reduction
- Clear time series data from droppped samples after scenario reduction

### Fixed
- Removed hard-coded `elec grids` from *setVariableLimits* and *rampSched files*
- Cyclic bounds between different samples was not working correctly (#97)
- Time series smoothing not working at all (#100)
- Fix a number of compilation warnings
- Limiting the provision of online reserve based on the online variable
- Sample probability bug from scenario reduction (probability of single scenario above one)


## 1.1.5 - 2020-11-28
### Fixed
- Long-term scenario data when using only one scenario
- Bug with scenario smooting which caused wrong values on later than first solve


## 1.1.4 - 2019-11-02
### Fixed
- Sample probability bug from scenario reduction


## 1.1.3 - 2019-10-24
### Changed 
- Scenario reduction is done based on total available energy


## 1.1.2 - 2019-10-23
### Changed 
- Maintain original scenario labels after reduction


## 1.1 - 2019-04-17
### Added
- New model setting 't_perfectForesight' tells the number of time steps (from 
  the beginning of current solve) for which realized data is used instead of 
  forecasts. This value cannot exceed current forecast length, however. Setting 
  the value lower than 't_jump' has no effect.
- Automated the calculation of sample start and end times if using long-term 
  scenarios. Also setting number of scenarios to one, instructs the model to use
  central forecast for the long-term.
- Speedup for model dimension calculation (set `msft` etc.)
- Support long time intervals in the first block
- Possibility to limit `v_online` to zero according to time series
- Output for reserve transfer results
- Reserve provision limits with investments
- Constrain the set of units to which ramp equations are applied
- Piecewise linear heat rate curves
- Checks for reserves
- Allow to set certain value for `v_gen` at 't000000'

### Changed
- Removed some old command line arguments
- Removed obsolete 'emissionIntensity' fuel parameter

### Fixed
- Unit ramps during start-up and shutdown
- Refreshing forecast data in *inputsLoop*
- Aggregated groups that were not in use were included in the model
- `mst_end` not found for the last sample
- Start-up not working for units without start costs or start fuel consumption
- *periodicInit* will fail with multiple model definitions
- Reserves should not be allowed to be locked when the interval is greater than 
  smallest interval in use
- Start-up phase and aggregated time steps do not work together
- In SOS2 unit cannot exceed the generation of `p_ut_runUp`
- Startup cost calculation
- Efficiency presentations
- `p_uNonoperational` not fully correct


## 1.0.6 - 2019-03-27
### Fixed
- Major bug in state variable reserve equations
- Scenario smoothing alogirithm

### Changed
- Speedup for timeseries calculations

### Added 
- New model setting `mSettings(mType, 'onlyExistingForecasts') = 0|1` to control 
  the reading of forecasts. Set to 1 to only read forecast data that exists in 
  the file. Note that zeros need to be saved as Eps when using this.
- Proper stochastic programming for the long-term scenarios period. Possible also
  to create a stochastic tree from the original data.
- Clickable link to *sr.log* in the process window in case of SCENRED2 error
- New diagnostic parameter for timeseries scenarios `d_ts_scenarios`


## 1.0.5 - 2019-02-14
### Fixed
- Probabilities were not updated after using scenario reduction

### Added
- Enable long-term samples that extend several years by using planning horizon 
  which is longer than one scenario (e.g. 3 years). Note: Cannot use all data for 
  samples as last years need to be reserved for the planning horizon.


## 1.0.4 - 2019-02-11
### Fixed
- Severe bug in setting node state level limits

### Changed
- Suppress ouput from SCENRED2


## 1.0.3 - 2019-02-05
### Fixed
- Only selects forecasts with positive probability for the solve


## 1.0.2 - 2019-02-04
### Added
- New model setting `dataLength` to set the length of time series data before it is
  recycled. Warn if this is not defined and automatically calculated from data.
- Command line arguments '--input_dir=<path>' and '--ouput_dir=<path' to set
  input and output directories, respectively.
- Added sample dimension to most variables and equations (excl. investments). 
  Samples can now be used as long-term scenario alternatives (for e.g. hydro scehduling)
- Number of parallel samples can be reduced using SCENRED2. Activate with active('scenRed')
  and set parameters in modelsInit.

### Changed
- Automatic calculation of parameter `dt_circular` takes into account time steps 
  only from `t000001` onwards.
- Debug mode yes/no changed to debug levels 0, 1 or 2. With higher level produces
  more information. Default is 0, when no extra files are written (not even *debug.gdx*).
  Set debug level with command line parameter `--debug=LEVEL`.

### Fixed
- Calculation of parameter `df_central`
- Readability of some displayed messages 


## 1.0 - 2018-09-12
### Changed
- Major updates to data structures etc.


