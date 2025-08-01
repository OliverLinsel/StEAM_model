#This is the visualisation script
#if plotly exports dont work, use kaleido==0.1.0post1
#if new figures are not exported to the figures folder, delete existing ones and rerun or optimize folder to documents rather then pictures

#activate myenv
#C:\Users\oliver\InstallScriptSpineToolbox_v1\myenv\Scripts\activate.bat
#%%
"""
Develop visualization script

Created 2024
@author OL
"""

#import modules
import sys
import geopandas as gpd
import os
from shapely.geometry import Point, Polygon, LineString, MultiPoint
from shapely.ops import triangulate
import pandas as pd
from matplotlib import pyplot as plt
import numpy as np
from itertools import combinations, groupby
from scipy.spatial import Delaunay
#from gams import GamsWorkspace, GamsException
from backbonetools.io import BackboneResult
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import seaborn as sns
import plotly.graph_objects as go
import plotly.io as pio
import plotly.express as px
import matplotlib as mpl
from matplotlib.colors import LinearSegmentedColormap, ListedColormap
import time
import mpl_toolkits
from mpl_toolkits.axes_grid1.inset_locator import inset_axes
import matplotlib.patches as mpatches
import math
from plotly.subplots import make_subplots
import re
from string import digits
import squarify
import matplotlib.font_manager as fm

############### Load Data ###############

print('Execute in Directory:')
print(os.getcwd() + "\n")

print("Start reading input Data" + "\n")

#Define Case Study
case_study = "RFNBO"

try:
    #use if run in spine-toolbox
    case_study_path                 = os.path.join(os.getcwd(), "Data", "HPC_results", str(case_study))
    path_world_eu_bz                = r".\Data\Transport\data_input\world_eu_bz\world_eu_bz.shp"
    path_nodes                      = r".\Data\Transport\data_input\nodes\nodes_and_parameters.xlsx"
    path_TEMP                       = "TEMP\\"
    path_Main_Input                 = "TEMP\\MainInput.xlsx"
    path_Main_Input                 = os.path.join(case_study_path, "base_info", "MainInput.xlsx") #use this in case of running from a manual backup and not from TEMP files
    subset_countries                = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
    ### visualization ###
    path_transport_visualisation    = "TEMP\\Visualisation\\transport_visualisation.xlsx"
    path_transport_visualisation    = os.path.join(case_study_path, "base_info", "transport_visualisation.xlsx") #use this in case of running from a manual backup and not from TEMP files
    path_RFNBO_paper_res            = os.path.join(case_study_path)
    path_RFNBO_paper_vis            = os.path.join(case_study_path, "figures")
    world                           = gpd.read_file(os.path.join("..", "Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    case_study_path                 = os.path.join("Data", "HPC_results", str(case_study))
    path_world_eu_bz                = r"Data\Transport\data_input\world_eu_bz\world_eu_bz.shp"
    path_nodes                      = r"Data\Transport\data_input\nodes\nodes_and_parameters.xlsx"
    path_Main_Input                 = r".\PythonScripts\TEMP\MainInput.xlsx"
    path_Main_Input                 = os.path.join(case_study_path, "base_info", "MainInput.xlsx") #use this in case of running from a manual backup and not from TEMP files
    subset_countries                = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
    path_TEMP                       = r".\PythonScripts\TEMP\\"
    ### visualization ###
    path_transport_visualisation    = r".\PythonScripts\TEMP\Visualisation\transport_visualisation.xlsx"
    path_transport_visualisation    = os.path.join(case_study_path, "base_info", "transport_visualisation.xlsx") #use this in case of running from a manual backup and not from TEMP files
    path_RFNBO_paper_res            = os.path.join(case_study_path)
    path_RFNBO_paper_vis            = os.path.join(case_study_path, "figures")
    world = gpd.read_file(os.path.join("Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile

START = time.perf_counter() 

res_dpi     = 25

VRE_capacity_before_visualised_as_other = 20 #GW
cap_diff_before_visualised_as_other = 1 #GW
lower_threshhold_before_dropping_invest_values = 1 #MW
pie_scaling = 4
default_font = "Times New Roman"
vmin = 45 #minimum value for the color scale
vmax = 140 #maximum value for the color scale

#define plot limits
# default_xlim = (40, 150) #Asia
# default_ylim = (2, 75) #Asia
default_ylim = (28,70) #Europa
default_xlim = (-25,38) #Europa
# default_ylim = (-90,90) #Welt
# default_xlim = (-180,180) #Welt
#define legend position as 8% from the left side of the x range and 25% from the top of the y range
legend_x = default_xlim[0] + (default_xlim[1] - default_xlim[0]) * 0.08
legend_y = default_ylim[0] + (default_ylim[1] - default_ylim[0]) * 0.3

do_you_want_to_plot_a_specific_node = False
specific_node = "DE"
str_XX_region = ""

print("Read all scenario paths" + "\n")

folderlist = []
filenamelist = []

for foldername in os.listdir(path_RFNBO_paper_res):
    path_foldername = os.path.join(path_RFNBO_paper_res, foldername)
    for scen_filename in os.listdir(path_foldername):
        if scen_filename.endswith(".gdx"):
            folderlist.append(path_foldername)
            filenamelist.append(scen_filename)

filenames_df = pd.DataFrame(folderlist, columns=["foldername"])
filenames_df["run_list"] = filenames_df["foldername"].str.split("\\").str[-1]
filenames_df["scenario"] = filenames_df["run_list"].str[2:]
filenames_df["scenario_nr"] = filenames_df["run_list"].str.split("_").str[0]
filenames_df["filetype"] = filenamelist
filenames_df["filetype"] = filenames_df["filetype"].str.replace(".gdx", "")
filenames_df["filetype"] = filenames_df["filetype"].str.split("_").str[0]
filenames_df["year"] = filenames_df["run_list"].str.split("_").str[-1]
filenames_df["file_path"] = filenames_df["foldername"] + "\\" + filenames_df["filetype"] + ".gdx" #+ "_" + filenames_df["year"]
filenames_df["df_name"] = filenames_df["run_list"] + "_" + filenames_df["filetype"]
#%%

# def extract_year(filetype_str):
#     # First check for direct year match
#     for year in target_year_set:
#         if year in filetype_str:
#             return year
#     # Then fall back to debug code mapping
#     for dbg in debug_to_year:
#         if dbg in filetype_str:
#             return debug_to_year[dbg]
#     return None  # If nothing found

# filenames_df["year"] = filenames_df["filetype"].apply(extract_year)

# Initialize an empty dictionary



# if filenames_df["year"].isin([target_year_set[0]]).any(): #use if the year is in the filename
#     print("Apply new filename initialization using column years" + "\n")
#     # Step 1: Replace the prefix
#     filenames_df["filetype"] = filenames_df["filetype"].str.replace("_gams_py_gdb", "debug_", regex=False)

#     # Step 2: Replace only the digit after "debug_" using regex
#     debug_map = {'0': '2030', '1': '2040', '2': '2050', '3': '2060'}

#     for dbg_num, year in debug_map.items():
#         # Replace pattern like debug_0, debug_1 etc.
#         pattern = rf"debug_{dbg_num}(?!\d)"  # Negative lookahead ensures we don't match already-replaced values
#         filenames_df["filetype"] = filenames_df["filetype"].str.replace(pattern, f"debug_{year}", regex=True)    

#     print("Read BackboneResults into dictionary using individual scenarios and years" + "\n")

#     # get all rows in filenames_df where the year is in target_year
#     filenames_df_sel = filenames_df[filenames_df["year"].isin([target_year])]
#     filenames_df_sel = filenames_df_sel[filenames_df_sel["scenario"].isin(scenario_set)]
#     filenames_df = filenames_df_sel.copy()
# else: #use if the year is in the scenario folder name
#     filenames_df["year"] = filenames_df["run_list"].str.split("_").str[-1]
#     print("Apply old filename initialization" + "\n")
#     print("Read BackboneResults into dictionary" + "\n")

results_dict = {}

# alternative = "APS_2040"
target_year = filenames_df["year"].tolist()
scenario_set = filenames_df["scenario"].tolist() #Alternatively this can be hardcoded ['APS', 'RES', 'HRU', "testing", "stilltesting", "testing_2030", "stilltesting_2030"]
# target_year_set = ['2030', '2040', '2050', '2060']
# debug_number = ['gdb0', 'gdb1', 'gdb2', 'gdb3']
# debug_to_year = dict(zip(debug_number, target_year_set))

#filter if you need to
# filenames_df_sel = filenames_df[filenames_df["year"].isin([target_year])]
# filenames_df_sel = filenames_df_sel[filenames_df_sel["scenario"].isin(scenario_set)]
# filenames_df = filenames_df_sel.copy()

# Iterate over the DataFrame's rows
for i in filenames_df.index:
    if filenames_df["filetype"][i] != "inputData":
        try:
            # Use df_name as the key and BackboneResult(file_path) as the value
            key = filenames_df["df_name"][i]
            print(str(key))
            value = BackboneResult(filenames_df["file_path"][i])
            print(str(value))
            
            # Assign the result to the dictionary
            results_dict[key] = value
        except Exception as e:
            print(f"Error processing file {filenames_df['file_path'][i]}: {e}")

print("Apply old filename initialization" + "\n")
print("Read BackboneResults into dictionary" + "\n")
print("Succesfully read BackboneResults into dictionary" + "\n")

#%%
#import geopandas included shapefiles

print(path_world_eu_bz)
world_eu_bz = gpd.read_file(os.path.join(path_world_eu_bz))
# world = gpd.read_file(gpd.datasets.get_path('naturalearth_lowres'))
#import geopandas included shapefiles
world = world[["POP_EST", "CONTINENT", "NAME", "ISO_A3", "GDP_MD", "geometry"]]
world = world.rename(columns={"NAME":"name", "ISO_A3":"iso_a3", "POP_EST":"pop_est", "GDP_MD":"gdp_md_est", "CONTINENT":"continent"}) #renaming columns to match the ones in the nodeset

#%%
print("Start initializing transport dataframes" + "\n")

nodes                           = pd.read_excel(os.path.join(path_transport_visualisation), sheet_name="nodes")
nodes["geometry"]               = gpd.GeoSeries.from_wkt(nodes["geometry"])
nodes                           = gpd.GeoDataFrame(nodes, geometry="geometry")
terminals                       = pd.read_excel(os.path.join(path_transport_visualisation), sheet_name="terminals")
terminals["geometry"]           = gpd.GeoSeries.from_wkt(terminals["geometry"])
terminals                       = gpd.GeoDataFrame(terminals, geometry="geometry")
pipelines                       = pd.read_excel(os.path.join(path_transport_visualisation), sheet_name="pipelines")
pipelines["geometry"]           = gpd.GeoSeries.from_wkt(pipelines["geometry"])
pipelines                       = gpd.GeoDataFrame(pipelines, geometry="geometry")
try:
    terminal_connections = pd.read_excel(os.path.join(path_transport_visualisation), sheet_name="terminal_connections")
    terminal_connections["geometry"] = gpd.GeoSeries.from_wkt(terminal_connections["geometry"])
    terminal_connections = gpd.GeoDataFrame(terminal_connections, geometry="geometry")
    q = 0
except Exception as e:
    print(f"No terminal_connections: {e}")
    terminal_connections = gpd.GeoDataFrame()
    q = 1

try:
    shipping = pd.read_excel(os.path.join(path_transport_visualisation), sheet_name="shipping")
    shipping["geometry"] = gpd.GeoSeries.from_wkt(shipping["geometry"])
    shipping = gpd.GeoDataFrame(shipping, geometry="geometry")
    q = 0
except Exception as e:
    print(f"No shipping: {e}")
    shipping = gpd.GeoDataFrame()
    q = 1

#%%
#Get subset_countries from newly established "steam_subset_countries" sheet in debug
key_bc = next(k for k in results_dict.keys() if k.startswith("0_"))
debug = results_dict[key_bc]
subset_countries = debug.param_as_df_gdxdump("steam_subset_countries")
subset_countries = subset_countries.rename(columns={"s_countries":"name", "s_regions":"Regions"})

#%%
ts_cf_bc = debug.param_as_df_gdxdump("ts_cf_")
# create lists of all continuous time sets in ts_cf_bs["t"]
ts_list = ts_cf_bc["t"].unique().tolist()
#break list where count is not contiuous
t_start = 337
t_end = 504
t_start = 1
t_end = 168
t_start = 337
t_end = 505

print("Succesfully read all files" + "\n")

print("Start defining regions and colormaps" + "\n")

values = ["Austria", "Belgium", "Bulgaria", "Croatia", "Cyprus", "Czechia", "Denmark", "Estonia", "Finland", "France", "Germany", "Greece", "Hungary", "Ireland", "Italy", "Latvia", "Lithuania", "Luxembourg", "Malta", "Netherlands", "Poland", "Portugal", "Romania", "Slovakia", "Slovenia", "Spain", "Sweden"]
eu = world.loc[world['name'].isin(values)]
values = ["Ukraine", "United Kingdom", "Norway", "Switzerland", "Iceland","Serbia", "Albania", "Montenegro", "Kosovo", "North Macedonia", "Bosnia and Herz.", "Turkey", "Moldova", "Morocco", "Tunisia", "Egypt", "Libya", "Algeria", "Georgia", "Armenia", "Azerbaijan", "Libanon", "Syria"]
con_el_grid = world.loc[world['name'].isin(values)]
# %%

# Define the order of units roughly based on fully load hours
unit_order = ['Bat', 'PHS', 'Solar', 'PV', 'Wind', 'Wind_Onshore', 'Wind Onshore', 'Wind_Offshore', 'Wind Offshore', 'Oil', 'Gas', 'Biomass', 'Waste', 'Coal', 'Nuclear', 'Hydro', 'Electrolyzer', 'Other']
unit_order = ['Other', 'Electrolyzer', 'Hydro', 'Nuclear', 'Coal', 'Waste', 'Biomass', 'Gas', 'Oil', 'Wind Offshore', 'Wind_Offshore', 'Wind Onshore', 'Wind_Onshore', 'Wind', 'PV', 'Solar', 'PHS', 'Bat']

#defining colors

colors = ["#dccc3f", "#ffe99e", "#bce48b",  "#688e3b"]
cmap1 = LinearSegmentedColormap.from_list("mycmap", colors)
colors = ["#688e3b", "#bce48b", "#ffe99e", "#dccc3f"]
cmap1_r = LinearSegmentedColormap.from_list("mycmap", colors)

color_dict = {"Solar": 'gold', 'Solar old': 'lemonchiffon', "Solar|PV": 'gold',
    "Wind_Onshore": "cornflowerblue", "Wind Onshore": "cornflowerblue", "Wind|Wind_Onshore": "cornflowerblue",
    "Wind_Offshore": "blue", "Wind Offshore": "blue", "Wind|Wind_Offshore": "blue",
    "Hydro": "darkblue", "Hydro|Hydro": "darkblue",
    "Gas": "red", "Gas|CCGT": "red", "Gas|OCGT": "red",
    "Coal": "black", "Coal|Coal": "black", "Oil": "brown", "Oil|Oil": "brown",
    "Nuclear": "purple", "Nuclear|Nuclear": "purple",
    "Biomass": "darkgreen", "Biomass|Biomass": "darkgreen", "Waste": "orange",
    "Electrolyzer": "turquoise", "el|Electrolyzer": "turquoise",
    "FuelCell": "lightgreen", "Fuel Cell": "lightgreen",
    "Liquefaction": "orange", "Cracker": "orange", "HaberBosch": "darkgreen", 
    "Other": "grey", 'PHS': 'grey', 'PHS|Charge': 'grey', 'PHS|Discharge': 'darkgrey',
    "Bat": "grey", "Bat|Charge": "grey", "Bat|Discharge": "darkgrey",
    "h2": "yellow", "el": "turquoise"} #here it is the orher way around because of el|Ely and h2|OCGT

scen_color_dict = {'0_No_reg_bc_2030_results': 'blue', '1_Island_Grid_2030_results': 'orange',
                    '2_Def_Grid_2030_results': 'green', '3_Add_Corr_2030_results': 'red', '4_All_reg_2030_results': 'purple',
                    "0_lim_fac_bc_2030_results": "#00429d", "Base case 2030": "#00429d",
                    "1_lim_fac_0_2030_results": "#8d99b8", "Limited case 2030": "#8d99b8",
                    "2_lim_fac_start_2030_results": "#457cb6", "Kickstart case 2030": "#457cb6",
                    "3_lim_fac_bc_2040_results": "#93003a", "Base case 2040": "#93003a",
                    "4_lim_fac_0_2040_results": "#da808d", "Limited case 2040": "#da808d",
                    "5_lim_fac_start_2040_results": "#cd4763" , "Kickstart case 2040": "#cd4763",
                    '0_APS_Vanilla_2030_results': "#00429d", 'APS 2030 Mix H2': "#00429d",
                    '1_APS_Vanilla_2040_results': "#8d99b8", 'APS 2040 Mix H2': "#8d99b8",
                    "2_APS_noregbc_2030_results": "#457cb6", 'APS 2030 Green H2': "#457cb6",
                    "3_APS_noreg_2040_results": "#93003a", 'APS 2040 Green H2': "#93003a",
                    }

color_dict_countries = {
    "EU-ALB": "#b22222", "EU-AUT": "#d52b1e", "EU-BEL": "#c9b037", "EU-BGR": "#6ab150", "EU-BIH": "#1c3578", "EU-CHE": "#d52b1e",
    "EU-CZE": "#11457e", "EU-DEU": "#282828", "EU-ESP": "#c60b1e", "EU-EST": "#4891d9", "EU-FIN": "#003580", "EU-FRA": "#0055a4", "EU-GBR": "#00247d",
    "EU-GRC": "#0d5eaf", "EU-HRV": "#c60c30", "EU-HUN": "#436f4d","EU-IRL": "#169b62",  "EU-ISL": "#02529c", "EU-LTU": "#fdb913", "EU-LVA": "#9e3039",
    "EU-MDA": "#0033a0","EU-MKD": "#d20000", "EU-MNE": "#c8102e", "EU-NLD": "#21468b", "EU-POL": "#dc143c", "EU-PRT": "#006600", "EU-ROU": "#002b7f",
    "EU-SRB": "#c6363c", "EU-SVK": "#0b4ea2", "EU-SVN": "#005da4", "EU-UKR": "#ffd600", "EU-DNK": "#c60c30", "EU-ITA": "#008c45", "EU-NOR": "#ba0c2f", 
    "EU-SWE": "#fecc00", "AF-DZA": "#006233", "AF-EGY": "#ce1126", "AF-LBY": "#239e46", "AF-MAR": "#c1272d", "AF-TUN": "#e70013", "AS-TUR": "#e30a17"
    }

color_dict_regions = {
    "WBAL": "#7e2c3a", "AT": "#d52b1e", "BE": "#c9b037", "BG": "#6ab150", "CH": "#d52b1e",
    "CZ": "#11457e", "DE": "#282828", "ES": "#c60b1e", "BALT": "#a07e77", "FI": "#003580",
    "FR": "#0055a4", "GB": "#00247d", "GR": "#0d5eaf", "HR": "#c60c30", "HU": "#436f4d",
    "IE": "#169b62", "ISL": "#02529c", "MDA": "#0033a0", "NL": "#21468b", "PL": "#dc143c",
    "PT": "#006600", "RO": "#002b7f", "SK": "#0b4ea2", "SI": "#005da4", "UKR": "#ffd600",
    "DK": "#c60c30", "ITA": "#008c45", "NO": "#ba0c2f", "SE": "#fecc00", "ALG": "#006233",
    "EGY": "#ce1126", "LBY": "#239e46", "MAR": "#c1272d", "TUN": "#e70013", "TUR": "#e30a17"
}

#00429d,#457cb6,#8d99b8,#da808d,#cd4763,#93003a

#scenario names dict
scen_names_dict = {'0_lim_fac_bc_2030_results': 'Base case 2030',
                    "1_lim_fac_0_2030_results": 'Limited case 2030',
                    "2_lim_fac_start_2030_results": 'Kickstart case 2030',
                    "3_lim_fac_bc_2040_results": 'Base case 2040',
                    "4_lim_fac_0_2040_results": 'Limited case 2040',
                    "5_lim_fac_start_2040_results": 'Kickstart case 2040',
                    '0_APS_Vanilla_2030_results': 'APS 2030 Mix H2',
                    '1_APS_Vanilla_2040_results': 'APS 2040 Mix H2',
                    "2_APS_noregbc_2030_results": 'APS 2030 Green H2',
                    "3_APS_noreg_2040_results": 'APS 2040 Green H2',
                    '0_No_reg_bc_2030_results': 'No regulation RFNBO basecase',
                    '1_Island_Grid_2030_results': 'Island Grid RFNBO',
                    '2_Def_Grid_2030_results': 'Defossilized Grid RFNBO',
                    '3_Add_Corr_2030_results': 'Additionality and Correlation RFNBO',
                    '4_All_reg_2030_results': 'Complete Regulation RFNBO',
            }

### Create a colormap and scale for reference ###
def color_scale_plot(vmin, vmax):
    # Create a colormap object with the viridis colormap
    cmap = plt.cm.get_cmap('viridis')

    # Create a ScalarMappable object to map values to colors
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(vmin=vmin, vmax=vmax))
    sm._A = []  # Dummy array for ScalarMappable

    # Create a figure and axis object for the horizontal colorbar
    fig_h, ax_h = plt.subplots(figsize=(8, 1))
    cbar_h = fig_h.colorbar(sm, cax=ax_h, orientation='horizontal')

    # Set the font for the colorbar labels
    font = fm.FontProperties(family='Times New Roman', size=12)
    cbar_h.set_label('H2 marginal costs [€/MWh]', fontsize=12, fontproperties=font)
    cbar_h.ax.xaxis.set_label_position('bottom')
    cbar_h.ax.tick_params(labelsize=12)

    # Set the scale labels
    ticks = np.linspace(vmin, vmax, 7)
    cbar_h.set_ticks(ticks)
    cbar_h.set_ticklabels([f'{t:.0f}' for t in ticks])

    # Add ticks to the horizontal colorbar
    ax_h.set_xticks(ticks)
    ax_h.set_xticklabels([f'{t:.0f}' for t in ticks])

    # Create a figure and axis object for the vertical colorbar
    fig_v, ax_v = plt.subplots(figsize=(1, 8))
    cbar_v = fig_v.colorbar(sm, cax=ax_v, orientation='vertical')

    # Set the font for the colorbar labels
    cbar_v.set_label('H2 marginal costs [€/MWh]', fontsize=12, fontproperties=font)
    cbar_v.ax.yaxis.set_label_position('left')
    cbar_v.ax.tick_params(labelsize=12)

    # Set the scale labels
    cbar_v.set_ticks(ticks)
    cbar_v.set_ticklabels([f'{t:.0f}' for t in ticks])

    # Add ticks to the vertical colorbar
    ax_v.set_yticks(ticks)
    ax_v.set_yticklabels([f'{t:.0f}' for t in ticks])

    # Save the horizontal colorbar figure
    fig_h.savefig(os.path.join(path_RFNBO_paper_vis, "colorbar_horizontal.png"), dpi=300, bbox_inches='tight')
    # Save the vertical colorbar figure
    fig_v.savefig(os.path.join(path_RFNBO_paper_vis, "colorbar_vertical.png"), dpi=300, bbox_inches='tight')
    return

print("Succesfully defined regions and colormaps" + "\n")

print("Define tool functions for preprocessing" + "\n")

#Here all transport related dataframes are preprocessed and prepared for visualization
def transport_df_preprocessing(scenario_results, key):
    transport_results = scenario_results.r_transfer_gnn()
    #transport_results = transport_results.groupby(["grid", "node", "node.1"]).agg({"Val":"sum"}).reset_index().rename(columns={'node':'from_node','node.1':'to_node'})
    transport_results = transport_results.groupby(["grid", "from_node", "to_node"]).agg({"Val":"sum"}).reset_index()
    transport_results = transport_results.rename(columns={"grid":"commodity", "from_node":"h2_node1", "to_node":"h2_node2", "Val":"value"})
    transport_results["connection"] = transport_results.h2_node1 + "_" + transport_results.h2_node2
    transport_results["connection_alt"] = transport_results.h2_node2 + "_" + transport_results.h2_node1

    #pipelines results
    pipelines_light = pipelines[["name", "h2_node1", "h2_node2", "alternative", "commodity", "geometry"]]
    pipelines_light["connection"] = pipelines_light.h2_node1 + "_" + pipelines_light.h2_node2

    transport_results_m = transport_results.merge(pipelines_light, on="connection", how="inner")
    transport_results_m = transport_results_m.drop(columns=["h2_node1_y", "h2_node2_y", "commodity_y"])
    transport_results_m = transport_results_m.rename(columns={"h2_node1_x":"h2_node1", "h2_node2_x":"h2_node2", "commodity_x":"commodity"})
    transport_results_m = gpd.GeoDataFrame(transport_results_m, geometry="geometry")
    transport_results_m["value"] = transport_results_m["value"].astype(float).round(decimals=2).abs()

    #transmission results
    transmission_light =pipelines_light.copy()
    transmission_light["h2_node1"] = transmission_light["h2_node1"].str.replace("h2", "el")
    transmission_light["h2_node2"] = transmission_light["h2_node2"].str.replace("h2", "el")
    transmission_light = transmission_light.rename(columns={"h2_node1":"el_node1", "h2_node2":"el_node2"})
    transmission_light["connection"] = transmission_light.el_node1 + "_" + transmission_light.el_node2

    transmission_results_m = transport_results.merge(transmission_light, on="connection", how="inner")
    transmission_results_m = transmission_results_m.drop(columns=["h2_node1", "h2_node2", "commodity_y"])
    transmission_results_m = transmission_results_m.rename(columns={"el_node1_x":"el_node1", "el_node2_x":"el_node2", "commodity_x":"commodity"})
    transmission_results_m = gpd.GeoDataFrame(transmission_results_m, geometry="geometry")
    transmission_results_m["value"] = transmission_results_m["value"].astype(float).round(decimals=2).abs()

    if q != 1:
        # #terminal connections results
        terminal_connections_light = terminal_connections[["con_terminal_name", "Regions", "alternative", "geometry"]]
        terminal_connections_light["connection"] = terminal_connections_light.con_terminal_name + "_" + terminal_connections_light.Regions
        terminal_connections_light["connection_alt"] =  terminal_connections_light.Regions + "_" + terminal_connections_light.con_terminal_name

        terminal_connections_m = transport_results.merge(terminal_connections_light, on="connection", how="inner")
        terminal_connections_m = terminal_connections_m.drop(columns=["connection_alt_y", "connection_alt_x"])
        terminal_connections_m = gpd.GeoDataFrame(terminal_connections_m, geometry="geometry")
        terminal_connections_m["value"] = terminal_connections_m["value"].astype(float).round(decimals=2).abs()

        terminal_connections_m_alt = transport_results.merge(terminal_connections_light, on="connection_alt", how="inner")
        terminal_connections_m_alt = terminal_connections_m_alt.drop(columns=["connection_x"])
        terminal_connections_m_alt = terminal_connections_m_alt.rename(columns={"connection_alt":"connection"})
        terminal_connections_m_alt = gpd.GeoDataFrame(terminal_connections_m_alt, geometry="geometry")
        terminal_connections_m_alt["value"] = terminal_connections_m_alt["value"].astype(float).round(decimals=2).abs()

        # #shipping results
        shipping_light = shipping[["name", "origin", "destination", "alternative", "commodity", "geometry"]]
        shipping_light = shipping_light.rename(columns={"origin":"h2_node1", "destination":"h2_node2"})
        shipping_light["connection"] = shipping_light.h2_node1 + "_" + shipping_light.h2_node2

        shipping_m = transport_results.merge(shipping_light, on="connection", how="inner")
        shipping_m = shipping_m.drop(columns=["h2_node1_y", "h2_node2_y", "commodity_y"])
        shipping_m = shipping_m.rename(columns={"h2_node1_x":"h2_node1", "h2_node2_x":"h2_node2", "commodity_x":"commodity"})
        shipping_m = gpd.GeoDataFrame(shipping_m, geometry="geometry")
        shipping_m["value"] = shipping_m["value"].astype(float).round(decimals=2).abs()
    else:
        terminal_connections_m = gpd.GeoDataFrame()
        terminal_connections_m_alt = gpd.GeoDataFrame()
        shipping_m = gpd.GeoDataFrame()

    # Check if r_invest_transferCapacity_gnn() returns a non-empty DataFrame
    transfer_capacity_df = scenario_results.r_invest_transferCapacity_gnn()
    if not transfer_capacity_df.empty:
        # Ausnutzung der 5 groessten Pipelines
        pipeline_auslastung = (
            transfer_capacity_df
            .sort_values(by='Val', ascending=False)
            .reset_index(drop=True)
            .rename(columns={'from_node':'h2_node1', 'to_node':'h2_node2', 'Val':'pipeline_capacity_MW'})
            .merge(transport_results_m[['h2_node1','h2_node2','value']], how='left')
        )
        pipeline_auslastung['auslastung in prozent'] = pipeline_auslastung['value'] / (pipeline_auslastung['pipeline_capacity_MW'] * 8760)
        pipeline_auslastung = pipeline_auslastung[pipeline_auslastung['auslastung in prozent'].notna()].head(5)

    transport_results_m["scenario"] = key
    transmission_results_m["scenario"] = key
    terminal_connections_m["scenario"] = key
    terminal_connections_m_alt["scenario"] = key

    return transport_results_m, transmission_results_m, terminal_connections_m, shipping_m 

#Here all nodal and area related dataframes are preprocessed and prepared for visualization
def nodal_df_preprocessing(scenario_results, scenario_debug, key):
    nodes_disag = pd.read_excel(os.path.join(path_nodes), sheet_name=0) #einlesen der xlsx in einen dataframe
    nodes_disag = nodes_disag.rename(columns={"attribute.1":"attribute_"})
    nodes_disag = nodes_disag[["name", "value1", "value2"]]
    nodes_disag_points = nodes_disag.apply(lambda row: Point(row.value1, row.value2), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte
    #first lon then lat
    nodes_disag["region"] = nodes_disag["name"].map(subset_countries.set_index("name")["Regions"])

    nodes_disag = gpd.GeoDataFrame(nodes_disag, geometry=nodes_disag_points) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
    nodes_disag.crs = {"init": "epsg:4326"} #anpassan der Projektion

    #only using the rows that match the name in subset_countries
    nodes_disag = nodes_disag[nodes_disag["name"].isin(subset_countries["name"])]

    #transform to align crs of the dataframes
    nodes_disag = nodes_disag.to_crs(world.crs) #transforming the crs of the nodes_disag to match the world dataframe
    #copying geometry information from world where new_nodes_disag are within the geometry of the row in world
    world_regions = gpd.sjoin(world, nodes_disag, how="inner", predicate="intersects").reset_index()
    world_regions = world_regions[["name_right", "region", "geometry"]]
    world_regions = world_regions.rename(columns={"name_right":"name"})
    #create lists of all countries that belong to each region
    country_regions_list = world_regions.groupby("region").agg({"name": lambda x: list(x)}, ignore_index=True).reset_index()
    #unify geometries on region names
    world_regions = world_regions.dissolve(by="region", aggfunc={"name":"first"})
    world_regions = world_regions.merge(country_regions_list, on="region", how="left")
    world_regions = world_regions.drop(columns=["name_x"])
    world_regions = world_regions.rename(columns={"name_y":"list_of_countrycodes"}).reset_index(drop=True)

    demand_profiles = scenario_debug.param_as_df_gdxdump('ts_influx')
    #aggregated demand_profiles by grid and node
    demand_profiles = demand_profiles.groupby(['grid', 'node']).agg({'Val':'sum'}).reset_index()
    demand_profiles["node"] = demand_profiles["node"].str.split("_").str[0]
    #Filter the demand profiles for the APS_2040 alternative and the h2 grid
    demand_profiles = demand_profiles[demand_profiles["grid"] == "h2"]
    demand_profiles = demand_profiles.rename(columns={"node":"region"}).reset_index(drop=True)

    #merge demand profiles values to world_regions
    world_regions = world_regions.merge(demand_profiles, on="region", how="left")
    world_regions["Val"] = world_regions["Val"].abs()
    world_regions = world_regions.rename(columns={"Val":"h2_demand"}).reset_index(drop=True)

    nodes_h2 = nodes.rename(columns={"Regions":"region"}).drop(columns=["connection_investment_cost", "connection_investment_lifetime", "fix_ratio_out_in_connection_flow", "connection_fom_cost", "balance_type", "node_slack_penalty"])
    nodes_h2 = nodes_h2.merge(world_regions, on="region", how="inner").reset_index(drop=True)
    #drop double columns
    nodes_h2 = nodes_h2.drop(columns=["geometry_y", "list_of_countrycodes_y"])
    nodes_h2 = nodes_h2.rename(columns={"alternative":"alternative", "geometry_x":"geometry", "list_of_countrycodes_x":"list_of_countrycodes"})
    nodes_h2 = gpd.GeoDataFrame(nodes_h2, geometry="geometry")

    #Filter the DataFrame
    h2_prod_results = scenario_results.r_gen_gn()
    h2_prod_results = h2_prod_results.rename(columns={"grid":"commodity", "node":"region", "Val":"h2_production"})
    #drop all rows where the commodity is not h2 or elec
    h2_prod_results = h2_prod_results[h2_prod_results["commodity"] == "h2"]

    # 1. Alle negativen Werte zwischenspeichern
    h2_prod_negative = h2_prod_results[h2_prod_results["h2_production"] < 0].copy()

    # 2. Die negativen aus dem Haupt-DF entfernen
    h2_prod_results.loc[h2_prod_results["h2_production"] < 0, "h2_production"] = 0
    
    h2_prod_results["h2_production"] = h2_prod_results["h2_production"].abs()
    h2_prod_results["region"] = h2_prod_results["region"].str.split("_").str[0]
    
    h2_prod_negative["h2_production"] = h2_prod_negative["h2_production"].abs()
    h2_prod_negative["region"] = h2_prod_negative["region"].str.split("_").str[0]

    # 2. Gruppieren nach Region
    h2_prod_neg_sum = h2_prod_negative.groupby("region", as_index=False)["h2_production"].sum()

    # 3. Merge mit world_regions und Addition
    world_regions = world_regions.merge(h2_prod_neg_sum, on="region", how="left")
    world_regions["h2_production"] = world_regions["h2_production"].fillna(0)
    world_regions["h2_demand"] += world_regions["h2_production"]

    # Optional: wieder aufräumen
    world_regions = world_regions.drop(columns=["h2_production"])

    nodes_h2 = nodes.rename(columns={"Regions":"region"}).drop(columns=["connection_investment_cost", "connection_investment_lifetime", "fix_ratio_out_in_connection_flow", "connection_fom_cost", "balance_type", "node_slack_penalty"])
    nodes_h2 = nodes_h2.merge(world_regions, on="region", how="inner").reset_index(drop=True)
    #drop double columns
    nodes_h2 = nodes_h2.drop(columns=["geometry_y", "list_of_countrycodes_y"])
    nodes_h2 = nodes_h2.rename(columns={"alternative":"alternative", "geometry_x":"geometry", "list_of_countrycodes_x":"list_of_countrycodes"})
    nodes_h2 = gpd.GeoDataFrame(nodes_h2, geometry="geometry")

    h2_prod_results["h2_production"] = h2_prod_results["h2_production"].abs()
    h2_prod_results["region"] = h2_prod_results["region"].str.split("_").str[0]
    nodes_h2 = nodes_h2.merge(h2_prod_results, on="region", how="inner").reset_index(drop=True)
    nodes_h2 = nodes_h2.drop(columns=["commodity_y"])
    nodes_h2["h2_production"] = nodes_h2["h2_production"].astype(float)

    #all values under 0 are set to 0
    nodes_h2["h2_production"][nodes_h2["h2_production"] <= 0] = 0
    nodes_h2["radius"] = (nodes_h2["h2_production"] + nodes_h2["h2_demand"]) / (nodes_h2["h2_production"].max() + nodes_h2["h2_demand"].max()) * 10
    #nodes_h2["radius"] = 1 #if this line is disabeled the radius will be calculated by the formula above and thereby scaled to the respctive sum of production and demand

    #merge WACC to world_regions
    world_regions = world_regions.merge(nodes_h2[["region", "WACC"]], on="region", how="left")

    # #Add r_balance_marginalValue_gnAverage values to world_regions
    r_balance_marginalValue_gnAverage = scenario_results.r_balance_marginalValue_gnAverage()
    r_balance_marginalValue_gnAverage = r_balance_marginalValue_gnAverage.rename(columns={"grid":"commodity", "node":"region", "Val":"marginals"})
    r_balance_marginalValue_gnAverage_el = r_balance_marginalValue_gnAverage[r_balance_marginalValue_gnAverage["commodity"] == "elec"]
    r_balance_marginalValue_gnAverage_el["el_grid"] = r_balance_marginalValue_gnAverage_el["region"].str.split("_").str[1]
    r_balance_marginalValue_gnAverage_el["region"] = r_balance_marginalValue_gnAverage["region"].str.split("_").str[0]
    world_regions = world_regions.merge(r_balance_marginalValue_gnAverage_el, on="region", how="left")
    r_balance_marginalValue_gnAverage_h2 = r_balance_marginalValue_gnAverage[r_balance_marginalValue_gnAverage["commodity"] == "h2"]

    #drop all rows that contain a terminal
    r_balance_marginalValue_gnAverage_h2 = r_balance_marginalValue_gnAverage_h2[~r_balance_marginalValue_gnAverage_h2["region"].str.contains("terminal")]
    r_balance_marginalValue_gnAverage_h2["region"] = r_balance_marginalValue_gnAverage_h2["region"].str.split("_").str[0]
    world_regions = world_regions.merge(r_balance_marginalValue_gnAverage_h2, on="region", how="left")
    world_regions = world_regions.rename(columns={"marginals_x":"marginals_el", "marginals_y":"marginals_h2", "region":"Regions"})
    world_regions = world_regions.drop(columns=["grid"])

    #drop el_grid re rows
    # world_regions = world_regions[~world_regions["el_grid"].astype(str).str.contains("re")] #commented out because it would all rows
    world_regions["marginals_el"] = world_regions["marginals_el"].abs()
    world_regions["marginals_h2"] = world_regions["marginals_h2"].abs()
    #merge with nodes dataframe in Regions column to get geometry as geometry_node

    world_regions = world_regions.merge(nodes[["Regions", "x", "y"]], on="Regions", how="inner")

    nodes_disag["scenario"] = key
    nodes_h2["scenario"] = key
    world_regions["scenario"] = key

    return nodes_disag, nodes_h2, world_regions

def invest_df_preprocessing(result, debug):
    invest_df = result.r_invest_unitCapacity_gnu()
    if not invest_df.empty:
        invest_df[["Technology","Region"]]= invest_df["unit"].str.rsplit("|",n=1, expand=True)
        invest_df["Commodity"] = invest_df["Technology"].str.split("|").str[0]
        invest_df = invest_df.rename(columns={"Val":"Capacity [MW]"})

        invest_df = invest_df.query("grid!='storage'")
        invest_df = invest_df.query("grid!='derivatives'")
        is_discharge = invest_df["unit"].str.contains("Discharge" or "Charge" or "H2")
        invest_df = invest_df[~is_discharge]
        #rename Wind commodities Onshore or Offshore if the Technology strings contains Onshore or Offshore
        invest_df.loc[invest_df["Technology"].str.contains("Wind_Onshore"), "Commodity"] = "Wind Onshore"
        invest_df.loc[invest_df["Technology"].str.contains("Wind_Offshore"), "Commodity"] = "Wind Offshore"

        invest_df["colors"] = invest_df["Commodity"].map(color_dict)
        invest_df["Capacity [GW]"] = invest_df["Capacity [MW]"]/1000

        #drop rows if the capacity is very small
        invest_df = invest_df[invest_df["Capacity [MW]"] > lower_threshhold_before_dropping_invest_values]

        #order the dataframe by node alphabetically
        invest_df = invest_df.sort_values(by="Region").reset_index(drop=True)

        invest_df[invest_df["Technology"].str.contains("Electrolyzer")].sum()["Capacity [GW]"]
    else:
        invest_df = pd.DataFrame()
        print("No investment data found for " + str(debug) + "\n")
    return invest_df

def inv_df_prepro(results, scen):
    #the base scenario must contain 0_ to be identified as the base scenario       
    invest_df = results.r_invest_unitCapacity_gnu()
    if not invest_df.empty:
        invest_df[["Technology","Region"]]= invest_df["unit"].str.rsplit("|",n=1, expand=True)
        invest_df["Region"] = invest_df["Region"].str.replace("_add", "")
        invest_df["Commodity"] = invest_df["Technology"].str.split("|").str[0]
        invest_df = invest_df.rename(columns={"Val":"Capacity [MW]"})

        invest_df["scenario"] = str(scen)

        invest_df = invest_df.query("grid!='storage'")
        is_discharge = invest_df["unit"].str.contains("Discharge" or "Charge" or "H2")
        invest_df = invest_df[~is_discharge]
        #rename Wind commodities Onshore or Offshore if the Technology strings contains Onshore or Offshore
        invest_df.loc[invest_df["Technology"].str.contains("Wind_Onshore"), "Commodity"] = "Wind Onshore"
        invest_df.loc[invest_df["Technology"].str.contains("Wind_Offshore"), "Commodity"] = "Wind Offshore"

        invest_df["colors"] = invest_df["Commodity"].map(color_dict)
        invest_df["Capacity [GW]"] = invest_df["Capacity [MW]"]/1000

        #drop rows if the capacity is very small
        invest_df = invest_df[invest_df["Capacity [MW]"] > 1]

        #order the dataframe by node alphabetically
        invest_df = invest_df.sort_values(by="Region").reset_index(drop=True)

        invest_df["identifier"] = invest_df["node"] + "_" + invest_df["unit"]

        invest_df["colors"] = invest_df["scenario"].map(scen_color_dict)
    else:
        invest_df = pd.DataFrame()
        print("No investment data found for " + str(scen) + "\n")
    return invest_df

def cap_diff(invest_df_work, invest_df_bc, key):
    if not invest_df_work.empty:
        base_scen = key

        # merge invest_df_bc["Capacity [MW]_bc"] to invest_df_work on identifier
        invest_df_work_temp = invest_df_work.merge(invest_df_bc[["identifier", "Capacity [MW]_bc"]], on=["identifier"], how="left")

        invest_df_work_temp["cap_diff"] = invest_df_work_temp["Capacity [MW]"] - invest_df_work_temp["Capacity [MW]_bc"]
        invest_df_work = invest_df_work_temp.copy()
    else:
        invest_df_work = pd.DataFrame()
        print("No investment data found for " + str(key) + "\n")
    return invest_df_work

print("Define tool functions for visualization" + "\n")

def potential_hydrogen_transport_system():
    #Legend definition
    legend_elements1 =    [Line2D([0], [0], color='blue', lw=20, label='H2 Pipeline [TWh]'),
                        Line2D([0], [0], color='#52b0a9', lw=20, linestyle="--", label='Terminal Connection [TWh]'),
                        Line2D([0], [0], color='#239dce', lw=20, linestyle=":", label='H2 Shipping [TWh]'), 
                        #Line2D([0], [0], color='#FFA500', lw=20, label='Transmission Line [TWh]'),
                        Line2D([0], [0], marker='o', alpha=0.5, color='blue', label='H2 demand [TWh]',
                        markerfacecolor='blue', markersize=80, lw=0),
                        Line2D([0], [0], marker='o', alpha=1, color='black', label='Bidding zone node',
                        markerfacecolor='black', markeredgecolor="white", markeredgewidth=5, markersize=40, lw=0),
                        Line2D([0], [0], marker='o', alpha=1, color='white', label='Terminal node',
                        markerfacecolor='white', markeredgecolor="black", markeredgewidth=5, markersize=40, lw=0),
                        # Patch(facecolor='#ffe99e', edgecolor='white', label='Connected Electricity Grid'),
                        # Patch(facecolor='#bce48b', edgecolor='white', label='EU'),
                        #change font to default font
                        ]

    base = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.2)
    world_eu_bz.plot(ax=base, color='#daefb0', markersize=5, edgecolor='white', alpha=0.8, label="European interconnected grid")
    con_el_grid.plot(ax=base, color='#ffe99e', markersize=5, edgecolor='white', linewidth=6, alpha=1, label="Connected Electricity Grid")
    eu.plot(ax=base, color='#bce48b', markersize=5, edgecolor='white', linewidth=6, alpha=1, label="EU")
    # world_regions.plot(ax=base, column='Regions', cmap='YlGn', markersize=0.5, edgecolor='black', linewidth=1, alpha=0.6, legend=True, label="Regions")
    nodes_h2.plot(ax=base, color="blue", markersize=nodes_h2["h2_demand"]/nodes_h2["h2_demand"].max()*4*10**5, alpha=0.2, edgecolors='white', label="Demand [MWh]", zorder=4) #demand overlay '#cd7565'
    nodes.plot(ax=base, color='black', markersize=1000, linewidth=6, alpha=1, edgecolors='white', label="Country nodes", zorder=3) ##E05252
    pipelines.plot(ax=base, color='blue', linewidth=8, alpha=1, label="Pipelines", zorder=1) #Linestringelemente #9e0027 #6cc287
    #terminal exeption
    if q != 1:
        if terminals.empty == False:
            terminals.plot(ax=base, color='white', markersize=1000, linewidth=6, alpha=1, edgecolors='black', label="H2 terminals", zorder=2) #fead64
            terminal_connections.plot(ax=base, color='#52b0a9', linewidth=8, edgecolor='white', linestyle="--", alpha=1, label="Connection pipeline", zorder=1) #Linestringelemente #eba57c
            shipping.plot(ax=base, color='#239dce', linewidth=8, edgecolor='white', linestyle=":", alpha=1, label="Shipping routes", zorder=1) #Linestringelemente #ff8c00

    base.set_axis_off()
    plt.legend(handles=legend_elements1, fontsize=75, loc=3)
    # plt.ylim(28,70) #Europa
    # plt.xlim(-25,38) #Europa
    # plt.ylim(-90,90) #Welt
    # plt.xlim(-180,180) #Welt
    plt.xlim(default_xlim)
    plt.ylim(default_ylim)

    ### export the plot to a png ###
    plt.savefig(os.path.join(path_RFNBO_paper_vis, "potential_hydrogen_transport_system.png"), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)
    return

def prod_trans_geoplot(key, world_regions, nodes_h2, transp_r, transm_r, term_r, ship_r):
    scale = transp_r["value"].max()*100

    #pie chart scaling
    piesize = nodes_h2["h2_demand"].max()/1000000
    # piesize = 177 #TWh

    colors = ["#dccc3f", "#ffe99e", "#bce48b",  "#688e3b"]
    cmap1 = LinearSegmentedColormap.from_list("mycmap", colors)
    colors = ["#688e3b", "#bce48b", "#ffe99e", "#dccc3f"]
    cmap1_r = LinearSegmentedColormap.from_list("mycmap", colors)

    #Legend definition
    legend_elements =    [Line2D([0], [0], color='#003399', lw=20, label='H2 Pipeline [TWh]'),
                        Line2D([0], [0], color='#239dce', lw=20, label='H2 Shipping [TWh]'),
                        Line2D([0], [0], color='#52b0a9', lw=20, label='Terminal Connection [TWh]'),
                        # Line2D([0], [0], color='#FFA500', lw=20, label='Electricity Transmission [TWh]'),
                        Line2D([0], [0], marker='o', color='#ff275d', label='H2 demand [TWh]',
                        markerfacecolor='#ff275d', markersize=50, lw=0),
                        Line2D([0], [0], marker='o', color='#334ab3', label='H2 production [TWh]',
                        markerfacecolor='#334ab3', markersize=50, lw=0),
                        Patch(facecolor='#dccc3f', edgecolor='white', label='H2 marginal costs [€/MWh]')
                        ]


    # function to create inset axes and plot bar chart on it
    # this is good for 3 items bar chart
    def build_pie(mapx, mapy, ax, width, xvals=['a','b'], yvals=[1,4], total=["5"], fcolors=['r','g']):
        ax_h = inset_axes(ax, width=width, height=width, loc=10, \
                        bbox_to_anchor=(mapx, mapy), \
                        bbox_transform=ax.transData, \
                        borderpad=0, \
                        axes_kwargs={'alpha': 0.5, 'visible': True})
        for y in zip(yvals):
            ax_h = plt.pie(yvals, colors=fcolors, radius=total, shadow=False, wedgeprops = {'linewidth': 3, 'edgecolor': "white", "alpha":0.8}) #, labels=("H2 Demand " + str("{:.0f}".format(yvals[0]/1000)), "H2 Production " + str("{:.0f}".format(yvals[1]/1000))), textprops={'size': 30}) #labels=xvals radius=yvals.sum
        return ax_h

    #Make cmap from #f1a340 #f7f7f7 #998ec3
    #cmap_lav_grn = 1 #"matplotlib.colors.LinearSegmentedColormap.from_list("", ["red","violet","blue"])

    base = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.5)
    con_el_grid.plot(ax=base, color='#ffe99e', markersize=5, edgecolor='white', linewidth=6, alpha=1, label="Connected Electricity Grid")
    eu.plot(ax=base, color='#bce48b', markersize=5, edgecolor='white', linewidth=6, alpha=1, label="EU")
    world_regions.plot(ax=base, column=world_regions['marginals_h2'], cmap="viridis", vmin=vmin, vmax=vmax, edgecolor='white', linewidth=6, alpha=1, legend=False, legend_kwds={"label": "WACC", "orientation": "horizontal"}, # 'shrink': 0.3
                    missing_kwds={"color": "lightgrey", "edgecolor": "red","hatch": "///","label": "Missing values"}) #color='#a8a8a8' RdYlGn_r cmap1_r
    # nodes_h2.plot(ax=base, color='blue', markersize=nodes_h2["h2_demand"]/5000, alpha=0.6, label="H2 demand", zorder=4) ##E05252 #demand overlay '#cd7565'
    nodes_h2.plot(ax=base, color='black', markersize=500, linewidth=2, alpha=1, edgecolors='white', label="Regions nodes", zorder=3) ##E05252
    transp_r.plot(ax=base, color='#003399', linewidth=transp_r["value"]/transp_r["value"].max()*100, alpha=0.5, label="Pipelines", zorder=2, marker=".", markersize=100) #Linestringelemente #9e0027 #6cc287 
    transm_r.plot(ax=base, color='#FF6103', linewidth=transm_r["value"]/transm_r["value"].max()*100, alpha=0.5, label="Electricity Transmission", zorder=1, marker=".", markersize=100) #Linestringelemente #9e0027 #6cc287 

    #terminal exeption
    if q != 1:
        if terminals.empty == False:
            terminals.plot(ax=base, color='white', markersize=500, linewidth=2, alpha=1,edgecolors='black', label="Terminals", zorder=2) #fead64
            term_r.plot(ax=base, color='#52b0a9', linewidth=term_r["value"]/transp_r["value"].max()*100, edgecolor='white', alpha=1, label="Connection pipeline", zorder=1) #Linestringelemente #eba57c
            ship_r.plot(ax=base, color='#239dce', linewidth=ship_r["value"]/transp_r["value"].max()*100, edgecolor='white', alpha=1, label="Shipping routes", zorder=1) #Linestringelemente #ff8c00

    # plt.legend(ncol=3, title="Legend", title_fontsize=100, prop=dict(family=default_font))
    # plt.legend(handles=legend_elements, fontsize=70, prop=dict(family=default_font), bbox_to_anchor=(1.05, 0.5), loc=3)
    plt.legend(loc="upper center", ncol=3, fontsize=60, title="Legend", title_fontsize=100)
    plt.legend(handles=legend_elements, fontsize=60, loc=3)
    # plt.ylim(28,70) #Europa
    # plt.xlim(-25,38) #Europa
    # plt.ylim(-90,90) #Welt
    # plt.xlim(-180,180) #Welt
    plt.xlim(default_xlim)
    plt.ylim(default_ylim)

    build_pie(legend_x, legend_y, base, width=0.5, xvals = ["h2_demand", "h2_production"], yvals = [110, 110], total=np.sqrt(nodes_h2["radius"].max())*pie_scaling, fcolors=colors) #, textinfo = [100, 100]) -20, 38 for Europe, -170, -60 for World
    plt.pie(x=[1,1], colors=['#ff275d','#334ab3'], radius=np.sqrt(nodes_h2["radius"].max())*pie_scaling, shadow=False, wedgeprops = {'linewidth': 3, 'edgecolor': "white", "alpha":0.8}, labels=("H2 Demand " + str("{:.0f}".format(piesize)) + " TWh", "H2 Production " + str("{:.0f}".format(piesize)) + " TWh"), textprops={'size': 50, "horizontalalignment":'center'})

    #create a piechart at each location in (lon1s,lat1s)
    colors = ['#ff275d','#334ab3']
    for i in nodes_h2.index:
        x1 = nodes_h2["x"][i]   # get data coordinates for plotting
        y1 = nodes_h2["y"][i]*(-1)   # get data coordinates for plotting
        bax = build_pie(x1, y1, base, width=0.5, xvals = ["h2_demand", "h2_production"], yvals = [nodes_h2["h2_demand"][i], nodes_h2["h2_production"][i]], total=np.sqrt(nodes_h2["radius"][i])*pie_scaling, fcolors=colors) #

    # Add a colorbar
    # cbar = plt.colorbar(ax=base, orientation='horizontal', shrink=0.5, pad=0.05)
    # cbar.set_label('H2 marginal costs [€/MWh]')

    # sm = plt.cm.ScalarMappable(cmap="viridis", norm=plt.Normalize(vmin=world_regions['marginals_h2'].min(), vmax=world_regions['marginals_h2'].max()))
    # sm._A = []  # Dummy array for ScalarMappable
    # fig = plt.gcf()
    # cbar = fig.colorbar(sm, ax=base, orientation='horizontal', shrink=0.5, pad=0.05, aspect=30)
    # cbar.set_label('H2 marginal costs [€/MWh]', fontsize=50, fontdict={'fontname': default_font})
    # cbar.ax.xaxis.set_label_position('bottom')
    # cbar.ax.tick_params(labelsize=50)

    base.set_axis_off()
    ### export the plot to a png ###
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("production_transport_geoplot and h2 marginals " + str(key) + ".png")), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)
    return

def marginals_geoplot(key):
    #set world_regions marginals_el to None if it is >1000
    world_regions["marginals_el"][world_regions["marginals_el"] > 1000] = None

    #create el marginals diagram
    base = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.5)
    world_regions.plot(ax=base, column=world_regions['marginals_el'], cmap="viridis", vmin=vmin, vmax=vmax, edgecolor='white', linewidth=6, alpha=1, legend=False, legend_kwds={"label": "WACC", "orientation": "horizontal"}, # 'shrink': 0.3
                    missing_kwds={"color": "lightgrey", "label": ""}) #color='#a8a8a8' RdYlGn_r , "edgecolor": "red","hatch": "///",
    nodes.plot(ax=base, color='black', markersize=500, linewidth=2, alpha=1, edgecolors='white', label="Regions nodes", zorder=3) ##E05252

    if q != 1:
        if terminals.empty == False:
            terminals.plot(ax=base, color='white', markersize=500, linewidth=2, alpha=1,edgecolors='black', label="Terminals", zorder=2) #fead64

    #plotting the values from world_regions["marginals_el"] onto the map as annotations
    for x, y, label in zip(world_regions["x"], world_regions["y"], world_regions["marginals_el"].round(2)):
        base.annotate(label, xy=(x, -y), xytext=(5, 5), textcoords="offset points", fontsize=60, bbox=dict(facecolor='white', edgecolor='none', boxstyle='round,pad=0.5'))

    plt.legend(loc="upper center", ncol=3, fontsize=50, title=("Long-term avg. marginal costs [€/MWh_el] " + str(key)), title_fontsize=100, prop=dict(family=default_font))
    plt.ylim(28,70) #Europa
    plt.xlim(-25,38) #Europa
    # plt.ylim(-90,90) #Welt
    # plt.xlim(-180,180) #Welt
    plt.xlim(default_xlim)
    plt.ylim(default_ylim)

    base.set_axis_off()

    ### export the plot to a png ###
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("el_marginals_geoplot_" + str(key) + ".png")), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)

    #create h2 marginals diagram
    base1 = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.5)
    world_regions.plot(ax=base1, column=world_regions['marginals_h2'], cmap="viridis", vmin=vmin, vmax=vmax, edgecolor='white', linewidth=6, legend=False, legend_kwds={"label": "H2 marginal costs", "orientation": "horizontal"}, # 'shrink': 0.3
                    missing_kwds={"color": "lightgrey", "edgecolor": "red","hatch": "///","label": "Missing values"}) #color='#a8a8a8' RdYlGn_r
    nodes.plot(ax=base1, color='black', markersize=500, linewidth=2, alpha=1, edgecolors='white', label="Regions nodes", zorder=3) ##E05252

    if q != 1:
        if terminals.empty == False:
            terminals.plot(ax=base1, color='white', markersize=500, linewidth=2, alpha=1,edgecolors='black', label="Terminals", zorder=2) #fead64

    #plotting the values from world_regions["h2_marginal"] onto the map as annotations
    for x, y, label in zip(world_regions["x"], world_regions["y"], world_regions["marginals_h2"].round(2)):
        base1.annotate(label, xy=(x, -y), xytext=(5, 5), textcoords="offset points", fontsize=60, bbox=dict(facecolor='white', edgecolor='none', boxstyle='round,pad=0.5'))

    plt.legend(loc="upper center", ncol=3, fontsize=50, title=("Long-term avg. marginal costs [€/MWh_h2] " + str(key)), title_fontsize=100)
    # plt.ylim(28,70) #Europa
    # plt.xlim(-25,38) #Europa
    # plt.ylim(-90,90) #Welt
    # plt.xlim(-180,180) #Welt
    plt.xlim(default_xlim)
    plt.ylim(default_ylim)

    base1.set_axis_off()

    ### export the plot to a png ###
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("h2_marginals_geoplot_" + str(key) + ".png")), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)
    return

def WACC_geoplot(world_regions):
    base2 = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.5)
    world_regions.plot(ax=base2, column=world_regions['WACC']*(-1), cmap="viridis", edgecolor='white', linewidth=6, alpha=1, legend=False, legend_kwds={"label": "WACC", "orientation": "horizontal"}, # 'shrink': 0.3
                    missing_kwds={"color": "lightgrey", "edgecolor": "red","hatch": "///","label": "Missing values"}) #color='#a8a8a8' RdYlGn_r
    nodes.plot(ax=base2, color='black', markersize=500, linewidth=2, alpha=1, edgecolors='white', label="Regions nodes", zorder=3) ##E05252

    if q != 1:
        if terminals.empty == False:
            terminals.plot(ax=base2, color='white', markersize=500, linewidth=2, alpha=1,edgecolors='black', label="Terminals", zorder=2) #fead64

    #plotting the values from world_regions["WACC"] onto the map as annotations
    for x, y, label in zip(world_regions["x"], world_regions["y"], world_regions["WACC"].round(3).abs()):
        base2.annotate(label, xy=(x, -y), xytext=(5, 5), textcoords="offset points", fontsize=50, bbox=dict(facecolor='white', edgecolor='none', boxstyle='round,pad=0.5'))

    plt.legend(loc="upper center", ncol=3, fontsize=50, title=("WACC"), title_fontsize=100)
    # plt.ylim(28,70) #Europa
    # plt.xlim(-25,38) #Europa
    # plt.ylim(-90,90) #Welt
    # plt.xlim(-180,180) #Welt
    plt.xlim(default_xlim)
    plt.ylim(default_ylim)
    base2.set_axis_off()

    ### export the plot to a png ###
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("WACC_geoplot.png")), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)
    return

def cap_diff_plot(invest_df):
    #Sort DataFrame by WACC in descending order
    #invest_diff_ely_sorted = invest_diff_ely.sort_values(by='WACC', ascending=True)
    invest_df = invest_df[invest_df["Technology"].str.contains("Electrolyzer")]
    invest_df["colors"] = invest_df["scenario"].map(scen_color_dict)
    invest_df = invest_df[invest_df["grid"] == "h2"]
    invest_df = invest_df.sort_values(by='node', ascending=True)
    invest_df = invest_df.sort_values(by='scenario', ascending=True)
    # substract _h2 from node
    invest_df["node"] = invest_df["node"].str.replace("_h2", "")

    #apply scen_name_dict
    invest_df["scenario_name"] = invest_df["scenario"].map(scen_names_dict)

    #aggregate regions with cumulated installed Capacity [GW] for all VRE smaller then cap_diff_before_visualised_as_other to "Others" if this applies for both 2030 and 2040
    invest_df["node"] = invest_df.apply(
        lambda row: "Others" if invest_df[(invest_df["scenario"] == row["scenario"]) & (invest_df["node"] == row["node"])]["Capacity [GW]"].sum() <= cap_diff_before_visualised_as_other else row["node"],
        axis=1)

    # Create bar chart
    fig = go.Figure()

    for scen in invest_df["scenario_name"].unique():
        invest_df_scen = invest_df[invest_df["scenario_name"] == scen]
        # Add bars for Capacity [GW]
        fig.add_trace(go.Bar(
            x=invest_df_scen['node'],
            y=invest_df_scen['Capacity [MW]']/1000,
            name=str(scen),
            marker_color=invest_df_scen["colors"]
        ))

    # Update layout
    fig.update_layout(
        title='Installed Electrolyzer Capacities [GW]',
        #change title font to default_font
        font=dict(family=default_font, size=12, color="black"),
        xaxis_title='Node',
        yaxis_title='Capacity [GW]',
        barmode='group',
        plot_bgcolor='white'
    )

    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey')
    fig.update_xaxes(linecolor='black', showline=True, gridcolor='lightgrey')

    # Show plot
    fig.show()
    fig.write_image(os.path.join(path_RFNBO_paper_vis, "cap_diff_plot.png"), scale=res_dpi/2, width=1200, height = 400)
    #fig.write_image(os.path.join(path_RFNBO_paper_vis, "cap_diff_plot.svg"), scale=res_dpi/2)
    return

def cap_diff_rel_plot(invest_df):
    # Sort DataFrame by WACC in descending order
    #invest_df_sorted = invest_df.sort_values(by='WACC', ascending=True)
    invest_df = invest_df[invest_df["Technology"].str.contains("Electrolyzer")]
    invest_df = invest_df[invest_df["grid"] == "h2"]
    invest_df = invest_df.sort_values(by='node', ascending=True)

    # Create bar chart for cap_diff with sorted nodes
    fig = go.Figure()

    # Add bars for cap_diff with sorted nodes
    fig.add_trace(go.Bar(
        x=invest_df['node'],
        y=invest_df['cap_diff'],
        name='Capacity Difference',
        marker_color='green'
    ))

    # Update layout
    fig.update_layout(
        title='Invested Electrolyzer Capacity compared to Base Case [MW]',
        #change title font to default_font
        font=dict(family=default_font, size=12, color="black"),
        legend=dict(font=dict(size=12, family=default_font, color="black")),
        xaxis_title='Node',
        yaxis_title='Capacity Difference',
        barmode='relative',
        plot_bgcolor='white'
    )

    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey') #, range = [0, invest_df["limit"]])
    #fig.update_xaxes(linecolor='black')
    fig.add_hline(y=0, line_color="black", line_width=1)
    # Show plot
    #fig.show()
    fig.write_image(os.path.join(path_RFNBO_paper_vis, "cap_diff_rel_plot.png"), scale=res_dpi/2, width=800, height = 400)
    #fig.write_image(os.path.join(path_RFNBO_paper_vis, "cap_diff_rel_plot.svg"), scale=res_dpi/2)
    return

def cost_duration_curve(debug, scen_key):
    # price duration curves
    p_gnu_io=debug.param_as_df_gdxdump('p_gnu_io')
    p_gnu_io["vomCosts"]=p_gnu_io[p_gnu_io['param_gnu']=='vomCosts']["Val"]
    p_gnu_io=p_gnu_io[p_gnu_io['input_output']=='output']
    p_gnu_io=p_gnu_io.groupby(['node','grid','unit']).sum().reset_index()
    r_balance_marginalValue_gnft=debug.param_as_df_gdxdump('r_balance_marginalValue_gnft')

    ymax=130
    yd=25
    ymin=0

    nodes, font, stylelist, colorlist, nodelist, ax_list = [],[],[],[],[],[]
    df=pd.DataFrame()

    grid=['elec','h2', "re_elec"]

    r_balanceMarginal=r_balance_marginalValue_gnft.loc[r_balance_marginalValue_gnft["grid"].isin(grid),:]
    r_balanceMarginal["scenario"]=r_balanceMarginal["grid"]

    ## use this if you want all nodes
    nodes=sorted(r_balanceMarginal.loc[(r_balanceMarginal['grid']==grid[0]) & ~(r_balanceMarginal['node'].str.contains('Terminal')),'node'].drop_duplicates())
    nodes=list(pd.Series(nodes).str.replace('_el',''))  # our nodes are named XXXXX_el for electricity nodes and XXXXX_h2 for hydrogen nodes
    #drop nodes containing _re
    nodes = [x for x in nodes if "_re" not in x]
    #rename scenario re_elec when node contains _re_el
    r_balanceMarginal.loc[r_balanceMarginal["node"].str.contains("_re_el"), "scenario"] = "re_elec"
    ## use this if you want the biggest nodes
    #nodes=nodes_list_biggest_generations_short

    for n in nodes:
        df_plot = pd.DataFrame(
            np.sort(r_balanceMarginal[r_balanceMarginal['node']==n + '_el'].pivot(columns=["scenario"],index="t", values="Val").values, axis=0)*-1, 
            index=r_balanceMarginal[r_balanceMarginal['node']==n + '_el'].pivot(columns=["scenario"],index="t", values="Val").index, 
            columns=r_balanceMarginal[r_balanceMarginal['node']==n + '_el'].pivot(columns=["scenario"],index="t", values="Val").columns)
        df_plot = pd.concat([
            df_plot, 
            pd.DataFrame(
            np.sort(r_balanceMarginal[r_balanceMarginal['node']==n + '_h2'].pivot(columns=["scenario"],index="t", values="Val").values, axis=0)*-1, 
            index=r_balanceMarginal[r_balanceMarginal['node']==n + '_h2'].pivot(columns=["scenario"],index="t", values="Val").index, 
            columns=r_balanceMarginal[r_balanceMarginal['node']==n + '_h2'].pivot(columns=["scenario"],index="t", values="Val").columns)],
            ignore_index=False, axis=1)
        df_plot = pd.concat([
            df_plot, 
            pd.DataFrame(
            np.sort(r_balanceMarginal[r_balanceMarginal['node']==n + '_re_el'].pivot(columns=["scenario"],index="t", values="Val").values, axis=0)*-1, 
            index=r_balanceMarginal[r_balanceMarginal['node']==n + '_re_el'].pivot(columns=["scenario"],index="t", values="Val").index, 
            columns=r_balanceMarginal[r_balanceMarginal['node']==n + '_re_el'].pivot(columns=["scenario"],index="t", values="Val").columns)],
            ignore_index=False, axis=1)
        nodelist.append(str(n))
        ax_list.append(df_plot)
    nrow=7
    ncol=5
    fig, axes = plt.subplots(nrow, ncol)    # 4 x 4 subplots
    count=0
    nodes = []
    for r in range(nrow):
        for c in range(ncol):
            if ((r==nrow-1) and (c==ncol-1)):
                axes[r,c].axis('off')
            else:
                ax_list[count].plot(ax=axes[r,c],lw=1)
                axes[r,c].set_title(nodelist[count]) # + ':\n' + str(int(df_h2_generation.loc[df_h2_generation['node'] == nodelist[count],'Val'].values[0]/(10**6))) + ' TWh H2  '
                                                    #+ '\n ' + str(int(df_elec_generation.loc[df_elec_generation['node'] == nodelist[count],'Val'].values[0]/(10**6))) + ' TWh elec', fontsize=11)
                count+=1
                axes[r,c].spines['top'].set_visible(False)
                axes[r,c].spines['right'].set_visible(False)
                axes[r,c].get_legend().remove()
                axes[r,c].set_xticks([])
                axes[r,c].set_xlabel("")
                axes[r,c].set_yticks([])
                axes[r,c].set_ylabel("")
                axes[r,c].spines['bottom'].set_visible(False)
                axes[r,c].set_ylim(ymin, ymax)
                axes[r,c].set_yticks(range(ymin,ymax,yd))
                axes[r,c].axhline(y=0, color='black', linestyle='-', linewidth=1)
        for r in range(nrow):
            axes[r,0].set_ylabel('EUR/MWh',fontname=default_font)
            axes[r,0].set_ylim(ymin, ymax)
            axes[r,0].set_yticks(range(ymin,ymax,yd))
            axes[r,0].set_xlim(0, 8760)
        for r in range(nrow):
            axes[r,1].set_yticklabels([])
            axes[r,2].set_yticklabels([])
            axes[r,3].set_yticklabels([])
        for c in range(ncol):
            axes[6,c].set_xlabel('Hours (sorted)',fontname=default_font)
        axes[6,3].legend(loc='center left', bbox_to_anchor=(1.2, 0.5),prop={'family':font},frameon=False)
    fig.set_figwidth(15)
    fig.set_figheight(10)
    plt.subplots_adjust(hspace=0.46)
    plt.suptitle(str(scen_key)) #scenario.replace('_','').replace('2','') + ' total system costs: ' + str('%.2E' % Decimal(debug.param_as_df_gdxdump('v_obj')['Val'][0])))
    plt.savefig(os.path.join(path_RFNBO_paper_vis, "cost_duration_curve " + str(scen_key) + ".png"), dpi=res_dpi*20, bbox_inches='tight', pad_inches=0.1)
    return

def r_capacity(results, debug, key):
    result = results
    debug = debug
    key = key

    invest_df = result.r_invest_unitCapacity_gnu()
    invest_df[["Technology","Region"]]= invest_df["unit"].str.rsplit("|",n=1, expand=True)
    invest_df["Region"] = invest_df["Region"].str.replace("Engine_", "")
    invest_df["Commodity"] = invest_df["Technology"].str.split("|").str[0]
    invest_df = invest_df.rename(columns={"Val":"Capacity [MW]"})
    invest_df = invest_df.query("grid!='storage'")
    invest_df = invest_df.query("grid!='derivatives'")
    is_discharge = invest_df["unit"].str.contains("Discharge" or "Charge" or "H2")
    invest_df = invest_df[~is_discharge]
    #invest_df[invest_df["grid"] == "elec"] = invest_df[invest_df["grid"] == "elec"].replace("elec", "elec add")

    ## introduce Brownfield capacity
    p_gnu_io = debug.param_as_df_gdxdump("p_gnu_io")
    p_gnu_io = (p_gnu_io[
        (p_gnu_io['param_gnu'] == 'capacity') & 
        (p_gnu_io['Val'] > 0.01) &                                      # no eps values
        (p_gnu_io['grid'] == 'elec')]
        .reset_index(drop=True)
        .rename(columns={'Val':'Capacity [MW]'})
        .drop(['input_output','param_gnu'],axis=1))
    p_gnu_io[["Technology","Region"]]= p_gnu_io["unit"].str.rsplit("|",n=1, expand=True)
    p_gnu_io['Region'] = p_gnu_io['Region'].str.split('_',expand=True)[0]
    p_gnu_io["Commodity"] = p_gnu_io["Technology"].str.split("|").str[0]    # OCGT and CCGT labeled as Gas
    # concat
    invest_df = pd.concat([invest_df,p_gnu_io], ignore_index=True)
    #rename Wind commodities Onshore or Offshore if the Technology strings contains Onshore or Offshore
    invest_df.loc[invest_df["Technology"].str.contains("Wind_Onshore"), "Commodity"] = "Wind Onshore"
    invest_df.loc[invest_df["Technology"].str.contains("Wind_Offshore"), "Commodity"] = "Wind Offshore"
    #remove all the Invest strings together with the number at the end from the VRE technologies
    invest_df["Technology"] = invest_df["Technology"].str.replace("Invest", "")
    #replace the number at the end of the VRE technologies with an empty string
    invest_df["Technology"] = invest_df["Technology"].str.replace(r'\d+$', '', regex=True)
    invest_df["colors"] = invest_df["Commodity"].map(color_dict)

    #drop rows if the capacity is very small
    invest_df = invest_df[invest_df["Capacity [MW]"] > 1]
    invest_df["Capacity [GW]"] = invest_df["Capacity [MW]"]/1000

    #Combine additional regions by replacing the _add string
    invest_df["Region"] = invest_df["Region"].str.replace("_add", "")

    #combine re_el and el again
    invest_df.loc[invest_df["node"].str.contains("_re_el"), "node"] = invest_df.loc[invest_df["node"].str.contains("_re_el"), "node"].str.replace("_re_el", "_el")

    #order the dataframe by node alphabetically
    invest_df = invest_df.sort_values(by="Technology").reset_index(drop=True)
    # Sort Commodity by unit_order
    invest_df["Commodity"] = pd.Categorical(invest_df["Commodity"], categories=unit_order, ordered=True)
    # invest_df = invest_df.sort_values(by="Commodity").reset_index(drop=True)
    invest_df = invest_df.sort_values(by="Region").reset_index(drop=True)
    invest_df = invest_df.sort_values(by="grid").reset_index(drop=True)

    fig = px.bar(invest_df, x="Region", y="Capacity [GW]", title="Total Plant Capacity", color="Technology", facet_row="grid", hover_data=["Technology", "node"], color_discrete_map=color_dict)
    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey') #, range = [0, invest_df["limit"]])
    fig.update_xaxes(linecolor='black')
    fig.update_layout(plot_bgcolor='white', autosize=False, width=1300, height=800, font=dict(size=16, family=default_font, color="black"), showlegend=False)
    fig.show()
    fig.write_image(os.path.join(path_RFNBO_paper_vis, str("total_plant_capacity_" + str(key) + ".png")), scale=res_dpi/3, width=1000, height = 700)
    return invest_df

def r_generation(results, key):
    result = results
    key = key
    production = result.r_gen_gnu()
    production = production.rename(columns={"Val":"Production [MWh]"}) 
    production[["Technology","Region"]]= production["unit"].str.rsplit("|",n=1, expand=True)
    production["Commodity"] = production["Technology"].str.split("|").str[0]
    production["node"] = production["node"].str.split("_").str[0]

    #drop all rows wih grid that is not elec or h2
    production = production.query("grid=='elec'") #or grid=='h2'
    is_discharge = production["unit"].str.contains("Discharge" or "Charge" or "PHS" or "Bat")
    production = production[~is_discharge]
    #rename Wind commodities Onshore or Offshore if the Technology strings contains Onshore or Offshore
    production.loc[production["Technology"].str.contains("Wind_Onshore"), "Commodity"] = "Wind Onshore"
    production.loc[production["Technology"].str.contains("Wind_Offshore"), "Commodity"] = "Wind Offshore"
    #remove all the Invest strings together with the number at the end from the VRE technologies
    production["Technology"] = production["Technology"].str.replace("Invest", "")
    #replace the number at the end of the VRE technologies with an empty string
    production["Technology"] = production["Technology"].str.replace(r'\d+$', '', regex=True)

    production["colors"] = production["Technology"].map(color_dict)
    production["Production [TWh]"] = production["Production [MWh]"]/10**6

    production["Production [TWh]"][production["Production [TWh]"] <= 0] = production["Production [TWh]"] #*0.74

    #order the dataframe by node alphabetically
    production = production.sort_values(by="Region").reset_index(drop=True)

    #combine re_el and el again
    production.loc[production["node"].str.contains("_re_el"), "node"] = production.loc[production["node"].str.contains("_re_el"), "node"].str.replace("_re_el", "_el")

    fig = px.bar(production, x="node", y="Production [TWh]", title="Electricity Generation and Consumption", color="Technology", facet_row="grid", hover_data=["Technology"],
                 labels={"Production [TWh]":"Electricity Production [TWh]", "node":"Region"}, color_discrete_map=color_dict)
    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey') #, range = [0, invest_df["limit"]])
    #fig.update_xaxes(linecolor='black')
    fig.add_hline(y=0, line_color="black", line_width=1)
    fig.update_layout(plot_bgcolor='white', autosize=False, width=1300, height=600, font=dict(size=16, family=default_font, color="black"), showlegend=False)
    fig.write_image(os.path.join(path_RFNBO_paper_vis, "Electricity Generation and Consumption " + str(key) + ".png"), format="png", scale=res_dpi/3, width=1200, height = 700)
    #fig.show()
    return production

def total_system_costs(scenario_results, key):
    if "results" in key:
        system_cost = pd.DataFrame()
        system_cost["Total System Costs [MEUR]"] = scenario_results.r_cost_realizedCost()
        system_cost["scenario"] = key
        system_cost["Number"] = system_cost["scenario"].str.split("_").str[0]
        system_cost["colors"] = system_cost["scenario"].map(scen_color_dict)
        system_cost["Year"] = system_cost["scenario"].str.split("_").str[-2]
        system_cost["Case"] = system_cost["scenario"].str.split("_").str[-3]
        # basecase = system_cost.loc[system_cost["Number"] == str(0), "Case"]
        return system_cost

def total_system_costs_plot(agg_tsc_df_i):
    agg_tsc_df = pd.DataFrame()
    agg_tsc_df_bc = pd.DataFrame()
    base_value = agg_tsc_df_i.loc[agg_tsc_df_i["scenario"].str.contains("bc"), "Total System Costs [MEUR]"].values[0]
    for y in agg_tsc_df_i["scenario"].unique():
        agg_tsc_df_y = agg_tsc_df_i[agg_tsc_df_i["scenario"] == y]
        agg_tsc_df_y["Costs relative to base case"] = (agg_tsc_df_y["Total System Costs [MEUR]"] / base_value)
        #merge with agg_tsc_df on scenario
        agg_tsc_df_bc = pd.concat([agg_tsc_df_bc, agg_tsc_df_y])

    agg_tsc_df = agg_tsc_df_bc.copy()

    # Assuming "Costs relative to base case" is already calculated and added to agg_tsc_df
    agg_tsc_df["Costs relative to base case"] = agg_tsc_df["Costs relative to base case"] * 100 - 100
    agg_tsc_df["Costs relative to base case"] = agg_tsc_df["Costs relative to base case"].round(2)
    # Convert the values to string with '%' symbol
    agg_tsc_df["Costs relative to base case"] = '+ ' + agg_tsc_df["Costs relative to base case"].astype(str) + '%'
    # delete zeros
    agg_tsc_df["Costs relative to base case"] = agg_tsc_df["Costs relative to base case"].replace("+ 0.0%", "")
    
    #apply scen_name_dict
    agg_tsc_df["scenario_name"] = agg_tsc_df["scenario"].map(scen_names_dict)

    #Building bar chart for total system costs from agg_tsc_df
    fig = px.bar(agg_tsc_df, x="scenario_name", y="Total System Costs [MEUR]", title="Total System Costs", color="scenario", hover_data=["scenario_name"], color_discrete_map=scen_color_dict,
                text="Costs relative to base case")

    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey')
    fig.update_xaxes(linecolor='black', title="Scenario", showline=True, gridcolor='lightgrey')
    fig.update_layout(plot_bgcolor='white', autosize=False, width=1300, height=800, font=dict(size=20, family=default_font, color="black"), showlegend=False)

    # Update text position
    fig.update_traces(textposition='outside')

    fig.write_image(os.path.join(path_RFNBO_paper_vis, "Total System Costs.png"), scale=res_dpi/3, width=700, height = 700)
    fig.show()
    return

def installed_vre_capacities(agg_invest_df):
    agg_invest_df_c = agg_invest_df.copy()
    # Split scenario column into scenario and year
    agg_invest_df_c["Year"] = agg_invest_df_c["scenario"].str.split("_").str[-2]
    agg_invest_df_c["Region"] = agg_invest_df_c["Region"].str.replace("_isl", "")  # Remove _isl from Region names
    # Aggregate for each set of scenario, node, and commodity
    agg_invest_df_c = agg_invest_df_c.groupby(["scenario", "Region", "Commodity"]).agg({"Capacity [GW]": "sum", "colors": "first", "Year": "first"}).reset_index()
    # agg_invest_df_c["scenario_abrv"] = agg_invest_df_c["scenario"].str.split("_").str[-3]
    agg_invest_df_c["scenario_name"] = agg_invest_df_c["scenario"].map(scen_names_dict)

    #use only VRE
    agg_invest_df_c = agg_invest_df_c[agg_invest_df_c["Commodity"].isin(["Wind Onshore", "Wind Offshore", "Solar"])]

    #aggregate regions with cumulated installed Capacity [GW] for all VRE smaller then VRE_capacity_before_visualised_as_other to "Others" if this applies for both 2030 and 2040
    agg_invest_df_c["Region"] = agg_invest_df_c.apply(
        lambda row: "Others" if agg_invest_df_c[(agg_invest_df_c["scenario"] == row["scenario"]) & (agg_invest_df_c["Region"] == row["Region"])]["Capacity [GW]"].sum() <= VRE_capacity_before_visualised_as_other else row["Region"],
        axis=1)
    
    he_wi = 400
    font_size = 22

    #Building bar chart for total system costs from agg_tsc_df
    fig = px.bar(agg_invest_df_c,
                x="Region",
                y="Capacity [GW]",               
                title="Total installed VRE capacity",
                color="scenario", color_discrete_map=scen_color_dict,
                facet_row="Year",
                facet_row_spacing = 0,
                hover_data=["Commodity", "Capacity [GW]", "scenario_name"],
                )

    fig.update_yaxes(mirror=True, showline=True, linecolor='black', gridcolor='lightgrey')
    fig.update_xaxes(linecolor='lightgrey', showline=False, gridcolor='lightgrey', showgrid=True)
    fig.update_layout(height=he_wi * 2, width=he_wi * 5, plot_bgcolor='white', autosize=False, font=dict(size=20, family=default_font, color="black"), showlegend=True,
                    legend=dict(title="Scenario:", title_font=dict(size=font_size, family=default_font), font=dict(size=font_size, family=default_font), orientation="h", yanchor="top", y=6, xanchor="right", x=1),
                    barmode='group')
    
    fig.write_image(os.path.join(path_RFNBO_paper_vis, "Installed VRE capacities compared.png"), scale=res_dpi/3)
    return

def powerplant_scheduling_plot(debug, key):
    # default plotting of the biggest h2 producer
    r_gen_gn = debug.param_as_df_gdxdump('r_gen_gn')

    ########
    # elec #
    ########

    if do_you_want_to_plot_a_specific_node == True:
        node = specific_node
    else:
        node = r_gen_gn[(r_gen_gn['grid'] == 'h2') & (r_gen_gn['node'].str.startswith(str_XX_region))].sort_values(by='Val', ascending=False).reset_index(drop=True).loc[0,'node'].strip('_h2') + '_el' 

    node = "DE_el"
    # node = "PT_el"
    # node = "EU-Benelux_el"
    # node = "EU-FRA_el"
    # node = "AF-MAR_el"

    df_r_genByFuel_gnft                 = debug.param_as_df_gdxdump('r_gen_gnuft').query(f'node == "{node}"')  # generation
    df_r_balance_marginalValue_gnft     = debug.param_as_df_gdxdump('r_balance_marginalValue_gnft').query(f'node == "{node}"') # marginals
    df_i_ts_influx                      = debug.param_as_df_gdxdump('ts_influx_').query(f'node == "{node}"') # demand
    df_r_transfer_gnnft                 = debug.param_as_df_gdxdump('r_transfer_gnnft') # Shipping and Pipelines

    #filter the dataframes for the defined time period between t_start and t_end
    df_r_genByFuel_gnft                 = df_r_genByFuel_gnft.loc[(df_r_genByFuel_gnft['t'] >= t_start) & (df_r_genByFuel_gnft['t'] <= t_end), :]
    df_r_balance_marginalValue_gnft     = df_r_balance_marginalValue_gnft.loc[(df_r_balance_marginalValue_gnft['t'] >= t_start) & (df_r_balance_marginalValue_gnft['t'] <= t_end), :]
    df_i_ts_influx                      = df_i_ts_influx.loc[(df_i_ts_influx['t'] >= t_start) & (df_i_ts_influx['t'] <= t_end), :]
    df_r_transfer_gnnft                 = df_r_transfer_gnnft.loc[(df_r_transfer_gnnft['t'] >= t_start) & (df_r_transfer_gnnft['t'] <= t_end), :]

    trans_to = df_r_transfer_gnnft.loc[df_r_transfer_gnnft['to_node'] == node, :]
    trans_from = df_r_transfer_gnnft.loc[df_r_transfer_gnnft['from_node'] == node, :]
    trans_from.loc[:,'Val'] = trans_from.loc[:,'Val'] * -1
    trans_concat = pd.concat([trans_to, trans_from.rename(columns={'from_node':'to_node','to_node':'from_node'})], ignore_index=True).rename(columns={'to_node':'node','from_node':'unit'})
    total_production_trans = trans_concat.groupby('unit')['Val'].sum().reset_index(name='Total_Production')
    total_production_trans = total_production_trans[total_production_trans['Total_Production'].abs() > 100] # this can be parametrised
    trans_concat_filtered = pd.merge(trans_concat, total_production_trans, on='unit')

    df_r_genByFuel_gnft                 = df_r_genByFuel_gnft.sort_values(by='t', ignore_index=True, ascending=True)
    df_r_balance_marginalValue_gnft     = df_r_balance_marginalValue_gnft.sort_values(by='t', ignore_index=True, ascending=True)
    df_i_ts_influx                      = df_i_ts_influx.sort_values(by='t', ignore_index=True, ascending=True)
    trans_concat_filtered               = trans_concat_filtered.sort_values(by='t', ignore_index=True, ascending=True)

    df_r_genByFuel_gnft.loc[df_r_genByFuel_gnft['unit'].str.contains('Wind_OffshoreInvest|Wind_OnshoreInvest|PVInvest'), 'unit'] = df_r_genByFuel_gnft[df_r_genByFuel_gnft['unit'].str.contains('Wind_OffshoreInvest|Wind_OnshoreInvest|PVInvest')]['unit'].str.translate(str.maketrans('','', digits))
    df_r_genByFuel_gnft = df_r_genByFuel_gnft.groupby(['grid','node','unit','f','t']).agg({'Val':'sum'}).reset_index()

    # df_r_genByFuel_gnft['t']                = df_r_genByFuel_gnft               ['t'].astype(str)
    # df_r_balance_marginalValue_gnft['t']    = df_r_balance_marginalValue_gnft   ['t'].astype(str)
    # df_i_ts_influx['t']                     = df_i_ts_influx                    ['t'].astype(str)
    # trans_concat_filtered['t']              = trans_concat_filtered             ['t'].astype(str)

    color_dict = {                  # Color dictionary
    'Solar': 'yellow',
    'Solar old': 'yellow',
    'Wind_Onshore': 'lightblue', 'Wind Onshore': 'lightblue',
    'Wind_Offshore': 'blue', 'Wind Offshore': 'blue',
    'Hydro': 'darkblue',
    'Gas': 'red',
    'Coal': 'black',
    'Oil': 'brown',
    'Biomass': 'darkgreen',
    'Nuclear': 'darkorange',
    'Waste': 'orange',
    'Electrolyzer': 'turquoise',
    'Other': 'grey'
    }

    df_r_genByFuel_gnft['Color'] = 'grey'  # Default color

    # Convert keys in color_dict to lowercase
    color_dict_lower = {color_key.lower(): value for color_key, value in color_dict.items()}

    for color_key in color_dict_lower:
        # Convert 'unit' column to lowercase for comparison
        idx_col = df_r_genByFuel_gnft['unit'].str.lower().str.contains(color_key)
        # Update Color column only for matching rows
        df_r_genByFuel_gnft.loc[idx_col, 'Color'] = color_dict_lower[color_key]

    color_dict_unit = dict(zip(df_r_genByFuel_gnft['unit'], df_r_genByFuel_gnft['Color']))

    # Calculate variance for each category in unit
    variance_df = df_r_genByFuel_gnft.groupby('unit')['Val'].var().reset_index()
    variance_df = variance_df.rename(columns={'Val': 'Variance'})

    # Sort categories based on variance
    variance_df = variance_df.merge(df_r_genByFuel_gnft.groupby('unit')['Val'].sum().abs().reset_index(name='weight').sort_values(by='weight'))
    variance_df['weight'] = variance_df['weight']/variance_df['weight'].sum()
    variance_df['combined'] = variance_df['Variance'] / variance_df['weight']
    variance_df = variance_df.sort_values(by='combined')

    # Calculate total production for each unit
    total_production = df_r_genByFuel_gnft.groupby('unit')['Val'].sum().reset_index()
    total_production = total_production.rename(columns={'Val': 'Total_Production'})

    # Filter units with total production greater than 100
    total_production = total_production[total_production['Total_Production'].abs() > 100]

    # Merge filtered units back to the original dataframe
    df_r_genByFuel_gnft_filtered = pd.merge(df_r_genByFuel_gnft, total_production, on='unit')

    # concat with Shipping and Pipeline
    df_r_genByFuel_gnft_filtered = pd.concat([trans_concat_filtered, df_r_genByFuel_gnft_filtered], ignore_index=True)

    # Convert DataFrame columns to dictionary
    df_r_genByFuel_gnft_filtered['Val'] = df_r_genByFuel_gnft_filtered['Val']/1000

    df_r_genByFuel_gnft_filtered["Commodity"] = df_r_genByFuel_gnft_filtered['unit'].str.split("|").str[0]  # Extract commodity from unit

    # #filter df_r_balance_marginalValue_gnft to t_start and t_end
    # df_r_genByFuel_gnft_filtered = df_r_genByFuel_gnft_filtered[(df_r_genByFuel_gnft_filtered['t'] >= t_start) & (df_r_genByFuel_gnft_filtered['t'] <= t_end)]
    # df_r_balance_marginalValue_gnft = df_r_balance_marginalValue_gnft[(df_r_balance_marginalValue_gnft['t'] >= t_start) & (df_r_balance_marginalValue_gnft['t'] <= t_end)]
    # df_i_ts_influx = df_i_ts_influx[(df_i_ts_influx['t'] >= t_start) & (df_i_ts_influx['t'] <= t_end)]

    # Sort df_r_genByFuel_gnft_filtered by column Commodity to order unit_order
    df_r_genByFuel_gnft_filtered = df_r_genByFuel_gnft_filtered.sort_values(by='Commodity', key=lambda x: x.map(lambda y: unit_order.index(y) if y in unit_order else len(unit_order)))

    # Plot the area plot
    fig = px.bar(
        df_r_genByFuel_gnft_filtered, x='t', y='Val', color='unit', color_discrete_map =color_dict_unit#, facet_row="grid" category_orders={'unit': variance_df['unit']}, 
        # line_shape='linear', line_group='unit', hover_data=[' XXX '], title=" XXX ",
        )

    # Add line plot to the figure as a secondary y-axis
    # if '0_' in key:
    fig.add_trace(go.Scatter(x=df_r_balance_marginalValue_gnft['t'], y=df_r_balance_marginalValue_gnft['Val']*-1,
                            mode='lines',
                            name='Marginal Electricity Cost [€/MWh]',
                            yaxis='y2',
                            line=dict(color='black', width=2)))

    fig.add_trace(go.Scatter(x=df_i_ts_influx['t'],y=df_i_ts_influx['Val']*-1*(1/1000),
                            mode='lines',
                            name='Demand [GW]',
                            yaxis='y',
                            line=dict(color='red', dash='dashdot', width=4.5)))

    fig.update_layout(
        title='Powerplant Scheduling: ' + node + '   ' + key,
        xaxis_title='Time Steps (t)',
        yaxis_title='Stacked Production [GW]',
        legend_title = 'Unit',
        plot_bgcolor='white',  # Set background color to white
        yaxis2=dict(title='Marginal Price [€/MWh]', overlaying='y', side='right'), 
        legend=dict(x=1.05, y=1.), 
        font=dict(
            family=default_font,
            size=16,  # Set the font size
            color="black"  # Set font color
        ),
        autosize=False,
        height=800, # Set the height of the plot
        width=1300,
        barmode='relative',
        xaxis=dict(range=[t_start, t_end]) # Limit x-axis to t_start and t_end
    )

    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey') #, range = [0, invest_df["limit"]])
    fig.update_xaxes(linecolor='black')
    fig.write_image(os.path.join(path_RFNBO_paper_vis, '06_' + key + node + "_f_generation_ts_elec.png"))
    fig.show()

    ######
    # h2 #
    ######

    node = node.strip('_el') + '_h2'

    df_r_genByFuel_gnft                 = debug.param_as_df_gdxdump('r_gen_gnuft').query(f'node == "{node}"')  # generation
    df_r_balance_marginalValue_gnft     = debug.param_as_df_gdxdump('r_balance_marginalValue_gnft').query(f'node == "{node}"') # marginals
    df_i_ts_influx                      = debug.param_as_df_gdxdump('ts_influx_').query(f'node == "{node}"') # demand
    df_r_transfer_gnnft                 = debug.param_as_df_gdxdump('r_transfer_gnnft') # Shipping and Pipelines

    #filter the dataframes for the defined time period between t_start and t_end
    df_r_genByFuel_gnft                 = df_r_genByFuel_gnft.loc[(df_r_genByFuel_gnft['t'] >= t_start) & (df_r_genByFuel_gnft['t'] <= t_end), :]
    df_r_balance_marginalValue_gnft     = df_r_balance_marginalValue_gnft.loc[(df_r_balance_marginalValue_gnft['t'] >= t_start) & (df_r_balance_marginalValue_gnft['t'] <= t_end), :]
    df_i_ts_influx                      = df_i_ts_influx.loc[(df_i_ts_influx['t'] >= t_start) & (df_i_ts_influx['t'] <= t_end), :]
    df_r_transfer_gnnft                 = df_r_transfer_gnnft.loc[(df_r_transfer_gnnft['t'] >= t_start) & (df_r_transfer_gnnft['t'] <= t_end), :]

    trans_to = df_r_transfer_gnnft.loc[df_r_transfer_gnnft['to_node'] == node, :]
    trans_from = df_r_transfer_gnnft.loc[df_r_transfer_gnnft['from_node'] == node, :]
    trans_from.loc[:,'Val'] = trans_from.loc[:,'Val'] * -1
    trans_concat = pd.concat([trans_to, trans_from.rename(columns={'from_node':'to_node','to_node':'from_node'})], ignore_index=True).rename(columns={'to_node':'node','from_node':'unit'})
    total_production_trans = trans_concat.groupby('unit')['Val'].sum().reset_index(name='Total_Production')
    total_production_trans = total_production_trans[total_production_trans['Total_Production'].abs() > 100] # this can be parametrised
    trans_concat_filtered = pd.merge(trans_concat, total_production_trans, on='unit')

    df_r_genByFuel_gnft                 = df_r_genByFuel_gnft.sort_values(by='t', ignore_index=True, ascending=True)
    df_r_balance_marginalValue_gnft     = df_r_balance_marginalValue_gnft.sort_values(by='t', ignore_index=True, ascending=True)
    df_i_ts_influx                      = df_i_ts_influx.sort_values(by='t', ignore_index=True, ascending=True)
    trans_concat_filtered               = trans_concat_filtered.sort_values(by='t', ignore_index=True, ascending=True)

    df_r_genByFuel_gnft.loc[df_r_genByFuel_gnft['unit'].str.contains('Wind_OffshoreInvest|Wind_OnshoreInvest|PVInvest'), 'unit'] = df_r_genByFuel_gnft[df_r_genByFuel_gnft['unit'].str.contains('Wind_OffshoreInvest|Wind_OnshoreInvest|PVInvest')]['unit'].str.translate(str.maketrans('','', digits))
    df_r_genByFuel_gnft = df_r_genByFuel_gnft.groupby(['grid','node','unit','f','t']).agg({'Val':'sum'}).reset_index()

    # df_r_genByFuel_gnft['t']                = df_r_genByFuel_gnft               ['t'].astype(str)
    # df_r_balance_marginalValue_gnft['t']    = df_r_balance_marginalValue_gnft   ['t'].astype(str)
    # df_i_ts_influx['t']                     = df_i_ts_influx                    ['t'].astype(str)
    # trans_concat_filtered['t']              = trans_concat_filtered             ['t'].astype(str)

    color_dict = {                  # Color dictionary
    'Solar': 'yellow',
    'Solar old': 'yellow',
    'Wind_Onshore': 'lightblue', 'Wind Onshore': 'lightblue',
    'Wind_Offshore': 'blue', 'Wind Offshore': 'blue',
    'Hydro': 'darkblue',
    'Gas': 'red',
    'Coal': 'black',
    'Oil': 'brown',
    'Biomass': 'darkgreen',
    'Nuclear': 'darkorange',
    'Waste': 'orange',
    'Electrolyzer': 'turquoise',
    'Other': 'grey'
    }

    df_r_genByFuel_gnft['Color'] = 'grey'  # Default color

    # Convert keys in color_dict to lowercase
    color_dict_lower = {color_key.lower(): value for color_key, value in color_dict.items()}

    for color_key in color_dict_lower:
        # Convert 'unit' column to lowercase for comparison
        idx_col = df_r_genByFuel_gnft['unit'].str.lower().str.contains(color_key)
        # Update Color column only for matching rows
        df_r_genByFuel_gnft.loc[idx_col, 'Color'] = color_dict_lower[color_key]

    color_dict_unit = dict(zip(df_r_genByFuel_gnft['unit'], df_r_genByFuel_gnft['Color']))

    # Calculate variance for each category in unit
    variance_df = df_r_genByFuel_gnft.groupby('unit')['Val'].var().reset_index()
    variance_df = variance_df.rename(columns={'Val': 'Variance'})

    # Sort categories based on variance
    variance_df = variance_df.merge(df_r_genByFuel_gnft.groupby('unit')['Val'].sum().abs().reset_index(name='weight').sort_values(by='weight'))
    variance_df['weight'] = variance_df['weight']/variance_df['weight'].sum()
    variance_df['combined'] = variance_df['Variance'] / variance_df['weight']
    variance_df = variance_df.sort_values(by='combined')

    # Calculate total production for each unit
    total_production = df_r_genByFuel_gnft.groupby('unit')['Val'].sum().reset_index()
    total_production = total_production.rename(columns={'Val': 'Total_Production'})

    # Filter units with total production greater than 100
    total_production = total_production[total_production['Total_Production'].abs() > 100]

    # Merge filtered units back to the original dataframe
    df_r_genByFuel_gnft_filtered = pd.merge(df_r_genByFuel_gnft, total_production, on='unit')

    # concat with Shipping and Pipeline
    df_r_genByFuel_gnft_filtered = pd.concat([df_r_genByFuel_gnft_filtered, trans_concat_filtered], ignore_index=True)

    # #filter df_r_balance_marginalValue_gnft to t_start and t_end
    # df_r_genByFuel_gnft_filtered = df_r_genByFuel_gnft_filtered[(df_r_genByFuel_gnft_filtered['t'] >= t_start) & (df_r_genByFuel_gnft_filtered['t'] <= t_end)]
    # df_r_balance_marginalValue_gnft = df_r_balance_marginalValue_gnft[(df_r_balance_marginalValue_gnft['t'] >= t_start) & (df_r_balance_marginalValue_gnft['t'] <= t_end)]
    # df_i_ts_influx = df_i_ts_influx[(df_i_ts_influx['t'] >= t_start) & (df_i_ts_influx['t'] <= t_end)]

    # Convert DataFrame columns to dictionary
    df_r_genByFuel_gnft_filtered['Val'] = df_r_genByFuel_gnft_filtered['Val']/1000

    # Plot the area plot
    fig = px.bar(
        df_r_genByFuel_gnft_filtered, x='t', y='Val', color='unit', category_orders={'unit': variance_df['unit']}, color_discrete_map =color_dict_unit#, facet_row="grid"
        # line_shape='linear', line_group='unit', hover_data=[' XXX '], title=" XXX ",
        )
    
    # Add line plot to the figure as a secondary y-axis
    # if '0_' in key:
    fig.add_trace(go.Scatter(x=df_r_balance_marginalValue_gnft['t'], y=df_r_balance_marginalValue_gnft['Val']*-1,
                            mode='lines',
                            name='Marginal H2 Cost [€/MWh]',
                            yaxis='y2',
                            line=dict(color='black')))

    fig.add_trace(go.Scatter(x=df_i_ts_influx['t'],y=df_i_ts_influx['Val']*-1*(1/1000),
                        mode='lines',
                        name='Demand [GW]',
                        yaxis='y',
                        line=dict(color='grey')))

    fig.update_layout(
        title='Hydrogen Scheduling:: ' + node + '   ' + key,
        xaxis_title='Time Steps (t)',
        yaxis_title='Stacked Production [GW]',
        legend_title='Unit',
        plot_bgcolor='white',  # Set background color to white
        yaxis2=dict(title='Marginal Price [€/MWh]', overlaying='y', side='right'),
        legend=dict(x=1.05, y=1.),
        font=dict(
            family=default_font,
            size=16,  # Set the font size
            color="black"  # Set font color
        ),
        autosize=False,
        height=800,  # Set the height of the plot
        width=1300,
        barmode='relative',
        xaxis=dict(range=[t_start, t_end])  # Limit x-axis to t_start and t_end
    )

    fig.update_yaxes(matches=None, mirror=True, ticks='outside', showline=True, linecolor='black', gridcolor='lightgrey') #, range = [0, invest_df["limit"]])
    fig.update_xaxes(linecolor='black')
    fig.write_image(os.path.join(path_RFNBO_paper_vis, '07_' + key + node + "_f_generation_ts_h2.png"))
    fig.show()
    return

def tree_plot_h2_production(debug, key):
    r_gen_gn_df = debug.param_as_df_gdxdump('r_gen_gn')
    r_gen_gn_df = r_gen_gn_df.loc[r_gen_gn_df['grid'] == 'h2']
    r_gen_gn_df["Regions"] = r_gen_gn_df["node"].str.split("_").str[0]
    r_gen_gn_df = r_gen_gn_df.loc[~r_gen_gn_df["Regions"].str.contains("Terminal")]
    r_gen_gn_df["Continent"] = r_gen_gn_df["Regions"].str.split("-").str[0]
    r_gen_gn_df["Countries"] = r_gen_gn_df["Regions"].str.split("-").str[1]

    #drop rows with Val < 1
    r_gen_gn_df = r_gen_gn_df.loc[r_gen_gn_df["Val"] > 1]

    #sort by Val and then by Continent
    r_gen_gn_df = r_gen_gn_df.sort_values(by="Val")
    r_gen_gn_df = r_gen_gn_df.sort_values(by="Continent")

    # Assign colors based on the Continent column
    color_dict = {'EU': '#003399', 'AS': 'orange', 'AF': 'green', 'NA': 'red', 'SA': 'violet', 'OC': 'turquoise'}
    color_dict = {'EU': '#440154', 'AS': '#21918c', 'AF': '#fde725', 'NA': '#f05b72', 'SA': '#3b528b', 'OC': '#31a354'}
    colors = r_gen_gn_df['Continent'].map(color_dict)

    # #create colors by mapping viridis colors to the Continents
    # colors = plt.cm.viridis(np.linspace(0, 1, len(r_gen_gn_df['Continent'])))

    plt.figure(figsize=(140, 140))
    plt.title("Total Hydrogen Production " + str(round(r_gen_gn_df['Val'].sum()/10**6)) + " TWh " + str(key), fontsize=150, fontdict={'fontname': default_font})
    squarify.plot(sizes=r_gen_gn_df['Val'], label=r_gen_gn_df['Countries'], color=colors, alpha=0.7, linewidth=3, edgecolor="white",
                text_kwargs={'fontsize': 100, 'color': 'black', 'fontweight': 'bold',
                'bbox': dict(boxstyle="round,pad=0.3", edgecolor="none", facecolor="white", alpha=1)})
    plt.axis('off')
    #save figure
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("Total Hydrogen Production " + str(key) + ".png")), dpi=res_dpi, bbox_inches='tight')
    return

def tree_plot_h2_demand(debug, key):
    r_gen_gn_df = debug.param_as_df_gdxdump('ts_influx')

    #aggregate by node and grid
    r_gen_gn_df = r_gen_gn_df.groupby(['grid','node']).agg({'Val':'sum'}).reset_index()
    r_gen_gn_df = r_gen_gn_df.loc[r_gen_gn_df['grid'] == 'h2']
    r_gen_gn_df["Regions"] = r_gen_gn_df["node"].str.split("_").str[0]
    r_gen_gn_df["Continent"] = r_gen_gn_df["Regions"].str.split("-").str[0]
    #absolute Val
    r_gen_gn_df["Val"] = r_gen_gn_df["Val"].abs()
    # #drop rows with Val < 1
    r_gen_gn_df = r_gen_gn_df.loc[r_gen_gn_df["Val"] > 1]
    r_gen_gn_df["Countries"] = r_gen_gn_df["Regions"].str.split("-").str[1]

    #drop rows with Val < 1
    r_gen_gn_df = r_gen_gn_df.loc[r_gen_gn_df["Val"] > 1]

    #sort by Val and then by Continent
    r_gen_gn_df = r_gen_gn_df.sort_values(by="Val")
    r_gen_gn_df = r_gen_gn_df.sort_values(by="Continent")

    # Assign colors based on the Continent column
    color_dict = {'EU': '#003399', 'AS': 'orange', 'AF': 'green', 'NA': 'red', 'SA': 'violet', 'OC': 'turquoise'}
    color_dict = {'EU': '#440154', 'AS': '#21918c', 'AF': '#fde725', 'NA': '#f05b72', 'SA': '#3b528b', 'OC': '#31a354'}
    colors = r_gen_gn_df['Continent'].map(color_dict)

    # #create colors by mapping viridis colors to the Continents
    # colors = plt.cm.viridis(np.linspace(0, 1, len(r_gen_gn_df['Continent'])))

    plt.figure(figsize=(140, 140))
    plt.title("Total Hydrogen Demand " + str(round(r_gen_gn_df['Val'].sum()/10**6)) + " TWh " + str(key), fontsize=150, fontdict={'fontname': default_font})
    squarify.plot(sizes=r_gen_gn_df['Val'], label=r_gen_gn_df['Countries'], color=colors, alpha=0.7, linewidth=3, edgecolor="white",
                text_kwargs={'fontsize': 100, 'color': 'black', 'fontweight': 'bold',
                'bbox': dict(boxstyle="round,pad=0.3", edgecolor="none", facecolor="white", alpha=1)})
    plt.axis('off')
    #save figure
    plt.savefig(os.path.join(path_RFNBO_paper_vis, str("Total Hydrogen Demand " + str(key) + ".png")), dpi=res_dpi*0.75, bbox_inches='tight')
    return

def marginal_system_costs_plot(agg_world_regions):
    # marginal plot ## not finished ##
    agg_world_regions_c = agg_world_regions[['Regions','h2_demand','marginals_el','marginals_h2','scenario']]
    for scenario in agg_world_regions_c['scenario'].unique():
        agg_world_regions_c.loc[agg_world_regions_c['scenario'] == scenario,'h2_demand_weight'] = agg_world_regions_c[agg_world_regions_c['scenario'] == scenario]['h2_demand'] / agg_world_regions_c[agg_world_regions_c['scenario'] == scenario]['h2_demand'].sum()
    agg_world_regions_c['marginals_el_weighted'] = agg_world_regions_c['marginals_el'] * agg_world_regions_c['h2_demand_weight']
    agg_world_regions_c['marginals_h2_weighted'] = agg_world_regions_c['marginals_h2'] * agg_world_regions_c['h2_demand_weight']
    agg_agg_world_regions_c = agg_world_regions_c.groupby('scenario').agg({'marginals_el_weighted':'sum','marginals_h2_weighted':'sum'}).reset_index()

    base_value_h2 = agg_agg_world_regions_c[agg_agg_world_regions_c["scenario"].str.startswith('0_')]["marginals_h2_weighted"].values
    base_value_el = agg_agg_world_regions_c[agg_agg_world_regions_c["scenario"].str.startswith('0_')]["marginals_el_weighted"].values
    agg_agg_world_regions_c["H2 Costs relative to base case"] = (agg_agg_world_regions_c["marginals_h2_weighted"]/base_value_h2)
    agg_agg_world_regions_c["Elec Costs relative to base case"] = (agg_agg_world_regions_c["marginals_el_weighted"]/base_value_el)
    #merge with agg_tsc_df on scenario
    for cost_rel_to_baseCase in ['H2 Costs relative to base case','Elec Costs relative to base case']:
        agg_agg_world_regions_c[cost_rel_to_baseCase] = agg_agg_world_regions_c[cost_rel_to_baseCase] * 100 - 100
        agg_agg_world_regions_c[cost_rel_to_baseCase] = agg_agg_world_regions_c[cost_rel_to_baseCase].round(2)
        # Convert the values to string with '%' symbol
        agg_agg_world_regions_c[cost_rel_to_baseCase] = agg_agg_world_regions_c[cost_rel_to_baseCase].astype(str) + '%'
        # delete zeros
        agg_agg_world_regions_c[cost_rel_to_baseCase] = agg_agg_world_regions_c[cost_rel_to_baseCase].replace("0.0%", "")
    ## change this to long format and facet_row ## to do ##
    #Building bar chart for total system costs from agg_agg_world_regions_c
    agg_agg_world_regions_c_long = pd.concat([
        agg_agg_world_regions_c[['scenario','marginals_el_weighted','Elec Costs relative to base case']].rename(columns={'marginals_el_weighted':'marginals','Elec Costs relative to base case':'Costs relative to base case'}).assign(**{'grid':'elec'}),
        agg_agg_world_regions_c[['scenario','marginals_h2_weighted','H2 Costs relative to base case']].rename(columns={'marginals_h2_weighted':'marginals','H2 Costs relative to base case':'Costs relative to base case'}).assign(**{'grid':'h2'})
        ])
    
    #apply scen_name_dict
    agg_agg_world_regions_c_long["scenario_name"] = agg_agg_world_regions_c_long["scenario"].map(scen_names_dict)

    fig = px.bar(agg_agg_world_regions_c_long,
                x="scenario_name", 
                y="marginals", 
                title="Marginal System Costs: " + str_XX_region, 
                color="scenario", 
                hover_data=["scenario"], 
                color_discrete_map=scen_color_dict,
                text="Costs relative to base case",
                facet_row='grid',
                )
    
    # Add subplot titles
    fig.for_each_annotation(lambda a: a.update(text=a.text.split("=")[1].replace("elec", "Electricity").replace("h2", "Hydrogen")))

    # Increase the size of the label
    fig.update_layout(
        font=dict(
            size=16,  # Set the font size here
            family=default_font,
            color="black"
        )
    )

    fig.update_yaxes(
        mirror=True,
        ticks='outside',
        showline=True,
        linecolor='black',
        gridcolor='lightgrey',
        range=[0, agg_agg_world_regions_c_long['marginals'].max() * 1.1],
        title_text="Marginal Costs [€/MWh]"
    )
    
    fig.update_xaxes(linecolor='black', title="Scenario", showline=True, gridcolor='lightgrey')
    fig.update_layout(plot_bgcolor='white', autosize=False, width=1300, height=800, showlegend=False) #font=dict(size=12, family=default_font, color="black")
    # Update text position
    fig.update_traces(textposition='outside')
    fig.write_image(os.path.join(path_RFNBO_paper_vis, "demand weighted average marginals.png"), scale=res_dpi/3, width=700, height = 700)
    return

print("Main working loop + export visualizations to figure folder" + "\n")

agg_transp_r = pd.DataFrame()
agg_transm_r = pd.DataFrame()
agg_term_r = pd.DataFrame()
agg_ship_r = pd.DataFrame()
agg_world_regions = pd.DataFrame()
agg_invest_df = pd.DataFrame()
agg_tsc_df = pd.DataFrame()

for key in results_dict.keys():
    if "results" in key:
        results = results_dict[key]
        debug = results_dict[key.replace("results", "debug")]
        scen_key = key
        transp_r, transm_r, term_r, ship_r = transport_df_preprocessing(results, scen_key) #transport_results_m, transmission_results_m, terminal_connections_m, shipping_m 
        print(results)
        nodes_disag, nodes_h2, world_regions = nodal_df_preprocessing(results, debug, scen_key) #nodes_disag, nodes_h2, world_regions
        agg_transp_r = pd.concat([agg_transp_r, transp_r])
        agg_transm_r = pd.concat([agg_transm_r, transm_r])
        agg_term_r = pd.concat([agg_term_r, term_r])
        agg_ship_r = pd.concat([agg_ship_r, ship_r])
        agg_world_regions = pd.concat([agg_world_regions, world_regions])

        invest_df_work = inv_df_prepro(results, key)
        print("key_bc: " + str(key_bc))
        print("scen_key: " + str(scen_key))
        if str("bc") in scen_key:
            base_scen = scen_key
            invest_df_bc = invest_df_work.copy()
            invest_df_bc = invest_df_bc.rename(columns={"Capacity [MW]":"Capacity [MW]_bc"})
        invest_df = cap_diff(invest_df_work, invest_df_bc, key)
        agg_invest_df = pd.concat([agg_invest_df, invest_df])
        tsc_df = total_system_costs(results, scen_key)
        agg_tsc_df = pd.concat([agg_tsc_df, tsc_df])

        prod_trans_geoplot(scen_key, world_regions, nodes_h2, transp_r, transm_r, term_r, ship_r)
        # marginals_geoplot(scen_key)
        # invest_df_preprocessing(results, debug)
        # r_capacity(results, debug, key)
        # r_generation(results, key)
        # powerplant_scheduling_plot(debug, key)
        # tree_plot_h2_production(debug, key)
        # tree_plot_h2_demand(debug, key)
        # cost_duration_curve(debug, scen_key)
        print("Succesfully exported results for scenario " + str(key) + "\n")

# potential_hydrogen_transport_system()
# WACC_geoplot(agg_world_regions)
# cap_diff_plot(agg_invest_df)
# cap_diff_rel_plot(agg_invest_df)
# total_system_costs_plot(agg_tsc_df)
# installed_vre_capacities(agg_invest_df)
# marginal_system_costs_plot(agg_world_regions)
# color_scale_plot(vmin, vmax)

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')  
# %%
