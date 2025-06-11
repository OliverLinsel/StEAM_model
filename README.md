# StEAM_model
Sector transformation and energy systems analysis model (StEAM)
Sektortransformations und Energiesystemanalyse Modell (StEAM)

This is the repository for the StEAM energy system model. Please find the necessary dataset on Zenodo.

StEAM is based on the energy system modelling framework Backbone https://gitlab.vtt.fi/backbone/backbone/-/tree/release-3.x
and runs inside the workflow management software SpineToolbox https://github.com/spine-tools/Spine-Toolbox

To use StEAM you need a GAMS environment to execute backbone.

Installation:
1. Download the software package
Define working folder:
```
cd path\to\folder
```
Clone repository:
```
git clone https://github.com/OliverLinsel/StEAM_model.git
```
3. Download the Dataset from Zenodo and add the content to the Data folder on the top level of the StEAM_model folder
Zenodo Link:
5. Create python environment and install its requirements
```
conda create --name steam --y
```
Activate conda environment:
```
conda activate steam
```
Install requirements (in InstallationScript folder)
```
pip install -r /path/to/requirements.txt
```
7. Start SpineToolbox and load the project
```
conda activate steam
spinetoolbox
```
9. If necessary, refresh data connections in the project
Use Toolbox Menu in the top left.
11. Via the model_config.csv the model can be configured
Default values for CO2 taxes, RFNBO criteria and capacity limitations can be defined here.
13. The subset_countries.csv defines the regional aggregation
The left columns lists all countries that should be included (care for nomenclature). The right columns contains the regions to which the coutnries on the left should be assigned to.
15. In the TSAM Tool the time aggregation can be defined
17. Execute the project in SpineToolbox

In case you need to uninstall everything, delete the folder StEAM_model and remove the environment including all packages using this command:
```
conda env remove -n steam
```

This model has been built in cooperation between the chair of energy systems and energy economics from the Ruhr-University Bochum and the chair of energy economics from the University Duisburg-Essen.
This project was supported by the German Federal Ministry of Economic Affairs and Climate Action, research grant number 03El1043A.
Thank you to everyone who contributed!
