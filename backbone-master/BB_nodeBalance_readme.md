# Backbone node balance plotter

## Authors 

Esa Pursiheimo, Tomi J. Lindroos


## Release notes

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


## Installation instructions

The node balance plotter is installed as a part of the Backbone.

**CHECKPOINT:**
* Check that  
    * You have installed GAMS - GAMS is in windows path (open command prompt, type path). If not, google instructions how to add GAMS to system path with your operation system. Note: do not add GAMS to user specific path.
    * You have installed Miniconda - You have miniconda installed, see https://docs.anaconda.com/miniconda/miniconda-install/ if not. Alternative git softwares are of course ok, but not covered by these instructions
    * You have installed Backbone - For these instructions, we assume that Backbone is installed to c:\backbone\ . If you do not have the model, see installation instructions at https://gitlab.vtt.fi/backbone/backbone is cloed to
    * Your Backbone version is new enough (3.12->) that you have the BB_nodeBalance.py file


## Creating miniconda environment

* Start miniconda e.g. by typing `miniconda` to windows search bar and select the correct program
* Create a new environment by typing `conda create -n BB_plotter python=3.12`
* Activate the new environment with `conda activate BB_plotter`
* Install following packages to the created environment. These steps might take a minute or two as pip needs to collect many related packages
	* `pip install dash` 
	* `pip install dash_bootstrap_components`
	* `pip install gdxpds`
	* `pip install gamsapi[transfer]==xx.y.z` where xx.y.z is your GAMS version. Open gams Studio, click help -> GAMS Licensing -> check GAMS Distribution xx.y.z
	* `pip install openpyxl`

NOTE: GamsAPI is possible, but more difficult to install for older GAMS versions, see https://github.com/NREL/gdx-pandas


## Run the node balance plotter

* Start miniconda e.g. by typing `miniconda` to windows search bar and select the correct program
* Activate the environment with `conda activate BB_plotter`
* Go to c:\backbone folder, e.g. by typing `c:` and `cd backbone`
* Start node balance plotter by typing `python BB_nodeBalance.py`
	* after 5-20sec, you should see a notification `Dash is running on http://127.0.0.1:8884/` or similar
	* copy `http://127.0.0.1:8884/` to your browser web page adress, press enter, and you should see the BADHMOPL main window

NOTE: This does not required internet connection and does not allow others to access your computer. The node balance plotter creates a virtual server that can be accessed only from the computer running this app.


## Requirements and tips for using the node balance plotter

Requirements
* The node balance plotter required Backbone debug file (adding --debug=1 to run prompt)
* The default address for the debug.gdx in the balance plotter is ".\output\debug.gdx" meaning c:\backbone\output\debug.gdx in this example. Manually writing alternative paths allows using debug files from other debug files and other folders as well.

Tips
* Clicking daily figure opens hourly figure
* Clicking unit name in the legend removes that unit from the figure
* Double clicking unit name in the legend removes all other units from the figure