del bin/simple.exe

rem set fpcfile=land.dpr
rem set fpcfile=water.dpr
rem set fpcfile=land.dpr
set fpcfile=jtest.dpr

set fpccmd=%FPC_HOME%\bin\i386-win32\fpc.exe -Fu../ACS -Fu../dependencies/opengl -Fu../dependencies/opengl_fpc
set fpcoptions=-Fu.. -Fu../../base -Fu../../base/template -Fu../../base/ACS
set fpcoptions=%fpcoptions% -Fi.. -Fi../../base -Fi../../base/template
set fpcoptions=%fpcoptions% -FEbin -FUtemp

%fpccmd% %fpcoptions% %fpcfile%
