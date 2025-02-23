FROM mcr.microsoft.com/windows/servercore:ltsc2025

SHELL ["powershell", "-Command", \
    "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; \
    function Download-File($Uri, $OutFile, $Hash) { \
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile; \
        if ((Get-FileHash -Path $OutFile -Algorithm SHA256).Hash -ne $Hash) { \
            Write-Error \\\"Invalid hash for file '$OutFile'\\\" \
        }; \
    };"]

RUN \
    Download-File \
        -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' \
        -OutFile 'vs_buildtools.exe' \
        -Hash 'efc5cbf61e84d9762ac34da1ebea1802389b77233e9883ea1889d75f3d8b7e61'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'vs_buildtools.exe' \
        -ArgumentList \
            # https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools
            '--add Microsoft.VisualStudio.Component.VC.14.43.17.13.x86.x64', \
            '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64', \
            '--add Microsoft.VisualStudio.Component.Windows11SDK.26100', \
            '--quiet', '--wait', '--norestart', '--nocache'; \
    Remove-Item -Path 'vs_buildtools.exe', \"$env:TEMP/*\" -Recurse -Force; \
    New-Item \
        -Path 'C:/BuildTools' \
        -ItemType SymbolicLink \
        -Value \"${env:ProgramFiles(x86)}/Microsoft Visual Studio/2022/BuildTools\"

ENV CCACHE_DIR='C:\.ccache' \
    CCACHE_TEMPDIR='C:\ccache-tmp' \
    CONAN_HOME='C:\.conan2' \
    CARGO_HOME='C:\.cargo' \
    RUSTUP_HOME='C:\.rustup'

# Updating utilities should't change the mtime of the VC
RUN \
    Write-Host 'Installing CMake...'; \
    Download-File \
        -Uri 'https://github.com/Kitware/CMake/releases/download/v3.31.5/cmake-3.31.5-windows-x86_64.msi' \
        -OutFile 'cmake.msi' \
        -Hash '97e249f199b86c1fc56dbc5e80b1a9e1f912c34dfbf8e7933ba1944e3034455f'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'msiexec' \
        -ArgumentList '/quiet /norestart /package cmake.msi ADD_CMAKE_TO_PATH=System'; \
    Remove-Item -Path 'cmake.msi'; \
\
    Write-Host 'Installing Ninja...'; \
    Download-File \
        -Uri 'https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip' \
        -OutFile 'ninja.zip' \
        -Hash 'f550fec705b6d6ff58f2db3c374c2277a37691678d6aba463adcbb129108467a'; \
    Expand-Archive -Path 'ninja.zip' -DestinationPath \"$env:ProgramFiles/Ninja\"; \
    Remove-Item -Path 'ninja.zip'; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\Ninja\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing ccache...'; \
    Download-File \
        -Uri 'https://github.com/ccache/ccache/releases/download/v4.10.2/ccache-4.10.2-windows-x86_64.zip' \
        -OutFile 'ccache.zip' \
        -Hash '6252f081876a9a9f700fae13a5aec5d0d486b28261d7f1f72ac11c7ad9df4da9'; \
    Expand-Archive -Path 'ccache.zip' -DestinationPath \"$env:ProgramFiles\"; \
    Move-Item -Path \"$env:ProgramFiles/ccache-*\" -Destination \"$env:ProgramFiles/ccache\"; \
    Remove-Item -Path 'ccache.zip', \"$env:ProgramFiles/ccache/*\" -Exclude '*.exe' -Recurse -Force; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\ccache\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing Git...'; \
    Download-File \
        -Uri 'https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.tar.bz2' \
        -OutFile 'git.tar.bz2' \
        -Hash 'ec46b07acc431dcbe64ef5665582b934530b09b8f7ef3b39ad912832a3fefa6b'; \
    New-Item -Path \"$env:ProgramFiles\" -Name 'Git' -ItemType 'directory'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'tar' \
        -ArgumentList \
            '--extract', \
            '--file=git.tar.bz2', \
            \"--directory=`\"$env:ProgramFiles/Git`\"\"; \
    Remove-Item -Path 'git.tar.bz2'; \
    Remove-Item -Path \"$env:ProgramFiles/Git/usr/bin/ssh*.exe\"; \
    Add-Content -Path \"$env:ProgramFiles/Git/etc/gitconfig\" -Value \"[safe]`n`tdirectory = *\"; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\Git\bin\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing Rust...'; \
    Download-File \
        -Uri 'https://static.rust-lang.org/rustup/archive/1.27.1/x86_64-pc-windows-msvc/rustup-init.exe' \
        -OutFile 'rustup-init.exe' \
        -Hash '193d6c727e18734edbf7303180657e96e9d5a08432002b4e6c5bbe77c60cb3e8'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'rustup-init.exe' \
        -ArgumentList \
            '-y', \
            '--profile minimal', \
            '--target i686-pc-windows-msvc x86_64-pc-windows-msvc', \
            '--default-toolchain 1.85.0'; \
    Remove-Item -Path 'rustup-init.exe'; \
\
    Write-Host 'Installing Python...'; \
    Download-File \
        -Uri 'https://www.python.org/ftp/python/3.13.2/python-3.13.2-amd64.exe' \
        -OutFile 'python-installer.exe' \
        -Hash '9aaa1075d0bd3e8abd0623d2d05de692ff00780579e1b232f259028bac19bb51'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'python-installer.exe' \
        -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Shortcuts=0 Include_doc=0 Include_test=0'; \
    Remove-Item -Path 'python-installer.exe', \"$env:TEMP/*\" -Recurse -Force;

RUN \
    Write-Host 'Installing Conan...'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'pip' \
        -ArgumentList 'install --no-cache-dir conan==2.12.2';

USER ContainerUser

ENTRYPOINT [ \
    "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/Tools/VsDevCmd.bat", "-host_arch=amd64", \
    "-arch=amd64", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass" \
]
