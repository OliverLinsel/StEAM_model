"""
Import electricity demand script

Created 2022 // Last change 20231026 KT
@author OL

reworked on 14.11.2022 CK
reworked on 30.01.2023 CJ
reworked on 15.06.2023 KT
H2 & Elec scenarios amended on 12.03.2024 AH
Elec scenarios annual course implemented in function `transform_dataframe(.)` on 20.03.2024 AH
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


################# Functions ################################################################
# %%

def transform_dataframe(df_to_transform, df_subset_nodes, grid, scenario_code, val_decimals = 2 , cluster_demand_in_regions=1, apply_annual_course=0, df_data_course = None):
    """
    Transforms the data of a given DataFrame according to specified parameters.

    Args:
        
    - df_to_transform (DataFrame): DataFrame to be transformed.
    - df_subset_nodes (DataFrame): Subset nodes DataFrame containing country codes and regions.
    - grid (str): Value to be inserted in the 'grid' column.
    - scenario_code (str): Code to be prefixed to the 'alternative' column values.
    - val_decimals: Rounding precision. Default is 2.
    - cluster_demand_in_regions (int, optional): Flag indicating whether to cluster demand in regions or not. Default is 1.
    - apply_annual_course (int, optional): Switches between constant demand time series and annula course. Default is 0.
    - df_data_course: Pandas df as reference for annual course. Default is None

    Returns:
        
    - DataFrame: Transformed DataFrame.
    """
    
    if df_data_course is None and apply_annual_course == 1:
        apply_annual_course = 0
        print('No reference df as input parameter in function `transform_dataframe(.)`. Constant demand time series calculated.')
    
    # Melt DataFrame with 'countryCode' as id_vars
    df_reshaped = pd.melt(df_to_transform, id_vars=['countryCode'])
    
    # Prefix scenario code to 'variable' column values
    # lambda function extracts year string out of 'h2_scenario_year' headers and adds scenario prefix
    df_reshaped['variable'] = df_reshaped['variable'].apply(lambda x: scenario_code + '_' + x.split('_')[2])
    
    # Rename columns
    df_reshaped.rename(columns={'countryCode': 'node', 'variable': 'alternative'}, inplace=True)

    # Cluster demand in regions if flag is set
    if cluster_demand_in_regions:
        # Map country codes to regions
        countries_to_regions = dict(zip(df_subset_nodes['Countries'].str.slice(0, 6), df_subset_nodes['Regions']))
        df_reshaped['node'] = df_reshaped['node'].map(countries_to_regions)
        
        # Group by 'node' and 'alternative' columns and sum 'value'
        df_reshaped = df_reshaped.groupby(['node','alternative'], as_index=False)['value'].sum()
        # Sort DataFrame
        df_reshaped = df_reshaped.sort_values(by=['alternative', 'node']).reset_index(drop=True)

    # Insert 'grid' column with specified value
    df_reshaped.insert(0, 'grid', grid)
    # Insert 'forecast index' column with default value
    df_reshaped.insert(3, 'forecast index', 'f00')
    if apply_annual_course:
        # optional ToDo: select any of the reference regions in `df_data_course`. currenlty the 0th row is selected.
        data_course_reference = df_data_course.iloc[0,4:]
        new_columns = pd.DataFrame({f't{(i+1):06}': -np.round(data_course_reference.iloc[i]/np.sum(data_course_reference)*df_reshaped['value']*10**6, val_decimals) for i in range(8760)})
    else:
        # Create 8760 columns with values -Demand/8.76 with name convention "t000000 + timestep"
        new_columns = pd.DataFrame({f't{i:06}': -np.round(df_reshaped['value'] / 8.76*10**3, val_decimals) for i in range(1, 8761)})
    
    # Drop 'value' column
    df_reshaped.drop(columns=['value'], inplace=True)
    # Concatenate new columns with existing DataFrame
    df_reshaped = pd.concat([df_reshaped, new_columns], axis=1)
    
    return df_reshaped



def match_country_codes(names, country_list):
    """
    Function to find indices of names containing country codes in a given list of names.

    Args:
    - names: list of strings representing names
    - country_list: list of country codes

    Returns:
    - indices_xx_xxx_n: list of indices of names containing country codes in the format xx-xxx(n),
                        where 'xx' represents two uppercase letters, 'xxx' represents three uppercase
                        letters, and 'n' represents 1-2 digits.
    """
    
    # Define the regular expression pattern to match country codes in the format xx-xxx(n)
    pattern = r'\b([A-Z]{2}-[A-Z]{3}\d{1,2})\b'
    
    # Compile the regular expression pattern for efficiency
    country_regex = re.compile(pattern)

    # Use list comprehension to find indices of names containing country codes
    indices_xx_xxx_n = [i for i, name in enumerate(names) if country_regex.search(name)]
    
    return indices_xx_xxx_n  # Return the list of indices containing matched country codes




def group_and_sum_country_codes(df):
    """
    Extracts the country code part for grouping and sums the 'h2_demand_gross' column.

    Args:
    df (pandas.DataFrame): Input DataFrame containing the necessary columns.

    Returns:
    pandas.DataFrame: DataFrame grouped by the extracted country code part with summed 'h2_demand_gross'.
    """
    df=df.copy()
    # Take the first 6 characters of the 'name' column
    df['name'] = df['name'].str[:6]

    # Group by the extracted country code part and sum the 'h2_demand_gross' column
    df = df.groupby(['commodity','name', 'alternative'], as_index=False).agg({'h2_demand_gross': 'sum'})

    return df




################# Constants ################################################################
#%%

# APS (Announced Pledges Scenario)
# RES (GREen Alternative Scenario) 
# HRU (Hydrogen Run-Up Scenario)
scenario_names = ['APS', 'RES', 'HRU']
scenario_years = ['20' + yr for yr in ['20', '25', '30', '40', '45', '50', '60']]
demand_columns = ['h2_demand_' + year for year in scenario_years]
cluster_demand_in_regions = 1 # swich off regional clustering for test purpose
write_to_csv = 1 # swich off for test purpose

################# Options ################################################################


# %%
print("Start converting unit data" + "\n")

print('Execute in Directory:')
my_path=os.getcwd()
# my_path=my\folders  # adapt as needed
print(my_path)

try:
    # use if run in spine-toolbox
    excel_path_GLOBIOM          = sys.argv[1]
    path_MainInput              = sys.argv[2]
    excel_path_H2_base          = sys.argv[3]
    excel_path_APS              = sys.argv[4]
    excel_path_RES              = sys.argv[5]
    excel_path_HRU              = sys.argv[6]
    outputfile                  = r"TEMP\Demand.csv"
    outputfile_BB               = r"TEMP\Demand_BB.csv"
except:    
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    excel_path_GLOBIOM          = r"Data\Plexos\MESSAGEix-GLOBIOM\Input timeseries EN_NPi2020_500_pool-bi_new\CSV Files\All Demand UTC 2015.csv"
    path_MainInput              = r"PythonScripts\TEMP\MainInput.xlsx"
    excel_path_H2_base          = r"Data\Transport\data_input\nodes\20240321_nodes_and_parameters.xlsx"
    excel_path_APS              = r"Data\Szenario_Data\03 - APS_scenario_data.xlsx"
    excel_path_RES              = r"Data\Szenario_Data\02 - RES_scenario_data.xlsx"
    excel_path_HRU              = r"Data\Szenario_Data\01 - HRU_scenario_data.xlsx"
    outputfile                  = r"PythonScripts\TEMP\Demand.csv"
    outputfile_BB               = r"PythonScripts\TEMP\Demand_BB.csv"

df_main     = pd.read_excel(path_MainInput, sheet_name='model_date')
m_conf      = pd.read_excel(path_MainInput, sheet_name="model_config")
model_start = df_main.query('object_class_name =="backbone" and parameter_name == "model_start"')['value'].values[0]
model_duration = df_main.query('object_class_name =="backbone" and parameter_name == "model_duration"')['value'].values[0]

# %%
################# Read Data ##############################################################

df_subset_nodes         = pd.read_excel(path_MainInput, sheet_name='subset_countries')

scenarios = pd.read_excel(path_MainInput, sheet_name='scenarios')

df_elec_base         = pd.read_csv(excel_path_GLOBIOM)
df_H2_base           = pd.read_excel(excel_path_H2_base, sheet_name="nodes", usecols= [7,0,6,8]) # values in GWh
df_APS               = pd.read_excel(excel_path_APS, sheet_name="demands (TWh)")
df_RES               = pd.read_excel(excel_path_RES, sheet_name="demands (TWh)")
df_HRU               = pd.read_excel(excel_path_HRU, sheet_name="demands (TWh)")

#read RFNBO regulation option
RFNBO_option    = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value

print('Data files successfully read.')

##################  Country subset creation ###############################################
# %%

list_subset_countries   = df_subset_nodes.Countries.to_list()

# 1st 6 characters of each country code, duplicates removed by list(set(...))
list_subset_countries_sliced = list(set([country[:6] for country in list_subset_countries]))

if not (set(list_subset_countries ).issubset(set(df_elec_base.columns))):
    raise Exception(f'Country of subset {set(list_subset_countries ) - set(df_elec_base.columns)} is not present in the countries of the Plexos data')
# to be updated for all searches

# This one for H2 scenario files, all countries show XX-XXX format
country_idx = np.nonzero(df_APS['countryCode'].isin(list_subset_countries_sliced))[0].tolist()

country_idx_H2_base_v0 = np.nonzero(df_H2_base['name'].isin(list_subset_countries))[0].tolist()
country_idx_H2_base_v1 = match_country_codes(df_H2_base['name'], list_subset_countries)

# print(df_H2_base['name'][country_idx_H2_base_v1])

########################### Data frame rearrangement ############################################

# slection of  Excel columns A -- H
df_elec_APS = df_APS.iloc[country_idx, list(range(8))]
df_elec_RES = df_RES.iloc[country_idx, list(range(8))]
df_elec_HRU = df_HRU.iloc[country_idx, list(range(8))]

# Selection of Excel columns A and I -- O
df_H2_APS = df_APS.iloc[country_idx, [0] + list(range(8, 15))]
df_H2_RES = df_RES.iloc[country_idx, [0] + list(range(8, 15))]
df_H2_HRU = df_HRU.iloc[country_idx, [0] + list(range(8, 15))]



demand_H2_APS = transform_dataframe(df_H2_APS, df_subset_nodes, 'h2', scenario_names[0])
demand_H2_RES = transform_dataframe(df_H2_RES, df_subset_nodes, 'h2', scenario_names[1])
demand_H2_HRU = transform_dataframe(df_H2_HRU, df_subset_nodes, 'h2', scenario_names[2])
print('H2 Scenario DFs calculated.')
#########################################################################################

# %%
# Subset H2 Base demand 
df_H2_base_grouped = pd.concat(
    [group_and_sum_country_codes(df_H2_base.iloc[country_idx_H2_base_v0]), 
    group_and_sum_country_codes(df_H2_base.iloc[country_idx_H2_base_v1])], ignore_index=True)

# Cluster demand in regions if flag is set
df_H2_base_grouped.rename(columns={'name': 'node', 'commodity': 'grid', 'h2_demand_gross': 'value'}, inplace=True)
if cluster_demand_in_regions:
    # Map country codes to regions
    countries_to_regions = dict(zip(df_subset_nodes['Countries'].str.slice(0, 6), df_subset_nodes['Regions']))
    df_H2_base_grouped['node'] = df_H2_base_grouped['node'].map(countries_to_regions)
    # Group by 'node' and 'alternative' columns and sum 'value'
    df_H2_base_grouped = df_H2_base_grouped.groupby(['grid','node','alternative'], as_index=False)['value'].sum()
# Insert 'forecast index' column with default value
df_H2_base_grouped.insert(3, 'forecast index', 'f00')
# Create 8760 columns with values -Demand/8.76 with name convention "t000000 + timestep"
new_columns = pd.DataFrame({f't{i:06}': -np.round(df_H2_base_grouped['value'] / 8.76,2) for i in range(1, 8761)})

# Drop 'value' column
df_H2_base_grouped.drop(columns=['value'], inplace=True)
# Concatenate new columns with existing DataFrame
df_H2_base_grouped = pd.concat([df_H2_base_grouped, new_columns], axis=1)

# # Subset elec base demand
df_elec_base_subset = df_elec_base.loc[:, ['Datetime'] + list_subset_countries]

#######################################################################################################
#convert to Spine Toolbox format

# #aggregate to regions
# df_elec_base_agg = (df_elec_base_subset
#     .T
#     .drop('Datetime', axis=0)
#     .reset_index(names='Countries')
#     .merge(df_subset_nodes, how='left', on='Countries')
#     .groupby(['Regions'])
#     .agg(dict(zip(range(8760), 8760*['sum'])))

# ).T



# df_elec_base_agg['Datetime'] = df_elec_base_subset.loc[:,'Datetime']

# #reorder columns
# new_column_order = [df_elec_base_agg.columns[-1]] + list(df_elec_base_agg.columns[:-1])
# df_elec_base_agg = df_elec_base_agg[new_column_order]
# df_elec_base_agg.columns.name = None

# #write to csv
# df_elec_base_agg.to_csv(outputfile, index=False)

#########################################################################################
#convert to BB format

#starting by aggregation
df_bb = (df_elec_base_subset
    .T
    .drop('Datetime', axis=0)
    .reset_index(names='Countries')
    .merge(df_subset_nodes, how='left', on='Countries')
    .groupby(['Regions'])
    .agg(dict(zip(range(8760), 8760*['sum'])))
)

# "Forecast Index" is crucial in Backbone when implementing stochastic optimization. 
# In our scenarios,its value must always be set to "f00", indicating deterministic simulation.

#demand is negative, inflow is positive (in BB)
df_bb = (df_bb * -1).reset_index()
df_bb = df_bb.rename(columns={'Regions':'node'})
df_bb.insert(loc=0, column='grid', value='elec')
df_bb.insert(loc=2, column='alternative', value='Base')
df_bb.insert(loc=3, column='forecast index', value='f00')
#introduce BB timestep nomenclature
df_bb = df_bb.rename(columns=dict(zip(range(0,8760),'t' + pd.Series(range(1,8761)).astype(str).str.zfill(6))))
print('Base DFs calculated.')

# The course of elec reference data is used to shape the "elec" scenrio data:
demand_elec_APS = transform_dataframe(df_elec_APS, df_subset_nodes, 'elec', scenario_names[0], 2, 1, 1, df_bb)
demand_elec_RES = transform_dataframe(df_elec_RES, df_subset_nodes, 'elec', scenario_names[1], 2, 1, 1, df_bb)
demand_elec_HRU = transform_dataframe(df_elec_HRU, df_subset_nodes, 'elec', scenario_names[2], 2, 1, 1, df_bb)
print('Electricity Scenario DFs calculated.')

if write_to_csv:
    df_bb_bulk = pd.concat([df_bb, df_H2_base_grouped,
                            demand_elec_APS, demand_elec_RES, demand_elec_HRU,
                            demand_H2_APS, demand_H2_RES, demand_H2_HRU,], ignore_index=True)

    #write to csv
    df_bb_subset = pd.concat([df_bb_bulk.iloc[:,0:4] ,df_bb_bulk.iloc[:, np.arange(model_start+3, model_start+model_duration+3) ] ], axis = 1)   
    #rename nodes specific to their grid
    df_bb_subset['node'][df_bb_subset['grid'] == 'elec'] += '_el'
    df_bb_subset['node'][df_bb_subset['grid'] == 'h2'] += '_h2'
    
    id_columns = df_bb_bulk.iloc[:,0:4].columns.to_list()
    value_columns = df_bb_bulk.iloc[:, np.arange(model_start+3, model_start+model_duration+3) ].columns.to_list() 
    df_bb_subset = df_bb_subset.melt(id_vars=id_columns,value_vars=value_columns, var_name='time_step')
    df_bb_subset= df_bb_subset.loc[df_bb_subset['alternative'].isin(scenarios['alternative']),:]

    #The Defossilized Grid option conducts a pre-solve without any hydrogen demand to determine the CO2 intensity of the system to then asses, whether the RFNBO production may use the grid electricity.
    if RFNBO_option == "Defossilized_Grid_prerun":
        print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
        ### Defossilized Grids ###
        alt_rfnbo = "Defossilized_Grid_prerun"
        #deleting all hydrogen demands
        df_bb_subset = df_bb_subset[~df_bb_subset['grid'].str.contains('h2')]

    df_bb_subset.to_csv(outputfile_BB, index=False, float_format='%.0f')
    
    print('Demand data successfully saved to csv.')
# %%
