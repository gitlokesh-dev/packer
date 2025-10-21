\
packer {
  required_plugins {
    azurerm = {
      version = ">= 1.8.0"
      source  = "github.com/hashicorp/azurerm"
    }
  }
}

locals {
  config = jsondecode(file("${path.root}/config/image-config-cc.json"))
}

source "azure-arm" "cc" {
  subscription_id                   = var.subscription_id
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = var.cc_image_name
  location                          = var.location

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-Datacenter"
  communicator    = "winrm"
  winrm_use_ssl   = true
  winrm_insecure  = true
  winrm_timeout   = "5m"
  winrm_username  = "packer"
  vm_size         = var.vm_size
  temp_resource_group_name = "${var.resource_group}-tmp"
}

build {
  name    = "cc-image"
  sources = ["source.azure-arm.cc"]

  provisioner "file" {
    source      = "config/image-config-cc.json"
    destination = "C:/Windows/Temp/packer_config_cc.json"
  }

  provisioner "windows-shell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "Write-Host 'Installing PSWindowsUpdate and applying updates...'",
      "Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue",
      "Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers",
      "Import-Module PSWindowsUpdate",
      "Get-WindowsUpdate -AcceptAll -Install -AutoReboot"
    ]
  }

  # Domain join: domain password provided via environment variable PACKER_DOMAIN_PASSWORD (set by pipeline or CLI)
  provisioner "windows-shell" {
    inline = [
      "Write-Host 'Attempting domain join (uses env PACKER_DOMAIN_PASSWORD)'",
      "powershell -Command \"$c = Get-Content 'C:\\Windows\\Temp\\packer_config_cc.json' -Raw | ConvertFrom-Json; $sec = ConvertTo-SecureString ($env:PACKER_DOMAIN_PASSWORD) -AsPlainText -Force; $cred = New-Object System.Management.Automation.PSCredential($c.domain_join.user, $sec); Add-Computer -DomainName $c.domain_join.domain -Credential $cred -Force; Restart-Computer -Force\""
    ]
  }

  # After reboot, install Citrix Connector
  provisioner "windows-shell" {
    inline = [
      "Write-Host 'Installing Citrix Cloud Connector...'",
      "powershell -Command \"$c = Get-Content 'C:\\Windows\\Temp\\packer_config_cc.json' -Raw | ConvertFrom-Json; $out = 'C:\\Windows\\Temp\\ccinstaller.exe'; Invoke-WebRequest -Uri $c.software[0].url -OutFile $out; Start-Process -FilePath $out -ArgumentList $c.software[0].args -Wait\""
    ]
  }

  provisioner "windows-shell" {
    inline = [
      "Write-Host 'Cleanup and sysprep...'",
      "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "if (Test-Path 'C:\\Windows\\System32\\Sysprep\\sysprep.exe') { Start-Process -FilePath 'C:\\Windows\\System32\\Sysprep\\sysprep.exe' -ArgumentList '/oobe','/generalize','/shutdown' -Wait }"
    ]
  }
}
