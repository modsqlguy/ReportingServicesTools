# Copyright (c) 2016 Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT License (MIT)

function Revoke-RsCatalogItemAccess
{
    <#
        .SYNOPSIS
            This script revokes access to catalog items from users/groups.
        
        .DESCRIPTION
            This script revokes all access on the specified catalog item from the specified user/group.
        
        .PARAMETER Identity
            Specify the user or group name to revoke access from.
        
        .PARAMETER Path
            Specify the path to catalog item on the server.
    
        .PARAMETER Strict
            Throw a terminating error when trying to revoke all permissions when there are none assigned to the target identity.
        
        .PARAMETER ReportServerUri
            Specify the Report Server URL to your SQL Server Reporting Services Instance.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .PARAMETER Credential
            Specify the password to use when connecting to your SQL Server Reporting Services Instance.
            Use the "Connect-RsReportServer" function to set/update a default value.
        
        .PARAMETER Proxy
            Report server proxy to use.
            Use "New-RsWebServiceProxy" to generate a proxy object for reuse.
            Useful when repeatedly having to connect to multiple different Report Server.
        
        .EXAMPLE
            Revoke-RsCatalogItemAccess -Identity 'johnd' -Path '/My Folder/SalesReport'
            Description
            -----------
            This command will establish a connection to the Report Server located at http://localhost/reportserver using current user's credentials and then revoke all access granted to user 'johnd' on catalog item found at '/My Folder/SalesReport'.
        
        .EXAMPLE
            Revoke-RsCatalogItemAccess -ReportServerUri 'http://localhost/reportserver_sql2012' -Identity 'johnd' -Path '/My Folder/SalesReport'
            Description
            -----------
            This command will establish a connection to the Report Server located at http://localhost/reportserver_2012 using current user's credentials and then revoke all access granted to user 'johnd' on catalog item found at '/My Folder/SalesReport'.
        
        .EXAMPLE
            Revoke-RsCatalogItemAccess -Credential 'CaptainAwesome' -Identity 'johnd' -Path '/My Folder/SalesReport'
            Description
            -----------
            This command will establish a connection to the Report Server located at http://localhost/reportserver using CaptainAwesome's credentials and then revoke all access to user 'johnd' on catalog item found at '/My Folder/SalesReport'.
        
        .NOTES
            Author:      ???
            Editors:     Friedrich Weinmann
            Created on:  ???
            Last Change: 02.02.2017
            Version:     1.1
            
            Release 1.1 (02.02.2017, Friedrich Weinmann)
            - Removed/Replaced all instances of "Write-Information", in order to maintain PowerShell 3.0 Compatibility.
            - Fixed Parameter help (Don't poison the name with "(optional)", breaks Get-Help)
            - Standardized the parameters governing the Report Server connection for consistent user experience.
            - Implemented ShouldProcess (-WhatIf, -Confirm)
			- Replaced calling exit with throwing a terminating error (exit is a bit of an overkill when failing a simple execution)
			- Improved error message on failure.
            - Renamed the parameter 'UserOrGroupName' to 'Identity', in order to maintain parameter naming conventions. Added the previous name as an alias, for backwards compatiblity.
            - Renamed the parameter 'ItemPath' to 'Path', in order to maintain parameter naming conventions. Added the previous name as an alias, for backwards compatiblity.
            - New parameter: 'Strict'. Using this, the function will throw a terminating error when trying to revoke all permissions when there are none assigned to the target identity.
            - Renamed function from "Revoke-AccessOnCatalogItem" to "Revoke-RsCatalogItemAccess", in order to conform to naming standards and include the module prefix. Introduced an alias with the old name for backwards compatibility.
            - New parameter: 'Proxy'. Allows passing already established proxy objects for use instead of reestablishing each time.
    
            Release 1.0 (???, ???)
            - Initial Release
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param
    (
        [Alias('UserOrGroupName')]
        [Parameter(Mandatory = $True)]
        [string]
        $Identity,
        
        [Alias('ItemPath')]
        [Parameter(Mandatory = $True)]
        [string]
        $Path,
        
        [switch]
        $Strict,
        
        [string]
        $ReportServerUri,
        
        [Alias('ReportServerCredentials')]
        [System.Management.Automation.PSCredential]
        $Credential,
        
        $Proxy
    )
    
    if ($PSBoundParameters.ContainsKey("ReportServerUri")) { $tempUri = $ReportServerUri }
    else { $tempUri = [ReportingServicesTools.ConnectionHost]::Uri }
    
    if ($PSCmdlet.ShouldProcess($tempUri, "Revoke all roles on $Path for $Identity"))
    {
        #region Connect to Report Server using Web Proxy
        if (-not $Proxy)
        {
            try
            {
                $splat = @{ }
                if ($PSBoundParameters.ContainsKey('ReportServerUri')) { $splat['ReportServerUri'] = $ReportServerUri }
                if ($PSBoundParameters.ContainsKey('Credential')) { $splat['Credential'] = $Credential }
                $Proxy = New-RSWebServiceProxy @splat
            }
            catch
            {
                throw
            }
        }
        #endregion Connect to Report Server using Web Proxy

        #region Retrieve policies and validate
        # retrieving existing policies for the current item
        try
        {
            Write-Verbose "Retrieving policies for $Path..."
            $inheritsParentPolicy = $false
            $originalPolicies = $proxy.GetPolicies($Path, [ref] $inheritsParentPolicy)
            
            Write-Verbose "Policies retrieved: $($originalPolicies.Length)!"
        }
        catch
        {
            throw (New-Object System.Exception("Error retrieving existing policies for $Path! $($_.Exception.Message)", $_.Exception))
        }

        # keeping only those policies where userOrGroupName is not explicitly mentioned
        $policyList = $originalPolicies | Where-Object { $_.GroupUserName -ne $Identity }
        
        if ($Strict -and (-not ($originalPolicies | Where-Object { $_.GroupUserName -eq $Identity } )))
        {
            throw (New-Object System.Management.Automation.PSArgumentException("$Identity was not granted any rights on $Path!"))
        }
        #endregion Retrieve policies and validate
        
        #region updating policies on the item
        try
        {
            Write-Verbose "Revoking all access from $Identity on $Path..."
            $proxy.SetPolicies($Path, $policyList)
            Write-Verbose "Revoked all access from $Identity on $Path!"
        }
        catch
        {
            throw (New-Object System.Exception("Error occurred while revoking all access from $Identity on $Path! $($_.Exception.Message)", $_.Exception))
        }
        #endregion updating policies on the item
    }
}
New-Alias -Name "Revoke-AccessOnCatalogItem" -Value Revoke-RsCatalogItemAccess -Scope Global