Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web.Extensions

# Function to set DNS based on selected provider
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
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses
            }
            else {
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $DNSserver
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
