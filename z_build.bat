@echo off
REM ///////////////////////////////////////////////////////////////////////////
REM // Set Paths
REM ///////////////////////////////////////////////////////////////////////////
set "MSVC_PATH=C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC"
set "TOOLS_VER=140"

REM ###############################################
REM # DO NOT MODIFY ANY LINES BELOW THIS LINE !!! #
REM ###############################################

REM ///////////////////////////////////////////////////////////////////////////
REM // Setup environment
REM ///////////////////////////////////////////////////////////////////////////
if exist "%QTVC_PATH%\bin\qtvars.bat" ( call "%QTVC_PATH%\bin\qtvars.bat" )
if exist "%QTVC_PATH%\bin\qtenv2.bat" ( call "%QTVC_PATH%\bin\qtenv2.bat" )
call "%MSVC_PATH%\vcvarsall.bat" x86

REM ///////////////////////////////////////////////////////////////////////////
REM // Check environment
REM ///////////////////////////////////////////////////////////////////////////
if "%VCINSTALLDIR%"=="" (
	echo %%VCINSTALLDIR%% not specified. Please check your MSVC_PATH var!
	goto BuildError
)
if not exist "%VCINSTALLDIR%\bin\cl.exe" (
	echo C++ compiler not found. Please check your MSVC_PATH var!
	goto BuildError
)
if "%QTDIR%"=="" (
	echo %%QTDIR%% not specified. Please check your QTDIR var!
	goto BuildError
)
if not exist "%QTDIR%\bin\moc.exe" (
	echo Qt meta compiler not found. Please check your QTDIR var!
	goto BuildError
)
if not exist "%QTDIR%\include\QtCore\qglobal.h" (
	echo %%QTDIR%% header files not found. Please check your QTDIR var!
	goto BuildError
)

REM ///////////////////////////////////////////////////////////////////////////
REM // Get current date and time (in ISO format)
REM ///////////////////////////////////////////////////////////////////////////
set "ISO_DATE="
set "ISO_TIME="
if not exist "%~dp0\..\Prerequisites\GnuWin32\date.exe" BuildError
for /F "tokens=1,2 delims=:" %%a in ('"%~dp0\..\Prerequisites\GnuWin32\date.exe" +ISODATE:%%Y-%%m-%%d') do (
	if "%%a"=="ISODATE" set "ISO_DATE=%%b"
)
for /F "tokens=1,2,3,4 delims=:" %%a in ('"%~dp0\..\Prerequisites\GnuWin32\date.exe" +ISOTIME:%%T') do (
	if "%%a"=="ISOTIME" set "ISO_TIME=%%b:%%c:%%d"
)
if "%ISO_DATE%"=="" goto BuildError
if "%ISO_TIME%"=="" goto BuildError

REM ///////////////////////////////////////////////////////////////////////////
REM // Clean up temp files
REM ///////////////////////////////////////////////////////////////////////////
echo ---------------------------------------------------------------------
echo CLEAN UP
echo ---------------------------------------------------------------------
for %%i in (bin,obj,tmp) do (
	del /Q /S /F "%~dp0\%%i\*.*"
)

REM ///////////////////////////////////////////////////////////////////////////
REM // Build the binaries
REM ///////////////////////////////////////////////////////////////////////////
echo ---------------------------------------------------------------------
echo BEGIN BUILD
echo ---------------------------------------------------------------------
MSBuild.exe /property:Configuration=release /target:clean   "%~dp0\x264_launcher_MSVC2015.sln"
if not "%ERRORLEVEL%"=="0" goto BuildError
MSBuild.exe /property:Configuration=release /target:rebuild "%~dp0\x264_launcher_MSVC2015.sln"
if not "%ERRORLEVEL%"=="0" goto BuildError

REM ///////////////////////////////////////////////////////////////////////////
REM // Detect build number
REM ///////////////////////////////////////////////////////////////////////////
set "BUILD_NO="
for /F "tokens=2,*" %%s in (%~dp0\src\version.h) do (
	if "%%s"=="VER_X264_BUILD" set "BUILD_NO=%%~t"
)
if "%BUILD_NO%"=="" goto BuildError

REM ///////////////////////////////////////////////////////////////////////////
REM // Copy base files
REM ///////////////////////////////////////////////////////////////////////////
echo ---------------------------------------------------------------------
echo BEGIN PACKAGING
echo ---------------------------------------------------------------------
set "PACK_PATH=%TMP%\~%RANDOM%%RANDOM%.tmp"
mkdir "%PACK_PATH%"
mkdir "%PACK_PATH%\imageformats"
mkdir "%PACK_PATH%\toolset\x86"
mkdir "%PACK_PATH%\toolset\x64"
mkdir "%PACK_PATH%\toolset\common"
mkdir "%PACK_PATH%\sources"
copy "%~dp0\bin\Win32\Release\x264_launcher.exe"    "%PACK_PATH%"
copy "%~dp0\bin\Win32\Release\MUtils32-?.dll"       "%PACK_PATH%"
copy "%~dp0\bin\Win32\Release\toolset\x86\*.exe"    "%PACK_PATH%\toolset\x86"
copy "%~dp0\bin\Win32\Release\toolset\x86\*.dll"    "%PACK_PATH%\toolset\x86"
copy "%~dp0\bin\Win32\Release\toolset\x64\*.exe"    "%PACK_PATH%\toolset\x64"
copy "%~dp0\bin\Win32\Release\toolset\x64\*.dll"    "%PACK_PATH%\toolset\x64"
copy "%~dp0\bin\Win32\Release\toolset\common\*.exe" "%PACK_PATH%\toolset\common"
copy "%~dp0\bin\Win32\Release\toolset\common\*.gpg" "%PACK_PATH%\toolset\common"
copy "%~dp0\etc\sources\*.xz"                       "%PACK_PATH%\sources"
copy "%~dp0\LICENSE.html"                           "%PACK_PATH%"
copy "%~dp0\*.txt"                                  "%PACK_PATH%"

REM ///////////////////////////////////////////////////////////////////////////
REM // Copy dependencies
REM ///////////////////////////////////////////////////////////////////////////
copy "%MSVC_PATH%\redist\x86\Microsoft.VC%TOOLS_VER%.CRT\*.dll"                     "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\bin\QtCore4.dll"            "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\bin\QtGui4.dll"             "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\bin\QtSvg4.dll"             "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\bin\QtXml4.dll"             "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\bin\QtXml4.dll"             "%PACK_PATH%"
copy "%~dp0\..\Prerequisites\Qt4\v%TOOLS_VER%_xp\Shared\plugins\imageformats\*.dll" "%PACK_PATH%\imageformats"
del "%PACK_PATH%\imageformats\*d4.dll" 2> NUL
if %TOOLS_VER% GEQ 140 (
	copy "%~dp0\..\Prerequisites\MSVC\redist\ucrt\DLLs\x86\*.dll" "%PACK_PATH%"
)

REM ///////////////////////////////////////////////////////////////////////////
REM // Generate Docs
REM ///////////////////////////////////////////////////////////////////////////
"%~dp0\..\Prerequisites\Pandoc\pandoc.exe" --from markdown_github+pandoc_title_block+header_attributes+implicit_figures --to html5 --toc -N --standalone -H "%~dp0\etc\css\style.inc" --output "%PACK_PATH%\README.html" "%~dp0\README.md"

REM ///////////////////////////////////////////////////////////////////////////
REM // Compress
REM ///////////////////////////////////////////////////////////////////////////
"%~dp0\..\Prerequisites\UPX\upx.exe" --best "%PACK_PATH%\x264_launcher.exe"
"%~dp0\..\Prerequisites\UPX\upx.exe" --best "%PACK_PATH%\MUtils32-1.dll"
"%~dp0\..\Prerequisites\UPX\upx.exe" --best "%PACK_PATH%\Qt*.dll"

REM ///////////////////////////////////////////////////////////////////////////
REM // Attributes
REM ///////////////////////////////////////////////////////////////////////////
attrib +R "%PACK_PATH%\*.exe"
attrib +R "%PACK_PATH%\*.dll"
attrib +R "%PACK_PATH%\*.txt"
attrib +R "%PACK_PATH%\*.html"

REM ///////////////////////////////////////////////////////////////////////////
REM // Setup install parameters
REM ///////////////////////////////////////////////////////////////////////////
mkdir "%~dp0\out" 2> NUL
set "OUT_PATH=%~dp0\out\x264_launcher.%ISO_DATE%"
:GenerateOutfileName
if exist "%OUT_PATH%.exe" (
	set "OUT_PATH=%OUT_PATH%.new"
	goto GenerateOutfileName
)
if exist "%OUT_PATH%.sfx" (
	set "OUT_PATH=%OUT_PATH%.new"
	goto GenerateOutfileName
)
if exist "%OUT_PATH%.zip" (
	set "OUT_PATH=%OUT_PATH%.new"
	goto GenerateOutfileName
)

REM ///////////////////////////////////////////////////////////////////////////
REM // Create Tag
REM ///////////////////////////////////////////////////////////////////////////
echo Simple x264/x265 Launcher - graphical front-end for x264 and x265 > "%PACK_PATH%\BUILD_TAG.txt"
echo Copyright (C) 2004-2017 LoRd_MuldeR ^<MuldeR2@GMX.de^> >> "%PACK_PATH%\BUILD_TAG.txt"
echo. >> "%PACK_PATH%\BUILD_TAG.txt"
echo Build #%BUILD_NO%, created on %ISO_DATE% at %ISO_TIME% >> "%PACK_PATH%\BUILD_TAG.txt"
echo. >> "%PACK_PATH%\BUILD_TAG.txt"
echo. >> "%PACK_PATH%\BUILD_TAG.txt"
"%~dp0\..\Prerequisites\GnuWin32\cat.exe" "%~dp0\etc\setup\build.nfo" >> "%PACK_PATH%\BUILD_TAG.txt"

REM ///////////////////////////////////////////////////////////////////////////
REM // Build the installer
REM ///////////////////////////////////////////////////////////////////////////
"%~dp0\..\Prerequisites\NSIS\makensis.exe" "/DX264_DATE=%ISO_DATE%" "/DX264_BUILD=%BUILD_NO%" "/DX264_OUTPUT_FILE=%OUT_PATH%.sfx" "/DX264_SOURCE_PATH=%PACK_PATH%" "%~dp0\etc\setup\setup.nsi"
if not "%ERRORLEVEL%"=="0" goto BuildError

call "%~dp0\..\Prerequisites\SevenZip\7zSD.cmd" "%OUT_PATH%.sfx" "%OUT_PATH%.exe" "Simple x264/x265 Launcher" "x264_launcher-setup-r%BUILD_NO%"
if not "%ERRORLEVEL%"=="0" goto BuildError

set "VERPATCH_PRODUCT=Simple x264/x265 Launcher (Setup)"
set "VERPATCH_FILEVER=%ISO_DATE:-=.%.%BUILD_NO%"
"%~dp0\..\Prerequisites\VerPatch\verpatch.exe" "%OUT_PATH%.exe" "%VERPATCH_FILEVER%" /pv "%VERPATCH_FILEVER%" /fn /s desc "%VERPATCH_PRODUCT%" /s product "%VERPATCH_PRODUCT%" /s title "x264 Launcher Installer SFX" /s copyright "Copyright (C) 2004-2017 LoRd_MuldeR" /s company "Free Software Foundation"
if not "%ERRORLEVEL%"=="0" goto BuildError

attrib +R "%OUT_PATH%.exe"
attrib +R "%OUT_PATH%.sfx"

REM ///////////////////////////////////////////////////////////////////////////
REM // Build ZIP package
REM ///////////////////////////////////////////////////////////////////////////
pushd "%PACK_PATH%"
"%~dp0\..\Prerequisites\GnuWin32\zip.exe" -r -9 -z "%OUT_PATH%.zip" "*.*" < "%PACK_PATH%\BUILD_TAG.txt"
popd

if not "%ERRORLEVEL%"=="0" goto BuildError
attrib +R "%OUT_PATH%.zip"

REM ///////////////////////////////////////////////////////////////////////////
REM // Clean up
REM ///////////////////////////////////////////////////////////////////////////
rmdir /Q /S "%PACK_PATH%"

REM ///////////////////////////////////////////////////////////////////////////
REM // COMPLETE
REM ///////////////////////////////////////////////////////////////////////////
echo.
echo Build completed.
echo.
pause
goto:eof

REM ///////////////////////////////////////////////////////////////////////////
REM // FAILED
REM ///////////////////////////////////////////////////////////////////////////
:BuildError
echo.
echo Build has failed !!!
echo.
pause
