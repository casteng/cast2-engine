(*
 @Abstract(CAST II engine debug tesselation unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 Unit contains debug tesselator classes
*)
{$Include GDefines.inc}
unit C2DebugTess;

interface

uses Base3D, C2Types, C2Visual, CAST2;

type
  TDebugTesselator = class(TTesselator)
    constructor Create; override;
  end;

  TBoxTesselator = class(TDebugTesselator)
    constructor Create; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TSphereTesselator = class(TDebugTesselator)
    constructor Create; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

  TConeTesselator = class(TDebugTesselator)
    constructor Create; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
  end;

implementation

// Primitive draw accuracy
const Acc = 30;

{ TDebugTesselator }

constructor TDebugTesselator.Create;
begin
  inherited;
  PrimitiveType    := ptLINESTRIP;
  InitVertexFormat(GetVertexFormat(False, False, False, False, False, 0, []));

  Init;
end;

{ TBoxTesselator }

constructor TBoxTesselator.Create;
begin
  inherited;

  TotalVertices    := 16;
  TotalPrimitives  := 15;
end;

function TBoxTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
begin
  SetVertexDataC(-1, -1, -1,  0, VBPTR);
  SetVertexDataC( 1, -1, -1,  1, VBPTR);
  SetVertexDataC( 1,  1, -1,  2, VBPTR);
  SetVertexDataC(-1,  1, -1,  3, VBPTR); 
  SetVertexDataC(-1, -1, -1,  4, VBPTR); 
  SetVertexDataC(-1, -1,  1,  5, VBPTR); 
  SetVertexDataC( 1, -1,  1,  6, VBPTR); 
  SetVertexDataC( 1,  1,  1,  7, VBPTR);
  SetVertexDataC(-1,  1,  1,  8, VBPTR); 
  SetVertexDataC(-1, -1,  1,  9, VBPTR); 
  SetVertexDataC( 1, -1,  1, 10, VBPTR); 
  SetVertexDataC( 1, -1, -1, 11, VBPTR); 
  SetVertexDataC( 1,  1, -1, 12, VBPTR); 
  SetVertexDataC( 1,  1,  1, 13, VBPTR); 
  SetVertexDataC(-1,  1,  1, 14, VBPTR); 
  SetVertexDataC(-1,  1, -1, 15, VBPTR);

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

(*function GetSphereMesh(Center: TVector3s; Radius, Color1, Color2: Longword): TMeshTesselator;
const Acc = 32;
var i: Integer;
begin
  Result := TMeshTesselator.Create('Sphere', (Acc+1)*2, nil, 0, nil);
  with Result do begin
    PrimitiveType := ptLINESTRIP;
    VertexFormat := GetVertexFormat(False, False, True, False, 0);
    VertexSize :=  GetVertexSize(VertexFormat);
    TotalPrimitives := Acc*2+1;
  end;
  GetMem(Result.Vertices, (Acc+1)*2*Result.VertexSize);
  for i := 0 to Acc do begin
    with TCDBufferType(Result.Vertices^)[i] do begin
      X := Cos(i/Acc*2*pi)*Radius; Y := -Sin(i/Acc*2*pi)*Radius;
      Z := Center.Z;
      DColor := Color1;
    end;
    with TCDBufferType(Result.Vertices^)[Acc+i+1] do begin
      X := Cos(i/Acc*2*pi)*Radius; Z := -Sin(i/Acc*2*pi)*Radius;
      Y := Center.Y;
      DColor := Color2;
    end;
  end;
end;*)

{ TSphereTesselator }

constructor TSphereTesselator.Create;
begin
  inherited;
  TotalVertices   := (Acc+2)*3;
  TotalPrimitives := (Acc+2)*3-1;
end;

function TSphereTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  SetVertexDataC(0, 0,  0, 0, VBPTR);
  for i := 0 to Acc do SetVertexDataC(Cos(i/Acc*2*pi), -Sin(i/Acc*2*pi),  0,                i+1,          VBPTR);
  SetVertexDataC(0, 0,  0, Acc+2, VBPTR);
  for i := 0 to Acc do SetVertexDataC(-Sin(i/Acc*2*pi),  0,               Cos(i/Acc*2*pi),  Acc+2+i+1,    VBPTR);
  SetVertexDataC(0, 0,  0, (Acc+2)*2, VBPTR);
  for i := 0 to Acc do SetVertexDataC(0,                Cos(i/Acc*2*pi), -Sin(i/Acc*2*pi), (Acc+2)*2+i+1, VBPTR);

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

{ TConeTesselator }

constructor TConeTesselator.Create;
begin
  inherited;
  TotalVertices   := Acc+1;
  TotalPrimitives := Acc;
end;

function TConeTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
begin
  Result := 0;
end;

end.
