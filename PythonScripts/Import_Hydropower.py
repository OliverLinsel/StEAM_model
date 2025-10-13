"""
aggregate hydropower data script

Created on 2023-02-22 // considering splitting up RES + ROR Hydropower ## to do ##
@author KT
reworked on 2023-05-16 KT
reworked on 2023-10-25 KT

"""
# %%
#import modules
import sys
import pandas as pd
import numpy as np
from shutil import copyfile
from datetime import datetime,timedelta
import glob
import os
from math import nan
import re
import time

################# Options ################################################################

print("Start converting Hydropower data" + "\n")

print('Execute in Directory:')
print(os.getcwd())

try:        # use if run in spine-toolbox
    excel_path_GLOBIOM          = sys.argv[1]
    excel_path_WORLD            = sys.argv[2]
    csv_path_hydro_profiles     = sys.argv[3]
    csv_path_JRC_hydro          = sys.argv[4]
    path_MainInput              = sys.argv[5]
    outputfile                  = "TEMP\Hydropower.xlsx"
    outputfile_BB               = "TEMP\Hydropower_BB.xlsx"
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    excel_path_GLOBIOM          = r"Data\Plexos\MESSAGEix-GLOBIOM\PLEXOS-World model MESSAGEix - GLOBIOM Soft-Link.xlsx"
    excel_path_WORLD            = r"Data\Plexos\PLEXOS World\PLEXOS-World 2015 Gold V1.1.xlsx"
    csv_path_hydro_profiles     = r"Data\Plexos\PLEXOS World\Hydro_Monthly_Profiles (2015).csv"
    csv_path_JRC_hydro          = r"Data\JRC_Hydro_Power\jrc-hydro-power-plant-database.csv"
    path_MainInput              = r"PythonScripts\TEMP\MainInput.xlsx"
    outputfile                  = r"PythonScripts\TEMP\Hydropower.xlsx"
    outputfile_BB               = r"PythonScripts\TEMP\Hydropower_BB.xlsx"

################# Options End ############################################################

START = time.perf_counter() 

################# Read Data ##############################################################

objects_WORLD                           = pd.read_excel(excel_path_WORLD, sheet_name="Objects")         # XX-XXX-XX ONLY -> concatinated subset works fine
properties_WORLD                        = pd.read_excel(excel_path_WORLD, sheet_name="Properties")      # XX-XXX-XX ONLY -> concatinated subset works fine
memberships_WORLD                       = pd.read_excel(excel_path_WORLD, sheet_name="Memberships")     # XX-XXX-XX ONLY -> concatinated subset works fine
memberships_GLOBIOM                     = pd.read_excel(excel_path_GLOBIOM, sheet_name="Memberships")   # XX-XXX-XX ONLY -> concatinated subset works fine
hydro_monthly_profiles_2015_WORLD       = pd.read_csv(csv_path_hydro_profiles, encoding='unicode_escape')   # XXX ONLY -> concatinated subset works fine
eu_hydro_database_JRC                   = pd.read_csv(csv_path_JRC_hydro, encoding='unicode_escape')
list_subset_countries 					= pd.read_excel(path_MainInput, sheet_name="subset_countries")#.Countries.to_list()
region_selection                        = pd.Series(['Africa', 'Asia', 'Europe', 'Oceania', 'North America','South America'])  #all 6 selected atm, no impact on performance, can stay enabled independently
m_conf                                  = pd.read_excel(path_MainInput, sheet_name="model_config")
# %%
################# Read Data End ##########################################################

##prepare subset countries
list_subset_countries['Countries_short']        = list_subset_countries['Countries'].str.split('-',n =1).str[1] 
alle_nodes_PLEXOS                               = pd.Series(memberships_GLOBIOM['child_object'][memberships_GLOBIOM['child_class'] == 'Node'].unique())
list_subset_countries['Countries in PLEXOS?']   = list_subset_countries['Countries'].isin(set(alle_nodes_PLEXOS))
fehlende_nodes_PLEXOS                           = alle_nodes_PLEXOS[alle_nodes_PLEXOS.str.startswith(tuple(list_subset_countries[list_subset_countries['Countries in PLEXOS?'] == 0]['Countries'].values)) == 1].reset_index(drop=True)
list_subset_countries                           = pd.concat([list_subset_countries[['Countries', 'Regions']], pd.DataFrame({'Countries':fehlende_nodes_PLEXOS.str.rsplit('-',n=1).str[0]}).merge(list_subset_countries[['Countries','Regions']]).assign(**{'Countries':fehlende_nodes_PLEXOS})],ignore_index=True)
# %%

################## Read Data End ##########################################################

eps = float(0.0001)
eps = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value
#read availabilityCapacityMargin
availabilityCapacityMargin_config              = m_conf.loc[m_conf['Parameter'] == "availabilityCapacityMargin", "Value"].values[0] # capacityMargin read value

#assign capacity profile data to country nodes
monate                      = ["2015-01-01T00:00:00","2015-02-01T00:00:00","2015-03-01T00:00:00", "2015-04-01T00:00:00", "2015-05-01T00:00:00", "2015-06-01T00:00:00", "2015-07-01T00:00:00", "2015-08-01T00:00:00", "2015-09-01T00:00:00", "2015-10-01T00:00:00", "2015-11-01T00:00:00", "2015-12-01T00:00:00"]
df_hydro_profiles           = hydro_monthly_profiles_2015_WORLD.rename(columns={"M1":monate[0], "M2":monate[1], "M3":monate[2], "M4":monate[3], "M5":monate[4], "M6":monate[5], "M7":monate[6], "M8":monate[7], "M9":monate[8], "M10":monate[9], "M11":monate[10], "M12":monate[11]})
df_hydro_profiles[monate]   = df_hydro_profiles[monate] / 100
hydro_list_SA_World         = memberships_WORLD["parent_object"][memberships_WORLD["child_object"].isin(region_selection + '_Hyd')].reset_index(drop=True)
df_hydro_profiles           = df_hydro_profiles[df_hydro_profiles["NAME"].isin(hydro_list_SA_World)].reset_index(drop=True) #show only profiles relating to PLEXOS nodes (not limiting atm, all regions are selected)
powerplant_to_node = memberships_WORLD[["child_object", "parent_object"]][(memberships_WORLD["child_class"] == "Node")]
powerplant_to_node = powerplant_to_node.rename(columns={'child_object':'SA-Node', 'parent_object':'NAME'})
df_hydro_profiles = df_hydro_profiles.merge(powerplant_to_node, how='left', on='NAME')
#assign powerplant data to capacity profiles
hydro_properties_SA_World   = properties_WORLD[["child_object", "property", "value"]][(properties_WORLD["child_object"].isin(hydro_list_SA_World)) & (properties_WORLD["property"].isin(["Units", "Max Capacity"])) & (properties_WORLD["scenario"] != "{Object}Exclude 2016-2019 Generators")].reset_index(drop=True)
unit_capacity               = hydro_properties_SA_World[hydro_properties_SA_World["property"] == "Max Capacity"].reset_index(drop=True)
number_of_units             = hydro_properties_SA_World[hydro_properties_SA_World["property"] == "Units"].reset_index(drop=True)
powerplant_capacity         = number_of_units.drop(columns="property")
powerplant_capacity.value   = number_of_units.value * unit_capacity.value
powerplant_capacity         = powerplant_capacity.rename(columns={'child_object':'NAME', 'value':'powerplant_capacity'})
df_hydro_profiles           = df_hydro_profiles.merge(
    powerplant_capacity,
    how='left',
    on='NAME')
df_hydro_agg                = df_hydro_profiles.groupby(
    ['SA-Node']).agg(
        {'powerplant_capacity':'sum'}).reset_index().rename(columns={'powerplant_capacity':'cumulated_capacity'})
df_hydro_profiles           = df_hydro_profiles.merge(
    df_hydro_agg,
    how='left',
    on='SA-Node')
#weigh capacity profiles according to power share for each Node
df_hydro_profiles['rel_share_of_capacity_from_node'] = df_hydro_profiles['powerplant_capacity']/df_hydro_profiles['cumulated_capacity']
df_hydro_profiles[monate] = pd.DataFrame(
    np.array(df_hydro_profiles[monate].T) *                         #matrix of 12x7266 entries for hydro profiles
    np.array(df_hydro_profiles['rel_share_of_capacity_from_node'])  #vector of 1x7266 entries for specific weight
    ).T.rename(columns=dict(zip(list(range(len(monate))), monate))) #weigh capacity factor profile for each powerplant according to share of total nodal capacity for (following) aggregation sum
df_hydro_profiles = df_hydro_profiles.groupby(['SA-Node', 'cumulated_capacity']).agg(dict(zip(monate, len(monate)*['sum']))).reset_index()
#cumulate data from powerplant specific to node specific format
#nodes_list_SA_World         = objects_WORLD["name"][(objects_WORLD["class"] == "Node") & (objects_WORLD["category"].isin(region_selection))].reset_index(drop=True) #uncomment (and use:)) if you want to initialize Hydro Units for each Node available in PLEXOS data (even if there is no matching generation profile)
df_hydro_profiles['unit_discharge']             = "Hydro|" + df_hydro_profiles['SA-Node']
fuel_node_list              = memberships_GLOBIOM[["parent_object", "child_object"]][(memberships_GLOBIOM["parent_class"] == "Generator") & (memberships_GLOBIOM["child_class"] == "Fuel") & (memberships_GLOBIOM["parent_object"].isin("Hydro|" + df_hydro_profiles['SA-Node']))].reset_index(drop=True)
df_hydro_profiles = df_hydro_profiles.merge(fuel_node_list.rename(columns={'parent_object':'unit_discharge', 'child_object':'fuel_node'}), how='left', on='unit_discharge')
#some profiles are missing from PLEXOS GLOBIOM dataset
print('missing (PLEXOS GLOBIOM) Nodes for following (PLEXOS WORLD) entries: ' + str(df_hydro_profiles[df_hydro_profiles["fuel_node"].apply(type).isin([float])]["SA-Node"].to_list()))
print('total missing capacity: ' + str(sum(df_hydro_profiles[df_hydro_profiles["fuel_node"].apply(type).isin([float])]["cumulated_capacity"])) + ' MW ')
df_hydro_profiles = df_hydro_profiles.drop(list(df_hydro_profiles[df_hydro_profiles["fuel_node"].apply(type).isin([float])].index.values)).reset_index(drop=True) #drop entry if data from WORLD (profiles) is not available in data from GLOBIOM (fuel_nodes)
#use (relative) capacity factors for (absolute) inflow in MWh
df_hydro_profiles[monate] = pd.DataFrame(
    np.array(df_hydro_profiles[monate].T) * -1 *                    #matrix of 12x7266 entries for hydro profiles
    np.array(df_hydro_profiles['cumulated_capacity'])               #vector of 1x7266 entries for specific weight
    ).T.rename(columns=dict(zip(list(range(len(monate))), monate))) #weigh capacity factor profile for each powerplant according to share of total nodal capacity for (following) aggregation sum
# Create a new DataFrame with the JSON data (good shit, thanks ChatGPT!)
#derive average storage capacity factor (based on EU hydropower JRC data)
df_ROR_DAM_data = eu_hydro_database_JRC[["installed_capacity_MW", "type", "storage_capacity_MWh", "avg_annual_generation_GWh"]][(eu_hydro_database_JRC["type"] != "HPHS") & (eu_hydro_database_JRC["avg_annual_generation_GWh"].isna() == False) & (eu_hydro_database_JRC["storage_capacity_MWh"].isna() == False)].reset_index(drop=True) #only list ROR and DAM hydropower with available storage data
columns         = ["share_of_cap", "storage_d_Pmax", "weighted_share_storage_d_Pmax"]
for i in columns:
    if df_ROR_DAM_data.columns.isin([i]).any() == False:
        df_ROR_DAM_data.insert(loc=len(df_ROR_DAM_data.columns), value=nan, column=i)
#ratio of HROR to HDAM and average storage capacity of HDAM assumed to be representative from EU to global scope (lumped together in both Plexos data sets)
capacity_ROR                                        = sum(eu_hydro_database_JRC["installed_capacity_MW"][eu_hydro_database_JRC["type"] == "HROR"])          # 35 GW
capacity_DAM                                        = sum(eu_hydro_database_JRC["installed_capacity_MW"][eu_hydro_database_JRC["type"] == "HDAM"])          #105 GW
capacity_w_storage_data                             = sum(df_ROR_DAM_data["installed_capacity_MW"])                                                         # 41 GW
df_ROR_DAM_data["share_of_cap"]                     = df_ROR_DAM_data["installed_capacity_MW"] / sum(df_ROR_DAM_data["installed_capacity_MW"])
df_ROR_DAM_data["storage_d_Pmax"]                   = df_ROR_DAM_data["storage_capacity_MWh"] / df_ROR_DAM_data["installed_capacity_MW"] * (1/24)
df_ROR_DAM_data["weighted_share_storage_d_Pmax"]    = df_ROR_DAM_data["share_of_cap"] * df_ROR_DAM_data["storage_d_Pmax"] #change weighting from only HDAM to represent lumped data of Plexos
weighted_avg_storage_d_Pmax_DAM                     = sum(df_ROR_DAM_data["weighted_share_storage_d_Pmax"])                         #50days
weighted_avg_storage_d_Pmax_ROR_DAM                 = weighted_avg_storage_d_Pmax_DAM * (capacity_DAM/(capacity_DAM+capacity_ROR))  #38days
df_hydro_profiles["storage_capacity"]               = df_hydro_profiles["cumulated_capacity"] * weighted_avg_storage_d_Pmax_ROR_DAM * 24

#########################################################################################################################################################
######################################################## minimum flow criteria, fix_node_state disabled atm #############################################
#########################################################################################################################################################
# #derive minimal electricity production timeseries from (ecological) minimal discharge rates ["Hydropower Flexibility Valuation Tool [...]", Roni et al. 2022]
# min_durchfluss_m3s  = [1.42, 1.42, 1.42, 1.42, 1.42, 1.42, 0.79, 0.57, 0.54, 0.54, 0.65, 0.85] #minimal discharge as absolute value m3/s
# min_durchfluss_rel  = pd.Series(min_durchfluss_m3s) / 20.61 #minimal discharge as relative value
# df_min              = pd.DataFrame(columns=df_hydro_profiles['SA-Node'], index=monate)
# for i in range(len(df_min.columns)):    #loop for each country node i to allocate minimal discharge rates to corresponding month (lowest min discharge:lowest capacity factor)
#     ts_cf_i = pd.Series(df_hydro_profiles.loc[i,"2015-01-01T00:00:00":"2015-12-01T00:00:00"]) #timeseries capacity factor
#     ts_cf_i.reset_index(drop=True, inplace=True)
#     if ts_cf_i.any() != 0:
#         min_durchfluss_rel          = min_durchfluss_rel.sort_values()                                   #sort minimal discharge values
#         min_durchfluss_rel.index    = ts_cf_i.sort_values().index                                  #relate minimal discharge values to sorted capacity factor values
#         min_durchfluss_rel          = min_durchfluss_rel.sort_index()                                    #bring to original format (Jan, Feb... Dec)
#         min_durchfluss_rel.index    = monate                                                       #change format for timeseries import
#         df_min[df_hydro_profiles['SA-Node'][i]] = min_durchfluss_rel * df_hydro_profiles["cumulated_capacity"][df_hydro_profiles['SA-Node'] == df_hydro_profiles['SA-Node'][i]].values[0]                             #abspeichern der Werte
#         #Pruefung ob minimaler Durchfluss Constraint Probleme verursacht
#         df_temp                     = (pd.DataFrame(index=["min_df_rel", "ts_cf_i"], data=[min_durchfluss_rel.values, ts_cf_i.values], columns=min_durchfluss_rel.index))
#         for j in df_temp.columns:
#             if (df_temp.loc["min_df_rel", j] <= df_temp.loc["ts_cf_i", j]) == False:
#                 #print("minimaler Durchfluss zu hoch fuer Hydropower bei: " + df_hydro_profiles['SA-Node'][i] + " -> " + j)   #Warnung wird ausgegeben wenn der minimale Durchfluss hoeher als der zur Verfuegung stehende ist
#                 pass
#     else:
#         df_min[df_hydro_profiles['SA-Node'][i]] = 0  #save 0 if no data available
# df_min = df_min.transpose()
# #df_hydro_profiles["minflow_timeseries_abs"] = 
# df_hydro_profiles = df_hydro_profiles.merge((df_min[monate].apply(lambda row: row.to_dict(), axis=1).apply(lambda x: {"type": "time_series", "data": x})).reset_index().rename(columns={0:'minflow_timeseries_abs'}), how='left', on='SA-Node')
# #prepare set up fix_node_state parameter
# t_start                                             = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])).strftime('%Y-%m-%dT%H:%M:%S')
# t_start_minus1                                      = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0]) - pd.Timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S')
# t_end_minus1                                        = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1]) - pd.Timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S')
# #muss noch angepasst werden auf df_hydro_profiles
# df_cumulated_hydro_profiles.boundary_timeseries_abs = '{"type": "time_series", "data": {"' + t_start_minus1 + '": ' + (df_cumulated_hydro_profiles.storage_capacity * 0.5).astype(str)  + ', "' + t_start + '": ' + "NaN" + ', "' + t_end_minus1 + '": ' + (df_cumulated_hydro_profiles.storage_capacity * 0.5).astype(str) + '}}' #Umsetzung ueber timeseries mit NaN Werten verurusacht Probleme mit TSAM Segments-Gewichtung, daher Versuch ueber time_pattern
# # df_cumulated_hydro_profiles.boundary_timeseries_abs = '{\"type\": \"time_pattern\", \"data\": {\"h0-1\":' + (df_cumulated_hydro_profiles.storage_capacity * 0.5).astype(str) + ', \"'"h1-" + str(int(modeled_duration_in_hours - 1)) + '\": NaN' + ', \"'"h" + str(int(modeled_duration_in_hours - 1)) + "-" + str(int(modeled_duration_in_hours)) + '\": ' + (df_cumulated_hydro_profiles.storage_capacity * 0.5).astype(str) + '}}'
# #Beispiel: '{\"type\": \"time_pattern\", \"data\": {\"h0-1\": 150.0, \"h335-336\": 80.0}}'

#########################################################################################################################################################
#########################################################################################################################################################
#########################################################################################################################################################

df_hydro_profiles = df_hydro_profiles.rename(columns={'SA-Node':'Countries'})
df_hydro_profiles = df_hydro_profiles[df_hydro_profiles['Countries'].isin(list_subset_countries.Countries)].reset_index(drop=True)
df_hydro_profiles = df_hydro_profiles.merge(list_subset_countries, how='left', on='Countries')
#aggregate to regions
df_hydro_profiles['Unit_name_ohne_Country'] = df_hydro_profiles.apply(lambda x: x['unit_discharge'].replace(x['Countries'], ''), axis=1)
df_hydro_profiles['Regions'] = df_hydro_profiles['Regions'] + '_el'
df_hydro_profiles['unit_name_aggregation'] = df_hydro_profiles['Unit_name_ohne_Country'] + df_hydro_profiles['Regions']
df_hydro_profiles = (
    df_hydro_profiles
    .drop(columns=['Countries','unit_discharge','Unit_name_ohne_Country','fuel_node'])
    .groupby(['unit_name_aggregation','Regions'])
    .agg(dict(zip(monate + ['cumulated_capacity', 'storage_capacity'], (len(monate) + 2)*['sum'])))#, 'fuel_prices':'mean'}) Achtung fuel prices fehlen noch
    .reset_index()
)

### adapt to new naming convention commodities_in|technology|Regions
df_hydro_profiles["unit_name_aggregation"]      = df_hydro_profiles["unit_name_aggregation"].str.replace("Hydro", "Hydro|Hydro")
df_hydro_profiles["unit_name_aggregation"]      = df_hydro_profiles["unit_name_aggregation"].str.replace("_el", "")
df_hydro_profiles["Regions"]                    = df_hydro_profiles["unit_name_aggregation"].str.split('|').str[2] 
df_hydro_profiles['commodities_in']             = "Hydro"
df_hydro_profiles['commodities_out']            = "el"
df_hydro_profiles["node_in"]                    = df_hydro_profiles["Regions"] + "_" + df_hydro_profiles["commodities_in"]
df_hydro_profiles["node_out"]                   = df_hydro_profiles["Regions"] + "_" + df_hydro_profiles["commodities_out"]
df_hydro_profiles['reservoir']                  = df_hydro_profiles["commodities_in"] + "|" + "Reservoir" + "|" + df_hydro_profiles['Regions']
df_hydro_profiles['unit_discharge']             = df_hydro_profiles["commodities_in"] + "|" + "Hydro" + "|" + df_hydro_profiles['Regions']
#%%

df_hydro_profiles["cumulated_timeseries_abs"]   = df_hydro_profiles[monate].apply(lambda row: row.to_dict(), axis=1).apply(lambda x: {"type": "time_series", "data": x})
df_hydro_profiles["cumulated_timeseries_abs"] = pd.Series(df_hydro_profiles["cumulated_timeseries_abs"].astype(str))
df_hydro_profiles["cumulated_timeseries_abs"] = df_hydro_profiles.apply(lambda x: x["cumulated_timeseries_abs"].replace("'", '"'), axis=1)
# df_hydro_profiles["cumulated_timeseries_abs"] = (pd.Series("'" + df_hydro_profiles["cumulated_timeseries_abs"].astype(str) + "'"))

#%%

#prepare investcost calculation
t_start                     = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])
t_end                       = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1])
modeled_duration_in_years   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760)
modeled_duration_in_days    = round(((t_end - t_start) / pd.Timedelta(hours=1)) * (1/24))

################# Prepare Export #########################################################

#initialization (0 dimensional properties) only needs to be performed if import_objects is not applied in Spine Importer or if object will not be used in any following relationships
node                                        = pd.DataFrame({"Object class names":"node", "Object names":df_hydro_profiles.reservoir})
unit                                        = pd.DataFrame({"Object class names":"unit", "Object names":df_hydro_profiles["unit_name_aggregation"]})
dim_0_initialization_dtype_str              = pd.concat([node, unit], ignore_index=True)

node_has_state                              = pd.DataFrame({"Object class names":"node", "Object names":df_hydro_profiles.reservoir, "Parameter names":"has_state", "Alternative names":"Base", "Parameter values":"true"})   #Achtung hier muss im Importer manuell der Datentyp auf Boolean Value umgestellt werden, sonst wird nur ein String importiert (als True werden die Werte "True", "true", "1", 1 akzeptiert
dim_1_object_value_dtype_bool               = pd.concat([node_has_state], ignore_index=True)

node_state_cap                              = pd.DataFrame({"Object class names":"node", "Object names":df_hydro_profiles.reservoir, "Parameter names":"node_state_cap", "Alternative names":"Base", "Parameter values":df_hydro_profiles.storage_capacity})
# fix_node_state 					            = pd.DataFrame({"Object class names":"node", "Object names":df_cumulated_hydro_profiles.reservoir, "Parameter names":"fix_node_state", "Alternative names":"Base", "Parameter values":df_cumulated_hydro_profiles.boundary_timeseries_abs})
#balance_type = pd.DataFrame({"Object class names":"node", "Object names":pd.Series(df_cumulated_hydro_profiles.fuel_node.unique()), "Parameter names":"balance_type", "Alternative names":"Base", "Parameter values":"balance_type_none"}) #wird in import_plexos_units importiert; fuel_node nach Umstellung von unit_availability_factor bei Hydro_Inflow_Unit zu demand bei Hydro_Reservoir_Node nicht mehr verknuepft
# initial_node_state                          = pd.DataFrame({"Object class names":"node", "Object names":df_cumulated_hydro_profiles.reservoir, "Parameter names":"initial_node_state", "Alternative names":"Base", "Parameter values":(df_cumulated_hydro_profiles.storage_capacity * 0.5).astype(str)}) #wird mit representative periods nicht korrekt beruecksichtigt
demand                                      = pd.DataFrame({"Object class names":"node", "Object names":df_hydro_profiles.reservoir, "Parameter names":"demand", "Alternative names":"Base", "Parameter values":df_hydro_profiles.cumulated_timeseries_abs}) #negative demand defined as inflow to reservoir
# dim_1_object_value_dtype_str                = pd.concat([node_state_cap, fix_node_state """oder initial_node_state""", demand], ignore_index=True)
unit_inital_units_invested_available        = pd.DataFrame({"Object class names":"unit", "Object names":df_hydro_profiles["unit_name_aggregation"], "Parameter names":"initial_units_invested_available", "Alternative names":"Base", "Parameter values":df_hydro_profiles.cumulated_capacity/float(m_conf.Value[m_conf["Parameter"] == "subunit_size"].values[0])})
unit_candidate_units                        = pd.DataFrame({"Object class names":"unit","Object names":df_hydro_profiles["unit_name_aggregation"], "Parameter names":"candidate_units", "Alternative names":"Base", "Parameter values":df_hydro_profiles.cumulated_capacity/float(m_conf.Value[m_conf["Parameter"] == "subunit_size"].values[0])})
unit_unit_investment_cost                   = pd.DataFrame({"Object class names":"unit","Object names":df_hydro_profiles["unit_name_aggregation"], "Parameter names":"unit_investment_cost", "Alternative names":"Base", "Parameter values":0})
unit_unit_investment_lifetime               = pd.DataFrame({"Object class names":"unit","Object names":df_hydro_profiles["unit_name_aggregation"], "Parameter names":"unit_investment_lifetime", "Alternative names":"Base", "Parameter values":'{\"type\": \"duration\", \"data\": \"' + str(modeled_duration_in_days) + "D" + '\"}'})
dim_1_object_value_dtype_str                = pd.concat([node_state_cap, demand, unit_inital_units_invested_available, unit_candidate_units, unit_unit_investment_cost, unit_unit_investment_lifetime], ignore_index=True)

node__temporal_block_cyclic_condition       = pd.DataFrame({"Relationship class names":"node__temporal_block", "Object class names 1":"node", "Object class names 2":"temporal_block", "Object names 1":df_hydro_profiles.reservoir, "Object names 2":"seasonal", "Parameter names":"cyclic_condition", "Alternative names":"Base", "Parameter values":"true"}) #watch carefully when working with TSAM
dim_2_relationship_value_dtype_bool         = pd.concat([node__temporal_block_cyclic_condition], ignore_index=True)

unit__from_node_discharge_capacity          = pd.DataFrame({"Relationship class names":"unit__from_node", "Object class names 1":"unit", "Object class names 2":"node", "Object names 1":df_hydro_profiles["unit_name_aggregation"], "Object names 2":df_hydro_profiles["reservoir"], "Parameter names":"unit_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[m_conf["Parameter"] == "subunit_size"].values[0]})
unit__to_node_discharge_capacity            = pd.DataFrame({"Relationship class names":"unit__to_node", "Object class names 1":"unit", "Object class names 2":"node", "Object names 1":df_hydro_profiles["unit_name_aggregation"], "Object names 2":df_hydro_profiles["node_out"], "Parameter names":"unit_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[m_conf["Parameter"] == "subunit_size"].values[0]})
# unit__to_node_discharge_min_flow            = pd.DataFrame({"Relationship class names":"unit__to_node", "Object class names 1":"unit", "Object class names 2":"node", "Object names 1":df_cumulated_hydro_profiles.unit_discharge, "Object names 2":df_cumulated_hydro_profiles.node, "Parameter names":"min_unit_flow", "Alternative names":"Base", "Parameter values":df_cumulated_hydro_profiles.minflow_timeseries_abs})
# dim_2_relationship_value_dtype_str          = pd.concat([unit__from_node_discharge_capacity, unit__to_node_discharge_capacity, unit__to_node_discharge_min_flow], ignore_index=True) #minmal flow seems to be bugged when mulitple temporal blocks are implemented
# unit__from_node_fuel_cost           = pd.DataFrame({"Relationship class names":"unit__from_node", "Object class names 1":"unit", "Object class names 2":"node", "Object names 1":agg_kraftwerke.unit_name_aggregation, "Object names 2":fuel_nodes.Commodity, "Parameter names":"fuel_costs", "Alternative names":"Base", "Parameter values":agg_kraftwerke.fuel_prices})
dim_2_relationship_value_dtype_str          = pd.concat([unit__from_node_discharge_capacity, unit__to_node_discharge_capacity], ignore_index=True)

unit__node__node_discharge_fix_ratio_out_in = pd.DataFrame({"Relationship class names":"unit__node__node", "Object class names 1":"unit", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":df_hydro_profiles["unit_name_aggregation"], "Object names 2":df_hydro_profiles.reservoir, "Object names 3":df_hydro_profiles["node_out"], "Parameter names":"fix_ratio_in_out_unit_flow", "Alternative names":"Base", "Parameter values":1})
dim_3_relationship_value_dtype_str          = pd.concat([unit__node__node_discharge_fix_ratio_out_in], ignore_index=True)

################# Prepare Export End #####################################################

################# Convert to Backbone ####################################################

eps = float(0.0000001)
eps = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#dim0
bb_dim_0_initialization_dtype_str = pd.concat([pd.DataFrame({'Object class names':['grid']*2,'Object names':['hydro','elec']}), dim_0_initialization_dtype_str],ignore_index=True)

#dim1
columns_1d = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter values']
values_u = ['unit','unitXXX','parameterXXX','Base','valueXXX']
template_u = pd.DataFrame(dict(zip(columns_1d, values_u)), index=range(len(df_hydro_profiles))).assign(**{'Object names':df_hydro_profiles['unit_name_aggregation']})
#p_unit -> availability, maxUnitCount, is_active, eff00 (no minUnitCount, investMIP, eff01, op00, op01)
bb_dim_1_availability = template_u.assign(**{'Parameter names':'availability','Parameter values':1})
bb_dim_1_maxUnitCount = bb_dim_1_availability.assign(**{'Parameter names':'maxUnitCount','Parameter values':0}) # wird nicht vmtl nicht zwingend benoetigt da 0 gleich nicht beachtet
#bb_dim_1_eff00 = bb_dim_1_availability.assign(**{'Parameter names':'eff00','Parameter values':1})
bb_dim_1_relationship_dtype_str = pd.concat([bb_dim_1_availability,bb_dim_1_maxUnitCount]) #flow unit dont have efficiency ,bb_dim_1_eff00

#dim2
columns_2d = ['Relationship class names', 'Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter values']
columns_2d_map = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values']
#p_gn -> nodeBalance, energyStoredPerUnitOfState, usePrice, boundStart
values_gn = ['grid__node','grid','node','hydro','hydroResXXX','parameterXXX','Base','valuesXXX']
template_gn = pd.DataFrame(dict(zip(columns_2d, values_gn)), index=range(len(df_hydro_profiles)))
#parameters
bb_dim_2_nodeBalance = template_gn.assign(**{'Object names 2':df_hydro_profiles['reservoir'],'Parameter names':'nodeBalance','Parameter values':1})
bb_dim_2_energyStored = bb_dim_2_nodeBalance.assign(**{'Parameter names':'energyStoredPerUnitOfState'})
bb_dim_2_usePrice = bb_dim_2_nodeBalance.assign(**{'Parameter names':'usePrice','Parameter values':0})
bb_dim_2_boundEnd = bb_dim_2_nodeBalance.assign(**{'Parameter names':'boundEnd'})
bb_dim_2_boundStart = bb_dim_2_nodeBalance.assign(**{'Parameter names':'boundStart'})

##### introduce unittype
unittype                = pd.DataFrame({"unit": df_hydro_profiles["unit_discharge"].drop_duplicates()})
unittype["technology"] = unittype["unit"].str.split('|', expand=True)[0]
bb_dim2_unitunittype = pd.DataFrame({"Relationship class names": "unit__unittype", 
                                     "Object class names 1": "unit",
                                     "Object class names 2": "unittype",
                                     "Object names 1": unittype["unit"],
                                     "Object names 2": unittype["technology"]})

bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_nodeBalance,bb_dim_2_energyStored,bb_dim_2_usePrice,bb_dim_2_boundEnd,bb_dim_2_boundStart, bb_dim2_unitunittype],ignore_index=True)

#utAvailabilityLimits -> becomeAvailable
bb_dim_1_map_utAvailabilityLimits = pd.DataFrame(dict(zip(columns_2d_map, ['unit','unitXXX','becomeAvailable','Base','t000001',1])), index=range(len(df_hydro_profiles))).assign(**{'Object names':df_hydro_profiles['unit_name_aggregation']})
bb_dim_1_relationship_dtype_map = pd.concat([bb_dim_1_map_utAvailabilityLimits],ignore_index=True)
bb_dim_1_map_utAvailabilityLimits = pd.DataFrame(dict(zip(columns_2d_map, ['unit','unitXXX','becomeAvailable','Base','t000001',1])), index=range(len(df_hydro_profiles))).assign(**{'Object names':df_hydro_profiles['unit_name_aggregation']})
bb_dim_1_relationship_dtype_map = pd.concat([bb_dim_1_map_utAvailabilityLimits],ignore_index=True)

#dim3
columns_3d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object names 1','Object names 2','Object names 3','Parameter names','Alternative names','Parameter values']
#effLevelGroupUnit
# bb_dim_3_effLevelGroupUnit = pd.DataFrame(index=range(len(df_hydro_profiles)*3), columns=columns_3d)
# bb_dim_3_effLevelGroupUnit = bb_dim_3_effLevelGroupUnit.assign(**{'Relationship class names':'effLevel__effSelector__unit','Object class names 1':'effLevel','Object class names 2':'effSelector','Object class names 3':'unit','Object names 1':['level1','level2','level3']*len(df_hydro_profiles),'Object names 2':'directOff','Object names 3':(pd.concat([df_hydro_profiles['unit_name_aggregation']]*3,ignore_index=True)).sort_values(ignore_index=True)})
#p_gnBoundaryPropertiesForStates
bb_dim_3_downwardLimit_useConsant = pd.DataFrame(index=range(len(df_hydro_profiles)), columns=columns_3d).assign(**{'Relationship class names':'grid__node__boundary','Object class names 1':'grid','Object class names 2':'node','Object class names 3':'boundary','Object names 1':'hydro', 'Object names 2':df_hydro_profiles['reservoir'],'Object names 3':'downwardLimit','Parameter names':'useConstant','Alternative names':'Base','Parameter values':1})
bb_dim_3_downwardLimit_constant = bb_dim_3_downwardLimit_useConsant.assign(**{'Parameter names':'Constant','Parameter values':eps})
bb_dim_3_upwardLimit_useConsant = bb_dim_3_downwardLimit_useConsant.assign(**{'Object names 3':'upwardLimit'})
bb_dim_3_upwardLimit_constant = bb_dim_3_downwardLimit_constant.assign(**{'Object names 3':'upwardLimit','Parameter values':df_hydro_profiles['storage_capacity']})
bb_dim_3_reference_useConstant = bb_dim_3_upwardLimit_useConsant.assign(**{'Object names 3':'reference','Parameter names':'useConstant','Parameter values':1})
bb_dim_3_reference_constant = bb_dim_3_reference_useConstant.assign(**{'Parameter names':'constant','Parameter values':0.5 * df_hydro_profiles['storage_capacity'].astype(float)}) # not in use atm
bb_dim_3_balancePenalty_useConstant = bb_dim_3_reference_useConstant.assign(**{'Object names 3':'balancePenalty','Parameter names':'useConstant','Parameter values':1})
bb_dim_3_balancePenalty_constant = bb_dim_3_reference_useConstant.assign(**{'Object names 3':'balancePenalty','Parameter names':'constant','Parameter values':10**6})
bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_downwardLimit_useConsant,bb_dim_3_downwardLimit_constant,bb_dim_3_upwardLimit_useConsant,bb_dim_3_upwardLimit_constant,bb_dim_3_balancePenalty_useConstant,bb_dim_3_balancePenalty_constant],ignore_index=True) #bb_dim_3_effLevelGroupUnit not included bexause flow untis dont have effLimit

#dim4
columns_4d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object class names 4','Object names 1','Object names 2','Object names 3','Object names 4','Parameter names','Alternative names','Parameter values']
values_gnuio = ['grid__node__unit__io','grid','node', 'unit','io','elecOderHydro','countryOderResNodes','unitXXX','inputOderOutput','ParameterXXX','Base','ValueXXX']
template_gnuio = pd.DataFrame(dict(zip(columns_4d, values_gnuio)), index=range(len(df_hydro_profiles)))
#p_gnu_io -> conversionCoeff, capacity, unitSize, invCosts, fomCosts, vomCosts, annuityFactor, upperLimitCapacityRatio
bb_dim_4_conversionCoeff_i = pd.DataFrame(dict(zip(columns_4d, values_gnuio)), index=range(len(df_hydro_profiles))).assign(**{'Object names 1':'hydro','Object names 2':df_hydro_profiles['reservoir'],'Object names 3':df_hydro_profiles['unit_name_aggregation'],'Object names 4':'input','Parameter names':'conversionCoeff','Parameter values':1})
bb_dim_4_conversionCoeff_o = bb_dim_4_conversionCoeff_i.assign(**{'Object names 1':'elec','Object names 2':df_hydro_profiles['node_out'],'Object names 4':'output'})
bb_dim_4_capacity_o = bb_dim_4_conversionCoeff_o.assign(**{'Parameter names':'capacity','Parameter values':df_hydro_profiles['cumulated_capacity']})
bb_dim_4_capacity_o[bb_dim_4_capacity_o['Parameter values'] == 0] = bb_dim_4_capacity_o[bb_dim_4_capacity_o['Parameter values'] == 0].assign(**{'Parameter values':eps}) #setting the zero capacity entries to 0.001 cause Backbone seems to ignore zero values sometimes... ## to do ## have to check this later ('eps' should sometimes be used as 0 but causes problems for exporter (string!=float))
bb_dim_4_unitSize_o = bb_dim_4_capacity_o.assign(**{'Parameter names':'unitSize','Parameter values':1})
bb_dim_4_unitSize_i = bb_dim_4_conversionCoeff_i.assign(**{'Parameter names':'unitSize','Parameter values':1})

#Deleting unitSize for Hydro pp to get rid of Backbone Warning has capacity <> unitSize * unitCount
bb_dim_4_unitSize_o = bb_dim_4_unitSize_o.loc[~(bb_dim_4_unitSize_o["Object names 3"].str.contains("Hydro")), :]  #Hydro does not have a unit size
bb_dim_4_unitSize_i = bb_dim_4_unitSize_i.loc[~(bb_dim_4_unitSize_i["Object names 3"].str.contains("Hydro")), :]  #Hydro does not have a unit size

bb_dim_4_invCosts_o = bb_dim_4_capacity_o.assign(**{'Parameter names':'invCosts','Parameter values':float(m_conf.Value[m_conf["Parameter"] == "unit_investment_cost"].values[0])}) ## to do ## ermoeglichen, dass Powerplants je nach Technologie entsprechend unterschiedliche Kosten zugewiesen bekommen (z.B. ueber Abfrage neben "Parameter" noch "Technologie","Commodity","fix_ratio" etc.)
bb_dim_4_fomCosts_o = bb_dim_4_capacity_o.assign(**{'Parameter names':'fomCosts','Parameter values':(0/100)*float(m_conf.Value[m_conf["Parameter"] == "unit_investment_cost"].values[0])}) #Platzhalter ## to do ##
bb_dim_4_vomCosts_o = bb_dim_4_capacity_o.assign(**{'Parameter names':'vomCosts','Parameter values':0*(1/5000)*float(m_conf.Value[m_conf["Parameter"] == "unit_investment_cost"].values[0])}) #Platzhalter ## to do ##
bb_dim_4_annuityFactor_o = bb_dim_4_capacity_o.assign(**{'Parameter names':'annuityFactor','Parameter values':0.07}) #Platzhalter ## to do ##
bb_dim_4_availabilityCapacityMargin = bb_dim_4_capacity_o.assign(**{'Parameter names':'availabilityCapacityMargin','Parameter values':availabilityCapacityMargin_config})

## bb_dim_4_upperLimitCapacityRatio ## kein Limit an die CapacityRatio, da Node festen Wert als maximale Speichermenge zugewiesen hat und Investitionen ausgeschlossen sind
bb_dim_4_relationship_dtype_str = pd.concat([
    bb_dim_4_conversionCoeff_i,
    bb_dim_4_conversionCoeff_o,
    bb_dim_4_capacity_o,
    bb_dim_4_unitSize_o,
    bb_dim_4_unitSize_i,
    bb_dim_4_availabilityCapacityMargin,
    # bb_dim_4_invCosts_o,  # invest disabled through p_unit's maxUnitCount
    # bb_dim_4_fomCosts_o,
    # bb_dim_4_vomCosts_o,
    # bb_dim_4_annuityFactor_o
    ],ignore_index=True)

##demand timeseries has to be converted a little bit special and gets its own sheet
#introduce BB timestep nomenclature, data is available in monthly resolution, to make it easy each month represents the same number of days (30.41666) and the same number of hours (730)
df_influx = pd.DataFrame(columns='t' + pd.Series(range(1,8761)).astype(str).str.zfill(6),index=range(len(df_hydro_profiles)))
for i in range(len(monate)):
    df_influx.iloc[:,730*int(i):730*(int(i)+1)] = pd.DataFrame([df_hydro_profiles[monate[i]]]*730).T
#demand is negative, inflow is positive (in BB, data df_hydro is negative)
df_influx = (df_influx * -1)
# %%
df_bb_ts = pd.concat([pd.DataFrame({'grid':'hydro','node':df_hydro_profiles['reservoir'],'Alternative names':'PLEXOS_2015_plus_JRC_Hydro','forecast index':'f00'}),df_influx.iloc[:,:modeled_duration_in_days*24]],ignore_index=False,axis=1) # limit timeseries to modeling horizon to make importing faster in test runs


# introduce model_config option to take away Hydropowers storage potential via 'hydro_noStorage'
# previous assumption that hydropower can utilize its full storage potential perfectly flexible may be not well suited if you wanna research storage and flexibility
# should this be the standart config? (cf. e.g. https://doi.org/10.1371/journal.pone.0259876)
if m_conf.loc[m_conf['Parameter'] == 'hydro_noStorage','Value'].values[0] == 'yes':
    bb_dim_0_initialization_dtype_str = pd.DataFrame({
        'Object class names':'unit',
        'Object names':df_hydro_profiles['unit_discharge'],
    })
    bb_dim_1_relationship_dtype_str # passt
    bb_dim_2_relationship_dtype_str = pd.DataFrame({
        'Relationship class names':'flow__unit',
        'Object class names 1':'flow',
        'Object class names 2':'unit',
        'Object names 1':'Hydro',
        'Object names 2':df_hydro_profiles['unit_discharge'],
        'Parameter names':'',
        'Alternative names':'',
        'Parameter values':'',
        })
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim2_unitunittype], ignore_index=True) # add unit unittype relationship
    bb_dim_1_relationship_dtype_map # passt
    # bb_dim_3_relationship_dtype_str = bb_dim_3_effLevelGroupUnit #flow units dont have effLevelGroup
    bb_dim_4_relationship_dtype_str = pd.concat([
        bb_dim_4_capacity_o,
        bb_dim_4_unitSize_o,
        ],ignore_index=True)
    # muss parallel auch bei deaktivierter noStorage Option fuer den Importer umgestellt werden ## to do ## ausserdem Importer setting selbst anpassen und mit beiden optionen testen
    bb_dim_2_relationship_dtype_map = (pd.concat([df_hydro_profiles['node_out'], df_influx.iloc[:,:modeled_duration_in_days*24].mul(1/df_hydro_profiles['cumulated_capacity'].values, axis=0)],
    ignore_index=False, axis=1)
    .melt(id_vars='node_out',var_name='time_step')
    .rename(columns={
        'node_out':'Object names 2',
        'time_step':'Parameter indexes 2',
        'value':'Parameter values'
        })
    .assign(**{
        'Relationship class names':'flow__node',
        'Object class names 1':'flow',
        'Object class names 2':'node',
        'Object names 1':'Hydro',
        'Parameter names':'capacityFactor',
        'Alternative names':'PLEXOS_2015_plus_JRC_Hydro',
        'Parameter indexes 1':'f00',
        })
    )
    bb_dim_2_relationship_dtype_map = bb_dim_2_relationship_dtype_map[['Relationship class names','Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter indexes 1','Parameter indexes 2','Parameter values']]

#### Adding the constraints for the Delegated Act for RFNBOs ####

if RFNBO_option == "Vanilla":
    bb_dim_4_relationship_dtype_str = bb_dim_4_relationship_dtype_str.drop_duplicates()
    print("Base model without any RFNBO modifications" + "\n")

if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #reassining all storages to the renewable electricity nodes
    #dim 0
    bb_dim_0_initialization_dtype_str['Object names'] = bb_dim_0_initialization_dtype_str['Object names'].str.replace('_el','_re_el')
    #dim1
    bb_dim_1_relationship_dtype_str['Object names'] = bb_dim_1_relationship_dtype_str['Object names'].str.replace('_el','_re_el')
    #dim1map
    bb_dim_1_relationship_dtype_map['Object names'] = bb_dim_1_relationship_dtype_map['Object names'].str.replace('_el','_re_el')
    #dim2
    bb_dim_2_relationship_dtype_str["Object names 2"] = bb_dim_2_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    #dim2map
    bb_dim_2_relationship_dtype_map["Object names 2"] = bb_dim_2_relationship_dtype_map["Object names 2"].str.replace('_el','_re_el')
    #dim3
    bb_dim_3_relationship_dtype_str["Object names 2"] = bb_dim_3_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    bb_dim_3_relationship_dtype_str["Object names 3"] = bb_dim_3_relationship_dtype_str["Object names 3"].str.replace('_el','_re_el')
    #dim4
    bb_dim_4_relationship_dtype_str["Object names 2"] = bb_dim_4_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    bb_dim_4_relationship_dtype_str["Object names 3"] = bb_dim_4_relationship_dtype_str["Object names 3"].str.replace('_el','_re_el')
    #dim2ts
    df_bb_ts['node'] = df_bb_ts['node'].str.replace('_el','_re_el')

if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"
    #keeping all old hydro at the mixed electricity nodes. new hydro is considered infeasible because of regulation

if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid_prerun"
    
    #dim 0
    bb_dim_0_initialization_dtype_str['Object names'] = bb_dim_0_initialization_dtype_str['Object names'].str.replace('_el','_re_el')
    #dim1
    bb_dim_1_relationship_dtype_str['Object names'] = bb_dim_1_relationship_dtype_str['Object names'].str.replace('_el','_re_el')
    #dim1map
    bb_dim_1_relationship_dtype_map['Object names'] = bb_dim_1_relationship_dtype_map['Object names'].str.replace('_el','_re_el')
    #dim2
    bb_dim_2_relationship_dtype_str["Object names 2"] = bb_dim_2_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    #dim2map
    bb_dim_2_relationship_dtype_map["Object names 2"] = bb_dim_2_relationship_dtype_map["Object names 2"].str.replace('_el','_re_el')
    #dim3
    bb_dim_3_relationship_dtype_str["Object names 2"] = bb_dim_3_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    bb_dim_3_relationship_dtype_str["Object names 3"] = bb_dim_3_relationship_dtype_str["Object names 3"].str.replace('_el','_re_el')
    #dim4
    bb_dim_4_relationship_dtype_str["Object names 2"] = bb_dim_4_relationship_dtype_str["Object names 2"].str.replace('_el','_re_el')
    bb_dim_4_relationship_dtype_str["Object names 3"] = bb_dim_4_relationship_dtype_str["Object names 3"].str.replace('_el','_re_el')
    #dim2ts
    df_bb_ts['node'] = df_bb_ts['node'].str.replace('_el','_re_el')

if RFNBO_option == "Defossilized_Grid":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid"

    #the hydro power plants remain at the mixed electricity nodes

if RFNBO_option == "Add_and_Corr":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Additionality and Correlation ###
    alt_rfnbo = "Additionality_and_Correlation"

    #the hydro power plants remain at the mixed electricity nodes

if RFNBO_option == "All_at_once":
    print("Applying all regulations for RFNBOs" + "\n")
    ### All at once ###
    alt_rfnbo = "All_at_once"

    #the hydro power plants remain at the mixed electricity nodes

################# Write File #############################################################

# with pd.ExcelWriter(path = outputfile) as writer: 
#     pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
# with pd.ExcelWriter(path = outputfile, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
#     dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
#     dim_1_object_value_dtype_bool.to_excel(writer, index=False, sheet_name="02_dim1_bool")
#     dim_1_object_value_dtype_str.to_excel(writer, index=False, sheet_name="03_dim1")
#     dim_2_relationship_value_dtype_bool.to_excel(writer, index=False, sheet_name="04_dim2_bool")
#     dim_2_relationship_value_dtype_str.to_excel(writer, index=False, sheet_name="04_dim2")
#     dim_3_relationship_value_dtype_str.to_excel(writer, index=False, sheet_name="05_dim3")

# print("\n" + "Spines Hydropower data exported to: " + outputfile + "\n")

# bb_dim_2_relationship_dtype_map = (pd.concat([
#         df_hydro_profiles['reservoir'], 
#         df_influx.iloc[:,:modeled_duration_in_days*24]],
#     ignore_index=False, axis=1)
#     .melt(id_vars='reservoir',var_name='time_step')
#     .rename(columns={
#         'reservoir':'Object names 2',
#         'time_step':'Parameter indexes 2',
#         'value':'Parameter values'
#         })
#     .assign(**{
#         'Relationship class names':'grid__node',
#         'Object class names 1':'grid',
#         'Object class names 2':'node',
#         'Object names 1':'hydro',
#         'Parameter names':'influx',
#         'Alternative names':'PLEXOS_2015_plus_JRC_Hydro',
#         'Parameter indexes 1':'f00',
#         })
#     )
# bb_dim_2_relationship_dtype_map = bb_dim_2_relationship_dtype_map[['Relationship class names','Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter indexes 1','Parameter indexes 2','Parameter values']]

# with pd.ExcelWriter(path = outputfile_BB) as writer:
#     pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
# with pd.ExcelWriter(path = outputfile_BB, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
#     bb_dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
#     bb_dim_1_relationship_dtype_str.to_excel(writer, index=False, sheet_name="02_dim1")
#     bb_dim_2_relationship_dtype_str.to_excel(writer, index=False, sheet_name="03_dim2")
#     bb_dim_1_relationship_dtype_map.to_excel(writer, index=False, sheet_name="04_dim1_map")
#     bb_dim_3_relationship_dtype_str.to_excel(writer, index=False, sheet_name="05_dim3")
#     bb_dim_4_relationship_dtype_str.to_excel(writer, index=False, sheet_name="06_dim4")
#     bb_dim_2_relationship_dtype_map.to_excel(writer, index=False, sheet_name='07_dim2_map')
# # %%
print("\n" + "Backbones Hydropower data exported to: " + outputfile_BB + "\n")

with pd.ExcelWriter(path = outputfile_BB) as writer:
    pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
with pd.ExcelWriter(path = outputfile_BB, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    bb_dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
    bb_dim_1_relationship_dtype_str.to_excel(writer, index=False, sheet_name="02_dim1")
    bb_dim_2_relationship_dtype_str.to_excel(writer, index=False, sheet_name="03_dim2")
    bb_dim_1_relationship_dtype_map.to_excel(writer, index=False, sheet_name="04_dim1_map")
    bb_dim_3_relationship_dtype_str.to_excel(writer, index=False, sheet_name="05_dim3")
    bb_dim_4_relationship_dtype_str.to_excel(writer, index=False, sheet_name="06_dim4")
    if m_conf.loc[m_conf['Parameter'] == 'hydro_noStorage','Value'].values[0] == 'yes':
        bb_dim_2_relationship_dtype_map.to_excel(writer, index=False, sheet_name='07_dim2_map')

print("\n" + "Backbones Hydropower data overwritten with NO STORAGE OPTION to: " + outputfile_BB + "\n")

#%%
STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
# %%
