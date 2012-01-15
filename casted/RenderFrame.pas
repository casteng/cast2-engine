{$I GDefines.inc}
{$I C2Defines.inc}
unit RenderFrame;

interface

uses
   Logger, 
  C2Render,
  C2EdMain,
  {$IFDEF DIRECT3D8} C2DX8Render, {$ENDIF}
  {$IFDEF OPENGL} C2OGLRender, {$ENDIF}
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls;

type
  TRendererFrame = class(TFrame)
    RenderPanel: TPanel;
    procedure InitRender;
  end;

  implementation

uses MainForm;

{$R *.dfm}

{ TFrame1 }

procedure TRendererFrame.InitRender;
begin
  ControlStyle := ControlStyle + [csOpaque];
  RenderPanel.ControlStyle := RenderPanel.ControlStyle + [csOpaque];

  {$IFDEF DIRECT3D8} Core.Renderer := TDX8Renderer.Create(Core); {$ENDIF}
  {$IFDEF OPENGL} Core.Renderer := TOGLRenderer.Create(Core); {$ENDIF}

  if App.Config.GetAsInteger('Render\SoftwareVP') = 1 then begin
    Core.Renderer.AppRequirements.HWAccelerationLevel := haSoftwareVP;                      // Necessary for .X loader even if it creates its own device
    Log(ClassName + '.Initrender: software vertex processing specified in config', lkWarning);
  end else
    Core.Renderer.AppRequirements.HWAccelerationLevel := haPureDevice;
//
  Include(Core.Renderer.AppRequirements.Flags, arPreserveFPU);

  Core.Renderer.CreateDevice(RenderPanel.Handle, 1+0*Core.Renderer.TotalVideoModes-1, False);
  Core.Renderer.InitDebugRender(Core.DefaultMaterial);
  Core.Renderer.DebugOutput := True;
end;

end.
