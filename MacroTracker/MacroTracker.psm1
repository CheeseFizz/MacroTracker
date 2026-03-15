$Script:MTDir = Join-Path [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData) "CheeseFizz" "MacroTracker"
$Script:MaxFileSize = 100KB

function InitializeEnvironment {
    # Check for potential failure on non-Windows systems
    if ($Script:MTDir -eq (Join-Path "" "CheeseFizz" "MacroTracker")){
        throw "Unexpected error: OS did not provide LocalApplicationData directory"
    }
    if (-not (Test-Path $Script:MTDir)) {
        New-Item -Path $Script:MTDir -ItemType Directory -Force | Out-Null
    }

    $tdir = Join-Path $Script:MTDir "Data"
    if (-not (Test-Path $tdir)) {
        New-Item -Path $tdir -ItemType Directory -Force | Out-Null
    }
}

function New-MTEntry {
    [CmdletBinding()]
    param(
        # kcal
        [Int16]
        $Calories,

        # grams
        [Int16]
        $Protein,

        [Int16]
        $Fiber,
        
        # grams
        [Int16]
        $Carbs,

        # grams
        [Int16]
        $Fat,

        # don't add calculated calories to calorie total
        [switch]
        $NoCalc
    )


}