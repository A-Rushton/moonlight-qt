# Builds webrtc-audio-processing as release and debug-CRT static libraries in libs\webrtc-apm\windows-{x64,arm64}
$ErrorActionPreference = 'Stop'

$Version = "2.1"
# Bump when the local patches change so cached builds are replaced
$BuildId = "$Version-2"
$Url = "https://freedesktop.org/software/pulseaudio/webrtc-audio-processing/webrtc-audio-processing-$Version.tar.xz"
$Sha256 = "ae9302824b2038d394f10213cab05312c564a038434269f11dbf68f511f9f9fe"
$Targets = @(
    @{ Name = "windows-x64"; VcArch = "amd64"; TgtArch = "x64"; CpuFamily = "x86_64"; Cpu = "x86_64"; Machine = "X64"; Guard = @("/guard:cf", "/guard:ehcont") },
    @{ Name = "windows-arm64"; VcArch = "arm64"; TgtArch = "arm64"; CpuFamily = "aarch64"; Cpu = "arm64"; Machine = "ARM64"; Guard = @("/guard:cf", "/guard:ehcont", "/guard:signret") }
)
# Debug apps link the debug CRT (/MDd), which a /MD static lib can't mix with
$Variants = @(
    @{ Lib = "webrtc-apm.lib"; Crt = "md"; Suffix = "" },
    @{ Lib = "webrtc-apm-debug.lib"; Crt = "mdd"; Suffix = "-debug" }
)
# webrtc needs C++20 under MSVC (designated initializers); abseil must match
$CppStd = "c++20"

$SourceRoot = Split-Path -Parent $PSScriptRoot
$OutRoot = Join-Path $SourceRoot "libs\webrtc-apm"

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Exe $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-Built($Target) {
    $OutDir = Join-Path $OutRoot $Target.Name
    $VersionFile = Join-Path $OutDir "VERSION"
    foreach ($Variant in $Variants) {
        if (-not (Test-Path (Join-Path $OutDir "lib\$($Variant.Lib)"))) {
            return $false
        }
    }
    (Test-Path $VersionFile) -and ((Get-Content $VersionFile -Raw).Trim() -eq $BuildId)
}

function Import-VcVars($VcVarsAll, $Arch, $TgtArch, $WorkDir) {
    $Bat = Join-Path $WorkDir "vcvars-$Arch.bat"
    Set-Content -Path $Bat -Encoding ASCII -Value @(
        "@echo off",
        "call `"$VcVarsAll`" $Arch >nul || exit /b 1",
        "set"
    )
    $Lines = & $Bat
    if ($LASTEXITCODE -ne 0) {
        throw "vcvarsall.bat $Arch failed with exit code $LASTEXITCODE"
    }
    foreach ($Line in $Lines) {
        $Index = $Line.IndexOf('=')
        if ($Index -gt 0) {
            [Environment]::SetEnvironmentVariable($Line.Substring(0, $Index), $Line.Substring($Index + 1), 'Process')
        }
    }
    if ($env:VSCMD_ARG_TGT_ARCH -ne $TgtArch) {
        throw "vcvarsall.bat $Arch targets '$env:VSCMD_ARG_TGT_ARCH', expected '$TgtArch'"
    }
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        throw "cl.exe not found after vcvarsall.bat $Arch"
    }
}

function Edit-Source($Path, $Find, $Replace) {
    $Text = [IO.File]::ReadAllText($Path)
    $Index = $Text.IndexOf($Find, [StringComparison]::Ordinal)
    if ($Index -lt 0 -or $Text.IndexOf($Find, $Index + 1, [StringComparison]::Ordinal) -ge 0) {
        throw "Expected exactly one match for the patch in $Path"
    }
    [IO.File]::WriteAllText($Path, $Text.Substring(0, $Index) + $Replace + $Text.Substring($Index + $Find.Length))
}

function Save-Environment {
    $Saved = @{}
    Get-ChildItem env: | ForEach-Object { $Saved[$_.Name] = $_.Value }
    $Saved
}

function Restore-Environment($Saved) {
    @(Get-ChildItem env:) | Where-Object { -not $Saved.ContainsKey($_.Name) } | ForEach-Object {
        [Environment]::SetEnvironmentVariable($_.Name, $null, 'Process')
    }
    foreach ($Name in $Saved.Keys) {
        [Environment]::SetEnvironmentVariable($Name, $Saved[$Name], 'Process')
    }
}

$Pending = @($Targets | Where-Object { -not (Test-Built $_) })
if ($Pending.Count -eq 0) {
    Write-Host "webrtc-audio-processing $BuildId already built" -ForegroundColor Green
    exit 0
}

foreach ($Tool in @("meson", "ninja", "python")) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        throw "$Tool not found"
    }
}

$VsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $VsWhere)) {
    throw "vswhere.exe not found"
}
$VsPath = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $VsPath) {
    throw "Visual Studio with C++ tools not found"
}
$VcVarsAll = Join-Path $VsPath "VC\Auxiliary\Build\vcvarsall.bat"

$HostArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }

$WorkDir = Join-Path ([IO.Path]::GetTempPath()) ("wapm-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {
    $Archive = Join-Path $WorkDir "src.tar.xz"
    Write-Host "Downloading webrtc-audio-processing $Version..." -ForegroundColor Cyan
    Invoke-Native "curl.exe" @("-s", "-L", "-f", "--retry", "3", "-o", $Archive, $Url)
    $Hash = (Get-FileHash -Algorithm SHA256 $Archive).Hash.ToLowerInvariant()
    if ($Hash -ne $Sha256) {
        throw "Checksum mismatch for $Url (got $Hash)"
    }
    Invoke-Native "python" @("-c", "import sys, tarfile; t = tarfile.open(sys.argv[1]); t.extractall(sys.argv[2], **({'filter': 'data'} if hasattr(tarfile, 'data_filter') else {}))", $Archive, $WorkDir)
    $SrcDir = Join-Path $WorkDir "webrtc-audio-processing-$Version"

    # Expose AEC3 tuning through a factory that takes an EchoCanceller3Config
    $PatchDir = Join-Path $PSScriptRoot "webrtc-apm"
    Copy-Item -Path (Join-Path $PatchDir "echo_canceller3_factory.h") -Destination (Join-Path $SrcDir "webrtc\api\audio")
    Copy-Item -Path (Join-Path $PatchDir "echo_canceller3_factory.cc") -Destination (Join-Path $SrcDir "webrtc\modules\audio_processing\aec3")
    Edit-Source (Join-Path $SrcDir "webrtc\api\meson.build") `
        "  ['audio', 'echo_control.h'],`n" `
        "  ['audio', 'echo_control.h'],`n  ['audio', 'echo_canceller3_factory.h'],`n"
    Edit-Source (Join-Path $SrcDir "webrtc\modules\audio_processing\meson.build") `
        "  'aec3/echo_canceller3.cc',`n" `
        "  'aec3/echo_canceller3.cc',`n  'aec3/echo_canceller3_factory.cc',`n"

    # MSVC has no GCC inline asm for the ARM FPCR access, so leave denormals alone there
    Edit-Source (Join-Path $SrcDir "webrtc\system_wrappers\source\denormal_disabler.cc") `
        "    defined(WEBRTC_ARCH_ARM_FAMILY)`n#define WEBRTC_DENORMAL_DISABLER_SUPPORTED" `
        "    (defined(WEBRTC_ARCH_ARM_FAMILY) && !defined(_MSC_VER))`n#define WEBRTC_DENORMAL_DISABLER_SUPPORTED"

    foreach ($Target in $Pending) {
        $Name = $Target.Name
        Write-Host "Building $Name..." -ForegroundColor Cyan

        $MachineFile = Join-Path $WorkDir "$Name.ini"
        $MachineLines = @(
            "[binaries]",
            "c = 'cl'",
            "cpp = 'cl'",
            "ar = 'lib'"
        )
        if ($Target.VcArch -eq $HostArch) {
            $VcArg = $HostArch
            $MachineArg = "--native-file"
        } else {
            $VcArg = "$($HostArch)_$($Target.VcArch)"
            $MachineArg = "--cross-file"
            $MachineLines += @(
                "",
                "[host_machine]",
                "system = 'windows'",
                "cpu_family = '$($Target.CpuFamily)'",
                "cpu = '$($Target.Cpu)'",
                "endian = 'little'",
                "",
                "[properties]",
                "skip_sanity_check = true"
            )
        }
        # Match the app's hardening flags (globaldefs.pri); these also reach abseil
        $GuardArgs = ($Target.Guard | ForEach-Object { "'$_'" }) -join ", "
        $MachineLines += @(
            "",
            "[built-in options]",
            "c_args = [$GuardArgs]",
            "cpp_args = [$GuardArgs]"
        )
        Set-Content -Path $MachineFile -Encoding ASCII -Value $MachineLines

        $OutDir = Join-Path $OutRoot $Name
        if (Test-Path $OutDir) {
            Remove-Item -Path $OutDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path (Join-Path $OutDir "lib") | Out-Null

        $SavedEnv = Save-Environment
        try {
            Import-VcVars $VcVarsAll $VcArg $Target.TgtArch $WorkDir
            foreach ($Variant in $Variants) {
                $Tag = "$Name$($Variant.Suffix)"
                $BuildDir = Join-Path $WorkDir "b-$Tag"
                $Prefix = Join-Path $WorkDir "i-$Tag"
                Invoke-Native "meson" @("setup", $BuildDir, $SrcDir, $MachineArg, $MachineFile,
                    "--buildtype=release", "--default-library=static", "-Db_vscrt=$($Variant.Crt)",
                    "-Dwrap_mode=forcefallback", "-Dcpp_std=$CppStd", "-Dabseil-cpp:cpp_std=$CppStd",
                    "--prefix", $Prefix)
                Invoke-Native "meson" @("compile", "-C", $BuildDir)
                Invoke-Native "meson" @("install", "-C", $BuildDir, "--quiet")

                $MainLib = @(Get-ChildItem -Path (Join-Path $Prefix "lib") -File |
                    Where-Object { $_.Name -match '^(lib)?webrtc-audio-processing-2\.(a|lib)$' })
                if ($MainLib.Count -ne 1) {
                    throw "webrtc-audio-processing library not found for $Tag"
                }
                $AbslLibs = @(Get-ChildItem -Path (Join-Path $BuildDir "subprojects") -Recurse -File |
                    Where-Object { $_.Extension -in @(".a", ".lib") } | Sort-Object FullName)
                if ($AbslLibs.Count -eq 0) {
                    throw "No abseil libraries found for $Tag"
                }

                $Rsp = Join-Path $WorkDir "lib-$Tag.rsp"
                $OutLib = Join-Path $OutDir "lib\$($Variant.Lib)"
                $RspLines = @("/NOLOGO", "/MACHINE:$($Target.Machine)", "/OUT:`"$OutLib`"")
                $RspLines += @($MainLib) + $AbslLibs | ForEach-Object { "`"$($_.FullName)`"" }
                Set-Content -Path $Rsp -Encoding ASCII -Value $RspLines
                Invoke-Native "lib.exe" @("@$Rsp")
            }
        } finally {
            Restore-Environment $SavedEnv
        }

        # Headers are identical across CRT variants, so take the last one installed
        $IncDir = Join-Path $Prefix "include"
        if (-not (Test-Path (Join-Path $IncDir "absl"))) {
            throw "abseil headers were not installed for $Name"
        }
        Copy-Item -Path (Join-Path $IncDir "webrtc-audio-processing-2") -Destination (Join-Path $OutDir "include") -Recurse
        Copy-Item -Path (Join-Path $IncDir "absl") -Destination (Join-Path $OutDir "include\absl") -Recurse
        Set-Content -Path (Join-Path $OutDir "VERSION") -Encoding ASCII -Value $BuildId
        Write-Host "Built $OutDir" -ForegroundColor Green
    }
} finally {
    Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}
