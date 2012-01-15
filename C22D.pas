(*
 @Abstract(CAST II Engine 2D wrapper unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains classes for rendering 2D objects through 3D device
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C22D;

interface

uses
  Logger,
  BaseTypes, BaseMsg, Basics, Base3D, BaseGraph, Props, BaseClasses, Resources,
  C2Types, C2Tess2D, C2Visual, C2Materials, CAST2, C2Core, ItemMsg;

const
  ZDecr = 0.0001;

type
  // 2D primitive kinds
  T2DPrimitiveKind = (// Solid primitive
                      pkSolid,
                      // Text
                      pkText);

  TBitmapFont = class(TBaseBitmapFont)
    procedure AddProperties(const Result: TProperties); override;
    procedure SetProperties(Properties: TProperties); override;
  protected
    procedure ResolveLinks; override;
  end;

  // 2D output implementation based on CAST II engine
  TC2Screen = class(TScreen)
  private
    CachedTetragonMesh: TTetragonMesh;
    CachedLineMesh: TLineMesh;
    CachedTextMesh: TTextMesh;

    Tech, SolidTech: TTechnique;
    Core: TCore;
    FCoreValid: Boolean;
    // Decrement Z to imitate correct primitive order
    procedure AdvanceZ(); {$I inline.inc}
  public
    constructor Create;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure Reset; override;

    // Should be called before use and after each scene cleaning or a new scene loading
    procedure SetCore(ACore: TCore);

// Draw/fill parameters
    procedure SetTechnique(PrimitiveKind: T2DPrimitiveKind; const ATech: TTechnique);
// Primitive drawing
    procedure LineTo(const X, Y: Single); override;
    procedure Bar(X1, Y1, X2, Y2: Single); override;
// Text drawing
    procedure PutText(const Str: string); override;
    procedure PutTextXY(const X, Y: Single; const Str: string); override;

    procedure Clear; override;

    // Material technique used to draw solid 2D primitives
    property SolidTechnique: TTechnique read SolidTech;
    // Material technique used to draw text
    property TextTechnique: TTechnique read Tech;
  end;

  // Returns list of classes introduced by the unit
  function GetUnitClassList: TClassArray;

implementation

function GetUnitClassList: TClassArray;
begin
  Result := GetClassList([TBitmapFont]);
end;

{ TBitmapFont }

procedure TBitmapFont.AddProperties(const Result: TProperties);
begin
  inherited;

  AddItemLink(Result, 'Bitmap',   [], 'TImageResource');
  AddItemLink(Result, 'UV map',   [], 'TUVMapResource');
  AddItemLink(Result, 'Char map', [], 'TCharMapResource');
end;

procedure TBitmapFont.SetProperties(Properties: TProperties);
begin
  inherited;

  if Properties.Valid('Bitmap')   then SetLinkProperty('Bitmap',   Properties['Bitmap']);
  if Properties.Valid('UV map')   then SetLinkProperty('UV map',   Properties['UV map']);
  if Properties.Valid('Char map') then SetLinkProperty('Char map', Properties['Char map']);

  ResolveLinks;
end;

procedure TBitmapFont.ResolveLinks;
var LinkedRes: TItem; 
begin
  inherited;
  if ResolveLink('UV map', LinkedRes) then begin
    UVMap    := (LinkedRes as TUVMapResource).Data;
    TotalUVs := (LinkedRes as TUVMapResource).TotalElements;
  end;
  if ResolveLink('Char map', LinkedRes) then begin
    CharMap         := (LinkedRes as TCharMapResource).Data;
    TotalCharacters := (LinkedRes as TCharMapResource).TotalElements;
  end;
  if ResolveLink('Bitmap', LinkedRes) then begin
    Bitmap       := (LinkedRes as TImageResource).Data;
    BitmapFormat := (LinkedRes as TImageResource).Format;
    XScale       := (LinkedRes as TImageResource).Width;
    YScale       := (LinkedRes as TImageResource).Height;
  end;
end;

{ TC2Screen }

constructor TC2Screen.Create;
begin
  inherited;
//  SolidTech := TTechnique.Create(nil);
//  SolidTech.TotalPasses := 1;
//  SolidTech.Passes[0] := TRenderPass.Create(nil);
  CachedTetragonMesh := nil;
  CachedLineMesh := nil;
  CachedTextMesh := nil;
  FCoreValid := False;
end;

procedure TC2Screen.HandleMessage(const Msg: TMessage);
begin
  inherited;

  if Msg.ClassType = TSceneClearMsg then 
    FCoreValid := False;
  if Msg.ClassType = TSceneLoadedMsg then
    SetCore(Core);
end;

procedure TC2Screen.Reset;
begin
  inherited;
  if Assigned(Core) and Assigned(Core.DefaultMaterial) and (Core.DefaultMaterial.TotalTechniques > 0) then
    SetTechnique(pkSolid, Core.DefaultMaterial.Technique[0]);
end;

const DefTechName: ShortString = 'Default_$_2D';

procedure TC2Screen.SetCore(ACore: TCore);
var Ind: Integer;
begin
  if (Core = ACore) and FCoreValid then Exit;
  
  Core := ACore;
  if Assigned(Core) and Assigned(Core.DefaultMaterial) and (Core.DefaultMaterial.TotalTechniques > 0) then begin
    FCoreValid := True;

    // Search for default technique
    Ind := Core.DefaultMaterial.TotalTechniques-1;
    while (Ind >= 0 ) and (Core.DefaultMaterial.Technique[Ind].Name <> DefTechName) do Dec(Ind);
    // Create one of not exists
    if Ind < 0 then begin
      Ind := Core.DefaultMaterial.TotalTechniques;

      Core.DefaultMaterial.TotalTechniques := Ind + 1;
      
      Core.DefaultMaterial.Technique[Ind] := TTechnique.Create(Core);
      Core.DefaultMaterial.Technique[Ind].Name := DefTechName;
      Core.DefaultMaterial.Technique[Ind].Parent := Core.DefaultMaterial;
      Core.DefaultMaterial.Technique[Ind].TotalPasses := 1;
      Core.DefaultMaterial.Technique[Ind].Valid := True;
      Core.DefaultMaterial.Technique[Ind].Passes[0] := TRenderPass.Create(Core);
      Core.DefaultMaterial.Technique[Ind].Passes[0].Name := 'Default 2D pass';
      Core.DefaultMaterial.Technique[Ind].Passes[0].Parent := Core.DefaultMaterial.Technique[Ind];
      Core.DefaultMaterial.Technique[Ind].Passes[0].Group         := 0;
      Core.DefaultMaterial.Technique[Ind].Passes[0].BlendingState := GetBlendingState(True, bmSRCALPHA, bmINVSRCALPHA, 0, tfGREATER, boADD);
      Core.DefaultMaterial.Technique[Ind].Passes[0].ZBufferState  := GetZBufferState(False, tfLESSEQUAL, 0);
      Core.DefaultMaterial.Technique[Ind].Passes[0].Order         := poPostProcess;
      Core.DefaultMaterial.Technique[Ind].Passes[0].LightingState := GetLightingState(slNONE, False, False, GetColor($40404040));
      Core.DefaultMaterial.Technique[Ind].Passes[0].FillShadeMode := GetFillShadeMode(fmSOLID, smGOURAUD, cmNONE, $FFFFFFFF);
      Core.DefaultMaterial.Technique[Ind].Passes[0].FogKind       := fkNone;
      Core.DefaultMaterial.Technique[Ind].Passes[0].TotalStages   := 1;
      Core.DefaultMaterial.Technique[Ind].Passes[0].Stages[0].ColorArg0 := taDIFFUSE;
      Core.DefaultMaterial.Technique[Ind].Passes[0].Stages[0].ColorOp := toARG2;
      Core.DefaultMaterial.Technique[Ind].Passes[0].State := Core.DefaultMaterial.Technique[Ind].Passes[0].State + [isVisible];
    end;

    SetTechnique(pkSolid, Core.DefaultMaterial.Technique[Ind]);
    SetTechnique(pkText,  Core.DefaultMaterial.Technique[Ind]);
  end else FCoreValid := False;
end;

procedure TC2Screen.SetTechnique(PrimitiveKind: T2DPrimitiveKind; const ATech: TTechnique);
begin
  Assert(FCoreValid, 'TC2Screen.SetCore should be called before use');
  if ATech <> nil then begin
    case PrimitiveKind of
      pkSolid: begin
        SolidTech := ATech;
        CachedTetragonMesh := TTetragonMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TTetragonMesh, SolidTech]);
        CachedLineMesh     := TLineMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TLineMesh, SolidTech]);
      end;
      pkText: begin
        Tech := ATech;
        CachedTextMesh     := TTextMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TTextMesh, Tech]);
      end;
    end;
  end else
    Log(ClassName + '.SetTechnique: Parameter is nil', lkError);
end;

procedure TC2Screen.LineTo(const X, Y: Single);
var Mesh: TLineMesh;
begin
  Assert(FCoreValid, 'TC2Screen.SetCore should be called before use');
  Assert(Assigned(SolidTech), ClassName + '.LineTo: Solid technique is undefined');
  Assert(Assigned(CachedLineMesh));

//  Mesh := TLineMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TLineMesh, SolidTech]);
  Mesh := CachedLineMesh;

  Mesh.AddPoint(CurrentX, CurrentY, Color);

  MoveTo(X, Y);
  Mesh.AddPoint(CurrentX, CurrentY, Color);

  AdvanceZ();
end;

procedure TC2Screen.AdvanceZ;
begin
  CurrentZ := CurrentZ - ZDecr;
  {$IFDEF DEBUG}
  if CurrentZ < 0 then begin
    CurrentZ := ClearingZ;
    Log('TC2Screen.AdvanceZ: Z overflow', lkError);
  end;
  {$ENDIF}
end;

procedure TC2Screen.Bar(X1, Y1, X2, Y2: Single);
begin
  Assert(FCoreValid, 'TC2Screen.SetCore should be called before use');
  Assert(Assigned(SolidTech), ClassName + '.Bar: Solid technique is undefined');
  Assert(Assigned(CachedTetragonMesh));

//  if X1 > X2 then begin X := X2; X2 := X1; X1 := X; end;
//  if Y1 > Y2 then begin Y := Y2; Y2 := Y1; Y1 := Y; end;

//  Mesh := TTetragonMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TTetragonMesh, SolidTech]);

//  Mesh := CachedTetragonMesh;

  CachedTetragonMesh.AddCorner(X1, Y1, UV.U,        UV.V,        Color);
  CachedTetragonMesh.AddCorner(X2, Y2, UV.U + UV.W, UV.V + UV.H, Color);

  AdvanceZ();
end;

procedure TC2Screen.PutText(const Str: string);
var Mesh: TTextMesh; TX, TY: Single;
begin
  Assert(FCoreValid, 'TC2Screen.SetCore should be called before use');
  Assert(Tech <> nil, ClassName + '.DrawFormattedText: Technique is undefined');
  Assert(Assigned(CachedTextMesh));

  if not (Font is TBitmapFont) or (TBitmapFont(Font).TotalUVs = 0) then Exit;
  if Str = '' then Exit;

//  Mesh := TTextMesh((Core.SharedTesselators as TSharedTesselators).Tesselator[TTextMesh, Tech]);
  Mesh := CachedTextMesh;

  Mesh.SetFont(Font, 1, 1);

  Mesh.AddText(CurrentX, CurrentY, Color, Str);
  Font.GetTextExtent(Str, TX, TY);
  MoveTo(LocalX + TX, LocalY);

  AdvanceZ();
end;

procedure TC2Screen.PutTextXY(const X, Y: Single; const Str: string);
begin
  MoveTo(X, Y);
  PutText(Str);
end;

procedure TC2Screen.Clear;
begin
  inherited;
//  if (Core <> nil) and (Core.Renderer <> nil) then Core.Renderer.Clear(False, True, False, 0, ClearingZ, 0);
  CurrentZ := ClearingZ;
end;

initialization
  if Screen <> nil then Screen.Free;
  Screen := TC2Screen.Create;
  GlobalClassList.Add('C22D', GetUnitClassList);
finalization
  if Screen <> nil then begin
    if Screen is TC2Screen then (Screen as TC2Screen).Core := nil;         // Core should be freed here
    Screen.Free;
  end;
end.
