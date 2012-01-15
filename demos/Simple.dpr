(*
 CAST II Engine water demo
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 (C) 2007 George "Mirage" Bakhtadze
*)
{$I GDefines.inc}
{$I C2Defines.inc}
{$APPTYPE CONSOLE}

{$IFDEF FPC}{$IFDEF USEGLUT}
  {$DEFINE GLUT}
{$ENDIF}{$ENDIF}

program Simple;

uses
  Logger,
  OSUtils,
  AppsInit,
  {$IFDEF GLUT}
    AppsInitGLUT,
  {$ELSE}
    {$IFDEF WINDOWS}
      AppsInitWin,
    {$ENDIF}
  {$ENDIF}
  {$IFDEF DIRECT3D8} C2DX8Render, {$ENDIF}
  {$IFDEF OPENGL} C2OGLRender, {$ENDIF}
  CAST2,
  C2Core,
  SysUtils,
  Basics, Geometry,
  BaseTypes,
  BaseGraph, C22D;

var
  Core: TCore;
  Camera: TCamera;

  Starter: TAppStarter;                                        // Application starter

  Tris: TTriangles;
  Poly: T2DPointList;

procedure DrawPoly(Points: TPoints2D; Color: TColor);
var i: Integer;
begin
  if Length(Points) < 3 then Exit;

  Screen.Color := Color;

  Screen.MoveTo(Points[0].X, Points[0].Y);
  for i := 1 to High(Points) do Screen.LineTo(Points[i].X, Points[i].Y);
  Screen.LineTo(Points[0].X, Points[0].Y);
end;

procedure DrawTri(Points: TPoints2D; Tri: TTriangle; Color: TColor);
begin
  Screen.Color := Color;

  Screen.MoveTo(Tri[0].X, Tri[0].Y);
  Screen.LineTo(Tri[1].X, Tri[1].Y);
  Screen.LineTo(Tri[2].X, Tri[2].Y);
  Screen.LineTo(Tri[0].X, Tri[0].Y);
end;

var
  DrawInd: Integer = 0;

procedure DrawTris(APoints: TPoints2D; Color: TColor);
begin
//  for i := 0 to High(Tris) do DrawPoly(Tris[i], Color);
  if Random(300) = 0 then DrawInd := (DrawInd + 1) mod Length(Tris);

  DrawTri(APoints, Tris[DrawInd], Color);
end;

var
  Pnt: TPoints2D;

begin
  Log('===*** loading glut...');
  Randomize;
  //ReportMemoryLeaksOnShutdown := True;

  // Create window
  {$IFDEF GLUT}
    Starter := TGLUTAppStarter.Create('CAST II Simple Demo', [soSingleUser]);
    {$IFDEF LINUX}
      OSUtils.InitX11(0);
    {$ENDIF}
  {$ELSE}
    Starter := TWin32AppStarter.Create('CAST II Simple Demo', [soSingleUser]);
  {$ENDIF}

  Core := TCore.Create;
  Core.Root := TCASTRootItem.Create(Core);
  with TCamera.Create(nil) do Parent := Core.Root;

//  Core.MessageHandler    := HandleMessage;      // Set message handler
  Starter.MessageHandler := Core.HandleMessage; // Redirect window messages to engine

  // Create renderer
  {$IFDEF DIRECT3D8}
    Core.Renderer := TDX8Renderer.Create(Core);
    if not Core.Renderer.CreateDevice(Starter.WindowHandle, 0, False) then begin
      Starter.PrintError('Failed to initiaize render device', lkFatalError);
      Exit;
    end;
  {$ENDIF}
  {$IFDEF OPENGL}
    Core.Renderer := TOGLRenderer.Create(Core);
    if not Core.Renderer.CreateDevice(Starter.WindowHandle, 0, False) then begin
      Starter.PrintError('Failed to initiaize render device', lkFatalError);
      Exit;
    end;
  {$ENDIF}

  Core.Root := TCASTRootItem.Create(Core);
  with TCamera.Create(nil) do Parent := Core.Root;

  TC2Screen(Screen).SetCore(Core);

  Assert(ClassifyPoint(Vec2s(100, 100), Vec2s(0, 0), Vec2s(200, 50)) = ppRIGHT, 'ClassifyPoint!');

//  Poly: array[0..4] of TVector2s = ((v:(), (v:(200, 200)), (v:(300, 100)), (v:(300, 300)), (v:(100, 300)));
  SetLength(Pnt, 5+3);
  Pnt[0] := vec2s(100, 100);
  Pnt[1] := vec2s(200, 200);
  Pnt[2] := vec2s(300, 100);
  Pnt[3] := vec2s(300, 300);
  Pnt[4] := vec2s(100, 300);

  Pnt[5] := vec2s(100, 400);
  Pnt[6] := vec2s(80, 200);
  Pnt[7] := vec2s(10, 200);

  Poly := T2DPointList.Create();
  Poly.AddAll(Pnt);
  Tris := Poly.Triangulate();
  {SetLength(Tris, 1);
  Tris[0][0].X := 1;
  Tris[0][0].Y := 1;
  Tris[0][1].X := 1;
  Tris[0][1].Y := 100;
  Tris[0][2].X := 100;
  Tris[0][2].Y := 100;}


  // Check if all is OK
  while not Starter.Terminated do begin
    if Starter.Process then Core.Process();

  //    Screen.ResetViewport;
    Screen.Clear;

    DrawPoly(Pnt, GetColor($FF00FFFF));

    DrawTris(Pnt, GetColor($FFFF0000));

  end;

  Poly.Free();
  // Shutdown
  FreeAndNil(Core);
  FreeAndNil(Starter);
end.
