REM Check if Python 3.11 is installed

REM Replace "3.x" with the desired Python version (e.g., 3.8, 3.9, etc.)
set PythonVersion=3.9

REM Replace "myenv" with the desired name for the virtual environment
set EnvName=myenv

if exist %LocalAppData%\Programs\Python\Python39\python.exe (
  %LocalAppData%\Programs\Python\Python39\python -m venv %EnvName%

) else (
	  	echo Python 3.9 not found in user app folder.. searching fo install for all users
  if exist "%ProgramFiles%\Programs\Python39\python.exe" (
 		%ProgramFiles%\Programs\Python39\python -m venv %EnvName%
	) else (
			echo Python 3.11 is not installed. Installing Python 3.9...
		REM Download and install Python 3.11.0 in the current directory
		curl -o python_installer.exe https://www.python.org/ftp/python/3.9.0/python-3.9.0-amd64.exe
		python_installer.exe \silent InstallAllUsers=0  PrependPath=0 Include_test=0
		del python_installer.exe
		%LocalAppData%\Programs\Python\Python39\Python -m venv %EnvName%
	)
)


REM Activate the virtual environment
call myenv\Scripts\activate

REM Install required packages
pip install -r requirements.txt

REM Deactivate the virtual environment
deactivate

REM This will pause the Command Prompt
call cmd
