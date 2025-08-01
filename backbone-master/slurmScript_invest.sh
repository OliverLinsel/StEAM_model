#!/bin/bash
#test script for slurm for general "backbone-master"
###########################
## Set up submit to ...
#SBATCH -J co_RFNBO_OL
#SBATCH -t 0
#SBATCH --ntasks-per-node=48
#SBATCH -N 1
##SBATCH --mem-per-cpu=1344
##SBATCH -o test-%j.out
###########################

## Start Slurm Script command:  sbatch -w dermaschine RFNBO/bbm_complete/slurmScript_invest.sh

## -J Jobname -> frei zu vergeben 
## -t 0 -> heißt die Zeit des laufenden Jobs - 0 unendliche Jobzeit
## -N 1 -> aktuell nicht verändern
## --ntasks-per-node=48 -> Anzahl der gewünschten Kerne festlegen - Max 96

##echo "current user: $USER"

PATH=$PATH:/opt/gams/gams42.1_linux_x64_64_sfx

##free -mh
##uname -a
cd /mnt/speicher/.wissmit/oliver/Data/Backbone/RFNBO/bbm_complete

##echo "...................................check CPU Speed..................................."
##watch -n1 "grep Hz /proc/cpuinfo" 
##das stoppt leider das Fortschreiten im weiteren Code, und ist damit ein Endlosjob
##cat /proc/cpuinfo | grep Hz
##echo "...................................switching to GAMS..................................."
# invest run
gams Backbone.gms --input_dir=./input --input_file_gdx="inputData.gdx" --output_dir=./output --init_file=investInit.gms --debug=1 --penalty=100000
##echo "...................................job finished, return to conda..................................."
##free -mh
cp Backbone.lst /mnt/speicher/.wissmit/oliver/Data/Backbone/RFNBO/bbm_complete/output

#SBATCH --mail-user=oliver.linsel@rub.de
#SBATCH --mail-type=END,FAIL

