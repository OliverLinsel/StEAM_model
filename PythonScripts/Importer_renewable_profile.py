"""
Import renewable profile script

Created 2022-11-14 // Last change 20240723 KT added weighting to aggregation
@author OL, CK
reworked on 2023-01-30 CJ
reworked on 2023-06-29 KT

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
import json

# %%
################# Options ################################################################

print("Start converting renewable profiles" + "\n")

print('Execute in Directory:')
print(os.getcwd())

try:
    path_solar                  = sys.argv[1]
    path_wind                   = sys.argv[2]
    path_demand                 = sys.argv[3]
    path_MainInput              = sys.argv[4]
    path_RE_invest              = sys.argv[5]
    outputfile                  = r"TEMP\Renewable_profiles.csv"
    outputfile_BB               = r"TEMP\Renewable_profiles_BB.csv"
    path_RE_invest              = r'..\Data\Invest_Renew\Steps_5\df_profiles.csv'    # kann auch ueber sys.argv
    m_conf                      = pd.read_excel(path_MainInput, sheet_name="model_config")
except:
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    path_solar                  = r'.\Data\Plexos\MESSAGEix-GLOBIOM\Input timeseries EN_NPi2020_500_pool-bi_new\CSV Files\All Nodes Solar Only Normalised.csv'
    path_demand                 = r'.\Data\Plexos\MESSAGEix-GLOBIOM\Input timeseries EN_NPi2020_500_pool-bi_new\CSV Files\All Demand UTC 2015.csv'
    path_MainInput              = r'.\PythonScripts\TEMP\MainInput.xlsx'
    path_RE_invest              = r'.\Data\Invest_Renew\Steps_5\df_profiles.csv'
    path_RE_1dim_data           = r'.\Data\Invest_Renew\Steps_5\02_dim1.csv'
    outputfile                  = r'.\PythonScripts\TEMP\Renewable_profiles.csv'
    m_conf                      = pd.read_excel(path_MainInput, sheet_name="model_config")
    outputfile_BB               = r'.\PythonScripts\TEMP\Renewable_profiles_BB.csv'
# %%
################# Options End ############################################################

START = time.perf_counter() 

################# Read Data ##############################################################

solar               = pd.read_csv(path_solar)                                           # XX-XXX-XX ONLY -> concatinated subset works fine
df_demand           = pd.read_csv(path_demand)                                          # XX-XXX PLUS XX-XXX-XX -> DO NOT USE CONCATINATED subet to avoid double counting
df_profiles_invest  = pd.read_csv(path_RE_invest, sep=';')                              # XX-XXX ONLY -> concatinated subset works fine (not even needed here)
df_subset_nodes     = pd.read_excel(path_MainInput, sheet_name='subset_countries')

df_profiles_invest  = df_profiles_invest.drop('Datetime',axis= 1)
df_profiles_invest.columns = df_profiles_invest.columns.str.replace('WINDInvest', 'Wind_OnshoreInvest').str.replace("WIND_OFFSHOREInvest", "Wind_OffshoreInvest")     # ermoeglicht Zuordnung

df_RE_1dim_data     = pd.read_csv(path_RE_1dim_data, sep = ';') # VRE potential used for weighing of profiles
df_RE_1dim_data["Object_names"] = df_RE_1dim_data["Object_names"].str.replace('WINDInvest', 'Wind_OnshoreInvest').str.replace("WIND_OFFSHOREInvest", "Wind_OffshoreInvest") # ermoeglicht Zuordnun

df_main         = pd.read_excel(path_MainInput, sheet_name='model_date')
model_start     = df_main.query('object_class_name =="backbone" and parameter_name == "model_start"')['value'].values[0]
model_duration  = df_main.query('object_class_name =="backbone" and parameter_name == "model_duration"')['value'].values[0]

scenarios = pd.read_excel(path_MainInput, sheet_name='scenarios')
model_config = pd.read_excel(path_MainInput, sheet_name='model_config')

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value

#%%
################# Read Data End ##########################################################

# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().sort_values().plot()
print('Wind_Offshore avg. cf global old: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().mean()))
# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().sort_values().plot()
print('Wind_Onshore avg. cf global old: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().mean()))
# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean().sort_values().plot()
print('Solar avg. cf global old: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean().mean()))

## 20250212 VRE ts_cf fix
# nerfing PV and Offshore, buffing Onshore // optimally we should reference a paper and use factors that a) are heterogenous for different regions b) apply them in a methodologically solid way instead of applying the correction factor uniformly on the whole timeseries we could apply it e.g. affecting the lowest 20% of capacity factors less, the mid 20% - 60% a lot, the high 60% - 80% moderately and the highest 80% - 100% not at all... or something else
# if you want to have the old data set unchanged just use the old model config
if model_config.loc[model_config['Parameter'] == 'ts_cf_fix','Value'].values[0] == 'specific_scaling':
    # config specific scaling
    Ref_avg_ts_cf_global_pv = 0.169 # Statista, 2022 https://www.statista.com/statistics/799330/global-solar-pv-installation-cost-per-kilowatt (link is weird, its actually 'Average capacity factor for utility-scale solar PV systems worldwide')
    onshore_glaettungsfaktor_multi = 1      # not in use
    onshore_glaettungsfaktor_expo = 1.55    # this is used to reduce positive extreme values
    Ref_avg_ts_cf_global_onshore = 0.266    # results in 0.26; Statista, 2022 https://www.statista.com/statistics/1477288/onshore-wind-power-capacity-factor-by-country
    offshore_glaettungsfaktor_multi = 1
    offshore_glaettungsfaktor_expo = 0.4
    Ref_avg_ts_cf_global_offshore = 0.386   # results in 0.36; Statista, 2022 https://www.statista.com/statistics/1477283/offshore-wind-power-capacity-factor-by-country
    ## Bsp.: alle PV Kurven um avg 5% Punkte nach unten
    df_solar_cor_fac = pd.DataFrame(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean()).reset_index()
    df_solar_cor_fac['mean_alterwert_avg'] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean().mean()
    df_solar_cor_fac['mean_zielwert_avg'] = Ref_avg_ts_cf_global_pv
    df_solar_cor_fac['delta_alterwert_zielwert_avg'] = df_solar_cor_fac['mean_alterwert_avg'] - df_solar_cor_fac['mean_zielwert_avg']
    df_solar_cor_fac['neu_avg'] = df_solar_cor_fac[0] - df_solar_cor_fac['delta_alterwert_zielwert_avg']
    df_solar_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'] = df_solar_cor_fac['neu_avg'] / df_solar_cor_fac[0]
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mul(df_solar_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'].values, axis=1) # apply
    ## Bsp.: erst Onshore Outlier um Differenz zu neuem Ref_avg_ts_cf_global begradigen, dann alle gleichmäßig um 10% Punkte nach oben
    df_onshore_cor_fac = pd.DataFrame(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean()).reset_index()
    df_onshore_cor_fac['mean_alterwert_avg'] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().mean()
    df_onshore_cor_fac['mean_zielwert_avg'] = Ref_avg_ts_cf_global_onshore
    df_onshore_cor_fac['0_temp'] = df_onshore_cor_fac['mean_zielwert_avg'] - df_onshore_cor_fac[0]
    df_onshore_cor_fac[1] = df_onshore_cor_fac[0]*onshore_glaettungsfaktor_multi*(df_onshore_cor_fac['0_temp']+1)**onshore_glaettungsfaktor_expo
    df_onshore_cor_fac['delta_alterwert_zielwert_avg'] = df_onshore_cor_fac['mean_alterwert_avg'] - df_onshore_cor_fac['mean_zielwert_avg']
    df_onshore_cor_fac['neu_avg'] = df_onshore_cor_fac[1] - df_onshore_cor_fac['delta_alterwert_zielwert_avg']
    df_onshore_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'] = df_onshore_cor_fac['neu_avg'] / df_onshore_cor_fac[0]
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mul(df_onshore_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'].values, axis=1) # apply
    ## Bsp.: erst Offshore Outlier um Differenz zu neuem Ref_avg_ts_cf_global begradigen, dann alle gleichmäßig um 10% Punkte nach oben
    df_offshore_cor_fac = pd.DataFrame(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean()).reset_index()
    df_offshore_cor_fac['mean_alterwert_avg'] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().mean()
    df_offshore_cor_fac['mean_zielwert_avg'] = Ref_avg_ts_cf_global_offshore
    df_offshore_cor_fac['0_temp'] = df_offshore_cor_fac['mean_zielwert_avg'] - df_offshore_cor_fac[0]
    df_offshore_cor_fac[1] = df_offshore_cor_fac[0]*offshore_glaettungsfaktor_multi*(df_offshore_cor_fac['0_temp']+1)**offshore_glaettungsfaktor_expo
    df_offshore_cor_fac['delta_alterwert_zielwert_avg'] = df_offshore_cor_fac['mean_alterwert_avg'] - df_offshore_cor_fac['mean_zielwert_avg']
    df_offshore_cor_fac['neu_avg'] = df_offshore_cor_fac[1] - df_offshore_cor_fac['delta_alterwert_zielwert_avg']
    df_offshore_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'] = df_offshore_cor_fac['neu_avg'] / df_offshore_cor_fac[0]
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mul(df_offshore_cor_fac['aenderungsfaktor_von_alt_zu_neu_avg'].values, axis=1) # apply

## flat global factor
if model_config.loc[model_config['Parameter'] == 'ts_cf_fix','Value'].values[0] == 'flat_scaling':
    # reference FLH (to fix for DEU) // alternative cf (to fix for global)
    # Prognos / EWI / GWS 2014, printed in 'Entwicklung der Energiemärkte – Energiereferenzprognose Projekt Nr. 57/12' p.260 # https://www.ewi.uni-koeln.de/cms/wp-content/uploads/2015/12/2014_06_24_ENDBER_P7570_Energiereferenzprognose-GESAMT-FIN-IA.pdf // alternative # https://www.statista.com/statistics/1498992/capacity-factor-renewables-by-technology/?__sso_cookie_checker=failed 
    cf_PV_ref = 999/8760        # alternative 0.16
    cf_Wind_Onshore_ref = 2179/8760  # alternative 0.36
    cf_Wind_Offshore_ref = 3468/8760 # alternative 0.41
    region_ref = 'DEU'          # alternative ''
    # current FLH
    cf_PV_steam = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains(region_ref)) & (df_profiles_invest.columns.str.contains('Solar'))]].mean().mean()    
    cf_Wind_Onshore_steam = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains(region_ref)) & (df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().mean()  
    cf_Wind_Offshore_steam = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains(region_ref)) & (df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().mean()
    # flat correction factors # if these are too extreme you could remove the # before '** 0.5' to make the scaling factor closer to 1
    cor_fac_PV = (cf_PV_ref / cf_PV_steam) #** 0.5     
    cor_fac_Wind_Onshore = (cf_Wind_Onshore_ref / cf_Wind_Onshore_steam) #** 0.5  
    cor_fac_Wind_Offshore = (cf_Wind_Offshore_ref / cf_Wind_Offshore_steam) #** 0.5
    # apply UNIFORMLY TO ALL (!) cf_df
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]] * cor_fac_PV
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]] * cor_fac_Wind_Onshore
    df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]] = df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]] * cor_fac_Wind_Offshore

# reduce timesteps with cf over 1 to 1 (and correct cf under 0 to 0)
df_profiles_invest[df_profiles_invest>1]=1
df_profiles_invest[df_profiles_invest<0]=0

# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().sort_values().plot()
print('Wind_Offshore avg. cf global new: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Offshore'))]].mean().mean()))
# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().sort_values().plot()
print('Wind_Onshore avg. cf global new: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Wind_Onshore'))]].mean().mean()))
# df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean().sort_values().plot()
print('Solar avg. cf global new: ' + str(df_profiles_invest.loc[:,df_profiles_invest.columns[(df_profiles_invest.columns.str.contains('Solar'))]].mean().mean()))
# %%

list_subset_countries   = df_subset_nodes.Countries.to_list()
if not (set(list_subset_countries).issubset(set(df_demand.columns))):                   # brauchen wir den Demand hier wirklich? ## to klaer ##
    raise Exception('Country of subset is not present in the countries of the Plexos data')
demand_datetimes        = pd.to_datetime(df_demand["Datetime"],dayfirst=True,format="mixed")

nodes_solar             = [ x[-1] for x in solar.columns.str.split('|').tolist()]

## Add Continent codes to the country codes from the cost potential curves

continent_country_mapping = pd.DataFrame({'Plexos_code_country': nodes_solar[3:]})
continent_country_mapping['continent']  = continent_country_mapping['Plexos_code_country'].str.split('-', n=1).str[0]
continent_country_mapping['country']    = continent_country_mapping['Plexos_code_country'].str.split('-', n=1).str[1]

#dict(continent_country_mapping['country'], continent_country_mapping['Plexos_code_country'])
replace_dict = dict(zip(continent_country_mapping['country'].str[:3], continent_country_mapping['Plexos_code_country'].str[:6]))

df_profiles_invest_2 = df_profiles_invest.copy()


def replace_last_part(s,substring,replacement ):
    parts = s.split('|')
    if parts[-1] ==substring:
        parts[-1] = replacement
    return '|'.join(parts)

# Replace substrings in the DataFrame from countries to regions
for substring, replacement in replace_dict.items():
     df_profiles_invest_2.columns = df_profiles_invest_2.columns.map(lambda x: replace_last_part(x,substring = substring, replacement=replacement ))

renew_agg_subset= pd.concat([df_profiles_invest_2], axis = 1)

# %% aggregate to regions
#########################################################################################################
# Gewichtungsfaktor z.B. Gesamtflaeche, Leistungs- oder Energiepotenzial muss miteinbezogen werden 
# hier Leistungspotenzial gewaehlt (maximal zubaubare Kapazitaet -> candidate_units)
#########################################################################################################

# %%
renew_agg = (renew_agg_subset

             .T
             .reset_index(names='Units')
)

renew_agg['Countries'] = renew_agg['Units'].astype(str).str.split('|',expand=True)[2]

# Remove the node part in the last of the sequence after split by |
renew_agg['unit'] = renew_agg['Units'].str.split('|', expand=True).iloc[:, :-1].apply('|'.join, axis=1)

renew_agg = renew_agg.merge(df_subset_nodes, how='left', on='Countries')
renew_agg['Units'] = renew_agg['unit'] + "|" + renew_agg['Regions']

### weighted aggregation by each countries VRE potential ###

# VRE potential
df_candidate_units = df_RE_1dim_data[df_RE_1dim_data['Parameter_name'] == 'candidate_units']
#df_candidate_units['Object_names'] = df_candidate_units['Object_names'].str.replace('WINDInvest', 'Wind_OnshoreInvest').str.replace("WIND_OFFSHORE", "Wind_Offshore") 

# rename for merge
renew_agg['Object_names'] = renew_agg['unit'] + '|' + renew_agg['Countries'].str[-3:]
renew_agg = renew_agg.merge(df_candidate_units[['Object_names','Paramter_value']]).rename(columns={'Paramter_value':'potential_GW'})

## if you wanna compare to non weighted profiles do steps 1 - 3 commented below ##
# weigh capacity profiles by country potential (multiply)
renew_agg.loc[:,0:8759] = (renew_agg.loc[:,0:8759].T * renew_agg.loc[:,'potential_GW']).T   # step1: for non weighted profiles comment this out

# aggregation
renew_agg = renew_agg.drop(['Countries','Regions','unit'], axis = 1)

agg_dict = dict(zip(range(8760), 8760*['sum']))                                             # step2: for non weighted profiles change this from 'sum' to 'mean'
agg_dict.update({'potential_GW':'sum'})

renew_agg = renew_agg.groupby(['Units']).agg(agg_dict)
renew_agg.index.name = ''

# normalize capacity profiles by regional potential (divide)
renew_agg.loc[:,0:8759] = (renew_agg.loc[:,0:8759].T / renew_agg.loc[:,'potential_GW']).T   # step3: for non weighted profiles comment this out

df_combined        = pd.concat([pd.DataFrame(demand_datetimes),renew_agg.T], axis = 1 )

# %%
################# Write File #############################################################

df_combined.to_csv(outputfile, header=True, index=False)

#########################################################################################
#convert to BB format
df_bb = df_combined.drop(columns='Datetime').T
df_bb = df_bb.rename(columns=dict(zip(range(0,8760),'t' + pd.Series(range(1,8761)).astype(str).str.zfill(6)))).reset_index().rename(columns={'index':'flow'})
df_bb.insert(loc=1, column='node', value=df_bb['flow'].astype(str).str.split('|',expand=True)[2] + '_el')
df_bb['flow'] = df_bb['flow'].astype(str).str.split('|',expand=True)[0] + '|' + df_bb['flow'].astype(str).str.split('|',expand=True)[1]
df_bb.insert(loc=2, column='alternative', value='Base')
df_bb.insert(loc=3, column='forecast_index', value='f00')

df_bb = df_bb.fillna(0)

df_bb_subset = pd.concat([df_bb.iloc[:,0:4] ,df_bb.iloc[:, np.arange(model_start+3, model_start+model_duration+3) ]], axis = 1)   
id_columns = df_bb_subset.iloc[:,0:4].columns.to_list()
value_columns = df_bb_subset.iloc[:, np.arange(model_start+3, model_start+model_duration+3) ].columns.to_list() 
df_bb_subset = df_bb_subset.melt(id_vars=id_columns,value_vars=value_columns, var_name='time_step')

#### Adding the constraints for the Delegated Act for RFNBOs ####

if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    df_bb_subset_re = df_bb_subset.copy()
    df_bb_subset_re["node"] = df_bb_subset_re["node"].str.replace('_el','_re_el')
    df_bb_subset = pd.concat([df_bb_subset,df_bb_subset_re], axis = 0)

if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"
    df_bb_subset_re = df_bb_subset.copy()
    df_bb_subset_re["node"] = df_bb_subset_re["node"].str.replace('_el','_re_el')
    df_bb_subset = pd.concat([df_bb_subset,df_bb_subset_re], axis = 0)

if RFNBO_option == "Defossilized_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid"
    df_bb_subset_re = df_bb_subset.copy()
    df_bb_subset_re["node"] = df_bb_subset_re["node"].str.replace('_el','_re_el')
    df_bb_subset = pd.concat([df_bb_subset,df_bb_subset_re], axis = 0)

if RFNBO_option == "Add_and_Corr":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Additionality and Correlation ###
    alt_rfnbo = "Additionality_and_Correlation"
    df_bb_subset_re = df_bb_subset.copy()
    df_bb_subset_re["node"] = df_bb_subset_re["node"].str.replace('_el','_re_el')
    df_bb_subset = pd.concat([df_bb_subset,df_bb_subset_re], axis = 0)

if RFNBO_option == "All_at_once":
    print("Applying all regulations for RFNBOs" + "\n")
    ### All at once ###

df_bb_subset = df_bb_subset.loc[df_bb_subset['alternative'].isin(scenarios['alternative']),:]
df_bb_subset.to_csv(outputfile_BB, mode = 'w', header=True, index=False,float_format='%.2f')


# %% Format for importer
## 
# df_bb_strings = df_bb.iloc[:,0:4]
# df_bb_floats = df_bb.iloc[:,4:]

# # Function to format each row
# def format_row(row):
#     columns = row.index
#     data_list = []

#     # for column in columns:
#     #     data_list.append([column, row[column]])
#     data_list = [[column, row[column]] for column in columns]
#     formatted_data = ["f00", {"type": "map", "index_type": "str", "data": data_list}]
#     output_string = r'{"index_type": "str", "data":[' + json.dumps(formatted_data) + r"]}"
#     return output_string

# # Apply the function to each row
# formatted_data = df_bb_floats.apply(format_row, axis=1)
# df_formatted_data= pd.DataFrame({"formatted_data": formatted_data}).reset_index(drop = True)
# # Create a new DataFrame with the formatted data
# result_df = pd.concat([df_bb_strings.reset_index(drop=True),df_formatted_data ],axis = 1)

# result_df.iloc[0:10,].to_csv(outputfile_BB, mode = 'w', header=True, index=False,float_format='%.3f')

#from itables import init_notebook_mode
#init_notebook_mode(all_interactive=True)

print("\n" + "renewable profile data exported to: " + outputfile + "and " + outputfile_BB + "\n")

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
# %%
