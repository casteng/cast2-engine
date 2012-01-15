{$Include GDefines}
{$Include CDefines}
unit CDebug;

interface

uses CTypes, CTess, CRes;

procedure CreateBoxMesh(var Mesh: TMeshTesselator);
function CreateSphereMesh(VRes, IRes: TArrayResource; var Mesh: TMeshTesselator): Boolean;

implementation

procedure CreateBoxMesh(var Mesh: TMeshTesselator);
begin
  Mesh := TMeshTesselator.Create('Bounding box mesh', 8, nil, 36, nil);
  with Mesh do begin
    VertexFormat := GetVertexFormat(False, False, False, False, 0);
    VertexSize :=  GetVertexSize(VertexFormat);
  end;
  GetMem(Mesh.Vertices, 8*Mesh.VertexSize); GetMem(Mesh.Indices, 36*2);
  with TCBufferType(Mesh.Vertices^)[0] do begin
    X := -1; Y := -1; Z := -1;
  end;
  with TCBufferType(Mesh.Vertices^)[1] do begin
    X :=  1; Y := -1; Z := -1;
  end;
  with TCBufferType(Mesh.Vertices^)[2] do begin
    X :=  1; Y :=  1; Z := -1;
  end;
  with TCBufferType(Mesh.Vertices^)[3] do begin
    X := -1; Y :=  1; Z := -1;
  end;
  with TCBufferType(Mesh.Vertices^)[4] do begin
    X := -1; Y := -1; Z :=  1;
  end;
  with TCBufferType(Mesh.Vertices^)[5] do begin
    X :=  1; Y := -1; Z :=  1;
  end;
  with TCBufferType(Mesh.Vertices^)[6] do begin
    X :=  1; Y :=  1; Z :=  1;
  end;
  with TCBufferType(Mesh.Vertices^)[7] do begin
    X := -1; Y :=  1; Z :=  1;
  end;
  TWordBuffer(Mesh.Indices^)[0] := 0; TWordBuffer(Mesh.Indices^)[1] := 3; TWordBuffer(Mesh.Indices^)[2] := 1;
  TWordBuffer(Mesh.Indices^)[3] := 1; TWordBuffer(Mesh.Indices^)[4] := 3; TWordBuffer(Mesh.Indices^)[5] := 2;
  TWordBuffer(Mesh.Indices^)[6] := 4+0; TWordBuffer(Mesh.Indices^)[7] := 4+1; TWordBuffer(Mesh.Indices^)[8] := 4+2;
  TWordBuffer(Mesh.Indices^)[9] := 4+0; TWordBuffer(Mesh.Indices^)[10] := 4+2; TWordBuffer(Mesh.Indices^)[11] := 4+3;

  TWordBuffer(Mesh.Indices^)[12] := 0; TWordBuffer(Mesh.Indices^)[13] := 4; TWordBuffer(Mesh.Indices^)[14] := 3;
  TWordBuffer(Mesh.Indices^)[15] := 4; TWordBuffer(Mesh.Indices^)[16] := 7; TWordBuffer(Mesh.Indices^)[17] := 3;
  TWordBuffer(Mesh.Indices^)[18] := 2; TWordBuffer(Mesh.Indices^)[19] := 5; TWordBuffer(Mesh.Indices^)[20] := 1;
  TWordBuffer(Mesh.Indices^)[21] := 2; TWordBuffer(Mesh.Indices^)[22] := 6; TWordBuffer(Mesh.Indices^)[23] := 5;

  TWordBuffer(Mesh.Indices^)[24] := 0; TWordBuffer(Mesh.Indices^)[25] := 1; TWordBuffer(Mesh.Indices^)[26] := 5;
  TWordBuffer(Mesh.Indices^)[27] := 0; TWordBuffer(Mesh.Indices^)[28] := 5; TWordBuffer(Mesh.Indices^)[29] := 4;
  TWordBuffer(Mesh.Indices^)[30] := 3; TWordBuffer(Mesh.Indices^)[31] := 7; TWordBuffer(Mesh.Indices^)[32] := 6;
  TWordBuffer(Mesh.Indices^)[33] := 3; TWordBuffer(Mesh.Indices^)[34] := 6; TWordBuffer(Mesh.Indices^)[35] := 2;
end;

function CreateSphereMesh(VRes, IRes: TArrayResource; var Mesh: TMeshTesselator): Boolean;
var i: Integer;
begin
  Result := False;
  if (VRes = nil) or (IRes = nil) then Exit;
  Mesh := TMeshTesselator.Create('Bounding sphere mesh', VRes.TotalElements, nil, IRes.TotalElements, nil);
  with Mesh do begin
    VertexFormat := GetVertexFormat(True, False, False, False, 0);
    VertexSize := GetVertexSize(VertexFormat);
  end;
  GetMem(Mesh.Vertices, VRes.TotalElements*Mesh.VertexSize);
  GetMem(Mesh.Indices, IRes.TotalElements*2);
  for i := 0 to VRes.TotalElements-1 do begin
    TCBufferType(Mesh.Vertices^)[i].X := TCNTBufferType(VRes.Data^)[i].X;
    TCBufferType(Mesh.Vertices^)[i].Y := TCNTBufferType(VRes.Data^)[i].Y;
    TCBufferType(Mesh.Vertices^)[i].Z := TCNTBufferType(VRes.Data^)[i].Z;
  end;
  Move(IRes.Data^, Mesh.Indices^, IRes.Size);
  Result := True;
end;

end.
