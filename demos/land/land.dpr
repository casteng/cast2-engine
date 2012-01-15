(*
 CAST II Engine landscape demo
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
program Land;

uses
  Logger,
  BaseTypes, Windows,
  LandMain,
  AppsInit, AppsInitWin,
  SysUtils;

var LandDemo: TLandDemo;

type
  TLandStarter = class(TWin32AppStarter)
  protected
    procedure InitWindowSettings(var AWindowClass: TWndClass; var ARect: BaseTypes.TRect); override;
  end;

{ TLandStarter }

procedure TLandStarter.InitWindowSettings(var AWindowClass: TWndClass; var ARect: BaseTypes.TRect);
begin
{  ARect.Left := 0;
  ARect.Top := 0;
  ARect.Right := 512;
  ARect.Bottom := 356;}
end;

begin
  // Create window
  Starter := TLandStarter.Create('CAST II Landscape Demo', [soSingleUser]);

//  try
  // Check if all is OK
  if not Starter.Terminated then begin
    LandDemo := TLandDemo.Create;
    // Main application cycle
    while Starter.Process do LandDemo.Process;
  end;
{  except
    on E: Exception do Log(E.Message, lkFatalError);
  end;}

  // Shutdown
  FreeAndNil(LandDemo);
  FreeAndNil(Starter);
end.

