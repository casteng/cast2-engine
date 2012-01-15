(*
 CAST II Engine Juggle library test
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
{$APPTYPE CONSOLE}

{$IFDEF FPC}{$IFDEF USEGLUT}
  {$DEFINE GLUT}
{$ENDIF}{$ENDIF}

program JTest;

uses
  JTestMain,
  OSUtils, AppsInit,
  {$IFDEF GLUT}
    AppsInitGLUT,
  {$ELSE}
    {$IFDEF WINDOWS}
      AppsInitWin,
    {$ENDIF}
  {$ENDIF}

  SysUtils;

var JTestDemo: TJTestDemo;

begin
  try
    // Create window
    {$IFDEF GLUT}
      Starter := TGLUTAppStarter.Create('CAST II Simple Demo', [soSingleUser]);
      {$IFDEF LINUX}
        OSUtils.InitX11(Starter.WindowHandle);
      {$ENDIF}
    {$ELSE}
      Starter := TWin32AppStarter.Create('CAST II Simple Demo', [soSingleUser]);
    {$ENDIF}

    // Check if all is OK
    if not Starter.Terminated then begin
      JTestDemo := TJTestDemo.Create;
      // Main application cycle
      while Starter.Process do JTestDemo.Process;
    end;

    // Shutdown
    FreeAndNil(JTestDemo);
    FreeAndNil(Starter);

  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
