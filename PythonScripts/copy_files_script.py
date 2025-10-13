#%%
import sys 
import shutil
from datetime import datetime
import os

print("Initiate paths" + "\n")
# Define the base directory and output destination
try:
    #use if run in spine-toolbox
    base_output_path       = sys.argv[1]
    outputfile_dir         = r"..\backbone-master\input"
except: 
    #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    base_output_path = os.path.join(os.getcwd(), ".spinetoolbox", "items", "export_to_bb", "output")
    outputfile_dir = os.path.join(os.getcwd(), "backbone-master", "input")

#%%
print("Change the working directory to your local script's directory" + "\n")
#hard coding the output directory temporarily because for some unidentifiable reason it is not working with the above code
base_output_path = r"C:\Users\oliver\Documents\RUB\01_Projekte\StEAM\Programme\StEAM_model\.spinetoolbox\items\export_to_bb\output"
outputfile_dir = r"C:\Users\oliver\Documents\RUB\01_Projekte\StEAM\Programme\StEAM_model\backbone-master\input"

print("Ensure path exists" + "\n")
# Ensure the base output path exists
if not os.path.exists(base_output_path):
    raise FileNotFoundError(f"The directory {base_output_path} does not exist.")

# Find the most recently modified subfolder in the base output directory
subfolders = [os.path.join(base_output_path, d) for d in os.listdir(base_output_path) if os.path.isdir(os.path.join(base_output_path, d))]
most_recent_subfolder = max(subfolders, key=os.path.getmtime)

# Get all .gdx files in the most recent subfolder
gdx_files = [f for f in os.listdir(most_recent_subfolder) if f.endswith('.gdx')]

# Copy each .gdx file to the output directory
for gdx_file in gdx_files:
    gdx_file_path = os.path.join(most_recent_subfolder, gdx_file)
    shutil.copy(gdx_file_path, outputfile_dir)

print(f"Copied {len(gdx_files)} .gdx files to {outputfile_dir}.")

# find inputData_2030 in the output directory
inputfile = os.path.join(outputfile_dir, "inputData_2030.gdx")
# rename inputData_2030.gdx to inputData.gdx
outputfile = os.path.join(outputfile_dir, "inputData.gdx")
if os.path.exists(inputfile):
    # Check if the file already exists
    if os.path.exists(outputfile):
        # If it exists, remove it
        os.remove(outputfile)
    
    # Rename the file
    os.rename(inputfile, outputfile)

print(f"Renaming {inputfile} to {outputfile}.")
print("Finished copying files" + "\n")
#%%