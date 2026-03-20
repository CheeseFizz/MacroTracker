$Script:MTDir = Join-Path [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData) "CheeseFizz" "MacroTracker"
$Script:MaxFileSize = 100KB
$Script:DateStrFormat = "yyyyMMdd"
$Script:TimeStrFormat = "hh:mm:ss"
$Script:OldDataCache = $null

class Entry {
    [string]$Description
}
class DietEntry : Entry {
    [Int16]$Calories
    [Int16]$Protein
    [Int16]$Fiber
    [Int16]$Carbs
    [Int16]$Fat

    DietEntry([hashtable]$props) {
        foreach ($k in $this.PSObject.Properties.GetEnumerator().Name) {
            $this.$k = $props[$k]
        }
    }

    DietEntry(
        [Int16]$Calories,
        [Int16]$Protein,
        [Int16]$Fiber,
        [Int16]$Carbs,
        [Int16]$Fat,
        [string]$Description
    ) {
        $this.Calories = $Calories
        $this.Protein = $Protein
        $this.Fiber = $Fiber
        $this.Carbs = $Carbs
        $this.Fat = $Fat
        $this.Description = $Description
    }
}

class ActivityEntry : Entry {
    [Int16]$Calories

    ActivityEntry([hashtable]$props) {
        foreach ($k in $this.PSObject.Properties.GetEnumerator().Name) {
            $this.$k = $props[$k]
        }
    }

    ActivityEntry(
        [Int16]$Calories,
        [string]$Description
    ) {
        $this.Calories = $Calories
        $this.Description = $Description
    }
}

class EntryLog {
    [System.Collections.IDictionary]$Diet
    [System.Collections.IDictionary]$Activity

    EntryLog() {
        $this.Diet     = [System.Collections.Generic.Dictionary[string, DietEntry]]::new()
        $this.Activity = [System.Collections.Generic.Dictionary[string, ActivityEntry]]::new()
    }

}

class MTDataLog {
    [DateTime]$DataStart
    [DateTime]$DataEnd
    [System.Collections.IDictionary]$Data

    MTDataLog() {
        $this.DataStart = (Get-Date).Date 
        $this.DataEnd = (Get-Date).Date 
        $this.Data = [System.Collections.Generic.Dictionary[string, EntryLog]]::new()
    }
}

function InitializeEnvironment {
    # Check for potential failure on non-Windows systems before making directories
    if ($Script:MTDir -eq (Join-Path "" "CheeseFizz" "MacroTracker")){
        $Script:MTDir = ""
        throw "Unexpected error: OS did not provide LocalApplicationData directory"
    }
    if (-not (Test-Path $Script:MTDir)) {
        New-Item -Path $Script:MTDir -ItemType Directory -Force | Out-Null
    }

    $sfile = Join-Path $Script:MTDir "settings.json"
    if (-not (Test-Path $sfile)) {
        $Script:MTSettings = @{
            BMR = 0
            DataDirectory = Join-Path $Script:MTDir "Data"
        }
        $Script:MTSettings | ConvertTo-Json | Out-File $sfile -Force
    }

    if (-not (Test-Path $Script:MTSettings["DataDirectory"])) {
        New-Item -Path $Script:MTSettings["DataDirectory"] -ItemType Directory -Force | Out-Null
    }

    #load current log
    $dfile = Join-Path $Script:MTSettings["DataDirectory"] "data.xml"
    if (Test-Path $dfile) {
        $Script:CurrentDataLog = Get-Content $dfile | ConvertFrom-CliXml 
    }
    else {
        $Script:CurrentDataLog = [MTDataLog]::new()
    }
}

function SaveData {
    # Save data to disk
    $Script:CurrentDataLog.DataEnd = $dt.Date
    $dfilepath = Join-Path $Script:MTSettings["DataDirectory"] "data.xml"
    $Script:CurrentDataLog | ConvertTo-CliXml -Depth 10 | Out-File $dfilepath
    
    # Roll over data file if it's too big
    $datafile = Get-Item $dfile

    if ($datafile.Length -ge $Script:MaxFileSize) {
        # Clean cut for datafile
        # Get current day's data to put in new file
        $dt = Get-Date
        $todaydata = $Script:CurrentDataLog.Data[$($dt.ToString($Script:DateStrFormat))]

        $newMTDataLog = [MTDataLog]::new()
        $newMTDataLog.Data[$($dt.ToString($Script:DateStrFormat))] = $todaydata
        

        # Remove today's data from current file
        $Script:CurrentDataLog.Data.Remove($($dt.ToString($Script:DateStrFormat))) | Out-Null

        # Save old log to a new file
        $startstamp = $Script:CurrentDataLog.DataStart.ToString($Script:DateStrFormat)
        $endstamp = $Script:CurrentDataLog.DataEnd.ToString($Script:DateStrFormat)
        $timestampedfilename = "data_$($startstamp)-$($endstamp).xml"
        $timestampedfilepath = $dfilepath = Join-Path $Script:MTSettings["DataDirectory"] $timestampedfilename

        $Script:CurrentDataLog | ConvertTo-CliXml -Depth 10 | Out-File $timestampedfilepath

        # Set new CurrentDataLog and save it
        $Script:CurrentDataLog = $newMTDataLog
        $Script:CurrentDataLog | ConvertTo-CliXml -Depth 10 | Out-File $dfilepath
    }
}

function Add-MTDietEntry {
    param(
        # kcal
        [Int16]
        $Calories=0,

        # grams
        [Int16]
        $Protein=0,

        # grams
        [Int16]
        $Fiber=0,
        
        # grams
        [Int16]
        $Carbs=0,

        # grams
        [Int16]
        $Fat=0,

        [string]
        $Description="",

        # don't add calculated calories to calorie total
        [switch]
        $NoCalc
    )

    if ($Script:MTDir -ieq "") {
        throw "Module initialization failed, so functions are unavailable"
    }

    if (
        $Calories -eq 0 -and
        $Protein -eq 0 -and
        $Fiber -eq 0 -and
        $Carbs -eq 0 -and
        $Fat -eq 0
    ) {
        # nothing fancy, just don't do anything
        return
    }

    $entry = [DietEntry]::new($PSBoundParameters)

    if (-not ($Calories -gt 0 -or $NoCalc)) {
        # Calculate Calories field
        $entry.Calories = (
            4 * $Protein + 
            4 * ($Carbs - $Fiber) +
            2 * $Fiber +
            9 * $Fat
        )
    }
    
    SaveEntry -Entry $Entry
}

function Add-MTActivityEntry {
    param(
        # kcal
        [Int16]
        $Calories=0,

        [string]
        $Description=""
    )

    if ($Script:MTDir -ieq "") {
        throw "Module initialization failed, so functions are unavailable"
    }

    if (
        $Calories -eq 0 -and
        $Description -ieq ""
    ) {
        # nothing fancy, just don't do anything
        return
    }

    $entry = [ActivityEntry]::new($PSBoundParameters)   

    SaveEntry -Entry $Entry
}

function SaveEntry {
    param(
        [Entry]$Entry
    )

    switch ($Entry.GetType().Name) {
        "DietEntry" {
            $dest = "Diet"
        }
        "ActivityEntry" {
            $dest = "Activity"
        }
        Default {
            throw "Unexpected error"
        }
    }

    $dt = Get-Date
    if ($null -ieq $Script:CurrentDataLog.Data[$($dt.ToString($Script:DateStrFormat))]){
        $Script:CurrentDataLog.Data[$($dt.ToString($Script:DateStrFormat))] = [EntryLog]::new()
    }

    $Script:CurrentDataLog.Data[$($dt.ToString($Script:DateStrFormat))].$dest[$($dt.ToString("hh:mm:ss"))] = $Entry

    SaveData
}

function getData {
    param(
        [datetime]$Date
    )

    # check if data is available in current datalog
    if ($Date -lt $Script:CurrentDataLog.DataStart) {
        
        # check if cached already
        if (
            $Date -ge $Script:OldDataCache.DataStart -and
            $Date -lt $Script.$Script:OldDataCache.DataEnd
        ) {
            return $Script:OldDataCache.Data[$Date.ToString($Script:DateStrFormat)]
        }

        # look for applicable datalog
        $data = $null # use a local var for testing that I found something

        $dfiles = Get-ChildItem $Script:MTSettings["DataDirectory"] -Name "*.xml"
        foreach ($f in $dfiles) {
            # filename format: data_$($startstamp)-$($endstamp).xml
            $splitname = $f.Name.Split([char[]]@("_","-","."))
            $start = [datetime]::ParseExact($splitname[1], $Script:DateStrFormat , $null)
            $end = [datetime]::ParseExact($splitname[2], $Script:DateStrFormat , $null)
            if ($Date -ge $start -and $Date -lt $end) {
                $data = Get-Content $f | ConvertFrom-CliXml
                break
            }
        }
        if ($null -ine $data) {
            $Script:OldDataCache = $data 
            return $Script:OldDataCache.Data[$Date.ToString($Script:DateStrFormat)]
        }
    }
    elseif ($Date -gt $Script:CurrentDataLog.DataEnd) {
        return
    }

    return $Script:CurrentDataLog.Data[$Date.ToString($Script:DateStrFormat)]
}

function Get-MTData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="Quick")]
        [ValidateSet("Last", "Today", "Week")]
        [string]
        $From,
        
        [Parameter(Mandatory=$true, ParameterSetName="TimeSpan")]
        [timespan]
        $TimeSpan,

        [switch]
        $AsHashtable
    )

    throw [System.NotImplementedException] "This function isn't implemented yet"

    $Now = Get-Date
    [array]$reqdata = @()

    if ($PSCmdlet.ParameterSetName -ieq "Quick") {
        switch ($From) {
            "Last" {
                $todaydata = $Script:CurrentDataLog.Data[$Now.ToString($Script:DateStrFormat)]
                $lastactkey = $todaydata.Activity.Keys | Sort-Object -Stable
                $lastdietkey = $todaydata.Diet.Keys | Sort-Object -Stable
                if ($lastactkey -gt $lastdietkey) {
                    $reqdata += $Script:CurrentDataLog.Data[$Now.ToString($Script:DateStrFormat)].Activity[$lastactkey]
                }
                else {
                    $reqdata += $Script:CurrentDataLog.Data[$Now.ToString($Script:DateStrFormat)].Diet[$lastactkey]
                }
            }
            "Today" {
                $reqdata += $Script:CurrentDataLog.Data[$Now.ToString($Script:DateStrFormat)]
            }
            "Week" {
                for ($day = $Now.Date.AddDays(-6); $day -le $Now.Date; $day = $day.AddDays(1)) {
                    $reqdata += getData -Date $day
                }
            }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -ieq "TimeSpan") {
        $start = $Now - $TimeSpan
        for ($day = $start; $day -le $Now; $day = $day.AddDays(1)){
            $reqdata += getData -Date $day
        }
    }

}

InitializeEnvironment

Export-ModuleMember -Function @(
    "Add-MTDietEntry",
    "Add-MTActivityEntry"
)