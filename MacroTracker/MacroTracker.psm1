$Script:MTDir = Join-Path [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData) "CheeseFizz" "MacroTracker"
$Script:MaxFileSize = 100KB

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
        $this.DataStart = Get-Date
        $this.DataEnd = Get-Date
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

function New-MTDietEntry {
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


}

funciton New-MTActivityEntry {

}

function SaveEntry {
    [CmdletBinding()]
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


}