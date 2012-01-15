(*
 @Abstract(CAST II Engine 2D tesselation unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 The unit contains 2D tesselator classes
*)
// ToFix: Remove unneeded data from vertex formats
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Tess2D;

interface

uses
  
  Logger,
  
  BaseTypes, C2Types, C2Visual, CAST2, BaseGraph;

const
  MaxColorStack = 15;
  PointsGrowStep = 32; LinesGrowStep = 32;
// Alignment
  amLeft = 0; amCenter = 1; amRight = 2;
  {$IFNDEF DYNAMICALLOC}
  // Maximum number of points in 2D tesselators when dynamic memory allocation are disabled
  MaxPoints = 65536;
  {$ENDIF}

type
  TPPoint = packed record X, Y, Z: Single; U,V: Single; Color: BaseTypes.TColor; end;

  TLineMesh = class(TSharedTesselator)
  public
    constructor Create; override;
    procedure AddPoint(const X, Y: Single; const Color: BaseTypes.TColor);
    procedure Clear; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    destructor Destroy; override;
  protected
    Points: array of TPPoint; TotalPoints: Integer;
  end;

  TTetragonMesh = class(TSharedTesselator)
  private
  public
    tx, ty, tu, tv: Single;
  public
    constructor Create; override;

    procedure AddPoint(X, Y, U, V: Single; Color: BaseTypes.TColor); {$I inline.inc}
    procedure AddCorner(AX, AY, AU, AV: Single; AColor: BaseTypes.TColor); {$I inline.inc}
    procedure Clear; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    function SetIndices(IBPTR: Pointer): Integer; override;
  protected
    Points: array of TPPoint; TotalPoints: Integer;
  end;

  TTextLine = record
    Text: string;
    Color: BaseTypes.TColor;
    X, Y, Z: Single;
    Font: BaseGraph.TBaseBitmapFont;
    Viewport: BaseGraph.TViewport;
    Transform: BaseGraph.T2DTransform;
  end;

  TTextMesh = class(TSharedTesselator)
  public
    constructor Create; override;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; override;
    procedure SetFont(const AFont: TFont; ATextSizeX, ATextSizeY: Single);
    procedure AddText(const AX, AY: Single; const Color: BaseTypes.TColor; const NewText: string); virtual;
    procedure Clear; override;
  protected
    Lines: array of TTextLine;
    TotalLines: Integer;
// Current text parameters
    Font: TFont;
    procedure AddLine(const AX, AY: Single; const Color: BaseTypes.TColor; const NewText: string);
  end;

implementation

function ClipBar(var X1, Y1, U1, V1: Single; var X2, Y2, U2, V2: Single): Boolean;
var VPLeft, VPTop, VPRight, VPBottom: Single;

  function GetCode(X, Y: Single): Integer;
  begin
    Result := Ord(X < VPLeft)       or Ord(X > VPRight)  shl 1 or
              Ord(Y < VPTop)  shl 2 or Ord(Y > VPBottom) shl 3;
  end;

var ts: Single;

begin
  VPLeft   := Screen.Viewport.Left;
  VPTop    := Screen.Viewport.Top;
  VPRight  := Screen.Viewport.Right;
  VPBottom := Screen.Viewport.Bottom;

  if X1 > X2 then begin
    ts := X1; X1 := X2; X2 := ts;
    ts := U1; U1 := U2; U2 := ts;
  end;
  if Y1 > Y2 then begin
    ts := Y1; Y1 := Y2; Y2 := ts;
    ts := V1; V1 := V2; V2 := ts;
  end;

  Result := False;                                                // Completely invisible cases
  if (X2 < VPLeft) or (X1 > VPRight) or (Y2 < VPTop) or (Y1 > VPBottom) then Exit;

  Result := True;
  if X1 < VPLeft then begin
    U1 := U1 + (U2-U1)/(X2-X1) * (VPLeft - X1);
    X1 := VPLeft;
  end;
  if X2 > VPRight then begin
    U2 := U2 + (U2-U1)/(X2-X1) * (VPRight - X2);
    X2 := VPRight;
  end;
  if Y1 < VPTop then begin
    V1 := V1 + (V2-V1)/(Y2-Y1) * (VPTop - Y1);
    Y1 := VPTop;
  end;
  if Y2 > VPBottom then begin
    V2 := V2 + (V2-V1)/(Y2-Y1) * (VPBottom - Y2);
    Y2 := VPBottom;
  end;
end;

{ TLineMesh }

constructor TLineMesh.Create;
begin
  inherited;
  TotalPoints := 0;
  PrimitiveType := ptLINELIST;
  VertexFormat  := GetVertexFormat(True, False, True, False, False, 0, [2]);

  TesselationStatus[tbVertex].TesselatorType := ttDynamic;
  TesselationStatus[tbIndex].TesselatorType  := ttDynamic;
end;

procedure TLineMesh.AddPoint(const X, Y: Single; const Color: BaseTypes.TColor);
var t: Single;
begin
  if Length(Points) <= TotalPoints then SetLength(Points, Length(Points) + PointsGrowStep);
  Points[TotalPoints].X := X; Points[TotalPoints].Y := Y;

  Points[TotalPoints].Z := Screen.CurrentZ;
  Points[TotalPoints].Color := Color;

  if Odd(TotalPoints) then begin                                 // Line completed
    if ClipLineColorTex(Points[TotalPoints-1].X, Points[TotalPoints-1].Y, t, t, Points[TotalPoints-1].Color,
                        Points[TotalPoints].X,   Points[TotalPoints].Y,   t, t, Points[TotalPoints].Color,
                        Screen.Viewport.Left, Screen.Viewport.Top, Screen.Viewport.Right, Screen.Viewport.Bottom) then begin
      Screen.TransformPoint(Points[TotalPoints-1].X, Points[TotalPoints-1].Y);
      Screen.TransformPoint(Points[TotalPoints].X,   Points[TotalPoints].Y);
      Inc(TotalPoints);
    end else Dec(TotalPoints);
  end else Inc(TotalPoints);

  TotalVertices := TotalPoints;
  Invalidate([tbVertex, tbIndex], True);
end;

function TLineMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var i: Integer;
begin
  Assert(TotalPoints mod 2 = 0, ClassName + '.Tesselate: TotalPoints should be divisible by 4');

  TotalPrimitives := TotalPoints div 2;

  for i := 0 to TotalPoints-1 do begin
    SetVertexDataCRHW(Points[i].X, Points[i].Y, Points[i].Z, 1/0.1, i, VBPTR);
    SetVertexDataD(Points[i].Color, i, VBPTR);
    SetVertexDataUV(0, 0, i, VBPTR);
  end;
  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

procedure TLineMesh.Clear;
begin
  TotalPoints   := 0;
  TotalVertices := TotalPoints;
end;

destructor TLineMesh.Destroy;
begin
  Clear;
  Points := nil;
  inherited;
end;

{ TTetragonMesh }

constructor TTetragonMesh.Create;
begin
  inherited;
  PrimitiveType := ptTRIANGLELIST;
  VertexFormat  := GetVertexFormat(True, False, True, False, False, 0, [2]);

  TotalVertices := 0; TotalIndices := 0; TotalPrimitives := 0;

  TesselationStatus[tbVertex].TesselatorType := ttDynamic;
  TesselationStatus[tbIndex].TesselatorType  := ttStatic;

  {$IFNDEF DYNAMICALLOC}
  SetLength(Points, MaxPoints * 4);
  {$ENDIF}
end;

procedure TTetragonMesh.AddPoint(X, Y, U, V: Single; Color: BaseTypes.TColor);
begin
  {$IFDEF DYNAMICALLOC}
  if Length(Points) <= TotalPoints then SetLength(Points, Length(Points) + PointsGrowStep);
  {$ELSE}
  Assert(TotalPoints < MaxPoints);
  {$ENDIF}
  Points[TotalPoints].X := X;
  Points[TotalPoints].Y := Y;

  Points[TotalPoints].Z := Screen.CurrentZ;

  Points[TotalPoints].Color := Color;

  Points[TotalPoints].U := U;
  Points[TotalPoints].V := V;

  Inc(TotalPoints);
end;

procedure TTetragonMesh.AddCorner(AX, AY, AU, AV: Single; AColor: BaseTypes.TColor);
//var CX, CY: Single;
begin
  if Odd(TotalPoints) then begin
{    if ClipBar(tx, ty, tu, tv,
//               Points[TotalPoints-1].U, Points[TotalPoints-1].V,
               AX, AY, AU, AV) then begin}

{      CX := X;
      CY := ty;//Points[TotalPoints-1].Y;
      Screen.TransformPoint(CX, CY);
      AddPoint(CX, CY, U, Points[TotalPoints-1].V, Color);

      CX := X;
      CY := Y;
      Screen.TransformPoint(CX, CY);
      AddPoint(CX, CY, U, V, Color);

      CX := tx;//Points[TotalPoints-3].X;
      CY := Y;
      Screen.TransformPoint(CX, CY);
      AddPoint(CX, CY, Points[TotalPoints-3].U, V, Color);}

//      Screen.TransformPoint(Points[TotalPoints-4].X, Points[TotalPoints-4].Y);

      {$IFDEF DYNAMICALLOC} if Length(Points) <= TotalPoints+3 then SetLength(Points, Length(Points) + PointsGrowStep); {$ENDIF}

//      CX := x;
//      CY := ty;
      with Points[TotalPoints] do begin
        X := AX;
        Y := ty;
        Screen.TransformPoint(x, y);
        Z := Screen.CurrentZ;
        Color := AColor;
        U := AU;
        V := tv;
      end;
      Inc(TotalPoints);

//      CX := x;
//      CY := y;
//      Screen.TransformPoint(CX, CY);
      with Points[TotalPoints] do begin
        X := AX;
        Y := AY;
        Screen.TransformPoint(x, y);
        Z := Screen.CurrentZ;
        Color := AColor;
        U := AU;
        V := AV;
      end;
      Inc(TotalPoints);

//      CX := tx;
//      CY := y;
//      Screen.TransformPoint(CX, CY);
      with Points[TotalPoints] do begin
        X := tx;
        Y := AY;
        Screen.TransformPoint(x, y);
        Z := Screen.CurrentZ;
        Color := AColor;
        U := tu;
        V := AV;
      end;
      Inc(TotalPoints);

      TotalVertices  := TotalPoints;
      TotalIndices   := (TotalPoints * 6) shr 2;
      Invalidate([tbVertex], True);
      if TotalIndices > LastTotalIndices then Invalidate([tbIndex], True);
//    end else Dec(TotalPoints);
  end else begin
    tx := AX; ty := AY;
    tu := AU; tv := AV;
    Screen.TransformPoint(AX, AY);
    AddPoint(AX, AY, AU, AV, AColor);
  end;
end;

procedure TTetragonMesh.Clear;
begin
  TotalPoints := 0;
  TotalVertices    := TotalPoints;
  TotalIndices     := TotalPoints;
  IndexingVertices := TotalVertices;
  Invalidate([tbVertex], True);
end;

function TTetragonMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
type TBuf = packed record x, y, z, rhw: Single; Diffuse: TColor; u, v: Single; end;
var i: Integer; PBuf: ^TBuf;
begin
  Assert(TotalPoints mod 4 = 0, ClassName + '.Tesselate: TotalPoints should be divisible by 4');

  TotalIndices     := (TotalPoints * 6) shr 2;
  IndexingVertices := TotalVertices;

  TotalPrimitives := TotalPoints div 2;

  PBuf := VBPTR;
  for i := 0 to TotalPoints-1 do begin
{   SetVertexDataCRHW(Points[i].X, Points[i].Y, Points[i].Z, 1/0.1, i, VBPTR);
    SetVertexDataD(Points[i].Color, i, VBPTR);
    SetVertexDataUV(Points[i].U, Points[i].V, i, VBPTR);}
    with Points[i] do begin
      PBuf^.x := x; PBuf^.y := y; PBuf^.z := z;
      PBuf^.rhw := 1/10;
      PBuf^.Diffuse := Color;
      PBuf^.u := u;
      PBuf^.v := v;
    end;
    Inc(PBuf);
  end;

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result            := TotalVertices;
end;

function TTetragonMesh.SetIndices(IBPTR: Pointer): Integer;
var i , Index: Integer;
begin
  Index := 0;
  for i := 0 to TotalPoints shr 2-1 do begin
{    TWordBuffer(IBPTR^)[Index]   := i*4;
    TWordBuffer(IBPTR^)[Index+1] := i*4+1;
    TWordBuffer(IBPTR^)[Index+2] := i*4+2;
    TWordBuffer(IBPTR^)[Index+3] := i*4;
    TWordBuffer(IBPTR^)[Index+4] := i*4+2;
    TWordBuffer(IBPTR^)[Index+5] := i*4+3;

    Inc(Index, 6);}

    TDWordBuffer(IBPTR^)[i*3]   := (i*4+1) shl 16 + i*4;
    TDWordBuffer(IBPTR^)[i*3+1] := (i*4) shl 16 + i*4+2;
    TDWordBuffer(IBPTR^)[i*3+2] := (i*4+3) shl 16 + i*4+2;
  end;

  TesselationStatus[tbIndex].Status := tsTesselated;
  LastTotalIndices := TotalIndices;
  Result           := TotalIndices;
end;

{ TTextTesselator }

constructor TTextMesh.Create;
begin
  inherited;

//  PrimitiveType := ptTRIANGLESTRIP;
  VertexFormat  := GetVertexFormat(True, False, True, False, False, 0, [2]);

  TesselationStatus[tbVertex].TesselatorType := ttDynamic;
  TesselationStatus[tbIndex].TesselatorType  := ttDynamic;

  Clear;

  Font := nil;
end;

procedure TTextMesh.SetFont(const AFont: TFont; ATextSizeX, ATextSizeY: Single);
begin
  Font := AFont;
end;

procedure TTextMesh.AddText(const AX, AY: Single; const Color: BaseTypes.TColor; const NewText: string);
var StrLen: Integer;
begin
  if NewText = '' then Exit;
  if not (Font is BaseGraph.TBaseBitmapFont) then begin
     Log(ClassName + '.AddText: Font is undefined', lkError); 
    Exit;
  end;

  AddLine(AX, AY, Color, NewText);

  StrLen := Length(NewText);

  Inc(TotalVertices, StrLen * 6);
  Inc(TotalPrimitives, StrLen * 2);

  if (TotalVertices = LastTotalVertices) and (TesselationStatus[tbVertex].Status = tsTesselated) then
    Invalidate([tbVertex, tbIndex], False) else
      Invalidate([tbVertex, tbIndex], True);
end;

function TTextMesh.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
var
  i, j, Index: Integer;
  X, Y, CurX, CurY, CurZ, AddY, UVecX, UVecY, VVecX, VVecY, t: Single;
  Coord: TUV;
//  X1, Y1, X2, Y2, U1, V1, U2, V2: Single;
begin
//  Assert((UVMap <> nil) and (CharMap <> nil), 'TTextMesh.Tesselate: One of the maps is nil');

  TotalVertices   := 0;
  TotalPrimitives := 0;

  Index := 0;
  for j := 0 to TotalLines-1 do begin
    CurZ := Lines[j].Z;

    X := Lines[j].X; Y := Lines[j].Y;
    CurX := X; CurY := Y;
    Screen.TransformPointWith(Lines[j].Transform, CurX, CurY);
    CurX := CurX - 0.5;

    if (Y < Lines[j].Viewport.Bottom) then begin
      UVecX := Lines[j].Font.XScale;
      UVecY := 0;
      Screen.RotateScalePointWith(Lines[j].Transform, UVecX, UVecY);
      VVecX := 0;
      VVecY := Lines[j].Font.YScale;
      Screen.RotateScalePointWith(Lines[j].Transform, VVecX, VVecY);

      for i := 0 to Length(Lines[j].Text)-1 do if (X < Lines[j].Viewport.Right) then begin
        Coord := Lines[j].Font.UVMap^[Lines[j].Font.CharMap^[Ord(Lines[j].Text[i+1])]];

        if X + Coord.W * Lines[j].Font.XScale > Lines[j].Viewport.Right then
          Coord.W := Coord.W * (1 - (X + Coord.W * Lines[j].Font.XScale - (Lines[j].Viewport.Right)) / (Coord.W * Lines[j].Font.XScale));
        if Y + Coord.H * Lines[j].Font.YScale > Lines[j].Viewport.Bottom then
          Coord.H := Coord.H * (1 - (Y + Coord.H * Lines[j].Font.YScale - (Lines[j].Viewport.Bottom)) / (Coord.H * Lines[j].Font.YScale));

        t := 0;
        if X < Lines[j].Viewport.Left then begin
          t := (Lines[j].Viewport.Left - X) / (Coord.W * Lines[j].Font.XScale);
          if t < 1 then begin

            CurX := CurX + UVecX * Coord.W * t;
//            CurX := CurX + (Lines[j].Viewport^.Left - X);
//            X    := X    + (Lines[j].Viewport^.Left - X);
            X := X + Coord.W * Lines[j].Font.XScale * t;
            CurY := CurY + UVecY * Coord.W * t;

            Coord.U := Coord.U + Coord.W * t;
            Coord.W := Coord.W * (1 - t);
          end;
        end;

        AddY := 0;
        if (t < 1) and (Y < Lines[j].Viewport.Top) then begin
          t := (Lines[j].Viewport.Top  - Y) / (Coord.H * Lines[j].Font.YScale);
          if t < 1 then begin
            Coord.V := Coord.V + Coord.H * t;
            Coord.H := Coord.H * (1 - t);
            AddY := Lines[j].Viewport.Top  - Y;
          end;
        end;

        if t < 1 then begin
          Inc(TotalVertices,   6);
          Inc(TotalPrimitives, 2);

          CurY := CurY + AddY;
          // First treangle
          SetVertexDataCRHW(CurX + VVecX * Coord.H, CurY + VVecY * Coord.H - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U, Coord.V + Coord.H, Index, VBPTR);

          Inc(Index);

          SetVertexDataCRHW(CurX, CurY - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U, Coord.V, Index, VBPTR);

          Inc(Index);

          SetVertexDataCRHW(CurX + UVecX * Coord.W + VVecX * Coord.H, CurY + UVecY * Coord.W + VVecY * Coord.H - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U + Coord.W, Coord.V + Coord.H, Index, VBPTR);

          Inc(Index);
          // Second treangle
          SetVertexDataCRHW(CurX, CurY - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U, Coord.V, Index, VBPTR);

          Inc(Index);

          SetVertexDataCRHW(CurX + UVecX * Coord.W, CurY + UVecY * Coord.W - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U + Coord.W, Coord.V, Index, VBPTR);

          Inc(Index);

          SetVertexDataCRHW(CurX + UVecX * Coord.W + VVecX * Coord.H, CurY + UVecY * Coord.W + VVecY * Coord.H - 0.5, CurZ, 1, Index, VBPTR);
          SetVertexDataD(Lines[j].Color, Index, VBPTR);
          SetVertexDataUV(Coord.U + Coord.W, Coord.V + Coord.H, Index, VBPTR);

          Inc(Index);

          CurY := CurY - AddY;
        end;

        CurX := CurX + UVecX * Coord.W;
        CurY := CurY + UVecY * Coord.W;
        X := X + Coord.W * Lines[j].Font.XScale;        
      end;
    end;  
  end;

  Assert(Index <= TotalVertices, ClassName + '.Tesselate: Index out of range');

  TesselationStatus[tbVertex].Status := tsTesselated;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

procedure TTextMesh.Clear;
begin
  TotalVertices   := 0;
  TotalPrimitives := 0;
  TotalLines      := 0;
end;

procedure TTextMesh.AddLine(const AX, AY: Single; const Color: BaseTypes.TColor; const NewText: string);
begin
  if Length(Lines) <= TotalLines then SetLength(Lines, Length(Lines) + LinesGrowStep);
  Lines[TotalLines].Text      := NewText;

  Lines[TotalLines].X         := AX;
  Lines[TotalLines].Y         := AY;
  Lines[TotalLines].Z         := Screen.CurrentZ;
  Lines[TotalLines].Color     := Color;
  Lines[TotalLines].Font      := Font as BaseGraph.TBaseBitmapFont;
  Lines[TotalLines].Viewport  := Screen.Viewport;
  Lines[TotalLines].Transform := Screen.Transform;
  Inc(TotalLines);
end;

end.
