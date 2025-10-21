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
  config = jsondecode(file("${path.root}/config/image-config-w11.json"))
}

source "azure-arm" "w11" {
  subscription_id                   = var.subscription_id
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = var.w11_image_name
  location                          = var.location

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-11"
  image_sku       = "win11-23h2-pro"
  communicator    = "winrm"
  winrm_use_ssl   = true
  winrm_insecure  = true
  winrm_timeout   = "5m"
  winrm_username  = "packer"
  vm_size         = var.vm_size
  temp_resource_group_name = "${var.resource_group}-tmp"
}

build {
  name    = "w11-citrix-image"
  sources = ["source.azure-arm.w11"]

  provisioner "file" {
    source      = "config/image-config-w11.json"
    destination = "C:/Windows/Temp/packer_config_w11.json"
  }

  provisioner "windows-shell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "Write-Host 'Installing NuGet and PSWindowsUpdate...'",
      "Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue",
      "Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers",
      "Import-Module PSWindowsUpdate",
      "Write-Host 'Running Windows Update (may reboot)'",
      "Get-WindowsUpdate -AcceptAll -Install -AutoReboot"
    ]
  }

  provisioner "windows-shell" {
    inline = [
      "Write-Host 'Installing software from config...'",
      "powershell -Command \"$c = Get-Content 'C:\\Windows\\Temp\\packer_config_w11.json' -Raw | ConvertFrom-Json; foreach($app in $c.software){ Write-Host ('Installing ' + $app.name); $out = 'C:\\Windows\\Temp\\' + ($app.name + '_' + (Get-Date -Format yyyyMMddHHmmss) + (Split-Path $app.url -Leaf)); Invoke-WebRequest -Uri $app.url -OutFile $out; if($out -match '\\.msi$'){ Start-Process msiexec.exe -ArgumentList '/i', $out, $app.args, '/qn', '/norestart' -Wait } else { Start-Process -FilePath $out -ArgumentList $app.args -Wait } }\""
    ]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"Write-Output 'restarted'\""
  }

  provisioner "windows-shell" {
    inline = [
      "Write-Host 'Cleanup temp files...'",
      "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "if (Test-Path 'C:\\Windows\\System32\\Sysprep\\sysprep.exe') { Write-Host 'Running sysprep'; Start-Process -FilePath 'C:\\Windows\\System32\\Sysprep\\sysprep.exe' -ArgumentList '/oobe','/generalize','/shutdown' -Wait }"
    ]
  }
}
