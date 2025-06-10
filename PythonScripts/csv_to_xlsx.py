import os
import sys
import pandas as pd
from openpyxl import Workbook
from openpyxl.utils.dataframe import dataframe_to_rows

print('Execute in Directory:')
print(os.getcwd())

# Set the output Excel file name
try:        #use if run in spine-toolbox
    output_excel_file   = "TEMP\\MainInput.xlsx"
    input_csv_files     = sys.argv[1]                                               #ganz egal welches CSV-File angegeben wird. Hauptsache der Ordner passt
except:     #use if run in Python environment
    if str(os.getcwd()).find('PythonScripts') > -1:
        os.chdir('..')
    output_excel_file   = "PythonScripts\\TEMP\\MainInput.xlsx"
    input_csv_files     = r".spinetoolbox\items\data_connection_main\model.csv"     #ganz egal welches CSV-File angegeben wird. Hauptsache der Ordner passt

# Set the directory path where CSV files are located
csv_directory =  os.path.dirname(input_csv_files)
xlsx_directory=  os.path.dirname(output_excel_file)

# Create a new workbook
workbook = Workbook()

# Loop through all files in the directory
for filename in os.listdir(csv_directory):
    if filename.endswith('.csv'):
        # Read the CSV file into a DataFrame
        csv_file = os.path.join(csv_directory, filename)
        df = pd.read_csv(csv_file,delimiter = ';')
        
        # Create a new sheet with the same name as the CSV file
        sheet_name = os.path.splitext(filename)[0]
        sheet = workbook.create_sheet(title=sheet_name)
        
        # Write the DataFrame to the sheet
        for row in dataframe_to_rows(df, index=False, header=True):
            sheet.append(row)

# Calculate modeling duration in hours
if (workbook['model_date']['C2'].value == 'model_start') & (workbook['model_date']['C3'].value == 'model_end'):
    m_start     = workbook['model_date']['E2'].value
    m_end       = workbook['model_date']['E3'].value
    steam_model_duration    = int((pd.to_datetime(m_end) -      pd.to_datetime(m_start))                .total_seconds()/3600)
    steam_model_start       = int((pd.to_datetime(m_start) -    pd.to_datetime('2015-01-01T00:00:00'))  .total_seconds()/3600) + 1
else:
    raise Exception("Can't calculate modeling dates for Backbone")

# Write timesteps for Backbone investInit.gms
workbook['model_date']['E5'] = steam_model_duration
workbook['model_date']['E6'] = steam_model_start

# Remove the default sheet created by openpyxl
workbook.remove(workbook['Sheet'])

# Save the workbook as an Excel file
workbook.save(output_excel_file)

print('Conversion complete. Excel file saved as', output_excel_file)