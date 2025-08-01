#This is the tool to assess certain RFNBO criteria such as CO2 intensity

#activate myenv
#C:\Users\oliver\InstallScriptSpineToolbox_v1\myenv\Scripts\activate.bat
#%%
"""
RFNBO assessment tool

Created 18.10.2024
@author OL
Last changed 18.01.2024
"""

#import modules
import sys
import pandas as pd
import geopandas as gpd
import os
from shapely.geometry import Point, Polygon, LineString, MultiPoint
from shapely.ops import triangulate
import pandas as pd
from matplotlib import pyplot as plt
import numpy as np
from itertools import combinations
from scipy.spatial import Delaunay
from backbonetools.io import BackboneResult
import seaborn as sns
import time
from matplotlib.patches import Patch
from matplotlib import colors

############### Load Data ###############

print('Execute in Directory:')
print(os.getcwd() + "\n")

START = time.perf_counter()

print("Start reading input Data" + "\n")

try:
    #use if run in spine-toolbox
    path_world_eu_bz                = r"..\Data\Transport\data_input\world_eu_bz\world_eu_bz.shp"
    path_nodes                      = r"..\Data\Transport\data_input\nodes\nodes_and_parameters.xlsx"
    path_Main_Input                 = "TEMP\\MainInput.xlsx"
    subset_countries                = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
    # ### RFNBO paper visualization ###
    path_RFNBO_paper_vis            = r"..\Data\HPC_results\RFNBO_test\figures"
    path_RFNBO_paper_res            = r"..\Data\HPC_results\RFNBO_test"
    world                               = gpd.read_file(os.path.join("..", "Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    path_world_eu_bz                = r".\Data\Transport\data_input\world_eu_bz\world_eu_bz.shp"
    path_nodes                      = r".\Data\Transport\data_input\nodes\nodes_and_parameters.xlsx"
    path_Main_Input                 = r".\PythonScripts\TEMP\MainInput.xlsx"
    subset_countries                = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
    path_RFNBO_paper_vis            = r".\Data\HPC_results\RFNBO_test\figures"
    path_RFNBO_paper_res            = r".\Data\HPC_results\RFNBO_test"
    world                               = gpd.read_file(os.path.join("Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile

res_dpi                         = 25
alternative = "APS_2030"

#read in results.gdx and/or debug.gdx
prerun_path = os.path.join(path_RFNBO_paper_res, "2_Def_Grid_2030\\2_Def_Grid_prerun")

case_color_dict = {'May': 'red', 'May_not': 'white'}

print("Read and preprocess geo data and results", "\n")  
#import shapefiles
world_eu_bz = gpd.read_file(os.path.join(path_world_eu_bz))

#import geopandas included shapefiles
world = world[["POP_EST", "CONTINENT", "NAME", "ISO_A3", "GDP_MD", "geometry"]]
world = world.rename(columns={"NAME":"name", "ISO_A3":"iso_a3", "POP_EST":"pop_est", "GDP_MD":"gdp_md_est", "CONTINENT":"continent"}) #renaming columns to match the ones in the nodeset


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

#%%
#copying geometry information from world where new_nodes_disag are within the geometry of the row in world
world_regions = gpd.sjoin(world, nodes_disag, how="inner", predicate="intersects").reset_index()
world_regions = world_regions[["name_right", "region", "geometry", "value1", "value2"]]
world_regions = world_regions.rename(columns={"name_right":"name", "value1":"x", "value2":"y"})
#create lists of all countries that belong to each region
country_regions_list = world_regions.groupby("region").agg({"name": lambda x: list(x)}, ignore_index=True).reset_index()
#unify geometries on region names
world_regions = world_regions.dissolve(by="region", aggfunc={"name":"first", "x":"mean", "y":"mean"})
world_regions = world_regions.merge(country_regions_list, on="region", how="left")
world_regions = world_regions.drop(columns=["name_x"])
world_regions = world_regions.rename(columns={"name_y":"list_of_countrycodes"}).reset_index(drop=True)

results_df = BackboneResult(os.path.join(prerun_path, "results.gdx"))
debug_df = BackboneResult(os.path.join(prerun_path, "debug.gdx"))

#%%
#prepare dataframe with CO2 emissions, electricity demand and renewable share
r_emission_df = results_df.r_emission()
r_emission_df["region"] = r_emission_df["emission"].str.split("_").str[0]
r_emission_df = r_emission_df.drop(columns=["emission"])
r_emission_df = r_emission_df.rename(columns={"Val":"CO2 emissions [t]"})

r_gen_gn_df = results_df.r_gen_gn()
#only elec grid
r_gen_gn_df = r_gen_gn_df.query("grid == 'elec'")
r_gen_gn_df["region"] = r_gen_gn_df["node"].str.split("_").str[0]
r_gen_gn_df["node"] = r_gen_gn_df.apply(lambda row: row["node"].replace(row["region"], ""), axis=1)
r_gen_gn_el_df = r_gen_gn_df.loc[r_gen_gn_df["node"] == "_el"]
r_gen_gn_re_el_df = r_gen_gn_df.loc[r_gen_gn_df["node"] == "_re_el"]
r_gen_gn_df = r_gen_gn_el_df.merge(r_gen_gn_re_el_df, on=["region", "grid"], how="outer", suffixes=("", "_re"))
r_gen_gn_df = r_gen_gn_df.drop(columns=["node", "grid", "node_re"])
r_gen_gn_df = r_gen_gn_df.rename(columns={"Val":"el generation [MWh]", "Val_re":"re_el generation [MWh]"})

r_gen_gn_df["Total generation [MWh]"] = r_gen_gn_df["el generation [MWh]"] + r_gen_gn_df["re_el generation [MWh]"]
r_gen_gn_df["re_el generation [MWh] rel"] = r_gen_gn_df["re_el generation [MWh]"] / r_gen_gn_df["Total generation [MWh]"]

print("Assess CO2 intensity", "\n")  
#merge with geoinformation
assessment_df = pd.merge(r_emission_df, r_gen_gn_df, how="left", on=["region"])
assessment_df = assessment_df.merge(world_regions, how="left", on="region")
assessment_df = assessment_df.set_geometry("geometry")
#calculate CO2 intensity
assessment_df["CO2 intensity [g/kWh]"] = assessment_df["CO2 emissions [t]"]/assessment_df["Total generation [MWh]"]*1000
#apply RFNBO rules
#The limits are either more then 90% of the electricity being renewable or the CO2 intensity being below 64.8 gCO2/kWh
assessment_df["may_draw"] = np.where((assessment_df["CO2 intensity [g/kWh]"] < 64.8) | (assessment_df["re_el generation [MWh] rel"] > 0.9), "May", "May_not")
#color code countries that may draw electricity directly from the grid
assessment_df["colors"] = assessment_df["may_draw"].map(case_color_dict)
assessment_df = assessment_df.sort_values(by="CO2 intensity [g/kWh]", ascending=False).reset_index(drop=True)

print("Plot CO2 intensity visualization", "\n")  
base = world.plot(color='#a8a8a8', linewidth=0.5, edgecolor='white', figsize=(100,80), alpha=0.5)
assessment_df.plot(ax=base, column=assessment_df["CO2 intensity [g/kWh]"], cmap="viridis_r", edgecolor=assessment_df["colors"], linewidth=6, alpha=1, legend=False, zorder=3, legend_kwds={"label": "CO2 intensity", "orientation": "horizontal"}, # 'shrink': 0.3
                missing_kwds={"color": "lightgrey", "edgecolor": "red","hatch": "///","label": "Missing values"}) #color='#a8a8a8' RdYlGn_r
#nodes.plot(ax=base, color='black', markersize=500, linewidth=2, alpha=1, edgecolors='white', label="Regions nodes", zorder=3) ##E05252

#plotting the values from assessment_df["CO2 intensity [g/kWh]"] onto the map as annotations
for x, y, label in zip(assessment_df["x"], -assessment_df["y"], assessment_df["CO2 intensity [g/kWh]"].round(2).abs()):
    base.annotate(label, xy=(x, -y), xytext=(5, 5), textcoords="offset points", fontsize=50, bbox=dict(facecolor='white', edgecolor='none', boxstyle='round,pad=0.5'))

norm = colors.Normalize(vmin=0, vmax=100)
cbar = plt.cm.ScalarMappable(norm=norm, cmap="viridis_r")
cbar.set_array([])
plt.colorbar(cbar, ax=base, orientation="vertical", fraction=0.05, pad=0.02)

#insert legend
legend_elements1 =    [
                    Patch(facecolor="limegreen", edgecolor='white', linewidth=2, label='CO2 intensity > 64.8 g/kWh or < 90% share of renewables'),
                    Patch(facecolor="limegreen", edgecolor='red', linewidth=8, label='CO2 intensity < 64.8 g/kWh or > 90% share of renewables'),
                    ]
plt.legend(loc="upper center", fontsize=50, title=("CO2 intensity [g/kWh]"), title_fontsize=100)
plt.legend(loc="lower left", handles=legend_elements1, ncol=1, fontsize=80)
plt.ylim(28,70) #Europa
plt.xlim(-25,38) #Europa
base.set_axis_off()
plt.savefig(os.path.join(prerun_path, ("Prerun_CO2_intensity_" + str(alternative) + ".png")), dpi=res_dpi, bbox_inches='tight', pad_inches=0.1)
assessment_df.to_csv(os.path.join(prerun_path, "assessment_df.csv"), sep=";", index=False)

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's', "\n")
#%%