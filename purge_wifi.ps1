# Requiere privilegios de Administrador.

Write-Host "[*] Iniciando limpieza de kernel y red..." -ForegroundColor Cyan

# 1. Neutralizando Inicio Rápido
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-ItemProperty -Path $regPath -Name "HiberbootEnabled" -Value 0 -Force
Write-Host "[+] Hiberboot desactivado. El kernel no cacheará estados corruptos." -ForegroundColor Green

# 2. Limpiando gestión de energía del adaptador
$wifi = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "Native 802.11" }
if ($wifi) {
    Disable-NetAdapterPowerManagement -Name $wifi.Name -ErrorAction SilentlyContinue
    Write-Host "[+] Suspensión de energía bloqueada para: $($wifi.Name)" -ForegroundColor Green
} else {
    Write-Host "[-] Adaptador Wi-Fi no detectado. Abortando fase 2." -ForegroundColor Red
}

# 3. Limpiando perfiles y pila TCP/IP
netsh wlan delete profile name=* i=* | Out-Null
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
ipconfig /flushdns | Out-Null
Write-Host "[+] Perfiles Wi-Fi incinerados. Pila Winsock/IP y DNS purgados." -ForegroundColor Green

# 4. Extracción del controlador (Driver Nuke)
if ($wifi) {
    $pnp = Get-PnpDevice -Class Net | Where-Object { $_.FriendlyName -match $wifi.Name -or $_.FriendlyName -match "Wi-Fi|Wireless|802.11" }
    if ($pnp) {
        $drvProp = Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_DriverInfPath' -InstanceId $pnp.InstanceId -ErrorAction SilentlyContinue
        if ($drvProp -and $drvProp.Data) {
            $inf = $drvProp.Data
            Write-Host "[*] Nukeando paquete de controlador: $inf" -ForegroundColor Yellow
            pnputil /delete-driver $inf /uninstall /force | Out-Null
        }
        Disable-PnpDevice -InstanceId $pnp.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[+] Controlador y dispositivo desinstalados." -ForegroundColor Green
    }
}

Write-Host "`n[!] PROTOCOLO COMPLETADO." -ForegroundColor Red