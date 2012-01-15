{$Include GDefines}
{$Include CDefines}
unit CParticle;

interface

uses CTypes, Basics, Base3D, Cast, CTess, CRender, SysUtils, Windows;

type
  TParticle = packed record
    Position, Velosity: TVector3s;
    Radius, Mass: Single;
    Color, Age, LifeTime: Longword;
  end;

  TParticlesMesh = class(TTesselator)
    Particles: array of TParticle;
    TotalParticles: Integer;
    Capacity: Cardinal;
    GlobalForce: TVector3s;
    constructor Create(AStream: Cardinal); virtual;
    procedure Emit(Count: Integer); virtual;
    procedure Kill(Index: Integer); virtual;
    procedure Process; virtual;
    function Tesselate(RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    destructor Free;
  end;
  TParticleSystem = class(TItem)
//    function Process: Boolean; override;
  end;

implementation

{ TParticlesMesh }

constructor TParticlesMesh.Create(AStream: Cardinal);
begin
  Status := tsChanged;
  TotalIndices := 0; LastTotalIndices := 0; LastTotalVertices := 0; TotalStrips := 1; StripOffset := 0;
  IBOffset := 0; VBOffset := 0;
  FillMode := fmDefault;
  Stream := AStream;

  PrimitiveType := CPTypes[ptTRIANGLELIST];;
  VertexFormat := GetVertexFormat(True, False, True, False, 0);
  VertexSize := (3 + VertexFormat and 1 + (VertexFormat shr 1) and 1 * 3 + (VertexFormat shr 2) and 1 + (VertexFormat shr 3) and 1 + (VertexFormat shr 8) and 255 * 2) shl 2;
  AddTextureStageAlpha(nil, toArg2, taTexture, taDiffuse, toArg2, taTexture, taDiffuse, taClamp);
  
  Capacity := 10000;
  SetLength(Particles, Capacity);
  TotalParticles := 0;
  GlobalForce := GetVector3s(0, 0.1, 0);
end;

function TParticlesMesh.Tesselate(RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
type TPVertex = TTCDVertex; TPVertexBuffer = array[0..$FFFFFF] of TPVertex;
var i: Integer; VBuf: ^TPVertexBuffer;
begin
  VBuf := VBPTR;
  for i := 0 to TotalParticles-1 do with Particles[i] do begin
    with VBuf^[i*4] do begin
      X := Position.X - Radius; Y := Position.Y - Radius; Z := 0.01;
      RHW := 1; DColor := Color;
    end;
    with VBuf^[i*4+1] do begin
      X := Position.X + Radius; Y := Position.Y - Radius; Z := 0.01;
      RHW := 1; DColor := Color;
    end;
    with VBuf^[i*4+2] do begin
      X := Position.X + Radius; Y := Position.Y + Radius; Z := 0.01;
      RHW := 1; DColor := Color;
    end;
    with VBuf^[i*4+3] do begin
      X := Position.X - Radius; Y := Position.Y + Radius; Z := 0.01;
      RHW := 1; DColor := Color;
    end;
  end;
  TotalVertices := TotalParticles*4; TotalPrimitives := TotalParticles*2;
  Result := TotalVertices;
end;

function TParticlesMesh.SetIndices(IBPTR: Pointer): Integer;
var i: Integer; IBuf: ^TWordBuffer;
begin
  IBuf := IBPTR;
  for i := 0 to TotalParticles-1 do begin
    IBuf^[i*6] := i*4; IBuf^[i*6+1] := i*4+1; IBuf^[i*6+2] := i*4+2;
    IBuf^[i*6+3] := i*4; IBuf^[i*6+4] := i*4+2; IBuf^[i*6+5] := i*4+3;
  end;
  TotalIndices := TotalParticles*6;
  Result := TotalIndices;
end;

procedure TParticlesMesh.Process;
var i, TotalKilled: Integer;
begin
  TotalKilled := 0;
  for i := TotalParticles-1 downto 0 do begin
    Particles[i].Position := AddVector3s(Particles[i].Position, Particles[i].Velosity);
    Particles[i].Velosity := AddVector3s(Particles[i].Velosity, GlobalForce);
    if (Particles[i].Position.Y > 600) and (Particles[i].Velosity.Y > 0) then begin
      Kill(i); Inc(TotalKilled);
    end;
  end;
  Emit(TotalKilled);
end;

procedure TParticlesMesh.Emit(Count: Integer);
var i, OldTP: Integer; Col: Integer;
begin
  OldTP := TotalParticles;
  TotalParticles := MinI(Capacity, TotalParticles + Count);
  for i := OldTP to TotalParticles-1 do with Particles[i] do begin
    Position := GetVector3s(300, 600, 0);
    Velosity := GetVector3s((random-0.5)*4, -5-random*10, 0);
    Radius := 1+Random(2);
    Mass := 1;
    Col := Random(256);
    Color := $40FF0000 + MinI(255, Col)*$100 + Col shr 1;
    //$40000000+Random($01)*$1000000+$FFFFFF;
    Age := 0;
    LifeTime := 1000;
  end;
  TotalVertices := TotalParticles*4; TotalPrimitives := TotalParticles*2;
  TotalIndices := TotalParticles*6;
end;

procedure TParticlesMesh.Kill(Index: Integer);
begin
  if (Index < 0) or (Index >= TotalParticles) then Exit;
  Dec(TotalParticles);
  if Index = TotalParticles then Exit;
  Particles[Index] := Particles[TotalParticles];
end;

destructor TParticlesMesh.Free;
begin
  Capacity := 0; TotalParticles := 0;
  SetLength(Particles, 0);
end;

end.
