#%% 
import pandas as pd
import os
import pickle
import tsam.timeseriesaggregation as tsam
from numpy import random
import pandas as pd
import os
import shutil
import pickle
from pathlib import Path
import numpy as np
import sys
#from convertToGdx import convertToGdx

# %%


path_howToWrite             = 'PythonScripts/TimeSeriesAgg/howToWrite.txt'
path_excel_path_tmp         = 'PythonScripts/TimeSeriesAgg/writingSet.xlsx'
path_input_gdx              = 'backbone-master/input/inputData.gdx'
#path_input_gdx             = 'PythonScripts/TimeSeriesAgg/inputData.gdx'
path_template_investinit    = "PythonScripts/TimeSeriesAgg/resources/investInits/investInitSteam.gms"

# eps
eps     = float(0.0001)  # eps default value
try:        #use if run in spine-toolbox
    path_MainInput          = sys.argv[1]
    m_conf  = pd.read_excel(path_MainInput, sheet_name="model_config")
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
        os.chdir('..')
    path_MainInput          = r"PythonScripts\TEMP\MainInput.xlsx"  
    m_conf  = pd.read_excel(path_MainInput, sheet_name="model_config")      
eps     = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

path_output_investinit = 'backbone-master/input/investInit.gms'

bool_project_costs_to_full_year = 1
# Settings

#%%

os.getcwd()
if os.getcwd().find('TimeSeriesAgg') > -1:
    os.chdir('..')
    os.chdir('..')

if os.path.isfile(path_input_gdx) == False:
    raise Exception(f"{path_input_gdx} (input GDX does not exists)")

os.system(f"gdxxrw {path_input_gdx} output={path_excel_path_tmp} @{path_howToWrite}")

# %% Settings## IF length is zero the total time series is taken 
#numberOfPeriods = 1
#length = 0 
numberOfPeriods = 8
length = 24*7 # 24*7 # Length in hours

## Segmentation (hours per time step)
hoursPerTimeStep = 1

clusterMethod = 'adjacentPeriods'   # unsure if adjacentPeriods or hierarchical a better fit ## to do ##
clusterMethod_dict = {'averaging': 'averaging', 'kMeans': 'k_means', 'kMedoids': 'k_medoids', 
    'kMaxoids': 'k_maxoids', 'hierarchical': 'hierarchical', 'adjacentPeriods': 'adjacent_periods'}
clusterMethod = clusterMethod_dict[clusterMethod]

name = "StEAM"
inputFiles = path_excel_path_tmp
sheetNames = ["ts_cf", "ts_influx", "ts_node", "ts_unit"]

outputPath = 'Output'

ts_dict_pre = {"ts_cf": pd.DataFrame(), "ts_influx": pd.DataFrame(), "ts_node": pd.DataFrame(), "ts_unit": pd.DataFrame()}

# %% Read the time series
for sheetName in sheetNames:
    input = pd.read_excel(inputFiles, sheet_name=sheetName)
    if sheetName == "ts_cf":
        input.columns = ["flow", "node", "forecast index"] + input.columns.tolist()[3:]
        input.melt(id_vars=["flow", "node", "forecast index"], value_name='1', var_name='0',)
        input.set_index(["flow", "node", "forecast index"], inplace=True)
    if sheetName == "ts_influx":
        # input.set_index( inplace=True)
        input.columns = ["grid", "node", "forecast index"] + input.columns.tolist()[3:] #test
        input.melt(id_vars=["grid", "node", "forecast index"], value_name='1', var_name='0',)
        input.set_index(["grid", "node", "forecast index"], inplace=True)
    #if sheetName == "ts_node":
        #input.set_index(["grid", "node", "param_gnBoundaryTypes", "forecast"], inplace=True)
    #if sheetName == "ts_unit":
        #input.set_index(["unit", "param_unit", "forecast index"], inplace=True)
    ts_dict_pre[sheetName] = input


# %%
ts_dict= ts_dict_pre.copy()
ts_complete = pd.DataFrame()
for element in ts_dict:
    ts_dict[element].reset_index(inplace=True)
    if element == "ts_node":
        continue
    if element == "ts_unit":
        continue
    elif element == "ts_cf":
        ts_dict[element]["name"] = ts_dict[element]["flow"] + "-" + ts_dict[element]["node"] +"-"+ ts_dict[element]["forecast index"] + "-ts_cf"
        ts_dict[element] = ts_dict[element].drop(["flow", "node", "forecast index"], axis=1)
    elif element == "ts_influx":
        ts_dict[element]["name"] = ts_dict[element]["grid"] + "-" + ts_dict[element]["node"] +"-"+ ts_dict[element]["forecast index"] + "-ts_influx"
        ts_dict[element] = ts_dict[element].drop(["grid", "node", "forecast index"], axis=1)
    ts_dict[element] = ts_dict[element].set_index("name")
    ts_complete = pd.concat([ts_complete, ts_dict[element]])

ts_complete = ts_complete.fillna(0).T

os.remove(path_excel_path_tmp) 

# %%
#ts_complete = ts_complete.reset_index().pivot( columns="name", values=1)

# %%
df_length = len(ts_complete)

# Create a datetime vector with hourly resolution starting from 2015
datetime_vector = pd.date_range(start='2015-01-01', periods=df_length, freq='H')

# Update the DataFrame index with the datetime vector
ts_complete.index = datetime_vector


if length == 0:
    length = df_length

# %% Aggregation
aggregation = tsam.TimeSeriesAggregation(ts_complete,
                                          noTypicalPeriods = numberOfPeriods,
                                          hoursPerPeriod = length,
                                          clusterMethod= clusterMethod)

# %%
typPeriods = aggregation.createTypicalPeriods()
weights = aggregation.clusterPeriodNoOccur
clusterCenters = aggregation.clusterCenterIndices
clusterOrder = aggregation.clusterOrder

weights_df = pd.DataFrame([weights]).T
if bool_project_costs_to_full_year:
    weights_df = weights_df*8760/weights_df.sum()/length

# %%

df_index_match = aggregation.indexMatching()

# %%
with open(path_template_investinit, "r") as f:
     filedata = f.read()
# %%
newdata = filedata.replace("length", str(length))
newdata = newdata.replace("numberOfPeriods", str(numberOfPeriods))
newdata = newdata.replace("completeTSlen", str(df_length))
newdata = newdata.replace("num_number_candidate_periods", str(len(clusterOrder)))
newdata = newdata.replace("hoursPerTimeStep", str((hoursPerTimeStep)))
sample_string = ""
probability_string = ""
weight_string = ""
annuityWeight_string = ""
z_string = ""

 #%%
for i in range(len(weights_df)):
    # Index of t should start a 1, so t0000 is used for other stuff
    sample_string = sample_string+f"\tmsStart('invest', 's{i:03d}') = {clusterCenters[i]*length+1:03d};\n\tmsEnd('invest', 's{i:03d}') = {((clusterCenters[i]+1)*(length)+1):03d};\n"
    probability_string = probability_string  + f"\tp_msProbability('invest', 's{i:03d}') = 1;\n"
    weight_string = weight_string + f"\tp_msWeight('invest', 's{i:03d}') = {(weights_df.iloc[i, 0]):03f};\n"
    annuityWeight_string = annuityWeight_string + f"    p_msAnnuityWeight('invest', 's{i:03d}') = {(length*weights_df.iloc[i, 0]):03f}/8760;\n" # alternatively: '= {(1/numberOfPeriods):03f};\n"' (1/number of samples) -> 2c_objective.gms: this does not matter as long as the sum equals 1 and no intrayear invests or mothballs are occuring


for i in range(len(clusterOrder)):
    z_string = z_string+f"\tzs('z{i:03d}','s{clusterOrder[i]:03d}') = yes;\n"


# %%
newdata = newdata.replace("    // add sample timesteps", sample_string)
newdata = newdata.replace("    // add sample probability", probability_string)
newdata = newdata.replace("    // add sample weights", weight_string)
newdata = newdata.replace("    // add sample annuity weights", annuityWeight_string)
newdata = newdata.replace("    // add z string", z_string)
newdata = newdata.replace("replace_this_with_EPS", str(eps))

with open(path_output_investinit, "w") as f:
    f.write(newdata)

# shutil.copyfile("resources/backbone_input_gen/modelsInit.gms", os.path.join(outputPath,"modelsInit.gms"))
# shutil.copyfile("resources/backbone_input_gen/1_options.gms", os.path.join(outputPath,"1_options.gms"))
# shutil.copyfile("resources/backbone_input_gen/timeAndSamples.inc", os.path.join(outputPath,"timeAndSamples.inc"))
# # %%

# %%
