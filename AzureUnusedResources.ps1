Param(	
    [Parameter(Mandatory=$true)]
    [ValidateSet('All','Storage','Network')]	
    [String[]] $Scope,
    [Switch] $AskLogin,
    [Switch] $ServicePrincipal,
    [String] $SPUser,
    [String] $SPKey,
    [String] $Tenant,
    [Switch] $VerboseMode,
    [Parameter(Mandatory=$true)]    
    [ValidateSet('AnalysisOnly','Production')]
    [string[]] $Mode
)

# SCRIPT FUNCTIONS

function Log($message){
    if($VerboseMode)
    {
        Write-Host $message -ForegroundColor Cyan
    }
}

function GetVMProperties(){
    # Get All VM Information
    $AllVMS = Get-AzureRmVM
    Log([String]::Format("Found {0} VMs", $AllVMS.Count))

    foreach ($vm in $AllVMS) {
        Log ([String]::Format("Getting information from VM {0}", $vm.Name))
        $VMNames.Add($vm.name) > $null

        # Boot Diagnostics
        $diagnostics = $vm.DiagnosticsProfile.BootDiagnostics
        If ($diagnostics.Enabled -eq $true){
			$VMDiagnosticsStorageUrl.add($diagnostics.StorageUri) > $null
			Log ([String]::Format("Diagnostics enabled for VM {0}. Diagnostics location is {1}", $vm.Name, $diagnostics.StorageUri))
        }
        
        # Disks
        $storage = $VM.StorageProfile
        $OSDisk = $storage.OsDisk
        Log ([String]::Format("OS Disk is located in {0}", $OSDisk.vhd.uri))
        $DiskURIList.Add($OSDisk.vhd.uri) > $null
        
        #$DataDisks = New-Object System.Collections.ArrayList
        $DataDisks = $storage.DataDisks
        foreach ($disk in $DataDisks) {
            Log ([String]::Format("Data Disk is located in {0}", $disk.vhd.uri))
            $DiskURIList.Add($disk.vhd.uri) > $null
        }

        # Network Interface Cards
        $NICS = $vm.NetworkProfile.NetworkInterfaces
        foreach ($nic in $NICS) {
            $VMNICList.Add($nic.Id) > $null

            $nicName = $nic.Id.substring($nic.id.LastIndexOf('/') + 1)
            Log ([String]::Format("VM {0} contains NIC {1}", $vm.Name, $nicName))
        }
    }
}

# VARIABLE DECLARATION

$SelectedSubscriptions = New-Object System.Collections.ArrayList
$VMNames = New-Object System.Collections.ArrayList
$VMDiagnosticsStorageUrl = New-Object System.Collections.ArrayList
$DiskURIList = New-Object System.Collections.ArrayList
$VMNICList = New-Object System.Collections.ArrayList


if($Mode -eq 'Production'){
    Write-Warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    Write-Warning "!     YOU ARE RUNNING IN PRODUCTION MODE. ANY RESOURCE DETECTED AS NOT BEING USED WILL BE DELETED.     !"
    Write-Warning "!                IT IS A BEST PRACTICE TO RUN THIS SCRIPT IN ANALYSIS MODE FIRST                       !"
    Write-Warning "!                                                                                                      !"
    Write-Warning "!                                     PRESS [Y] TO CONTINUE                                            !"
    Write-Warning "!                                  ...ANY OTHER KEY TO EXIT                                            !"
    Write-Warning "!                                                                                                      !"
    Write-Warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    $key = Read-Host
    if ($key.toUpper() -ne "Y" -or $key -ne "y") {
        Write-Host "SAFE QUIT" -ForegroundColor Green
        exit
    }    
}

# MAIN SCRIPT
if($AskLogin){
    # Ask User for credentials
    Add-AzureRmAccount
}
elseif($ServicePrincipal){
    # Validate Service Principal credentials
    if($SPUser -eq $null -or $SPUser -eq "" `
        -or $SPKey -eq $null -or $SPKey -eq "" `
        -or $Tenant -eq $null -or $Tenant -eq ""){        
        Write-Error "Service Principal Credentials are missing. When specifying '-ServicePrincipal' switch, UserName, Key and Tenant properties are mandatory. Exiting now."
        exit
    }
    else{  # Authenticate with Service Principal Credentials
        $pass = ConvertTo-SecureString $SPKey -AsPlainText -Force
        $creds = New-Object -TypeName PSCredential -ArgumentList $SPUser, $pass
        
        Add-AzureRmAccount -Credential $creds -ServicePrincipal -TenantId $Tenant        
    }
}

# Get List of Subscriptions
$AllSubscriptions = Get-AzureRmSubscription
Log([String]::Format("Found {0} Subscriptions", $AllSubscriptions.Count))

# If user is present ask which subscriptions should the script analyze
if(!$ServicePrincipal){
    foreach ($subscription in $AllSubscriptions){
        $title = $subscription.Name
        $message = "Do you want the subscription " + $title + " to be analyzed?"
	    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
		"Adds the subscription to the script."
	    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
		"Skips the subscription from scanning."
	    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    

        switch ($result){
            0 {
                $SelectedSubscriptions.Add($subscription) > $null
                Log ([String]::Format("Subscription {0} has been added", $subscription.Name))
            } 
            1 {
                Log ([String]::Format("Subscription {0} will be skipped", $subscription.Name))
            }
        }
    }
}
else{
    $SelectedSubscriptions = $AllSubscriptions
}

foreach ($subscription in $SelectedSubscriptions){
    Log ([String]::Format("Analyzing {0}", $subscription.Name))

    Select-AzureRmSubscription -SubscriptionId $subscription.Id
    Log ("Subscription Selected.")

    Log ("Starting VM Properties Collection")    
    $VMProperties=GetVMProperties
    Log ("Collected VM Properties")    

    Switch ($Scope) {
        All { 

        }
        Storage { 

        }
        Network { 
            
        }
        Default { 
            
        }
    }

    if($Mode -eq 'Production'){
        # Removes resources identified as unused

    }
    elseif ($Mode -eq 'AnalysisOnly'){
        # Prints resources identified as unused to the screen
        
    }
}



