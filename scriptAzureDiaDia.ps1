Write-Host "### Scripts de Ferramentas Azure ###"
Write-Host "##Autor Matheus William - 2025"
$numeroAssinatura = 0
while (($numeroAssinatura -le 0) -or ($numeroAssinatura -gt 10)) {
    $numeroAssinatura = [int](Read-Host "Informe quantas assinaturas vao ser analisadas")
    if($numeroAssinatura -gt 10){
        Write-Host 'Sao permitidos a validacao de ate 10 assinaturas. Informa um novo valor!' -ForegroundColor Cyan
    }
}
$subscription = @()
for ($i = 0; $i -lt $numeroAssinatura; $i++) {
    $subscription += (Read-Host "Informe o ID da "($i + 1)"º da Assinatura")   
}
$continue = $true
#az login
##########Inicia_Funcoes##########
function BackupOff {
    write-host "===================================================================="
    write-host "1- Validar Backups de VMs"
    #VMs que não estão com Backup Habilitado
    $virtualMachines = Get-AzVM
    $vaults = Get-AzRecoveryServicesVault
    $vaultCount = $vaults.Count
    $index = 0
    $vmListNoBackup = @()
    $containers = @()
    $backupItems = @()
    $protectedVMs = @()
    $Exist = $false
    foreach ($vault in $vaults) {
        $index++
        $percentComplete = ($index / $vaultCount) * 100
        Write-Progress -Activity "Buscando Containers e Itens de Backup" -Status "Processando Vault $index de $vaultCount" -PercentComplete $percentComplete
        $containers += Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID
        foreach ($container in $containers) {
            $backupItems += Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -VaultId $vault.ID
            $protectedVMs += $backupItems.sourceResourceId
        }
    }
    Write-Progress -Activity "Concluído" -Completed
    $vmCount = $virtualMachines.Count
    $index = 0
    $percentComplete = 0
    foreach ($vm in $virtualMachines) {
        $index++
        $percentComplete = ($index / $vmCount) * 100
        Write-Progress -Activity "Comparando VMs com Itens do Vault de Backup" -Status "Processando VMs $index de $vmCount" -PercentComplete $percentComplete
        foreach ($protected in $protectedVMs) {
            if ($vm.Id -ieq $protected) {
                #Valida se deu Match
                $Exist = $true
                $vmList += $protected
                break
            }
        }
        if ($Exist -ine $true) {
            $vmListNoBackup += $vm
            $Exist = $false
        }
    }
    Write-Progress -Activity "Concluído" -Completed
    if ($vmListNoBackup.Count -ne 0) {
        write-host "===================================================================="
        Write-Host 'Lista de VMs sem backup configurado!'
        $vmListNoBackup | select Name, ResourceGroupName
        write-host "===================================================================="
    }
    else {
        write-host "===================================================================="
        Write-Host 'Todas VM com backup configuardo!'
        write-host "===================================================================="
    }
}
function SnapshotOver{
    write-host "===================================================================="
    write-host "2- Validar Snapshots com mais de 60 Dias"
    #Snapshot Com mais de 60 Dias.
    # Definir o número de dias para filtrar
    $daysThreshold = 60
    $cutoffDate = (Get-Date).AddDays(-$daysThreshold)

    # Obter todos os snapshots no Azure
    $snapshots = Get-AzSnapshot | Where-Object {
        $_.TimeCreated -lt $cutoffDate -and
        $_.Tags["Created By"] -ne "AzureBackup" -and
        $_.Name -notlike "AzureBackup*"
    }

    # Exibir os snapshots filtrados
    if ($snapshots) {
        write-host "===================================================================="
        Write-Host 'Lista de Snapshot com mais de '$daysThreshold' dias:'
        $snapshots | Select-Object Name, ResourceGroupName, TimeCreated | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        write-host "===================================================================="
        Write-Host "Nenhum snapshot com mais de $daysThreshold dias encontrado (excluindo backups do Azure)."
        write-host "===================================================================="
    }
}
function DiskNull {
    write-host "===================================================================="
    write-host "3- Validar Discos sem recurso associado"
    #Obter todos os discos que não estão anexados a nenhuma VM
    $discosOrfaos = Get-AzDisk | Where-Object { $_.ManagedBy -eq $null -and
        $_.Name -inotlike "*ASR*"
    }
    # Exibir os discos filtrados
    if ($discosOrfaos) {
        Write-Host 'Lista de Discos que sem associacao:'
        $discosOrfaos | Select-Object Name, ResourceGroupName, DiskSizeGB | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhum disco órfão encontrado."
        write-host "===================================================================="
    }
}
function PipNull {
    write-host "===================================================================="
    write-host "4- Validar IP Publico sem recurso associado"
    #Obter todos os IPs públicos que não estão alocados e que possuem SKU Standard
    $ipsNaoAlocados = Get-AzPublicIpAddress | Where-Object {
        $_.Sku.Name -eq "Standard" -and
        $_.IpConfiguration -eq $null
    }

    # Exibir os IPs filtrados
    if ($ipsNaoAlocados) {
        Write-Host 'Lista de PIP não estao associado a recursos:'
        $ipsNaoAlocados | Select-Object Name, ResourceGroupName, PublicIpAddress | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhum IP público não alocado com SKU Standard encontrado."
        write-host "===================================================================="
    }
}
function NicNull {
    write-host "===================================================================="
    write-host "5- Validar Interface de Rede sem recurso de VM associado"
    #Obter todas as interfaces de rede (NICs)
    $nicNaoAtribuidas = Get-AzNetworkInterface | Where-Object {
        # Filtrar NICs que não estão associadas a:
        $_.VirtualMachine -eq $null -and
        $_.PrivateEndpoint -eq $null -and
        $_.NetworkSecurityGroup -eq $null
    }

    # Exibir as interfaces filtradas
    if ($nicNaoAtribuidas) {
        Write-Host 'NICs que estão sem recurso associado:'
        $nicNaoAtribuidas | Select-Object Name, ResourceGroupName, Location, MacAddress, EnableAcceleratedNetworking | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhuma interface de rede sem vínculo foi encontrada."
        write-host "===================================================================="
    }
}
function NsgNull {
    write-host "===================================================================="
    write-host "6- Validar NSG sem recurso associado"
    #Obter todos os NSGs na assinatura
    $nsgsNaoAtribuidos = Get-AzNetworkSecurityGroup | Where-Object {
        # Filtrar NSGs que não estão associados a nenhuma Subnet ou NIC
    ($_.Subnets.Count -eq 0) -and ($_.NetworkInterfaces.Count -eq 0)
    }

    # Exibir os NSGs filtrados
    if ($nsgsNaoAtribuidos) {
        write-host 'Segue a lista de NSG sem associação:'
        $nsgsNaoAtribuidos | Select-Object Name, ResourceGroupName, Location | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhum NSG não atribuído encontrado."
        write-host "===================================================================="
    }
}
function SaPublic {
    write-host "===================================================================="
    write-host "7- Validar Storage Account com Acesso Publico nos containers"
    #Lista quais ST tem blobs acesso publico
    # Lista todos os Storage Accounts na Subscription    
    $storageAccounts = Get-AzStorageAccount
    $storageWithPublicContainers = @()  # Lista para armazenar Storage Accounts com containers públicos
    foreach ($storage in $storageAccounts) {
        $containers = Get-AzStorageContainer -Context $storage.Context
        $hasPublicContainer = $false

        foreach ($container in $containers) {
            if ($container.PublicAccess -ne "Off") {
                $hasPublicContainer = $true
                break  # Sai do loop assim que encontrar um container público
            }
        }

        if ($hasPublicContainer) {
            $storageWithPublicContainers += $storage
        }
    }
    # Exibe os Storage Accounts que possuem containers públicos
    if ($storageWithPublicContainers.Count -gt 0) {
        Write-Host "Os seguintes Storage Accounts possuem pelo menos um container com acesso anônimo:"
        $storageWithPublicContainers | select StorageAccountName, ResourceGroupName
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhum Storage Account com containers públicos foi encontrado."
        write-host "===================================================================="
    }
}
function SaSoftDeleteDisable {
    write-host "===================================================================="
    write-host "8- Validar Storage Account com Soft Delete desabilitado"
    #Coletar quais Blobs estão com SOFTDELETE desabilitado
    # Obter todas as contas de armazenamento na assinatura
    $storageAccounts = Get-AzStorageAccount | Where-Object {
        $_.ResourceGroupName -notlike "cloud-shell*" -and
        $_.ResourceGroupName -notlike "RG-Site-Recovery*" -and
        $_.ResourceGroupName -notlike "AzureBackupRG*" -and
        $_.ResourceGroupName -notlike "ResourceMoverRG*"
    }
    $st = @()
    # Iterar sobre cada conta de armazenamento
    foreach ($storageAccount in $storageAccounts) {
        # Obter as propriedades da conta de armazenamento
        $properties = $storageAccount.Context.StorageAccount 
        # Verificar se a exclusão reversível está habilitada
        if ($properties.BlobDeleteRetentionPolicy.Enabled -ne $true) {
            # Exibir informações da conta de armazenamento com exclusão reversível desabilitada
            $st += $storageAccount 
        }
    }
    if ($st.cout -ne 0) {
        Write-Host 'S.A. com Soft Delete desabilitado:'
        $st | select StorageAccountName, ResourceGroupName | Format-Table
        write-host "===================================================================="
    }
    else {
        Write-Host 'Não encontrado nenhum S.A. com Soft Delete desabilitado.'
        write-host "===================================================================="
    }
    
}
function PIP-Basic {
    write-host "===================================================================="
    write-host "9- Validar IP Publico com SKU Basic"
    # Obter todos os IPs públicos que possuem SKU Basic
    $ipsNaoAlocados = Get-AzPublicIpAddress | Where-Object {
        $_.Sku.Name -eq "Basic"
    }

    # Exibir os IPs filtrados
    if ($ipsNaoAlocados) {
        Write-Host 'IPs Publicos com SKU Basic:'
        $ipsNaoAlocados | Select-Object Name, ResourceGroupName | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Nenhum IP público não alocado com SKU Standard encontrado."
        write-host "===================================================================="
    }
}
function AcceleratedNetworking {
    write-host "===================================================================="
    write-host "10- Avaliar VMs que podem habilitar Accelerated Networking"
    # Obter todas as interfaces de rede (NICs) que não possuem Accelerated Networking ativo
    $enableAcceleratedNetwork = @()
    $listVM = @()
    #$enabledAccelerated = @()
    $listSKU = az vm list-skus --location eastus --all true --resource-type virtualMachines --query '[?capabilities[?name==`AcceleratedNetworkingEnabled`].value | [0] == `True`].{Name:name}'--output table
    
    $nicSemAcceleratedNetworking = Get-AzNetworkInterface | Where-Object { $_.EnableAcceleratedNetworking -eq $false }
    
    foreach ($nic in $nicSemAcceleratedNetworking) {
        $listVM += Get-AzVM -Name ($nic.VirtualMachine.Id -split ("/") | Select-Object -Last 1) -ResourceGroupName $nic.ResourceGroupName
    }

    foreach ($vm in $listVM) {
        foreach ($sku in $listSKU) {
            if ($sku -contains $vm.HardwareProfile.VmSize) {
                $enableAcceleratedNetwork += $vm
                break
            }
        }
    }    

    # Exibir as interfaces filtradas
    if ($enableAcceleratedNetwork) {
        Write-Host 'Lista de VMs que podem ativar o Accelerated Networking:'
        $enableAcceleratedNetwork | Select-Object Name, ResourceGroupName | Format-Table -AutoSize
        write-host "===================================================================="
    }
    else {
        Write-Host "Todas as interfaces de rede possuem Accelerated Networking ativado."
        write-host "===================================================================="
    }
}
##########Finaliza_Funcoes##########

while ($continue -ne $false) {
    write-host "===================================================================="
    write-host "Digite o numero da opcao:"
    write-host "1- Validar Backups de VMs"
    write-host "2- Validar Snapshots com mais de 60 Dias"
    write-host "3- Validar Discos sem recurso associado"
    write-host "4- Validar IP Publico sem recurso associado"
    write-host "5- Validar Interface de Rede sem recurso de VM associado"
    write-host "6- Validar NSG sem recurso associado"
    write-host "7- Validar Storage Account com Acesso Publico nos containers"
    write-host "8- Validar Storage Account com Soft Delete desabilitado"
    write-host "9- Validar IP Publico com SKU Basic"
    write-host "10- Avaliar VMs que podem habilitar Accelerated Networking"
    write-host "11- Todas as opcoes acima!!"
    write-host "99- SAIR"
    $answer = (Read-Host "Qual opção você deseja?")
    write-host "===================================================================="

    foreach ($subs in $subscription) {
        write-host "===================================================================="
        switch ($answer) {
            1 { 
                Set-AzContext -Subscription $subs
                BackupOff 
            }
            2 { 
                Set-AzContext -Subscription $subs
                SnapshotOver 
            }
            3 { 
                Set-AzContext -Subscription $subs
                DiskNull
            }
            4 { 
                Set-AzContext -Subscription $subs
                PipNull 
            }
            5 { 
                Set-AzContext -Subscription $subs
                NicNull 
            }
            6 { 
                Set-AzContext -Subscription $subs
                NsgNull 
            }
            7 { 
                Set-AzContext -Subscription $subs
                SaPublic 
            }
            8 { 
                Set-AzContext -Subscription $subs
                SaSoftDeleteDisable 
            }
            9 { 
                Set-AzContext -Subscription $subs
                PIP-Basic 
            }
            10 {
                Set-AzContext -Subscription $subs
                AcceleratedNetworking 
            }
            11 {
                Set-AzContext -Subscription $subs 
                BackupOff; SnapshotOver; DiskNull; PipNull; NicNull; NsgNull; SaPublic; SaSoftDeleteDisable; PIP-Basic; AcceleratedNetworking 
            }
            99 { exit }
            Default {
                Write-Host 'Opção Invalida' -BackgroundColor Red
            }
        }
    }
}