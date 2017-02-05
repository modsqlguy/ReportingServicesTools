# Copyright (c) 2016 Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT License (MIT)


function Set-RsDataSourcePassword
{
    <#
        .SYNOPSIS
            Overwrites the password on a Datasource.
        
        .DESCRIPTION
            Overwrites the password on a Datasource.
        
        .PARAMETER Path
            Path to DataSource.
        
        .PARAMETER Password
            Password to set.
        
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
            Set-RsDataSourcePassword -ReportServerUri 'http://localhost/reportserver_sql2012' -Path /DataSource1 -Password SuperSecretPassword
            
            Description
            -----------
            Sets the password for the datasource /DataSource1 to 'SuperSecretPassword'
        
        .NOTES
            Author:      ???
            Editors:     Friedrich Weinmann
            Created on:  ???
            Last Change: 04.02.2017
            Version:     1.1
            
            Release 1.1 (04.02.2017, Friedrich Weinmann)
            - Fixed Parameter help (Don't poison the name with "(optional)", breaks Get-Help)
            - Standardized the parameters governing the Report Server connection for consistent user experience.
            - Renamed the parameter 'ItemPath' to 'Path', in order to maintain parameter naming conventions. Added the previous name as an alias, for backwards compatiblity.
            - Changed type of parameter 'Path' to System.String[], to better facilitate pipeline & nonpipeline use
            - Redesigned to accept pipeline input from 'Path'
            - Implemented ShouldProcess (-WhatIf, -Confirm)
    
            Release 1.0 (???, ???)
            - Initial Release
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Alias('ItemPath')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]] 
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $Password,
        
        [string]
        $ReportServerUri,
        
        [Alias('ReportServerCredentials')]
        [System.Management.Automation.PSCredential]
        $Credential,
        
        $Proxy
    )
    
    Begin
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
    }
    
    Process
    {
        foreach ($item in $Path)
        {
            if ($PSCmdlet.ShouldProcess($item, "Overwrite the password"))
            {
                try { $dataSourceContent = $Proxy.GetDataSourceContents($item) }
                catch { throw (New-Object System.Exception("Failed to retrieve Datasource content: $($_.Exception.Message)", $_.Exception))}
                $dataSourceContent.Password = $Password
                Write-Verbose "Setting password of datasource $item"
                try { $Proxy.SetDataSourceContents($item, $dataSourceContent) }
                catch { throw (New-Object System.Exception("Failed to update Datasource content: $($_.Exception.Message)", $_.Exception)) }
            }
        }
    }
}

