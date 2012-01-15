(*
 @Abstract(CAST II Engine miscellaneous tesselators unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains miscellaneous tesselator classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2MiscTess;

interface

uses
  Logger,
  BaseTypes, Basics, Base3D, CAST2, C2Types, C2Visual;

type
  TWholeTreeMesh = class(TTesselator)
    LevelHeight, LevelStride, InnerRadius, OuterRadius, IRadiusStep, ORadiusStep, StrideFactor: Single;
    StemLowRadius, StemHighRadius, StemHeight, CrownStart: Single;
    StemUHeight, StemVHeight, CrownUVRadius: Single;
    Smoothing, Levels: Integer;
    Colored, Stem: Boolean;
    StemColor, CrownColor: BaseTypes.TColor;
    constructor Create; override;
    function RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer; override;
    procedure SetParameters(ALevelHeight, ALevelStride, AInnerRadius, AOuterRadius, AIRadiusStep, AORadiusStep, AStrideFactor: Single;
                            AStem: Boolean;
                            AStemUHeight, AStemVHeight, ACrownUVRadius, AStemLowRadius, AStemHighRadius, AStemHeight, ACrownStart: Single;
                            ASmoothing, ALevels: Integer;
                            AColored: Boolean; AStemColor, ACrownColor: BaseTypes.TColor); virtual;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
    function GetBoundingBox: TBoundingBox; override;
  protected
    MaxY: Single;
  end;

implementation

{ TWholeTreeMesh }

constructor TWholeTreeMesh.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
  SetParameters(0.200, 0.300, 0.400, 0.800, 0.080, 0.080, 0.9, True, 0.25, 0.25, 1, 0.300, 0.100, 1.000, 0.200, 8, 3, True, GetColor($808020), GetColor($408040));
end;

function TWholeTreeMesh.RetrieveParameters(out Parameters: Pointer; Internal: Boolean): Integer;
begin
  Result     := 20;
  Parameters := @LevelHeight;
end;

procedure TWholeTreeMesh.SetParameters(ALevelHeight, ALevelStride, AInnerRadius, AOuterRadius, AIRadiusStep, AORadiusStep, AStrideFactor: Single;
                                       AStem: Boolean;
                                       AStemUHeight, AStemVHeight, ACrownUVRadius, AStemLowRadius, AStemHighRadius, AStemHeight, ACrownStart: Single;
                                       ASmoothing, ALevels: Integer;
                                       AColored: Boolean; AStemColor, ACrownColor: BaseTypes.TColor);
var i: Integer; LStride: Single;
begin
  InitVertexFormat(GetVertexFormat(False, True, AColored, False, False, 1, [2]));
  Smoothing    := ASmoothing; Levels := ALevels;
  LevelHeight  := ALevelHeight;
  LevelStride  := ALevelStride;
  InnerRadius  := AInnerRadius;
  OuterRadius  := AOuterRadius;
  IRadiusStep  := AIRadiusStep;
  ORadiusStep  := AORadiusStep;
  StrideFactor := AStrideFactor;

  Stem           := AStem;
  StemLowRadius  := AStemLowRadius;
  StemHighRadius := AStemHighRadius;
  StemHeight     := AStemHeight;
  CrownStart     := ACrownStart;

  StemUHeight    := AStemUHeight;
  StemVHeight    := AStemVHeight;
  CrownUVRadius  := ACrownUVRadius;

  Colored        := AColored;
  StemColor      := AStemColor;
  CrownColor     := ACrownColor; 

  TotalVertices   :=   Smoothing*2*Levels +   Smoothing*2 * Byte(Stem);
  TotalPrimitives :=   Smoothing*2*Levels +   Smoothing*2 * Byte(Stem);
  TotalIndices    := 3*Smoothing*2*Levels + 3*Smoothing*2 * Byte(Stem);

  IndexingVertices := TotalVertices;
  TotalStrips := 1;
  StripOffset := 0;
  VerticesRes := -1; IndicesRes := -1;

  // Compute max. Y
  MaxY := CrownStart;
  LStride := LevelStride;
  for i := 0 to Levels-1 do begin
    MaxY := MaxY + LStride;
    LStride := LStride * StrideFactor;
  end;
  if StemHeight > MaxY then MaxY := StemHeight;
end;

function TWholeTreeMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, j: Integer;
  CurY, CurIR, CurOR, LHeight, LStride, UVNorm: Single;
  Ofs: Cardinal;
  t1, t2: Single;
begin
// ******** Tree stem ************
  if Stem then begin
    for i := 0 to Smoothing-1 do begin
      t1 := Cos(i/180*pi*360/Smoothing); t2 := Sin(i/180*pi*360/Smoothing);
      SetVertexDataC(t1*StemLowRadius, 0, -t2*StemLowRadius, i, VBPTR);
      SetVertexDataW(0, i, VBPTR);

      SetVertexDataN(t1, 0, -t2, i, VBPTR);

//      U := 1-0.15+0.3*i/Smoothing;
      case i and 3 of
        0: t1 := 1 - StemUHeight;
        1: t1 := 1;
        2: t1 := 1 + StemUHeight;
        3: t1 := 1;
      end;
      t2 := 1-StemVHeight;
      SetVertexDataUV(t1, t2, i, VBPTR);
    end;
    for i := 0 to Smoothing-1 do begin
      Ofs := i+Smoothing;
      t1 := Cos(i/180*pi*360/Smoothing); t2 := Sin(i/180*pi*360/Smoothing);
      SetVertexDataC(t1*StemHighRadius, StemHeight, -t2*StemHighRadius, Ofs, VBPTR);
      SetVertexDataW(1 - StemHeight / MaxY, Ofs, VBPTR);

      SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);

//      U := 1-0.15+0.3*i/Smoothing;
      case i and 3 of
        0: t1 := 1 - StemUHeight;
        1: t1 := 1;
        2: t1 := 1 + StemUHeight;
        3: t1 := 1;
      end;
      t2 := 1+StemVHeight;
      SetVertexDataUV(t1, t2, Ofs, VBPTR);
    end;
  end;

// Tree crown
  CurY := CrownStart;
  CurIR := InnerRadius; CurOR := OuterRadius;
  LHeight := LevelHeight; LStride := LevelStride;
  for j := 0 to Levels-1 do begin
    if CurIR > CurOR then begin
      if CurIR = 0 then UVNorm := 0 else UVNorm := CurOR / CurIR;
    end else begin
      if CurOR = 0 then UVNorm := 0 else UVNorm := CurIR / CurOR;
    end;

    for i := 0 to Smoothing-1 do begin              // Outer edge
      Ofs := (j+Ord(Stem))*2*(Smoothing)+i;
      t1 := Cos(i/180*pi*360/Smoothing + j*35/180*pi); t2 := Sin(i/180*pi*360/Smoothing + j*35/180*pi);
      SetVertexDataC(t1*CurOR, CurY, -t2*CurOR, Ofs, VBPTR);
      SetVertexDataW(1 - CurY/ MaxY, Ofs, VBPTR);

      if Abs(CurOR) < 0.001 then begin
        SetVertexDataN(0, 1, 0, Ofs, VBPTR);
      end else begin
        SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);
      end;

      t1 := Cos(i/180*pi*360/Smoothing) * CrownUVRadius; t2 := Sin(i/180*pi*360/Smoothing) * CrownUVRadius;
      if CurIR > CurOR then begin
        SetVertexDataUV(0.5 + t1 * UVNorm * 0.5, 0.5 - t2 * UVNorm * 0.5, Ofs, VBPTR);
      end else begin
        SetVertexDataUV(0.5+t1*0.5, 0.5-t2*0.5, Ofs, VBPTR);
      end;
    end;

    for i := 0 to Smoothing-1 do begin          // Inner edge
      Ofs := ((j+Ord(Stem))*2+1)*(Smoothing)+i;
      t1 := Cos(i/180*pi*360/Smoothing + j*35/180*pi); t2 := Sin(i/180*pi*360/Smoothing + j*35/180*pi);
      SetVertexDataC(t1*CurIR, CurY + LHeight, -t2*CurIR, Ofs, VBPTR);
      SetVertexDataW(1 - (CurY + LHeight)/ MaxY, Ofs, VBPTR);

      if Abs(CurIR) < 0.001 then begin
        SetVertexDataN(0, 1, 0, Ofs, VBPTR);
      end else begin
        SetVertexDataN(t1, 0, -t2, Ofs, VBPTR);
      end;

      t1 := Cos(i/180*pi*360/Smoothing) * CrownUVRadius; t2 := Sin(i/180*pi*360/Smoothing) * CrownUVRadius;

      if CurIR < CurOR then begin                                                    // Inner edge
        SetVertexDataUV(0.5 + t1 * UVNorm * 0.5, 0.5 - t2 * UVNorm * 0.5, Ofs, VBPTR);
      end else begin                                                                 // Outer edge
        SetVertexDataUV(0.5+t1*0.5, 0.5-t2*0.5, Ofs, VBPTR);
      end;
    end;
//    YDec := YDec * (1-0.7/(Levels));
    CurY := CurY + LStride;
    CurIR := CurIR - IRadiusStep;
    CurOR := CurOR - ORadiusStep;
    LStride := LStride * StrideFactor;
    LHeight := LHeight * StrideFactor;
  end;

//  TotalVertices := TotalParticles*12; TotalPrimitives := TotalParticles*2;
  TesselationStatus[tbVertex].Status := tsTesselated;
  Result := TotalVertices;
  LastTotalVertices := TotalVertices;
end;

function TWholeTreeMesh.SetIndices(IBPTR: Pointer): Integer;
var i, j: Integer;
begin
{  for j := 0 to Levels-1 do begin
    for i := 0 to Smoothing-1 do begin
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3] := j*(Smoothing+1);
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3+1] := j*(Smoothing+1)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing+i)*3+2] := j*(Smoothing+1)+i+2;
    end;
    TWordBuffer(IBPTR^)[(j*Smoothing+Smoothing-1)*3+2] := j*(Smoothing+1)+1;
  end;}

  for j := 0 to Levels-Byte(not Stem) do begin
    for i := 0 to Smoothing-1 do begin
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+0] := (j*2+0)*(Smoothing+0)+i;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+1] := (j*2+0)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+2] := (j*2+1)*(Smoothing+0)+i;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+3] := (j*2+0)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+4] := (j*2+1)*(Smoothing+0)+i+1;
      TWordBuffer(IBPTR^)[(j*Smoothing)*6+i*6+5] := (j*2+1)*(Smoothing+0)+i+0;
    end;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+1] := (j*2+0)*(Smoothing+0)+0;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+3] := (j*2+0)*(Smoothing+0)+0;
    TWordBuffer(IBPTR^)[(j*Smoothing)*6+(Smoothing-1)*6+4] := (j*2+1)*(Smoothing+0)+0;
  end;

  TesselationStatus[tbIndex].Status := tsTesselated;

  Result := TotalIndices;
  LastTotalIndices := TotalIndices;
end;

function TWholeTreeMesh.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-OuterRadius, 0, -OuterRadius);
  Result.P2 := GetVector3s(OuterRadius, LevelStride*(Levels-1) + LevelHeight, OuterRadius);
end;

end.
