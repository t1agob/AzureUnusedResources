# Azure Unused Resources -  POWERSHELL
This repository is the home of a PowerShell script that will check any of your Microsoft Azure subscriptions for resources that are not being used anymore. The intent is to help you reduce costs by removing old resources that have been forgotten. 

This script can be run manually or in an automated way since it authentication using a Service Principal.

**WARNING:** THIS SCRIPT IS STILL UNDER DEVELOPMENT AND SOME FEATURES MAY STILL NOT BE WORKING. FEATURES NOT WORKING ARE LISTED BELOW

 - Production Mode
 - Storage Account Analysis

## Authentication with Microsot Azure
In order to use this script you need to be authenticated. You can handle it yourself or you can let the script authenticate you. For that you need to use the **_AuthMode_** parameter. Allowed values are:

- **Handled**

    This property states that authentication has already been handled by the user which means that the user already ran **_Add-AzureRmAccount_** cmdlet or similar. 
    
    _User will not be prompted for authentication._

- **Prompt**

    User will be requested to fill in username and password in order to authenticate. If user has Multi-factor authentication set up it will also be required to use it.

- **ServicePrincipal**

    By using a Service Principal the user will be allowed to run this script in an automated way without any user input.

    When using Service Principal authentication there are additional mandatory fields: 

     - **SPUser** Service Principal ID

     - **SPKey** Service Principal Key

     - **Tenant** Azure AD Tenant wher the Service Principal is registered

    To better understand how to setup a Service Principal please use Azure documentation [here](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal). 

    **IMPORTANT:** _The Service Principal created must have reader access to all subscriptions you intend to analyze. If you are planning to run in production mode the Service Principal needs to have contributor permissions._

## Working Scope
This script can analyze all resources or just a few. In order to work only on the resources the user wants, the scope needs to specified by using the **_Scope_** parameter. Allowed values are:

- **All**

    By specifying the this value the script will focus on **Storage and Network** resources when identifying resources that are not being used anymore.

- **Storage**

   By specifying the this value the script will focus only on **Storage** resources when identifying resources that are not being used anymore.

- **Network**

    By specifying the this value the script will focus only on **Network** resources when identifying resources that are not being used anymore.

## Working Mode
This script can run in 2 different modes depending on whether the user wants to get a list of resources that can be deleted or if the user wants to let the script delete every resource found not to be used. In order to specify what mode the script will be running the user needs to use the **_Mode_** parameter. Allowed values are:

- **AnalysisOnly**

    When running in **AnalysisOnly** mode the user will be presented with an Analysis Summary of all the resources that have been identified as not being used anymore. 

    After having this information the user will be able to manually delete the resources if he confirms that this information is accurate and the resource is really to be deleted.

- **Production**

    By running in **Production** mode the user will let the script delete every resource identified as not being used anymore. 

    **Warning**: Although the script has been tested multiple times in many different environments this automated process should be used carefully. The responsability of using the script in automated way is up to the user.

## Examples
##### Analyze only


```powershell
.\AzureUnusedResources -Scope All -AuthMode Prompt -Mode AnalysisOnly
```

##### Production mode


```powershell
.\AzureUnusedResources -Scope All -AuthMode Prompt -Mode Production
```

##### Verbose Mode


```powershell
.\AzureUnusedResources -Scope All -AuthMode Prompt -Mode AnalysisOnly -VerboseMode
```

##### Authenticating before running the script


```powershell
Add-AzureRmAccount

.\AzureUnusedResources -Scope All -AuthMode Prompt -Mode AnalysisOnly -VerboseMode
```

##### Authenticating with Service Principal


```powershell
.\AzureUnusedResources.ps1 -Scope All -AuthMode ServicePrincipal -SPUser "YOUR-SERVICE-PRINCIPAL-ID" -SPKey "YOUR-SERV
ICE-PRINCIPAL-KEY" -Tenant "YOUR-AZURE-AD-TENANT" -Mode AnalysisOnly
```