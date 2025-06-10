# %%
import pandas as pd
import os
import sys

print('Execute in Directory:' + "\n")
print(os.getcwd()  + "\n")

try:        #use if run in spine-toolbox
    path_Main_Input = sys.argv[1]
    path_damodaran  = sys.argv[2]
    path_iso3166    = sys.argv[3]
    path_iso3166fix = sys.argv[4]
    path_ind_WACC   = sys.argv[5]
    path_output     = 'TEMP/weighted_WACC_final.csv'
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    path_Main_Input = 'PythonScripts/TEMP/MainInput.xlsx'
    path_damodaran  = 'Data/WACC/ctryprem_July24.xlsx'
    path_iso3166    = 'Data/WACC/alpha-3_countrycodes.csv'
    path_iso3166fix = 'Data/WACC/alpha-3_manual_fix.csv'
    path_ind_WACC   = 'Data/WACC/waccGlobal_Jan24_StEAM_config.xlsx'
    path_output     = 'PythonScripts/TEMP/weighted_WACC_final.csv'

## read files
subset_countries    = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})
model_config        = pd.read_excel(os.path.join(path_Main_Input), sheet_name="model_config")   # check what WACC data set is used in model_config.csv (Base is 2024, Alternative is IRENA's 2021)
df_ERP_damodaran    = pd.read_excel(path_damodaran, sheet_name='ERPs by country') # Equity Risk Premium dataset, currently used as WACC placeholder
df_iso3             = pd.read_csv(path_iso3166)[['name','alpha-3']]  # ISO 3166 alpha 3 country codes
df_iso3_fix         = pd.read_csv(path_iso3166fix, sep=';') # this is done manually to fix missing entries in ERP dataset
df_iso3_fix = df_iso3_fix.set_index(df_iso3_fix.columns[0])
df_iso3_fix.index.name = None
df_read_taxes       = pd.read_excel(path_damodaran, sheet_name='Country Tax Rates')
df_rf               = pd.read_excel(path_ind_WACC, sheet_name='Industry Averages')
df_std_dev          = pd.read_excel(path_ind_WACC, sheet_name='Industry Averages', header=8).loc[:,'Standard Deviation':'Basis Spread']
df_industry_WACC    = pd.read_excel(path_ind_WACC, sheet_name='Industry Averages', header=18).dropna(axis=0).drop(['Number of Firms','Tax Rate', 'Cost of Equity', 'Cost of Debt', 'After-tax Cost of Debt', 'Cost of Capital'], axis=1)
#  %%
## read ERP + Default Spread data
df_bounds = df_ERP_damodaran[df_ERP_damodaran[df_ERP_damodaran.columns[0]].str.contains('Country').fillna(False)]   # check where the first table with rating and market ERP data starts and where the second table with Policy Risk Services risk score derived ERP data starts

df_rating_and_market_ERP = pd.DataFrame(df_ERP_damodaran, index=range(df_bounds.index[0] + 1, df_bounds.index[1] - 1))  # convert first table to df
df_rating_and_market_ERP.columns = df_bounds.iloc[0].fillna('not_available')
df_rating_and_market_ERP = df_rating_and_market_ERP.drop(['Region', "Moody's rating",'Country Risk Premium','Country Risk Premium3','Has to be sorted in ascending order','not_available'], axis=1)
df_rating_and_market_ERP.loc[(df_rating_and_market_ERP['Total Equity Risk Premium'].isna()==False) & (df_rating_and_market_ERP['Total Equity Risk Premium'] > 0.3), 'Total Equity Risk Premium2'] = None  # remove outlier value from 10 year CDS capital cost entries
df_rating_and_market_ERP.loc[(df_rating_and_market_ERP['Sovereign CDS, net of US'].isna()==False) & (df_rating_and_market_ERP['Sovereign CDS, net of US'] > 0.2), 'Sovereign CDS, net of US'] = None   # remove outlier value from 10 year CDS capital cost entries

df_PRS_risk_score_ERP = pd.DataFrame(df_ERP_damodaran, index=range(df_bounds.index[1] + 1, len(df_ERP_damodaran)))  # convert second table to df
df_PRS_risk_score_ERP.columns = df_bounds.iloc[1]
df_PRS_risk_score_ERP = df_PRS_risk_score_ERP.dropna(axis=1, how='all').dropna(axis=0, how='any')
df_PRS_risk_score_ERP = df_PRS_risk_score_ERP.drop(['PRS Composite Risk Score', 'CRP'], axis=1).rename(columns={'Default Spread':'Default Spread (PRS risk score based)','ERP':'Total Equity Risk Premium (PRS risk score based)'})
df_PRS_risk_score_ERP

df_WACC = pd.concat([df_rating_and_market_ERP, df_PRS_risk_score_ERP], ignore_index=True)
df_WACC['ERP_WACC'] = (df_WACC['Total Equity Risk Premium']   # rating spread based
                       .fillna(df_WACC['Total Equity Risk Premium2'])               # 10y CDS spread based
                       .fillna(df_WACC['Total Equity Risk Premium (PRS risk score based)']))       # political risk score based        
                       # generate combined ERP df based on all 3 different kinds of available ERP Data
df_WACC['DS_WACC'] = (df_WACC['Rating-based Default Spread'] 
                       .fillna(df_WACC['Sovereign CDS, net of US'])
                       .fillna(df_WACC['Default Spread (PRS risk score based)']))
## connect WACC to subset_countries

df_WACC = df_WACC[['Country','ERP_WACC','DS_WACC']].merge(df_iso3.rename(columns={'name':'Country'}), on='Country', how='left')    # some entries missing
df_WACC['alpha-3'] = df_WACC['alpha-3'].fillna(df_iso3_fix['alpha-3'])  # missing entries fixed

WACCset_countres                = subset_countries.copy()
WACCset_countres['alpha-3']     = WACCset_countres['name'].str.split('-',expand=True)[1]
WACCset_countres['continent']   = WACCset_countres['name'].str.split('-',expand=True)[0]
WACCset_countres = WACCset_countres.merge(df_WACC, on='alpha-3', how='left')

## taxes
df_taxes = pd.concat([
    df_read_taxes[['Country','Tax Rate']].dropna(),                                                      # called "looked up for 2023"
    df_read_taxes[['Country.1',2023]].dropna().rename(columns={'Country.1':'Country',2023:'Tax Rate'})   # called "2023"
], ignore_index=True).drop_duplicates().reset_index(drop=True)
df_avg_tax = pd.DataFrame({
    'Region':['Europe average','Africa average','Latin America average','North America average','Oceania average','Asia average'],
    'continent':['EU','AF','SA','NA','OC','AS']}
    ).merge(
        df_read_taxes    # no data for Asia available in Damodaran Tax Data
        [['Region','Average Tax Rate']].dropna(), 
        on='Region', 
        how='left')
df_avg_tax.loc[df_avg_tax['Region'] == 'Asia average', 'Average Tax Rate'] = df_avg_tax.loc[df_avg_tax['Region'] == 'Asia average', 'Average Tax Rate'].fillna(0.198) # average according to taxfoundation.org 19.8% (2024)
WACCset_countres = WACCset_countres.merge(df_taxes, how='left', on='Country') # add taxes to WACC data

## fill in missing values for countries with its continents highest values (for both ERP and DS)
# ERP
df_missing_ERP_WACC = WACCset_countres.loc[WACCset_countres['ERP_WACC'].isna()]
for i in df_missing_ERP_WACC.index:
    WACCset_countres.loc[i,'ERP_WACC'] = float(WACCset_countres.loc[WACCset_countres['continent'] == WACCset_countres.loc[i,'continent'], 'ERP_WACC'].max())
# DS
df_missing_DS_WACC = WACCset_countres.loc[WACCset_countres['DS_WACC'].isna()]
for i in df_missing_DS_WACC.index:
    WACCset_countres.loc[i,'DS_WACC'] = float(WACCset_countres.loc[WACCset_countres['continent'] == WACCset_countres.loc[i,'continent'], 'DS_WACC'].max())
# Taxes
df_missing_tax_WACC = WACCset_countres.loc[WACCset_countres['Tax Rate'].isna()]
for i in df_missing_tax_WACC.index:
    WACCset_countres.loc[i,'Tax Rate'] = float(df_avg_tax.loc[df_avg_tax['continent'] == WACCset_countres.loc[i,'continent'], 'Average Tax Rate'].values[0])    # fill in missing numbers with continent average instead of max value
## assigning units to industry financial values: Beta, Debt and Equity ratio, Stock value std dev
# risk free rate rf
rf = df_rf.loc[df_rf[df_rf.columns[0]].str.contains('Long Term Treasury bond rate') == True,'Unnamed: 3'].values[0] # Long Term Treasury Bond Rate (US 10y bonds)
# standard deviation of stock value for industry volatility spread
df_std_dev = df_std_dev[:df_std_dev['Standard Deviation'].isnull().argmax()]
sds_025_050 = df_std_dev.loc[df_std_dev[df_std_dev['Standard Deviation'] == 0.250001].index.values[0],'Basis Spread'] # stdDev 0.25 - 0.5 (standart deviation of Stock value Spread)
sds_050_065 = df_std_dev.loc[df_std_dev[df_std_dev['Standard Deviation'] == 0.500001].index.values[0],'Basis Spread'] # stdDev 0.5 - 0.65

## assigning nodes to regional financial values: Equity Risk Premium, Country Default Spread and Country Tax Rate

df_concat_country_industry = pd.concat([pd.concat([WACCset_countres]*len(df_industry_WACC),ignore_index=True).sort_values(by='name', ascending=True).reset_index(drop=True),
                                        pd.concat([df_industry_WACC]*len(WACCset_countres), ignore_index=True)],
                                        ignore_index=False, axis=1)

# c_e
df_concat_country_industry['Cost of Equity'] = rf + df_concat_country_industry['ERP_WACC'] * df_concat_country_industry['Beta']
# %%
# c_d_before_tax
df_concat_country_industry.loc[(df_concat_country_industry['Std Dev in Stock'] < 0.5) & (df_concat_country_industry['Std Dev in Stock'] > 0.25), 'Cost of Debt'] = rf + df_concat_country_industry['DS_WACC'] + sds_025_050
df_concat_country_industry.loc[(df_concat_country_industry['Std Dev in Stock'] < 0.65) & (df_concat_country_industry['Std Dev in Stock'] > 0.5), 'Cost of Debt'] = rf + df_concat_country_industry['DS_WACC'] + sds_050_065
# c_d
df_concat_country_industry['After-tax Cost of Debt'] = df_concat_country_industry['Cost of Debt'] * (1 - df_concat_country_industry['Tax Rate'])
# WACC
df_concat_country_industry['Cost of Capital'] = df_concat_country_industry['E/(D+E)'] * df_concat_country_industry['Cost of Equity'] + df_concat_country_industry['D/(D+E)'] * df_concat_country_industry['After-tax Cost of Debt']
df_concat_country_industry = df_concat_country_industry.drop('Country', axis=1).merge(df_iso3.rename(columns={'name':'Country'}), on='alpha-3', how='left') # assign ISO Country names
df_concat_country_industry_agg = df_concat_country_industry.groupby(['Country','name','Regions','alpha-3','continent']).agg({'Cost of Capital':'mean'}).reset_index().rename(columns={'Cost of Capital':'real_WACC'})
# df_concat_country_industry

# ################
# ## 2021 WACC ###
# ################
if model_config.loc[model_config['Object'] == 'WACC_year','Value'].values[0] == '2021':
    df_WACC_2021 = pd.read_excel('C:/spineProjects/git/steam/Data/Szenario_data/03 - APS_scenario_data.xlsx', sheet_name='WACC_all')[['CountryCode','Parameter_value_2040']].drop_duplicates()
    df_concat_country_industry = df_concat_country_industry.drop('Cost of Capital', axis=1).merge(df_WACC_2021.rename(columns={'CountryCode':'name','Parameter_value_2040':'Cost of Capital'}), on='name', how='left')
elif model_config.loc[model_config['Object'] == 'WACC_year','Value'].values[0] == '2024':
    pass
else:
    sys.exit('Is your data folder and main config up to date? You have to select WACC year from [2021, 2024] in model_config.csv')

df_concat_country_industry_l = pd.DataFrame()

###reconfigure to long format
for i in df_concat_country_industry.index:
    df_country_industry_loop = df_concat_country_industry.loc[i]
    #extract row i from df_concat_country_industry
    df_country_industry_loop = df_country_industry_loop.to_frame().T
    df_country_industry_loop["Zuordnung Steam"] = df_country_industry_loop["Zuordnung Steam"].str.replace('[','').str.replace(']','')
    technology_list = df_country_industry_loop["Zuordnung Steam"].str.split(',')
    for element in technology_list.iloc[0]:
        df_concat_country_industry_loop_element = df_country_industry_loop.copy()
        df_concat_country_industry_loop_element["Zuordnung Steam"] = element
        df_concat_country_industry_l = pd.concat([df_concat_country_industry_l, df_concat_country_industry_loop_element], axis=0, ignore_index=True)

df_concat_country_industry_l = df_concat_country_industry_l.rename(columns={'name':'Countries', 'Cost of Capital':'WACC', "Zuordnung Steam":"unit"})

# ################

df_concat_country_industry.sort_values(by='name', ascending=True).to_csv(path_output, sep=';', index=False)
df_concat_country_industry_l.sort_values(by='Countries', ascending=True).to_csv(path_output.replace('.csv','_long.csv'), sep=';', index=False)
print('exported WACC data to: ' + path_output + "\n")
# %%