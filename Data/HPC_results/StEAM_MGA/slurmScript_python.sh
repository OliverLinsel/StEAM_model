#!/bin/bash

####################################################################
# SETUP (note that “#SBATCH” is a command - in all other cases “#” comments out):
####################################################################

# NAME your job as you wish:
#SBATCH --job-name=MGA2030

# Set number of desired CORES - max 96 (set =24 in order to parallelise 4 jobs):
#SBATCH --ntasks-per-node=24

# TIMELIMIT of your job (HH:MM:SS) – “0” for an infinite run:
#SBATCH --time=0 

# MEMORY per CPU specification in [MB] (i.e. max.Memory/max.Cores=128GB/96):
##SBATCH --mem-per-cpu=1344

# DO NOT CHANGE:
#SBATCH -N 1

##SBATCH -o test-%j.out
####################################################################


# PATH to GAMS:
PATH=$PATH:/opt/gams/gams41.5_linux_x64_64_sfx

# api Version evtl ändern
export PYTHONPATH=$PATH:/opt/gams/gams41.5_linux_x64_64_sfx/apifiles/Python/api_38
export PYTHONPATH=$PATH:/opt/gams/gams41.5_linux_x64_64_sfx/apifiles/Python/gams:$PYTHONPATH

# CHANGE INTO WORKING DIRECTORY:
cd /mnt/speicher/studis/steam/backbone-master/

# START GAMS with options (ALWAYS use the argument output_dir!):
python3 conda env list
python3 StEAM_mga.py
# optional --debug=1 --output_file=<filename.gdx>

# COPY the rather verbose error msg (which would otherwise be overwritten by the next executions of gams):
# cp Backbone.lst /mnt/speicher/studis/$USER/SOME_FOLDER