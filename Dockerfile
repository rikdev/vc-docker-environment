FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN \
    Invoke-WebRequest \
        -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' \
        -OutFile 'vs_buildtools.exe'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'vs_buildtools.exe' \
        -ArgumentList \
            # https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools
            '--add Microsoft.VisualStudio.Component.VC.14.40.17.10.x86.x64', \
            '--add Microsoft.VisualStudio.Component.Windows11SDK.22621', \
            '--quiet', '--wait', '--norestart', '--nocache'; \
    Remove-Item -Path 'vs_buildtools.exe', \"$env:TEMP/*\" -Recurse -Force; \
    New-Item \
        -Path 'C:/BuildTools' \
        -ItemType SymbolicLink \
        -Value \"${env:ProgramFiles(x86)}/Microsoft Visual Studio/2022/BuildTools\"

# Updating utilities should't change the mtime of the VC
RUN \
    Write-Host 'Installing CMake...'; \
    Invoke-WebRequest \
        -Uri 'https://github.com/Kitware/CMake/releases/download/v3.23.2/cmake-3.23.2-windows-x86_64.msi' \
        -OutFile 'cmake.msi'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'msiexec' \
        -ArgumentList '/quiet /norestart /package cmake.msi ADD_CMAKE_TO_PATH=System'; \
    Remove-Item -Path 'cmake.msi'; \
\
    Write-Host 'Installing Ninja...'; \
    Invoke-WebRequest \
        -Uri 'https://github.com/ninja-build/ninja/releases/download/v1.11.0/ninja-win.zip' \
        -OutFile 'ninja.zip'; \
    Expand-Archive -Path 'ninja.zip' -DestinationPath \"$env:ProgramFiles/Ninja\"; \
    Remove-Item -Path 'ninja.zip'; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\Ninja\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing ccache...'; \
    Invoke-WebRequest \
        -Uri 'https://github.com/ccache/ccache/releases/download/v4.10.2/ccache-4.10.2-windows-x86_64.zip' \
        -OutFile 'ccache.zip'; \
    Expand-Archive -Path 'ccache.zip' -DestinationPath \"$env:ProgramFiles\"; \
    Move-Item -Path \"$env:ProgramFiles/ccache-*\" -Destination \"$env:ProgramFiles/ccache\"; \
    Remove-Item -Path 'ccache.zip', \"$env:ProgramFiles/ccache/*\" -Exclude '*.exe' -Recurse -Force; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\ccache\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing Git...'; \
    Invoke-WebRequest \
        -Uri 'https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/MinGit-2.46.0-64-bit.zip' \
        -OutFile 'git.zip'; \
    Expand-Archive -Path 'git.zip' -DestinationPath \"$env:ProgramFiles/MinGit\"; \
    Remove-Item -Path 'git.zip'; \
    [Environment]::SetEnvironmentVariable( \
        'Path', \
        [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine) + \";$env:ProgramFiles\MinGit\cmd\", \
        [EnvironmentVariableTarget]::Machine); \
\
    Write-Host 'Installing Rust...'; \
    Invoke-WebRequest \
        -Uri 'https://static.rust-lang.org/rustup/archive/1.27.1/x86_64-pc-windows-msvc/rustup-init.exe' \
        -OutFile 'rustup-init.exe'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'rustup-init.exe' \
        -ArgumentList \
            '-y', \
            '--profile minimal', \
            '--target i686-pc-windows-msvc x86_64-pc-windows-msvc', \
            '--default-toolchain 1.79.0'; \
    Remove-Item -Path 'rustup-init.exe'; \
\
    Write-Host 'Installing Python...'; \
    Invoke-WebRequest \
        -Uri 'https://www.python.org/ftp/python/3.12.5/python-3.12.5-amd64.exe' \
        -OutFile 'python-installer.exe'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'python-installer.exe' \
        -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Shortcuts=0 Include_doc=0 Include_test=0'; \
    Remove-Item -Path 'python-installer.exe', \"$env:TEMP/*\" -Recurse -Force;

RUN \
    Write-Host 'Installing Conan...'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'pip' \
        -ArgumentList 'install --no-cache-dir conan==1.48.1'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'conan' \
        -ArgumentList 'config init'; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'conan' \
        -ArgumentList \"config set general.user_home_short=$env:SystemDrive\.conan\"; \
    Start-Process -Wait -NoNewWindow \
        -FilePath 'conan' \
        -ArgumentList \"config set storage.path=$env:SystemDrive\.conan\";

ENV CCACHE_DIR='C:\.ccache' CCACHE_TEMPDIR='C:\ccache-tmp'

ENTRYPOINT [ \
    "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/Tools/VsDevCmd.bat", "-host_arch=amd64", \
    "-arch=amd64", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass" \
]
