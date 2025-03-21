# Azure Validation Scripts

Este repositório contém um conjunto de scripts em PowerShell para validar diferentes recursos no Azure. O script permite a execução de verificações em até 10 assinaturas simultaneamente, facilitando a gestão e otimização do ambiente em nuvem.

## Funcionalidades

O script realiza as seguintes validações:

1. **Validar Backups de VMs**
2. **Validar Snapshots com mais de 60 Dias**
3. **Validar Discos sem recurso associado**
4. **Validar IP Público sem recurso associado**
5. **Validar Interface de Rede sem recurso de VM associado**
6. **Validar NSG sem recurso associado**
7. **Validar Storage Account com Acesso Público nos Containers**
8. **Validar Storage Account com Soft Delete desabilitado**
9. **Validar IP Público com SKU Basic**
10. **Avaliar VMs que podem habilitar Accelerated Networking**
11. **Executar todas as opções acima**

## Pré-requisitos

Antes de executar o script, certifique-se de que você tem:

- Uma conta no Azure com permissões adequadas para visualizar e gerenciar os recursos
- O módulo **Azure CLI** instalado
- O **PowerShell** instalado e configurado

## Como Usar

1. Clone este repositório:
   ```sh
   git clone https://github.com/seu-repositorio/azure-validation-scripts.git
   ```
2. Acesse o diretório do projeto:
   ```sh
   cd azure-validation-scripts
   ```
3. Edite o script `azure_validation_scripts.ps1` e insira os IDs das assinaturas que deseja validar.
4. Execute o script no PowerShell:
   ```sh
   .\azure_validation_scripts.ps1
   ```

## Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues e pull requests com melhorias ou novas funcionalidades.

