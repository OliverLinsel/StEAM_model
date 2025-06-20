This is a very brief description on how to use the custom scripts:

invest2schedule:
The invest2schedule.cmd ist located in .\input\invest2schedule\
It uses the input.gdx that is in this folder and needs to be copied there manually from the .\input\ folder. This should avoid overwriting something by accident.
Once the input.gdx is copied, executing the invest2schedule.cmd should autoamtically copy any additionally needed files from the input-folder, the backbone-master main folder or the respective .\inc\invest2schedule_in folder.
If this works, an investmenr-run will be executed automatically with backbone (backbone.gms). The results are then created in the .\output\invest2schedule\ folder and called accordingly -invest.gdx

Once the investment run is finished, the relevant files will be copied automatically and the scheduling run is performed. Just like the investment run, the results are being created in the .\output\invest2schedule\ folder and called accordingly -scheduling.gdx

In case something doesnt work, it has probably something to do with the working directory or the location of one or more of the auxiliary files. The main working directory should always be the backbone-master folder, since all other paths are given relatively.


2schedule:
2schedule.cmd is basically a short-cut version of invest2schedule.cmd. This aims to start the scheduling run from an already finished investment run without running the investment run again. Use analog to the invest2schedule.cmd.


Slurm script:
The slurmScript_invest2scheduling.sh is basically the  Linux-equivalent of the Windows-invest2schedule.cmd

It is located in the main backbone folder (per default backbone-master) and adresses all relevant files relatively from there. In case you need to have different backbone-masters and need to rename them, this new name has to be transfered also to the cd command in the slurm script.

Once everything is in place, the slurmscript can be executed in your Linux server command line
by navigating to the main backbone folder:
cd PATH\to\main\backbone\folder

An executed as batch script:
sbatch -w "serverinstance" slurmScript_invest2scheduling.sh