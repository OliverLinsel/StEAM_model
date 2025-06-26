"""
Develop transport system script

Created 2023
@author OL
reworked on 18.09.2023 OL
last fix 20240123 KT converted to BB
"""
# %%
#import modules
import sys
import geopandas as gpd
import os
from shapely.geometry import Point, Polygon, LineString, MultiPoint
from shapely.ops import triangulate
import pandas as pd
import searoute as sr
from matplotlib import pyplot as plt
import numpy as np
from itertools import combinations
from scipy.spatial import Delaunay
import time

############### Load Data ###############

print("Start reading transport nodes, terminals and parameters" + "\n")

print("Define the order of Tool arguments as follows:" + "\n")
print("[0] = nodes_and_parameters.xlsx" + "\n")
print("[1] = proposed_h2_terminals" + "\n")
print("[2] = bm_world_3000mdepthres1.shp" + "\n")
print("[3] = MainInput.xlsx" + "\n")
#print("[4] = world_eu_bz.shp" + "\n") #new in to define the european bidding zones

print('Execute in Directory:')
print(os.getcwd())

START = time.perf_counter() 

try:
    #use if run in spine-toolbox
    path_transport_nodes_and_parameters = sys.argv[1]
    path_transport_terminals            = sys.argv[2]
    path_deepsea                        = sys.argv[3]
    path_Main_Input                     = sys.argv[4]
    #20240808 obsolete
    #path_WACC_data                      = r'Data/Szenario_Data/03 - APS_scenario_data.xlsx' #needs to be adapted if scenario/year dependend
    #WACC_data                           = pd.read_excel(path_WACC_data, sheet_name="WACC_table")
    path_reg_fac_list                   = sys.argv[5]
    path_WACC_Update                    = sys.argv[6]
    outputfile                          = 'TEMP/transport_objects.xlsx'
    outputfile_BB                       = 'TEMP/transport_objects_BB.xlsx'
    visualisation_output                = '../Pythonscripts/TEMP/Visualisation/'
    world                               = gpd.read_file(os.path.join("..", "Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    #use if run in Python environment
    path_transport_nodes_and_parameters = 'Data/Transport/data_input/nodes/nodes_and_parameters.xlsx'
    path_reg_fac_list                   = 'Data/Transport/data_input/nodes/reg_fac_list.csv'
    path_transport_terminals            = 'Data/Transport/data_input/proposed_terminals/proposed_terminals.xlsx'
    path_deepsea                        = 'Data/Transport/data_input/bm_world_3000mdepth/bm_world_3000mdepthres1.shp'
    path_world                          = 'Data/Transport/data_input/world_eu_bz/world_eu_bz.shp'
    path_Main_Input                     = 'Pythonscripts/TEMP/MainInput.xlsx'
    #20240808 obsolete
    #path_WACC_data                      = r'Data/Szenario_Data/03 - APS_scenario_data.xlsx' #needs to be adapted if scenario/year dependend
    #WACC_data                           = pd.read_excel(path_WACC_data, sheet_name="WACC_table")
    path_WACC_Update                    = r".\PythonScripts\TEMP\weighted_WACC_final.csv"
    outputfile                          = 'Pythonscripts/TEMP/transport_objects.xlsx'
    outputfile_BB                       = 'Pythonscripts/TEMP/transport_objects_BB.xlsx'
    visualisation_output                = 'Pythonscripts/TEMP/Visualisation/'
    world                               = gpd.read_file(os.path.join("Data", "Transport", "data_input", "naturalearthdata", "ne_110m_admin_0_countries.shp")) #read the world regions shapefile

subset_countries                    = pd.read_excel(path_Main_Input, sheet_name='subset_countries').rename(columns={'Countries':'name'})
m_conf                              = pd.read_excel(path_Main_Input, sheet_name="model_config")

#read capacityMargin
capacityMargin_h2              = m_conf.loc[m_conf['Parameter'] == "capacityMargin_h2", "Value"].values[0] # capacityMargin read value

print("Start reading GIS base information" + "\n")

#import geopandas included shapefiles
world = world[["POP_EST", "CONTINENT", "NAME", "ISO_A3", "GDP_MD", "geometry"]]
world = world.rename(columns={"NAME":"name", "ISO_A3":"iso_a3", "POP_EST":"pop_est", "GDP_MD":"gdp_md_est", "CONTINENT":"continent"}) #renaming columns to match the ones in the nodeset

#define deepsea
deepsea = gpd.read_file(os.path.join(path_deepsea))

print("Succesfully read all files" + "\n")

############### Centrally define default model parameters ###############

#reading basic temporal model information from MainInput
time_period = pd.read_excel(os.path.join(path_Main_Input), sheet_name="model_date") #einlesen der xlsx in ein dataframe
t_start = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[0])
t_end = pd.to_datetime(pd.ExcelFile(path_Main_Input).parse("model_date").value[1])
default_alternative = pd.read_excel(pd.ExcelFile(path_Main_Input), sheet_name="model_date").alternative_name[0]
default_alternative = 'Base'
time_share   = ((t_end - t_start) / pd.Timedelta(hours=1)) * (1/8760) #share of the year
duration = round(((t_end - t_start) / pd.Timedelta(hours=1)) * (1/24)) #duration in days

#eps
eps                         = float(0.0000001)  # read the eps value of the model_config sheet in the excel file path_Main_Input and save the values as eps // eps default value
eps                         = float(m_conf.loc[m_conf['Parameter'] == "eps", "Value"].values[0]) # eps read value

#read RFNBO regulation option
RFNBO_option                       = m_conf.loc[m_conf['Parameter'] == "RFNBO_option", "Value"].values[0] # RFNBO read value

print("Alternative: " + str(default_alternative) + "\n")
initial_cap = 0
exclude_countries = 1   #if this is enabled Belarus and Russia are disconnected from the transport grid (which is probably a good idea all things considered)

con_flow_cost = 2           #connection flow costs
node_slack_pen              = 10**6             #slack penalty cost
con_cap_pipelines           = initial_cap       #pipeline connection capacity
con_cap_ships               = initial_cap       #ship connection capacity
initial_pipeline_capacity   = initial_cap       #initial capacity
fix_ratio_io = 0.95            #default transmission losses
default_WACC = 0.06                    #default WACCC
#lifetime = 20               #default lifetime
default_invest = 1000       #€/km/MW Pipeline default invest
bts = 0.85                   #share of nodes with balance_type_node
connection_investment_cost = 100
default_connection_investment_lifetime = 20
default_connection_investment_lifetime_js = "{\"type\": \"duration\", \"data\": \"" + str(duration) + "D\"}"
candidate_connections = 'inf' #default candidate connections
connection_flow_cost = eps
ship_speed = 16*1.852       #in km/h equals 13kn
pipeline_elongation_factor = 1.3 #factor by which the length of the pipelines are multiplied to account for non-direct connection between nodes.
h2_pipelines_offshore_factor = 1.7 #factor for cost increasing through subsea pipelines
offshore_factor_geometery_buffer = 1.0 #degrees for increasing the total_world geometry projection during determination of offshore or onshore pipelines/con_lines w 1 degree ~ 111km
initial_pipeline_capacity = 0 #no initial capacity
retrofit_pipeline_cost = 0.7 #share of cost of new pipeline for retrofitting
assumed_weighted_average_pipeline_capacity = 8000  #in MW, usedd for calculating relative fom costs ## (wich are currently not in use because Backbone does not feature fom costs for connections, only for units)

print("Succesfully defined default model parameters" + "\n")

############### Centrally define default model parameters ###############

#Dieser Teil im Script ist neu und ermöglicht es flexibler die Knotenpunkte anzupassen (alles bis auf Europa und wenige andere Staaten raus und dann einzelne Bundesländer für Deutschland)
#mit diesem Skript werden aus der Liste aus der neues nodes Datei die einzelnen nodes in ein dataframe geschrieben und die Koordinaten in ein funktionierendes geometry Objekt verpackt.
new_nodes = pd.read_excel(path_transport_nodes_and_parameters, sheet_name=0) #einlesen der xlsx in ein dataframe
#

# WACC Update 20240802
# get WACC data
df_WACC = pd.read_csv(path_WACC_Update, sep=';')[['name','Cost of Capital','Zuordnung Steam']]
# merge WACC data
new_nodes = new_nodes.drop('WACC', axis=1).merge(df_WACC[df_WACC['Zuordnung Steam'].str.contains('Pipeline')].rename(columns={'Cost of Capital':'WACC'}), on='name', how='left').drop('Zuordnung Steam', axis=1)

new_nodes = new_nodes.rename(columns={"attribute.1":"attribute_"})
new_nodes = new_nodes[["name", "value1", "value2", "alternative", "commodity", "balance_type", "connection_investment_cost", "connection_investment_lifetime", "fix_ratio_out_in_connection_flow", "connection_fom_cost", "WACC"]]

print("Succesfully imported nodes_parameters.xlsx" + "\n")

#only using the rows that match the name in subset_countries

new_nodes = new_nodes[new_nodes["name"].isin(subset_countries["name"])]
new_nodes_WACC_copy_local = new_nodes.copy()

if new_nodes.empty == True:
    r = 1
    print("no countries selected" + "\n")
else:
    r = 0

if len(new_nodes.index) <= 2:
    r = 1
    print("not enough countries selected for triangulation - choose at least 3 countries" + "\n")
else:
    r = 0

print("Succesfully selected countries" + "\n")

#20240808 obsolete
#Overwrite WACCs with the values from the WACC file
# WACC_data = WACC_data.drop(columns=["WACC_old"])
# WACC_data = WACC_data.rename(columns={"Plex_node_names":"name"})
# new_nodes["WACC"] = new_nodes["name"].map(WACC_data.set_index("name")["WACC"])

#aggregating the nodes if subset_countries contains values in column with the header "Regions"
if len(subset_countries["Regions"]) != 0:
    print("Aggregation enabled" + "\n")
    #adding a column with the respective regions from subset_countries to new_nodes
    new_nodes["Regions"] = new_nodes["name"].map(subset_countries.set_index("name")["Regions"])
    new_nodes_disag = new_nodes.copy()
    #aggregating the nodes by the regions
    new_nodes = new_nodes.groupby(["Regions", "alternative", "commodity"]).agg({"value1":"mean", "value2":"mean", "connection_investment_cost":"mean", "connection_investment_lifetime":"mean", "fix_ratio_out_in_connection_flow":"mean", "connection_fom_cost":"mean", "WACC":"mean"}) # this is where weighting of WACC's could be introduced
    new_nodes = new_nodes.reset_index()
    new_nodes["name"] = new_nodes["Regions"]
    new_nodes_WACC_copy_regional = new_nodes.copy()

else:
    print("Aggregation disabled")

print("Succesfully aggregated regions" + "\n")

new_nodes_points = new_nodes.apply(lambda row: Point(row.value1, row.value2), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte
#first lon then lat
new_nodes_points.head() #hier sind dann die geometry informationen drinne

new_nodes = gpd.GeoDataFrame(new_nodes, geometry=new_nodes_points) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
new_nodes.crs = {"init": "epsg:4326"} #anpassan der Projektion

new_nodes = new_nodes.rename(columns={"value1":"x", "value2":"y"})      #renaming coordinate columns
new_nodes["y"] = new_nodes["y"]*(-1)                                    #transforming latitude values to match Spine GUI requirement - can be left out for other frameworks
new_nodes["h2_node"] = new_nodes['name'] + "_h2"                        #defining name for hydrogen nodes

new_nodes["balance_type"] = "balance_type_node"
new_nodes["node_slack_penalty"] = node_slack_pen

new_nodes_points = new_nodes_disag.apply(lambda row: Point(row.value1, row.value2), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte
new_nodes_disag = gpd.GeoDataFrame(new_nodes_disag, geometry=new_nodes_points) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
new_nodes_disag.crs = "EPSG:4326" #anpassan der Projektion

#copying geometry information from world where new_nodes_disag are within the geometry of the row in world
world_regions = gpd.sjoin(world, new_nodes_disag, how="right", predicate="intersects")
world_regions = world_regions[["name_right", "Regions", "geometry", "balance_type", "connection_investment_lifetime"]]
world_regions = world_regions.rename(columns={"name_right":"name"})
#create lists of all countries that belong to each region
country_regions_list = world_regions.groupby("Regions").agg({"name": lambda x: list(x)})
#unify geometries on region names
world_regions = world_regions.dissolve(by="Regions", aggfunc={"name":"first", "balance_type":"first", "connection_investment_lifetime":"mean"})
world_regions = world_regions.merge(country_regions_list, on="Regions", how="left")
world_regions = world_regions.drop(columns=["name_x"])
world_regions = world_regions.rename(columns={"name_y":"list_of_countrycodes"})
world_regions = world_regions.reset_index()

set(new_nodes['Regions'])- set(world_regions['Regions'])
new_nodes["list_of_countrycodes"] = world_regions["list_of_countrycodes"]

print("Succesfully defined nodes dataframe" + "\n")

############### Transforming Shapely Points to Numpy Array and triangulating it ###############

tri_work_points = new_nodes["geometry"].copy()

listarray = []
for pp in tri_work_points:
    listarray.append([pp.x, pp.y])
tri_work_array = np.array(listarray)

plexos_nodes_triangulation = Delaunay(tri_work_array)

# Now I have one shapefile with building polygons. I would like to convert them into lines split at each vertex, keeping the original source info as an attribute (Name).
# Use .boundary method to convert the polygons to lines, and .coords to fetch the coordinates of each line segment. Then .explode:
# https://gis.stackexchange.com/questions/436679/how-to-convert-polygons-to-line-segments-using-python

coord_groups = [plexos_nodes_triangulation.points[x] for x in plexos_nodes_triangulation.simplices] #plexos_nodes_triangulation ist eine Variable von weiter oben die die Dreiecke der Delaunay Triangulation beinahtlet und hier in ein gpd Polygon umgebaut wird.
polygons = [Polygon(x) for x in coord_groups]

df = gpd.GeoDataFrame(columns=["geometry"])     #the polygon file is a list array which is now defined as "geometry" attribute of the gdf
df["geometry"] = polygons
df["geometry"] = df.geometry.boundary
dfline = gpd.GeoDataFrame(data=df, geometry='geometry')

def explodeLine(row):
    """A function to return all segments of a line as a list of linestrings"""
    coords = row.geometry.coords #Create a list of all line node coordinates
    parts = []
    for part in zip(coords, coords[1:]): #For each start and end coordinate pair
        parts.append(LineString(part)) #Create a linestring and append to parts list
    return parts

dfline["tempgeom"] = dfline.apply(lambda x: explodeLine(x), axis=1)     #Create a list of all line segments explodeLine(dfline)
dfline = dfline.explode("tempgeom")                                     #Explode it so each segment becomes a row (https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.explode.html)

dfline = gpd.GeoDataFrame(data=dfline, geometry='tempgeom')
dfline = dfline.drop('geometry', axis=1)
dfline.crs = df.crs                                                     #apply coordinate system
dfline = dfline.rename_geometry("geometry")

dfline = dfline.reset_index()
dfline = dfline.drop("index", axis=1)
dfline["starts_temp"] = dfline.apply(lambda x: [y for y in x['geometry'].coords[0]], axis=1)
dfline["ends_temp"] = dfline.apply(lambda x: [y for y in x['geometry'].coords[-1]], axis=1)

def retracer(df_retracer, station):
    geo_xy = []
    for ind in dfline.index:
        xy = df_retracer.loc[ind][station]
        slc = Point(xy)
        geo_xy.append(slc)
    return geo_xy

dfline["starts"] = retracer(dfline, "starts_temp")
dfline = dfline.drop("starts_temp", axis=1)
dfline["ends"] = retracer(dfline, "ends_temp")
dfline = dfline.drop("ends_temp", axis=1)
# %%
nodes_starts = new_nodes[["h2_node", "geometry", "alternative", "commodity", "connection_investment_cost", "WACC", "fix_ratio_out_in_connection_flow", "connection_investment_lifetime"]]
nodes_ends = new_nodes[["h2_node", "geometry", 'WACC']]
nodes_starts = nodes_starts.rename(columns={"h2_node":"h2_node1", "geometry":"starts"})
nodes_ends = nodes_ends.rename(columns={"h2_node":"h2_node2", "geometry":"ends",'WACC':'WACC2'})
h2_pipelines = dfline.merge(nodes_starts, on="starts", how="left")
h2_pipelines = h2_pipelines.merge(nodes_ends, on="ends", how="left")
h2_pipelines["name"] = h2_pipelines["h2_node1"]+"_"+h2_pipelines["h2_node2"]
h2_pipelines = h2_pipelines.set_geometry("geometry")
h2_pipelines = h2_pipelines.set_crs(4326, allow_override=True)
h2_pipelines = h2_pipelines.drop(columns=["starts","ends"]) #dropping the deepsea pipelines by indexes

# https://geopandas.org/en/stable/docs/reference/api/geopandas.GeoSeries.length.html
h2_pipelines_proj = h2_pipelines.to_crs(crs=3857)    #, allow_override=True)
h2_pipelines_proj["length"] = h2_pipelines_proj.length    #calculating the length of the linestring elements
h2_pipelines["length"] = h2_pipelines_proj.length*pipeline_elongation_factor/1000   #pipeline elongation factor

#dropping the very long pipelines (mostly through the arctic)
#https://geopandas.org/en/stable/docs/reference/api/geopandas.GeoSeries.length.html
h2_pipelines = h2_pipelines.drop(h2_pipelines[h2_pipelines.length >= 80].index)

#dropping all pipelines crossing the deep sea
poly_union = deepsea.geometry.unary_union #combining all deepsea polygons to one multipolygon
subset = gpd.sjoin(h2_pipelines, deepsea, how='inner', predicate='intersects') #pipelines that cross the deepsea
h2_pipelines = h2_pipelines.drop(index = subset.index) #dropping the deepsea pipelines by indexes

if exclude_countries == 1:
    #dropping pipelines through Belarus and Russia
    bel_rus = world[world["name"].isin(["Belarus", "Russia"])]
    subset_bel_rus = gpd.sjoin(h2_pipelines, bel_rus, how='inner', predicate='intersects') #pipelines that cross Belarus or Russia
    h2_pipelines = h2_pipelines.drop(index = subset_bel_rus.index) #dropping the connections crossing Belarus and Russia

#select all pipelines crossing the sea to differentiate land pipelines and sbusea pipelines
h2_pipelines2 = h2_pipelines[["name","geometry"]]
world2 = world[["name","geometry"]]
world2["same"] = 1  #defining one value that is the same in all rows
total_world = world2.dissolve(by='same', aggfunc='sum').reset_index()[['same', 'geometry', "name"]]  # combine country areas to one multipolygon, keep column names in one line
total_world.geometry = total_world.geometry.buffer(offshore_factor_geometery_buffer) #enlarge landmass projection by factor
subset2 = gpd.sjoin(h2_pipelines2, total_world, how='inner', predicate='within') #pipelines that do not cross the sea
#%%
subset2 = subset2.drop(columns={"name_right"})
subset2 = subset2.rename(columns={"name_left":"name"})
subset2_list = subset2.name
onshore_connections_names_list = subset2_list.values.tolist()
h2_pipelines["shore"] = h2_pipelines_offshore_factor
# %%
print("Hier1 Lebenszeit:" + str(default_connection_investment_lifetime) + "\n")

h2_pipelines.loc[h2_pipelines["name"].isin(onshore_connections_names_list), "shore"] = 1
h2_pipelines["connection_investment_lifetime"] = h2_pipelines["connection_investment_lifetime"].fillna(default_connection_investment_lifetime)
h2_pipelines["connection_investment_lifetime_js"] = default_connection_investment_lifetime_js
h2_pipelines["connection_flow_cost"] = con_flow_cost
h2_pipelines["connection_capacity"] = initial_pipeline_capacity
h2_pipelines["annuity_factor"] = ((h2_pipelines.WACC + h2_pipelines.WACC2)/2) / (1 - (1 + ((h2_pipelines.WACC + h2_pipelines.WACC2)/2)) ** (-1 * h2_pipelines.connection_investment_lifetime))  #updated to use average of WACC's of both countries instead of just 1
h2_pipelines["connection_investment_cost_BB"] = h2_pipelines["length"]*h2_pipelines.connection_investment_cost*h2_pipelines.shore
h2_pipelines["connection_investment_cost"] = h2_pipelines.connection_investment_cost_BB
h2_pipelines["connection_investment_variable_type"] = "variable_type_continuous"
h2_pipelines["candidate_connections"] = candidate_connections
# %%
## h2 pipeline fom cost derivation
# based on absolute values in EUR/km*a has to be transformed to EUR/MW*km*a, this results in an underestimation of fomCosts for small pipelines and overestimation for big pipelines (but is necessary to avoid integer investments)
# dividing the EUR/km*a FOM cost by the weighted average pipeline capacity of 
assumed_weighted_average_pipeline_capacity  #defined at the script header config section

h2_pipelines = h2_pipelines.merge(new_nodes[['h2_node','connection_fom_cost']].rename(columns={'h2_node':'h2_node1'}), on='h2_node1', how='left')   # EUR/km*a      #offshore onshore not yet considered
h2_pipelines['connection_fom_cost_MW'] = h2_pipelines['connection_fom_cost'] * h2_pipelines['shore'] / assumed_weighted_average_pipeline_capacity   # EUR/km*MW*a   #offshore onshore now considered
h2_pipelines['connection_fom_cost_MW_complete'] = h2_pipelines['connection_fom_cost_MW'] * h2_pipelines["length"]                                   # EUR/MW*a

#this results compared to invest in relative fom costs of
h2_pipelines['rel_ratio_fom_to_invCosts'] = pd.Series(round(h2_pipelines['connection_fom_cost_MW_complete'] / h2_pipelines['connection_investment_cost'], ndigits=5))
print('with the assumed average pipeline capacity of:    ' + str(assumed_weighted_average_pipeline_capacity) + ' MW    relative fom costs of:    ' + str(list(h2_pipelines['rel_ratio_fom_to_invCosts'].unique())) + '    of invCosts are used')    #offshore pipelines are assumed to be more expensive to build and also equally more expensive to maintain

print("Succesfully triangulated pipeline connections" + "\n")

############### Discount for retrofitting pipelines ###############

#list of countries in subset_countries that start with "EU"
# list_of_existing_network_countries = subset_countries[subset_countries["name"].str.startswith("EU")]["Regions"].values.tolist()
#multiply connection_investment_cost_BB by retrofit_pipeline_cost
h2_pipelines["connection_investment_cost_BB"] = h2_pipelines["connection_investment_cost_BB"] * retrofit_pipeline_cost #ToDo - momentarily no sorting of the countries

############### Import read and geoparametereize terminals ###############

#mit diesem Skript werden aus der Liste aus der proposed_h2_terminals.csv Datei die einzelnen h2 terminals in ein dataframe geschrieben und die Koordinaten in ein funktionierendes geometry Objekt verpackt.
terminals = pd.read_excel(os.path.join(path_transport_terminals), sheet_name=0) #einlesen der xlsx in ein dataframe
# terminals = terminals[terminals['commodity'] == 'h2'] # filter to only include h2 technology (no nh3 etc)
#only using the rows that match the name in subset_countries

terminals['node'] = terminals['node'].str.split('-', expand=True)[0] + '-' + terminals['node'].str.split('-', expand=True)[1]   # assign sub countries to main country e.g. SA-BRA-SE to SA-BRA (otherwise BRA, CHN, USA etc. won't get any Terminals)
terminals = terminals[terminals["node"].isin(subset_countries["name"])]

# WACC Update 20240802
# %% merge WACC data
terminals = terminals.drop('WACC', axis=1)
terminals = terminals.merge(df_WACC[df_WACC['Zuordnung Steam'].str.contains('Ships')].rename(columns={'name':'node','Cost of Capital':'WACC_shipping'}), on='node', how='left').drop('Zuordnung Steam', axis=1)
terminals = terminals.merge(df_WACC[df_WACC['Zuordnung Steam'].str.contains('Cracker')].rename(columns={'name':'node','Cost of Capital':'WACC_conversion'}), on='node', how='left').drop('Zuordnung Steam', axis=1)     # HaberBosch, Cracker & Liquefaction, Regasification all have the same WACC values due to being in the same industrial risk data column

if terminals.empty == True:
    q = 1
    print("no nodes with terminals selected" + "\n")
else:
    q = 0

if len(terminals["terminal_name"].unique()) <= 1:
    q = 1
    print("not enough nodes with terminals selected" + "\n")
else:
    q = 0

terminal_points = terminals.apply(lambda row: Point(row.longitude, row.latitude), axis=1) #axis=1 macht, dass es von Reihe zu Reihe geht und nicht von Spalte zu Spalte #first lon then lat
terminals = gpd.GeoDataFrame(terminals, geometry=terminal_points) #hier werden die geo infos in die neue Spalte geometry im geodataframe eingefügt
terminals.crs = {"init": "epsg:4326"} #anpassen der Projektion

#now the h2_terminals["nodes_el"] will be compared to the node list in new_nodes["list_of_countrycodes"] and then the respective new_nodes["Regions"] will be written in the column h2_terminals["Regions"]
new_nodes_regions = new_nodes[["list_of_countrycodes", "Regions"]]
for t in new_nodes_regions.index:
    list_of_countrycodes = new_nodes_regions.loc[t, "list_of_countrycodes"]
    region_of_country = new_nodes_regions.loc[t, "Regions"]
    terminals.loc[terminals["node"].isin(list_of_countrycodes), "Regions"] = region_of_country

print("Succesfully defined h2 terminals" + "\n")

## complete fom pipeline cost allcoation with reg_facs
reg_fac_list = pd.read_csv(path_reg_fac_list, sep=';')  # read reg_fac list for pipeline fom costs (and fom costs in general) based on PLEXOS nodes
reg_fac_list = subset_countries.rename(columns={'name':'node'}).merge(reg_fac_list, on='node').drop('node', axis=1).drop_duplicates().reset_index(drop=True)    # merge reg_fac to current subset countries
reg_fac_list = reg_fac_list.groupby('Regions').agg({'reg_fac':'mean'}).reset_index()    # aggregate average reg_facs to each configured Region
reg_fac_list['Regions'] = reg_fac_list['Regions'] + '_h2'   # use name of h2_pipelines

h2_pipelines['reg_fac1'] = h2_pipelines.merge(reg_fac_list.rename(columns={'Regions':'h2_node1'}), on='h2_node1')['reg_fac']    # node1
h2_pipelines['reg_fac2'] = h2_pipelines.merge(reg_fac_list.rename(columns={'Regions':'h2_node2'}), on='h2_node2')['reg_fac']    # node2
h2_pipelines['reg_fac'] = (h2_pipelines['reg_fac1'] + h2_pipelines['reg_fac2']) / 2
h2_pipelines['reg_fac'] = (h2_pipelines['reg_fac'] + 1) / 2
h2_pipelines['connection_investment_cost_BB'] = h2_pipelines['connection_investment_cost_BB'] + (h2_pipelines['connection_fom_cost_MW_complete'] * ((h2_pipelines['reg_fac1'] + h2_pipelines['reg_fac2']) / 2) / h2_pipelines['annuity_factor'])    #add fomCosts to invCosts based on average reg_fac and average WACC of origin and destination region

############### Connect terminals to nodes ###############
con_line = pd.DataFrame() #empty dataframe for the connection lines

con_line3 = (terminals[
    ["terminal_name", "Regions", "alternative", "commodity", "node", "geometry", "WACC_conversion",'WACC_shipping', "terminal_connection_invest", "terminal_connection_fom_rel", "reg_fac", "terminal_connection_eff", "liquefaction_cost", "liquefaction_fom_rel","transf_lifetime", "transf_efficiency_substantial", "transf_efficiency_energetic", "regasification_cost", "regasification_fom_rel", "retransf_invest_cost", "retransf_lifetime", "retransf_efficiency_substantial", "retransf_efficiency_energetic"]]
    .merge(new_nodes_WACC_copy_regional[['name','WACC']].drop_duplicates().rename(columns={'name':'Regions','WACC':'WACC_pipeline_regional'}), on='Regions', how='left')
    .merge(new_nodes_WACC_copy_local[['name','WACC']].drop_duplicates().rename(columns={'name':'node','WACC':'WACC_conline_local'}), on='node', how='left')
)
# con_line3['delta_abs'] = con_line3['WACC_pipeline_regional'] - con_line3['WACC_conline_local']    # Auswertung fuer lokale WACC Differenzen innerhalb einer Region kann hier ansetzen (Terminal != Region) ## to do ##

if q == 0:
    con_line3 = con_line3.rename_geometry("geo1")
    con_line2 = new_nodes[["name", "Regions", "geometry", "connection_investment_lifetime"]]
    con_line2 = con_line2.rename_geometry("geo2")
    con_line2 = con_line2.rename(columns={"name":"node"})

    con_line = con_line3.merge(con_line2, on="Regions")
    con_line = con_line.drop(columns=["node_x","node_y"])

    con_line_geo = []
    for ind in con_line.index:
        coord_t = con_line.loc[ind]["geo1"]
        coord_n = con_line.loc[ind]["geo2"]
        clg = LineString([coord_t, coord_n])
        con_line_geo.append(clg)

    con_line = gpd.GeoDataFrame(con_line, geometry=con_line_geo, crs="EPSG:4326")
    con_line = con_line.drop(columns=["geo1","geo2"])

    # https://geopandas.org/en/stable/docs/reference/api/geopandas.GeoSeries.length.html
    con_line_proj = con_line.to_crs(crs=3857)    #, allow_override=True)"ESRI:54012"
    con_line_proj["length"] = con_line_proj.length    #calculating the length of the linestring elements
    con_line["length"] = con_line_proj.length*pipeline_elongation_factor/1000 #include pipeline elongation factor

    con_line["node1"] = con_line["terminal_name"]
    con_line["node2"] = con_line["Regions"]
    con_line["name"] = con_line["node1"] #+ "_" + con_line["node2"]
    
    #base parameters
    con_line["alternative"] = con_line["alternative"].fillna(default_alternative)
    con_line["commodity"] = con_line["commodity"]
    con_line["connection_type"] = "connection_type_normal"
    con_line["connection_capacity"] = con_cap_pipelines #alt. con_cap_def
    con_line["connection_flow_cost"] = con_flow_cost

#############################################################################################################
##reconfigure con_line to represent only the pipeline from the h2 demand node to the terminal location
    con_line["fix_ratio_out_in_connection_flow_origin"]         = con_line.terminal_connection_eff#*con_line.transf_efficiency_substantial   * con_line.transf_efficiency_energetic
    con_line["fix_ratio_out_in_connection_flow_destination"]    = con_line.terminal_connection_eff#*con_line.retransf_efficiency_substantial * con_line.retransf_efficiency_energetic
    con_line["fix_ratio_out_in_connection_flow"] = (con_line["fix_ratio_out_in_connection_flow_origin"] + con_line["fix_ratio_out_in_connection_flow_destination"]) / 2
    # %%
    #investment parameters
    con_line["connection_investment_cost_origin_BB"]        = ((con_line["length"] * con_line.terminal_connection_invest))# * (1 + con_line.terminal_connection_fom_rel * con_line.reg_fac)))# + con_line.liquefaction_cost * (1 + con_line.liquefaction_fom_rel * con_line.reg_fac)))       ## to do ## fom cost und invest cost auseinander ziehen, hier passiert, im Rest des Skriptes noch nicht (Ships, Pipelines)
    con_line["annuity_factor_origin"]                       = ((con_line.WACC_pipeline_regional + con_line.WACC_conline_local)/2) / (1 - (1 + (con_line.WACC_pipeline_regional  + con_line.WACC_conline_local)/2) ** (-1 * con_line.connection_investment_lifetime))    # use simple average between regional WACC and local terminal WACC for conline pipelines
    con_line["connection_investment_cost_origin"]           = con_line.connection_investment_cost_origin_BB * con_line.annuity_factor_origin                    #OUTDATED ## SPINE ONLY ##
    con_line["connection_investment_cost_destination_BB"]   = ((con_line["length"] * con_line.terminal_connection_invest))# * (1 + con_line.terminal_connection_fom_rel * con_line.reg_fac)))# + con_line.regasification_cost * (1 + con_line.regasification_fom_rel * con_line.reg_fac) + con_line.retransf_invest_cost))
    con_line["annuity_factor_destination"]                  = ((con_line.WACC_pipeline_regional  + con_line.WACC_conline_local)/2) / (1 - (1 + (con_line.WACC_pipeline_regional  + con_line.WACC_conline_local)/2) ** (-1 * con_line.connection_investment_lifetime))
    con_line["connection_investment_cost_destination"]      = con_line.connection_investment_cost_destination_BB * con_line.annuity_factor_destination          #OUTDATED ## SPINE ONLY ##
    
    #%%
    con_line['shore']               = gpd.sjoin(con_line, total_world, how='inner', predicate='within')['index_right']  # check if the con_line is on water (currently 50 of 76 are touching water compared to 36 of 72 h2_pipelines... seems like a lot. Could be that terminals are placed IN the water instead of NEAR the water) ## to do ##
    con_line['shore']               = con_line['shore'].fillna(h2_pipelines_offshore_factor)

    con_line["connection_investment_cost_BB"]               = con_line['shore'] * ((con_line.connection_investment_cost_origin_BB + con_line.connection_investment_cost_destination_BB) / 2) ## to do ## hier koennen wir die Daten auftrennen um den unterschiedlichen Investkosten von Liquefaction und Regasifcation gerecht zu werden (aktuell tuen wir so als ob Export und Import die gleichen Investkosten pro MW haben, Regasification sollte aber wesentlich guenstiger sein)

    con_line                                    = con_line.merge(new_nodes[['Regions','connection_fom_cost']], on='Regions', how='left')            # EUR/km*a      #offshore onshore not yet considered
    con_line['connection_fom_cost_MW']          = con_line['connection_fom_cost'] * con_line['shore'] / assumed_weighted_average_pipeline_capacity  # EUR/km*MW*a   #offshore onshore now considered
    con_line['connection_fom_cost_MW_complete'] = con_line['connection_fom_cost_MW'] * con_line["length"]                                           # EUR/MW*a
    # %%
    con_line['reg_fac']                             = (con_line['reg_fac'] + 1) / 2
    con_line["annuity_factor"]                      = (con_line.annuity_factor_origin + con_line.annuity_factor_destination) / 2
    con_line["connection_investment_variable_type"] = "variable_type_continuous"                                                                      #OUTDATED ## SPINE ONLY ##
    con_line["connection_investment_lifetime"]      = con_line.connection_investment_lifetime
    con_line["candidate_connections"]               = candidate_connections
    con_line["com_name"]                            = con_line["commodity"] + "_" + con_line["name"]
    con_line['connection_investment_cost_BB']       = con_line['connection_investment_cost_BB'] + con_line['connection_fom_cost_MW_complete'] * (con_line['reg_fac'] / con_line['annuity_factor'])    #add fomCosts to invCosts based on average reg_fac and average WACC of origin and destination region
    # con_line['relative_verteuerung_fom'] = (con_line['connection_investment_cost_BB'] + con_line['connection_fom_cost_MW_complete'] * (con_line['reg_fac'] / con_line['annuity_factor']))/(con_line['connection_investment_cost_BB'])   # niedrige WACC's und hohe reg_fac's sorgen fuer eine relativ hohe Verteuerung von bis zu 42% (EU-NLD), hohe WACC's und niedrige reg_fac's sorgen fuer eine sehr geringe Verteuerung von minimal 0.8% (AF-TZA), im Durchschnitt sorgen die fomCosts auf ein Jahr gerechnet fuer eine Verteuerung von 15%
# %%
print("Succesfully connected nodes and terminals" + "\n")

############### Calculating searoutes ###############

def calculate_searoute(origin, destination):
    origin_lon = terminals.query(f"terminal_name=='{origin}'")["longitude"].values
    origin_lat = terminals.query(f"terminal_name=='{origin}'")["latitude"].values
    destination_lon = terminals.query(f"terminal_name=='{destination}'")["longitude"].values
    destination_lat = terminals.query(f"terminal_name=='{destination}'")["latitude"].values
    p_origin = [origin_lon[0], origin_lat[0]]
    p_destination = [destination_lon[0], destination_lat[0]]
    route = sr.searoute(p_origin, p_destination, speed_knot = 13, append_orig_dest= True)
    sr_geo = LineString(route["geometry"]["coordinates"])
    return route["properties"]["duration_hours"], route["properties"]["length"], route["geometry"]["coordinates"], sr_geo

#%%

if q == 0:
    names = (terminals.terminal_name.to_list())
    names = set(names)
    names = list(names)
    combinations_names = np.array(list(combinations(names, 2)))

    df_sr = pd.DataFrame(columns=["origin", "destination"])

    df_sr["origin"] = combinations_names[:,0]
    df_sr["destination"] = combinations_names[:,1]

    duration_list = []
    length_list = []
    coord_list = []
    geo_list = []

    for i in df_sr.index:
        o = df_sr.iloc[i]["origin"]
        d = df_sr.iloc[i]["destination"]
        duration, length, coord, sr_geo_out = calculate_searoute(o, d)
        duration_list.append(duration)
        length_list.append(length)
        coord_list.append(coord)
        geo_list.append(sr_geo_out)

    df_sr["duration_hours"] = duration_list
    df_sr["length_km"] = length_list
    df_sr["coordinates"] = coord_list

    df_sr = gpd.GeoDataFrame(df_sr, geometry=geo_list, crs="EPSG:4326")
    df_sr["connection_type"] = "connection_type_normal"

#%%

print("Succesfully built searoutes" + "\n")

############### Export the finished transport system ###############
# %% 
if q == 0:
    total_shipping = pd.DataFrame()
    x_shipping = df_sr[["origin", "destination", "duration_hours", "length_km", "geometry", "connection_type"]]
    y_shipping = terminals[["terminal_name", "commodity", "node", "latitude", "longitude", "alternative", "WACC_shipping", "ship_invest", "ship_fom_rel", "reg_fac", "ship_fuel_consumption", "ship_lifetime", "ship_efficiency_1", "ship_efficiency_2"]]
    y_shipping = y_shipping.rename(columns={"terminal_name":"origin",'node':'node_origin','WACC_shipping':'WACC_origin','reg_fac':'reg_fac_origin'})
    total_shipping = x_shipping.merge(y_shipping, on="origin", how="left")
    total_shipping =     total_shipping = total_shipping.merge(terminals[['terminal_name','node','WACC_shipping','reg_fac']].drop_duplicates().rename(columns={'terminal_name':'destination','WACC_shipping':'WACC_destination','reg_fac':'reg_fac_destination','node':'node_destination'}), on='destination', how='left')

    total_shipping["origin"]        = total_shipping["commodity"] + "_" + total_shipping["origin"]
    total_shipping["destination"]   = total_shipping["commodity"] + "_" + total_shipping["destination"]
    total_shipping["name"]          = total_shipping["origin"] + "_" + total_shipping["destination"]

    total_shipping["WACC"]              = (total_shipping["WACC_origin"] + total_shipping["WACC_destination"]) / 2          # mean WACC
    total_shipping["reg_fac"]           = (total_shipping["reg_fac_origin"] + total_shipping["reg_fac_destination"]) / 2    # mean reg_fac
    total_shipping["reg_fac"]           = (total_shipping["reg_fac"] + 1) / 2                                               # only use reg_fac (labor cost factor) for 50% of fomCosts (rest is assumed to be material cost)
    total_shipping["annuity_factor"]    = (total_shipping["WACC"]) / (1 - (1 + total_shipping["WACC"]) ** (-1 * total_shipping.ship_lifetime))
    #total_shipping["connection_flow_cost"] = total_shipping.h2_ship_fuel_consumption * total_shipping.length_km #currently covered in efficiency thorugh h2 self consumption
    #total_shipping["alternative"] = total_shipping["alternative"].fillna(default_alternative)
    total_shipping["connection_investment_cost_BB"] = (total_shipping.length_km*total_shipping.ship_invest * (1+(total_shipping.ship_fom_rel*total_shipping.reg_fac)/total_shipping.annuity_factor))
    total_shipping["connection_investment_cost"] = total_shipping.connection_investment_cost_BB
    total_shipping["connection_investment_variable_type"] = "variable_type_continuous"
    total_shipping["connection_investment_lifetime"] = total_shipping.ship_lifetime
    total_shipping["candidate_connections"] = candidate_connections
    total_shipping["fix_ratio_out_in_connection_flow"] = total_shipping.ship_efficiency_1 * (1 - total_shipping.ship_efficiency_2 * total_shipping.length_km) #flash efficiency of the h2 ship
    total_shipping["connection_capacity"] = con_cap_ships
    total_shipping["connection_flow_cost"] = 0 #total_shipping.h2_ship_fuel_consumption
    #calculating the connection delay for every searoute in total_shipping
    total_shipping["connection_delay"] = '{\"type\": \"duration\", \"data\": \"' + (total_shipping["length_km"]/ship_speed).astype(str) + 'h\"}' #km/kmh - connection delay in hours

    #drop duplicates
    total_shipping  = total_shipping.drop_duplicates()
    con_line        = con_line.drop_duplicates()

    #add Regions to total_shipping according to the Regions column in con_line
    total_shipping["region_org"] = total_shipping["origin"].map(con_line.set_index(("com_name"))["Regions"])
    total_shipping["region_dest"] = total_shipping["destination"].map(con_line.set_index(("com_name"))["Regions"])

    #drop rows where region_org and region_dest are the same
    total_shipping = total_shipping.drop(total_shipping[total_shipping["region_org"] == total_shipping["region_dest"]].index)
    total_shipping = total_shipping.reset_index()
    total_shipping = total_shipping.drop(columns=["index"])

    print("Successfully parameterized searoutes" + "\n")

    ############### Terminals parameterize ###############

    terminals = terminals.rename(columns={"longitude":"x", "latitude":"y"})
    terminals["y"] = terminals["y"]*(-1)
    terminals = terminals.merge(con_line[['terminal_name','length']], on='terminal_name', how='left').drop_duplicates().reset_index(drop=True)
    terminals["balance_type"] = "balance_type_node"

    print("Succesfully transferred terminal information" + "\n")
############### Packing the dataframes and parameters for export ###############
# %%
#processing of the prepared dataframes to allow for easier readability in the ESM framework Spine
#1-Dimensional Importer Mappings
#h2_nodes
h2_nodes_concat_bal_ty    = pd.DataFrame({"Object_class_names":"node", "Object names 1":new_nodes.h2_node, "Parameter names":"balance_type", "Alternative names":new_nodes.alternative, "Parameter values":new_nodes.balance_type})
h2_nodes_concat_y    = pd.DataFrame({"Object_class_names":"node", "Object names 1":new_nodes.h2_node, "Parameter names":"x", "Alternative names":new_nodes.alternative, "Parameter values":new_nodes.y})
h2_nodes_concat_x    = pd.DataFrame({"Object_class_names":"node", "Object names 1":new_nodes.h2_node, "Parameter names":"y", "Alternative names":new_nodes.alternative, "Parameter values":new_nodes.x})
h2_nodes_slack_pen    = pd.DataFrame({"Object_class_names":"node", "Object names 1":new_nodes.h2_node, "Parameter names":"node_slack_penalty", "Alternative names":new_nodes.alternative, "Parameter values":node_slack_pen})
h2_nodes_concat_1D = pd.concat([h2_nodes_concat_bal_ty, h2_nodes_concat_y, h2_nodes_concat_x, h2_nodes_slack_pen], ignore_index=True)

#h2_terminals
if q == 0:
    h2_terminals_concat_bal_ty    = pd.DataFrame({"Object_class_names":"node", "Object names 1":terminals.name, "Parameter names":"balance_type", "Alternative names":terminals.alternative, "Parameter values":"balance_type_node"})
    h2_terminals_concat_y    = pd.DataFrame({"Object_class_names":"node", "Object names 1":terminals.name, "Parameter names":"y", "Alternative names":terminals.alternative, "Parameter values":terminals.y})
    h2_terminals_concat_x    = pd.DataFrame({"Object_class_names":"node", "Object names 1":terminals.name, "Parameter names":"x", "Alternative names":terminals.alternative, "Parameter values":terminals.x})
    h2_terminals_concat_1D = pd.concat([h2_terminals_concat_bal_ty, h2_terminals_concat_y, h2_terminals_concat_x], ignore_index=True)

#h2_pipelines
h2_pipelines_concat_cand_con    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":h2_pipelines.name, "Parameter names":"candidate_connections", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.candidate_connections})
h2_pipelines_concat_con_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":h2_pipelines.name, "Parameter names":"connection_type", "Alternative names":h2_pipelines.alternative, "Parameter values":"connection_type_normal"})
h2_pipelines_concat_inv_cost    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":h2_pipelines.name, "Parameter names":"connection_investment_cost", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_investment_cost})
h2_pipelines_concat_inv_lifetime    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":h2_pipelines.name, "Parameter names":"connection_investment_lifetime", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_investment_lifetime_js})
h2_pipelines_concat_inv_var_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":h2_pipelines.name, "Parameter names":"connection_investment_variable_type", "Alternative names":h2_pipelines.alternative, "Parameter values":"variable_type_continuous"})
h2_pipelines_concat_1D = pd.concat([h2_pipelines_concat_cand_con, h2_pipelines_concat_con_type, h2_pipelines_concat_inv_cost, h2_pipelines_concat_inv_lifetime, h2_pipelines_concat_inv_var_type], ignore_index=True)
# %%
#h2_terminal connections
if q == 0:
    h2_terminal_con_concat_cand_con    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":con_line.name, "Parameter names":"candidate_connections", "Alternative names":con_line.alternative, "Parameter values":con_line.candidate_connections})
    h2_terminal_con_concat_con_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":con_line.name, "Parameter names":"connection_type", "Alternative names":con_line.alternative, "Parameter values":"connection_type_normal"})
    h2_terminal_con_concat_inv_cost    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":con_line.name, "Parameter names":"connection_investment_cost", "Alternative names":con_line.alternative, "Parameter values":con_line.connection_investment_cost_origin})
    h2_terminal_con_concat_inv_lifetime    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":con_line.name, "Parameter names":"connection_investment_lifetime", "Alternative names":con_line.alternative, "Parameter values":default_connection_investment_lifetime_js})
    h2_terminal_con_concat_inv_var_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":con_line.name, "Parameter names":"connection_investment_variable_type", "Alternative names":con_line.alternative, "Parameter values":"variable_type_continuous"})
    h2_terminal_con_concat_1D = pd.concat([h2_terminal_con_concat_cand_con, h2_terminal_con_concat_con_type, h2_terminal_con_concat_inv_cost, h2_terminal_con_concat_inv_lifetime, h2_terminal_con_concat_inv_var_type], ignore_index=True)

#h2_ship connections
if q == 0:
    h2_ships_concat_cand_con    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":total_shipping.name, "Parameter names":"candidate_connections", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.candidate_connections})
    h2_ships_concat_con_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":total_shipping.name, "Parameter names":"connection_type", "Alternative names":total_shipping.alternative, "Parameter values":"connection_type_normal"})
    h2_ships_concat_inv_cost    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":total_shipping.name, "Parameter names":"connection_investment_cost", "Alternative names":total_shipping.alternative, "Parameter values": total_shipping.connection_investment_cost})
    h2_ships_concat_inv_lifetime    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":total_shipping.name, "Parameter names":"connection_investment_lifetime", "Alternative names":total_shipping.alternative, "Parameter values":default_connection_investment_lifetime_js})
    h2_ships_concat_inv_var_type    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":total_shipping.name, "Parameter names":"connection_investment_variable_type", "Alternative names":total_shipping.alternative, "Parameter values": "variable_type_continuous"})
    #h2_ships_concat_con_delay    = pd.DataFrame({"Object_class_names":"connection", "Object names 1":df_sr.name, "Parameter names":"connection_delay", "Alternative names":"Base", "Parameter values": df_sr.connection_delay})   #connection delay is not included yet due to shortened timescope in testing
    h2_ships_concat_1D = pd.concat([h2_ships_concat_cand_con, h2_ships_concat_con_type, h2_ships_concat_inv_cost, h2_ships_concat_inv_lifetime, h2_ships_concat_inv_var_type], ignore_index=True)

if q == 0:
    h2_connections_concat_1D = pd.concat([h2_nodes_concat_1D, h2_terminals_concat_1D, h2_pipelines_concat_1D, h2_terminal_con_concat_1D, h2_ships_concat_1D], ignore_index=True) #this dataframe will be exported to the ESM framework
else: h2_connections_concat_1D = pd.concat([h2_nodes_concat_1D], ignore_index=True) #this dataframe will be exported to the ESM framework

#2-Dimensional Importer Mappings
#h2_pipelines
h2_pipelines_concat_con_cap_f1    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node1, "Parameter names":"connection_capacity", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
h2_pipelines_concat_con_cap_f2    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node2, "Parameter names":"connection_capacity", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
h2_pipelines_concat_con_cap_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node1, "Parameter names":"connection_capacity", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
h2_pipelines_concat_con_cap_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node2, "Parameter names":"connection_capacity", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
h2_pipelines_concat_con_flow_cost_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node1, "Parameter names":"connection_flow_cost", "Alternative names":h2_pipelines.alternative, "Parameter values":connection_flow_cost*2})
h2_pipelines_concat_con_flow_cost_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node2, "Parameter names":"connection_flow_cost", "Alternative names":h2_pipelines.alternative, "Parameter values":connection_flow_cost*2})
h2_pipelines_concat_2D = pd.concat([h2_pipelines_concat_con_cap_f1, h2_pipelines_concat_con_cap_f2, h2_pipelines_concat_con_cap_t1, h2_pipelines_concat_con_cap_t2, h2_pipelines_concat_con_flow_cost_t1, h2_pipelines_concat_con_flow_cost_t2], ignore_index=True)

#h2_terminal connections
if q == 0:
    h2_terminal_con_concat_con_cap_f1    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node1, "Parameter names":"connection_capacity", "Alternative names":con_line.alternative, "Parameter values":con_line.connection_capacity})
    h2_terminal_con_concat_con_cap_f2    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node2, "Parameter names":"connection_capacity", "Alternative names":con_line.alternative, "Parameter values":con_line.connection_capacity})
    h2_terminal_con_concat_con_cap_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node1, "Parameter names":"connection_capacity", "Alternative names":con_line.alternative, "Parameter values":con_line.connection_capacity})
    h2_terminal_con_concat_con_cap_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node2, "Parameter names":"connection_capacity", "Alternative names":con_line.alternative, "Parameter values":con_line.connection_capacity})
    h2_terminal_con_concat_con_flow_cost_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node1, "Parameter names":"connection_flow_cost", "Alternative names":con_line.alternative, "Parameter values":connection_flow_cost*2})
    h2_terminal_con_concat_con_flow_cost_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":con_line.name, "Object names 2":con_line.node2, "Parameter names":"connection_flow_cost", "Alternative names":con_line.alternative, "Parameter values":connection_flow_cost*2})
    h2_terminal_con_concat_2D = pd.concat([h2_terminal_con_concat_con_cap_f1, h2_terminal_con_concat_con_cap_f2, h2_terminal_con_concat_con_cap_t1, h2_terminal_con_concat_con_cap_t2, h2_terminal_con_concat_con_flow_cost_t1, h2_terminal_con_concat_con_flow_cost_t2], ignore_index=True)

#h2_ship connections
if q == 0:
    h2_ships_concat_con_cap_f1    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.origin, "Parameter names":"connection_capacity", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    h2_ships_concat_con_cap_f2    = pd.DataFrame({"Relationship class names":"connection__from_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.destination, "Parameter names":"connection_capacity", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    h2_ships_concat_con_cap_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.origin, "Parameter names":"connection_capacity", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    h2_ships_concat_con_cap_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.destination, "Parameter names":"connection_capacity", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    h2_ships_concat_con_flow_cost_t1    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.origin, "Parameter names":"connection_flow_cost", "Alternative names":total_shipping.alternative, "Parameter values":connection_flow_cost})
    h2_ships_concat_con_flow_cost_t2    = pd.DataFrame({"Relationship class names":"connection__to_node", "Object_class_names":"connection", "Object class names 1":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.destination, "Parameter names":"connection_flow_cost", "Alternative names":total_shipping.alternative, "Parameter values":connection_flow_cost})
    h2_ships_concat_2D = pd.concat([h2_ships_concat_con_cap_f1, h2_ships_concat_con_cap_f2, h2_ships_concat_con_cap_t1, h2_ships_concat_con_cap_t2, h2_ships_concat_con_flow_cost_t1, h2_ships_concat_con_flow_cost_t2], ignore_index=True)

if q == 0:
    h2_connections_concat_2D = pd.concat([h2_pipelines_concat_2D, h2_terminal_con_concat_2D, h2_ships_concat_2D], ignore_index=True) #this dataframe will be exported to the ESM framework
else: h2_connections_concat_2D = pd.concat([h2_pipelines_concat_2D], ignore_index=True) #this dataframe will be exported to the ESM framework

#3-Dimensional Importer Mappings
#h2_pipelines
h2_pipelines_concat_fix_ratio_io1    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.fix_ratio_out_in_connection_flow})
h2_pipelines_concat_fix_ratio_io2    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":h2_pipelines.name, "Object names 2":h2_pipelines.h2_node2, "Object names 3":h2_pipelines.h2_node1, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.fix_ratio_out_in_connection_flow})
h2_pipelines_concat_3D = pd.concat([h2_pipelines_concat_fix_ratio_io1, h2_pipelines_concat_fix_ratio_io2], ignore_index=True)

#h2_terminal connections
if q == 0:
    h2_terminal_con_concat_fix_ratio_io1    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":con_line.name, "Object names 2":con_line.node1, "Object names 3":con_line.node2, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":con_line.alternative, "Parameter values":con_line.fix_ratio_out_in_connection_flow})
    h2_terminal_con_concat_fix_ratio_io2    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":con_line.name, "Object names 2":con_line.node2, "Object names 3":con_line.node1, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":con_line.alternative, "Parameter values":con_line.fix_ratio_out_in_connection_flow})
    h2_terminal_con_concat_3D = pd.concat([h2_terminal_con_concat_fix_ratio_io1, h2_terminal_con_concat_fix_ratio_io2], ignore_index=True)

#h2_ship connections
if q == 0:
    h2_ships_concat_fix_ratio_io1    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.fix_ratio_out_in_connection_flow})
    h2_ships_concat_fix_ratio_io2    = pd.DataFrame({"Relationship class names":"connection__node__node", "Object_class_names":"connection", "Object class names 1":"node", "Object class names 2":"node", "Object names 1":total_shipping.name, "Object names 2":total_shipping.destination, "Object names 3":total_shipping.origin, "Parameter names":"fix_ratio_out_in_connection_flow", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.fix_ratio_out_in_connection_flow})
    h2_ships_concat_3D = pd.concat([h2_ships_concat_fix_ratio_io1, h2_ships_concat_fix_ratio_io2], ignore_index=True)

if q == 0:
    h2_connections_concat_3D = pd.concat([h2_pipelines_concat_3D, h2_terminal_con_concat_3D, h2_ships_concat_3D], ignore_index=True) #this dataframe will be exported to the ESM framework
else: h2_connections_concat_3D = pd.concat([h2_pipelines_concat_3D], ignore_index=True) #this dataframe will be exported to the ESM framework

print("Succesfully packaged the 3D dataframes" + "\n")
########################### convert 2 BB ###########################
# %%
print("Start preparing BB datasets" + "\n")
##################################
terminals_og = terminals.copy()
con_line_og = con_line.copy()
# %%
# terminals = terminals_og
# con_line = con_line_og
## rework for shipping update
## moving regasification, liquefaction and cracker, haber-bosch to distinct units instead of aggregated to pipeline-import-export-transformation-transportation connection
# terminals prep
# terminals['commodity']          = terminals['commodity'].str.replace('h2','h2liq')
terminals['name']               = terminals['terminal_name'] + '|' + terminals['commodity']
terminals['name']               = terminals['name'].str.replace('terminal_','Terminal_')
terminals['terminal_name']      = terminals['terminal_name'].str.replace('terminal_','Terminal_')
terminals['con_terminal_name']  = 'ConTerminal|' + terminals['Regions'] + '|' + terminals['terminal_name'] + '|h2'

terminals.loc[terminals['commodity'] == 'h2liq','unit_name_trans']   = 'Liquefaction|'   + terminals[terminals['commodity'] == 'h2liq']['Regions']    + '|' + terminals[terminals['commodity'] == 'h2liq']['terminal_name']
terminals.loc[terminals['commodity'] == 'h2liq','unit_name_retrans'] = 'Regasification|' + terminals[terminals['commodity'] == 'h2liq']['Regions']    + '|' + terminals[terminals['commodity'] == 'h2liq']['terminal_name']
terminals.loc[terminals['commodity'] == 'nh3','unit_name_trans']    = 'HaberBosch|'     + terminals[terminals['commodity'] == 'nh3']['Regions']     + '|' + terminals[terminals['commodity'] == 'nh3']['terminal_name']
terminals.loc[terminals['commodity'] == 'nh3','unit_name_retrans']  = 'Cracker|'        + terminals[terminals['commodity'] == 'nh3']['Regions']     + '|' + terminals[terminals['commodity'] == 'nh3']['terminal_name']
# con_line prep

if q == 0:
    # con_line['commodity']           = con_line['commodity'].str.replace('h2','h2_l')
    con_line['name']                = con_line['terminal_name'] + '|' + con_line['commodity']
    con_line['name']                = con_line['name'].str.replace('terminal_','Terminal_')
    con_line['terminal_name']       = con_line['terminal_name'].str.replace('terminal_','Terminal_')
    con_line['con_terminal_name']   = 'ConTerminal|'+ con_line['Regions'] + '|' + con_line['terminal_name'] + '|h2'
    # reduction from 56 entries for direct connection from country node to h2l terminal and nh3 terminal to 28 entries for connection from country node to h2(g) terminal
    con_line                        = con_line[['terminal_name','Regions','alternative','WACC_pipeline_regional','WACC_conline_local','terminal_connection_invest','reg_fac','terminal_connection_eff','connection_investment_lifetime','geometry','length','node1','node2','connection_capacity','connection_flow_cost','fix_ratio_out_in_connection_flow_origin','fix_ratio_out_in_connection_flow_destination','fix_ratio_out_in_connection_flow', 'connection_investment_cost_origin_BB','annuity_factor_origin','connection_investment_cost_origin','connection_investment_cost_destination_BB','annuity_factor_destination', 'connection_investment_cost_destination','connection_investment_cost_BB', 'annuity_factor', 'candidate_connections','con_terminal_name','connection_fom_cost']].drop_duplicates().reset_index(drop=True)    #newly added fom costs added but can not be used on connections in BB (only for units) (based only on pipelines, not liquefaction or regasification!)

    #total_shipping.drop(['duration_hours','geometry','connection_type','latitude','longitude','alternative','ship_lifetime','connection_investment_lifetime','connection_investment_variable_type','candidate_connections','connection_delay','region_org','region_dest','connection_capacity','ship_fuel_consumption','connection_flow_cost','name'],axis=1)
    # total_shipping['commodity']         = total_shipping['commodity'].str.replace('h2','h2_l')
    total_shipping['origin']            = 'Terminal_' + total_shipping['origin']        .str.split('_', expand=True)[2] + '|' + total_shipping['commodity']
    total_shipping['destination']       = 'Terminal_' + total_shipping['destination']   .str.split('_', expand=True)[2] + '|' + total_shipping['commodity']
# %% ## pipeline loss calculation
# %%
from math import log
# configurable parameters for logarithmic pipeline loss function, fitted for average pipeline loss of about 2.3%
pipeline_loss_fixMin    = 0.5       # percent
pipeline_loss_log       = 100       # log base
# concat all pipelines and con_lines if q == 0, otherwise only pipelines
if q == 0:
    loss_calc = pd.concat([
        con_line[['length','node1','node2']].assign(**{'pipelineOrConline':'conline'}),
        h2_pipelines[['length','h2_node1','h2_node2']].rename(columns={'h2_node1':'node1','h2_node2':'node2'}).assign(**{'pipelineOrConline':'pipeline'})
    ], ignore_index=True)
else:
    loss_calc = h2_pipelines[['length','h2_node1','h2_node2']].rename(columns={'h2_node1':'node1','h2_node2':'node2'}).assign(**{'pipelineOrConline':'pipeline'})
loss_calc['log_loss'] = (1/100) * (pipeline_loss_fixMin +                                       # fix loss
                         loss_calc['length'].apply(lambda x: log(x)/log(pipeline_loss_log)) *   # length based logarithmic loss
                         (loss_calc['length'] / loss_calc['length'].mean()))                    # weighted by average
loss_calc['fix_ratio_out_in_log'] = 1 - loss_calc['log_loss']

if q == 0:
    con_line        = con_line      .merge(loss_calc[['length','fix_ratio_out_in_log']].drop_duplicates())

h2_pipelines    = h2_pipelines  .merge(loss_calc[['length','fix_ratio_out_in_log']].drop_duplicates())
##
# %%
#Intialization of objects
bb_grids_concat = pd.DataFrame({"Object_class_names":"grid", "Object names 1":['h2','derivatives']})
bb_nodes_concat = pd.DataFrame({"Object_class_names":"node", "Object names 1":new_nodes.h2_node})
if q == 0:
    bb_terminals_concat = pd.DataFrame({"Object_class_names":"node", "Object names 1":pd.concat([terminals.name, pd.Series(terminals['con_terminal_name'].unique())],ignore_index=True)})
    bb_units_concat     = pd.DataFrame({'Object_class_names':'unit', 'Object names 1':pd.concat([terminals['unit_name_trans'], terminals['unit_name_retrans']], ignore_index=True)})

if q == 0:
    bb_0D_concat = pd.concat([bb_grids_concat, bb_nodes_concat, bb_terminals_concat, bb_units_concat], ignore_index=True)
else: bb_0D_concat = pd.concat([bb_grids_concat, bb_nodes_concat], ignore_index=True)
## to do ## gucken ob hier noch unit spezifische Parameter fehlen... vgl. powerplants skript ## bisher waren hier noch gar keine units drin daher vermutlich schon :) ## bspw. unit availability usw
#Defining 2D connections grid_node
#h2_pipelines
bb_grid_node_concat_bal_ty = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":"h2", "Object names 2":new_nodes.h2_node, "Parameter names":"nodeBalance", "Alternative names":"Base", "Parameter values": new_nodes.balance_type.apply(lambda x: 0 if x == "balance_type_none" else 1)}) #h2 is fixed for now - may be later replaced by new_nodes.commodity

## 20250502 introduce capacityMargin for improved resiliency in (full year) schedule runs
bb_dim_2_capacityMargin_h2 = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1": "h2", "Object names 2":new_nodes["h2_node"], "Parameter names":'capacityMargin', "Alternative names":"Base", "Parameter values": capacityMargin_h2})

bb_2D_grid_node_concat = pd.concat([bb_grid_node_concat_bal_ty, bb_dim_2_capacityMargin_h2], ignore_index=True)

#h2_terminal connections
if q == 0:
    bb_grid_terminal_concat_bal_ty = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":'derivatives', "Object names 2":terminals.name, "Parameter names":"nodeBalance", "Alternative names":"Base", "Parameter values":1}) #there is no need to have terminals as energy sources
    bb_grid_con_terminal_concat_bal_ty = pd.DataFrame({"Relationship class names":"grid__node", "Object class names 1":"grid", "Object class names 2":"node", "Object names 1":'h2', "Object names 2":pd.Series(terminals['con_terminal_name'].unique()), "Parameter names":"nodeBalance", "Alternative names":"Base", "Parameter values":1})
    bb_2D_grid_terminal_concat = pd.concat([bb_grid_terminal_concat_bal_ty, bb_grid_con_terminal_concat_bal_ty], ignore_index=True)

if q == 0:
    bb_2D_concat = pd.concat([bb_2D_grid_node_concat, bb_2D_grid_terminal_concat], ignore_index=True)
else: bb_2D_concat = pd.concat([bb_2D_grid_node_concat], ignore_index=True)

#Defining 3D connections grid_node_node
#h2_pipelines
bb_gnn_pipelines_transferCap_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"transferCap", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
bb_gnn_pipelines_transferCapBidirectional_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"transferCapBidirectional", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_capacity})
bb_gnn_pipelines_transferLoss_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"transferLoss", "Alternative names":h2_pipelines.alternative, "Parameter values":1 - h2_pipelines.fix_ratio_out_in_log})
bb_gnn_pipelines_transferCapInvLimit_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"transferCapInvLimit", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.candidate_connections})
bb_gnn_pipelines_unitSize_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"unitSize", "Alternative names":h2_pipelines.alternative, "Parameter values":1}) #meant as 1MW
bb_gnn_pipelines_invCost_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"invCost", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_investment_cost_BB}) #€/MW ## to do ## fomCosts could be included by using h2_pipelines.connection_investment_cost_BB + (h2_pipelines.connection_fom_cost / h2_pipelines.annuity_factor) ~about 15-50% cost increase seems a bit high though... probably best to just not include this
bb_gnn_pipelines_annuityFactor_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1": "grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"annuityFactor", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.annuity_factor})
bb_gnn_pipelines_variableTransCost_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"variableTransCost", "Alternative names":h2_pipelines.alternative, "Parameter values":h2_pipelines.connection_flow_cost})
bb_gnn_pipelines_availability_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":h2_pipelines.commodity, "Object names 2":h2_pipelines.h2_node1, "Object names 3":h2_pipelines.h2_node2, "Parameter names":"availability", "Alternative names":h2_pipelines.alternative, "Parameter values":1})

#h2_terminal connections
if q == 0:
    bb_gnn_con_lines_transferCap_concat = pd.DataFrame({
        "Relationship class names":"grid__node__node", 
        "Object class names 1":"grid", 
        "Object class names 2":"node", 
        "Object class names 3":"node", 
        "Object names 1":'h2', 
        "Object names 2":con_line['con_terminal_name'], 
        "Object names 3":con_line.Regions + '_h2', 
        "Parameter names":"transferCap", 
        "Alternative names":'Base',         # or "Alternative names":con_line.alternative,
        "Parameter values":con_line.connection_capacity})
    bb_gnn_con_lines_transferCapBidirectional_concat = bb_gnn_con_lines_transferCap_concat  .assign(**{'Parameter names':'transferCapBidrectional'})
    bb_gnn_con_lines_transferLoss_concat = bb_gnn_con_lines_transferCap_concat              .assign(**{'Parameter names':'transferLoss',
                                                                                                       'Parameter values':1 - con_line.fix_ratio_out_in_log})
    bb_gnn_con_lines_transferCapInvLimit_concat = bb_gnn_con_lines_transferCap_concat       .assign(**{'Parameter names':'transferCapInvLimit',
                                                                                                       'Parameter values':con_line.candidate_connections})
    bb_gnn_con_lines_unitSize_concat = bb_gnn_con_lines_transferCap_concat                  .assign(**{"Parameter names":"unitSize", 
                                                                                                       "Parameter values":1}) #meant as 1MW
    bb_gnn_con_lines_invCost_concat = bb_gnn_con_lines_transferCap_concat                   .assign(**{"Parameter names":"invCost", 
                                                                                                       "Parameter values":con_line.connection_investment_cost_BB}) #EUR/MW
    bb_gnn_con_lines_annuityFactor_concat = bb_gnn_con_lines_transferCap_concat             .assign(**{"Parameter names":"annuityFactor", 
                                                                                                       "Parameter values":con_line.annuity_factor})
    bb_gnn_con_lines_variableTransCost_concat = bb_gnn_con_lines_transferCap_concat         .assign(**{"Parameter names":"variableTransCost", 
                                                                                                       "Parameter values":con_line.connection_flow_cost})
    bb_gnn_con_lines_availability_concat = bb_gnn_con_lines_transferCap_concat              .assign(**{"Parameter names":"availability", 
                                                                                                       "Parameter values":1})
# %%   
#h2_ship connections
if q == 0:
    bb_gnn_ships_transferCap_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"transferCap", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    bb_gnn_ships_transferCapBidirectional_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"transferCapBidirectional", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_capacity})
    bb_gnn_ships_transferLoss_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"transferLoss", "Alternative names":total_shipping.alternative, "Parameter values": 1 - total_shipping.fix_ratio_out_in_connection_flow})
    bb_gnn_ships_transferCapInvLimit_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"transferCapInvLimit", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.candidate_connections})
    bb_gnn_ships_unitSize_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"unitSize", "Alternative names":total_shipping.alternative, "Parameter values":1}) #meant as 1MW
    bb_gnn_ships_invCost_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"invCost", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_investment_cost_BB}) #€/MW
    bb_gnn_ships_annuityFactor_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"annuityFactor", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.annuity_factor})
    bb_gnn_ships_variableTransCost_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"variableTransCost", "Alternative names":total_shipping.alternative, "Parameter values":total_shipping.connection_flow_cost})
    bb_gnn_ships_availability_concat = pd.DataFrame({"Relationship class names":"grid__node__node", "Object class names 1":"grid", "Object class names 2":"node", "Object class names 3":"node", "Object names 1":'derivatives', "Object names 2":total_shipping.origin, "Object names 3":total_shipping.destination, "Parameter names":"availability", "Alternative names":total_shipping.alternative, "Parameter values":1})

    bb_gnn_conlines_complete_concat = pd.concat([           #conlines
        bb_gnn_con_lines_transferCap_concat,
        bb_gnn_con_lines_transferLoss_concat, 
        bb_gnn_con_lines_transferCapInvLimit_concat, 
        bb_gnn_con_lines_unitSize_concat,           
        bb_gnn_con_lines_invCost_concat,            
        bb_gnn_con_lines_annuityFactor_concat,      
        # bb_gnn_con_lines_variableTransCost_concat,        #no need for placeholder variableTransCost
        bb_gnn_con_lines_availability_concat
        ], ignore_index=True)
    bb_gnn_ships_complete_concat = pd.concat([              #ships
        bb_gnn_ships_transferCap_concat,
        bb_gnn_ships_transferLoss_concat, 
        bb_gnn_ships_transferCapInvLimit_concat, 
        bb_gnn_ships_unitSize_concat, 
        bb_gnn_ships_invCost_concat, 
        bb_gnn_ships_annuityFactor_concat,          
        # bb_gnn_ships_variableTransCost_concat,            #no need for placeholder variableTransCost
        bb_gnn_ships_availability_concat
        ], ignore_index=True)

if q == 0:
    bb_3D_concat = pd.concat([
        bb_gnn_pipelines_transferCap_concat,        ## pipelines from h2_node_a to h2_node_b and h2_node_b to h2_node_a
        bb_gnn_pipelines_transferLoss_concat, 
        bb_gnn_pipelines_transferCapInvLimit_concat, 
        bb_gnn_pipelines_unitSize_concat, 
        bb_gnn_pipelines_invCost_concat, 
        bb_gnn_pipelines_annuityFactor_concat,      
        # bb_gnn_pipelines_variableTransCost_concat,  #no need for placeholder variableTransCost
        bb_gnn_pipelines_availability_concat,       
        bb_gnn_conlines_complete_concat,            ## conlines from terminal to h2_node
        bb_gnn_conlines_complete_concat.assign(**{'Object names 2':bb_gnn_conlines_complete_concat['Object names 3'], 'Object names 3':bb_gnn_conlines_complete_concat['Object names 2']}), #conlines from h2_node to terminal
        bb_gnn_ships_complete_concat,               ## ships from terminal_a to terminal_b
        bb_gnn_ships_complete_concat.assign(**{'Object names 2':bb_gnn_ships_complete_concat['Object names 3'], 'Object names 3':bb_gnn_ships_complete_concat['Object names 2']})   #ships from terminal_b to terminal_a
        ], ignore_index=True)
else: bb_3D_concat = pd.concat([bb_gnn_pipelines_transferCap_concat, bb_gnn_pipelines_transferLoss_concat, bb_gnn_pipelines_transferCapInvLimit_concat, bb_gnn_pipelines_unitSize_concat, bb_gnn_pipelines_invCost_concat, bb_gnn_pipelines_annuityFactor_concat, bb_gnn_pipelines_variableTransCost_concat, bb_gnn_pipelines_availability_concat], ignore_index=True) # this has to be updated to be able to transport in both directions as well
# %% ## if we wanna go back to bidirectional
#combine Object names 2 and 3 to a single string in alphabetical order
# bb_3D_concat['sorter'] = bb_3D_concat[['Object names 2', 'Object names 3']].apply(lambda x: '_'.join(sorted(x)), axis=1)
#drop duplicates where the same connection is defined in both directions
# bb_3D_concat = bb_3D_concat.drop_duplicates(subset=['sorter', 'Object names 1', 'Relationship class names', 'Object class names 1', 'Object class names 2', 'Object class names 3', 'Parameter names', 'Alternative names'], keep='first').drop(columns=['sorter'])
print("Succesfully packaged the BB datasets" + "\n")

# generate new units for transformation and retransformation, connecting ConTerminals and Terminals
bb_dim_1_maxUnitCount   = pd.DataFrame({'Object_class_names':'unit',
                                        'Object names 1':pd.concat([terminals['unit_name_trans'], terminals['unit_name_retrans']], ignore_index=True),
                                        'Parameter names':'maxUnitCount',
                                        'Alternative names':'Base',
                                        'Parameter values':'inf'})
bb_dim_1_eff00          = bb_dim_1_maxUnitCount.assign(**{'Parameter names':'eff00',    # while Liquefaction and HaberBosch (transf) use their substance / material efficiency only Regasification and Cracker use substance * energetic efficency, implying that Hydrogen is used for energy in the retransformation process while electricity / external energy is used in the transformation process (unitConstraintNode + multiple Inputs for transformation cf. sector coupling Electrolyzer)
                                                          'Parameter values':pd.concat([terminals['transf_efficiency_substantial'], terminals['retransf_efficiency_substantial'] * terminals['retransf_efficiency_energetic']], ignore_index=True)})
bb_dim_1_availability   = bb_dim_1_maxUnitCount.assign(**{'Parameter names':'availability',
                                                          'Parameter values':1})
bb_dim_1_map_utAvailabilityLimits = pd.DataFrame({'Object class names':'unit',
                                                  'Object names':pd.concat([terminals['unit_name_trans'], terminals['unit_name_retrans']], ignore_index=True),
                                                  'Parameter names':'becomeAvailable',
                                                  'Alternative names':'Base',
                                                  'Parameter indexes':'t000001',
                                                  'Parameter values':1})
bb_1D_concat = pd.concat([bb_dim_1_maxUnitCount, 
                          bb_dim_1_eff00, 
                          bb_dim_1_availability], ignore_index=True)
bb_1Dmap_concat = pd.concat([bb_dim_1_map_utAvailabilityLimits], ignore_index=True)

##### introduce unittype
unittype                = pd.DataFrame({"unit": terminals["unit_name_trans"].drop_duplicates()})
unittype = pd.concat([unittype,
    pd.DataFrame({"unit": terminals["unit_name_retrans"].drop_duplicates()})
], ignore_index=True).drop_duplicates().reset_index(drop=True).dropna()
unittype["technology"] = unittype["unit"].str.split('|', expand=True)[0]
bb_dim2_unitunittype = pd.DataFrame({"Relationship class names": "unit__unittype", 
                                     "Object class names 1": "unit",
                                     "Object class names 2": "unittype",
                                     "Object names 1": unittype["unit"],
                                     "Object names 2": unittype["technology"]})

bb_2D_concat = pd.concat([bb_2D_concat, bb_dim2_unitunittype], ignore_index=True)

bb_dim_3_effLevelGroupUnit = pd.DataFrame({'Relationship class names':'effLevel__effSelector__unit',
                                           'Object class names 1':'effLevel',
                                           'Object class names 2':'effSelector',
                                           'Object class names 3':'unit',
                                           'Object names 1':['level1','level2','level3']*len(pd.concat([terminals['unit_name_trans'], terminals['unit_name_retrans']], ignore_index=True)),
                                           'Object names 2':'directOff',
                                           'Object names 3':(pd.concat([pd.concat([terminals['unit_name_trans'], terminals['unit_name_retrans']], ignore_index=True)]*3,ignore_index=True)).sort_values(ignore_index=True)})
bb_dim_3_unitConstraintNode = pd.DataFrame({
    'Relationship class names':'unit__constraint__node',
    'Object class names 1':'unit',
    'Object class names 2':'constraint',
    'Object class names 3':'node',
    'Object names 1':pd.concat([terminals['unit_name_trans']] * 2, ignore_index=True),  # only transformation (export) gets double inputs
    'Object names 2':'eq1',
    'Object names 3':pd.concat([terminals['con_terminal_name'], terminals['Regions'] + '_el'], ignore_index=True),
    'Parameter names':'coefficient',
    'Alternative names':'Base',
    'Parameter values':pd.concat([1 - terminals['transf_efficiency_energetic'], pd.Series(len(terminals['transf_efficiency_energetic']) * [-1])], ignore_index=True)})
bb_3D_concat = pd.concat([bb_3D_concat, 
                          bb_dim_3_effLevelGroupUnit, 
                          bb_dim_3_unitConstraintNode], ignore_index=True)

bb_dim_4_unitSize_import_o = pd.DataFrame({'Relationship class names':'grid__node__unit__io',      # output of Regasification for h2l and Crackerunit for nh3 to h2 grid (Import from Terminal to ConTerminal)
                                        'Object class names 1':'grid',
                                        'Object class names 2':'node',
                                        'Object class names 3':'unit',
                                        'Object class names 4':'io',
                                        'Object names 1':'h2',
                                        'Object names 2':terminals['con_terminal_name'],
                                        'Object names 3':terminals['unit_name_retrans'],
                                        'Object names 4':'output',
                                        'Parameter names':'unitSize',
                                        'Alternative names':'Base',
                                        'Parameter values':1})
bb_dim_4_unitSize_export_o = bb_dim_4_unitSize_import_o.assign(**{                                  # output of Liquefaction for h2l and Haberboschunit for nh3 to derivatives grid (Export from ConTerminal to Terminal)
    'Object names 1':'derivatives',
    'Object names 2':terminals['name'],
    'Object names 3':terminals['unit_name_trans']})
bb_dim_4_capacity_import_o = bb_dim_4_unitSize_import_o.assign(**{
    'Parameter names':'capacity',
    'Parameter values':eps})
bb_dim_4_capacity_export_o = bb_dim_4_unitSize_export_o.assign(**{
    'Parameter names':'capacity',
    'Parameter values':eps})
bb_dim_4_annuityFactor_import_o = bb_dim_4_unitSize_import_o.assign(**{
    'Parameter names':'annuityFactor',
    'Parameter values':terminals["WACC_conversion"] / (1 - (1 + terminals["WACC_conversion"]) ** (-1 * terminals.retransf_lifetime))})
bb_dim_4_annuityFactor_export_o = bb_dim_4_unitSize_export_o.assign(**{
    'Parameter names':'annuityFactor',
    'Parameter values':terminals["WACC_conversion"] / (1 - (1 + terminals["WACC_conversion"]) ** (-1 * terminals.transf_lifetime))})
bb_dim_4_invCosts_import_o = bb_dim_4_unitSize_import_o.assign(**{
    'Parameter names':'invCosts',
    'Parameter values':terminals['regasification_cost']})
bb_dim_4_invCosts_export_o = bb_dim_4_unitSize_export_o.assign(**{
    'Parameter names':'invCosts',
    'Parameter values':terminals['liquefaction_cost']})
bb_dim_4_fomCosts_import_o = bb_dim_4_unitSize_import_o.assign(**{
    'Parameter names':'fomCosts',
    'Parameter values':terminals['regasification_fom_rel'] * (1 + terminals['reg_fac'])/2 * terminals['regasification_cost']})
bb_dim_4_fomCosts_export_o = bb_dim_4_unitSize_export_o.assign(**{
    'Parameter names':'fomCosts',
    'Parameter values':terminals['liquefaction_fom_rel'] * (1 + terminals['reg_fac'])/2 * terminals['liquefaction_cost']})
bb_dim_4_conversionCoeff_import_o = bb_dim_4_unitSize_import_o.assign(**{
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_export_o = bb_dim_4_unitSize_export_o.assign(**{
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_import_i = bb_dim_4_unitSize_import_o.assign(**{
    'Object names 1':'derivatives',
    'Object names 2':terminals['name'],
    'Object names 4':'input',
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_export_i1 = bb_dim_4_unitSize_export_o.assign(**{      #conversionCoeff for two different inputs because Liquefaction and HaberBosch take considerable amounts of external energy (unlike Regasification and Ammoniacracker)
    'Object names 1':'h2',
    'Object names 2':terminals['con_terminal_name'],
    'Object names 4':'input',
    'Parameter names':'conversionCoeff',
    'Parameter values':1})
bb_dim_4_conversionCoeff_export_i2 = bb_dim_4_unitSize_export_o.assign(**{
    'Object names 1':'elec',
    'Object names 2':terminals['Regions'] + '_el',
    'Object names 4':'input',
    'Parameter names':'conversionCoeff',
    'Parameter values':eps})    # electricity is not converted to derivatives but only used for the transformation process (bb_dim_3_unitConstraintNode)
bb_4D_concat = pd.concat([bb_dim_4_unitSize_import_o, 
                          bb_dim_4_unitSize_export_o, 
                          bb_dim_4_capacity_import_o, 
                          bb_dim_4_capacity_export_o, 
                          bb_dim_4_annuityFactor_import_o, 
                          bb_dim_4_annuityFactor_export_o, 
                          bb_dim_4_invCosts_import_o, 
                          bb_dim_4_invCosts_export_o, 
                          bb_dim_4_fomCosts_import_o, 
                          bb_dim_4_fomCosts_export_o, 
                          bb_dim_4_conversionCoeff_import_o, 
                          bb_dim_4_conversionCoeff_export_o, 
                          bb_dim_4_conversionCoeff_import_i, 
                          bb_dim_4_conversionCoeff_export_i1, 
                          bb_dim_4_conversionCoeff_export_i2], ignore_index=True)
bb_4D_concat = bb_4D_concat.drop_duplicates(subset=['Relationship class names', 'Object class names 1', 'Object class names 2', 'Object class names 3', 'Object class names 4', 'Object names 1', 'Object names 2', 'Object names 3', 'Object names 4', 'Parameter names', 'Alternative names'], keep='first').reset_index(drop=True)

############### Export the finished transport system ###############

#### Adding the constraints for the Delegated Act for RFNBOs ####

if RFNBO_option == "Vanilla":
    print("Base model without any RFNBO modifications" + "\n")

if RFNBO_option == "No_reg":
    ### None ###
    alt_rfnbo = "No_reg"
    print("No regulation for RFNBOs applied" + "\n")
    #reassining electricity nodes to the renewable electricity nodes in 2D

if RFNBO_option == "Island_Grids":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Island Grids ###
    alt_rfnbo = "Island_Grid"

#The Defossilized Grid option conducts a pre-solve without any hydrogen demand to determine the CO2 intensity of the system to then asses, whether the RFNBO production may use the grid electricity.
if RFNBO_option == "Defossilized_Grid_prerun":
    print("Applying " + str(RFNBO_option) + " regulation for RFNBOs" + "\n")
    ### Defossilized Grids ###
    alt_rfnbo = "Defossilized_Grid_prerun"
    reg_ex_hydrogen = 'h2|Terminal|'
    bb_0D_concat = bb_0D_concat[~bb_0D_concat['Object names 1'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_1D_concat = bb_1D_concat[~bb_1D_concat['Object names 1'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_1Dmap_concat = bb_1Dmap_concat[~bb_1Dmap_concat['Object names'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_2D_concat = bb_2D_concat[~bb_2D_concat['Object names 2'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_3D_concat = bb_3D_concat[~bb_3D_concat['Object names 1'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_3D_concat = bb_3D_concat[~bb_3D_concat['Object names 2'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_3D_concat = bb_3D_concat[~bb_3D_concat['Object names 3'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_4D_concat = bb_4D_concat[~bb_4D_concat['Object names 2'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)
    bb_4D_concat = bb_4D_concat[~bb_4D_concat['Object names 3'].str.contains(reg_ex_hydrogen)].reset_index(drop=True)

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

#create a excel writer object and export the preprocessed transport model data
with pd.ExcelWriter(os.path.join(outputfile)) as writer:

   h2_connections_concat_1D.to_excel(writer, sheet_name="h2_connections_1D", index=False)
   h2_connections_concat_2D.to_excel(writer, sheet_name="h2_connections_2D", index=False)
   h2_connections_concat_3D.to_excel(writer, sheet_name="h2_connections_3D", index=False)

print("Succesfully exported Spines " + str(outputfile) + "\n")

with pd.ExcelWriter(os.path.join(outputfile_BB)) as writer:

   bb_0D_concat.to_excel(writer, sheet_name="h2_connections_0D", index=False)
   bb_1D_concat.to_excel(writer, sheet_name="h2_connections_1D", index=False)
   bb_1Dmap_concat.to_excel(writer, sheet_name="h2_connections_1Dmap", index=False)
   bb_2D_concat.to_excel(writer, sheet_name="h2_connections_2D", index=False)
   bb_3D_concat.to_excel(writer, sheet_name="h2_connections_3D", index=False)
   bb_4D_concat.to_excel(writer, sheet_name="h2_connections_4D", index=False)

print("Succesfully exported Backbones " + str(outputfile_BB) + "\n")

print("Draw new weighted WACCs from weighted_WACC_final.csv from KT WACC update and replace WACCs in TEMP files for visualization script" + str(outputfile_BB) + "\n")

############### Export dataframes for visualisation tool ###############
# Draw new weighted WACCs from weighted_WACC_final.csv from KT WACC update and replace WACCs in TEMP files for visualization script
new_nodes = (
    new_nodes
    .drop('WACC',axis=1)
    .merge(
        pd.read_csv(os.path.join(path_WACC_Update), sep=';')
            [['Regions','Cost of Capital']]
            .groupby('Regions')
            .agg({'Cost of Capital':'mean'})
            .reset_index(),
        on='Regions', 
        how='left')
    .rename(columns={'Cost of Capital':'WACC'})
)
new_nodes = (
    new_nodes
    .merge(
        pd.read_csv(os.path.join(path_WACC_Update), sep=';')
            [['name','Regions','Cost of Capital']]
            .groupby(['name','Regions'])
            .agg({'Cost of Capital':'mean'})    # industrial average WACC of countries
            .reset_index()
            .groupby('Regions')
            .agg({'Cost of Capital':'std'})     # standart deviation of countries for average WACC of regions
            .reset_index()
            .rename(columns={'Cost of Capital':'regional_WACC_StDev'}),
        on='Regions',
        how='left')
)

if q == 0:
    # add the shipping lines in form of multiple points instead of one long linestring for further processing in Backbone 
    shipping_coords = total_shipping[['origin','destination','geometry']].copy()
    shipping_coords['origin___destination'] = shipping_coords['origin'] + '___' + shipping_coords['destination']
    shipping_coords = (shipping_coords.set_index('origin___destination').geometry
            .apply(lambda x: list(x.coords))
            .explode(ignore_index=False)
            .apply(pd.Series)
            .reset_index()
            .rename(columns={0: 'y_Latitude', 1: 'x_Longitude'})).merge(shipping_coords[['origin___destination', 'origin','destination']], on='origin___destination', how='left')
    index_inside_shipping_routes = pd.Series()
    for number_of_points in shipping_coords.groupby('origin___destination').count().reset_index()['origin']:
        index_inside_shipping_routes = pd.concat([index_inside_shipping_routes, pd.Series(range(number_of_points))], ignore_index=True, axis=0)
    shipping_coords = pd.concat([shipping_coords, index_inside_shipping_routes], ignore_index=True, axis=1)

############### Export dataframes for visualisation tool ###############

with pd.ExcelWriter(os.path.join(visualisation_output, "transport_visualisation.xlsx")) as writer:

    new_nodes.to_excel(writer, sheet_name="nodes", index=False)
    terminals.to_excel(writer, sheet_name="terminals", index=False)
    h2_pipelines.to_excel(writer, sheet_name="pipelines", index=False)
    if q == 0:
        con_line.to_excel(writer, sheet_name="terminal_connections", index=False)
        total_shipping.astype(str).to_excel(writer, sheet_name="shipping", index=False)

print("Succesfully exported data for visualisation tool to " + str(os.path.join(visualisation_output)) + "\n")

STOP = time.perf_counter()
print('Total execution time of script',round((STOP-START), 1), 's')
#%%