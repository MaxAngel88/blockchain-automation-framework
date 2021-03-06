@echo off
@setlocal enableextensions
@cd /d "%~dp0"


echo "		 ____          ______ 		"
echo "		|  _ \   /\   |  ____|		"
echo "		| |_) | /  \  | |__   		"
echo "		|  _ < / /\ \ |  __|  		"
echo "		| |_) / ____ \| |     		"
echo "		|____/_/    \_\_|     		"



REM Check for admin privilages
REM If not present, then exit
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Success: Administrative permissions confirmed.
) else (
    echo Failure: Current permissions inadequate. Press any key to exit the setup..
	pause
	exit
)
REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Check for virtualization
REM If not present, then exit
systeminfo|findstr /C:"Virtualization Enabled In Firmware:">Virtualization.txt
set /P CHECK_VIRTUALIZATION=<Virtualization.txt
del Virtualization.txt
set CHECK_VIRTUALIZATION=%CHECK_VIRTUALIZATION:*: =%
if %CHECK_VIRTUALIZATION%==No (
echo Virtualization is not enabled. Please enable virtualization and re-run the script. Exiting..
PAUSE
EXIT
)

REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Installing GIT binary
REM Check if the git is already present or not, if already present, then this step will be skipped
git --version
set GITVAR=%errorlevel%
if %GITVAR%==9009 (
echo Starting git download v2.26.0 64 bit
powershell -Command "Invoke-WebRequest https://github.com/git-for-windows/git/releases/download/v2.26.0.windows.1/Git-2.26.0-64-bit.exe -OutFile gitsetup.exe"
if %ERRORLEVEL%==1 (
echo Bad internet/url. Exiting...
PAUSE
EXIT
)
echo Git download successful
echo Installing git. Press 'Next' at each prompt so that it gets installed with default settings
START /WAIT gitsetup.exe
echo git successfully installed
) else (
echo git already installed
)
REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Configuring git username and useremail
echo Please create a github account and continue
PAUSE

set /p GIT_USERNAME=Enter git username: 
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git config user.name" > CHECK_USERNAME.txt
set /P CHECK_USERNAME=<CHECK_USERNAME.txt
if %CHECK_USERNAME% NEQ %GIT_USERNAME% ( 
echo Updating username
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git config --global user.name %GIT_USERNAME%"
)
del CHECK_USERNAME.txt

set /p GIT_USEREMAIL=Enter user email: 
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git config user.email" > CHECK_USEREMAIL.txt
set /P CHECK_USEREMAIL=<CHECK_USEREMAIL.txt
if %CHECK_USEREMAIL% NEQ %GIT_USEREMAIL% (
echo Updating useremail
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git config --global user.email %GIT_USEREMAIL%"
)
del CHECK_USEREMAIL.txt

echo Git configured successfully

echo Configuring git so that EOLs are not updated to Windows CRLF
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git config --global core.autocrlf false"

REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Setting up of forked repo on local machine and checkout to a given branch ( defaulted to local)
echo Please fork the blockchain-automation-framework repository from browser.
PAUSE

"C:\Program Files\Git\bin\sh.exe" --login -i -c 'ssh-keygen -q -N "" -f ~/.ssh/gitops'
"C:\Program Files\Git\bin\sh.exe" --login -i -c "eval $(ssh-agent)"

md project
chdir project
set /p REPO_URL=Enter your forked repo clone url (HTTPS url): 
git clone %REPO_URL%
set /p REPO_BRANCH=Enter branch(default is local): 
chdir blockchain-automation-framework
if NOT DEFINED REPO_BRANCH set "REPO_BRANCH=local"
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git checkout %REPO_BRANCH%"
if %ERRORLEVEL% == 1 (
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git checkout -b develop"
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git checkout -b %REPO_BRANCH% develop"
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git checkout %REPO_BRANCH%"
"C:\Program Files\Git\bin\sh.exe" --login -i -c "git push -u origin %REPO_BRANCH%"
)
chdir ../..

REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Setting up docker toolbox
REM Check if the docker toolbox is already present or not, if already present, then this step will be skipped
docker --version
set DOCKERVAR=%errorlevel%
if %DOCKERVAR%==9009 (
echo Downloading dockertoolbox
powershell -Command "Invoke-WebRequest https://github.com/docker/toolbox/releases/download/v19.03.1/DockerToolbox-19.03.1.exe -OutFile dockertoolbox.exe"
if %ERRORLEVEL%==1 (
echo Bad internet/url. Exiting...
PAUSE
EXIT
)
echo Installing docker toolbox
echo Installing docker toolbox. Press 'Next' at each prompt so that it gets installed with default settings
echo Do not uncheck the virtualbox installation option in the installer. This step ensures, virtualbox gets installed with docker toolbox
START /WAIT dockertoolbox.exe
echo Docker toolbox successfully installed
) else (
echo Docker Toolbox already installed
)
REM Uncomment the below line if you want to run the docker shell and intialize docker for the first time here itself.
REM "C:\Program Files\Git\bin\bash.exe" --login -i "C:\Program Files\Docker Toolbox\start.sh"

REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Setting up of Hashicorp Vault Server
REM Check if the Hashicorp Vault is already installed or not, if already present, then this step will be skipped
vault --version
set VAULTVAR=%errorlevel%
if %VAULTVAR%==9009 (
powershell -Command "Invoke-WebRequest https://releases.hashicorp.com/vault/1.3.4/vault_1.3.4_windows_amd64.zip -OutFile vault.zip"
if %ERRORLEVEL%==1 (
echo Bad internet/url. Exiting...
PAUSE
EXIT
)
powershell -Command "Expand-Archive -Force vault.zip .\project\bin"
)
echo Please enter the project\bin (absolute path) to environment variables (both system and environment variables) and continue
PAUSE

REM Killing explorer.exe to set the environment variables
REM taskkill /f /im explorer.exe && explorer.exe
(
echo ui = true
echo storage "file" {
echo  path    = "~/project/data"
echo }
echo listener "tcp" {
echo   address     = "0.0.0.0:8200"
echo   tls_disable = 1
echo }
) > config.hcl

start /min vault server -config=config.hcl
echo Vault is running in other cmd (minimized, do not close it, or the vault will stop)
echo Open browser at http:://localhost:8200, provide 1 and 1 in both fields and initialize
echo Click Download keys or copy the keys. Then click Continue to unseal.
echo Provide the unseal key first and then the root token to login.

set /p VAULT_TOKEN=Enter vault token: 
set /p VAULT_KEY=Enter vault key: 
set VAULT_ADDR=http://127.0.0.1:8200
set VAULT_TOKEN=%VAULT_TOKEN%
vault operator unseal %VAULT_KEY%
vault secrets enable -version=1 -path=secret kv

REM ############################################################################################################################################################
REM ############################################################################################################################################################

REM Setting up of minikube
REM Check if Minikube is already installed or not, if already present, then this step will be skipped
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version
set VIRTUALBOXVAR=%errorlevel%
minikube status
set MINIKUBEVAR=%errorlevel%
if %VIRTUALBOXVAR% NEQ 9009 if %VIRTUALBOXVAR% NEQ 3 (
  if %MINIKUBEVAR%==9009 (
    powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    choco install minikube -y
  )else (
   echo Minikube is already installed
  )
)else (
  echo Virtualbox is not installed. Press any key to exit the setup...
  pause
  exit
)

set /p RAMSIZE=Enter ram to be used by minikube(MB):  
set /p CPUCOUNT=Enter cpu cores to be used by minikube:  
minikube config set memory %RAMSIZE%
minikube config set cpus %CPUCOUNT%
minikube config set kubernetes-version v1.15.4
minikube start --vm-driver=virtualbox
minikube status

echo "		 ____          ______ 		"
echo "		|  _ \   /\   |  ____|		"
echo "		| |_) | /  \  | |__   		"
echo "		|  _ < / /\ \ |  __|  		"
echo "		| |_) / ____ \| |     		"
echo "		|____/_/    \_\_|     		"




PAUSE
