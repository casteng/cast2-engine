(*
 CAST II Engine water demo
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
program Water;

uses
  WaterMain,
  AppsInit, AppsInitWin,
  SysUtils;

var WaterDemo: TWaterDemo;

begin
  // Create window
  Starter := TWin32AppStarter.Create('CAST II Water Demo', [soSingleUser]);

  // Check if all is OK
  if not Starter.Terminated then begin
    WaterDemo := TWaterDemo.Create;
    // Main application cycle
    while Starter.Process do WaterDemo.Process;
  end;

  // Shutdown
  FreeAndNil(WaterDemo);
  FreeAndNil(Starter);
end.

