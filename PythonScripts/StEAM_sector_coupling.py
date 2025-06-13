"""
Sector coupling script

Created 2023
@author OL
reworked on 15.01.2024 OL commodity and tech flexibility update // 20240130 KT port 2 Backbone
"""
#%%
#import modules
import sys
import geopandas as gpd
import os
from shapely.geometry import Point, Polygon, LineString, MultiPoint
import pandas as pd
from matplotlib import pyplot as plt
import numpy as np
import time

############### Load Data ###############

print("Start reading transport nodes, terminals and parameters" + "\n")

print("Define the order of Tool arguments as follows:" + "\n")
print("[0] = sector_coupling_technologies.xlsx" + "\n")
print("[1] = MainInput.xlsx" + "\n")

print('Execute in Directory:')
print(os.getcwd())

START = time.perf_counter() 

try:
    #use if run in spine-toolbox
    path_sector_coupling_technologies   = sys.argv[1]
    path_Main_Input                     = sys.argv[2]
    path_WACC_Update                    = sys.argv[3]
    outputfile                          = r"TEMP\\sector_coupling.xlsx"
    outputfile_BB                       = r"TEMP\\sector_coupling_BB.xlsx"
    path_WACC_data                      = r'Data/Szenario_Data/03 - APS_scenario_data.xlsx' #needs to be adapted if scenario/year dependend
    WACC_data                           = pd.read_excel(path_WACC_data, sheet_name="WACC_table")
    subset_countries                    = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries")
    subset_countries                    = subset_countries.rename(columns={"Countries":"name"})
    m_conf                              = pd.read_excel(path_Main_Input, sheet_name="model_config")
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    #use if run in Python environment
    path_sector_coupling_technologies   = r"Data\Transport\data_input\sector_coupling\sector_coupling_technologies.xlsx"
    path_Main_Input                     = r"PythonScripts\TEMP\MainInput.xlsx"
    path_WACC_Update                    = r'PythonScripts/TEMP/weighted_WACC_final.csv'
    outputfile                          = r"PythonScripts\\TEMP\\sector_coupling.xlsx"
    outputfile_BB                       = r"PythonScripts\\TEMP\\sector_coupling_BB.xlsx"
    subset_countries                    = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
    m_conf                              = pd.read_excel(path_Main_Input, sheet_name="model_config")
    #2040808 obsolete
    #path_WACC_data                      = r'Data/Szenario_Data/03 - APS_scenario_data.xlsx' #needs to be adapted if scenario/year dependend
    #WACC_data                           = pd.read_excel(path_WACC_data, sheet_name="WACC_table")

print(subset_countries["name"])

print("\n" + "Start reading GIS base information" + "\n")

#import geopandas included shapefiles
world = gpd.read_file(os.path.join("Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile
world = world[["POP_EST", "CONTINENT", "NAME", "ISO_A3", "GDP_MD", "geometry"]]
world = world.rename(columns={"NAME":"name", "ISO_A3":"iso_a3", "POP_EST":"pop_est", "GDP_MD":"gdp_md_est", "CONTINENT":"continent"}) #renaming columns to match the ones in the nodeset

print("Succesfully read all files" + "\n")
#%%
############### Centrally define default model parameters ###############

#reading basic temporal model information from MainInput
time_period = pd.read_excel(os.path.join(path_Main_Input), sheet_name="model_date") #einlesen der xlsx in ein dataframe
t_start = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[0])
t_end = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[1])
alternative = pd.read_excel(pd.ExcelFile(path_Main_Input), sheet_name="scenarios").alternative[1]
time_share   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760) #share of the year
duration = round(((t_end - t_start) / pd.Timedelta(hours=1)) * (1/24)) #duration in days

#eps
eps                         = float(0.0001)  # read the eps value of the model_config sheet in the excel file path_Main_Input and save the values as eps // eps default value
eps                         = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value

print("Alternative: " + str(alternative) + "\n")

default_alternative = 'Base'
default_WACC = 0.06 #default WACC
default_initial_units_invested_available = 0
default_candidate_units = 1000
default_fom_cost = 0
default_unit_investment_cost = 1000
default_unit_investment_lifetime = 20
default_unit_investment_lifetime_js = "{\"type\": \"duration\", \"data\": \"" + str(duration) + "D\"}"
default_unit_investment_variable_type = "unit_investment_variable_type_continuous"
default_fuel_cost = 2
default_unit_capacity = 1
default_vom_cost = 3
default_fix_ratio_io = 0.7
default_fix_ratio_ii_grav = 9 #kgh2o/kgh2
h2_energy_density = 33.3 #kWh/kgH2
default_fix_ratio_ii = default_fix_ratio_ii_grav/h2_energy_density #kgh2o/kgh2 / kWh/kgH2 = kgh2o/kWhh2
capacity_from = 1000
water_price =0 #EUR/kg

desalination_var = 0 #if desalination shall be included in the model, set to 1, else 0 - currently not working

print("Succesfully defined default model parameters" + "\n")

m_conf                      = pd.read_excel(path_Main_Input, sheet_name="model_config")
#prepare investcost calculation
t_start                     = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[0])
t_end                       = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[1])
modeled_duration_in_years   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760)

############### Centrally define default model parameters ###############

#mit diesem Skript werden aus der Liste aus der neues nodes Datei die einzelnen nodes in ein dataframe geschrieben und die Koordinaten in ein funktionierendes geometry Objekt verpackt.
h2_sector_coupling_tech = pd.read_excel(os.path.join(path_sector_coupling_technologies), sheet_name=0) #einlesen der xlsx in ein dataframe
#new_nodes = pd.read_excel(os.path.join(data_pth_input, "nodes/nodes_and_parameters_presentation.xlsx"), sheet_name=0) #einlesen der xlsx in ein dataframe alternative nodeset for presentations
h2_sector_coupling_tech = h2_sector_coupling_tech.rename(columns={"attribute.1":"attribute_"})
h2_sector_coupling_tech = h2_sector_coupling_tech[["name", "value1", "value2", "alternative", "technology", "commodities_in", "commodities_out", "efficiencies", "WACC", "initial_units_invested_available", "candidate_units", "fom_cost", "unit_investment_cost", "unit_investment_lifetime", "fuel_cost", "unit_capacity", "vom_cost", "reg_fac"]]
h2_sector_coupling_tech = h2_sector_coupling_tech.rename(columns={"value1":"x", "value2":"y"})      #renaming coordinate columns
#h2_sector_coupling_tech["y"] = h2_sector_coupling_tech["y"]*(-1)

#only using the rows that match the name in subset_countries
h2_sector_coupling_tech = h2_sector_coupling_tech[h2_sector_coupling_tech["name"].isin(subset_countries["name"])]

#adding a column with the respective regions from subset_countries to h2_sector_coupling_tech
h2_sector_coupling_tech = h2_sector_coupling_tech.merge(subset_countries, on="name", how="left")

#filling default values if there is no value in the excel sheet
h2_sector_coupling_tech["alternative"] = h2_sector_coupling_tech["alternative"].fillna(default_alternative)

## WACC Update 20240802
# get WACC data
df_WACC = pd.read_csv(path_WACC_Update, sep=';')[['name','Cost of Capital','Zuordnung Steam']]
df_WACC = pd.concat([df_WACC.drop('Zuordnung Steam', axis=1), df_WACC['Zuordnung Steam'].str.replace('[','').str.replace(']','').str.split(',', expand=True)], ignore_index=False, axis=1)
# %% merge unit technology names as prep for WACC data merge
df_rename_technologies = pd.DataFrame([['h2_ocgt_','H2|OCGT|'],['fuel_cell_','H2|FuelCell|'],['electrolyzer_','Electrolyzer|'],['desalination_','Desalination|'], ["h2_engine_", "H2|Engine|"]], columns=['technology','technology_renamed'])
df_rename_technologies['technology'] = df_rename_technologies['technology'].str.strip('_')
df_rename_technologies['technology_renamed'] = df_rename_technologies['technology_renamed'].str.strip('|')
h2_sector_coupling_tech = h2_sector_coupling_tech.merge(df_rename_technologies, on='technology', how='left')
# merge WACC data
h2_sector_coupling_tech = h2_sector_coupling_tech.drop('WACC', axis=1).merge(df_WACC.rename(columns={'Cost of Capital':'WACC'}), on='name', how='left')
# h2_sector_coupling_tech.loc[:, [col for col in h2_sector_coupling_tech.columns if isinstance(col, int)]]
h2_sector_coupling_tech = h2_sector_coupling_tech[    # this filters for correct technologies in WACC data ## I dont know how to do this in a prettier way atm... but Im open to suggestions
    (h2_sector_coupling_tech['technology_renamed'] == h2_sector_coupling_tech[0]) | 
    (h2_sector_coupling_tech['technology_renamed'] == h2_sector_coupling_tech[1]) |
    (h2_sector_coupling_tech['technology_renamed'] == h2_sector_coupling_tech[2]) |
    (h2_sector_coupling_tech['technology_renamed'] == h2_sector_coupling_tech[3]) |
    (h2_sector_coupling_tech['technology_renamed'] == h2_sector_coupling_tech[4])
].drop(['technology_renamed',0,1,2,3,4], axis=1).reset_index(drop=True)     # remove all intermediate WACC merging columns

h2_sector_coupling_tech = h2_sector_coupling_tech.drop('WACC', axis=1).merge(pd.read_csv(path_WACC_Update, sep=';')[['name','ERP_WACC']].rename(columns={'ERP_WACC':'WACC'}), on='name', how='left')

h2_sector_coupling_tech["WACC"] = h2_sector_coupling_tech["WACC"].fillna(default_WACC)
h2_sector_coupling_tech["initial_units_invested_available"] = h2_sector_coupling_tech["initial_units_invested_available"].fillna(default_initial_units_invested_available)
h2_sector_coupling_tech["candidate_units"] = h2_sector_coupling_tech["candidate_units"].fillna(default_candidate_units)
h2_sector_coupling_tech["unit_investment_lifetime"] = h2_sector_coupling_tech["unit_investment_lifetime"].fillna(default_unit_investment_lifetime)
h2_sector_coupling_tech["unit_investment_lifetime_js"] = default_unit_investment_lifetime_js
h2_sector_coupling_tech["unit_investment_cost"] = h2_sector_coupling_tech.unit_investment_cost.fillna(default_unit_investment_cost)
h2_sector_coupling_tech["fom_cost"] = (h2_sector_coupling_tech["fom_cost"] * h2_sector_coupling_tech["reg_fac"] * h2_sector_coupling_tech["unit_investment_cost"]).fillna(default_fom_cost)
h2_sector_coupling_tech["unit_investment_variable_type"] = default_unit_investment_variable_type
h2_sector_coupling_tech["fuel_cost"] = h2_sector_coupling_tech["fuel_cost"].fillna(default_fuel_cost)
h2_sector_coupling_tech["unit_capacity"] = h2_sector_coupling_tech["unit_capacity"].fillna(default_unit_capacity)
h2_sector_coupling_tech["vom_cost"] = h2_sector_coupling_tech["vom_cost"].fillna(default_vom_cost)
h2_sector_coupling_tech["reg_fac"] = h2_sector_coupling_tech["reg_fac"].fillna(1)

#Here the units are being connected with their respective Input and Output commodities and efficiencies
print("Efficienies started" + "\n")

sec_tech_1D = pd.DataFrame(columns=["unit", "alternative", "technology", "node_in", "node_out", "WACC", "initial_units_invested_available", "candidate_units", "fom_cost", "unit_investment_cost", "unit_investment_lifetime", "unit_investment_lifetime_js", "unit_investment_variable_type"])
sec_tech_2D = pd.DataFrame(columns=["unit", "alternative", "technology", "node_in", "node_out", "x", "y", "capacity_in", "capacity_out", "fuel_cost", "vom_cost"])
sec_tech_3D = pd.DataFrame(columns=["unit", "alternative", "technology", "node_in", "node_out", "parameter", "efficiency"])

for i in h2_sector_coupling_tech.index:
    list_element = 0
    a = h2_sector_coupling_tech.iloc[i]["technology"]
    com_in = h2_sector_coupling_tech.iloc[i]["commodities_in"]
    com_in_list = com_in.split(";")
    com_out = h2_sector_coupling_tech.iloc[i]["commodities_out"]
    com_out_list = com_out.split(";")
    eff = h2_sector_coupling_tech.iloc[i]["efficiencies"]
    eff_list = str(eff).split(";")
    alt = h2_sector_coupling_tech.iloc[i]["alternative"]
    region = h2_sector_coupling_tech.iloc[i]["Regions"]
    x = h2_sector_coupling_tech.iloc[i]["x"]
    y = h2_sector_coupling_tech.iloc[i]["y"]
    WACC = h2_sector_coupling_tech.iloc[i]["WACC"]
    initial_units_invested_available = h2_sector_coupling_tech.iloc[i]["initial_units_invested_available"]
    candidate_units = h2_sector_coupling_tech.iloc[i]["candidate_units"]
    fom_cost = h2_sector_coupling_tech.iloc[i]["fom_cost"]
    unit_investment_cost = h2_sector_coupling_tech.iloc[i]["unit_investment_cost"]
    unit_investment_lifetime = h2_sector_coupling_tech.iloc[i]["unit_investment_lifetime"]
    unit_investment_lifetime_js = h2_sector_coupling_tech.iloc[i]["unit_investment_lifetime_js"]
    unit_investment_variable_type = h2_sector_coupling_tech.iloc[i]["unit_investment_variable_type"]
    cap_in = h2_sector_coupling_tech.iloc[i]["unit_capacity"]
    cap_out = h2_sector_coupling_tech.iloc[i]["unit_capacity"]
    fuel_cost = h2_sector_coupling_tech.iloc[i]["fuel_cost"]
    vom = h2_sector_coupling_tech.iloc[i]["vom_cost"]
    for j in range(len(com_in_list)):
        com_in_j = com_in_list[j]
        for k in range(len(com_out_list)):
            com_out_k = com_out_list[k]
            name = h2_sector_coupling_tech.iloc[i]["name"]
            b = name + "_" + com_in_j
            c = name + "_" + com_out_k
            d = eff_list[list_element]
            sec_tech_fill_1D = pd.DataFrame({"unit": [a + "_" + name], "technology": [a], "alternative": [alt], "region": [region], "node_in": [b], "node_out": [c], "commodity_in": [com_in_j], "commodity_out": [com_out_k], "WACC": [WACC], "initial_units_invested_available": [initial_units_invested_available], "candidate_units": [candidate_units], "fom_cost": [fom_cost], "unit_investment_cost": [unit_investment_cost], "unit_investment_lifetime": [unit_investment_lifetime], "unit_investment_lifetime_js": [unit_investment_lifetime_js], "unit_investment_variable_type": [unit_investment_variable_type]})
            sec_tech_1D = pd.concat([sec_tech_1D, sec_tech_fill_1D], ignore_index=True)
            sec_tech_fill_2D = pd.DataFrame({"unit": [a + "_" + name], "technology": [a], "alternative": [alt], "name": name, "region": [region], "node_in": [b], "node_out": [c], "commodity_in": [com_in_j], "commodity_out": [com_out_k], "x": [x], "y": [y], "capacity_in": [float(cap_in)], "capacity_out": [float(cap_out)], "fuel_cost": [float(fuel_cost)], "vom_cost": [float(vom)]}) 
            sec_tech_2D = pd.concat([sec_tech_2D, sec_tech_fill_2D], ignore_index=True)
            sec_tech_fill_3D = pd.DataFrame({"unit": [a + "_" + name], "technology": [a], "alternative": [alt], "region": [region], "node_in": [b], "node_out": [c], "commodity_in": [com_in_j], "commodity_out": [com_out_k], "parameter": "fix_ratio_out_in_unit_flow", "efficiency": [float(d)]}) 
            sec_tech_3D = pd.concat([sec_tech_3D, sec_tech_fill_3D], ignore_index=True)
            list_element = list_element + 1

print("Efficienies ended" + "\n")

#saving disaggregated dataframes
sec_tech_disagg = sec_tech_2D.copy()

#aggregating the nodes if subset_countries contains values in column with the header "region"
if len(subset_countries["Regions"]) != 0:
    print("Aggregation enabled" + "\n")
    #aggregating the nodes by the regions
    #1D
    sec_tech_1D = sec_tech_1D.groupby(["region", "alternative", "technology"]).agg({"WACC":"mean", "initial_units_invested_available":"sum", "candidate_units":"sum", "fom_cost":"mean", "unit_investment_cost":"mean", "unit_investment_lifetime":"mean", "unit_investment_lifetime_js":"first", "unit_investment_variable_type":"first"})     # no WACC weighting ## to do ##
    sec_tech_1D = sec_tech_1D.reset_index()
    #reset region as name and redefine unit as technology + "_" + name
    sec_tech_1D["unit"] = sec_tech_1D["technology"] + "_" + sec_tech_1D["region"]
    #2D
    sec_tech_2D = sec_tech_2D.groupby(["region", "alternative", "technology", "commodity_in", "commodity_out"]).agg({"x":"mean", "y":"mean", "capacity_in":"sum", "capacity_out":"sum", "fuel_cost":"mean", "vom_cost":"mean"})
    sec_tech_2D = sec_tech_2D.reset_index()
    #reset region as name and redefine unit as technology + "_" + name
    sec_tech_2D["unit"] = sec_tech_2D["technology"] + "_" + sec_tech_2D["region"]
    sec_tech_2D["node_in"] = sec_tech_2D["region"] + "_" + sec_tech_2D["commodity_in"]
    sec_tech_2D["node_out"] = sec_tech_2D["region"] + "_" + sec_tech_2D["commodity_out"]
    #3D
    sec_tech_3D = sec_tech_3D.groupby(["region", "alternative", "technology", "commodity_in", "commodity_out"]).agg({"parameter":"first", "efficiency":"mean"}) #bei first funktionert es - bei mean nicht
    sec_tech_3D = sec_tech_3D.reset_index()
    #reset region as name and redefine unit as technology + "_" + name
    sec_tech_3D["unit"] = sec_tech_3D["technology"] + "_" + sec_tech_3D["region"]
    sec_tech_3D["node_in"] = sec_tech_3D["region"] + "_" + sec_tech_3D["commodity_in"]
    sec_tech_3D["node_out"] = sec_tech_3D["region"] + "_" + sec_tech_3D["commodity_out"]
else:
    print("Aggregation disabled" + "\n")

#combining the geodataframes again to one geodataframe after aggregation
sector_coupling_agg_nodes_points_agg = sec_tech_2D.apply(lambda row: Point(row.x, row.y), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte
sec_tech_agg = gpd.GeoDataFrame(sec_tech_2D, geometry = sector_coupling_agg_nodes_points_agg) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
sec_tech_agg.crs = "EPSG:4326" #anpassen der Projektion

sector_coupling_nodes_points_disagg = sec_tech_disagg.apply(lambda row: Point(row.x, row.y), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte
sec_tech_disagg = gpd.GeoDataFrame(sec_tech_disagg, geometry = sector_coupling_nodes_points_disagg) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
sec_tech_disagg.crs = "EPSG:4326" #anpassen der Projektion

#%%
#copying geometry information from world where h2_sector_coupling_nodes_disag are within the geometry of the row in world
world_regions = gpd.sjoin(world, sec_tech_disagg, how="inner", predicate="contains")
world_regions = world_regions[["name_right", "region", "geometry", "x", "y"]]
world_regions = world_regions.rename(columns={"name_right":"name"})
#create lists of all countries that belong to each region
country_regions_list = world_regions.groupby("region").agg({"name": lambda x: list(x)})
#unify geometries on region names
world_regions = world_regions.dissolve(by="region", aggfunc={"name":"first"})
world_regions = world_regions.merge(country_regions_list, on="region", how="left")
world_regions = world_regions.drop(columns=["name_x"])
world_regions = world_regions.rename(columns={"name_y":"list_of_countrycodes"})
world_regions = world_regions.reset_index()

#assign the list of countrycodes to sec_tech_agg by region
sec_tech_agg = sec_tech_agg.merge(world_regions, on="region", how="left")
sec_tech_agg = sec_tech_agg.rename(columns={"geometry_y":"regions_geometry"})
sec_tech_agg = gpd.GeoDataFrame(sec_tech_agg, geometry=sec_tech_agg.geometry_x)
sec_tech_agg = sec_tech_agg.drop(columns=["geometry_x"])

#processing of the prepared dataframes to allow for easier readability in the ESM framework Spine

#1-Dimensional Importer Mappings
#h2_units
h2_units_concat_unit_investment_cost = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"unit_investment_cost", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.unit_investment_cost})
h2_units_concat_unit_investment_lifetime_js = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"unit_investment_lifetime", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.unit_investment_lifetime_js})
h2_units_concat_unit_investment_variable_type = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"unit_investment_variable_type", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.unit_investment_variable_type})
h2_units_concat_fom_cost = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"fom_cost", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.fom_cost})
h2_units_concat_candidate_units = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"candidate_units", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.candidate_units})
h2_units_concat_initial_units_invested_available = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"initial_units_invested_available", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.initial_units_invested_available})
h2_units_concat_number_of_units                = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"number_of_units", "Alternative names":sec_tech_1D.alternative, "Parameter values":0})
h2_units_concat_annuity_factor = pd.DataFrame({"Object_class_names":"unit", "Object names 1":sec_tech_1D.unit, "Parameter names":"annuityFactor", "Alternative names":sec_tech_1D.alternative, "Parameter values":(sec_tech_1D.WACC * (1 + sec_tech_1D.WACC)**sec_tech_1D.unit_investment_lifetime) / ((1 + sec_tech_1D.WACC)**sec_tech_1D.unit_investment_lifetime - 1)})

#nodes
# nodes_concat_balance_type = pd.DataFrame({"Object_class_names":"node", "Object names 1":sec_tech_1D.node_in, "Parameter names":"balance_type", "Alternative names":sec_tech_1D.alternative, "Parameter values":"balance_type_node"})
# nodes_demand = pd.DataFrame({"Object_class_names":"node", "Object names 1":sec_tech_1D.node_in, "Parameter names":"demand", "Alternative names":sec_tech_1D.alternative, "Parameter values":sec_tech_1D.capacity_in})

#2-Dimensional Importer Mappings
#h2_units_to_nodes
unit_to_node_capacity = pd.DataFrame({"Relationship class names":"unit__to_node", "Object_class_names":"unit", "Object class names 1":"node", "Object names 1":sec_tech_2D.unit, "Object names 2":sec_tech_2D.node_out, "Parameter names":"unit_capacity", "Alternative names":sec_tech_2D.alternative, "Parameter values":sec_tech_2D.capacity_in})
unit_from_node_capacity = pd.DataFrame({"Relationship class names":"unit__from_node", "Object_class_names":"unit", "Object class names 1":"node", "Object names 1":sec_tech_2D.unit, "Object names 2":sec_tech_2D.node_in, "Parameter names":"unit_capacity", "Alternative names":sec_tech_2D.alternative, "Parameter values":capacity_from})
unit_to_node_fuel_cost = pd.DataFrame({"Relationship class names":"unit__to_node", "Object_class_names":"unit", "Object class names 1":"node", "Object names 1":sec_tech_2D.unit, "Object names 2":sec_tech_2D.node_out, "Parameter names":"fuel_cost", "Alternative names":sec_tech_2D.alternative, "Parameter values":sec_tech_2D.fuel_cost})
unit_to_node_vom_cost = pd.DataFrame({"Relationship class names":"unit__to_node", "Object_class_names":"unit", "Object class names 1":"node", "Object names 1":sec_tech_2D.unit, "Object names 2":sec_tech_2D.node_out, "Parameter names":"vom_cost", "Alternative names":sec_tech_2D.alternative, "Parameter values":sec_tech_2D.vom_cost})

#3-Dimensional Importer Mappings
#h2_units_nodes_nodes
h2_unit__node_node_concat_fix_ratio_io = pd.DataFrame({"Relationship class names":"unit__node__node", "Object_class_names":"unit", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":sec_tech_3D.unit, "Object names 2":sec_tech_3D.node_in, "Object names 3":sec_tech_3D.node_out, "Parameter names":"fix_ratio_out_in_unit_flow", "Alternative names":sec_tech_3D.alternative, "Parameter values":sec_tech_3D.efficiency})

#%%
if desalination_var == 1:
    h2_units_concat_1D = pd.concat([h2_units_concat_annuity_factor, h2_units_concat_unit_investment_cost, h2_units_concat_fom_cost, h2_units_concat_unit_investment_lifetime_js, h2_units_concat_unit_investment_variable_type, h2_units_concat_candidate_units, h2_units_concat_initial_units_invested_available, h2_units_concat_number_of_units], ignore_index=True)
    #nodes_concat_1D = pd.concat([nodes_concat_balance_type, nodes_demand], ignore_index=True)
    h2_units_concat_2D = pd.concat([unit_to_node_capacity, unit_from_node_capacity, unit_to_node_fuel_cost, unit_to_node_vom_cost], ignore_index=True)
    h2_units_concat_2D = h2_units_concat_2D.drop_duplicates().reset_index(drop=True)
    h2_units_concat_3D = pd.concat([h2_unit__node_node_concat_fix_ratio_io], ignore_index=True)
else:
    h2_units_concat_1D = pd.concat([h2_units_concat_annuity_factor, h2_units_concat_unit_investment_cost, h2_units_concat_fom_cost, h2_units_concat_unit_investment_lifetime_js, h2_units_concat_unit_investment_variable_type, h2_units_concat_candidate_units, h2_units_concat_initial_units_invested_available, h2_units_concat_number_of_units], ignore_index=True) #deleted mention of h2_units_concat_fom_cost until https://github.com/spine-tools/SpineOpt.jl/issues/825 resolves
    #nodes_concat_1D = pd.concat([nodes_concat_balance_type, nodes_demand], ignore_index=True)
    h2_units_concat_2D = pd.concat([unit_to_node_capacity, unit_from_node_capacity, unit_to_node_fuel_cost, unit_to_node_vom_cost], ignore_index=True)
    h2_units_concat_2D = h2_units_concat_2D.drop(h2_units_concat_2D[h2_units_concat_2D["Object names 2"].str.contains("h2o")].index)
    h2_units_concat_2D = h2_units_concat_2D.drop_duplicates().reset_index(drop=True)
    h2_units_concat_3D = pd.concat([h2_unit__node_node_concat_fix_ratio_io], ignore_index=True)
    h2_units_concat_3D = h2_units_concat_3D.drop(h2_units_concat_3D[h2_units_concat_3D["Object names 2"].str.contains("h2o")].index)
    #deleting all rows with desalination in the name
    #h2_units_concat_1D = h2_units_concat_1D.drop(h2_units_concat_1D[h2_units_concat_1D['Object names 1'].str.contains('Desalination')])

print("Succesfully packaged the 1/2/3D dataframes" + "\n")

#rename columns
h2_units_concat_2D = h2_units_concat_2D.rename(columns={'Object class names 1':'Object class names 2', 'Object_class_names':'Object class names 1'})
h2_units_concat_3D = h2_units_concat_3D.rename(columns={'Object class names 2':'Object class names 3', 'Object class names 1':'Object class names 2', 'Object_class_names':'Object class names 1'})

#anpassen fuer Synchronitaet zw SO und BB
h2_units_concat_1D[h2_units_concat_1D['Parameter names'] == 'candidate_units'] = h2_units_concat_1D[h2_units_concat_1D['Parameter names'] == 'candidate_units'].assign(**{'Parameter values':float(m_conf.Value[m_conf["Parameter"] == "candidate_units"].values[0])})

#%%
########################### convert 2 BB ###########################

# prepare SO data
merge_unit__to_node                             = h2_units_concat_2D[
    (h2_units_concat_2D['Relationship class names'] == 'unit__to_node') & 
    (h2_units_concat_2D['Parameter names'] == 'unit_capacity')
    # (h2_units_concat_2D['Alternative names'] == default_alternative)
    ].reset_index(drop=True)[['Object names 1',	'Object names 2']].rename(columns={'Object names 1':'Object names 3'})
f_rat_base = h2_units_concat_3D[
    (h2_units_concat_3D['Parameter names'] == 'fix_ratio_out_in_unit_flow')
    # (h2_units_concat_3D['Alternative names'] == default_alternative)
    ].reset_index(drop=True)
f_rat_base['inputs']                            = f_rat_base.groupby(['Object names 1','Object names 3'])['Object names 1'].transform('count')
f_rat_base['outputs']                           = f_rat_base.groupby(['Object names 1','Object names 2'])['Object names 1'].transform('count')
f_rat_base['io_total_lines_for_gnu_io_in_BB']   = f_rat_base['inputs'] + f_rat_base['outputs']
# parameters
# %%
bb_dim_4_invCosts_o         = (h2_units_concat_1D[(h2_units_concat_1D['Parameter names'] == 'unit_investment_cost')]
 .rename(columns={'Object_class_names':'Object class names 3','Object names 1':'Object names 3'})
 .assign(**{
     'Relationship class names':'grid__node__unit__io',
     'Object class names 1':'grid',
     'Object class names 2':'node',
     'Object class names 4':'io',
     'Object names 1':'hier die grids aus to-2D Tabelle abfragen',
     'Object names 4':'output',
     'Parameter names':'invCosts'
     })
)
# %%
bb_dim_4_invCosts_o         = bb_dim_4_invCosts_o.merge(merge_unit__to_node,how='right',on='Object names 3') # get the corresponding node to each unit's output
#If there is a crash here, it is because of the hard coded Alternative name 'APS_2040' in the merge_unit__to_node dataframe 
bb_dim_4_invCosts_o         = bb_dim_4_invCosts_o.assign(**{
    'Object names 1': bb_dim_4_invCosts_o['Object names 2'].apply(
        lambda x: x.split('_')[-1] if isinstance(x, str) and '_' in x else x
    )
}) # generate commodity grids
bb_dim_4_invCosts_o         = bb_dim_4_invCosts_o[bb_dim_4_invCosts_o.columns[[5,6,7,0,8,9,11,1,10,2,3,4]]] # reorder columns
bb_dim_1_maxUnitCount       = (h2_units_concat_1D[h2_units_concat_1D['Parameter names'] == 'candidate_units']
                         .rename(columns={'Object_class_names':'Object class names','Object names 1':'Object names'})
                         .reset_index(drop=True)
                         .assign(**{'Parameter names':'maxUnitCount'}))
bb_dim_1_maxUnitCount       = bb_dim_1_maxUnitCount.assign(**{'Parameter values':'inf'})#float(m_conf.Value[m_conf["Parameter"] == "subunit_size"].values[0]) * float(m_conf.Value[m_conf["Parameter"] == "candidate_units"].values[0])}) ## ueberschreiben von Eingangswerten zu INF zum testen ## to do ## sollte sinnvoller konfigurierbar gemacht werden
bb_dim_4_capacity_o         = (bb_dim_4_invCosts_o.assign(**{'Parameter names':'capacity',
                                                    'Parameter values':h2_units_concat_1D[
                                                        (h2_units_concat_1D['Object_class_names'] == 'unit') & 
                                                        (h2_units_concat_1D['Parameter names'] == 'initial_units_invested_available')]
                                                        .reset_index(drop=True)
                                                        ['Parameter values']}))
bb_dim_4_capacity_o[bb_dim_4_capacity_o['Parameter values'] == 0] = bb_dim_4_capacity_o[bb_dim_4_capacity_o['Parameter values'] == 0].assign(**{'Parameter values':eps})
bb_dim_4_unitSize           = bb_dim_4_capacity_o.assign(**{'Parameter names':'unitSize',
                                                            'Parameter values':1})
df_io                       = f_rat_base[['Object names 1','inputs','outputs','io_total_lines_for_gnu_io_in_BB']].drop_duplicates().reset_index(drop=True)
df_gnuio                    = pd.DataFrame(columns=['Relationship class names','Object class names 1','Object class names 2','Object class names 3','Object class names 4','Object names 1','Object names 2','Object names 3','Object names 4','Parameter names','Alternative names','Parameter values'])
for unit in f_rat_base['Object names 1'].unique():
    df_gnuio = pd.concat([df_gnuio,
                          pd.DataFrame({
                              'Object names 3':[unit]*df_io[df_io['Object names 1'] == unit].loc[:,'inputs'].values[0],
                              'Object names 4':'input'})
                              .assign(**{'Object names 2':f_rat_base[f_rat_base['Object names 1'] == unit]['Object names 2'].reset_index(drop=True),
                                         'Parameter values':f_rat_base[f_rat_base['Object names 1'] == unit]['Parameter values'].reset_index(drop=True)})
                        ], ignore_index=True)
    df_gnuio = pd.concat([df_gnuio,
                          pd.DataFrame({
                              'Object names 3':[unit]*df_io[df_io['Object names 1'] == unit].loc[:,'outputs'].values[0],
                              'Object names 4':'output'})
                              .assign(**{'Object names 2':f_rat_base[f_rat_base['Object names 1'] == unit]['Object names 3'].reset_index(drop=True),
                                         'Parameter values':1}) #hier muss man nochmal drueber schauen wenn tatsaechlich mehrere Outputs definiert werden... aktuell sind alle Inputs als Vielfache zu einer (1) Einheit Output definiert
                        ], ignore_index=True)
df_gnuio                    = df_gnuio.assign(**{
    'Relationship class names':'grid__node__unit__io',
    'Object class names 1':'grid',
    'Object class names 2':'node',
    'Object class names 3':'unit',
    'Object class names 4':'io',
    'Parameter names':'TEMP',
    'Alternative names':default_alternative}
    ).assign(**{'Object names 1': df_gnuio['Object names 2'].apply(lambda x: x.split("_")[-1] if isinstance(x, str) else x)})
df_gnuio["Object names 1"] = df_gnuio["Object names 1"].str.replace("el","elec",regex=False) # replace el with elec in Object names 1

#%%
df_unitConstraintNode       = pd.DataFrame(
    columns=list(df_gnuio.columns[i] for i in [0,1,2,3,5,6,7,9,10,11]), 
    data={'Object names 1':[val for val in list(df_io[df_io['inputs'] == 2].reset_index(drop=True)['Object names 1']) for _ in (0, 1)]}
    ).assign(**{
            'Relationship class names':'unit__constraint__node',
            'Object class names 1':'unit',
            'Object class names 2':'constraint',
            'Object class names 3':'node',
            'Object names 2':'eq1',
            'Object names 3':'nodeXXX',
            'Parameter names':'coefficient',
            'Alternative names':default_alternative,
            'Parameter values':'valueXXX'})
eq1_list                    = pd.Series(df_gnuio[
    (df_gnuio['Object names 4'] == 'input') & 
    (df_gnuio['Object names 3'].isin(df_unitConstraintNode['Object names 1']))]
    ['Parameter values']).reset_index(drop=True)
bb_dim_4_conversionCoeff    = df_gnuio.assign(**{'Parameter names':'conversionCoeff'}) #configure conversionCoeff to zero for byproduct flows which should not show up in equilibrium equation, configure to efficiency for main product
bb_dim_4_conversionCoeff[(bb_dim_4_conversionCoeff['Object names 3'].astype(str).str.split('_',expand=True,n=1)[0] == 'desalination') & (bb_dim_4_conversionCoeff['Object names 4'] == 'input') & (bb_dim_4_conversionCoeff['Object names 1'] == 'elec')] = bb_dim_4_conversionCoeff[(bb_dim_4_conversionCoeff['Object names 3'].astype(str).str.split('_',expand=True,n=1)[0] == 'desalination') & (bb_dim_4_conversionCoeff['Object names 4'] == 'input') & (bb_dim_4_conversionCoeff['Object names 1'] == 'elec')].assign(**{'Parameter values':eps})
bb_dim_4_conversionCoeff[(bb_dim_4_conversionCoeff['Object names 3'].astype(str).str.split('_',expand=True,n=1)[0] == 'electrolyzer') & (bb_dim_4_conversionCoeff['Object names 4'] == 'input') & (bb_dim_4_conversionCoeff['Object names 1'] == 'h2o')] = bb_dim_4_conversionCoeff[(bb_dim_4_conversionCoeff['Object names 3'].astype(str).str.split('_',expand=True,n=1)[0] == 'electrolyzer') & (bb_dim_4_conversionCoeff['Object names 4'] == 'input') & (bb_dim_4_conversionCoeff['Object names 1'] == 'h2o')].assign(**{'Parameter values':eps})
eq1_list[1::2]              = [i * (-1) for i in eq1_list[1::2]]
bb_dim_3_unitConstraintNode = df_unitConstraintNode.assign(**{
    'Object names 3':   df_gnuio[(df_gnuio['Object names 4'] == 'input') & (df_gnuio['Object names 3'].isin(df_unitConstraintNode['Object names 1']))]['Object names 2'].reset_index(drop=True), 
    'Parameter values': eq1_list})
bb_dim_3_unitConstraintNode
# %%
bb_dim_1_eff00              = pd.DataFrame({'Object class names':'unit',
                               'Object names':df_gnuio['Object names 3'].unique(),
                               'Parameter names':'eff00',
                               'Alternative names':default_alternative,
                               'Parameter values':1})
bb_dim_1_availability       = bb_dim_1_eff00.assign(**{'Parameter names':'availability'})
bb_dim_1_investMIP          = bb_dim_1_eff00.assign(**{'Parameter names':'investMIP',
                                              'Parameter values':0})
bb_dim_3_effLevelGroupUnit  = pd.DataFrame(
    index=range(len(bb_dim_1_eff00)*3), 
    columns=bb_dim_3_unitConstraintNode.columns).assign(**{
        'Relationship class names':'effLevel__effSelector__unit',
        'Object class names 1':'effLevel',
        'Object class names 2':'effSelector',
        'Object class names 3':'unit',
        'Object names 1':['level1','level2','level3']*len(bb_dim_1_eff00),
        'Object names 2':'directOff',
        'Object names 3':(pd.concat([bb_dim_1_eff00['Object names']]*3,ignore_index=True)).sort_values(ignore_index=True)})
bb_dim_2_nodeBalance        = pd.DataFrame({'Relationship class names':'grid__node',
                                     'Object class names 1':'grid',
                                     'Object class names 2':'node',
                                     'Object names 1':bb_dim_4_conversionCoeff[['Object names 1','Object names 2']].drop_duplicates().reset_index(drop=True)['Object names 1'],
                                     'Object names 2':bb_dim_4_conversionCoeff[['Object names 1','Object names 2']].drop_duplicates().reset_index(drop=True)['Object names 2'],
                                     'Parameter names':'nodeBalance',
                                     'Alternative names':default_alternative,
                                     'Parameter values':1})
bb_dim_2_nodeBalance[bb_dim_2_nodeBalance['Object names 1'] == 'h2o'] = bb_dim_2_nodeBalance[bb_dim_2_nodeBalance['Object names 1'] == 'h2o'].assign(**{'Parameter values':0}) #hier koennte man ansetzen und spaeter eventuell aus Rohwasser als unbegrenzte Commodity stattdessen ein regional spezifisches max. Volumen angeben... elec und h2 nodes gibts schon... ueberschreiben muesste trotzdem gehen
bb_dim_2_usePrice           = bb_dim_2_nodeBalance.assign(**{
    'Parameter names':'usePrice',
    'Parameter values':0})
bb_dim_2_usePrice[bb_dim_2_usePrice['Object names 1'] == 'h2o'] = bb_dim_2_usePrice[bb_dim_2_usePrice['Object names 1'] == 'h2o'].assign(**{'Parameter values':1}) # Rohwasser als Commodity ohne nodeBalance, mit Preis (=0 atm)
bb_dim_2_energyStored = bb_dim_2_nodeBalance[bb_dim_2_nodeBalance['Object names 1'].isin(['h2o','h2o_raw'])].assign(**{'Parameter names':'energyStoredPerUnitOfState',
                                                                                                                       'Parameter values':0}).reset_index(drop=True)
bb_dim_4_vomCosts           = bb_dim_4_invCosts_o.assign(**{'Parameter names':'vomCosts'}).drop('Parameter values',axis=1)
bb_dim_4_vomCosts[['Object names 2','Object names 3','Alternative names','Parameter values']] = bb_dim_4_vomCosts[['Object names 2','Object names 3','Alternative names']].merge(h2_units_concat_2D[(h2_units_concat_2D['Object class names 1'] == 'unit') & (h2_units_concat_2D['Parameter names'] == 'vom_cost')].reset_index(drop=True).rename(columns={'Object names 1':'Object names 3'})[['Object names 2','Object names 3','Alternative names','Parameter values']])
#Get real annuity factors from h2_uni_concat dataframe
bb_dim_4_annuityFactor = pd.DataFrame({'Relationship class names':"grid__node__unit__io",
                                        'Object class names 1':'grid',
                                        'Object class names 2':'node',
                                        'Object class names 3':'unit',
                                        'Object class names 4':'io',
                                        'Object names 1':bb_dim_4_vomCosts["Object names 1"],
                                        'Object names 2':bb_dim_4_vomCosts["Object names 2"],
                                        'Object names 3':bb_dim_4_vomCosts["Object names 3"],
                                        'Object names 4':'output',
                                        'Parameter names':'annuityFactor',
                                        'Alternative names':default_alternative}).reset_index(drop=True)

#The values from h2_units_concat_1D where the Object names 1 are the same as the Object names 3 in bb_dim_4_vomCosts and the Parameter names are annuityFactor
bb_dim_4_annuityFactor['Parameter values'] = h2_units_concat_1D[h2_units_concat_1D["Parameter names"] == "annuityFactor"]["Parameter values"].reset_index(drop=True) #Zuordnung frawürdig da hier die Gleichheit der Liste ausgenutzt wird, aber keine individuelle Zuordnung stattfindet
#%%

bb_dim_4_fom_costs = pd.DataFrame({'Relationship class names':"grid__node__unit__io",
                                        'Object class names 1':'grid',
                                        'Object class names 2':'node',
                                        'Object class names 3':'unit',
                                        'Object class names 4':'io',
                                        'Object names 1':bb_dim_4_vomCosts["Object names 1"],
                                        'Object names 2':bb_dim_4_vomCosts["Object names 2"],
                                        'Object names 3':bb_dim_4_vomCosts["Object names 3"],
                                        'Object names 4':'output',
                                        'Parameter names':'fomCosts',
                                        'Alternative names':default_alternative}).reset_index(drop=True)
                                        
bb_dim_4_fom_costs['Parameter values'] = h2_units_concat_1D[h2_units_concat_1D["Parameter names"] == "fom_cost"]["Parameter values"].reset_index(drop=True) #Zuordnung frawürdig da hier die Gleichheit der Liste ausgenutzt wird, aber keine individuelle Zuordnung stattfindet
bb_dim_4_fom_costs = bb_dim_4_fom_costs.drop_duplicates().reset_index(drop=True)
#drop empty values
bb_dim_4_fom_costs = bb_dim_4_fom_costs[bb_dim_4_fom_costs['Parameter values'] != 0]
#%%

#utAvailabilityLimits -> becomeAvailable
bb_dim_2_map_utAvailabilityLimits = pd.DataFrame(dict(zip(['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values'], ['unit','unitXXX','becomeAvailable','Base','t000001',1])), index=range(len(df_gnuio['Object names 3'].unique()))).assign(**{'Object names':df_gnuio['Object names 3'].unique()})
bb_dim_2_map_ts_PriceChange         = pd.DataFrame(dict(zip(['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values'], ['node','commoditynodeXXX','priceChange','Base','t000000','fuelPricesXXX'])), index=range(len(bb_dim_2_usePrice[bb_dim_2_usePrice['Object names 1'] == 'h2o'].reset_index(drop=True)))).assign(**{'Object names':bb_dim_2_usePrice[bb_dim_2_usePrice['Object names 1'] == 'h2o'].reset_index(drop=True)['Object names 2'],'Parameter values':water_price}) #or eps, not sure

#availabilityCapacityMargin for q_capacityMargin's capacityMargin in the h2 grid ## this will force a deterministic electrolyzer overcapacity invest introducing a basic concept of resilience (sampled invest system adequecy for scheduling/short term pricing run)
bb_dim_4_availabilityCapacityMargin = bb_dim_4_annuityFactor[bb_dim_4_annuityFactor['Object names 3'].str.contains('electrolyzer', case=False)].assign(**{'Parameter names':'availabilityCapacityMargin', 'Parameter values':1})

##################################
## concat
h2_units_concat_1D_BB = pd.concat([bb_dim_1_eff00,bb_dim_1_availability,bb_dim_1_investMIP,bb_dim_1_maxUnitCount],ignore_index=True)
h2_units_concat_2D_BB = pd.concat([bb_dim_2_nodeBalance,bb_dim_2_usePrice,bb_dim_2_energyStored],ignore_index=True)
bb_dim_2_relationship_dtype_map = pd.concat([bb_dim_2_map_utAvailabilityLimits,bb_dim_2_map_ts_PriceChange],ignore_index=True)
h2_units_concat_3D_BB = pd.concat([bb_dim_3_unitConstraintNode,bb_dim_3_effLevelGroupUnit],ignore_index=True)
h2_units_concat_4D_BB = pd.concat([bb_dim_4_annuityFactor,bb_dim_4_fom_costs, bb_dim_4_vomCosts, bb_dim_4_capacity_o,bb_dim_4_conversionCoeff,bb_dim_4_unitSize,bb_dim_4_invCosts_o, bb_dim_4_availabilityCapacityMargin],ignore_index=True) #del vomCosts
h2_units_concat_4D_BB = h2_units_concat_4D_BB.assign(**{'Object names 1':h2_units_concat_4D_BB['Object names 1'].replace(to_replace='el',value='elec'),'Object names 2':h2_units_concat_4D_BB['Object names 2']}) #.astype(str).str.removesuffix('_el')



####################################################################

## convert SO data to existing convention (country node = electricity demand node)
h2_units_concat_2D[h2_units_concat_2D['Object class names 2'] == 'node'] = (h2_units_concat_2D
                                                                            [h2_units_concat_2D['Object class names 2'] == 'node']
                                                                            .assign(**{'Object names 2':h2_units_concat_2D['Object names 2']
                                                                                       .astype(str)
                                                                                       .str
                                                                                       .removesuffix('_el')}))
h2_units_concat_3D[h2_units_concat_3D['Object class names 2'] == 'node'] = (h2_units_concat_3D
                                                                            [h2_units_concat_3D['Object class names 2'] == 'node']
                                                                            .assign(**{'Object names 2':h2_units_concat_3D['Object names 2']
                                                                                       .astype(str)
                                                                                       .str
                                                                                       .removesuffix('_el')}))
h2_units_concat_3D[h2_units_concat_3D['Object class names 3'] == 'node'] = (h2_units_concat_3D
                                                                            [h2_units_concat_3D['Object class names 3'] == 'node']
                                                                            .assign(**{'Object names 3':h2_units_concat_3D['Object names 3']
                                                                                       .astype(str)
                                                                                       .str
                                                                                       .removesuffix('_el')}))

#balance type was not included in SO data ################################################ major rework has to be done this is not working in SpineOpt as intended ########################################################################
spineOpt_balancetype_1d = bb_dim_2_nodeBalance[['Object class names 2','Object names 2','Parameter names','Alternative names','Parameter values']].assign(**{'Parameter names':'balance_type'}).rename(columns={'Object class names 2':'Object_class_names','Object names 2':'Object names 1'}).replace(to_replace=[1,0], value=['balance_type_node','balance_type_none'])
h2_units_concat_1D = pd.concat([h2_units_concat_1D, spineOpt_balancetype_1d],ignore_index=True)
h2_unit__node_node_concat_fix_ratio_io = h2_unit__node_node_concat_fix_ratio_io.assign(**{'Object names 2':h2_unit__node_node_concat_fix_ratio_io['Object names 3'], 'Object names 3':h2_unit__node_node_concat_fix_ratio_io['Object names 2'], 'Parameter names':'fix_ratio_in_out_unit_flow'})
h2_units_concat_3D = pd.concat([h2_unit__node_node_concat_fix_ratio_io], ignore_index=True) # currently inverse relation between incoming and outgoing flow 100 percent wrong, dont know how to fix atm lol
h2_units_concat_2D = pd.concat([unit_to_node_capacity, unit_from_node_capacity, unit_to_node_fuel_cost], ignore_index=True)
h2_units_concat_2D[h2_units_concat_2D['Parameter names'] == 'unit_capacity'] = h2_units_concat_2D[h2_units_concat_2D['Parameter names'] == 'unit_capacity'].assign(**{'Parameter values':1000})
h2_units_concat_2D = h2_units_concat_2D.drop_duplicates().reset_index(drop=True)

#################################################################### naming convention ####################################################################
rename_technologies = [['h2_ocgt_','h2|OCGT|'],['fuel_cell_','h2|FuelCell|'],['electrolyzer_','el|Electrolyzer|'],['desalination_','h2o_raw|Desalination|'], ["h2_engine_", "h2|Engine|"]]
rename_unit_outputs = [['Desalination',''], ['H2',''], ['Electrolyzer','']]

## rename technologies
for df in [h2_units_concat_1D_BB, bb_dim_2_relationship_dtype_map]:
    for tech in rename_technologies:
        df['Object names'] = df['Object names'].str.replace(tech[0],tech[1])
for column in ['Object names 1','Object names 2','Object names 3']:
    for tech in rename_technologies:
        h2_units_concat_3D_BB[column] = h2_units_concat_3D_BB[column].str.replace(tech[0],tech[1])
for column in ['Object names 2','Object names 3']:
    for tech in rename_technologies:
        h2_units_concat_4D_BB[column] = h2_units_concat_4D_BB[column].str.replace(tech[0],tech[1])
## rename unit outputs and _el-Nodes
# naming convention 1D
for tech_output in rename_unit_outputs:
    h2_units_concat_1D_BB.loc[
        h2_units_concat_1D_BB['Object names'].str.split('|', expand=True)[0] == tech_output[0],
        'Object names'] += tech_output[1]
# # naming convention 2D
# h2_units_concat_2D_BB.loc[
#     (h2_units_concat_2D_BB['Object class names 2'] == 'node') & 
#     (h2_units_concat_2D_BB['Object names 1'] == 'elec'),
#     'Object names 2'] += '_el'
# naming convention 2D map
for tech_output in rename_unit_outputs:
    bb_dim_2_relationship_dtype_map.loc[
        (bb_dim_2_relationship_dtype_map['Object class names'] == 'unit') &
        (bb_dim_2_relationship_dtype_map['Object names'].str.split('|', expand=True)[0] == tech_output[0]),
        'Object names'] += tech_output[1]
# naming convention 3D
# h2_units_concat_3D_BB.loc[(h2_units_concat_3D_BB['Object class names 3'] == 'node') &
#                           (~h2_units_concat_3D_BB['Object names 3'].str.contains('_')), 
#                           'Object names 3'] += '_el'
for class_value in [['Object class names 1', 'Object names 1'], ['Object class names 3','Object names 3']]:
    for tech_output in rename_unit_outputs:
        h2_units_concat_3D_BB.loc[
            (h2_units_concat_3D_BB[class_value[0]] == 'unit') &
            (h2_units_concat_3D_BB[class_value[1]].str.split('|', expand=True)[0] == tech_output[0]),
            class_value[1]] += tech_output[1]
# naming  convention 4D
h2_units_concat_4D_BB.loc[
    (h2_units_concat_4D_BB['Relationship class names'] == 'grid__node__unit__io') &
    (~h2_units_concat_4D_BB['Object names 2'].str.contains('_')),
    'Object names 2'] += '_el'
for class_value in [['Object class names 3','Object names 3']]:
    for tech_output in rename_unit_outputs:
        h2_units_concat_4D_BB.loc[
            (h2_units_concat_4D_BB[class_value[0]] == 'unit') &
            (h2_units_concat_4D_BB[class_value[1]].str.split('|', expand=True)[0] == tech_output[0]),
            class_value[1]] += tech_output[1]
#######################################################################

#### Adding the constraints for the Delegated Act for RFNBOs ####

if RFNBO_option == "Vanilla":
    print("Base model without any RFNBO modifications" + "\n")

if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #reassining electricity nodes to the renewable electricity nodes in 2D
    h2_units_concat_2D_BB["Object names 2"] = h2_units_concat_2D_BB["Object names 2"].str.replace('_el','_re_el')

    #reassining electricity nodes to the renewable electricity nodes in 3D
    h2_units_concat_3D_BB["Object names 3"] = h2_units_concat_3D_BB["Object names 3"].str.replace('_el','_re_el')

    #reassining electricity nodes to the renewable electricity nodes in 4D
    h2_units_concat_4D_BB["Object names 2"] = h2_units_concat_4D_BB["Object names 2"].str.replace('_el','_re_el')

if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"

    #reassining electricity nodes to the renewable electricity nodes in 2D
    h2_units_concat_2D_BB["Object names 2"] = h2_units_concat_2D_BB["Object names 2"].str.replace('_el','_re_el')

    #reassining electricity nodes to the renewable electricity nodes in 3D
    h2_units_concat_3D_BB["Object names 3"] = h2_units_concat_3D_BB["Object names 3"].str.replace('_el','_re_el')

    #reassining electricity nodes to the renewable electricity nodes in 4D
    h2_units_concat_4D_BB["Object names 2"] = h2_units_concat_4D_BB["Object names 2"].str.replace('_el','_re_el')

#The Defossilized Grid option conducts a pre-solve without any hydrogen demand to determine the CO2 intensity of the system to then asses, whether the RFNBO production may use the grid electricity.
if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid_prerun"
    reg_ex_hydrogen = 'h2|H2|Terminal|Electrolyzer|h2o'
    h2_units_concat_1D_BB = h2_units_concat_1D_BB[~h2_units_concat_1D_BB['Object names'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    h2_units_concat_2D_BB = h2_units_concat_2D_BB[~h2_units_concat_2D_BB['Object names 1'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_dim_2_relationship_dtype_map = bb_dim_2_relationship_dtype_map[~bb_dim_2_relationship_dtype_map['Object names'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    h2_units_concat_3D_BB = h2_units_concat_3D_BB[~h2_units_concat_3D_BB['Object names 1'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    h2_units_concat_3D_BB = h2_units_concat_3D_BB[~h2_units_concat_3D_BB['Object names 3'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    h2_units_concat_4D_BB = h2_units_concat_4D_BB[~h2_units_concat_4D_BB['Object names 3'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)

if RFNBO_option == "Defossilized_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid"

if RFNBO_option == "Add_and_Corr":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Additionality and Correlation ###
    alt_rfnbo = "Additionality_and_Correlation"

if RFNBO_option == "All_at_once":
    print("Applying all regulations for RFNBOs" + "\n")
    ### All at once ###
    alt_rfnbo = "All_at_once"

#######################################################################

# #### quick fix Electrolizer input
# idx_electroliz_invCosts = (h2_units_concat_4D_BB['Parameter names'].isin(['invCosts','annuityFactor','capacity','fomCosts','vomCosts','unitSize'])) & (h2_units_concat_4D_BB['Object names 3'].str.contains('Electrolyzer'))
# h2_units_concat_4D_BB.loc[idx_electroliz_invCosts ,'Object names 4'] = 'input'
# h2_units_concat_4D_BB.loc[idx_electroliz_invCosts ,'Object names 1'] = 'elec'
# h2_units_concat_4D_BB.loc[idx_electroliz_invCosts ,'Object names 2'] = h2_units_concat_4D_BB.loc[idx_electroliz_invCosts ,'Object names 2'].str.replace('_h2','_el')

#%%

# create a excel writer object and export the preprocessed sector coupling data
with pd.ExcelWriter(os.path.join(outputfile)) as writer:

    h2_units_concat_1D.to_excel(writer, sheet_name="sector_coupling_1D", index=False)
    h2_units_concat_2D.to_excel(writer, sheet_name="sector_coupling_2D", index=False)
    h2_units_concat_3D.to_excel(writer, sheet_name="sector_coupling_3D", index=False)

print("Succesfully exported Spines " + outputfile + "\n")

with pd.ExcelWriter(os.path.join(outputfile_BB)) as writer:

    h2_units_concat_1D_BB.to_excel(writer, sheet_name="sector_coupling_1D", index=False)
    h2_units_concat_2D_BB.to_excel(writer, sheet_name="sector_coupling_2D", index=False)
    bb_dim_2_relationship_dtype_map.to_excel(writer, sheet_name="sector_coupling_2D_map", index=False)
    h2_units_concat_3D_BB.to_excel(writer, sheet_name="sector_coupling_3D", index=False)
    h2_units_concat_4D_BB.to_excel(writer, sheet_name="sector_coupling_4D", index=False)

print("Succesfully exported Backbones " + outputfile_BB + "\n")

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')  
#%%