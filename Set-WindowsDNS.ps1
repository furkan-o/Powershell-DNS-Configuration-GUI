Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web.Extensions

# Does not work on Win10 but works on Win11
<#
function Set-WindowsDNS {
    param(
        [string]$DNSserver
    )

    if ($DNSserver -eq "Default") {
        return
    }

    try {
        $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        foreach ($Adapter in $Adapters) {
            Write-Host "Setting DNS to $DNSserver on $($Adapter.Name)"

            if ($DNSserver -eq "DHCP") {
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses -AddressFamily IPv4
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses -AddressFamily IPv6
            }
            else {
                $dnsConfigIPv4 = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4
                $primaryDnsIPv4 = $dnsConfigIPv4 | Select-Object -ExpandProperty ServerAddresses | Select-Object -First 1
                $secondaryDnsIPv4 = $dnsConfigIPv4 | Select-Object -ExpandProperty ServerAddresses | Select-Object -Last 1

                $dnsConfigIPv6 = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv6
                $primaryDnsIPv6 = $dnsConfigIPv6 | Select-Object -ExpandProperty ServerAddresses | Select-Object -First 1
                $secondaryDnsIPv6 = $dnsConfigIPv6 | Select-Object -ExpandProperty ServerAddresses | Select-Object -Last 1

                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $primaryDnsIPv4, $secondaryDnsIPv4 -AddressFamily IPv4
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $primaryDnsIPv6, $secondaryDnsIPv6 -AddressFamily IPv6
            }
        }
    }
    catch {
        Write-Warning "Unable to set DNS Provider due to an unhandled exception"
        Write-Warning $_.Exception.Message
        Write-Warning $_.Exception.StackTrace
    }
}
#>
# Function to set DNS based on selected provider
function Set-WindowsDNS {
    param(
        [string]$DNSserver
    )

    if ($DNSserver -eq "Default") {
        return
    }

    try {
        $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        foreach ($Adapter in $Adapters) {
            Write-Host "Setting DNS to $DNSserver on $($Adapter.Name)"

            if ($DNSserver -eq "DHCP") {
                netsh interface ip set dns name=$($Adapter.Name) source=dhcp
                netsh interface ipv6 set dns name=$($Adapter.Name) source=dhcp
            }
            else {
                $currentIPv4 = netsh interface ip show dns $($Adapter.Name) | Select-String "DNS servers configured through DHCP"
                $currentIPv6 = netsh interface ipv6 show dns $($Adapter.Name) | Select-String "DNS servers configured through DHCP"

                if ($currentIPv4) {
                    netsh interface ip set dns name=$($Adapter.Name) source=static addr=$DNSserver
                }
                else {
                    $currentIPv4Addr = (netsh interface ip show dns $($Adapter.Name) | Select-String "^\s*Address\s*:" -Context 0,1).Context.PostContext -replace "^\s*Address\s*:", ""
                    netsh interface ip set dns name=$($Adapter.Name) source=static addr=$DNSserver index=1
                    netsh interface ip add dns name=$($Adapter.Name) addr=$currentIPv4Addr index=2
                }

                if ($currentIPv6) {
                    netsh interface ipv6 set dns name=$($Adapter.Name) source=static addr=$DNSserver
                }
                else {
                    $currentIPv6Addr = (netsh interface ipv6 show dns $($Adapter.Name) | Select-String "^\s*Address\s*:" -Context 0,1).Context.PostContext -replace "^\s*Address\s*:", ""
                    netsh interface ipv6 set dns name=$($Adapter.Name) source=static addr=$DNSserver index=1
                    netsh interface ipv6 add dns name=$($Adapter.Name) addr=$currentIPv6Addr index=2
                }
            }
        }
    }
    catch {
        Write-Warning "Unable to set DNS Provider due to an unhandled exception"
        Write-Warning $_.Exception.Message
        Write-Warning $_.Exception.StackTrace
    }
}


# Read DNS servers from DNS.json
$dnsConfig = Get-Content -Raw -Path "DNS.json" | ConvertFrom-Json
$dnsProviders = $dnsConfig.configs.dns | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

# Create a form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DNS Configuration"
$form.Width = 300
$form.Height = 200
$form.StartPosition = "CenterScreen"

# Create a dropdown list for DNS providers
$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(50, 30)
$comboBox.Size = New-Object System.Drawing.Size(200, 20)
$comboBox.DropDownStyle = "DropDownList"
$comboBox.Items.AddRange($dnsProviders)
$form.Controls.Add($comboBox)

# Create a button to apply the selected DNS provider
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(100, 80)
$button.Size = New-Object System.Drawing.Size(100, 30)
$button.Text = "Apply DNS"
$button.Add_Click({
    $selectedProvider = $comboBox.SelectedItem.ToString()
    Set-WindowsDNS -DNSserver $dnsConfig.configs.dns.$selectedProvider.PrimaryIPv4
    [System.Windows.Forms.MessageBox]::Show("DNS set to $selectedProvider", "DNS Configuration", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$form.Controls.Add($button)

# Show the form
$form.ShowDialog() | Out-Null
