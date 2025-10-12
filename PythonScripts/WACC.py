# This script calculates the Weighted Average Costs of Capital (WACC) for a given set of countries and technologies
# developed for energy system modelers that want to use a better estimate than a 7% interest rate for investments

# standalone version available at https://github.com/kTelaar/StEAM_WACC
# developed as part of the StEAM model https://github.com/OliverLinsel/StEAM_model @ the chair of energy systems and energy economics of Ruhr-Universitaet Bochum
# authored by Konrad Telaar in 2024-2025

# %% import packages
import pandas as pd
import os
import sys

print('Execute in Directory:')
print(os.getcwd())

try:        #use if run in spine-toolbox
    path_Main_Input             = sys.argv[1]
    path_ctyprem_concat         = sys.argv[2]
    path_iso3166                = sys.argv[3]
    path_iso3166fix             = sys.argv[4]
    path_waccGlobal_concat      = sys.argv[5]
    path_taxes_update           = sys.argv[6]
    path_DGS10                  = sys.argv[7]
    path_T10YIE                 = sys.argv[8]
    path_steam_zuordnung        = sys.argv[9]
    path_output                 = 'TEMP/weighted_WACC_final.csv'
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    path_Main_Input             = 'PythonScripts/TEMP/MainInput.xlsx'
    path_ctyprem_concat         = 'Data/WACC/data_country/ctyprem_concat.xlsx'
    path_iso3166                = 'Data/WACC/country_codes/alpha-3_countrycodes.csv'
    path_iso3166fix             = 'Data/WACC/country_codes/alpha-3_manual_fix.csv'
    path_waccGlobal_concat      = 'Data/WACC/data_industry/waccGlobal_concat.xlsx'
    path_taxes_update           = 'Data/WACC/data_taxes/Statutory_Top_Corporate_Tax_Rates_and_Pillar_Two_Implementation.xlsx'
    path_DGS10                  = 'Data/WACC/data_riskfreerate/DGS10.csv'
    path_T10YIE                 = 'Data/WACC/data_riskfreerate/T10YIE.csv'
    path_steam_zuordnung        = 'Data/WACC/industry_technology_user_config.csv'
    path_output                 = 'PythonScripts/TEMP/weighted_WACC_final.csv'
# %%
#######################################################
## read config and data ###############################
#######################################################

# user configuration
subset_countries        = pd.read_excel(os.path.join(path_Main_Input), sheet_name="subset_countries").rename(columns={"Countries":"name"})  # read geographical configuration
model_config            = pd.read_excel(os.path.join(path_Main_Input), sheet_name="model_config")   # read financial year configuration
WACC_year               = int(model_config.loc[model_config['Object'] == 'WACC_year','Value'].values[0])
df_industry_unit_steam  = pd.read_csv(path_steam_zuordnung, sep=';', header=None).rename(columns={0:'Industry Name',1:'Zuordnung Steam'})    # read technological configuration

# alpha 3 country codes
df_iso3                 = pd.read_csv(path_iso3166)[['name','alpha-3']]  # ISO 3166 alpha 3 country codes
df_iso3_fix             = pd.read_csv(path_iso3166fix, sep=';') # this is done manually to fix missing entries
df_iso3_fix             = df_iso3_fix.set_index(df_iso3_fix.columns[0])
df_iso3_fix.index.name  = None

# taxes
df_read_taxes           = pd.read_excel(path_ctyprem_concat, sheet_name='Country Tax Rates')
df_taxes_update         = pd.read_excel(path_taxes_update, header=1)

# country risk premium for cost of equity and debt
df_WACC_update          = (pd.read_excel(path_ctyprem_concat, sheet_name='equity risk premium').rename(columns={WACC_year:'ERP_WACC'})[['Country', 'ERP_WACC']].merge( # country risk premium for cost of equity
        pd.read_excel(path_ctyprem_concat, sheet_name='default spread').rename(columns={WACC_year:'DS_WACC'})[['Country', 'DS_WACC']], on='Country', how='left'))    # coutnry risk premium for cost of debt

# risk-free rate
DGS10                       = pd.read_csv(path_DGS10) # 10y treasury yield
DGS10['observation_date']   = DGS10['observation_date'].str[:4]
T10YIE                      = pd.read_csv(path_T10YIE)   # 10y inflation
T10YIE['observation_date']  = T10YIE['observation_date'].str[:4]

# technogy risk premium as industrial beta and volatility spread
df_beta                 = pd.read_excel(path_waccGlobal_concat, sheet_name='beta')[['Industry Name',WACC_year]].rename(columns={WACC_year:'Beta'})
df_volatility_spread    = pd.read_excel(path_waccGlobal_concat, sheet_name='volatility spread')[['Industry Name',WACC_year]].rename(columns={WACC_year:'volatility spread'})

# equity share as weighting
df_equity_share = pd.read_excel(path_waccGlobal_concat, sheet_name='equity share')[['Industry Name',WACC_year]].rename(columns={WACC_year:'E/(D+E)'})

#######################################################
## start data preparation #############################
#######################################################

# assign nodes to country values: equity risk premium, debt default spread and country tax rate
df_WACC = (df_WACC_update
           .merge(df_iso3.rename(columns={'name':'Country'}), on='Country', how='left') # combine country names and alpha 3 country codes from subset_countries
           .merge(df_iso3_fix[['Country','alpha-3']], on='Country', how='left'))
df_WACC['alpha-3'] = df_WACC['alpha-3_x'].combine_first(df_WACC['alpha-3_y'])
df_WACC = df_WACC[df_WACC['alpha-3'].isna() == False].drop(columns=['alpha-3_x', 'alpha-3_y'])
df_WACC = df_WACC[df_WACC['ERP_WACC'].isna() == False]
subset_countries['alpha-3']     = subset_countries['name'].str.split('-',expand=True)[1]
subset_countries['continent']   = subset_countries['name'].str.split('-',expand=True)[0]
subset_countries = subset_countries.merge(df_WACC, on='alpha-3', how='left')

# assigning units to industry values: Beta, Debt and Equity ratio, volatility spread
df_debt_share = df_equity_share.rename(columns={'E/(D+E)':'D/(D+E)'})
df_debt_share.iloc[:,1] = (df_debt_share.iloc[:,1] - 1) * -1
df_industry_WACC = (df_industry_unit_steam
                    .merge(df_beta, on='Industry Name', how='left')
                    .merge(df_equity_share, on='Industry Name', how='left')
                    .merge(df_debt_share, on='Industry Name', how='left')
                    .merge(df_volatility_spread, on='Industry Name', how='left'))

# tax data
df_avg_tax = pd.DataFrame({'Region':['Europe average','Africa average','Latin America average','North America average','Oceania average','Asia average'],'continent':['EU','AF','SA','NA','OC','AS']}).merge(
        df_read_taxes[['Region','Average Tax Rate']].dropna(), on='Region', how='left') # no data for Asia available
df_avg_tax.loc[df_avg_tax['Region'] == 'Asia average', 'Average Tax Rate'] = df_avg_tax.loc[df_avg_tax['Region'] == 'Asia average', 'Average Tax Rate'].fillna(0.198) # average according to taxfoundation.org 19.8% (2024)
subset_countries = subset_countries.merge(df_taxes_update[['ISO 3','Corporate Tax Rate']].rename(columns={'ISO 3':'alpha-3', 'Corporate Tax Rate':'Tax Rate'}), on='alpha-3', how='left') # add taxes to WACC data
subset_countries['Tax Rate'] = subset_countries['Tax Rate'].str[:-1].astype(float) / 100    # convert from string with % symbol to float64 rate

# fill in missing values in country dataset (based on the maximum rates of the respective continent as countries that have no data available tend to be extremely high risk countries)
df_missing_ERP_WACC = subset_countries.loc[subset_countries['ERP_WACC'].isna()] # equity risk premium
for i in df_missing_ERP_WACC.index:
    subset_countries.loc[i,'ERP_WACC'] = float(subset_countries.loc[subset_countries['continent'] == subset_countries.loc[i,'continent'], 'ERP_WACC'].max())
df_missing_DS_WACC = subset_countries.loc[subset_countries['DS_WACC'].isna()] # debt default spread
for i in df_missing_DS_WACC.index:
    subset_countries.loc[i,'DS_WACC'] = float(subset_countries.loc[subset_countries['continent'] == subset_countries.loc[i,'continent'], 'DS_WACC'].max())
df_missing_tax_WACC = subset_countries.loc[subset_countries['Tax Rate'].isna()] # tax data
for i in df_missing_tax_WACC.index:
    subset_countries.loc[i,'Tax Rate'] = float(df_avg_tax.loc[df_avg_tax['continent'] == subset_countries.loc[i,'continent'], 'Average Tax Rate'].values[0])    # fill in missing numbers with continent average instead of max value

# combine country and industry data
df_concat_country_industry = pd.concat(
    [pd.concat([subset_countries]*len(df_industry_WACC),ignore_index=True).sort_values(by='name', ascending=True).reset_index(drop=True),
     pd.concat([df_industry_WACC]*len(subset_countries), ignore_index=True)],
     ignore_index=False, axis=1)

#######################################################
## start calculations #################################
#######################################################

# risk-free rate (dependent on configured year but independent of country and technology)
df_rf_update = DGS10.merge(T10YIE, on='observation_date', how='left').groupby('observation_date').agg({'DGS10':'mean','T10YIE':'mean'}).reset_index()
df_rf_update['risk free rate discounted'] = df_rf_update['DGS10'] - df_rf_update['T10YIE']  # this is the discounted or real risk-free rate (instead of the nominal)
rf = float(df_rf_update.loc[df_rf_update['observation_date'].astype(int) == WACC_year,'risk free rate discounted'].values[0] / 100)

# cost of equity
df_concat_country_industry['Cost of Equity'] = rf + df_concat_country_industry['ERP_WACC'] * df_concat_country_industry['Beta']
# cost of debt (before tax)
df_concat_country_industry['Cost of Debt'] = rf + df_concat_country_industry['DS_WACC'] + df_concat_country_industry['volatility spread']
# cost of debt (after tax)
df_concat_country_industry['After-tax Cost of Debt'] = df_concat_country_industry['Cost of Debt'] * (1 - df_concat_country_industry['Tax Rate'])
# WACC
df_concat_country_industry['Cost of Capital'] = df_concat_country_industry['E/(D+E)'] * df_concat_country_industry['Cost of Equity'] + df_concat_country_industry['D/(D+E)'] * df_concat_country_industry['After-tax Cost of Debt']
df_concat_country_industry = df_concat_country_industry.drop('Country', axis=1).merge(df_iso3.rename(columns={'name':'Country'}), on='alpha-3', how='left') # assign ISO Country names

#######################################################
## output #############################################
#######################################################

# alternative output options: uniform or technological-aggregated WACC
# uncomment if you want to use this
# df_concat_country_industry['Cost of Capital'] = 0.07    # Uniform WACC as Benchmark case for comparison
# df_concat_country_industry = df_concat_country_industry.groupby(['Country','name','Regions','alpha-3','continent']).agg({'Cost of Capital':'mean'}).reset_index().rename(columns={'Cost of Capital':'WACC_agg'})  # aggregate output to only display differences of countries (instead of countries and technologies, not usable in the StEAM_model workflow)

df_concat_country_industry.sort_values(by='name', ascending=True).to_csv(path_output, sep=';', index=False)

print('WACC data exported')
# %%