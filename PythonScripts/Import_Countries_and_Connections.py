"""
import countries and connections script

Created on 2022-11-02 // Last change 20231109 KT
@author CK, AH 
reworked on 2023-02-02 CK
reworked on 2023-05-16 KT

"""
# %% #import modules
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
import math

################# Options ################################################################

print("Assigning Country Nodes to Transmission line data" + "\n")

print('Execute in Directory:')
print(os.getcwd())

try:        #use if run in spine-toolbox
    input_data_path         = sys.argv[1]
    path_MainInput      	= sys.argv[2]
    # path_reg_fac_list       = sys.argv[5]   # why dont we use are Regional Factors for every kind of investment? Why only for pipelines and ships atm?! ## to do ##
    path_WACC_Update        = sys.argv[3]
    path_transport_nodes_and_parameters = sys.argv[4]
    outputfile              = 'TEMP\Countries_Connections.xlsx'
    outputfile_BB           = 'TEMP\Countries_Connections_BB.xlsx'
    RFNBO_assessment_path   = r".\Data\HPC_results\RFNBO\2_Def_Grid_2030\2_Def_Grid_prerun"
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    input_data_path         = r'./Data/Connections/20250606_transmission_data.xlsx'
    path_MainInput          = '.\PythonScripts\TEMP\MainInput.xlsx'
    # path_reg_fac_list       = 'Data/Transport/data_input/nodes/reg_fac_list.csv'
    path_WACC_Update        = r'PythonScripts/TEMP/weighted_WACC_final.csv'
    path_transport_nodes_and_parameters = r'./Data/Transport/data_input/nodes/nodes_and_parameters.xlsx'
    outputfile              = '.\PythonScripts\TEMP\Countries_Connections.xlsx'
    outputfile_BB           = '.\PythonScripts\TEMP\Countries_Connections_BB.xlsx'
    RFNBO_assessment_path   = r".\Data\HPC_results\RFNBO\2_Def_Grid_2030\2_Def_Grid_prerun"

################# Options End ############################################################

START = time.perf_counter()

################# Read Data ##############################################################

list_subset_countries   = pd.read_excel(path_MainInput,     sheet_name='subset_countries')
# objects_WORLD           = pd.read_excel(excel_path_PLEXOS,  sheet_name="Objects")       # XX-XXX-XX ONLY -> concatenated subset works fine
# objects_GLOBIOM         = pd.read_excel(excel_path_GLOBIOM, sheet_name="Objects")       # XX-XXX-XX ONLY -> concatenated subset works fine
# memberships_WORLD       = pd.read_excel(excel_path_PLEXOS,  sheet_name="Memberships")   # XX-XXX-XX ONLY -> concatenated subset works fine
# memberships_GLOBIOM     = pd.read_excel(excel_path_GLOBIOM, sheet_name="Memberships")   # XX-XXX-XX ONLY -> concatenated subset works fine
# properties_WORLD        = pd.read_excel(excel_path_PLEXOS,  sheet_name="Properties")    # XX-XXX-XX ONLY -> concatenated subset works fine
# properties_GLOBIOM      = pd.read_excel(excel_path_GLOBIOM, sheet_name="Properties")    # XX-XXX-XX ONLY -> concatenated subset works fine
# categories_GLOBIOM      = pd.read_excel(excel_path_GLOBIOM, sheet_name="Categories")    # XX-XXX-XX ONLY -> concatenated subset works fine
nodes_df                = pd.read_excel(input_data_path,  sheet_name="nodes")
lines_df                = pd.read_excel(input_data_path,  sheet_name="lines")
m_conf                  = pd.read_excel(path_MainInput,     sheet_name="model_config")
df_WACC                 = pd.read_csv(path_WACC_Update, sep=';')[['name','Cost of Capital','Zuordnung Steam']]
new_nodes               = pd.read_excel(path_transport_nodes_and_parameters, sheet_name=0).merge(list_subset_countries.rename(columns={'Countries':'name'}), how='inner', on='name')

################# Read Data End ##########################################################

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value
default_lines_eff = 0.96

#read capacityMargin
capacityMargin_el              = m_conf.loc[m_conf['Parameter'] == "capacityMargin_el", "Value"].values[0] # capacityMargin read value
capacityMargin_h2              = m_conf.loc[m_conf['Parameter'] == "capacityMargin_h2", "Value"].values[0] # capacityMargin read value

##read Node list
#Steam config
#prepare subset countries
list_subset_countries['Countries_short']        = list_subset_countries['Countries'].str.split('-',n =1).str[1] 

alle_nodes_PLEXOS                               = pd.Series(nodes_df['node'].unique())
list_subset_countries['Countries in PLEXOS?']   = list_subset_countries['Countries'].isin(set(alle_nodes_PLEXOS))
fehlende_nodes_PLEXOS                           = alle_nodes_PLEXOS[alle_nodes_PLEXOS.str.startswith(tuple(list_subset_countries[list_subset_countries['Countries in PLEXOS?'] == 0]['Countries'].values)) == 1].reset_index(drop=True)
list_subset_countries                           = pd.concat([list_subset_countries[['Countries', 'Regions']], pd.DataFrame({'Countries':fehlende_nodes_PLEXOS.str.rsplit('-',n=1).str[0]}).merge(list_subset_countries[['Countries','Regions']]).assign(**{'Countries':fehlende_nodes_PLEXOS})],ignore_index=True)

### splitting lines into node_from and node_to at |
lines_df['node_from'] = lines_df['name'].str.split('|', n=1).str[0]
lines_df['node_to']   = lines_df['name'].str.split('|', n=1).str[1]
#define capacity as the max absolute value of the Min and Max Flow
lines_df['Min Flow'] = lines_df['Min Flow'].abs()
lines_df['Max Flow'] = lines_df['Max Flow'].abs()
#lines capacity is the maximum of the absolute values of the min and max
lines_df['capacity'] = lines_df[['Min Flow', 'Max Flow']].max(axis=1)
lines_df = lines_df.drop(columns=['Min Flow', 'Max Flow']) #drop min and max flow columns

#define efficiency as 1 - loss
lines_df["efficiency"] = default_lines_eff
lines_df['efficiency'] = 1 - lines_df['Loss']

#%%

## only connections that contain the subset countries in name
lines_df = lines_df.loc[(lines_df['node_from'].isin(list_subset_countries.Countries)) & (lines_df['node_to'].isin(list_subset_countries.Countries))].reset_index(drop=True)
#merge Regions as region_from and region_to on Countries and node_from and node_to
lines_df = lines_df.merge(list_subset_countries[['Countries','Regions']], how='left', left_on='node_from', right_on='Countries').rename(columns={'Regions':'region_from'})
lines_df = lines_df.merge(list_subset_countries[['Countries','Regions']], how='left', left_on='node_to', right_on='Countries').rename(columns={'Regions':'region_to'})

lines_df = lines_df.drop(columns=['Countries_x', 'Countries_y']) #drop Countries columns
lines_df["name"] = lines_df["region_from"] + '|' + lines_df["region_to"]

#drop lines inside of regions
lines_df = lines_df.loc[~(lines_df['region_from'] == lines_df['region_to'])].reset_index(drop=True)
lines_df = lines_df.sort_values(by=['region_from','region_to']).reset_index(drop=True)

df_subset_lines = lines_df.copy() #create subset of lines_df to work with
#%%

##aggregate Regions
#create set of combinations from 'from_'- and 'to-regions'
df_subset_lines['from_to_list'] = None
for i in df_subset_lines.index:
    region_from_to_combination = [df_subset_lines.loc[i, 'region_from'], df_subset_lines.loc[i, 'region_to']]
    region_from_to_combination.sort()
    df_subset_lines.at[i, 'from_to_list'] = region_from_to_combination
df_subset_lines['from_to_str'] = df_subset_lines['from_to_list'].astype(str)
#aggregate
agg_lines = (
    df_subset_lines
    .groupby(['from_to_str'])
    .agg({'capacity':'sum','efficiency':'mean'}) #weighted mean would make sense...
    ##############################################################################################
    ############################ TO DO ###### TO DO ##### TO DO ##################################
    ##############################################################################################
    .reset_index()
)
#%%

#return region nodes
agg_lines = agg_lines.rename(columns={'node_from_region':'node_from', 'node_to_region':'node_to'})
agg_lines[['node_from','node_to']] = agg_lines['from_to_str'].str.split("'", expand=True)[[1,3]]
agg_lines['node_from'] = agg_lines['node_from'].astype(str) + '_el'
agg_lines['node_to'] = agg_lines['node_to'].astype(str) + '_el'
agg_lines['connection_merged'] = agg_lines['node_from'] + '|' + agg_lines['node_to']

#prepare investcost calculation
t_start                     = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])
t_end                       = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1])
modeled_duration_in_years   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760)

#%%
################# Prepare Export #########################################################

node                            = pd.DataFrame({"Object class names":"node", "Object names":pd.Series(list(list_subset_countries['Regions'].unique())).astype(str) + '_el'})
connection                      = pd.DataFrame({"Object class names":"connection", "Object names":agg_lines['connection_merged']})
dim_0_initialization_dtype_str  = pd.concat([node, connection], ignore_index=True)

node_slack_penalty                                  = pd.DataFrame({"Object class names":"node", "Object names":pd.Series(list(list_subset_countries['Regions'].unique())).astype(str) + '_el', "Parameter names":"node_slack_penalty", "Alternative names":"Base", "Parameter values":1000000000.0})
connection_candidate_connections                    = pd.DataFrame({"Object class names":"connection","Object names":agg_lines['connection_merged'], "Parameter names":"candidate_connections", "Alternative names":"Base", "Parameter values":agg_lines.capacity/float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]) + float(m_conf.Value[m_conf["Parameter"] == "candidate_connections"].values[0])})
connection_connection_investment_cost               = pd.DataFrame({"Object class names":"connection","Object names":agg_lines['connection_merged'], "Parameter names":"connection_investment_cost", "Alternative names":"Base", "Parameter values":float(m_conf.Value[m_conf["Parameter"] == "connection_investment_cost"].values[0]) * modeled_duration_in_years * float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0])}) #annuity * modeled duration in years = total investment cost per subunit
#connection_connection_investment_variable_type      = pd.DataFrame({"Object class names":"connection","Object names":agg_lines['connection_merged'], "Parameter names":"connection_investment_variable_type", "Alternative names":"Base", "Parameter values":m_conf.Value[m_conf["Parameter"] == "connection_investment_variable_type"].values[0]})
connection_connection_investment_lifetime           = pd.DataFrame({"Object class names":"connection","Object names":agg_lines['connection_merged'], "Parameter names":"connection_investment_lifetime", "Alternative names":"Base", "Parameter values":'{\"type\": \"duration\", \"data\": \"' + m_conf.Value[m_conf["Parameter"] == "connection_investment_lifetime"].values[0] + '\"}'})
connection_initial_connections_invested_available   = pd.DataFrame({"Object class names":"connection", "Object names":agg_lines['connection_merged'], "Parameter names":"initial_connections_invested_available", "Alternative names":"Base", "Parameter values":agg_lines.capacity/float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0])}) #this represents the starting capacity, now invest connections and initial connections are the same object which can be configured through Main_Input.xlsx
dim_1_object_value_dtype_str                        = pd.concat([node_slack_penalty, connection_candidate_connections, connection_connection_investment_cost, connection_connection_investment_lifetime, connection_initial_connections_invested_available], ignore_index=True) #connection_connection_investment_variable_type, 

connection__from_node_1           = pd.DataFrame({"Relationship class names":"connection__from_node", "Object class names 1":"connection", "Object class names 2":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_to, "Parameter names":"connection_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]})
connection__from_node_2           = pd.DataFrame({"Relationship class names":"connection__from_node", "Object class names 1":"connection", "Object class names 2":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_from, "Parameter names":"connection_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]})
connection__to_node_1             = pd.DataFrame({"Relationship class names":"connection__to_node", "Object class names 1":"connection", "Object class names 2":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_from, "Parameter names":"connection_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]})
connection__to_node_2             = pd.DataFrame({"Relationship class names":"connection__to_node", "Object class names 1":"connection", "Object class names 2":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_to, "Parameter names":"connection_capacity", "Alternative names":"Base", "Parameter values":m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]})
dim_2_relationship_value_dtype_str  = pd.concat([connection__from_node_1, connection__from_node_2, connection__to_node_1, connection__to_node_2], ignore_index=True)

connection__node__node_1          = pd.DataFrame({"Relationship class names":"connection__node__node", "Object class names 1":"connection", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_to, "Object names 3":agg_lines.node_from, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":"Base", "Parameter values":agg_lines.efficiency})
connection__node__node_2          = pd.DataFrame({"Relationship class names":"connection__node__node", "Object class names 1":"connection", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":agg_lines['connection_merged'], "Object names 2":agg_lines.node_from, "Object names 3":agg_lines.node_to, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":"Base", "Parameter values":agg_lines.efficiency})
dim_3_relationship_value_dtype_str  = pd.concat([connection__node__node_1, connection__node__node_2], ignore_index=True)

################# Prepare Export End #####################################################

print("Convert to Backbone" + "\n")

################# Convert to Backbone ####################################################

#dim0 (no connection objects in BB)
bb_dim_0_initialization_dtype_str = dim_0_initialization_dtype_str[dim_0_initialization_dtype_str["Object class names"] == "node"]

#dim2
columns_2d = ['Relationship class names', 'Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter values']
#p_gn -> nodeBalance
values_gn = ['grid__node','grid','node','elec','nodeXXX','parameterXXX','Base','valuesXXX']
template_gn = pd.DataFrame(dict(zip(columns_2d, values_gn)), index=range(len(dim_0_initialization_dtype_str['Object names'][dim_0_initialization_dtype_str["Object class names"] == "node"])))
#parameters
bb_dim_2_nodeBalance = template_gn.assign(**{'Object names 2':dim_0_initialization_dtype_str['Object names'][dim_0_initialization_dtype_str["Object class names"] == "node"],'Parameter names':'nodeBalance','Parameter values':1})

#%%
## 20250502 introduce capacityMargin for improved resiliency in (full year) schedule runs
bb_dim_2_capacityMargin_el = template_gn.assign(**{'Object names 2':dim_0_initialization_dtype_str['Object names'][dim_0_initialization_dtype_str["Object class names"] == "node"],'Parameter names':'capacityMargin','Parameter values':capacityMargin_el})
#bb_dim_2_capacityMargin_h2 = template_gn.assign(**{'Object names 2':dim_0_initialization_dtype_str['Object names'][dim_0_initialization_dtype_str["Object class names"] == "node"].str.replace('_el', '_h2'),'Parameter names':'capacityMargin','Parameter values':capacityMargin_h2})
## 
bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_nodeBalance, bb_dim_2_capacityMargin_el],ignore_index=True) #, bb_dim_2_capacityMargin_h2 included in h2 transport script
#%%

#dim3
columns_3d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object names 1','Object names 2','Object names 3','Parameter names','Alternative names','Parameter values'] #new df based on length of old 1dim df with new 3dim columns (Spine2BB)
#nodeslack
bb_dim_3_node_slack_penalty = pd.DataFrame(index=range(len(node_slack_penalty)), columns=columns_3d)
bb_dim_3_node_slack_penalty[['Object class names 2', 'Object names 2', 'Alternative names', 'Parameter values']] = node_slack_penalty[['Object class names', 'Object names','Alternative names', 'Parameter values']] #old data
bb_dim_3_node_slack_penalty[['Relationship class names','Object class names 1','Object class names 3', 'Object names 1', 'Object names 3', 'Parameter names','Parameter values']] = ['grid__node__boundary','grid','boundary', 'elec','balancePenalty','constant',10**6] #new data
bb_dim_3_node_slack_useConstant = bb_dim_3_node_slack_penalty.assign(**{'Parameter names':'useConstant',
                                                                        'Parameter values':1})
#inv candidates (# to do # may be differently defined in BB... have to check(!) cf number_of_units, initial_units_invested_available, we could change the definition so that candidate = x really means invest is enabled...)
#if (connection_candidate_connections['Parameter values'] - connection_initial_connections_invested_available['Parameter values']).any > 0:
bb_dim_3_candidate_connections = pd.DataFrame(index=range(len(connection_candidate_connections)), columns=columns_3d)
bb_dim_3_candidate_connections[['Object class names 2', 'Object class names 3','Object names 2', 'Object names 3', 'Alternative names']] = dim_3_relationship_value_dtype_str[['Object class names 2', 'Object class names 3','Object names 2', 'Object names 3', 'Alternative names']]
bb_dim_3_candidate_connections[['Relationship class names', 'Object class names 1','Object names 1', 'Parameter names','Parameter values']] = ['grid__node__node', 'grid','elec','transferCapInvLimit',float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]) * float(m_conf.Value[m_conf["Parameter"] == "candidate_connections"].values[0])]
#inv cost
bb_dim_3_connection_inv_cost = pd.DataFrame(bb_dim_3_candidate_connections)
bb_dim_3_connection_inv_cost['Parameter names'] = 'invCost'
bb_dim_3_connection_inv_cost['Parameter values'] = connection_connection_investment_cost['Parameter values'].astype(float) * (1/modeled_duration_in_years) * (1/float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0]))
#inv variable type
# if connection_connection_investment_variable_type["Parameter values"].values[0] != 'variable_type_continuous':
#     print('if you have a good reason to enable integer invest in transmission capacity you can introduce the parameter "investMIP" correlating to connection_investment_variable_type with variable_type_integer in Spine... do you though?' + "\n")
# else:
#     pass
# else:
#     print("no transmission invest")

#inv lifetime -> p_gnn annuityFactor[oder (similar to p_unit availabilityLimits) p_gnn mit availability als Zeitreihe unter ts_gnn. Unklar wie genau... nicht unbedingt notwendig atm]
# bb_dim_3_annuity = pd.DataFrame(bb_dim_3_candidate_connections)
# bb_dim_3_annuity['Parameter names'] = 'annuityFactor'
# bb_dim_3_annuity['Parameter values'] = 'will_be_introduced_later_in_model_config'
#(initial) transmission capacity
bb_dim_3_connection_transferCap = pd.DataFrame(bb_dim_3_candidate_connections)
bb_dim_3_connection_transferCap['Parameter names'] = 'transferCap'
bb_dim_3_connection_transferCap['Parameter values'] = connection_initial_connections_invested_available['Parameter values'].astype(float) * float(m_conf.Value[(m_conf["Parameter"] == "subunit_size")].values[0])
#line loss
bb_dim_3_connection_loss = pd.DataFrame(bb_dim_3_candidate_connections)
bb_dim_3_connection_loss['Parameter names'] = 'transferLoss'
bb_dim_3_connection_loss['Parameter values'] = 1 - connection__node__node_1['Parameter values'].astype(float)
bb_dim_3_connection_investMIP       = bb_dim_3_connection_loss.assign(**{'Parameter names':'investMIP','Parameter values':0})
bb_dim_3_connection_unitSize        = bb_dim_3_connection_loss.assign(**{'Parameter names':'unitSize','Parameter values':1})
bb_dim_3_connection_availability    = bb_dim_3_connection_loss.assign(**{'Parameter names':'availability','Parameter values':1})
bb_dim_3_p_gnn_node_a_to_b = pd.concat([
    # bb_dim_3_candidate_connections, 
    # bb_dim_3_connection_inv_cost, 
    bb_dim_3_connection_transferCap, 
    bb_dim_3_connection_loss, 
    # bb_dim_3_connection_investMIP, 
    bb_dim_3_connection_unitSize,
    # bb_dim_3_connection_annuityFactor,
    bb_dim_3_connection_availability
    ], ignore_index=True)

########################## introduce elec transmission invest #####################################

#auskommentiert alte WACC code snippets
# if model_config.loc[model_config['Object'] == 'Transmission_invest','Value'].values[0] == '2021':
#     df_WACC_2021 = pd.read_excel(path_APS_scenario_data, sheet_name='WACC_all')[['CountryCode','Parameter_value_2040']].drop_duplicates()
#     df_concat_country_industry = df_concat_country_industry.drop('Cost of Capital', axis=1).merge(df_WACC_2021.rename(columns={'CountryCode':'name','Parameter_value_2040':'Cost of Capital'}), on='name', how='left')
# elif model_config.loc[model_config['Object'] == 'WACC_year','Value'].values[0] == '2024':
#     pass
# else:
#     sys.exit('Is your data folder and main config up to date? You have to select WACC year from [2021, 2024] in model_config.csv')

transferCapInvLimit_v = m_conf.loc[m_conf['Parameter'] == "cross_border_transmission_cap", "Value"].values[0]

bb_dim_3_connection_transferCapInvLimit = bb_dim_3_connection_loss.assign(**{
    'Parameter names':'transferCapInvLimit',
    'Alternative names':'Base',   # could be changed to e.g. elecTransmissionInvest for testing of changes
    'Parameter values':transferCapInvLimit_v})

## get geoData to calculate distance from region centers to each other
new_nodes = new_nodes.groupby(["Regions"]).agg({"value1":"mean", "value2":"mean"}).reset_index().rename(columns={'value1':'x','value2':'y'})
new_nodes['Regions'] = new_nodes['Regions'] + '_el'

df_distance = (
    bb_dim_3_connection_inv_cost[['Object names 2','Object names 3']]
    .merge(
        new_nodes.rename(columns={'Regions':'Object names 2','x':'x_long_obj2','y':'y_lat_obj2'}),
        on='Object names 2',
        how='left')
    .merge(new_nodes.rename(columns={'Regions':'Object names 3','x':'x_long_obj3','y':'y_lat_obj3'}),
        on='Object names 3',
        how='left')
)
# %%
# calculate great-circle distance distance in km based on longitude and latitude
df_distance['phi_obj2'] = df_distance['y_lat_obj2'].apply(lambda x: math.radians(x)) # Coordinates in decimal degrees (e.g. 2.89078, 12.79797)
df_distance['phi_obj3'] = df_distance['y_lat_obj3'].apply(lambda x: math.radians(x))
df_distance['delta_phi'] = (df_distance['y_lat_obj3'] - df_distance['y_lat_obj2']).apply(lambda x: math.radians(x))
df_distance['delta_lambda'] = (df_distance['x_long_obj3'] - df_distance['x_long_obj2']).apply(lambda x: math.radians(x))

df_distance['a'] = (
    df_distance['delta_phi'].apply(lambda x: math.sin(x * 0.5)) ** 2 + 
    df_distance['phi_obj2'].apply(lambda x: math.cos(x)) * 
    df_distance['phi_obj3'].apply(lambda x: math.cos(x)) *
    df_distance['delta_lambda'].apply(lambda x: math.sin(x * 0.5)) ** 2
)
df_distance['c'] = (
    2 * 
    df_distance['a'].apply(lambda x: math.atan2(
        x ** 0.5,
        (1-x) ** 0.5)
    )
)
df_distance['km'] = 6371000 * df_distance['c'] * 0.001 # output distance in kilometers
df_distance = df_distance[['Object names 2','Object names 3','km']] # drop not needed calculation columns
# %%
# introduce cost data based on medium cost assumptions of Helistö 2015 ## to do ## check Härtel 2017 for sensitivity analysis
bb_dim_3_connection_inv_cost = pd.concat([
    bb_dim_3_connection_transferCapInvLimit.assign(**{
        'Parameter names':'invCost',
        'Alternative names':'elecTrans_lowCost',
        'Parameter values':df_distance['km'] * 1100 + 0.7 * 10**5}),    # Distance in km * Linecosts per km in €/MW*km + Stationcosts in €/MW
    bb_dim_3_connection_transferCapInvLimit.assign(**{
        'Parameter names':'invCost',
        'Alternative names':'elecTrans_mediumCost',
        'Parameter values':df_distance['km'] * 1300 + 1.0 * 10**5}),
    bb_dim_3_connection_transferCapInvLimit.assign(**{
        'Parameter names':'invCost',
        'Alternative names':'elecTrans_highCost',
        'Parameter values':df_distance['km'] * 1500 + 1.3 * 10**5})],
    ignore_index=True)

df_WACC_elec_transmission = (   # load regional WACC data for transmission invest (chosen industrial category: 'Power')
    df_WACC[df_WACC['Zuordnung Steam'] == '[Elec_transmission]'][['name','Cost of Capital']]
    .merge(
        list_subset_countries.rename(columns={'Countries':'name'}), 
        on='name', 
        how='left')
    .groupby('Regions')
    .agg({'Cost of Capital':'mean'})
    .reset_index()
)
df_WACC_elec_transmission['node_el'] = df_WACC_elec_transmission['Regions'] + '_el'

bb_dim_3_connection_annuityFactor   = bb_dim_3_connection_transferCapInvLimit.assign(**{
    'Parameter names':'annuityFactor',
    'Parameter values':'toBeReplaced'}) # create placeholder df to merge onto for regional WACCs
bb_dim_3_connection_annuityFactor = bb_dim_3_connection_annuityFactor.merge(df_WACC_elec_transmission[['node_el','Cost of Capital']].rename(columns={'node_el':'Object names 2'}), on='Object names 2', how='left') # merge WACC from Region A
bb_dim_3_connection_annuityFactor = bb_dim_3_connection_annuityFactor.merge(df_WACC_elec_transmission[['node_el','Cost of Capital']].rename(columns={'node_el':'Object names 3'}), on='Object names 3', how='left') # merge WACC from Region B
bb_dim_3_connection_annuityFactor['Cost of Capital_mean'] = (bb_dim_3_connection_annuityFactor['Cost of Capital_x'] + bb_dim_3_connection_annuityFactor['Cost of Capital_y']) / 2   # simple average of WACC A and WACC B for transmission between Region A and Region B # this is a simplification that could potentially be discussed (same as for pipeline and shipping connections)
bb_dim_3_connection_annuityFactor['Parameter values'] = (
    (
        bb_dim_3_connection_annuityFactor['Cost of Capital_mean'] * 
        (1 + bb_dim_3_connection_annuityFactor['Cost of Capital_mean']) ** 50) / # check if 50 years is ok as lifetime parameter for transmission invest ## to do ## do we consider reg_fac here as well?
    (
        (1 + bb_dim_3_connection_annuityFactor['Cost of Capital_mean']) ** 50 - 1)
)
bb_dim_3_connection_annuityFactor = bb_dim_3_connection_annuityFactor.drop(['Cost of Capital_x', 'Cost of Capital_y','Cost of Capital_mean'], axis=1)

bb_dim_3_p_gnn_node_a_to_b = pd.concat([bb_dim_3_p_gnn_node_a_to_b,
    bb_dim_3_connection_annuityFactor,
    bb_dim_3_connection_transferCapInvLimit, 
    bb_dim_3_connection_inv_cost],
    ignore_index=True)


bb_dim_3_p_gnn_node_b_to_a = bb_dim_3_p_gnn_node_a_to_b.assign(**{'Object names 2':bb_dim_3_p_gnn_node_a_to_b['Object names 3'],'Object names 3':bb_dim_3_p_gnn_node_a_to_b['Object names 2']}) #man sollte hier eigentlich Gruppen erstellen und dafuer sorgen, dass wenn in Verb1_a_b investiert wird auch automatisch Kapazitaet in Verb1_b_a erzeugt wird... alternativ bidirectional transmission testen... fuer ersten Test egal

bb_dim_3_relationship_dtype_str = pd.concat([
    bb_dim_3_p_gnn_node_a_to_b, 
    bb_dim_3_p_gnn_node_b_to_a, 
    # bb_dim_3_node_slack_penalty,
    # bb_dim_3_node_slack_useConstant
    ],ignore_index=True)

###### Adding the constraints for the Delegated Act for RFNBOs ######
unique_nodes_complete = bb_dim_0_initialization_dtype_str["Object names"].unique()

print("Applying RFNBO settings for " + str(RFNBO_option) + "\n")

#%%
if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #Portugal hat keine Connections - das heißt es gibt auch keinen Stromtransport von re_el zu el!
    
    #copying nodes and adding suffix "re_el" to the node names to identify them as renewable nodes
    #list of unique nodes in bb_dim_0_initialization_dtype_str Object names
    bb_dim_0_initialization_dtype_str_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_re["Object names"] = bb_dim_0_initialization_dtype_str_re["Object names"].str.replace('_el','_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_re], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_re["Object names 2"] = bb_dim_2_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_re], ignore_index=True)

    #copying the 3 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str[bb_dim_3_relationship_dtype_str["Relationship class names"] != 'grid__node__boundary'].copy()
    #reducing the rows to only one row per node and parameter
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.groupby(["Object names 2", "Parameter names"]).agg({"Relationship class names":"first", "Object class names 1":"first", "Object class names 2":"first", "Object class names 3":"first", "Object names 1":"first", "Object names 2":"first", "Object names 3":"first", "Parameter names":"first", "Alternative names":"first", "Parameter values":"first"}).reset_index(drop=True)
    #renaming and adding the suffix "re_el" to the origin node names to define a one way connection between nodes
    bb_dim_3_relationship_dtype_str_re["Object names 3"] = bb_dim_3_relationship_dtype_str_re["Object names 2"]
    bb_dim_3_relationship_dtype_str_re["Object names 2"] = bb_dim_3_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #set transferCap and transferLoss to 1000000 and 0 respectively to enable free flow of energy in one direction
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferCap", "Parameter values"] = 1000000
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferLoss", "Parameter values"] = 0

    # adding a re_el to el connection for all non connected countries
    bb_dim_3_helper = bb_dim_3_relationship_dtype_str_re.copy()
    #list of unique nodes in bb_dim_3_helper
    unique_nodes = bb_dim_3_helper["Object names 3"].unique()
    #compare unique nodes complete and unique nodes and give list of nodes that are missing
    missing_nodes = list(set(unique_nodes_complete) - set(unique_nodes))
    print("Missing nodes:", missing_nodes)
    
    #drop Object names 3 and 2
    bb_dim_3_helper = bb_dim_3_helper.drop(["Object names 2", "Object names 3"], axis=1)
    bb_dim_3_helper = bb_dim_3_helper.drop_duplicates()

    for n in missing_nodes:
        new_row = bb_dim_3_helper.copy()
        new_row["Object names 3"] = n
        new_row["Object names 2"] = new_row["Object names 3"].str.replace("el", "re_el")
        #concat to bb_dim_3_relationship_dtype_str_re
        bb_dim_3_relationship_dtype_str_re = pd.concat([bb_dim_3_relationship_dtype_str_re, new_row])

    #adding the new 3dim node relations to the existing 3dim node relations
    bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_relationship_dtype_str, bb_dim_3_relationship_dtype_str_re], ignore_index=True)

#%%
if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"
    #copying nodes and adding suffix "_isl_re_el" to the node names to identify them as renewable island nodes
    bb_dim_0_initialization_dtype_str_isl_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_isl_re["Object names"] = bb_dim_0_initialization_dtype_str_isl_re["Object names"].str.replace('_el','_isl_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_isl_re], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_isl_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_isl_re["Object names 2"] = bb_dim_2_relationship_dtype_str_isl_re["Object names 2"].str.replace('_el','_isl_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_isl_re], ignore_index=True)

    #no dim3 fpr isl_re_el required, since there is no grid between the islands

#The Defossilized Grid option conducts a pre-solve without any hydrogen demand to determine the CO2 intensity of the system to then asses, whether the RFNBO production may use the grid electricity.
if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid_prerun"
    
    #copying nodes and adding suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_0_initialization_dtype_str_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_re["Object names"] = bb_dim_0_initialization_dtype_str_re["Object names"].str.replace('_el','_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_re], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_re["Object names 2"] = bb_dim_2_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_re], ignore_index=True)

    #copying the 3 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str[bb_dim_3_relationship_dtype_str["Relationship class names"] != 'grid__node__boundary'].copy()
    #reducing the rows to only one row per node and parameter
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.groupby(["Object names 2", "Parameter names"]).agg({"Relationship class names":"first", "Object class names 1":"first", "Object class names 2":"first", "Object class names 3":"first", "Object names 1":"first", "Object names 2":"first", "Object names 3":"first", "Parameter names":"first", "Alternative names":"first", "Parameter values":"first"}).reset_index(drop=True)
    #renaming and adding the suffix "re_el" to the origin node names to define a one way connection between nodes
    bb_dim_3_relationship_dtype_str_re["Object names 3"] = bb_dim_3_relationship_dtype_str_re["Object names 2"]
    bb_dim_3_relationship_dtype_str_re["Object names 2"] = bb_dim_3_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #set transferCap and transferLoss to 1000000 and 0 respectively to enable free flow of energy in one direction
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferCap", "Parameter values"] = 1000000
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferLoss", "Parameter values"] = 0

    # adding a re_el to el connection for all non connected countries
    bb_dim_3_helper = bb_dim_3_relationship_dtype_str_re.copy()
    #list of unique nodes in bb_dim_3_helper
    unique_nodes = bb_dim_3_helper["Object names 3"].unique()
    #compare unique nodes complete and unique nodes and give list of nodes that are missing
    missing_nodes = list(set(unique_nodes_complete) - set(unique_nodes))
    print("Missing nodes:", missing_nodes)
    
    #drop Object names 3 and 2
    bb_dim_3_helper = bb_dim_3_helper.drop(["Object names 2", "Object names 3"], axis=1)
    bb_dim_3_helper = bb_dim_3_helper.drop_duplicates()

    for n in missing_nodes:
        new_row = bb_dim_3_helper.copy()
        new_row["Object names 3"] = n
        new_row["Object names 2"] = new_row["Object names 3"].str.replace("el", "re_el")
        #concat to bb_dim_3_relationship_dtype_str_re
        bb_dim_3_relationship_dtype_str_re = pd.concat([bb_dim_3_relationship_dtype_str_re, new_row])

    #adding the new 3dim node relations to the existing 3dim node relations
    bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_relationship_dtype_str, bb_dim_3_relationship_dtype_str_re], ignore_index=True)

if RFNBO_option == "Defossilized_Grid":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid"

    #read assessment_df from prerun path
    prerun_path = os.path.join(RFNBO_assessment_path)
    assessment_df = pd.read_csv(os.path.join(prerun_path, "assessment_df.csv"), sep=";")

    #get the countries from the assessment_df that may use grid electricity. The rest is configured as in the no_reg scenario
    non_def_regions_list = assessment_df.loc[assessment_df["may_draw"] == "May_not", "region"].to_list()
    non_def_regions_list = '|'.join(non_def_regions_list)
    def_regions_list = assessment_df.loc[assessment_df["may_draw"] == "May", "region"].to_list()
    def_regions_list = '|'.join(def_regions_list)

    print("Regions that may not use grid electricity: " + str(non_def_regions_list) + "\n")
    print("Regions that may use grid electricity: " + str(def_regions_list) + "\n")

    #copying nodes and adding suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_0_initialization_dtype_str_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_re["Object names"] = bb_dim_0_initialization_dtype_str_re["Object names"].str.replace('_el','_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_re], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_re["Object names 2"] = bb_dim_2_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_re], ignore_index=True)

    #copying the 3 dim node relations and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str[bb_dim_3_relationship_dtype_str["Relationship class names"] != 'grid__node__boundary'].copy()
    #reducing the rows to only one row per node and parameter
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.groupby(["Object names 2", "Parameter names"]).agg({"Relationship class names":"first", "Object class names 1":"first", "Object class names 2":"first", "Object class names 3":"first", "Object names 1":"first", "Object names 2":"first", "Object names 3":"first", "Parameter names":"first", "Alternative names":"first", "Parameter values":"first"}).reset_index(drop=True)
    #renaming and adding the suffix "re_el" to the origin node names to define a one way connection between nodes
    bb_dim_3_relationship_dtype_str_re["Object names 3"] = bb_dim_3_relationship_dtype_str_re["Object names 2"]
    bb_dim_3_relationship_dtype_str_re["Object names 2"] = bb_dim_3_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #set transferCap and transferLoss to 1000000 and 0 respectively to enable free flow of energy in one direction
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferCap", "Parameter values"] = 1000000
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferLoss", "Parameter values"] = 0

    # adding a re_el to el connection for all non connected countries
    bb_dim_3_helper = bb_dim_3_relationship_dtype_str_re.copy()
    #list of unique nodes in bb_dim_3_helper
    unique_nodes = bb_dim_3_helper["Object names 3"].unique()
    #compare unique nodes complete and unique nodes and give list of nodes that are missing
    missing_nodes = list(set(unique_nodes_complete) - set(unique_nodes))
    print("Missing nodes:", missing_nodes)
    
    #drop Object names 3 and 2
    bb_dim_3_helper = bb_dim_3_helper.drop(["Object names 2", "Object names 3"], axis=1)
    bb_dim_3_helper = bb_dim_3_helper.drop_duplicates()

    for n in missing_nodes:
        new_row = bb_dim_3_helper.copy()
        new_row["Object names 3"] = n
        new_row["Object names 2"] = new_row["Object names 3"].str.replace("el", "re_el")
        #concat to bb_dim_3_relationship_dtype_str_re
        bb_dim_3_relationship_dtype_str_re = pd.concat([bb_dim_3_relationship_dtype_str_re, new_row])

    #adding biderectional connections between renewable nodes and mixed nodes for regions in def_regions_list
    # Filter only rows where "Object names 2" contains regions from def_regions_list (regex)
    bb_dim_3_relationship_dtype_str_re_def = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Object names 2"].str.contains(def_regions_list, regex=True)].copy()
    bb_dim_3_relationship_dtype_str_re_def["Object names 2"] = bb_dim_3_relationship_dtype_str_re_def["Object names 2"].str.replace('_re_el','_el')
    bb_dim_3_relationship_dtype_str_re_def["Object names 3"] = bb_dim_3_relationship_dtype_str_re_def["Object names 2"].str.replace('el','re_el')

    #adding the new 3dim node relations to the existing 3dim node relations
    bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_relationship_dtype_str, bb_dim_3_relationship_dtype_str_re, bb_dim_3_relationship_dtype_str_re_def], ignore_index=True)

#%%
if RFNBO_option == "Add_and_Corr":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    
    ### Additionality and Correlation ###
    alt_rfnbo = "Additionality_and_Correlation"

    #copying nodes and adding suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_0_initialization_dtype_str_re_add = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_re_add["Object names"] = bb_dim_0_initialization_dtype_str_re_add["Object names"].str.replace('_el','_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_re_add], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_re_add = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_re_add["Object names 2"] = bb_dim_2_relationship_dtype_str_re_add["Object names 2"].str.replace('_el','_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_re_add], ignore_index=True)

    #copying the 3 dim node relations and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_3_relationship_dtype_str_re_add = bb_dim_3_relationship_dtype_str[bb_dim_3_relationship_dtype_str["Relationship class names"] != 'grid__node__boundary'].copy()
    #reducing the rows to only one row per node and parameter
    bb_dim_3_relationship_dtype_str_re_add = bb_dim_3_relationship_dtype_str_re_add.groupby(["Object names 2", "Parameter names"]).agg({"Relationship class names":"first", "Object class names 1":"first", "Object class names 2":"first", "Object class names 3":"first", "Object names 1":"first", "Object names 2":"first", "Object names 3":"first", "Parameter names":"first", "Alternative names":"first", "Parameter values":"first"}).reset_index(drop=True)
    #renaming and adding the suffix "re_el" to the origin node names to define a one way connection between nodes
    bb_dim_3_relationship_dtype_str_re_add["Object names 3"] = bb_dim_3_relationship_dtype_str_re_add["Object names 2"]
    bb_dim_3_relationship_dtype_str_re_add["Object names 2"] = bb_dim_3_relationship_dtype_str_re_add["Object names 2"].str.replace('_el','_re_el')
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re_add = bb_dim_3_relationship_dtype_str_re_add.loc[bb_dim_3_relationship_dtype_str_re_add["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #set transferCap and transferLoss to 1000000 and 0 respectively to enable free flow of energy in one direction
    bb_dim_3_relationship_dtype_str_re_add.loc[bb_dim_3_relationship_dtype_str_re_add["Parameter names"] == "transferCap", "Parameter values"] = 1000000
    bb_dim_3_relationship_dtype_str_re_add.loc[bb_dim_3_relationship_dtype_str_re_add["Parameter names"] == "transferLoss", "Parameter values"] = 0

    # adding a re_el to el connection for all non connected countries
    bb_dim_3_helper = bb_dim_3_relationship_dtype_str_re_add.copy()
    #list of unique nodes in bb_dim_3_helper
    unique_nodes = bb_dim_3_helper["Object names 3"].unique()
    #compare unique nodes complete and unique nodes and give list of nodes that are missing
    missing_nodes = list(set(unique_nodes_complete) - set(unique_nodes))
    print("Missing nodes:", missing_nodes)
    
    #drop Object names 3 and 2
    bb_dim_3_helper = bb_dim_3_helper.drop(["Object names 2", "Object names 3"], axis=1)
    bb_dim_3_helper = bb_dim_3_helper.drop_duplicates()

    for n in missing_nodes:
        new_row = bb_dim_3_helper.copy()
        new_row["Object names 3"] = n
        new_row["Object names 2"] = new_row["Object names 3"].str.replace("el", "re_el")
        #concat to bb_dim_3_relationship_dtype_str_re
        bb_dim_3_relationship_dtype_str_re_add = pd.concat([bb_dim_3_relationship_dtype_str_re_add, new_row])

    #adding the new 3dim node relations to the existing 3dim node relations
    bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_relationship_dtype_str, bb_dim_3_relationship_dtype_str_re_add], ignore_index=True)

if RFNBO_option == "All_at_once":
    print("Applying all regulations for RFNBOs" + "\n")
    
    ### All at once ###
    alt_rfnbo = "All_at_once"

    #copying nodes and adding suffix "_isl_re_el" to the node names to identify them as renewable island nodes
    bb_dim_0_initialization_dtype_str_isl_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_isl_re["Object names"] = bb_dim_0_initialization_dtype_str_isl_re["Object names"].str.replace('_el','_isl_re_el')

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_isl_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_isl_re["Object names 2"] = bb_dim_2_relationship_dtype_str_isl_re["Object names 2"].str.replace('_el','_isl_re_el')

    #read assessment_df from prerun path
    prerun_path = os.path.join(RFNBO_assessment_path)
    assessment_df = pd.read_csv(os.path.join(prerun_path, "assessment_df.csv"), sep=";")

    #get the countries from the assessment_df that may use grid electricity. The rest is configured as in the no_reg scenario
    non_def_regions_list = assessment_df.loc[assessment_df["may_draw"] == "May_not", "region"].to_list()
    non_def_regions_list = '|'.join(non_def_regions_list)
    def_regions_list = assessment_df.loc[assessment_df["may_draw"] == "May", "region"].to_list()
    def_regions_list = '|'.join(def_regions_list)

    print("Regions that may not use grid electricity: " + str(non_def_regions_list) + "\n")
    print("Regions that may use grid electricity: " + str(def_regions_list) + "\n")

    #copying nodes and adding suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_0_initialization_dtype_str_re = bb_dim_0_initialization_dtype_str.copy()
    bb_dim_0_initialization_dtype_str_re["Object names"] = bb_dim_0_initialization_dtype_str_re["Object names"].str.replace('_el','_re_el')

    #adding the new nodes to the existing nodes
    bb_dim_0_initialization_dtype_str = pd.concat([bb_dim_0_initialization_dtype_str, bb_dim_0_initialization_dtype_str_re, bb_dim_0_initialization_dtype_str_isl_re], ignore_index=True)

    #copying the 2 dim node realtions and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_2_relationship_dtype_str_re = bb_dim_2_relationship_dtype_str.copy()
    bb_dim_2_relationship_dtype_str_re["Object names 2"] = bb_dim_2_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')

    #adding the new 2dim node relations to the existing 2dim node relations
    bb_dim_2_relationship_dtype_str = pd.concat([bb_dim_2_relationship_dtype_str, bb_dim_2_relationship_dtype_str_re, bb_dim_2_relationship_dtype_str_isl_re], ignore_index=True)

    #copying the 3 dim node relations and adding the suffix "re_el" to the node names to identify them as renewable nodes
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str[bb_dim_3_relationship_dtype_str["Relationship class names"] != 'grid__node__boundary'].copy()
    #reducing the rows to only one row per node and parameter
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.groupby(["Object names 2", "Parameter names"]).agg({"Relationship class names":"first", "Object class names 1":"first", "Object class names 2":"first", "Object class names 3":"first", "Object names 1":"first", "Object names 2":"first", "Object names 3":"first", "Parameter names":"first", "Alternative names":"first", "Parameter values":"first"}).reset_index(drop=True)
    #renaming and adding the suffix "re_el" to the origin node names to define a one way connection between nodes
    bb_dim_3_relationship_dtype_str_re["Object names 3"] = bb_dim_3_relationship_dtype_str_re["Object names 2"]
    bb_dim_3_relationship_dtype_str_re["Object names 2"] = bb_dim_3_relationship_dtype_str_re["Object names 2"].str.replace('_el','_re_el')
    #drop all rows where Parameter names are annuity Factor, invCost
    bb_dim_3_relationship_dtype_str_re = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"].isin(["annuityFactor", "invCost", "transferCapInvLimit"]) == False]
    #set transferCap and transferLoss to 1000000 and 0 respectively to enable free flow of energy in one direction
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferCap", "Parameter values"] = 1000000
    bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Parameter names"] == "transferLoss", "Parameter values"] = 0

    # adding a re_el to el connection for all non connected countries
    bb_dim_3_helper = bb_dim_3_relationship_dtype_str_re.copy()
    #list of unique nodes in bb_dim_3_helper
    unique_nodes = bb_dim_3_helper["Object names 3"].unique()
    #compare unique nodes complete and unique nodes and give list of nodes that are missing
    missing_nodes = list(set(unique_nodes_complete) - set(unique_nodes))
    print("Missing nodes:", missing_nodes)
    
    #drop Object names 3 and 2
    bb_dim_3_helper = bb_dim_3_helper.drop(["Object names 2", "Object names 3"], axis=1)
    bb_dim_3_helper = bb_dim_3_helper.drop_duplicates()

    for n in missing_nodes:
        new_row = bb_dim_3_helper.copy()
        new_row["Object names 3"] = n
        new_row["Object names 2"] = new_row["Object names 3"].str.replace("el", "re_el")
        #concat to bb_dim_3_relationship_dtype_str_re
        bb_dim_3_relationship_dtype_str_re = pd.concat([bb_dim_3_relationship_dtype_str_re, new_row])

    #adding biderectional connections between renewable nodes and mixed nodes for regions in def_regions_list
    # Filter only rows where "Object names 2" contains regions from def_regions_list (regex)
    bb_dim_3_relationship_dtype_str_re_def = bb_dim_3_relationship_dtype_str_re.loc[bb_dim_3_relationship_dtype_str_re["Object names 2"].str.contains(def_regions_list, regex=True)].copy()
    bb_dim_3_relationship_dtype_str_re_def["Object names 2"] = bb_dim_3_relationship_dtype_str_re_def["Object names 2"].str.replace('_re_el','_el')
    bb_dim_3_relationship_dtype_str_re_def["Object names 3"] = bb_dim_3_relationship_dtype_str_re_def["Object names 2"].str.replace('el','re_el')

    #adding the new 3dim node relations to the existing 3dim node relations
    bb_dim_3_relationship_dtype_str = pd.concat([bb_dim_3_relationship_dtype_str, bb_dim_3_relationship_dtype_str_re, bb_dim_3_relationship_dtype_str_re_def], ignore_index=True)


print("Applied RFNBO settings" + "\n")

#%%
################# Write File #############################################################

with pd.ExcelWriter(path = outputfile) as writer:
    pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
with pd.ExcelWriter(path = outputfile, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
    dim_1_object_value_dtype_str.to_excel(writer, index=False, sheet_name="02_dim1")
    dim_2_relationship_value_dtype_str.to_excel(writer, index=False, sheet_name="03_dim2")
    dim_3_relationship_value_dtype_str.to_excel(writer, index=False, sheet_name="04_dim3")

print("\n" + "Spines Connection Invest data exported to: " + outputfile + "\n")

with pd.ExcelWriter(path = outputfile_BB) as writer:
    pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
with pd.ExcelWriter(path = outputfile_BB, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    bb_dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
    bb_dim_2_relationship_dtype_str.to_excel(writer, index=False, sheet_name="02_dim2")
    bb_dim_3_relationship_dtype_str.to_excel(writer, index=False, sheet_name="03_dim3")

print("\n" + "Backbones Connection Invest data exported to: " + outputfile_BB + "\n")

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
# %%
