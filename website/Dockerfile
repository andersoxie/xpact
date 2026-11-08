# XPact website (API, worker, XPact DLLs, data and the built site) as a Windows container.
#
# Windows only: xpact.dll is a Windows DLL (Eiffel + MSVC) and the worker uses Windows Job Objects,
# so this needs a Windows host with Windows containers (Windows Server, or Windows 10/11 Pro).
# The DLLs cannot be built inside the image, so build everything on the host first:
#
#   .\website\scripts\build-dll.ps1
#   .\website\scripts\publish.ps1
#   docker build -f website\Dockerfile -t xpact-website website\dist
#   docker run -d --name xpact -p 5099:8080 --memory 4g xpact-website
#
# More in docs/docker.md.

# Server Core, not Nano Server: the XPact DLLs import SHELL32.dll.
# Pick the tag that matches the host's Windows version (ltsc2022 = Windows Server 2022, ltsc2025 = 2025).
ARG WINDOWS_TAG=ltsc2022
FROM mcr.microsoft.com/dotnet/aspnet:10.0-windowsservercore-${WINDOWS_TAG}

WORKDIR C:\\app
# The API looks for wwwroot\ in the working folder, so it must stay the app folder.
# The build context is website\dist. Only what the site runs on: no .pdb, no web.config (IIS only).
COPY ["*.exe", "*.dll", "*.json", "./"]
COPY native native/
COPY data data/
COPY wwwroot wwwroot/

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

# Not an administrator inside the container.
USER ContainerUser

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD curl.exe -fs http://localhost:8080/api/health || exit 1

ENTRYPOINT ["C:\\app\\Xpact.Api.exe"]
