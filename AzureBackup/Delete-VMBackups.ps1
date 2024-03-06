
<#

Description:
- Given a resource group name, recovery services vault name, and a virtual machine name prefix, will disable backup protection and 
    delete all recovery points for the matching virtual machines
Usage:
- 1.  Modify the resource group name ($rgName), recovery services vault name ($vaultName), and the vm name prefix ($vmNamePrefix) to match your
    environment
  2.  Update the value of the $forceDelete variable to $true when you are actually ready to delete the backup items from the vault
    (default value is $false. Use this to validate that the backup items found are the correct ones. Once validated, run the code using
    a value of $true to perform the deletion
- NOTE: This does not handle vaults that are using Immutability, Multi User Authorization, or other additional data protection
    tools or methods

Disclaimer:
- Code is presented as-is with no guarantee that it will work in your environment. Please test thoroughly in your own test 
    environment prior to using in a production environment. Not responsible for any unexpected effects or unintended
     deleted production data. This is only an example of what happened to work in my test environment.

#>
 

## Variables

 
$rgName = "<resource group name>" 
$vaultName = "<recovery services vault name>"
$vmNamePrefix = "<prefix of vm names to be deleted>"

# change this value to true to actually stop the VM protection and delete recovery points
$forceDelete = $false

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $rgName -Name $vaultName -ErrorAction SilentlyContinue

if ($vault -eq $null)
{
    Write-Host "Unable to find Recovery Services Vault $vaultName in Resource Group $rgName" -ForegroundColor Yellow
}
else
{
    # Disable soft delete for the Azure Backup Recovery Services vault
    Write-Host "Disabling soft delete on vault $vaultName" -ForegroundColor Green
    Set-AzRecoveryServicesVaultProperty -Vault $vault.ID -SoftDeleteFeatureState Disable
    Write-Host "Soft delete disabled for vault $vaultName" -ForegroundColor Green

    # get list of all backup machines whose names start with the
    Write-Host "Finding backed up virtual machines with name starting with '$vmNamePrefix'" -ForegroundColor Green
    Set-AzRecoveryServicesVaultContext -Vault $vault

    $items = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM `
                        -VaultId $vault.ID | Where-Object {($_.Name.Split(';')[3]).ToUpper().StartsWith($vmNamePrefix.ToUpper())}

    Write-Host "Found" $items.Count.ToString() "virtual machine backups to be deleted" -ForegroundColor Green

    # loop through list of found virtual machines
    foreach ($vmBackup in $items)
    {
        $vmName = $vmBackup.Name.Split(';')[3]
        Write-Host "Deleting backup configuration and recovery points for $vmName" -ForegroundColor Green

        if ($forceDelete)
        {
            Disable-AzRecoveryServicesBackupProtection -Item $vmBackup -VaultId $vault.ID -RemoveRecoveryPoints -Force -Verbose
            Write-Host "### DELETED - Backup configuration and recovery points deleted for virtual machine $vmName" -ForegroundColor Green
            Write-Host ""
        }
        else
        {
            Write-Host "NOTE: Backup configuration and recovery points WERE NOT DELETED for virtual machine $vmName. Force Delete variable set to false." -ForegroundColor Yellow
        }
    }

    # Re-enable soft delete on the Recovery Sercices Vault
    Write-Host "Re-enabling soft delete on vault $vaultName" -ForegroundColor Green
    Set-AzRecoveryServicesVaultProperty -Vault $vault.ID -SoftDeleteFeatureState Enable
    Write-Host "Soft delete re-enabled for vault $vaultName" -ForegroundColor Green
}
