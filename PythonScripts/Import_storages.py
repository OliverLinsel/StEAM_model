"""
import storage powerplants script

Created 2023-Feb
@author DS
added nodes-subset on 2023-08-02 CK (look at initial definition of df_storages_SA_list)
updated for regional aggregation 20231109 KT
last fix: ready for Backbone 20240108

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

################# Options ################################################################

print("Start importing of Storage Powerplants data" + "\n")

print('Execute in Directory:')
print(os.getcwd())

try:        #use if run in spine-toolbox
    excel_path_GLOBIOM      = sys.argv[1]
    excel_path_PLEXOS       = sys.argv[2]
    path_MainInput          = sys.argv[3]
    path_WACC_Update        = sys.argv[4]
    outputfile_BB           = ".\TEMP\Plexos_storage_BB.xlsx"
except:
    excel_path_GLOBIOM      = r"Data\Plexos\MESSAGEix-GLOBIOM\PLEXOS-World model MESSAGEix - GLOBIOM Soft-Link.xlsx"
    excel_path_PLEXOS       = r"Data\Plexos\PLEXOS World\PLEXOS-World 2015 Gold V1.1.xlsx"
    path_MainInput          = r"PythonScripts\TEMP\MainInput.xlsx"
    path_WACC_Update        = r'PythonScripts/TEMP/weighted_WACC_final.csv'
    outputfile_BB           = r"PythonScripts\TEMP\Plexos_storage_BB.xlsx"

################# Options End ############################################################

START = time.perf_counter()

# ################# Read Data ##############################################################

objects_WORLD           = pd.read_excel(excel_path_PLEXOS,  sheet_name="Objects")           # XX-XXX-XX ONLY -> concatinated subset works fine
objects_GLOBIOM         = pd.read_excel(excel_path_GLOBIOM, sheet_name="Objects")           # XX-XXX-XX ONLY -> concatinated subset works fine
memberships_WORLD       = pd.read_excel(excel_path_PLEXOS,  sheet_name="Memberships")       # XX-XXX-XX ONLY -> concatinated subset works fine
properties_WORLD        = pd.read_excel(excel_path_PLEXOS,  sheet_name="Properties")        # XX-XXX-XX ONLY -> concatinated subset works fine
m_conf                  = pd.read_excel(path_MainInput,     sheet_name="model_config")
df_subset_nodes         = pd.read_excel(path_MainInput,     sheet_name='subset_countries')

# ################# Read Data End ##########################################################

eps = float(0.0001)
eps = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value

##read Node list
#Steam config

# %%
#prepare subset countries
df_subset_nodes['Countries_short']        = df_subset_nodes['Countries'].str.split('-',n =1).str[1] 
alle_nodes_PLEXOS                               = pd.Series(objects_GLOBIOM['name'][objects_GLOBIOM['class'] == 'Node'].unique())
df_subset_nodes['Countries in PLEXOS?']   = df_subset_nodes['Countries'].isin(set(alle_nodes_PLEXOS))
fehlende_nodes_PLEXOS                           = alle_nodes_PLEXOS[alle_nodes_PLEXOS.str.startswith(tuple(df_subset_nodes[df_subset_nodes['Countries in PLEXOS?'] == 0]['Countries'].values)) == 1].reset_index(drop=True)
df_subset_nodes                           = pd.concat([df_subset_nodes[['Countries', 'Regions']], pd.DataFrame({'Countries':fehlende_nodes_PLEXOS.str.rsplit('-',n=1).str[0]}).merge(df_subset_nodes[['Countries','Regions']]).assign(**{'Countries':fehlende_nodes_PLEXOS})],ignore_index=True)
# %%
list_subset_countries   = df_subset_nodes.Countries.to_list()
#PLEXOS data
nodes_list_SA_Globiom   = objects_GLOBIOM   ["name"][(objects_GLOBIOM   ["class"] == "Node")].reset_index(drop=True)
nodes_list_SA_World     = objects_WORLD     ["name"][(objects_WORLD     ["class"] == "Node")].reset_index(drop=True)
df_nodes_SA_delta       = pd.DataFrame({"nodes_GLOBIOM":nodes_list_SA_Globiom, "nodes_WORLD":nodes_list_SA_World})
# %%

print(
    "GLOBIOM Node: " + 
    str(list(
            df_nodes_SA_delta['nodes_GLOBIOM']
            [
                df_nodes_SA_delta['nodes_GLOBIOM']
                .isin(df_nodes_SA_delta['nodes_WORLD']) == False
            ]
            .dropna()
            .values[:]
    )) + 
    " missing in WORLD dataset")
print(
    "WORLD Node: " + 
    str(list(
            df_nodes_SA_delta['nodes_WORLD']
            [
                df_nodes_SA_delta['nodes_WORLD']
                .isin(df_nodes_SA_delta['nodes_GLOBIOM']) == False
            ]
            .dropna()
            .values[:]
     )) + 
    " missing in (implemented) GLOBIOM dataset")
# %% # load Plexos WORLD data
units_cut           = properties_WORLD[['child_class', 'child_object', 'property', 'value', 'scenario']]
storages            = units_cut.loc[units_cut['child_class'] == 'Battery']
########   Limitation to the nodes-subset    ############ 
#df_storages_SA_list = memberships_WORLD[["parent_object", "child_object"]][(memberships_WORLD["parent_class"] == "Battery") & (memberships_WORLD["child_object"].isin(nodes_list_SA_World))].reset_index(drop=True)
df_storages_SA_list = memberships_WORLD[["parent_object", "child_object"]][(memberships_WORLD["parent_class"] == "Battery") & (memberships_WORLD["child_object"].isin(nodes_list_SA_World))].reset_index(drop=True)
storages            = storages[storages["child_object"].isin(df_storages_SA_list["parent_object"])].reset_index(drop=True)
storages.drop("child_class", axis=1, inplace=True)
for i in ["technology", "country", "connection", "country_node", "name"]:
    if storages.columns.isin([i]).any() == False:
        storages.insert(loc=0, column=i, value=nan)
storages            = storages.assign(country=storages["child_object"].str.split('_', expand=True)[0])
storages            = storages.assign(technology=storages["child_object"].str.split('_', expand=True)[1])
storages            = storages.assign(name=storages["child_object"].str.split('_', expand=True)[2])
# %% #drop scenario specific values
storages.drop(list(storages[(storages.property == "Units") & (storages.scenario != "{Object}Include All Storage")].index), axis=0, inplace=True)
storages.drop(list(storages[(storages.property == "Initial SoC")].index), axis=0, inplace=True)
storages.drop(list(storages[(storages.property == "Max Power") & (storages.scenario == "{Object}Include PHS")].index), axis=0, inplace=True)
storages.reset_index(drop=True, inplace=True)
for i in storages.index:    #assign Nodes used in Plexos WORLD (SA-GUF missing)
    storages.loc[i, "country_node"] = (df_storages_SA_list["child_object"][df_storages_SA_list["parent_object"] == storages.loc[i, "child_object"]].values[0])
storages.country_node.replace(to_replace="SA-GUF", value="SA-SUR", inplace=True)
storages.loc[storages.country_node == "SA-SUR", "scenario"] = "MANUAL CHANGE OF SA-GUF (WORLD) to SA-SUR (GLOBIOM)"
print("MANUAL CHANGE OF SA-GUF (WORLD) to SA-SUR (GLOBIOM)")
storages.name = "Storage|" + storages.technology + "|" + storages.country_node + "|" + storages.name
storages.connection = storages.country_node + "|" + storages.name
#generate data for DataFrame in shorter format
storages_names          = pd.Series(storages.name.unique())
storages_country_node   = pd.Series(storages.loc[storages.loc[storages.property == "Units", "value"].index, "country_node"].reset_index(drop=True))
storages_technology     = pd.Series(storages.loc[storages.property == "Units", "technology"]).reset_index(drop=True)
storages_connection     = pd.Series(storages.connection.unique())
storages_units          = storages.loc[storages.property == "Units", "value"].reset_index(drop=True)
storages_capacity       = storages.loc[storages.property == "Capacity", "value"].reset_index(drop=True)
storages_unit_maxpower  = storages.loc[storages.property == "Max Power", "value"].reset_index(drop=True)
storages_pp_maxpower    = storages_units * storages_unit_maxpower  #maximum power capacity of the whole storage powerplant (not part of Plexos dataset)
storages_efficiency     = storages.loc[storages.property == "Charge Efficiency", "value"].reset_index(drop=True) #full cycle efficiency data taken into account in charging process
#set up cumulated DataFrame
#complete data
df_storages             = pd.DataFrame({"storages_names":storages_names, "storages_country_node":storages_country_node, "storages_connection":storages_connection, "technology":storages_technology, "storages_unit_maxpower":storages_unit_maxpower, "storages_units":storages_units, "fullload_capacity_hours":nan, "storages_efficiency":storages_efficiency/100, "storages_pp_maxpower":storages_pp_maxpower, "storages_capacity":storages_capacity, "boundary_timeseries_abs":nan})
df_storages.fullload_capacity_hours = round(df_storages.storages_capacity / df_storages.storages_pp_maxpower, 1)
#aggregated data
df_temp = df_storages.drop(["storages_connection", "boundary_timeseries_abs", "storages_unit_maxpower", "storages_units"], axis=1)
df_temp.insert(1, "set", "Storage|" + df_temp.technology + "|" + df_temp.storages_country_node + "|" + df_temp.fullload_capacity_hours.astype(str) + "h|" + df_temp.storages_efficiency.astype(str))
df_storages_agg = pd.DataFrame({"nodes":pd.Series(df_temp.set.unique()) + "|Reservoir", "country":nan, "units":pd.Series(df_temp.set.unique()), "technology":nan, "unit_MW":nan, "node_MWh":nan, "fullload_h":nan, "charging_efficiency":nan, "boundary_timeseries_abs":nan})
for i in df_storages_agg.index:
    df_storages_agg.loc[i, "country"]               = df_temp.storages_country_node[df_temp.set == df_storages_agg.units[i]].reset_index(drop=True)[0]
    df_storages_agg.loc[i, "technology"]            = df_temp.technology[df_temp.set == df_storages_agg.units[i]].reset_index(drop=True)[0]
    df_storages_agg.loc[i, "fullload_h"]            = df_temp.fullload_capacity_hours[df_temp.set == df_storages_agg.units[i]].reset_index(drop=True)[0]
    df_storages_agg.loc[i, "charging_efficiency"]   = df_temp.storages_efficiency[df_temp.set == df_storages_agg.units[i]].reset_index(drop=True)[0]
    df_storages_agg.loc[i, "unit_MW"]               = sum(df_temp.storages_pp_maxpower[df_temp.set == df_storages_agg.units[i]])
    df_storages_agg.loc[i, "node_MWh"]              = sum(df_temp.storages_capacity[df_temp.set == df_storages_agg.units[i]])
#set up the fix_node_state parameter
t_start                                             = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])).strftime('%Y-%m-%dT%H:%M:%S')
t_start_minus1h                                     = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0]) - pd.Timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S')
t_end_minus1h                                       = (pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1]) - pd.Timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S')
df_storages_agg.boundary_timeseries_abs             = '{"type": "time_series", "data": {"' + t_start_minus1h + '": ' + (df_storages_agg.node_MWh * 0.5).astype(str)  + ', "' + t_start + '": ' + "NaN" + ', "' + t_end_minus1h + '": ' + (df_storages_agg.node_MWh * 0.5).astype(str) + '}}'
#prepare investcost calculation
t_start                     = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[0])
t_end                       = pd.to_datetime(pd.ExcelFile(path_MainInput).parse("model_date").value[1])
modeled_duration_in_years   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760)
modeled_duration_in_days    = round(((t_end - t_start) / pd.Timedelta(hours=1)) * (1/24))
#generate typical storage powerplants that will be initialized at every node in the final data set, outliers will be dropped, resulting in initial storage powerplant capacity imported (Should PHS investing enabled through type powerplants?) and investable type powerplants configured
#type powerplants (you can configure any additional type storage powerplant you like, changes could include different / free config of fullload hours for thermal storage...) ## to do ##
df_count = (df_storages_agg[['technology','unit_MW','node_MWh','fullload_h','charging_efficiency']]
    .groupby(['charging_efficiency', 'technology'])
    .size()
    .reset_index(name='counts')
)
df_sum = (df_storages_agg[['technology','unit_MW','node_MWh','fullload_h','charging_efficiency']]
    .groupby(['charging_efficiency', 'technology'])
    .agg({'unit_MW':'sum','node_MWh':'sum'})
    .reset_index()
    .rename(columns={'unit_MW':'unit_MW_sum','node_MWh':'node_MWh_sum'})
)
df_type_storage_powerplants = (df_sum
    .merge(df_count,how='left', on=['technology', 'charging_efficiency'])
)
df_type_storage_powerplants = df_type_storage_powerplants[df_type_storage_powerplants['counts'] > 5]    #dont show unique storage plants
df_type_storage_powerplants['fullload_h'] = round(df_type_storage_powerplants['node_MWh_sum']/df_type_storage_powerplants['unit_MW_sum'], 2)
df_type_storage_powerplants = (df_type_storage_powerplants  #aggregate (chemical) storages with very similar characteristics
    .groupby(['technology','fullload_h'])
    .agg({'unit_MW_sum':'sum','node_MWh_sum':'sum','counts':'sum','charging_efficiency':'mean'})
    .reset_index()
)
df_type_storage_powerplants['charging_efficiency'] = round(df_type_storage_powerplants['charging_efficiency'],2)
df_type_storage_powerplants['unit_MW_share'] =   df_type_storage_powerplants['unit_MW_sum']/  sum(df_type_storage_powerplants['unit_MW_sum'])
df_type_storage_powerplants['node_MWh_share'] =  df_type_storage_powerplants['node_MWh_sum']/ sum(df_type_storage_powerplants['node_MWh_sum'])
df_type_storage_powerplants['investable'] = 'inf'
# set country limit based on subset_countries
df_storages_2015 = df_storages_agg[df_storages_agg["country"].isin(list_subset_countries)].reset_index(drop=True)
#merge country data to region
df_storages_2015 = (
    df_storages_2015
    .merge(
        df_subset_nodes.rename(columns={'Countries':'country'}), 
        how='left', 
        on='country')
)
##############################################################################
## storage script rework for Backbone
# brownfield: PHS (delete thermal, batteries, chemical etc)
# greenfield: Batteries, H2 storage
##############################################################################
df_storages_2015 = df_storages_2015[df_storages_2015['technology'] == 'PHS'].reset_index(drop=True) # brownfield only PHS
# %%
##aggregate Regions
# df_storages_2015 = (
df_phs_2015 = (df_storages_2015
               .groupby(['Regions','technology','charging_efficiency'])
               .agg({'unit_MW':'sum','node_MWh':'sum'})
               .reset_index()
               .rename(columns={'charging_efficiency':'roundtrip_efficiency'})
               .assign(**{
                   'maxUnitCount':  0, 
                   'grid':          'elec'})
)
df_phs_2015['node_out'] = df_phs_2015['Regions'] + '_el'
#make sure maxUnitCount equals installed capacity even if investment is disabled
            
df_bat = pd.DataFrame({
    'Regions':              pd.Series(df_subset_nodes['Regions'].unique()), 
    'technology':           'Bat',
    'roundtrip_efficiency': 0.9,
    'unit_MW':              0,
    'node_MWh':             0, 
    'maxUnitCount':         10**6, 
    'invCost_MW':           5.4 * 10**5,            #if one MW of charging is invested also one MW of discharging is added without costs due to p_groupPolicyUnit's 'constrainedCapMultiplier'
    'invCost_MWh':          3 * 10**5 * 0.9**-1,
    'lifetime':             10,
    'grid':                 'elec',
    'node_out':             pd.Series(df_subset_nodes['Regions'].unique()) + '_el',
    'cap_unit':             'Bat|Capacity|' + pd.Series(df_subset_nodes['Regions'].unique()),   #only needed for investable (greenfield) storages
    'groups':               'Bat|Group_Charge_Discharge|' + pd.Series(df_subset_nodes['Regions'].unique()),     #only needed for investment constraints
    'groups_fix_capacity':  'Bat|Group_Capacity_Discharge|' + pd.Series(df_subset_nodes['Regions'].unique())})  #only needed for investment constraints
# %%
df_h2 = pd.DataFrame({
    'Regions':              pd.Series(df_subset_nodes['Regions'].unique()), 
    'technology':           'H2',
    'roundtrip_efficiency': 0.7,
    'unit_MW':              0,
    'node_MWh':             0, 
    'maxUnitCount':         10**6, 
    'invCost_MW':           3.9 * 10**6 * 0.3,
    'invCost_MW_discharge': 0,                    # is h2 discharge rate from the storage powerplant restricted by anything? Batteries have to have the same charging and discharging capacity which is not the case for h2 units ## expander / valve / temperature adjusting cost could be added here ## to do ## this parameter is currently not used (cf. bb_dim_4_invCosts_dis_o)
    'invCost_MWh':          2.97 * 10**5 / 33.33,
    'lifetime':             20,
    'grid':                 'h2',
    'node_out':             pd.Series(df_subset_nodes['Regions'].unique()) + '_h2',
    'cap_unit':             'H2|Capacity|' + pd.Series(df_subset_nodes['Regions'].unique())})     #only needed for investable (greenfield) storages
#
## WACC Update 20240802
df_WACC = (pd.read_excel(path_MainInput, sheet_name='subset_countries')         # subset countries
           .merge(pd.read_csv(path_WACC_Update, sep=';')[['name','Zuordnung Steam', 'Cost of Capital']]   # merged with ERP WACC data
                  .rename(columns={'name':'Countries','Cost of Capital':'WACC'}), on='Countries', how='left'))
df_WACC_agg = df_WACC.groupby(['Regions','Zuordnung Steam']).agg({'WACC':'mean'}).reset_index()     # this can be improved upon by weights
df_bat = df_bat.merge(df_WACC_agg[df_WACC_agg['Zuordnung Steam'].str.contains('Bat\|Capacity')]).drop('Zuordnung Steam', axis=1)
df_h2 = df_h2.merge(df_WACC_agg[df_WACC_agg['Zuordnung Steam'].str.contains('H2\|Capacity')]).drop('Zuordnung Steam', axis=1)
#
df_type_plus_2015 = pd.concat([df_phs_2015, df_bat, df_h2], ignore_index=True)

#
df_type_plus_2015 = df_type_plus_2015.assign(**{
    'nodes':            df_type_plus_2015['technology'] + '|Store|'                     + df_type_plus_2015['Regions'],
    'units':            df_type_plus_2015['technology'] + '|Charge|'                    + df_type_plus_2015['Regions'],
    'units_discharge':  df_type_plus_2015['technology'] + '|Discharge|'                 + df_type_plus_2015['Regions']})
# %%
## to do ## dokumentieren wo die Zahlen herkommen
# maxUnitCount = inf für Batterie und H2 (10 ** 9 = 1 PW bzw. 1 PWh)
# Batterie 540€/kW Leistung und 300€/kWh Volumen mit 10% min SOC
# H2 industrial scale storage 50 bar, charging efficiency https://iea-etsap.org/E-TechDS/PDF/P12_H2_Feb2014_FINAL%203_CRES-2a-GS%20Mz%20GSOK.pdf 85-90% others between 60-80%, https://cordis.europa.eu/programme/id/H2020_FCH-02-5-2018 ~70%
# charging costs compressor 3.9 €/W_el mit 0.3W_el/1W_h2
# df_storages_2015['charging_efficiency'].unique()
# aufbau vgl MA mit charging / discharging / cap unit
# df_type_storage_powerplants
## achtung (!) 
# Batterie nur in festem C Verhältnis (=1) kaufbar und immer Discharge Kap = Charge Kap
# Wasserstoff frei konfigurierbare Speichermenge, und Discharge Kap != Charge Kap wobei nur Charge Kap teuer ist
################# Convert to Backbone ####################################################

##### dim0 #####
units                               = pd.concat(        #units complete: discharge + charge + cap
    [
        df_type_plus_2015['units_discharge'],
        df_type_plus_2015['units'],
        df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['cap_unit']    #not needed for PHS
    ], ignore_index=True)
storage_groups                      = pd.DataFrame({'Object class names':'group','Object names':'eachConstrainedChargingAndEachDischargingUnitIsPartOfTwoGroups'},  #Batteries MW:MW
                                                   index=range(len(df_type_plus_2015[df_type_plus_2015['groups'].isna() == False])*2)
                                                   ).assign(**{
                                                       'Object names':pd.concat(
                                                           [
                                                                df_type_plus_2015[df_type_plus_2015['groups'].isna() == False]
                                                                ['groups_fix_capacity']+'1',
                                                                df_type_plus_2015[df_type_plus_2015['groups'].isna() == False]
                                                                ['groups_fix_capacity']+'2'
                                                            ], ignore_index=True)})
storage_fix_cap_groups              = pd.DataFrame({'Object class names':'group','Object names':'eachConstrainedChargingAndEachCapacityUnitIsPartOfTwoGroups'},     #Batteries MW:MWh
                                                   index=range(len(df_type_plus_2015[df_type_plus_2015['groups_fix_capacity'].isna() == False])*2)
                                                   ).assign(**{
                                                       'Object names':pd.concat(
                                                           [
                                                               df_type_plus_2015[df_type_plus_2015['groups_fix_capacity'].isna() == False]
                                                               ['groups_fix_capacity']+'1',
                                                               df_type_plus_2015[df_type_plus_2015['groups_fix_capacity'].isna() == False]
                                                               ['groups_fix_capacity']+'2'
                                                            ],ignore_index=True)})
bb_dim_0_initialization_dtype_str   = pd.concat(
    [
        pd.DataFrame({'Object class names':['grid'],'Object names':['storage']}), 
        pd.DataFrame({"Object class names":"unit", "Object names":units}),
        pd.DataFrame({"Object class names":"node", "Object names":df_type_plus_2015['nodes']}),
        storage_groups,
        storage_fix_cap_groups
    ], ignore_index=True)
# %%
##### dim1 #####
columns_1d = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter values']
#p_unit -> availability, maxUnitCount, eff00, investMIP
values_u = ['unit','unitXXX','parameterXXX','Base','valueXXX']
template_u = pd.DataFrame(dict(zip(columns_1d, values_u)), index=range(len(df_type_plus_2015)))
template_u_dis_cha = pd.DataFrame(dict(zip(columns_1d, values_u)), index=range(len(units)))
# %%
bb_dim_1_availability       = template_u_dis_cha.assign(**{
    'Object names':units, 
    'Parameter names':'availability',
    'Parameter values':1})
bb_dim_1_investMIP          = pd.DataFrame(dict(zip(columns_1d, values_u)), index=range(len(df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0]) * 3)).assign(**{    # * 3 for discharge, charge and cap units of investable storages
    'Object names':pd.concat([
        df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['units'],
        df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['units_discharge'],
        df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['cap_unit']
    ], ignore_index=True),
    'Parameter names':'investMIP',
    'Parameter values':0})  #investMIP parameter only for investable greenfield storages (BAT,H2) not for brownfield (PHS)
# %%
bb_dim_1_maxUnitCount       = pd.DataFrame(
    columns=bb_dim_1_availability.columns, 
    index=range(len(df_type_plus_2015) * 3)
    ).assign(**{
        'Object class names':'unit',
        'Object names':pd.concat([                  #all unit columns
            df_type_plus_2015['units'], 
            df_type_plus_2015['units_discharge'], 
            df_type_plus_2015['cap_unit']           #here are missing entries for PHS plants
        ], ignore_index=True),
        'Parameter names':'maxUnitCount',
        'Alternative names':'Base',
        'Parameter values':pd.concat([df_type_plus_2015['maxUnitCount']] * 3, ignore_index=True)})  #write correct maxUnitCount values
bb_dim_1_maxUnitCount = bb_dim_1_maxUnitCount[~bb_dim_1_maxUnitCount['Object names'].isna() == True].reset_index(drop=True) #drop missing entries (cap units)
# %%
bb_dim_1_eff00_cha = template_u.assign(**{
    'Object names':df_type_plus_2015['units'],
    'Parameter names':'eff00',
    'Parameter values':df_type_plus_2015['roundtrip_efficiency']**0.5})     #square root of efficiency cause assumption that half of losses caused by roundtrip efficiency are at charging and half at discharging (no standby losses)
bb_dim_1_eff00_dis = bb_dim_1_eff00_cha.assign(**{
    'Object names':df_type_plus_2015['units_discharge']})
##energy cap unit is only needed for supplying capacity via energyStoredPerUnitOfState to the storage node (and making storage volume able to invest in case of battery and h2 storage), the unit efficiency does nothing, 1 is just a placeholder cause there has to be an efficiency defined (checken obs auch ohne geht?!)
bb_dim_1_eff00_cap = pd.DataFrame(dict(zip(columns_1d, values_u)), 
                                  index=range(len(df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0]))
                                  ).assign(**{
                                      'Object names':df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['cap_unit'],
                                      'Parameter names':'eff00',
                                      'Parameter values':1})
bb_dim_1_maxUnitCount.loc[bb_dim_1_maxUnitCount['Parameter values'] == 10**6, 'Parameter values'] = 'inf'
# %%
bb_dim_1_relationship_dtype_str = pd.concat([
    bb_dim_1_availability,
    bb_dim_1_investMIP,
    bb_dim_1_maxUnitCount,
    bb_dim_1_eff00_cha,
    bb_dim_1_eff00_dis,
    bb_dim_1_eff00_cap
    ], ignore_index=True)

##### dim2 #####
columns_2d = ['Relationship class names', 'Object class names 1','Object class names 2','Object names 1','Object names 2','Parameter names','Alternative names','Parameter values']

#p_gn -> nodeBalance, energyStoredPerUnitOfState
values_gn = ['grid__node','grid','node','storage','nodeXXX','parameterXXX','Base','valuesXXX']
template_gn = pd.DataFrame(dict(zip(columns_2d, values_gn)), index=range(len(df_type_plus_2015)))
#parameters
bb_dim_2_nodeBalance    = template_gn.assign(**{'Object names 2':df_type_plus_2015['nodes'],'Parameter names':'nodeBalance','Parameter values':1})
bb_dim_2_energyStored   = bb_dim_2_nodeBalance.assign(**{'Parameter names':'energyStoredPerUnitOfState'})
bb_dim_2_boundStart     = bb_dim_2_nodeBalance.assign(**{'Parameter names':'boundStart'})                       #should storages start with a fix value (of e.g. 0?)

#p_groundPolicyUnit -> constrainedCapMultiplier 
# Hilfsrechnung: jedes constrainte Storagepowerplant (nur Batteries atm) bekommt 2 Gruppen fuer jeden Constraint (Invest in Discharge MW = Charge MW & Invest in Discharge MW = Energy MWh) zugewiesen und besteht aus einer Charging und einer Discharging Unit bzw. Energy Cap Unit. In beiden Gruppen jedes Powerplants sind Charging und Discharging Units zugeordnet allerdings bei der 1. Gruppe mit (1dis;-1cha) bei der 2. Gruppe mit (-1dis;1cha) -> sorgt dafuer dass immer in gleich viel Charging wie Discharging Kapazitaet investiert wird.
df_only_w_constrained_groups_dis_cha = df_type_plus_2015[df_type_plus_2015['groups'].isna() == False].reset_index(drop=True)
df_only_w_constrained_groups_dis_cap = df_type_plus_2015[df_type_plus_2015['groups_fix_capacity'].isna() == False].reset_index(drop=True)

g_ser, u_ser, v_ser = [], [], []
for i in df_only_w_constrained_groups_dis_cha.index:
    g_ser = g_ser + [df_only_w_constrained_groups_dis_cha.loc[i,'groups'] + '1']*2 + [df_only_w_constrained_groups_dis_cha.loc[i,'groups'] + '2']*2
    u_ser = u_ser + [df_only_w_constrained_groups_dis_cha.loc[i,'units_discharge'], df_only_w_constrained_groups_dis_cha.loc[i,'units']]*2
    v_ser = v_ser + [1, -1, -1, 1]
bb_dim_2_constrainedCapMultiplier_dis_cha = pd.DataFrame(dict(zip(columns_2d, values_gn)), 
                                                 index=range(len(df_only_w_constrained_groups_dis_cha)*4)       # discharge units and charge units each get two entries for the dis_MW = cha_MW constraint
                                                 ).assign(**{
                                                     'Relationship class names':'unit__group',
                                                     'Object class names 1':'unit',
                                                     'Object class names 2':'group',
                                                     'Object names 1':u_ser,
                                                     'Object names 2':g_ser,
                                                     'Parameter names':'constrainedCapMultiplier',
                                                     'Parameter values':v_ser})
g_ser, u_ser, v_ser = [], [], []
for i in df_only_w_constrained_groups_dis_cap.index:
    g_ser = g_ser + [df_only_w_constrained_groups_dis_cap.loc[i,'groups_fix_capacity'] + '1']*2 + [df_only_w_constrained_groups_dis_cap.loc[i,'groups_fix_capacity'] + '2']*2
    u_ser = u_ser + [df_only_w_constrained_groups_dis_cap.loc[i,'units_discharge'], df_only_w_constrained_groups_dis_cap.loc[i,'cap_unit']]*2
    v_ser = v_ser + [1, -1, -1, 1]
bb_dim_2_constrainedCapMultiplier_dis_cap = pd.DataFrame(dict(zip(columns_2d, values_gn)), 
                                                 index=range(len(df_only_w_constrained_groups_dis_cap)*4)       # discharge units and cap units each get two entries for the dis_MW = cap_MWh constraint
                                                 ).assign(**{
                                                     'Relationship class names':'unit__group',
                                                     'Object class names 1':'unit',
                                                     'Object class names 2':'group',
                                                     'Object names 1':u_ser,
                                                     'Object names 2':g_ser,
                                                     'Parameter names':'constrainedCapMultiplier',
                                                     'Parameter values':v_ser})
#sheet uGroup sollte man sich sparen koennen wenn 'Import Objects' bei bb_dim_2_constrainedCapMultiplier gecheckt wird ## to do ## testen ##
bb_dim_2_relationship_dtype_str = pd.concat(
    [
        bb_dim_2_nodeBalance,
        bb_dim_2_energyStored,
        bb_dim_2_constrainedCapMultiplier_dis_cha,
        bb_dim_2_constrainedCapMultiplier_dis_cap,
        # bb_dim_2_boundStart
    ],ignore_index=True)

columns_2d_map = ['Object class names', 'Object names','Parameter names','Alternative names','Parameter indexes','Parameter values']
#utAvailabilityLimits -> becomeAvailable
bb_dim_2_map_utAvailabilityLimits = pd.DataFrame(dict(zip(columns_2d_map, 
                                                          ['unit','unitXXX','becomeAvailable','Base','t000001',1])),
                                                          index=range(len(units))
                                                          ).assign(**{
                                                              'Object names':units})
bb_dim_2_relationship_dtype_map = pd.concat([bb_dim_2_map_utAvailabilityLimits],ignore_index=True)

##### dim3 #####
columns_3d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object names 1','Object names 2','Object names 3','Parameter names','Alternative names','Parameter values']
values_gnb = ['grid__node__boundary','grid','node','boundary','storage','nodeXXX','downwardLimit','parameterXXX','Base','valuesXXX']
template_gnb = pd.DataFrame(dict(zip(columns_3d, values_gnb)), index=range(len(df_type_plus_2015)))
#effLevelGroupUnit
bb_dim_3_effLevelGroupUnit = pd.DataFrame(index=range(len(units)*3), columns=columns_3d)
bb_dim_3_effLevelGroupUnit = bb_dim_3_effLevelGroupUnit.assign(**{
    'Relationship class names':'effLevel__effSelector__unit',
    'Object class names 1':'effLevel',
    'Object class names 2':'effSelector',
    'Object class names 3':'unit',
    'Object names 1':['level1','level2','level3']*len(units),
    'Object names 2':'directOff',
    'Object names 3':(pd.concat([units]*3,ignore_index=True)).sort_values(ignore_index=True)})
#p_gnBoundaryPropertiesForStates -> downwardLimit, upwardLimit, reference (for boundStart / boundEnd) w useConstant, constant 
#upwardLimit subject to invest variable via p_gn energyStoredPerUnitOfState in storage 'nodes' and p_gnu_io upperLimitCapacityRatio of 'cap_unit', should be equivalent to upwardLimit (which is instead used for seasonal hydro power storage in the other script) and can be used for PHS. Unclear what best practice is... here upwardLimit for brownfield PHS for easier results analysis
bb_dim_3_downwardLimit_useConsant   = template_gnb.assign(**{
    'Object names 2':df_type_plus_2015['nodes'],
    'Parameter names':'useConstant',
    'Parameter values':1})
bb_dim_3_downwardLimit_constant     = bb_dim_3_downwardLimit_useConsant.assign(**{
    'Parameter names':'Constant',
    'Parameter values':0})
bb_dim_3_reference_useConstant = bb_dim_3_downwardLimit_useConsant.assign(**{
    'Object names 3':'reference'})
bb_dim_3_reference_constant = bb_dim_3_reference_useConstant.assign(**{ #bound Start to 0, could be discussed if this is realistic ## to do ## discarding boundStart completely could also be ok
    'Parameter names':'constant',
    'Parameter values':0})
bb_dim_3_upwardLimit_useConsant = pd.DataFrame(dict(zip(columns_3d, values_gnb)), 
                                               index=range(len(df_type_plus_2015[df_type_plus_2015['technology'] == 'PHS']))    #only brownfield PHS with non investable upwardLimit
                                               ).assign(**{
                                                   'Object names 2':df_type_plus_2015[df_type_plus_2015['technology'] == 'PHS']['nodes'],
                                                   'Object names 3':'upwardLimit',
                                                   'Parameter names':'useConstant',
                                                   'Parameter values':1})
bb_dim_3_upwardLimit_constant = bb_dim_3_upwardLimit_useConsant.assign(**{
    'Parameter names':'Constant',
    'Parameter values':df_type_plus_2015[df_type_plus_2015['technology'] == 'PHS']['node_MWh']})

bb_dim_3_relationship_dtype_str = pd.concat([
    bb_dim_3_effLevelGroupUnit,
    bb_dim_3_downwardLimit_useConsant,
    bb_dim_3_downwardLimit_constant,
    # bb_dim_3_reference_useConstant,
    # bb_dim_3_reference_constant,
    bb_dim_3_upwardLimit_useConsant,
    bb_dim_3_upwardLimit_constant
    ],ignore_index=True)

##### dim4 #####
columns_4d = ['Relationship class names', 'Object class names 1','Object class names 2','Object class names 3','Object class names 4','Object names 1','Object names 2','Object names 3','Object names 4','Parameter names','Alternative names','Parameter values']
#p_gnu_io -> conversionCoeff, capacity, unitSize, invCosts, fomCosts, vomCosts, annuityFactor, upperLimitCapacityRatio
values_gnuio = ['grid__node__unit__io','grid','node', 'unit','io','elecOderh2OderStorage','countryOderStorageNodes','ChargeOderDischargeOderCapUnits','inputOderOutput','ParameterXXX','Base','XXX']
template_gnuio = pd.DataFrame(dict(zip(columns_4d, values_gnuio)), index=range(len(df_type_plus_2015)))

#parameters
bb_dim_4_conversionCoeff_cha_i = template_gnuio.assign(**{
    'Object names 1':df_type_plus_2015['grid'],
    'Object names 2':df_type_plus_2015['node_out'],
    'Object names 3':df_type_plus_2015['units'],
    'Object names 4':'input',
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_cha_o = bb_dim_4_conversionCoeff_cha_i.assign(**{
    'Object names 1':'storage',
    'Object names 2':df_type_plus_2015['nodes'],
    'Object names 3':df_type_plus_2015['units'],
    'Object names 4':'output',
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_dis_i = bb_dim_4_conversionCoeff_cha_o.assign(**{
    'Object names 3':df_type_plus_2015['units_discharge'], 
    'Object names 4':'input'})
bb_dim_4_conversionCoeff_dis_o = bb_dim_4_conversionCoeff_cha_i.assign(**{
    'Object names 3':df_type_plus_2015['units_discharge'], 
    'Object names 4':'output'})
bb_dim_4_conversionCoeff_cap_o = pd.DataFrame(dict(zip(columns_4d, values_gnuio)),  #cap units df is shorter cause PHS does not have any
                                              index=range(len(df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0]))
                                              ).assign(**{
                                                  'Object names 1':'storage',
                                                  'Object names 2':df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['nodes'],
                                                  'Object names 3':df_type_plus_2015[df_type_plus_2015['maxUnitCount']>0].reset_index(drop=True)['cap_unit'],
                                                  'Object names 4':'output',
                                                  'Parameter names':'conversionCoeff',
                                                  'Parameter values':1})    #cap_units do NOT get an input, only output
bb_dim_4_conversionCoeff_concat = pd.concat([
    bb_dim_4_conversionCoeff_cha_i, 
    bb_dim_4_conversionCoeff_cha_o, 
    bb_dim_4_conversionCoeff_dis_i, 
    bb_dim_4_conversionCoeff_dis_o, 
    bb_dim_4_conversionCoeff_cap_o
    ], ignore_index=True)
#capacity only needs to be defined for one way (either input or output)
#for powerplants typically the output e.g. Coal with 1000 MW_el
#for storages typically the input of the charging unit and the output of the discharging unit e.g. a battery that can load with 100 NW from the grid and discharge with 100 MW to the grid
bb_dim_4_capacity_cha_i = bb_dim_4_conversionCoeff_cha_i.assign(**{
    'Parameter names':'capacity',
    'Parameter values':df_type_plus_2015['unit_MW']})
bb_dim_4_capacity_cha_o = bb_dim_4_conversionCoeff_cha_o.assign(**{
    'Parameter names':'capacity',
    'Parameter values':df_type_plus_2015['unit_MW']})
bb_dim_4_capacity_dis_o = bb_dim_4_conversionCoeff_dis_o.assign(**{
    'Parameter names':'capacity',
    'Parameter values':df_type_plus_2015['unit_MW']})
# bb_dim_4_capacity_cap_o = bb_dim_4_conversionCoeff_cap_o.assign(**{ #this is propably not needed
#     'Parameter names':'capacity',
#     'Parameter values':0})
bb_dim_4_unitSize = pd.concat([  #unitSize = 1 typically defined for output, here as well for input when costs are associated with input
                               bb_dim_4_conversionCoeff_dis_o, 
                               bb_dim_4_conversionCoeff_cap_o,
                               bb_dim_4_conversionCoeff_cha_o
                               ], ignore_index=True
                               ).assign(**{
                                   'Parameter names':'unitSize',
                                   'Parameter values':1})

#Deleting unitSize for PHS to get rid of Backbone Warning has capacity <> unitSize * unitCount
bb_dim_4_unitSize = bb_dim_4_unitSize.loc[~(bb_dim_4_unitSize["Object names 3"].str.contains("PHS")), :]  #PHS does not have a unit size
# %%
## to do ## Kosten verknuepfen statt hard gecoded einfuegen (aber oben bei Erstellung von df_h2 und df_battery)
bb_dim_4_invCosts_cap_o = bb_dim_4_conversionCoeff_cap_o.assign(**{
    'Parameter names':'invCosts',
    'Parameter values':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['invCost_MWh']}) 
bb_dim_4_invCosts_cha_i = bb_dim_4_invCosts_cap_o.assign(**{
    'Object names 1':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['grid'],
    'Object names 2':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['node_out'],
    'Object names 3':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['units'],
    'Object names 4':'input',
    'Parameter values':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['invCost_MW']})
bb_dim_4_invCosts_cha_o = bb_dim_4_invCosts_cap_o.assign(**{
    'Object names 3':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['units'],
    'Parameter values':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['invCost_MW']})
bb_dim_4_invCosts_dis_o = bb_dim_4_invCosts_cha_i.assign(**{
    'Object names 3':df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True)['units_discharge'],
    'Object names 4':'output',
    'Parameter values':1})  #discharge units do not cost anything for hydrogen, for batteries they are coupled directly via p_groupPolicyUnit to the charging capacity which does have invCosts ## 1 EUR / MW als Platzhalter damit nicht immer 10 ** 6 investiert wird
# %%
bb_dim_4_annuityFactor_cap_o = bb_dim_4_invCosts_cap_o.assign(**{
    'Parameter names':'annuityFactor',
    'Parameter values':((
        df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True).WACC * # (WACC * (1 + WACC) ** Lifetime) / ((1 + WACC) ** Lifetime) -1)
        (   1 + df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True).WACC) ** df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True).lifetime) / 
        ((  1 + df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True).WACC) ** df_type_plus_2015[df_type_plus_2015['invCost_MW']>0].reset_index(drop=True).lifetime - 1))})
bb_dim_4_annuityFactor_cha_i = bb_dim_4_invCosts_cha_i.assign(**{'Parameter names':'annuityFactor','Parameter values':bb_dim_4_annuityFactor_cap_o['Parameter values']})
bb_dim_4_annuityFactor_cha_o = bb_dim_4_invCosts_cha_o.assign(**{'Parameter names':'annuityFactor','Parameter values':bb_dim_4_annuityFactor_cap_o['Parameter values']})
bb_dim_4_annuityFactor_dis_o = bb_dim_4_invCosts_dis_o.assign(**{'Parameter names':'annuityFactor','Parameter values':bb_dim_4_annuityFactor_cap_o['Parameter values']})
# %%
bb_dim_4_upperLimitCapacityRatio_cap_o = bb_dim_4_invCosts_cap_o.assign(**{
    'Parameter names':'upperLimitCapacityRatio',
    'Parameter values':1})
bb_dim_4_capacity_cha_i[bb_dim_4_capacity_cha_i['Parameter values'] == 0] = bb_dim_4_capacity_cha_i[bb_dim_4_capacity_cha_i['Parameter values'] == 0].assign(**{'Parameter values':eps}) 
bb_dim_4_capacity_cha_o[bb_dim_4_capacity_cha_o['Parameter values'] == 0] = bb_dim_4_capacity_cha_o[bb_dim_4_capacity_cha_o['Parameter values'] == 0].assign(**{'Parameter values':eps}) 
bb_dim_4_capacity_dis_o[bb_dim_4_capacity_dis_o['Parameter values'] == 0] = bb_dim_4_capacity_dis_o[bb_dim_4_capacity_dis_o['Parameter values'] == 0].assign(**{'Parameter values':eps})
# bb_dim_4_annuityFactor_dis_o = bb_dim_4_annuityFactor_dis_o[~bb_dim_4_annuityFactor_dis_o['Object names 3'].isin(bb_dim_4_invCosts_dis_o[bb_dim_4_invCosts_dis_o['Parameter values'] == 0]['Object names 3'].reset_index(drop=True))]   #remove all annuityFactors from discharging units where invCosts are zero
# bb_dim_4_invCosts_cha_i[bb_dim_4_invCosts_cha_i['Parameter values'] == 0] = bb_dim_4_invCosts_cha_i[bb_dim_4_invCosts_cha_i['Parameter values'] == 0].assign(**{'Parameter values':eps}) 
bb_dim_4_invCosts_dis_o[bb_dim_4_invCosts_dis_o['Parameter values'] == 1] = bb_dim_4_invCosts_dis_o[bb_dim_4_invCosts_dis_o['Parameter values'] == 1].assign(**{'Parameter values':eps})
#setting the zero capacity entries to 0.001 cause Backbone seems to ignore zero values sometimes... ## to do ## have to check this later ('eps' should sometimes be used as 0 but causes problems for exporter (string!=float))

bb_dim_4_relationship_dtype_str = pd.concat([
    bb_dim_4_conversionCoeff_concat,
    # bb_dim_4_capacity_cha_i,
    bb_dim_4_capacity_cha_o,
    bb_dim_4_capacity_dis_o,
    bb_dim_4_unitSize,
    bb_dim_4_invCosts_cap_o,
    # bb_dim_4_invCosts_cha_i,
    bb_dim_4_invCosts_cha_o,
    bb_dim_4_invCosts_dis_o,
    bb_dim_4_annuityFactor_cap_o,
    # bb_dim_4_annuityFactor_cha_i,
    bb_dim_4_annuityFactor_cha_o,
    bb_dim_4_annuityFactor_dis_o,
    bb_dim_4_upperLimitCapacityRatio_cap_o
    ],ignore_index=True)
bb_dim_4_relationship_dtype_str
# constraintOnlineMultiplier koennte noch in p_groupPolicyUnit genutzt werden um gleichzeitiges Chargen und Dischargen zu verhindern... sollte aber aufgrund von efficiencies unter 1 kein Problem sein ## to do ## in Test-Results ueberpruefen
# alternativ zu boundStart koennte auch gnss_bound (Anfangsfuellstand = Endfuellstand) schon ausreichend sein

#### Adding the constraints for the Delegated Act for RFNBOs ####

if RFNBO_option == "Vanilla":
    print("Base model without any RFNBO modifications" + "\n")

if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #reassining all storages to the renewable electricity nodes
    bb_dim_4_relationship_dtype_str['Object names 2'] = bb_dim_4_relationship_dtype_str['Object names 2'].str.replace('_el','_re_el')

if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"
    #reassining all old storages to the mixed electricity nodes and the new storages to the renewable electricity nodes
    bb_dim_4_relationship_dtype_str_re = bb_dim_4_relationship_dtype_str[bb_dim_4_relationship_dtype_str['Object names 3'].str.contains("Bat|H2")].reset_index(drop=True)
    bb_dim_4_relationship_dtype_str_re['Object names 2'] = bb_dim_4_relationship_dtype_str_re['Object names 2'].str.replace('_el','_re_el')
    bb_dim_4_relationship_dtype_str = bb_dim_4_relationship_dtype_str.drop(bb_dim_4_relationship_dtype_str[bb_dim_4_relationship_dtype_str['Object names 3'].str.contains("Bat|H2")].index)
    
    bb_dim_4_relationship_dtype_str = pd.concat([bb_dim_4_relationship_dtype_str, bb_dim_4_relationship_dtype_str_re], ignore_index=True)

if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid"
    #Deleting all H2 Storages
    reg_ex_hydrogen = 'H2'
    bb_dim_0_initialization_dtype_str = bb_dim_0_initialization_dtype_str[~bb_dim_0_initialization_dtype_str['Object names'].str.contains(reg_ex_hydrogen)]
    bb_dim_1_relationship_dtype_str = bb_dim_1_relationship_dtype_str[~bb_dim_1_relationship_dtype_str['Object names'].str.contains(reg_ex_hydrogen)]
    bb_dim_2_relationship_dtype_str = bb_dim_2_relationship_dtype_str[~bb_dim_2_relationship_dtype_str['Object names 1'].str.contains(reg_ex_hydrogen)]
    bb_dim_2_relationship_dtype_map = bb_dim_2_relationship_dtype_map[~bb_dim_2_relationship_dtype_map['Object names'].str.contains(reg_ex_hydrogen)]
    bb_dim_3_relationship_dtype_str = bb_dim_3_relationship_dtype_str[~bb_dim_3_relationship_dtype_str['Object names 3'].str.contains(reg_ex_hydrogen)]
    bb_dim_4_relationship_dtype_str = bb_dim_4_relationship_dtype_str[~bb_dim_4_relationship_dtype_str['Object names 3'].str.contains(reg_ex_hydrogen)]

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

#%%
################# Write File #############################################################

with pd.ExcelWriter(path = outputfile_BB) as writer:
    pd.DataFrame().to_excel(writer, sheet_name='00_Placeholder', header=True, index=False)
with pd.ExcelWriter(path = outputfile_BB, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    bb_dim_0_initialization_dtype_str.to_excel(writer, index=False, sheet_name="01_dim0")
    bb_dim_1_relationship_dtype_str.to_excel(writer, index=False, sheet_name="02_dim1")
    bb_dim_2_relationship_dtype_str.to_excel(writer, index=False, sheet_name="03_dim2")
    bb_dim_2_relationship_dtype_map.to_excel(writer, index=False, sheet_name="04_dim2_map")
    bb_dim_3_relationship_dtype_str.to_excel(writer, index=False, sheet_name="05_dim3")
    bb_dim_4_relationship_dtype_str.to_excel(writer, index=False, sheet_name="06_dim4")

print("\n" + "Backbones Storage data exported to: " + outputfile_BB + "\n")

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
# %%