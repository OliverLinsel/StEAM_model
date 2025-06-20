#!/bin/bash
#test script for slurm for general "backbone-master"
###########################
## Set up submit to ...
#SBATCH -J steam_ol_def_grid_pre
#SBATCH -t 0
#SBATCH --ntasks-per-node=48
#SBATCH -N 1
##SBATCH --mem-per-cpu=1344
##SBATCH -o test-%j.out
###########################

## -J Jobname -> frei zu vergeben
## -t 0 -> heißt die Zeit des laufenden Jobs - 0 unendliche Jobzeit
## -N 1 -> aktuell nicht verändern
## --ntasks-per-node=48 -> Anzahl der gewünschten Kerne festlegen - Max 96

##echo "current user: $USER"

PATH=$PATH:/opt/gams/gams42.1_linux_x64_64_sfx

##free -mh
##uname -a
cd /mnt/speicher/.wissmit/oliver/Data/Backbone/backbone-master

# Added .cmd script

# Change directory to the invest2schedule input folder
# cd ../..

echo "Running in directory: $PWD"

# preparing additional input data files
cp ./inc/4d_postProcess_invest.gms ./input/invest2schedule/4d_postProcess.gms
rm -f ./input/invest2schedule/invest_results.inc
rm -f ./input/invest2schedule/timeAndSamples.inc
cp ./input/timeAndSamples.inc ./input/invest2schedule/timeAndSamples.inc
cp ./inc/invest2schedule_inc/changes-invest.inc ./input/invest2schedule/changes.inc
cp ./inc/invest2schedule_inc/cplex_invest.opt ./cplex.opt

# invest run
gams Backbone.gms --input_dir=./input/invest2schedule --input_file_gdx="inputData.gdx" --output_dir=./output/invest2schedule --init_file=investInit.gms --debug=1 --penalty=100000

# copying summary of invest results to invest2schedule folder
cp ./output/invest_results.inc ./input/invest2schedule/invest_results.inc
cp ./output/invest2schedule/debug.gdx ./output/invest2schedule/debug-invest.gdx
cp ./output/invest2schedule/results.gdx ./output/invest2schedule/results-invest.gdx
cp ./Backbone.log ./output/log-invest.log
cp ./Backbone.lst ./output/lst-invest.lst

# preparing additional input data files
rm -f ./input/invest2schedule/4d_postProcess.gms
rm -f ./input/invest2schedule/changes.inc
cp ./inc/invest2schedule_inc/changes-schedule.inc ./input/invest2schedule/changes.inc
cp ./inc/invest2schedule_inc/cplex_schedule.opt ./cplex.opt

# schedule run
gams Backbone.gms --input_dir=./input/invest2schedule --output_dir=./output/invest2schedule --init_file=scheduleInit.gms --debug=1 --penalty=1000

cp ./output/invest2schedule/debug.gdx ./output/invest2schedule/debug-scheduling.gdx
cp ./output/invest2schedule/results.gdx ./output/invest2schedule/results-scheduling.gdx
rm -f ./input/invest2schedule/changes.inc
cp ./inc/invest2schedule_inc/cplex_invest.opt ./cplex.opt

##echo "...................................job finished, return to conda..................................."
##free -mh
cp Backbone.lst ./output

#SBATCH --mail-user=<user>
#SBATCH --mail-type=<END>
