# References: 
#https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction?view=o365-worldwide#exclude-files-and-folders-from-asr-rules
#https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction?view=o365-worldwide#powershell
#https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-output?view=powershell-7.3
#https://kaidojarvemets.com/simplifying-cyber-defense-how-to-configure-attack-surface-reduction-with-powershell/#:~:text=The%20following%20are%20the%20steps,the%20AttackSurfaceReductionRules_Actions%20and%20AttackSurfaceReductionRules_Ids%20properties


# set the GUID of the the ASR Rule
$ASRRuleGUID = '26190899-1602-49e8-8b27-eb1d0a1ce869'

$ActiveASRRules = Get-MPPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids
#first check if the specified ASR has already been set

if ( $ActiveASRRules -contains $ASRRuleGUID){
    Write-Output "The ASR Rule $ASRRuleGUID is already set"

}
else {
    # set it if it has not been set
    Set-MpPreference -AttackSurfaceReductionRules_Ids $ASRRuleGUID -AttackSurfaceReductionRules_Actions Enabled
    Write-Output "The ASR Rule $ASRRuleGUID has been successfully set"

}

#####
# References:
# https://www.tenable.com/audits/items/CIS_Microsoft_Windows_Server_2019_STIG_v1.0.1_L1_DC.audit:0dc79e9a4bf73bcd9cd1e190c69df018

# Both the Parse-SecPol and Set-SecPol functions were code from StackOverflow. The code an be found here:
# https://stackoverflow.com/questions/23260656/modify-local-security-policy-using-powershell
# This code is used to parse the local securit config file and make create structures to easily refernce in code
# then update and set the config file
Function Parse-SecPol($CfgFile){ 
    secedit /export /cfg "$CfgFile" | out-null
    $obj = New-Object psobject
    $index = 0
    $contents = Get-Content $CfgFile -raw
    [regex]::Matches($contents,"(?<=\[)(.*)(?=\])") | %{
        $title = $_
        [regex]::Matches($contents,"(?<=\]).*?((?=\[)|(\Z))", [System.Text.RegularExpressions.RegexOptions]::Singleline)[$index] | %{
            $section = new-object psobject
            $_.value -split "\r\n" | ?{$_.length -gt 0} | %{
                $value = [regex]::Match($_,"(?<=\=).*").value
                $name = [regex]::Match($_,".*(?=\=)").value
                $section | add-member -MemberType NoteProperty -Name $name.tostring().trim() -Value $value.tostring().trim() -ErrorAction SilentlyContinue | out-null
            }
            $obj | Add-Member -MemberType NoteProperty -Name $title -Value $section
        }
        $index += 1
    }
    return $obj
}

Function Set-SecPol($Object, $CfgFile){
   $SecPool.psobject.Properties.GetEnumerator() | %{
        "[$($_.Name)]"
        $_.Value | %{
            $_.psobject.Properties.GetEnumerator() | %{
                "$($_.Name)=$($_.Value)"
            }
        }
    } | out-file $CfgFile -ErrorAction Stop
    secedit /configure /db c:\windows\security\local.sdb /cfg "$CfgFile" /areas SECURITYPOLICY
}


$SecPool = Parse-SecPol -CfgFile C:\test\Test.cgf

$administratorsGroup = Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.ObjectClass -eq 'User' }

foreach ($user in $administratorsGroup) {
    $username = $user.Name
    Write-Output "Local account and member of Administrators group: $username"
}

$DenyGroup= @("Guests") + $administratorsGroup


#configure the SeDenyNetworkLogonRight to deny network access for guests, andminstrative group, and local group here
$SecPool.'Privilege Rights'.SeDenyNetworkLogonRight = $DenyGroup

Set-SecPol -Object $SecPool -CfgFile C:\Test\Test.cfg