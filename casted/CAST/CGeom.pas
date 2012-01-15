{$Include GDefines}
{$Include CDefines}
unit CGeom;

interface

uses Base3D, CTypes, CTess, CRes;

function GetLineMesh(P1, P2: TVector3s; Color: Longword): TMeshTesselator;
function GetSphereMesh(Center: TVector3s; Radius, Color1, Color2: Longword): TMeshTesselator;
function GetBoxMesh(P1, P2: TVector3s; AColor: Longword): TMeshTesselator;
//function CreateBoxMesh: TMeshTesselator;
//function CreateSphereMesh(VRes, IRes: TArrayResource): TMeshTesselator;

type
  TWireTesselator = class(TTesselator)
  end;

implementation

function GetLineMesh(P1, P2: TVector3s; Color: Longword): TMeshTesselator;
begin
  Result := TMeshTesselator.Create('Line mesh', 2, nil, 0, nil);
  with Result do begin
    PrimitiveType := CPTypes[ptLINELIST];
    VertexFormat := GetVertexFormat(False, False, True, False, 0);
    VertexSize :=  GetVertexSize(VertexFormat);
    TotalPrimitives := 1;
  end;
  GetMem(Result.Vertices, 2*Result.VertexSize);
  with TCDBufferType(Result.Vertices^)[0] do begin
    X := P1.X; Y := P1.Y; Z := P1.Z;
    DColor := Color;
  end;
  with TCDBufferType(Result.Vertices^)[1] do begin
    X := P2.X; Y := P2.Y; Z := P2.Z;
    DColor := Color;
  end;
end;

function GetBoxMesh(P1, P2: TVector3s; AColor: Longword): TMeshTesselator;
var VB: ^TCDBufferType;
begin
  Result := TMeshTesselator.Create('Box mesh', 16, nil, 0, nil);
  with Result do begin
    PrimitiveType := CPTypes[ptLINESTRIP];
    VertexFormat := GetVertexFormat(False, False, True, False, 0);
    VertexSize :=  GetVertexSize(VertexFormat);
    TotalPrimitives := 15;
  end;
  GetMem(Result.Vertices, 16*Result.VertexSize);
  VB := Result.Vertices;
  with VB^[00] do begin X := P1.X; Y := P1.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[01] do begin X := P2.X; Y := P1.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[02] do begin X := P2.X; Y := P2.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[03] do begin X := P1.X; Y := P2.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[04] do begin X := P1.X; Y := P1.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[05] do begin X := P1.X; Y := P1.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[06] do begin X := P2.X; Y := P1.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[07] do begin X := P2.X; Y := P2.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[08] do begin X := P1.X; Y := P2.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[09] do begin X := P1.X; Y := P1.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[10] do begin X := P2.X; Y := P1.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[11] do begin X := P2.X; Y := P1.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[12] do begin X := P2.X; Y := P2.Y; Z := P1.Z; DColor := AColor; end;
  with VB^[13] do begin X := P2.X; Y := P2.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[14] do begin X := P1.X; Y := P2.Y; Z := P2.Z; DColor := AColor; end;
  with VB^[15] do begin X := P1.X; Y := P2.Y; Z := P1.Z; DColor := AColor; end;
end;

function GetSphereMesh(Center: TVector3s; Radius, Color1, Color2: Longword): TMeshTesselator;
const Acc = 32;
var i: Integer;
begin
  Result := TMeshTesselator.Create('Sphere', (Acc+1)*2, nil, 0, nil);
  with Result do begin
    PrimitiveType := CPTypes[ptLINESTRIP];
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
end;

function CreateBoxMesh: TMeshTesselator;
begin
  Result := TMeshTesselator.Create('Bounding box mesh', 8, nil, 36, nil);
  with Result do begin
    VertexFormat := GetVertexFormat(False, False, False, False, 0);
    VertexSize :=  GetVertexSize(VertexFormat);
  end;
  GetMem(Result.Vertices, 8*Result.VertexSize); GetMem(Result.Indices, 36*2);
  with TCBufferType(Result.Vertices^)[0] do begin
    X := -1; Y := -1; Z := -1;
  end;
  with TCBufferType(Result.Vertices^)[1] do begin
    X :=  1; Y := -1; Z := -1;
  end;
  with TCBufferType(Result.Vertices^)[2] do begin
    X :=  1; Y :=  1; Z := -1;
  end;
  with TCBufferType(Result.Vertices^)[3] do begin
    X := -1; Y :=  1; Z := -1;
  end;
  with TCBufferType(Result.Vertices^)[4] do begin
    X := -1; Y := -1; Z :=  1;
  end;
  with TCBufferType(Result.Vertices^)[5] do begin
    X :=  1; Y := -1; Z :=  1;
  end;
  with TCBufferType(Result.Vertices^)[6] do begin
    X :=  1; Y :=  1; Z :=  1;
  end;
  with TCBufferType(Result.Vertices^)[7] do begin
    X := -1; Y :=  1; Z :=  1;
  end;
  TWordBuffer(Result.Indices^)[0] := 0; TWordBuffer(Result.Indices^)[1] := 3; TWordBuffer(Result.Indices^)[2] := 1;
  TWordBuffer(Result.Indices^)[3] := 1; TWordBuffer(Result.Indices^)[4] := 3; TWordBuffer(Result.Indices^)[5] := 2;
  TWordBuffer(Result.Indices^)[6] := 4+0; TWordBuffer(Result.Indices^)[7] := 4+1; TWordBuffer(Result.Indices^)[8] := 4+2;
  TWordBuffer(Result.Indices^)[9] := 4+0; TWordBuffer(Result.Indices^)[10] := 4+2; TWordBuffer(Result.Indices^)[11] := 4+3;

  TWordBuffer(Result.Indices^)[12] := 0; TWordBuffer(Result.Indices^)[13] := 4; TWordBuffer(Result.Indices^)[14] := 3;
  TWordBuffer(Result.Indices^)[15] := 4; TWordBuffer(Result.Indices^)[16] := 7; TWordBuffer(Result.Indices^)[17] := 3;
  TWordBuffer(Result.Indices^)[18] := 2; TWordBuffer(Result.Indices^)[19] := 5; TWordBuffer(Result.Indices^)[20] := 1;
  TWordBuffer(Result.Indices^)[21] := 2; TWordBuffer(Result.Indices^)[22] := 6; TWordBuffer(Result.Indices^)[23] := 5;

  TWordBuffer(Result.Indices^)[24] := 0; TWordBuffer(Result.Indices^)[25] := 1; TWordBuffer(Result.Indices^)[26] := 5;
  TWordBuffer(Result.Indices^)[27] := 0; TWordBuffer(Result.Indices^)[28] := 5; TWordBuffer(Result.Indices^)[29] := 4;
  TWordBuffer(Result.Indices^)[30] := 3; TWordBuffer(Result.Indices^)[31] := 7; TWordBuffer(Result.Indices^)[32] := 6;
  TWordBuffer(Result.Indices^)[33] := 3; TWordBuffer(Result.Indices^)[34] := 6; TWordBuffer(Result.Indices^)[35] := 2;
end;

function CreateSphereMesh(VRes, IRes: TArrayResource): TMeshTesselator;
var i: Integer;
begin
  Result := nil;
  if (VRes = nil) or (IRes = nil) then Exit;
  Result := TMeshTesselator.Create('Bounding sphere mesh', VRes.TotalElements, nil, IRes.TotalElements, nil);
  with Result do begin
    VertexFormat := GetVertexFormat(True, False, False, False, 0);
    VertexSize := GetVertexSize(VertexFormat);
  end;
  GetMem(Result.Vertices, VRes.TotalElements*Result.VertexSize);
  GetMem(Result.Indices, IRes.TotalElements*2);
  for i := 0 to VRes.TotalElements-1 do begin
    TCBufferType(Result.Vertices^)[i].X := TCNTBufferType(VRes.Data^)[i].X;
    TCBufferType(Result.Vertices^)[i].Y := TCNTBufferType(VRes.Data^)[i].Y;
    TCBufferType(Result.Vertices^)[i].Z := TCNTBufferType(VRes.Data^)[i].Z;
  end;
  Move(IRes.Data^, Result.Indices^, IRes.Size);
end;

end.
