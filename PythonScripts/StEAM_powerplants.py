# under construction
# This is the new powerplants script for the StEAM model
#%%

"""
Created 2025
@author OL
based on the former Import_Plexos_data.py script
"""

# Notes:
# CSP, Desalination not part of the model
# Electrolyzer, Liquifaction, Regasification not part of this script

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

##### Defining directories #####

print("Defining directories" + "\n")

print('Execute in Directory:')
print(os.getcwd())

try:
    #use if run in spine-toolbox
    path_MainInput          = sys.argv[1]
    df_pp_base_path         = sys.argv[2]
    path_RE_1dim_data       = sys.argv[3]
    path_WACC_Update        = sys.argv[4]
    dir_scenario_data       = '../Data/Szenario_Data'
    outputfile_BB           = r"TEMP\Plexos_powerplants_BB.xlsx"
    path_lim_fac            = '../Data/Limiting_factors/capacity_expansion_limits.xlsx'
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    path_MainInput          = r"PythonScripts\TEMP\MainInput.xlsx"
    df_pp_base_path         = r"Data\Powerplants\20240425_pp_base_data.xlsx"
    path_RE_1dim_data       = r"Data/Invest_Renew/Steps_5/02_dim1.csv"
    path_WACC_Update        = r'PythonScripts/TEMP/weighted_WACC_final_long.csv'
    dir_scenario_data       = r"Data/Szenario_Data"
    outputfile_BB           = r"PythonScripts\TEMP\Plexos_powerplants_BB.xlsx"
    path_lim_fac            = r"Data\Limiting_factors\capacity_expansion_limits.xlsx"

#start timer
START   = time.perf_counter()

print("Reading model settings from MainInput" + "\n")

#read datasets from excel file
subset_countries   = pd.read_excel(path_MainInput, sheet_name='subset_countries')
m_conf                  = pd.read_excel(path_MainInput, sheet_name="model_config")
df_RE_1dim_data         = pd.read_csv(path_RE_1dim_data, sep = ';') # XX-XXX ONLY -> concatinated subset works fine (not even needed here)

#prepare investcost calculation
t_start                     = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])
t_end                       = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1])
modeled_duration_in_years   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760)
modeled_duration_in_days    = round(((t_end - t_start) / pd.Timedelta(hours=1)) * (1/24))

#read the eps value of the model_config sheet in the excel file path_Main_Input and save the values as eps
eps                         = float(0.0001) # define default value
eps                         = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#read RFNBO regulation option
RFNBO_option                = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value
#read limiting factors option
lim_fac_option              = m_conf.loc[m_conf['Parameter'] == "Cap_Lim_option", "Value"].values[0] # limiting factors read value
#read system integration cost factor
system_integration_factor    = float(m_conf.loc[m_conf['Parameter'] == "system_integration_factor", "Value"].values[0]) # system integration cost read value

print("System integration cost factor: " + str(system_integration_factor) + " not implemented yet" + "\n")

print("Defining regex lists for commodities and technologies" + "\n")

#centrally define relevant lists of energy sources
list_of_all_commodities = ['Coal', 'Oil', 'Gas', 'Nuclear', 'Wind', 'Solar', 'Geothermal', 'Biomass', 'GAS', "Hydro", "h2", "el"] #list of all commodities
list_of_renewables      = ['Solar', 'Wind', 'Hydro', 'Geothermal', 'Biomass'] #list of renewable energy sources
list_of_renewables_nbo  = ['Solar', 'Wind', 'Hydro', 'Geothermal'] #list of renewable energy sources
list_of_h2_assets       = ['Electrolyzer', 'FuelCell', 'Liquifaction', 'Regasification', "h2|OCGT", "h2|FuelCell"] #list of hydrogen assets - needed for RFNBO option to feed into re_elec grid
list_of_vre             = ['Solar', 'Wind', "Hydro"] #list of variable renewable energy sources (Hydro being run of river)
list_of_fossils         = ['Coal', 'Oil', 'Gas'] #list of fossil energy sources
list_of_endo_commodities= ['el', 'h2'] #list of system endogenous commodities
list_of_fuels           = ["Biomass", "Nuclear", "Coal", "Gas", "Oil"] #list of fuels
dont_invest             = ['Nuclear', "Coal", "Oil", 'Other'] #list of energy sources that should not be invested in
dont_consider           = ["CSP", "Hydro", "Desalination", "Geothermal", "Other", "Liquifaction", "Regasification", "h2_Liquification"] #list of all technologies that should not be considered in the model

# define regex for filtering
regex_all_commodities = '|'.join(list_of_all_commodities) #regular expression for all powerplant commodities
regex_renewables = '|'.join(list_of_renewables) #regular expression for renewable energy sources
regex_renewables_nbo = '|'.join(list_of_renewables_nbo) #regular expression for renewable energy sources
regex_vre = '|'.join(list_of_vre) #regular expression for variable renewable energy sources
regex_h2_assets = '|'.join(list_of_h2_assets) #regular expression for hydrogen assets needed for RFNBO option to feed into re_elec grid
regex_fossils = '|'.join(list_of_fossils) #regular expression for fossil energy sources
regex_dont_invest = '|'.join(dont_invest) #regular expression for energy sources that should not be invested in
regex_dont_consider = '|'.join(dont_consider) #regular expression for all technologies that should not be considered in the model
regex_endo_commodities = '|'.join(list_of_endo_commodities) #regular expression for endogenous commodities
regex_fuels = '|'.join(list_of_fuels) #regular expression for fuels

##### Read powerplant base data #####
print("Reading powerplants base datast from : " + str(df_pp_base_path) + "\n")

df_pp_base              = pd.read_excel(df_pp_base_path, sheet_name="powerplants")
#select only relevant columns
df_pp_base              = df_pp_base[['Countries', 'Alternative', 'technology', 'commodities_in', 'commodities_out', 'efficiencies', 'capacity', 'fomCosts_factor', 'vomCosts', 'Lifetime', 'reg_fac', "unit_ramp"]]
#unit being defined as input commodity and technology
df_pp_base["unit"] = df_pp_base["commodities_in"] + '|' + df_pp_base["technology"]
#name being defined as unit and country
df_pp_base["name"] = df_pp_base["unit"] + '|' + df_pp_base["Countries"]

#define maxRampUp and maxRampDown as max_ramp from Base data
df_pp_base["maxRampUp"] = df_pp_base["unit_ramp"]
df_pp_base["maxRampDown"] = df_pp_base["unit_ramp"]
#remove unit_ramp column
df_pp_base = df_pp_base.drop(columns=["unit_ramp"])

#define UnitSize as 1 MW for all technologies
df_pp_base["UnitSize"] = 1

#define conversionCoeff for all non-vre technologies as 1
df_pp_base["conversionCoeff"] = np.nan
df_pp_base.loc[~df_pp_base["commodities_in"].str.contains(regex_vre), "conversionCoeff"] = 1

#create alpha-3 help dataframe
subset_countries_l = df_pp_base[["Countries"]].drop_duplicates().reset_index(drop=True)
subset_countries_l['continent']   = subset_countries_l['Countries'].str.split('-',expand=True)[0]
subset_countries_l['alpha-3']     = subset_countries_l['Countries'].str.split('-',expand=True)[1]
subset_countries_l['subregion']     = subset_countries_l['Countries'].str.split('-',expand=True)[2]
#drop all rows with existing subregion values
subset_countries_l = subset_countries_l.drop(subset_countries_l[~subset_countries_l['subregion'].isna()].index).reset_index(drop=True)

##### Read WACC data #####
print("Reading WACC dataset from : " + str(path_WACC_Update) + "\n")

# get WACC data
df_WACC = pd.read_csv(path_WACC_Update, sep=';')[['Countries', 'WACC','unit']]
df_WACC['unit'] = df_WACC['unit'].str.replace('WIND_OFFSHOREInvest','Wind_Offshore')
df_WACC['unit'] = df_WACC['unit'].str.replace('WIND_ONSHOREInvest','Wind_Onshore')
df_WACC['unit'] = df_WACC['unit'].str.replace('PVInvest','PV')
df_WACC['unit'] = df_WACC['unit'].str.replace('Biomass','Biomass|Biomass')
df_WACC['unit'] = df_WACC['unit'].str.replace('Coal','Coal|Coal')
df_WACC['unit'] = df_WACC['unit'].str.replace('Oil','Oil|Oil')
df_WACC['unit'] = df_WACC['unit'].str.replace('Nuclear','Nuclear|Nuclear')
df_WACC['name'] = df_WACC['unit'] + '|' + df_WACC['Countries']

df_pp_base = df_pp_base.merge(df_WACC[['name', 'WACC']], on=['name'], how='left')

#calculate annuity factor using the formula: (WACC * (1 + WACC) ** lifetime) / ((1 + WACC) ** lifetime - 1)

df_pp_base['annuityFactor'] = (df_pp_base['WACC'] * (1 + df_pp_base['WACC']) ** df_pp_base['Lifetime']) / ((1 + df_pp_base['WACC']) ** df_pp_base['Lifetime'] - 1)

##### Split dataframe into VRE and non-VRE for potential handling #####

df_pp_base_og   = df_pp_base.copy()
df_pp_base_vre  = df_pp_base[df_pp_base["commodities_in"].isin(list_of_vre)]
df_pp_base      = df_pp_base[~df_pp_base["commodities_in"].isin(list_of_vre)]

#define maxUnitCount for non-VRE technologies as inf
df_pp_base['maxUnitCount'] = 'inf'

##### Prepare VRE data #####
print("Reading VRE potential data from : " + str(path_RE_1dim_data) + "\n")

#read potential data
df_VRE_potential    = pd.read_csv(path_RE_1dim_data, sep = ';')
#select only relevant rows with Parameter_name = candidate_units
df_VRE_potential    = df_VRE_potential[df_VRE_potential['Parameter_name'] == 'candidate_units']
df_VRE_potential    = df_VRE_potential.rename(columns={'Paramter_value': 'maxUnitCount'})
#select only relevant columns
df_VRE_potential    = df_VRE_potential[['Object_names', 'Alternative', 'maxUnitCount']]
df_VRE_potential['Object_names'] = df_VRE_potential['Object_names'].str.replace('WINDI','Wind_OnshoreI')
df_VRE_potential['Object_names'] = df_VRE_potential['Object_names'].str.replace('WIND_OFFSHORE','Wind_Offshore')

#Scale maxUnitCount value to MW
df_VRE_potential['maxUnitCount'] = df_VRE_potential['maxUnitCount'] * 1000
#cut off after comma
df_VRE_potential['maxUnitCount'] = df_VRE_potential['maxUnitCount'].astype(int)

#fix alpha-3 info by merging with subset_countries_l
df_VRE_potential["alpha-3"] = df_VRE_potential["Object_names"].str.split('|',expand=True)[2]
df_VRE_potential = df_VRE_potential.merge(subset_countries_l[['Countries', 'alpha-3']], on='alpha-3', how='left')

#define name as Object_names without "Invest" and the number after "Invest"
df_VRE_potential['name'] = df_VRE_potential['Object_names'].str.replace('Invest', '')
df_VRE_potential['name'] = df_VRE_potential['name'].str.replace(r'\d+', '', regex=True)
#delete the last of the three | divided string elements in name column
df_VRE_potential['name'] = df_VRE_potential['name'].str.split('|',expand=True)[0] + '|' + df_VRE_potential['name'].str.split('|',expand=True)[1] + '|' + df_VRE_potential['Countries']
df_VRE_potential['Object_names'] = df_VRE_potential['Object_names'].str.split('|',expand=True)[0] + '|' + df_VRE_potential['Object_names'].str.split('|',expand=True)[1] + '|' + df_VRE_potential['Countries']
df_VRE_potential = df_VRE_potential.drop(columns=['Countries', 'alpha-3'])

#merge Base VRE data to new VRE Investment Units
df_pp_base_vre = df_VRE_potential.merge(df_pp_base_vre, on=['name', 'Alternative'], how='left')

##### Read Scenario data #####
print("Reading scenario data from : " + str(dir_scenario_data) + "\n")

df_loop_all = pd.DataFrame()
df_CO2_all = pd.DataFrame()

def mymelt(df):

    numeric_columns = df.select_dtypes('number').columns
    non_numeric_columns = df.select_dtypes(exclude=['number']).columns.to_list()

    numeric_columns = df.select_dtypes('number').columns
    non_numeric_columns = df.select_dtypes(exclude=['number']).columns.to_list()
    df_melt = df.melt(value_vars=numeric_columns,id_vars=non_numeric_columns, var_name='Year',value_name='Parameter_value')
    return df_melt

# Loop over all files in the scenario data directory
for filename in os.listdir(dir_scenario_data):
    if filename.endswith(".xlsx") or filename.endswith(".xls"):
        # Construct the full file path
        file_path = os.path.join(dir_scenario_data, filename)
        
        # Read the "costs" and "co2" sheet from the Excel file
        df_invest_scen_source = pd.read_excel(file_path, sheet_name="costs")
        df_CO2_scen_source = pd.read_excel(file_path, sheet_name="co2-budget")
        df_CO2_scen_source = df_CO2_scen_source.rename(columns={df_CO2_scen_source.columns[0]: 'Countries'})
        
        df_loop = mymelt(df_invest_scen_source)
        df_loop['Scenario'] = filename.replace('_scenario_data.xlsx','').split(' - ')[1]
        df_CO2_scen_source['Scenario'] = filename.replace('_scenario_data.xlsx','').split(' - ')[1]
        print(filename + "\n")

        # Append the dataframe to the list
        df_loop_all = pd.concat([df_loop_all, df_loop], ignore_index=True)
        df_CO2_all = pd.concat([df_CO2_all, df_CO2_scen_source], ignore_index=True)

#%%
##### prepare CO2 data for export #####
print("Preparing CO2 emission budget df" + "\n")

#transform CO2 data to long format
df_CO2_melt = df_CO2_all.melt(
    value_vars=df_CO2_all.select_dtypes(include = 'number')
    .columns,id_vars=df_CO2_all.select_dtypes(exclude='number')
    .columns.to_list(), var_name='Year',value_name='Parameter_value') #from wide to long

df_CO2_melt['Alternative'] = df_CO2_melt['Scenario'] + '_' + df_CO2_melt['Year'].astype(str)
df_CO2_melt = df_CO2_melt.merge(subset_countries, on='Countries', how='left')
df_CO2_melt = df_CO2_melt.groupby(['Regions','Alternative']).agg({'Parameter_value':'sum'}).reset_index()
df_CO2_melt["Regional_emissions"] = df_CO2_melt["Regions"] + "_CO2" #add CO2 to Regions
df_CO2_melt['Parameter_value'] = df_CO2_melt['Parameter_value'] * 10**6 * modeled_duration_in_years #scale scenario data (Mt) to Backbone (t) and to modeling horizon

##### prepare invest data for concatenation #####
print("Perform string magic to unify nomenclature and prepare datasets for concatenation" + "\n")

df_pp_invest_scen = df_loop_all.copy()
#only use relevant columns
df_pp_invest_scen = df_pp_invest_scen[['CountryCode', 'Object_names_1', 'Parameter_name', 'Year', 'Parameter_value', 'Scenario']]
df_pp_invest_scen = df_pp_invest_scen.rename(columns={'CountryCode': 'Countries', 'Object_names_1': 'name'})
#string magic to fix non pp commodities
df_pp_invest_scen['name'] = df_pp_invest_scen['name'].str.replace('h2_OCGT','h2|OCGT')
#filter for all powerplant technologies
df_pp_invest_scen["Year"] = df_pp_invest_scen["Year"].str.replace('Parameter_value_', '')
df_pp_invest_scen["Alternative"] = df_pp_invest_scen["Scenario"] + '_' + df_pp_invest_scen["Year"].astype(str)
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('w/o CCS|', '')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('GAS', 'Gas')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Coal', 'Coal|Coal')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Oil', 'Oil|Oil')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Nuclear', 'Nuclear|Nuclear')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Biomass', 'Biomass|Biomass')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Onshore', 'Wind_Onshore')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Offshore', 'Wind_Offshore')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('CSP', 'Solar|CSP')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Hydro', 'Hydro|Hydro')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Desalination', 'h2o|Desalination')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('Electrolyzer', 'el|Electrolyzer')
df_pp_invest_scen["name"] = df_pp_invest_scen["name"].str.replace('fuel_cell', 'h2|FuelCell')
df_pp_invest_scen["commodities_in"] = df_pp_invest_scen["name"].str.split('|',expand=True)[0]
df_pp_invest_scen["technology"] = df_pp_invest_scen["name"].str.split('|',expand=True)[1]
df_pp_invest_scen["name"] = df_pp_invest_scen["commodities_in"] + '|' + df_pp_invest_scen["technology"] + '|' + df_pp_invest_scen["Countries"]
df_pp_invest_scen = df_pp_invest_scen[df_pp_invest_scen['name'].str.contains(regex_all_commodities)]
df_pp_invest_scen = df_pp_invest_scen[~df_pp_invest_scen['name'].str.contains(regex_dont_consider)]

#transform long format to wide format for Parameter_names
df_pp_invest_scen = df_pp_invest_scen.pivot_table(index=['Countries', 'name', 'Alternative', 'commodities_in', 'technology'], columns='Parameter_name', values='Parameter_value').reset_index()

##### apply scenario data to df_pp_base_vre #####

#merging the invest data to the df_pp_base_vre dataframe while retaining each Alternative via matrix multiplication

df_vre_invest_names = df_pp_base_vre[["Object_names"]].drop_duplicates().reset_index(drop=True)
df_invest_scen_names = df_pp_invest_scen[["Alternative"]].drop_duplicates().reset_index(drop=True)
#add Base as Alternative to invest scenario names
#df_invest_scen_names = pd.concat([df_invest_scen_names, pd.DataFrame({'Alternative': ['Base']})], ignore_index=True)
#combine the two dataframes
df_cross_names = df_vre_invest_names.merge(df_invest_scen_names, how='cross')
df_cross_names['name'] = df_cross_names['Object_names'].str.replace('Invest', '')
df_cross_names['name'] = df_cross_names['name'].str.replace(r'\d+', '', regex=True)

df_pp_invest_scen_cross = df_cross_names.merge(df_pp_invest_scen[["Alternative", "name", "unit_investment_cost"]], on=['Alternative', 'name'], how='left')

#concat df_pp_invest_scen_cross to df_pp_base_vre
# print("The following columns are different: " + str(set(df_pp_base_vre.columns) - set(df_pp_invest_scen_cross.columns)) + "\n")
df_pp_vre = pd.concat([df_pp_base_vre, df_pp_invest_scen_cross], axis=0, ignore_index=True)
df_pp_vre["commodities_in"] = df_pp_vre["name"].str.split('|',expand=True)[0]

##### apply scenario data to df_pp_base #####

#filter for all non vre technologies
df_invest_scen_non_vre = df_pp_invest_scen[~df_pp_invest_scen['name'].str.contains(regex_vre)]

df_pp = pd.concat([df_pp_base, df_invest_scen_non_vre], axis=0, ignore_index=True)
df_pp["Object_names"] = df_pp["name"]

##### parallelyze the dataframes #####

#examine column difference between df_pp_base and df_pp_base_vre
print("The following columns are different: " + str(set(df_pp_base.columns) - set(df_pp_base_vre.columns)) + "\n")

##### concatenate the two dataframes back together #####
df_pp_complete = pd.concat([df_pp, df_pp_vre], axis=0, ignore_index=True)
df_pp_complete["Countries"] = df_pp_complete["name"].str.split('|',expand=True)[2]

#raise commodities, fomCosts_factor and reg_fac to all scenarios to calculate fomCosts later
df_pp_complete = df_pp_complete.drop(columns=['fomCosts_factor', "reg_fac", "commodities_in", "commodities_out"])
df_pp_complete = df_pp_complete.merge(df_pp_base_og[["name", "commodities_out", "fomCosts_factor", "reg_fac"]], on='name', how='left')
df_pp_complete["commodities_in"] = df_pp_complete["name"].str.split('|',expand=True)[0]

##### aggregate df_pp_complete to get the final dataframe #####
df_pp_complete = df_pp_complete.merge(subset_countries, on='Countries', how='left')
df_pp_complete["unit_name_aggregation"] = df_pp_complete["Object_names"].str.split('|',expand=True)[0] + '|' + df_pp_complete["Object_names"].str.split('|',expand=True)[1] + '|' + df_pp_complete["Regions"]
df_pp_complete = df_pp_complete.rename(columns={'unit_investment_cost': 'invCosts', "fuel_cost": "fuel_prices"}) 

#drop all rows without Regions
df_pp_complete = df_pp_complete.dropna(subset=['Regions'])

#calculate the fomCosts from fomCosts_factor and invCosts
print("Calculate fomCosts" + "\n")
df_pp_complete['fomCosts'] = df_pp_complete['invCosts'] * df_pp_complete['fomCosts_factor'] * (1 + df_pp_complete["reg_fac"])
#integrate system_integration_factor for VRE technologies
df_pp_complete.loc[df_pp_complete["unit_name_aggregation"].str.contains(regex_vre), "fomCosts"] = df_pp_complete.loc[df_pp_complete["unit_name_aggregation"].str.contains(regex_vre), "fomCosts"] * system_integration_factor

#non powerplant technologies dont have annuityFactor to recalculate fomCosts - therefore Base remains - #todo

#%%
print("Perform geographic aggregation" + "\n")
df_pp_complete_agg = df_pp_complete.groupby(['unit_name_aggregation', 'Alternative', "Regions"]).agg(
    {'technology': 'first', 'efficiencies': 'mean', 'capacity': 'sum', 'fomCosts': 'mean', 'vomCosts': 'mean', 'Lifetime': 'mean', "commodities_in":"first",
     'commodities_out':"first", 'UnitSize': 'first', 'conversionCoeff': 'first', 'maxRampUp': 'mean', 'maxRampDown': 'mean', 'maxUnitCount': 'sum',
     'WACC': 'first', 'annuityFactor': 'mean', "fuel_prices":"mean", "invCosts":"mean"}).reset_index()

#correct the maxUnitCount aggregation problem for INF values
df_pp_complete_agg.loc[df_pp_complete_agg["maxUnitCount"].astype(str).str.contains("inf"), "maxUnitCount"] = "inf"

print("Define grids, nodes and care for special non powerplant technologies " + "\n")
#set np.nan values where df_pp_complete_agg["maxUnitCount"] == 0
df_pp_complete_agg["maxUnitCount"] = df_pp_complete_agg["maxUnitCount"].replace(0, np.nan)

#define commodities_out for non powerplant units
df_pp_complete_agg.loc[df_pp_complete_agg["technology"] == "Electrolyzer", "commodities_out"] = "h2"
df_pp_complete_agg.loc[df_pp_complete_agg["technology"] == "FuelCell", "commodities_out"] = "el"
df_pp_complete_agg.loc[df_pp_complete_agg["technology"] == "OCGT", "commodities_out"] = "el"

#fill the input_output columns with input as base value und overwrite all electricity producing units with output
df_pp_complete_agg["node_out"] = df_pp_complete_agg["Regions"] + "_el"

#first define output direction
df_pp_complete_agg["grid_out"] = df_pp_complete_agg["commodities_out"].str.replace("el", "elec")
df_pp_complete_agg["node_out"] = df_pp_complete_agg["Regions"] + '_' + df_pp_complete_agg["commodities_out"] 
df_pp_complete_agg["grid_in"] = df_pp_complete_agg["commodities_in"].str.replace("el", "elec")
#rename grid to fuel for all non VRE technologies
df_pp_complete_agg["node_in"] =  df_pp_complete_agg["Regions"] + '_' + df_pp_complete_agg["commodities_in"]  
#for all grid_in that are not endogenous commodities nor VRE, set grid_in to fuel and that are neither vre
df_pp_complete_agg.loc[~df_pp_complete_agg["grid_in"].fillna('').str.contains(regex_endo_commodities + "|" + regex_vre), "grid_in"] = df_pp_complete_agg.loc[~df_pp_complete_agg["grid_in"].fillna('').str.contains(regex_endo_commodities+"|" + regex_vre), "commodities_in"]
df_pp_complete_agg.loc[df_pp_complete_agg["unit_name_aggregation"].fillna('').str.contains(regex_fuels), "grid_in"] = "fuel"
#drop rows where 

#%%
df_pp_complete_agg.loc[df_pp_complete_agg["technology"] == "Electrolyzer", "node_out"] = df_pp_complete_agg.loc[df_pp_complete_agg["technology"] == "Electrolyzer", "Regions"] + "_h2"

### ToDo
# #if in any case the capacity exceeds the maxUnitCount, print "Error"
# if ((df_pp_complete_agg["maxUnitCount"].fillna(0) - df_pp_complete_agg["capacity"].fillna(0)) < 0).any():
#     problematic_rows = df_pp_complete_agg[df_pp_complete_agg["maxUnitCount"].fillna(0) < df_pp_complete_agg["capacity"].fillna(0)]
#     print("Error: maxUnitCount < capacity for the following rows:")
#     print(problematic_rows)
#     raise ValueError("maxUnitCount is less than capacity in some rows. Please check the data.")

if 1 == 2:
    print("To much installed initial capacity" + "\n")
else:
    #set capacity for all VRE technologies but Invest0 to 0.001
    df_pp_complete_agg.loc[(df_pp_complete_agg["commodities_in"].str.contains(regex_vre) & (~df_pp_complete_agg["unit_name_aggregation"].str.contains("Invest0"))), "capacity"] = eps

# Fuel unit_node
print("Create fuel nodes df" + "\n")
# Create Data Frame for to map commodity to fuel prices
fuel_nodes = df_pp_complete_agg[["Regions", "Alternative", "commodities_in", "commodities_out", "fuel_prices"]].drop_duplicates().reset_index(drop=True)
# read default values from MainInput.xlsx
for commodity in list_of_fuels:
    fuel_nodes.loc[(fuel_nodes['commodities_in'] == commodity) & (fuel_nodes['Alternative'] == "Base"), 'fuel_prices'] = float(m_conf.Value[(m_conf["Parameter"] == "fuel_prices") & (m_conf["Object"] == commodity)].values[0])
#use only non endogenous commodities and non vre technologies
fuel_nodes = fuel_nodes[~fuel_nodes['commodities_in'].str.contains(regex_endo_commodities)]
fuel_nodes = fuel_nodes[~fuel_nodes['commodities_in'].str.contains(regex_vre)]
fuel_nodes["usePrice"] = 1
#fuel_nodes without price dont usePrice
fuel_nodes.loc[fuel_nodes['fuel_prices'].isna(), 'usePrice'] = 0
#manually set Biomass rows to 0 until it is incorporated into scenario data
fuel_nodes.loc[fuel_nodes['commodities_in'] == "Biomass", 'usePrice'] = 1
fuel_nodes['nodeBalance'] = 0
#clean up dataframe and drop duplicates and rows without parameter values
fuel_nodes = fuel_nodes.drop_duplicates().reset_index(drop=True)
fuel_nodes = fuel_nodes.dropna(subset=['fuel_prices'])
fuel_nodes["nodes"] = fuel_nodes["Regions"] + "_" + fuel_nodes["commodities_in"]

print("Create emission factors df" + "\n")
emission_factors = m_conf[m_conf['Parameter'] == 'emission_factor'].reset_index(drop=True)
emission_factors = emission_factors.rename(columns={'Object':'commodities_in'})
emission_factors = emission_factors.merge(fuel_nodes[["commodities_in", "Regions"]].drop_duplicates(), how='inner', on='commodities_in')
emission_factors["regional_emissions"] = emission_factors["Regions"] + "_CO2"
emission_factors["emission_node"] = emission_factors["Regions"] + "_" + emission_factors["commodities_in"]

#defining ts_emissionPrice EUR/tEmission
print("Create emission tax df" + "\n")
emission_tax = m_conf[m_conf['Parameter'] == 'emission_tax'].reset_index(drop=True)
emission_tax = emission_tax.rename(columns={"Alternative":"Alternative names", "Value":"emission_tax_val"})
#new df emission_tax_m that projects emission_tax to regional_emissions in df emission_factors
regional_emissions_df = pd.DataFrame()
regional_emissions_df["emission"] = emission_factors["regional_emissions"]
#Add a temporary key to both dataframes
emission_tax['key'] = 1
regional_emissions_df['key'] = 1
#Perform the cross join using merge
emission_tax_m = pd.merge(emission_tax, regional_emissions_df, on='key').drop('key', axis=1)
emission_tax_m = emission_tax_m.drop_duplicates()

#%%
##### prepare Backbone export #####
print("Prepare Backbone export dfs for the different dimensions" + "\n")

#dim0
## get units from df_pp_complete_agg
initial_dim0_values     = pd.DataFrame({'Object class names':['grid','group'],'Object names':['fuel','fuelGroup']})
unit                    = pd.DataFrame({"Object class names":"unit", "Object names":df_pp_complete_agg.unit_name_aggregation})
#node                    = pd.DataFrame({"Object class names":"node", "Object names":fuel_nodes.commodities_in.unique()})
emission                = pd.DataFrame({"Object class names":"emission", "Object names":df_CO2_melt["Regional_emissions"].unique()})

bb_dim_0_initialization = pd.concat([initial_dim0_values, unit, emission], axis=0, ignore_index=True) #node,
bb_dim_0_initialization = bb_dim_0_initialization.drop_duplicates()

#bb_dim_1_relationship_dtype_str - maxUnitCount, eff00, availability, 
columns_1d = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter values']

maxUnitCount            = pd.DataFrame({"Object class names":"unit", "Object names":df_pp_complete_agg.unit_name_aggregation, "Parameter names":"maxUnitCount", "Alternative names":"Base", "Parameter values":df_pp_complete_agg.maxUnitCount})
eff00                   = pd.DataFrame({"Object class names":"unit", "Object names":df_pp_complete_agg.unit_name_aggregation, "Parameter names":"eff00", "Alternative names":"Base", "Parameter values":df_pp_complete_agg.efficiencies})
availability            = pd.DataFrame({"Object class names":"unit", "Object names":df_pp_complete_agg.unit_name_aggregation, "Parameter names":"availability", "Alternative names":"Base", "Parameter values":1})

bb_dim_1_relationship   = pd.concat([maxUnitCount, eff00, availability], axis=0, ignore_index=True)
bb_dim_1_relationship   = bb_dim_1_relationship.drop_duplicates()
#drop all rows with NaN values in the Parameter values column
bb_dim_1_relationship = bb_dim_1_relationship.dropna(subset=['Parameter values'])

#bb_dim_1_map - becomeAvailable, priceChange
columns_1d_map = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values']

becomeAvailable         = pd.DataFrame({"Object class names":"unit", "Object names":df_pp_complete_agg.unit_name_aggregation, "Parameter names":"becomeAvailable", "Alternative names":"Base", "Parameter indexes":"t000001", "Parameter values":1})
priceChange             = pd.DataFrame({"Object class names":"node", "Object names":fuel_nodes["nodes"], "Parameter names":"priceChange", "Alternative names":fuel_nodes["Alternative"], "Parameter indexes":"t000000", "Parameter values":fuel_nodes["fuel_prices"]})

bb_dim_1_relationship_map = pd.concat([becomeAvailable, priceChange], axis=0, ignore_index=True)
bb_dim_1_relationship_map = bb_dim_1_relationship_map.drop_duplicates()

#bb_dim_2 nodeBalance, energyStoredPerUnitOfState, usePrice, emissionCap
columns_2d = ['Relationship class names', 'Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter values']
columns_2d_map = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values']

nodeBalance            = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":"fuel", "Object names 2":fuel_nodes["nodes"], "Parameter names":"nodeBalance", "Alternative names":fuel_nodes["Alternative"], "Parameter values":fuel_nodes["nodeBalance"]})
energyStoredPerUnitOfState = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":"fuel", "Object names 2":fuel_nodes["nodes"], "Parameter names":"energyStoredPerUnitOfState", "Alternative names":fuel_nodes["Alternative"], "Parameter values":0})
usePrice               = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":"fuel", "Object names 2":fuel_nodes["nodes"], "Parameter names":"usePrice", "Alternative names":fuel_nodes["Alternative"], "Parameter values":fuel_nodes["usePrice"]})
emissionCap            = pd.DataFrame({"Relationship class names":"group__emission", "Object class names 1":"group", "Object class names 2":"emission", "Object names 1":"fuelGroup", "Object names 2":df_CO2_melt["Regional_emissions"], "Parameter names":"emissionCap", "Alternative names":df_CO2_melt.Alternative, "Parameter values":df_CO2_melt.Parameter_value})
p_nEmission = pd.DataFrame({"Relationship class names":'node__emission', "Object class names 1":'node', "Object class names 2":'emission', "Object names 1":emission_factors["emission_node"], "Object names 2":emission_factors["regional_emissions"], "Parameter names":'emission_content', "Alternative names":emission_factors["Alternative"], "Parameter values":emission_factors["Value"]})

#flowunit
values_fu = ['flow__unit','flow','unit','solarWindOnWindOff','unitXXX','','','']
template_fu = pd.DataFrame(dict(zip(columns_2d, values_fu)), index=range(len(df_pp_complete_agg[df_pp_complete_agg['commodities_in'].str.contains(regex_vre)])))
## creating and assigning flowUnit
df_zuordnung_flow = df_pp_complete_agg[df_pp_complete_agg['commodities_in'].str.contains(regex_vre)][["unit_name_aggregation", "Regions", "commodities_in"]].reset_index(drop = True)
df_zuordnung_flow[["commodities_in", 'technology', "Regions"]] = pd.DataFrame(df_zuordnung_flow["unit_name_aggregation"].str.split('|',expand=True))
df_zuordnung_flow["flow"] = df_zuordnung_flow["commodities_in"] + '|' + df_zuordnung_flow["technology"]
#df_zuordnung_flow["flow"] = df_zuordnung_flow["commodities_in"] + '|' + df_zuordnung_flow["Regions"]

bb_dim_2_flowUnit = template_fu.assign(**{'Object names 1':df_zuordnung_flow["flow"],'Object names 2':df_zuordnung_flow['unit_name_aggregation']})

bb_dim_2_relationship = pd.concat([nodeBalance, energyStoredPerUnitOfState, usePrice, emissionCap, p_nEmission, bb_dim_2_flowUnit], axis=0, ignore_index=True)
bb_dim_2_relationship = bb_dim_2_relationship.drop_duplicates()

#implement CO2 taxation
bb_dim_2_map_ts_emissionPriceChange = pd.DataFrame({'Relationship class names':"group__emission",'Object class names 1':"group",'Object class names 2':"emission",'Object names 1':"fuelGroup",'Object names 2':emission_tax_m['emission'],'Parameter names':'emissionPrice','Alternative names':emission_tax_m['Alternative names'],'Parameter indexes':"t000000",'Parameter values':emission_tax_m['emission_tax_val']})
bb_dim_2_relationship_map = pd.concat([bb_dim_2_map_ts_emissionPriceChange],ignore_index=True)
bb_dim_2_relationship_map = bb_dim_2_relationship_map.drop_duplicates()

#bb_dim_3 eff_Level, fuelGroup
columns_3d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object names 1','Object names 2','Object names 3','Parameter names','Alternative names','Parameter values']

#%%
#effLevelGroupUnit
##flow units dont have eff_group
df_eff_non_vre_units = df_pp_complete_agg[~df_pp_complete_agg['commodities_in'].str.contains(regex_vre)][["unit_name_aggregation", "Regions", "commodities_in"]].reset_index(drop = True)

bb_dim_3_effLevelGroupUnit = pd.DataFrame(index=range(len(df_eff_non_vre_units)*3), columns=columns_3d)
bb_dim_3_effLevelGroupUnit = bb_dim_3_effLevelGroupUnit.assign(**{'Relationship class names':'effLevel__effSelector__unit', 'Object class names 1':'effLevel', 'Object class names 2':'effSelector', 'Object class names 3':'unit', 'Object names 1':['level1','level2','level3']*len(df_eff_non_vre_units), 'Object names 2':'directOff', 'Object names 3':(pd.concat([df_eff_non_vre_units['unit_name_aggregation']]*3,ignore_index=True)).sort_values(ignore_index=True)})
bb_dim_3_gnGroup = pd.DataFrame(index=range(len(fuel_nodes["nodes"].unique())), columns=columns_3d).assign(**{'Relationship class names':'grid__node__group', 'Object class names 1':'grid', 'Object class names 2':'node', 'Object class names 3':'group', 'Object names 1':'fuel', 'Object names 2': fuel_nodes["nodes"].unique(), 'Object names 3':'fuelGroup'})

bb_dim_3_relationship = pd.concat([bb_dim_3_effLevelGroupUnit,bb_dim_3_gnGroup],ignore_index=True)
bb_dim_3_relationship = bb_dim_3_relationship.drop_duplicates()

#%%
#dim4 p_gnu_io -> conversionCoeff, capacity, unitSize, invCosts, fomCosts, vomCosts, annuityFactor, upperLimitCapacityRatio
columns_4d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object class names 4','Object names 1','Object names 2','Object names 3','Object names 4','Parameter names','Alternative names','Parameter values']

#implementing the parameters for p_gnu_io that are not scenario dependent
#defining help Base df
df_pp_agg_gnu_io_base = df_pp_complete_agg[df_pp_complete_agg["Alternative"] == "Base"]
annuityFactor = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"annuityFactor", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["annuityFactor"]})
capacity = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"capacity", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["capacity"]})
unitSize = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"unitSize", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["UnitSize"]})
conversionCoeff_out = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"conversionCoeff", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["conversionCoeff"]})
conversionCoeff_in = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_in"], "Object names 2":df_pp_agg_gnu_io_base["node_in"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"input", "Parameter names":"conversionCoeff", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["conversionCoeff"]})
#VRE do not possess input side or conversionCoeff_in
conversionCoeff_in = conversionCoeff_in[~conversionCoeff_in['Object names 3'].str.contains(regex_vre)]
conversionCoeff = pd.concat([conversionCoeff_out, conversionCoeff_in], axis=0, ignore_index=True)
maxRampUp = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"maxRampUp", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["maxRampUp"]})
maxRampDown = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"maxRampDown", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["maxRampDown"]})
vomCosts = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_agg_gnu_io_base["grid_out"], "Object names 2":df_pp_agg_gnu_io_base["node_out"], "Object names 3":df_pp_agg_gnu_io_base["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"vomCosts", "Alternative names":"Base", "Parameter values":df_pp_agg_gnu_io_base["vomCosts"]})

#implementing the parameters for p_gnu_io that are scenario dependent
fomCosts = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_complete_agg["grid_out"], "Object names 2":df_pp_complete_agg["node_out"], "Object names 3":df_pp_complete_agg["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"fomCosts", "Alternative names":df_pp_complete_agg["Alternative"], "Parameter values":df_pp_complete_agg["fomCosts"]})
invCosts = pd.DataFrame({"Relationship class names":"grid__node__unit__io", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"unit", "Object class names 4":"io", "Object names 1":df_pp_complete_agg["grid_out"], "Object names 2":df_pp_complete_agg["node_out"], "Object names 3":df_pp_complete_agg["unit_name_aggregation"], "Object names 4":"output", "Parameter names":"invCosts", "Alternative names":df_pp_complete_agg["Alternative"], "Parameter values":df_pp_complete_agg["invCosts"]})

bb_dim_4_relationship = pd.concat([annuityFactor, invCosts, capacity, unitSize, conversionCoeff, maxRampUp, maxRampDown, vomCosts, fomCosts], axis=0, ignore_index=True)
bb_dim_4_relationship = bb_dim_4_relationship.drop_duplicates()

#%%
##### delete investment info for powerplants that shall not be invested in #####
print("Disable investment for powerplants that shall not be invested in :" + str(regex_dont_invest) + "\n")

bb_dim_1_relationship.loc[((bb_dim_1_relationship['Object names'].str.contains(regex_dont_invest)) & (bb_dim_1_relationship['Parameter names'] == 'maxUnitCount')), 'Parameter values'] = eps
bb_dim_4_relationship = bb_dim_4_relationship[~((bb_dim_4_relationship['Object names 3'].str.contains(regex_dont_invest)) & (bb_dim_4_relationship['Parameter names'].isin(['annuityFactor','invCosts'])))].reset_index(drop=True)
bb_dim_4_relationship.loc[
    (bb_dim_4_relationship['Parameter names'] == 'capacity') &
    (bb_dim_4_relationship['Parameter values'] == eps) &
    (bb_dim_4_relationship['Object names 3'].str.contains(regex_dont_invest)) &
    (bb_dim_4_relationship['Object names 4'] == 'output'),
    'Parameter values'] = eps

## Set small capacities to zero to prevent numerical problems
bb_dim_4_relationship.loc[
    (bb_dim_4_relationship['Parameter names'] == 'capacity') &
    (bb_dim_4_relationship['Parameter values'] <  50) &
    (bb_dim_4_relationship['Object names 4'] == 'output'),
    'Parameter values'] = eps

#### Adding the constraints for the Delegated Act for RFNBOs ####
print("Apply RFNBO options: " + str(RFNBO_option) + "\n")

if RFNBO_option == "Vanilla":
    bb_dim_4_relationship = bb_dim_4_relationship.drop_duplicates()
    print("Base model without any RFNBO modifications" + "\n")

#No_reg scenario is the base scenario that only applies the definition for renewable electricity from RED for the production of green hydrogen
if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #reassining renewable electricity units to the new renewable electricity node in p_gnu_io
    combined_regex = f"{regex_renewables}|{regex_h2_assets}"
    mask = bb_dim_4_relationship['Object names 3'].str.contains(combined_regex, regex=True) #and bb_dim_4_relationship["Object names 4"] == "output"
    bb_dim_4_relationship.loc[mask, 'Object names 2'] = bb_dim_4_relationship.loc[mask, 'Object names 2'].str.replace('_el', '_re_el')
    bb_dim_4_relationship = bb_dim_4_relationship.drop_duplicates()

#%%
#The Island Grid scenario models the RFNBOs as island grids by forcing the model to invest in addtional and separate renewable powerplants for the RFNBOs. Existing renewable powerplants are not allowed to be used for RFNBOs.
if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"
    #copying the renewable powerplants and add the suffix "add" to the Object names 3 to identify them as additional renewable powerplants
    bb_dim_0_initialization_re = bb_dim_0_initialization[bb_dim_0_initialization['Object names'].str.contains(regex_renewables_nbo or regex_h2_assets)].reset_index(drop=True)
    bb_dim_0_initialization_re["Object names"] = bb_dim_0_initialization_re["Object names"] + "_add"

    #adding the additional renewable powerplant units to the normal units in unit
    bb_dim_0_initialization = pd.concat([bb_dim_0_initialization, bb_dim_0_initialization_re], ignore_index=True)

    #copying the renewable powerplants and add the suffix "add" to the Object names 3 to identify them as additional renewable powerplants
    bb_dim_1_relationship_re = bb_dim_1_relationship[bb_dim_1_relationship['Object names'].str.contains(regex_renewables_nbo or regex_h2_assets)].reset_index(drop=True)
    bb_dim_1_relationship_re["Object names"] = bb_dim_1_relationship_re["Object names"] + "_add"

    #setting maxUnitCount to 0 for the original renewable powerplants so that only the additional ones can be invested in
    bb_dim_1_relationship.loc[bb_dim_1_relationship['Object names'].str.contains(regex_renewables_nbo or regex_h2_assets), 'Parameter values'] = eps

    #adding the additional renewable powerplant units to the normal units in p_unit
    bb_dim_1_relationship = pd.concat([bb_dim_1_relationship, bb_dim_1_relationship_re], ignore_index=True)

    #copying the renewable powerplants and adding the suffix "_add" to the Object names 3 to identify them as additional renewable powerplants
    bb_dim_1_relationship_dtype_map_re = bb_dim_1_relationship_map[bb_dim_1_relationship_map['Object names'].str.contains(regex_renewables_nbo or regex_h2_assets)].reset_index(drop=True)
    bb_dim_1_relationship_dtype_map_re_units = bb_dim_1_relationship_dtype_map_re[bb_dim_1_relationship_dtype_map_re["Object class names"] == "unit"].reset_index(drop=True)
    bb_dim_1_relationship_dtype_map_re_nodes = bb_dim_1_relationship_dtype_map_re[bb_dim_1_relationship_dtype_map_re["Object class names"] == "node"].reset_index(drop=True)
    bb_dim_1_relationship_dtype_map_re_units["Object names"] = bb_dim_1_relationship_dtype_map_re["Object names"] + "_add"
    bb_dim_1_relationship_dtype_map_re_nodes["Object names"] = bb_dim_1_relationship_dtype_map_re["Object names"].str.replace('_el','_re_el')

    #adding the additional renewable powerplant units to the normal units in p_fuelmap
    bb_dim_1_relationship_dtype_map = pd.concat([bb_dim_1_relationship_map, bb_dim_1_relationship_dtype_map_re_units, bb_dim_1_relationship_dtype_map_re_nodes], ignore_index=True)

    #copying the flow units and adding the suffix "_add" to the Object names 2 to identify them as additional flow units
    bb_dim_2_relationship_re = bb_dim_2_relationship[bb_dim_2_relationship["Relationship class names"] == "flow__unit"].reset_index(drop=True)
    bb_dim_2_relationship_re["Object names 2"] = bb_dim_2_relationship_re["Object names 2"] + "_add"

    #adding the island units to the normal units in p_flowUnit
    bb_dim_2_relationship = pd.concat([bb_dim_2_relationship, bb_dim_2_relationship_re], ignore_index=True)

    #copying the renewable powerplants and adding the suffix "_add" to the Object names 3 to identify them as additional renewable powerplants
    bb_dim_3_relationship_re = bb_dim_3_relationship[bb_dim_3_relationship['Object names 3'].str.contains(regex_renewables_nbo or regex_h2_assets)].reset_index(drop=True)
    bb_dim_3_relationship_re["Object names 3"] = bb_dim_3_relationship_re["Object names 3"] + "_add"

    #adding the island units to the normal units in eff_Level
    bb_dim_3_relationship = pd.concat([bb_dim_3_relationship, bb_dim_3_relationship_re], ignore_index=True)

    #Copying the renewable powerplants to the island nodes and adding the suffix "_re_el" to the Object names 2 to identifiy the renewable electricity node
    bb_dim_4_relationship_re = bb_dim_4_relationship[bb_dim_4_relationship['Object names 3'].str.contains(regex_renewables_nbo or regex_h2_assets)].reset_index(drop=True)
    bb_dim_4_relationship_re["Object names 2"] = bb_dim_4_relationship_re["Object names 2"].str.replace('_el','_re_el')
    #Renaming the renewable powerplants to identify them as additional renewable powerplants
    mask = bb_dim_4_relationship_re["Object names 4"] == "output"
    bb_dim_4_relationship_re.loc[mask, "Object names 3"] = (bb_dim_4_relationship_re.loc[mask, "Object names 3"] + "_add")

    #adding the island units to the normal units in p_gnu_io
    bb_dim_4_relationship = pd.concat([bb_dim_4_relationship, bb_dim_4_relationship_re], ignore_index=True)
    bb_dim_4_relationship = bb_dim_4_relationship.drop_duplicates()

#The Defossilized Grid option conducts a pre-solve without any hydrogen demand to determine the CO2 intensity of the system to then asses, whether the RFNBO production may use the grid electricity.
#The limits are either more then 90% of the electricity being renewable or the CO2 intensity being below 64.8 gCO2/kWh
if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid_prerun"
    #deleting all hydrogen related units and elements
    regex_hydrogen = 'H2|h2|hydrogen|Hydrogen|Desalination|Electrolyzer'
    bb_dim_0_initialization = bb_dim_0_initialization[~bb_dim_0_initialization['Object names'].str.contains(regex_hydrogen)].reset_index(drop=True)
    bb_dim_1_relationship = bb_dim_1_relationship[~bb_dim_1_relationship['Object names'].str.contains(regex_hydrogen)].reset_index(drop=True)
    bb_dim_1_relationship_map = bb_dim_1_relationship_map[~bb_dim_1_relationship_map['Object names'].str.contains(regex_hydrogen)].reset_index(drop=True)
    bb_dim_3_relationship = bb_dim_3_relationship[~bb_dim_3_relationship['Object names 3'].str.contains(regex_hydrogen)].reset_index(drop=True)
    bb_dim_4_relationship = bb_dim_4_relationship[~bb_dim_4_relationship['Object names 3'].str.contains(regex_hydrogen)].reset_index(drop=True)

if RFNBO_option == "Defossilized_Grid":
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

# introducing the limiting factors option
print("Apply limiting factors option :" + "\n")

if lim_fac_option == "Vanilla":
    
    print("Base model without any limiting factors" + "\n")

if lim_fac_option == "Base_case":
    #reading the limiting factors from the csv file
    
    lim_fac = pd.read_excel(path_lim_fac, sheet_name="cap_exp_lim")
    #aggregating the nodes if subset_countries contains values in column with the header "Regions"
    if len(subset_countries["Regions"]) != 0:
        print("Aggregation for lim_fac enabled" + "\n")
        #adding a column with the respective regions from subset_countries to new_nodes
        lim_fac["Regions"] = lim_fac["ISO3 code"].map(subset_countries.set_index("Countries_short")["Regions"])
        lim_fac_disag = lim_fac.copy()
        #aggregating the nodes by the regions and preparing lim fac for the parameter dataframe
        lim_fac = lim_fac.groupby(["Regions", "Year", "Technology"]).agg({"Electricity Installed Capacity (MW)":"sum", "capacity_added":"sum", "area_potential":"sum", "log_expol":"sum", "tech_potential":"sum"}).reset_index()
        #replace Solar photovoltaic with PV, Onshore wind energy with WIND_ONSHORE and Offshore wind energy with WIND_OFFSHORE
        lim_fac["Technology"] = lim_fac["Technology"].replace({"Solar photovoltaic":"PV", "Onshore wind energy":"WIND_ONSHORE", "Offshore wind energy":"WIND_OFFSHORE"})
        # fix merge issue with Base year
        lim_fac["Year"] = lim_fac["Year"].fillna(0).astype(int)
        # select all rows with the maxUnitCount parameter for Solar and Wind
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_relationship[bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") & (bb_dim_1_relationship["Parameter names"] == "maxUnitCount")].reset_index(drop=True)
        # split Alternative names at _ to get the year
        bb_dim_1_maxUnitCount_vre_work["Year"] = bb_dim_1_maxUnitCount_vre_work["Alternative names"].str.split("_").str[1].fillna(0).astype(int)
        bb_dim_1_maxUnitCount_vre_work["Regions"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[-1]
        bb_dim_1_maxUnitCount_vre_work["Tech"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[1]
        # split away InvestX in an individual column from the Tech name to isolate the technology
        bb_dim_1_maxUnitCount_vre_work["Invest"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[1]
        bb_dim_1_maxUnitCount_vre_work["Technology"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[0]
        #merge the lim_fac with the bb_dim_1_maxUnitCount_vre_work on the Regions, Year and Technology
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work.merge(lim_fac, how="left", on=["Regions", "Year", "Technology"])
        
        # Refactoring the maxUnitCount for the different invest levels
        bb_dim_1_maxUnitCount_vre_work["workset"] = (
            bb_dim_1_maxUnitCount_vre_work["Technology"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Year"].astype(str))
        
        bb_dim_1_maxUnitCount_vre_work["merge_base"] = bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" + bb_dim_1_maxUnitCount_vre_work["Technology"]

        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] == "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] != "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_base["maxUnitCount_sum_old"] = 0

        # Rename columns to avoid conflicts during merge
        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work_base.rename(columns={"Parameter values": "Parameter values_base", "maxUnitCount_sum_old": "maxUnitCount_sum_old_base"})
        # Merge Parameter values column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "Parameter values_base"]], on=["Invest", "merge_base"], how="left")
        
        # Merge maxUnitCount_sum_old column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "maxUnitCount_sum_old_base"]], on=["Invest", "merge_base"], how="left")

        #recombine bb_dim_1_maxUnitCount_vre_work_base and bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work_base, bb_dim_1_maxUnitCount_vre_work_scen], ignore_index=True).drop_duplicates()
         
        for workset in bb_dim_1_maxUnitCount_vre_work["workset"].unique():
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["workset"] == workset].reset_index(drop=True)
                        
            # Sum up the maxUnitCount for the different invest levels for each set of region, year and technology
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work_set.fillna(0)
            bb_dim_1_maxUnitCount_vre_work_set["maxUnitCount_sum_old_base"] = bb_dim_1_maxUnitCount_vre_work_set["Parameter values_base"].sum()

            bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work[~bb_dim_1_maxUnitCount_vre_work["workset"].str.contains(workset)].reset_index(drop=True)
            # recombine base and scen
            bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work, bb_dim_1_maxUnitCount_vre_work_set], ignore_index=True).drop_duplicates()

        bb_dim_1_maxUnitCount_vre_work["Parameter values"] = bb_dim_1_maxUnitCount_vre_work["Parameter values_base"] * (bb_dim_1_maxUnitCount_vre_work["area_potential"] / bb_dim_1_maxUnitCount_vre_work["maxUnitCount_sum_old_base"]) 
        
        #prepare the new dataframe to concat to bb_dim_1_relationship
        bb_dim_1_maxUnitCount_vre = bb_dim_1_maxUnitCount_vre_work[["Object class names", "Object names", "Parameter names", "Alternative names", "Parameter values"]]
        #replace the corresponding rows in bb_dim_1_relationship with the new bb_dim_1_maxUnitCount_vre
        bb_dim_1_relationship = bb_dim_1_relationship[~bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") | (bb_dim_1_relationship["Parameter names"] != "maxUnitCount")]
        bb_dim_1_relationship = pd.concat([bb_dim_1_relationship, bb_dim_1_maxUnitCount_vre], ignore_index=True)

    print("Model without limiting factors" + "\n")

if lim_fac_option == "Cap_lim":
    #reading the limiting factors from the csv file
    
    lim_fac = pd.read_excel(path_lim_fac, sheet_name="cap_exp_lim")
    #aggregating the nodes if subset_countries contains values in column with the header "Regions"
    if len(subset_countries["Regions"]) != 0:
        print("Aggregation for lim_fac enabled" + "\n")
        #adding a column with the respective regions from subset_countries to new_nodes
        lim_fac["Regions"] = lim_fac["ISO3 code"].map(subset_countries.set_index("Countries_short")["Regions"])
        lim_fac_disag = lim_fac.copy()
        #aggregating the nodes by the regions and preparing lim fac for the parameter dataframe
        lim_fac = lim_fac.groupby(["Regions", "Year", "Technology"]).agg({"Electricity Installed Capacity (MW)":"sum", "capacity_added":"sum", "area_potential":"sum", "log_expol":"sum", "tech_potential":"sum"}).reset_index()
        #replace Solar photovoltaic with PV, Onshore wind energy with WIND_ONSHORE and Offshore wind energy with WIND_OFFSHORE
        lim_fac["Technology"] = lim_fac["Technology"].replace({"Solar photovoltaic":"PV", "Onshore wind energy":"WIND_ONSHORE", "Offshore wind energy":"WIND_OFFSHORE"})
        # fix merge issue with Base year
        lim_fac["Year"] = lim_fac["Year"].fillna(0).astype(int)
        # select all rows with the maxUnitCount parameter for Solar and Wind
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_relationship[bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") & (bb_dim_1_relationship["Parameter names"] == "maxUnitCount")].reset_index(drop=True)
        # split Alternative names at _ to get the year
        bb_dim_1_maxUnitCount_vre_work["Year"] = bb_dim_1_maxUnitCount_vre_work["Alternative names"].str.split("_").str[1].fillna(0).astype(int)
        bb_dim_1_maxUnitCount_vre_work["Regions"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[-1]
        bb_dim_1_maxUnitCount_vre_work["Tech"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[1]
        # split away InvestX in an individual column from the Tech name to isolate the technology
        bb_dim_1_maxUnitCount_vre_work["Invest"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[1]
        bb_dim_1_maxUnitCount_vre_work["Technology"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[0]
        #merge the lim_fac with the bb_dim_1_maxUnitCount_vre_work on the Regions, Year and Technology
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work.merge(lim_fac, how="left", on=["Regions", "Year", "Technology"])
        
        # Refactoring the maxUnitCount for the different invest levels
        bb_dim_1_maxUnitCount_vre_work["workset"] = (
            bb_dim_1_maxUnitCount_vre_work["Technology"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Year"].astype(str))
        
        bb_dim_1_maxUnitCount_vre_work["merge_base"] = bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" + bb_dim_1_maxUnitCount_vre_work["Technology"]

        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] == "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] != "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_base["maxUnitCount_sum_old"] = 0

        # Rename columns to avoid conflicts during merge
        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work_base.rename(columns={"Parameter values": "Parameter values_base", "maxUnitCount_sum_old": "maxUnitCount_sum_old_base"})
        # Merge Parameter values column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "Parameter values_base"]], on=["Invest", "merge_base"], how="left")
        
        # Merge maxUnitCount_sum_old column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "maxUnitCount_sum_old_base"]], on=["Invest", "merge_base"], how="left")

        #recombine bb_dim_1_maxUnitCount_vre_work_base and bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work_base, bb_dim_1_maxUnitCount_vre_work_scen], ignore_index=True).drop_duplicates()
         
        for workset in bb_dim_1_maxUnitCount_vre_work["workset"].unique():
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["workset"] == workset].reset_index(drop=True)
                        
            # Sum up the maxUnitCount for the different invest levels for each set of region, year and technology
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work_set.fillna(0)
            bb_dim_1_maxUnitCount_vre_work_set["maxUnitCount_sum_old_base"] = bb_dim_1_maxUnitCount_vre_work_set["Parameter values_base"].sum()

            bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work[~bb_dim_1_maxUnitCount_vre_work["workset"].str.contains(workset)].reset_index(drop=True)
            # recombine base and scen
            bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work, bb_dim_1_maxUnitCount_vre_work_set], ignore_index=True).drop_duplicates()

        bb_dim_1_maxUnitCount_vre_work["Parameter values"] = bb_dim_1_maxUnitCount_vre_work["Parameter values_base"] * (bb_dim_1_maxUnitCount_vre_work["log_expol"] / bb_dim_1_maxUnitCount_vre_work["maxUnitCount_sum_old_base"]) 
        
        #prepare the new dataframe to concat to bb_dim_1_relationship
        bb_dim_1_maxUnitCount_vre = bb_dim_1_maxUnitCount_vre_work[["Object class names", "Object names", "Parameter names", "Alternative names", "Parameter values"]]
        #replace the corresponding rows in bb_dim_1_relationship with the new bb_dim_1_maxUnitCount_vre
        bb_dim_1_relationship = bb_dim_1_relationship[~bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") | (bb_dim_1_relationship["Parameter names"] != "maxUnitCount")]
        bb_dim_1_relationship = pd.concat([bb_dim_1_relationship, bb_dim_1_maxUnitCount_vre], ignore_index=True)

    print("Model with limiting factors" + "\n")

if lim_fac_option == "Kickstart":
    #reading the limiting factors from the csv file
    
    lim_fac = pd.read_excel(path_lim_fac, sheet_name="cap_exp_lim_kickstart")
    #aggregating the nodes if subset_countries contains values in column with the header "Regions"
    if len(subset_countries["Regions"]) != 0:
        print("Aggregation for lim_fac enabled" + "\n")
        #adding a column with the respective regions from subset_countries to new_nodes
        lim_fac["Regions"] = lim_fac["ISO3 code"].map(subset_countries.set_index("Countries_short")["Regions"])
        lim_fac_disag = lim_fac.copy()
        #aggregating the nodes by the regions and preparing lim fac for the parameter dataframe
        lim_fac = lim_fac.groupby(["Regions", "Year", "Technology"]).agg({"Electricity Installed Capacity (MW)":"sum", "capacity_added":"sum", "area_potential":"sum", "log_expol":"sum", "tech_potential":"sum"}).reset_index()
        #replace Solar photovoltaic with PV, Onshore wind energy with WIND_ONSHORE and Offshore wind energy with WIND_OFFSHORE
        lim_fac["Technology"] = lim_fac["Technology"].replace({"Solar photovoltaic":"PV", "Onshore wind energy":"WIND_ONSHORE", "Offshore wind energy":"WIND_OFFSHORE"})
        # fix merge issue with Base year
        lim_fac["Year"] = lim_fac["Year"].fillna(0).astype(int)
        # select all rows with the maxUnitCount parameter for Solar and Wind
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_relationship[bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") & (bb_dim_1_relationship["Parameter names"] == "maxUnitCount")].reset_index(drop=True)
        # split Alternative names at _ to get the year
        bb_dim_1_maxUnitCount_vre_work["Year"] = bb_dim_1_maxUnitCount_vre_work["Alternative names"].str.split("_").str[1].fillna(0).astype(int)
        bb_dim_1_maxUnitCount_vre_work["Regions"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[-1]
        bb_dim_1_maxUnitCount_vre_work["Tech"] = bb_dim_1_maxUnitCount_vre_work["Object names"].str.split("|").str[1]
        # split away InvestX in an individual column from the Tech name to isolate the technology
        bb_dim_1_maxUnitCount_vre_work["Invest"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[1]
        bb_dim_1_maxUnitCount_vre_work["Technology"] = bb_dim_1_maxUnitCount_vre_work["Tech"].str.split("Invest").str[0]
        #merge the lim_fac with the bb_dim_1_maxUnitCount_vre_work on the Regions, Year and Technology
        bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work.merge(lim_fac, how="left", on=["Regions", "Year", "Technology"])
        
        # Refactoring the maxUnitCount for the different invest levels
        bb_dim_1_maxUnitCount_vre_work["workset"] = (
            bb_dim_1_maxUnitCount_vre_work["Technology"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" +
            bb_dim_1_maxUnitCount_vre_work["Year"].astype(str))
        
        bb_dim_1_maxUnitCount_vre_work["merge_base"] = bb_dim_1_maxUnitCount_vre_work["Regions"] + "_" + bb_dim_1_maxUnitCount_vre_work["Technology"]

        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] == "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["Alternative names"] != "Base"].reset_index(drop=True)
        bb_dim_1_maxUnitCount_vre_work_base["maxUnitCount_sum_old"] = 0

        # Rename columns to avoid conflicts during merge
        bb_dim_1_maxUnitCount_vre_work_base = bb_dim_1_maxUnitCount_vre_work_base.rename(columns={"Parameter values": "Parameter values_base", "maxUnitCount_sum_old": "maxUnitCount_sum_old_base"})
        # Merge Parameter values column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "Parameter values_base"]], on=["Invest", "merge_base"], how="left")
        
        # Merge maxUnitCount_sum_old column from bb_dim_1_maxUnitCount_vre_work_base to bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work_scen = bb_dim_1_maxUnitCount_vre_work_scen.merge(bb_dim_1_maxUnitCount_vre_work_base[["Invest", "merge_base", "maxUnitCount_sum_old_base"]], on=["Invest", "merge_base"], how="left")

        #recombine bb_dim_1_maxUnitCount_vre_work_base and bb_dim_1_maxUnitCount_vre_work_scen
        bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work_base, bb_dim_1_maxUnitCount_vre_work_scen], ignore_index=True).drop_duplicates()
         
        for workset in bb_dim_1_maxUnitCount_vre_work["workset"].unique():
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work[bb_dim_1_maxUnitCount_vre_work["workset"] == workset].reset_index(drop=True)
                        
            # Sum up the maxUnitCount for the different invest levels for each set of region, year and technology
            bb_dim_1_maxUnitCount_vre_work_set = bb_dim_1_maxUnitCount_vre_work_set.fillna(0)
            bb_dim_1_maxUnitCount_vre_work_set["maxUnitCount_sum_old_base"] = bb_dim_1_maxUnitCount_vre_work_set["Parameter values_base"].sum()

            bb_dim_1_maxUnitCount_vre_work = bb_dim_1_maxUnitCount_vre_work[~bb_dim_1_maxUnitCount_vre_work["workset"].str.contains(workset)].reset_index(drop=True)
            # recombine base and scen
            bb_dim_1_maxUnitCount_vre_work = pd.concat([bb_dim_1_maxUnitCount_vre_work, bb_dim_1_maxUnitCount_vre_work_set], ignore_index=True).drop_duplicates()

        bb_dim_1_maxUnitCount_vre_work["Parameter values"] = bb_dim_1_maxUnitCount_vre_work["Parameter values_base"] * (bb_dim_1_maxUnitCount_vre_work["log_expol"] / bb_dim_1_maxUnitCount_vre_work["maxUnitCount_sum_old_base"]) 
        
        #prepare the new dataframe to concat to bb_dim_1_relationship
        bb_dim_1_maxUnitCount_vre = bb_dim_1_maxUnitCount_vre_work[["Object class names", "Object names", "Parameter names", "Alternative names", "Parameter values"]]
        #replace the corresponding rows in bb_dim_1_relationship with the new bb_dim_1_maxUnitCount_vre
        bb_dim_1_relationship = bb_dim_1_relationship[~bb_dim_1_relationship["Object names"].str.contains("Solar|Wind") | (bb_dim_1_relationship["Parameter names"] != "maxUnitCount")]
        bb_dim_1_relationship = pd.concat([bb_dim_1_relationship, bb_dim_1_maxUnitCount_vre], ignore_index=True)

    print("Model with kickstarted limiting factors" + "\n")

#drop duplicates in bb_dim_4_relationship
bb_dim_4_relationship = bb_dim_4_relationship.drop_duplicates().reset_index(drop=True)

#%%
###################################################################################
print("Export feed in table for Backbone" + "\n")

with pd.ExcelWriter(path = outputfile_BB) as writer:
    pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
with pd.ExcelWriter(path = outputfile_BB, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    bb_dim_0_initialization.reset_index(drop=True).to_excel(writer, index=False, sheet_name="01_dim0")
    bb_dim_1_relationship.reset_index(drop=True).to_excel(writer, index=False, sheet_name="02_dim1")
    bb_dim_1_relationship_map.reset_index(drop=True).to_excel(writer, index=False, sheet_name="03_dim1_map")
    bb_dim_2_relationship.reset_index(drop=True).to_excel(writer, index=False, sheet_name="04_dim2")
    bb_dim_2_relationship_map.to_excel(writer, index=False, sheet_name="05_dim2_map")
    bb_dim_3_relationship.reset_index(drop=True).to_excel(writer, index=False, sheet_name="06_dim3")
    bb_dim_4_relationship.reset_index(drop=True).to_excel(writer, index=False, sheet_name="07_dim4")

print("\n" + "Backbones powerplant data exported to: " + outputfile_BB + "\n")
STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
#%%