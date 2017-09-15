Param(	
    [Parameter(Mandatory=$true)]
    [ValidateSet('All','Storage','Network')]	
    [String[]] $Scope,
    [Parameter(Mandatory=$true)]
    [ValidateSet('Handled','Prompt','ServicePrincipal')]
    [String[]] $AuthMode,
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

        if($OSDisk.vhd -ne $null){
            Log ([String]::Format("OS Disk is located in {0}", $OSDisk.vhd.uri))
            $DiskURIList.Add($OSDisk.vhd.uri) > $null
        }
        else{            
            Log ([String]::Format("OS Managed Disk id is {0}", $vm.StorageProfile.OsDisk.ManagedDisk.Id))
            $DiskURIList.Add($OSDisk.StorageProfile.OsDisk.ManagedDisk.Id)
        }

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


function CollectStorageAccounts(){

}

function CollectManagedDisks(){
    $ManagedDisks=Get-AzureRmDisk
    Log ([String]::Format("Found {0} Managed Disks", $ManagedDisks.Count))

    $diskCount = 0
    foreach($disk in $ManagedDisks){
        if($disk.OwnerId -eq $null){
            $diskCount++
            $ManagedDiskList.Add($disk.Id) > $null
        }
    }

    Log ([String]::Format("Added {0} Managed Disks to List", $diskCount))
}

function CollectPIPs(){
    $PublicIPs = Get-AzureRmPublicIpAddress
    Log ([String]::Format("Found {0} Public IP Addresses", $PublicIPs.Count))

    $pipCount = 0
    foreach ($pip in $PublicIPs){          
        if($pip.IpConfiguration -eq $null){
            $pipCount++
            $PIPList.Add($pip.Id) > $null
        }
        else{
            $pipConfigId = $pip.IpConfiguration.Id
            if ($pipConfigId.split("/")[7] -ne 'virtualNetworkGateways'){
                $nicId = $pipConfigId.Substring(0,$pipConfigId.IndexOf("/ipConfiguration"))
                if(!$VMNICList.Contains($nicId)){
                    $pipCount++
                    $PIPList.Add($pip.Id) > $null
                }
            }
        }        
    }

    Log ([String]::Format("Added {0} Public IP Addresses to List", $pipCount))
}

function CollectNICs(){
    $NICs=Get-AzureRmNetworkInterface
    Log ([String]::Format("Found {0} NICs", $NICs.Count))

    $nicCount = 0
    foreach($nic in $NICs){
       if($nic.VirtualMachine -eq $null){
           $nicCount++
           $NICList.Add($nic.Id) > $null
       }
    }

    Log ([String]::Format("Added {0} NICs to List", $nicCount))
}

function CollectNSGs(){

}

function CollectSubnets(){

}

function CollectVNETs(){

}

function Print($list){
    foreach($item in $list){
        Write-Output (Get-AzureRmResource -ResourceId $item).Name
    }

}

# VARIABLE DECLARATION

$SelectedSubscriptions = New-Object System.Collections.ArrayList
$VMNames = New-Object System.Collections.ArrayList
$VMDiagnosticsStorageUrl = New-Object System.Collections.ArrayList
$DiskURIList = New-Object System.Collections.ArrayList
$VMNICList = New-Object System.Collections.ArrayList
$ManagedDiskList = New-Object System.Collections.ArrayList
$PIPList = New-Object System.Collections.ArrayList
$NICList = New-Object System.Collections.ArrayList


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
if($AuthMode -eq "Prompt"){
    # Ask User for credentials
    Log ("Asking user for credentials")
    Add-AzureRmAccount
    Log ("Successfuly authenticated")
}
elseif($AuthMode -eq "ServicePrincipal"){
    # Validate Service Principal credentials
    if($SPUser -eq $null -or $SPUser -eq "" `
        -or $SPKey -eq $null -or $SPKey -eq "" `
        -or $Tenant -eq $null -or $Tenant -eq ""){        
        Log("Values missing for Service Principal")    
        Write-Error "Service Principal Credentials are missing. When specifying '-ServicePrincipal' switch, UserName, Key and Tenant properties are mandatory. Exiting now."        
        exit
    }
    else{  # Authenticate with Service Principal Credentials
        $pass = ConvertTo-SecureString $SPKey -AsPlainText -Force
        $creds = New-Object -TypeName PSCredential -ArgumentList $SPUser, $pass
        
        Log ([String]::Format("Authenticating with Service Principal",$SPUser))
        Add-AzureRmAccount -Credential $creds -ServicePrincipal -TenantId $Tenant        
        Log ("Successfuly authenticated")
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
    GetVMProperties
    Log ("Collected VM Properties")    

    Switch ($Scope) {
        All { 
            Log ("Collecting information on Storage Accounts")
            $StorageAccountsToProcess = CollectStorageAccounts

            Log ("Collecting information on Managed Disks")
            CollectManagedDisks

            Log ("Collecting information on Networking")
            CollectPIPs
            CollectNICs
            $NSGsToProcess = CollectNSGs
            $SubnetsToProcess = CollectSubnets
            $VNETsToProcess = CollectVNETs
        }
        Storage { 
            Log ("Collecting information on Storage Accounts")
            $StorageAccountsToProcess = CollectStorageAccounts

            Log ("Collecting information on Managed Disks")
            CollectManagedDisks
        }
        Network { 
            Log ("Collecting information on Networking")
            CollectPIPs
            CollectNICs
            $NSGsToProcess = CollectNSGs
            $SubnetsToProcess = CollectSubnets
            $VNETsToProcess = CollectVNETs
        }
        Default { 
            
        }
    }    
}


if($Mode -eq 'Production'){
    # Removes resources identified as unused





}
elseif ($Mode -eq 'AnalysisOnly'){
    # Prints resources identified as unused to the screen
    Write-Host "******************************************************************" -ForegroundColor Yellow
    Write-Host "*                       ANALYSIS SUMMARY                         *" -ForegroundColor Yellow
    Write-Host "******************************************************************" -ForegroundColor Yellow
    Write-Host "*   The following items have been identified as not being used   *" -ForegroundColor Yellow
    Write-Host "*   and they can be removed.                                     *" -ForegroundColor Yellow
    Write-Host "******************************************************************" -ForegroundColor Yellow
    
    Write-Host "MANAGED DISKS:" -ForegroundColor Yellow
    Print -list $ManagedDiskList

    Write-Host "PUBLIC IPS:" -ForegroundColor Yellow
    Print -list $PIPList

    Write-Host "NETWORK INTERFACES:" -ForegroundColor Yellow
    Print -list $NICList

}



