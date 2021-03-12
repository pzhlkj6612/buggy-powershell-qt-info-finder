
param (
    [Parameter(Mandatory = $true)]
    [string]
    ${QT_VERSION},
    [Parameter(Mandatory = $true)]
    [string]
    ${TOOLCHAIN_TYPE},
    [Parameter(Mandatory = $true)]
    [string]
    ${TOOLCHAIN_ARCH}
)


$ErrorActionPreference = 'Stop'


${original_foreground_color} = $host.ui.RawUI.ForegroundColor


if (-not (${QT_VERSION} -match '^\d+\.\d+\.\d+$')) {
    throw "Invalid Qt version: ${QT_VERSION}"
}
Write-Output -InputObject "Got Qt version: ${QT_VERSION}"

if (-not (${TOOLCHAIN_TYPE} -match '^(?<type>mingw|msvc)$')) {
    throw "Invalid Qt toolchain: ${TOOLCHAIN_TYPE}"
}

${TOOLCHAIN_TYPE} = $Matches['type']
Write-Output -InputObject "Got Qt toolchain type: ${TOOLCHAIN_TYPE}"

if (-not (${TOOLCHAIN_ARCH} -match '^(?<arch>32|64)$')) {
    throw "Invalid Qt toolchain: ${TOOLCHAIN_ARCH}"
}

${TOOLCHAIN_ARCH} = $Matches['arch']
Write-Output -InputObject "Got Qt toolchain architecture: ${TOOLCHAIN_ARCH}"



${release_info_download_url} = `
    Invoke-WebRequest https://api.github.com/repos/pzhlkj6612/qt-windows-x86-desktop-msvc-mingw-compatibility-finder/releases/latest | `
    Select-Object -ExpandProperty 'Content' | `
    ConvertFrom-Json | `
    Select-Object -ExpandProperty 'assets' | `
    Where-Object { $_.content_type -eq 'application/json' } | `
    Select-Object -ExpandProperty 'browser_download_url'
Write-Output -InputObject 'Got Qt info json file url.'

${release_info_json} = `
    Invoke-WebRequest ${release_info_download_url} | `
    ConvertFrom-Json
Write-Output -InputObject 'Got Qt info json.'

${toolchain_available_versions_arches_and_package_names} = `
    ${release_info_json}. `
    ${QT_VERSION}. `
    ${TOOLCHAIN_TYPE}
Write-Output -InputObject 'Available toolchain versions:'
${toolchain_available_versions_arches_and_package_names} | Format-List


# BUG. 5.9.0 msvc 32 not found


# Must be a list.
${toolchain_available_versions_descending_sorted} = @(
    ${toolchain_available_versions_arches_and_package_names} | `
        Get-Member -MemberType NoteProperty | `
        Select-Object -ExpandProperty 'Name' | `
        Sort-Object -Descending)
Write-Output -InputObject 'Sorted available toolchain versions:'
${toolchain_available_versions_descending_sorted} | Format-List


# We need the latest one.
${toolchain_version} = ${toolchain_available_versions_descending_sorted}[0]
Write-Output -InputObject "The latest toolchain version: ${toolchain_version}"

${toolchain_package_name} = `
    ${release_info_json}. `
    ${QT_VERSION}. `
    ${TOOLCHAIN_TYPE}. `
    ${toolchain_version}. `
    ${TOOLCHAIN_ARCH}
    
$host.ui.RawUI.ForegroundColor = 'Blue'
Write-Output -InputObject "The package name of the toolchain = ${toolchain_package_name}"
$host.ui.RawUI.ForegroundColor = ${original_foreground_color}

if ($null -eq ${toolchain_package_name}) {
    throw "Invalid Qt toolchain combination: ${QT_VERSION} + ${TOOLCHAIN_TYPE}"
}

# Expected:
#   win32_mingw53
#   win64_mingw53
#   win32_mingw73
#   win64_mingw73
#   win32_mingw81
#   win64_mingw81
#   win32_msvc2015
#   win64_msvc2015_64
#   win32_msvc2017
#   win64_msvc2017_64
#   win32_msvc2019
#   win64_msvc2019_64
${qt_arch} = "win${TOOLCHAIN_ARCH}_${TOOLCHAIN_TYPE}${toolchain_version}"
if ((${TOOLCHAIN_TYPE} -eq 'msvc') -and (${TOOLCHAIN_ARCH} -eq '64')) {
    ${qt_arch} = "${qt_arch}_64"
}
Write-Output -InputObject "Got qtArch = ${qt_arch}"

# Expected:
#   mingw53_32
#   mingw53_64
#   mingw73_32
#   mingw73_64
#   mingw81_32
#   mingw81_64
#   msvc2015
#   msvc2015_64
#   msvc2017
#   msvc2017_64
#   msvc2019
#   msvc2019_64
${qt_install_dir_name} = "${TOOLCHAIN_TYPE}${toolchain_version}"
if ((${TOOLCHAIN_TYPE} -eq 'mingw') -or
    ((${TOOLCHAIN_TYPE} -eq 'msvc') -and (${TOOLCHAIN_ARCH} -eq '64'))) {
    ${qt_install_dir_name} = "${qt_install_dir_name}_${TOOLCHAIN_ARCH}"
}
Write-Output -InputObject "Got qtInstallDirName = ${qt_install_dir_name}"


# Set outputs.

# Common
$host.ui.RawUI.ForegroundColor = 'Yellow'
Write-Output -InputObject "::set-output name=qtArch::${qt_arch}"
Write-Output -InputObject "::set-output name=qtInstallDirName::${qt_install_dir_name}"
$host.ui.RawUI.ForegroundColor = ${original_foreground_color}


# MinGW only.

if (${TOOLCHAIN_TYPE} -eq 'mingw') {
    # Robustness.
    if (-not (${toolchain_version} -match '^(?<major>\d+)(?<minor>\d)$')) {
        throw "Invalid Qt MinGW tools version: ${toolchain_version}"
    }

    ${tool_major_version} = $Matches['major']
    ${tool_minor_version} = $Matches['minor']

    # Expected:
    #   5.3.0
    #   7.3.0
    #   8.1.0
    ${tool_version} = "${tool_major_version}.${tool_minor_version}.0"
    Write-Output -InputObject "MinGW tool version = ${tool_version}"

    # Expected:
    #   qt.tools.win32_mingw530
    #   qt.tools.win64_mingw530
    #   qt.tools.win32_mingw730
    #   qt.tools.win64_mingw730
    #   qt.tools.win32_mingw810
    #   qt.tools.win64_mingw810
    ${tool_full_qualified_tool_name} = "qt.tools.win${TOOLCHAIN_ARCH}_mingw${tool_major_version}${tool_minor_version}0"
    Write-Output -InputObject "MinGW tool full qualified name = ${tool_full_qualified_tool_name}"

    # Expected:
    #   tools_mingw,5.3.0,qt.tools.win32_mingw530
    #   tools_mingw,5.3.0,qt.tools.win64_mingw530
    #   tools_mingw,7.3.0,qt.tools.win32_mingw730
    #   tools_mingw,7.3.0,qt.tools.win64_mingw730
    #   tools_mingw,8.1.0,qt.tools.win32_mingw810
    #   tools_mingw,8.1.0,qt.tools.win64_mingw810
    ${tool_iqa_name} = "tools_mingw,${tool_version},${tool_full_qualified_tool_name}"
    Write-Output -InputObject "MinGW tool name used by install-qt-action = ${tool_iqa_name}"

    # Expected:
    #   mingw530_32
    #   mingw530_64
    #   mingw730_32
    #   mingw730_64
    #   mingw810_32
    #   mingw810_64
    ${tool_dir_name} = "mingw${tool_major_version}${tool_minor_version}0_${TOOLCHAIN_ARCH}"
    Write-Output -InputObject "MinGW tool directory name = ${tool_dir_name}"


    # Set MinGW outputs.

    # MinGW
    $host.ui.RawUI.ForegroundColor = 'DarkGreen'
    Write-Output -InputObject "::set-output name=toolIqaName::${tool_iqa_name}"
    Write-Output -InputObject "::set-output name=toolDirName::${tool_dir_name}"
    $host.ui.RawUI.ForegroundColor = ${original_foreground_color}
}
