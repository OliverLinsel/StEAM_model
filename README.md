# StEAM_model
Sector transformation and energy systems analysis model (StEAM)
Sektortransformations und Energiesystemanalyse Modell (StEAM)

This is the repository for the StEAM energy system model. Please find the necessary dataset on Zenodo.

StEAM is based on the energy system modelling framework Backbone https://gitlab.vtt.fi/backbone/backbone/-/tree/release-3.x
and runs inside the workflow management software SpineToolbox https://github.com/spine-tools/Spine-Toolbox

To use StEAM you need a GAMS environment to execute backbone.

Installation:
1. Download the software package
2. Download the dataset from Zenodo and place the file on the top level of the file strucutre
3. Install the python environment with its requirements
4. Execute SpineToolbox and load the project
5. If necessary, refresh data connections in the project
6. Via the model_config.csv the model can be configured
7. The subset_countries.csv defines the regional aggregation
8. In the TSAM Tool the time aggregation can be defined
9. Execute the project in SpineToolbox

This model has been built in cooperation between the chair of energy systems and energy economics from the Ruhr-University Bochum and the chair of energy economics from the University Duisburg-Essen.
This project was supported by the German Federal Ministry of Economic Affairs and Climate Action, research grant number 03El1043A.
