Title Running scenario: "Backbone Steam model - invest and schedule"

:: Change directory to the invest2schedule input folder
cd ..\..

echo Running in directory: %cd%

:: in case you want to directly start from already succesfull invest run
:: copy .\inc\4d_postProcess_invest.gms .\input\invest2schedule\4d_postProcess.gms
:: if exist .\input\invest2schedule\timeAndSamples.inc del .\input\invest2schedule\timeAndSamples.inc
:: copy .\input\timeAndSamples.inc .\input\invest2schedule\timeAndSamples.inc

:: copying summary of invest results to invest2schedule folder
copy .\output\invest_results.inc .\input\invest2schedule\invest_results.inc
copy .\output\invest2schedule\debug.gdx .\output\invest2schedule\debug-invest.gdx
copy .\output\invest2schedule\results.gdx .\output\invest2schedule\results-invest.gdx
copy .\Backbone.log .\output\log-invest.log
copy .\Backbone.lst .\output\lst-invest.lst
:: preparing additional input data files
if exist .\input\invest2schedule\4d_postProcess.gms del .\input\invest2schedule\4d_postProcess.gms
if exist .\input\invest2schedule\changes.inc del .\input\invest2schedule\changes.inc
copy .\inc\invest2schedule_inc\changes-schedule.inc .\input\invest2schedule\changes.inc
copy .\inc\invest2schedule_inc\cplex_schedule.opt .\cplex.opt
:: schedule run - change GAMS path if necessary
C:\GAMS\49\gams.exe Backbone.gms --input_dir=.\input\invest2schedule --output_dir=.\output\invest2schedule --init_file=scheduleInit.gms --debug=1 --penalty=1000
copy .\output\invest2schedule\debug.gdx .\output\invest2schedule\debug-scheduling.gdx
copy .\output\invest2schedule\results.gdx .\output\invest2schedule\results-scheduling.gdx
if exist .\input\invest2schedule\changes.inc del .\input\invest2schedule\changes.inc
copy .\inc\invest2schedule_inc\cplex_invest.opt .\cplex.opt
pause