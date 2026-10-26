@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set E=C:\Users\masou\Desktop\Lia\xpact\xpactGit\build\libexpat-R_2_8_1
cmake -S %E%\libexpat-R_2_8_1\expat -B %E%\build -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF -DEXPAT_SHARED_LIBS=ON || exit /b 1
cmake --build %E%\build || exit /b 1
cl 2>&1 | findstr Version
cmake --version | findstr version
