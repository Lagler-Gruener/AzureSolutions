 ## Azure mapping tool

**The history about the tool.**
One of my customer have a huge Azure environment and over the time he had problems with the permission assigment.
The main permission assigment is On-Premis based on active directory group assigment.

The customer also use an agile resource group strategy in the cloud, which  means, he defines different resource groups for the applications and also for the different layers.

In the past he assign automatically predefined permission (synced) groups.
That fact had an inpact of an huge amount of Active Directory groups.

Ove the time, the customer also had many external partners which are invited over B2B. In fact, the customer aren't able to use the synced active directory groups because those groups doesn't support "cloud only" users membership.

**The requironments**
The basic requironments to that tool was a way to use one group assigment for the On-Prem and the B2B assigment to Azure resource groups/resources/AAD permissions.
Over the time we add the following functionalities too:

* Add permission to resource groups with an specified tag
* Implement a web portal for the administration tasks
* A central logging and throubleshooting area
* The possibility to create new resource groups ove the administration portal
* A decoupeld architecture
* A full syncronisation between On-Prem and Azure AD

----------------------------------------------------------------------------

**The requironments are motivation enough for me**
I'm starting with the architecture design. I'm focusing on PaaS and SaaS services only and at the end the architecture looks like the following:

![Alt text](Architecture/Images/Architecture.png?raw=true "Architecture")

----------------------------------------------------------------------------
###Mappingtool Workflows
The application have different workflows to archive the whole functionality.

**Process "add/change resourcegroup tag**
The main process for the application is the "Add/Change resourcegroup tag". 
The process includes the following steps:

    -When a new Tag element was add to the specified Tag Key an event subscription execute and Azure Automation webhook
    -That webhook get the configured mappings from the central configuration and check if the changes are valide
    -If the change is valide, the script add the configuration to the configuration table and execute a seperate runbook to create the Azure AD group
    -That script creates the Azure AD group and update the configuration too (with the group id and state)
    -The initial script also add the create information into a message queue
    -The On-Prem Logic App task will execute the create ad group script to get all information from the message queue and creates the active directory group
    -When everything was successfull the script update the configuration (add the sid from the local group and change the state)

![Alt text](Architecture/Images/AddChangeTagProcess.png?raw=true "Add/Change rg tag")

----------------------------------------------------------------------------

**Process "add azure ad group**
The process to add an Azure AD group includes the following steps:

    -Monitor changes at the Azure Activity log and create an LogAnalytics alert if a new one was created
    -The action group executes an Azure Webhook runbook
    -The configuration will be add to the central table and to the message queue
    -The On-Prem Task will be executed by an Azure Logic App to create the active directory group

![Alt text](Architecture/Images/AddZAADGroupProcess.png?raw=true "Add azure ad group")

----------------------------------------------------------------------------

**Process "add active directory group**
The process to add an active directory group includes the following steps:

    -The monitor script will be executed every X minutes to check changes in the On-Prem configuration
    -If a new group was added the script add the information into a message queue and also update the configuration table
    -The Azure AD task which will be execute ba an Azure Logic App check the message queue and execute the runbook to create an Azure AD group
    -At the end the configuration will be updated (Azure AD group ID and state)

![Alt text](Architecture/Images/AddADGroupProcess.png?raw=true "Add azure ad group")

----------------------------------------------------------------------------

**Process "monitor active directory group**
The process to monitor active directory groups includes the following steps:

    -The monitoring runbook will be execute by an Azure Logic App every X minutes
    -That script compare the configuration from the setting "uSNChanged" (active directory attribute and configuration setting in table)
    -If the values doesn't compare the script add the current group configuration based on json to the message queue
    -When the task is done the same Logic App executes the cloud membership runbook to update the the group configuration (Add and remove synced users)
    -At the end the script updates the "uSNChanged" setting in the central configuration table
    -Each step will be logged into Azure Log Analytics and if there ocures any error, the information will be add to the issues table

![Alt text](Architecture/Images/MonitorADMebershipProcess.png?raw=true "Monitor ad group")

----------------------------------------------------------------------------

**Process "monitor azure ad group group**
The process to monitor azure ad groups includes the following steps:

##Feature request

----------------------------------------------------------------------------

**Process "resource group remove**
The process for resource group remove includes the following steps:

    -When a member removes an Azure AD resource group an Azure Event subscription executes and Azure Automation runbook by a webhook
    -That script get the following informations from the configuration table
        -Configured Azure AD groups
        -Configured Active Directory groups
    -Based on the Azure AD configuration the groups will be renamed (configuration setting)
    -The script also add the information about the group remove to an Azure message queue
    -After the Azure task is finished, the configuration will be archived (for restore task (future request))
    -An Azure Logic App will execute the remove runbook On-Prem to rename the Active directory group and move it into a preconfigured OU
    -All tasks will be logged into Azure Logic App

> [!IMPORTANT]
> Important, there is no delete process includet!

![Alt text](Architecture/Images/RemoveAzRGroupProcess.png?raw=true "Remove Azure RG")

----------------------------------------------------------------------------

#OPEN

**Process "Azure AD group remove**
The process for Azure AD group remove includes the following steps:

    -If an Azure AD group is removed based on the right naming schema, an Azure Log Analytics alert will be triggerd
    -The action group executes a webook based Azure runbook
    -This runbook 

![Alt text](Architecture/Images/MonitorADMebershipProcess.png?raw=true "Monitor ad group")


