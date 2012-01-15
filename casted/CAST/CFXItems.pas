{$Include GDefines}
{$Include CDefines}
unit CFXItems;

interface

uses Basics, Base3D, CTypes, CAST, CFX, CParticle, CMiscItems;

const
  emAlpha = 0; emColor = 1; emBrightness = 2;

type
  TFXExplosion = class(TItem)
    ExplosionSize: Single;
    OuterForce: TVector3s;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure Init(const Ready: Boolean); virtual;
    function SetChild(Index: Integer; AItem: TItem): TItem; override;
    function DeleteChild(AItem: TItem): Integer; override;
    function GetProperties: TProperties; override;
    function SetProperties(AProperties: TProperties): Integer; override;
    function Process: Boolean; override;
  protected
    LifeTime, MaxLifeTime, ShockwaveTime, ShockwaveDelay, FlareTime, FlareDelay: Integer;
    SmokeElevation, CoreElevation, SmokeStartY, CoreStartY: Single;
    CoreEmitDelay, CoreEmitAmount, CoreEmitDuration,
    SmokeEmitDelay, SmokeEmitAmount, SmokeEmitDuration: Integer;
    Shockwave: TPlane;
    ShockwaveBright, FlareBright, FlareWidth, FlareHeight: Integer;
    ShockwaveColor, FlareColor, LightColor: Longword;
    Flare: TBillboard;
    Core, Smoke: TParticleSystem;
  end;

  TComplexFireworks = class(TItem)
    RandomAngle, RandomOrder: Boolean;
    TotalLaunched, Quantity, LaunchDelay: Integer;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Process: Boolean; override;
    procedure LaunchNext; virtual;
    procedure Start; virtual;
  private
    Counter, Current: Integer;
  end;

  TTextEmitter = record
    X, Y: Single;
  end;

  TParticleText = class(T2DParticleSystem)
    Density: Integer;                      // How many particles used
    EmitMode: Integer;                     // Emit location -1 - upper border, 0 - entire, 1 - bottom border
    ExtractMode: Integer;                  // Value extraction mode
    Tolerance: Longword;
    SpeedJitter, RadiusJitter, Elevation, Frequency: Single;
    AlignMode: Integer;                    // Text alignment mode
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); override;
    procedure SetBitmap(ResIndex: Integer);
    procedure SetText(const AText: string); virtual;
    procedure SetTextRes(const ATextRes: Integer); virtual;
    function SetProperties(AProperties: TProperties): Integer; override;
    function GetProperties: TProperties; override;
    function Emit(Count: Single): Integer; override;
    procedure ExtractParticles;
    function Process: Boolean; override;
  protected
    Bitmap, CnvBitmap: PImageBuffer;
    BMPWidth, BMPHeight: Integer;
    UVMap: TUVMap;
    CharMap: TCharMap;
    BMPRes, TextRes, FontRes, CharMapRes: Integer;
    FText: string;                         // Text property, text to render and cleared text
    Emitters: array of TTextEmitter;       // Places where the particles are emitting
    TotalEmitters: Integer;                // Number of potential emitters
    TextWidth: Single;
  published
    property Text: string read FText write SetText;
  end;

implementation

uses CRes, Adv2D;

{ TFXExplosion }

constructor TFXExplosion.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  inherited;
  SmokeEmitDelay := 1;
  LightColor := $FF808080;
  ExplosionSize := 1000;
  MaxLifeTime := 6;
  LifeTime := MaxLifeTime;
  Init(False);
end;

procedure TFXExplosion.Init(const Ready: Boolean);                   // if ready launch explosion process
var i: Integer;
begin
  if Ready then begin
    if (Shockwave <> nil) then if (MaxLifeTime-LifeTime < ShockwaveTime) then begin
      Shockwave.SetScale(GetVector3s(0, 0, 0));
      Shockwave.Color := ShockwaveColor;
    end;
  end;

  Shockwave := GetChildByName('Shockwave', True) as TPlane;
  if Shockwave <> nil then begin
    ShockwaveColor := ShockWave.Color; ShockWaveBright := (ShockwaveColor shr 24) and $FF;
  end;

  Flare := GetChildByName('Flare', True) as TBillboard;
  if Flare <> nil then begin
    FlareColor := Flare.Color; FlareBright := (FlareColor shr 24) and $FF;
    FlareWidth := Flare.Width; FlareHeight := Flare.Height;
  end;

  Core := GetChildByName('Core', True) as TParticleSystem;
  Smoke := GetChildByName('Smoke', True) as TParticleSystem;

  if Ready then begin
    Status := Status or isProcessing;
    if Core <> nil then begin
      Core.SetLocation(GetVector3s(0, CoreStartY, 0));
      Core.OuterForce := OuterForce;
    end;
    if Smoke <> nil then begin
      Smoke.SetLocation(GetVector3s(0, SmokeStartY, 0));
      Smoke.OuterForce := OuterForce;
    end;  
  end else Status := Status and not isProcessing;

  if ShockWave <> nil then ShockWave.Hide;
  if Flare <> nil then Flare.Hide;

{  if Ready then if Assigned(World) and Assigned(World.Landscape) and Assigned(World.Landscape.HeightMap) then
   if Location.Y > -World.Landscape.HeightMap.BreakHeight then
    World.Landscape.MakeCrater(Location.X, Location.Z,
     Trunc(0.5 + ExplosionSize - MaxS(0, (Location.Y - World.Landscape.HeightMap.GetHeight(Location.X, Location.Z)))));}

  for i := 0 to TotalChilds-1 do if Childs[i] is TParticleSystem then Childs[i].Init;   
end;

function TFXExplosion.DeleteChild(AItem: TItem): Integer;
begin
  Result := inherited DeleteChild(AItem);
  Init(False);
end;

function TFXExplosion.SetChild(Index: Integer; AItem: TItem): TItem;
begin
  Result := inherited SetChild(Index, AItem);
  if Index = TotalChilds-1 then Init(False);
end;

function TFXExplosion.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Core emit delay', ptInt32, Pointer(CoreEmitDelay));
  NewProperty(Result, 'Core emit amount', ptInt32, Pointer(CoreEmitAmount));
  NewProperty(Result, 'Core emit duration', ptInt32, Pointer(CoreEmitDuration));
  NewProperty(Result, 'Core elevation', ptSingle, Pointer(Self.CoreElevation));
  NewProperty(Result, 'Core start Y', ptSingle, Pointer(CoreStartY));
  NewProperty(Result, 'Smoke elevation', ptSingle, Pointer(SmokeElevation));
  NewProperty(Result, 'Smoke start Y', ptSingle, Pointer(SmokeStartY));
  NewProperty(Result, 'Smoke emit amount', ptInt32, Pointer(SmokeEmitAmount));
  NewProperty(Result, 'Smoke emit duration', ptInt32, Pointer(SmokeEmitDuration));
  NewProperty(Result, 'Smoke delay', ptInt32, Pointer(SmokeEmitDelay));
  NewProperty(Result, 'Explosion size', ptSingle, Pointer(ExplosionSize));
  NewProperty(Result, 'Life time', ptInt32, Pointer(MaxLifeTime));
  NewProperty(Result, 'Shockwave delay', ptInt32, Pointer(ShockwaveDelay));
  NewProperty(Result, 'Shockwave duration', ptInt32, Pointer(ShockwaveTime));
  NewProperty(Result, 'Flare delay', ptInt32, Pointer(FlareDelay));
  NewProperty(Result, 'Flare duration', ptInt32, Pointer(FlareTime));
  NewProperty(Result, 'Light source color', ptColor32, Pointer(LightColor));
end;

function TFXExplosion.SetProperties(AProperties: TProperties): Integer;
begin
  Result := 0;
  if inherited SetProperties(AProperties) < 0 then Exit;

  CoreEmitDelay := Integer(GetPropertyValue(AProperties, 'Core emit delay'));
  CoreEmitAmount := Integer(GetPropertyValue(AProperties, 'Core emit amount'));
  CoreEmitDuration := Integer(GetPropertyValue(AProperties, 'Core emit duration'));
  Self.CoreElevation := Single(GetPropertyValue(AProperties, 'Core elevation'));
  CoreStartY := Single(GetPropertyValue(AProperties, 'Core start Y'));

  SmokeElevation := Single(GetPropertyValue(AProperties, 'Smoke elevation'));
  SmokeStartY := Single(GetPropertyValue(AProperties, 'Smoke start Y'));
  SmokeEmitAmount := Integer(GetPropertyValue(AProperties, 'Smoke emit amount'));
  SmokeEmitDuration := Integer(GetPropertyValue(AProperties, 'Smoke emit duration'));
  SmokeEmitDelay := Integer(GetPropertyValue(AProperties, 'Smoke delay'));
  ExplosionSize := Single(GetPropertyValue(AProperties, 'Explosion size'));
  MaxLifeTime := Integer(GetPropertyValue(AProperties, 'Life time'));

  ShockwaveTime := Integer(GetPropertyValue(AProperties, 'Shockwave duration'));
  ShockwaveDelay := Integer(GetPropertyValue(AProperties, 'Shockwave delay'));
  FlareTime := Integer(GetPropertyValue(AProperties, 'Flare duration'));
  FlareDelay := Integer(GetPropertyValue(AProperties, 'Flare delay'));
  LightColor := Longword(GetPropertyValue(AProperties, 'Light source color'));

//  if Assigned(DebrisFountain) then TPSFountain(DebrisFountain).Emit(DebrisIntencity);
  if Core <> nil then begin
    Core.SetLocation(GetVector3s(Core.Location.X, CoreStartY, Core.Location.Z));
    Core.Init;
  end;
  Init((TotalChilds = 0) or (Childs[0] <> nil));

  LifeTime := MaxLifeTime;
end;

function TFXExplosion.Process: Boolean;
var arg: Single;
begin
  Result := inherited Process;

  if (MaxLifeTime-LifeTime = SmokeEmitDelay + SmokeEmitDuration div 2) then if Assigned(World) and Assigned(World.Landscape) and Assigned(World.Landscape.HeightMap) then
   if Location.Y > -World.Landscape.HeightMap.BreakHeight then
    World.Landscape.MakeCrater(Location.X, Location.Z,
     Trunc(0.5 + ExplosionSize - MaxS(0, (Location.Y - World.Landscape.HeightMap.GetHeight(Location.X, Location.Z)))));

  if (MaxLifeTime-LifeTime >= CoreEmitDelay) and (MaxLifeTime-LifeTime < CoreEmitDuration + CoreEmitDelay) then begin
    Core.Emit(CoreEmitAmount);
    Core.SetLocation(GetVector3s(Core.Location.X, CoreStartY + CoreElevation*(MaxLifeTime-LifeTime-CoreEmitDelay), Core.Location.Z));
  end;

  if (MaxLifeTime-LifeTime >= SmokeEmitDelay) and (MaxLifeTime-LifeTime < SmokeEmitDuration + SmokeEmitDelay) then begin
    Smoke.Emit(SmokeEmitAmount);
    Smoke.SetLocation(GetVector3s(Smoke.Location.X, SmokeStartY + SmokeElevation*(MaxLifeTime-LifeTime-SmokeEmitDelay), Smoke.Location.Z));
  end;

  if ShockWave <> nil then if (MaxLifeTime-LifeTime = ShockwaveTime + ShockwaveDelay) then begin
    Shockwave.SetScale(GetVector3s(1, 1, 1));
    Shockwave.Color := ShockwaveColor;
    Shockwave.Hide;
  end else if (Shockwave.Status and isProcessing > 0) and (MaxLifeTime-LifeTime > ShockwaveDelay) and (MaxLifeTime-LifeTime < ShockwaveTime+ShockwaveDelay) then begin
    arg := Sin(MaxS(0, (MaxLifeTime-LifeTime-ShockwaveDelay) / ShockwaveTime * pi/2));
//    Shockwave := Childs[TotalChilds-1] as TBillboard;
    Shockwave.SetScale(GetVector3s(arg, arg, arg));
    Shockwave.Color := Shockwave.Color and $FFFFFF or Round((1-arg)*ShockwaveBright) shl 24;
    ShockWave.Show;
  end;

  if Flare <> nil then if (MaxLifeTime-LifeTime = FlareTime + FlareDelay) then begin
    Flare.SetDimensions(FlareWidth, FlareHeight);
    Flare.SetColor(FlareColor);
    Flare.Hide;
  end else if (Flare.Status and isProcessing > 0) and (MaxLifeTime-LifeTime > FlareDelay) and (MaxLifeTime-LifeTime < FlareDelay + FlareTime) then begin
    arg := Sin(MaxS(0, (MaxLifeTime-LifeTime-FlareDelay) / FlareTime * pi/2));
//    Shockwave := Childs[TotalChilds-1] as TBillboard;
    Flare.SetDimensions(Trunc(0.5 + FlareWidth * arg), Trunc(0.5 + FlareHeight * arg));
    Flare.SetColor(Flare.Color and $FFFFFF or Round((1-arg)*FlareBright) shl 24);
    Flare.Show;
  end;

  if LifeTime > 0 then Dec(LifeTime) else begin
    Smoke.SetLocation(GetVector3s(Smoke.Location.X, SmokeStartY, Smoke.Location.Z));
    Core.SetLocation(GetVector3s(Core.Location.X, CoreStartY, Core.Location.Z));
    Smoke.Init; Core.Init;
    if not World.EditorMode then World.AddToKillList(Self, True);
  end;
end;

{ TComplexFireworks }

function TComplexFireworks.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Quantity', ptInt32, Pointer(Quantity));
  NewProperty(Result, 'Launch delay', ptInt32, Pointer(LaunchDelay));
  NewProperty(Result, 'Random angle', ptBoolean, Pointer(RandomAngle));
  NewProperty(Result, 'Random order', ptBoolean, Pointer(RandomOrder));
end;

function TComplexFireworks.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;
  Quantity := Integer(GetPropertyValue(AProperties, 'Quantity'));
  LaunchDelay := Integer(GetPropertyValue(AProperties, 'Launch delay'));
  RandomAngle := Boolean(GetPropertyValue(AProperties, 'Random angle'));
  RandomOrder := Boolean(GetPropertyValue(AProperties, 'Random order'));

  if World.EditorMode then Start else TotalLaunched := Quantity;

  Result := 0;
end;

function TComplexFireworks.Process: Boolean;
begin
  Result := inherited Process;
  if (Quantity <> 0) and (TotalLaunched >= Quantity) then Exit;
  if Counter > 0 then Dec(Counter) else LaunchNext;
end;

procedure TComplexFireworks.LaunchNext;
var Item: T2DFireworks; Attempts: Integer;
begin
  Counter := LaunchDelay; Inc(TotalLaunched);
  for Attempts := 1 to TotalChilds do begin
    if RandomOrder then Current := Random(TotalChilds) else
     if Current < TotalChilds-1 then Inc(Current) else Current := 0;
    if Childs[Current] is T2DFireworks then begin
      Item := Childs[Current] as T2DFireworks;
      Break;
    end;
  end;
  if Item = nil then Exit;
  if RandomAngle then Item.LaunchAngle := Random*2*pi;
  Item.Start;
  Item.Status := Item.Status or isPauseProcessing or isProcessing;
end;

procedure TComplexFireworks.Start;
begin
  TotalLaunched := 0; Current := 0;
  LaunchNext;
end;

{ TParticleText }

constructor TParticleText.Create(AName: TShortName; AWorld: TWorld; AParent: TItem);
begin
  CnvBitmap := nil;
  inherited;
end;

procedure TParticleText.SetBitmap(ResIndex: Integer);
begin
  if not (World.ResourceManager.Resources[ResIndex] is TImageResource) then Exit;
  BMPRes := ResIndex;

  BmpWidth := TImageResource(World.ResourceManager.Resources[ResIndex]).Width;
  BmpHeight := TImageResource(World.ResourceManager.Resources[ResIndex]).Height;

  if World.ResourceManager.Resources[ResIndex].Format = pfA8R8G8B8 then
   Bitmap := World.ResourceManager.Resources[ResIndex].Data else begin
     if CnvBitmap <> nil then FreeMem(CnvBitmap);
     GetMem(CnvBitmap, BmpWidth * BmpHeight * 4);
     ConvertImage(World.ResourceManager.Resources[ResIndex].Format, pfA8R8G8B8, BmpWidth * BmpHeight,
                  World.ResourceManager.Resources[ResIndex].Data, 0, nil, CnvBitmap);
     Bitmap := CnvBitmap;
   end;
end;

procedure TParticleText.SetText(const AText: string);
begin
  FText := AText;
//  KillAll;
end;

procedure TParticleText.SetTextRes(const ATextRes: Integer);
begin
  TextRes := ATextRes;
  if (TextRes = -1) or (TextRes >= World.ResourceManager.TotalResources) or not (World.ResourceManager[TextRes] is TTextResource) then
   SetText('') else
    SetText(TTextResource(World.ResourceManager[TextRes]).GetText);
end;

function TParticleText.GetProperties: TProperties;
begin
  Result := inherited GetProperties;
  NewProperty(Result, 'Density', ptInt32, Pointer(Density));
  NewProperty(Result, 'Emit mode', ptInt32, Pointer(EmitMode));
  NewProperty(Result, 'Extract mode', ptInt32, Pointer(ExtractMode));
  NewProperty(Result, 'Tolerance', ptNat32, Pointer(Tolerance));

  NewProperty(Result, 'Speed jitter', ptSingle, Pointer(SpeedJitter));
  NewProperty(Result, 'Radius jitter', ptSingle, Pointer(RadiusJitter));
  NewProperty(Result, 'Elevation', ptSingle, Pointer(Elevation));
  NewProperty(Result, 'Frequency', ptSingle, Pointer(Frequency));

  NewProperty(Result, 'Align mode', ptInt32, Pointer(AlignMode));

  NewProperty(Result, 'Text', ptResource + World.ResourceManager.GetResourceClassIndex('TTextResource') shl 8, Pointer(TextRes));
  NewProperty(Result, 'Font', ptGroupBegin, nil);
    NewProperty(Result, 'Bitmap', ptResource + World.ResourceManager.GetResourceClassIndex('TImageResource') shl 8, Pointer(BMPRes));
    NewProperty(Result, 'UVMap', ptResource + World.ResourceManager.GetResourceClassIndex('TFontResource') shl 8, Pointer(FontRes));
    NewProperty(Result, 'Characters mapping', ptResource + World.ResourceManager.GetResourceClassIndex('TCharMapResource') shl 8, Pointer(CharMapRes));
  NewProperty(Result, '', ptGroupEnd, nil);
end;

function TParticleText.SetProperties(AProperties: TProperties): Integer;
begin
  Result := -1;
  if inherited SetProperties(AProperties) < 0 then Exit;

  Density := Integer(GetPropertyValue(AProperties, 'Density'));
  EmitMode := Integer(GetPropertyValue(AProperties, 'Emit mode'));
  ExtractMode := Integer(GetPropertyValue(AProperties, 'Extract mode'));
  Tolerance := Longword(GetPropertyValue(AProperties, 'Tolerance'));

  SpeedJitter := Single(GetPropertyValue(AProperties, 'Speed jitter'));
  RadiusJitter := Single(GetPropertyValue(AProperties, 'Radius jitter'));
  Elevation := Single(GetPropertyValue(AProperties, 'Elevation'));
  Frequency := Single(GetPropertyValue(AProperties, 'Frequency'));

  AlignMode := Integer(GetPropertyValue(AProperties, 'Align mode'));

  FontRes := Integer(GetPropertyValue(AProperties, 'UVMap'));
  CharMapRes := Integer(GetPropertyValue(AProperties, 'Characters mapping'));

  if (FontRes >= 0) and (FontRes < World.ResourceManager.TotalResources) and (World.ResourceManager[FontRes] is TArrayResource) then
   UVMap := TUVMap(World.ResourceManager[FontRes].Data);
  if (CharMapRes >= 0) and (CharMapRes < World.ResourceManager.TotalResources) and (World.ResourceManager[CharMapRes] is TArrayResource) then
   CharMap := TCharMap(World.ResourceManager[CharMapRes].Data);

  SetTextRes(Integer(GetPropertyValue(AProperties, 'Text')));

  SetBitmap(Integer(GetPropertyValue(AProperties, 'Bitmap', Pointer(-1))));

  ExtractParticles;

  Result := 0;
end;

procedure TParticleText.ExtractParticles;
var i, iu, iv, VStep: Integer; UV: TUV; u, v: Single; Value: Longword;
begin
  if (UVMap = nil) or (CharMap = nil) or (Text = '') then Exit;
  TotalEmitters := 0;
  TextWidth := 0;
  for i := 0 to Length(FText)-1 do begin
    UV := UVMap[CharMap[Ord(Text[i+1])]];
// Scan character bitmap for first opaque pixel in each column and add its coordinates to emitters array
    u := 0;
    while u < UV.W * BMPWidth do begin
      if EmitMode = 1 then begin
        v := UV.H * BMPHeight; VStep := -1;
      end else begin
        v := 0 + epsilon; VStep := 1;
      end;
      while (v > 0) and (v < UV.H * BMPHeight - epsilon) do begin
        iu := MinI(BMPWidth-1, MaxI(0, Trunc(0.5 + UV.U * BMPWidth + U)));
        iv := MinI(BMPHeight-1, MaxI(0, Trunc(0.5 + UV.V * BMPHeight + V)));
        case ExtractMode of
          emAlpha: Value := Bitmap[iv * BMPWidth + iu] shr 24;
          emColor: Value := MaxI(MaxI((Bitmap[iv * BMPWidth + iu] shr 16) and $FF, (Bitmap[iv * BMPWidth + iu] shr 8) and $FF), Bitmap[iv * BMPWidth + iu] and $FF);
          emBrightness: Value := MinI(MinI((Bitmap[iv * BMPWidth + iu] shr 16) and $FF, (Bitmap[iv * BMPWidth + iu] shr 8) and $FF), Bitmap[iv * BMPWidth + iu] and $FF);
        end;
        if Value > Tolerance then begin         // Opaque pixel found
          Inc(TotalEmitters); SetLength(Emitters, TotalEmitters);
          Emitters[TotalEmitters-1].X := TextWidth + u * Scale.X;
          Emitters[TotalEmitters-1].Y := - v * Scale.Y;
          if EmitMode <> 0 then Break;
        end;
        v := v + VStep;
      end;
      u := u + 1;
    end;

    TextWidth := TextWidth + UV.W * BMPWidth * Scale.X;
  end;
end;

function TParticleText.Emit(Count: Single): Integer;
var i, Ind: Integer; PMesh: TParticlesMesh; X, AlignAdjust: Single;
begin
  Result := inherited Emit(Count);

  if TotalEmitters = 0 then Exit;

  PMesh := TParticlesMesh(CurrentLOD);

  case AlignMode of
    amLeft: begin X := Location.X; AlignAdjust := 0; end;
    amCenter: begin X := World.Renderer.RenderPars.ActualWidth*0.5 + Location.X; AlignAdjust := -TextWidth*0.5; end;
    amRight: begin X := World.Renderer.RenderPars.ActualWidth + Location.X; ; AlignAdjust := -TextWidth; end;
  end;

  for i := PMesh.TotalParticles-Result to PMesh.TotalParticles-1 do with PMesh.Particles[i] do begin
    Ind := Random(TotalEmitters);
    Velocity := GetVector3s((Random-0.5)*SpeedJitter, 0, 0);
    Position := GetVector3s(X + Emitters[Ind].X + AlignAdjust, Emitters[Ind].Y - Location.Y, 0);
    Radius := DefaultRadius * (0.5 + Random * RadiusJitter);
    Color := (DefaultColor and $FFFFFF) or $1 shl 24;
  end;

  UpdateMesh;
end;

function TParticleText.Process: Boolean;
var i, a, da: Integer;
begin
  da := (DefaultColor shr 24) and $FF;
  with TParticlesMesh(CurrentLOD) do for i := TotalParticles-1 downto 0 do with Particles[i] do begin
//    a := MinI(255, Trunc(1.5 + Particles[i].Age/Particles[i].LifeTime*(DefaultColor shr 24)));
//    ScaleVector3s(Particles[i].Velocity, Particles[i].Velocity, 1.01);
    Particles[i].Velocity.x := SIN(Frequency * Particles[i].Age/Particles[i].LifeTime*pi)*Random*SpeedJitter;
    Particles[i].Velocity.y := Particles[i].Velocity.y + Elevation*Random;
    if Particles[i].Age < 8 then
     a := (1+Particles[i].Age)*da div 8 else
      a := da - (Particles[i].Age-8) * da div (Particles[i].LifeTime-8);
//    if a < 0 then a := 0;
//    if a > 255 then a := 255;
    Particles[i].Color := (DefaultColor AND $0FFFFFF) OR (Longword(a) shl 24);
  end;
  ParticlesToEmit := Density;
  Result := inherited Process;
end;

end.
