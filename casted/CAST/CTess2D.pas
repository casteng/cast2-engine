{$Include GDefines}
{$Include CDefines}
unit CTess2D;

interface

uses Basics, CTypes, CTess, CMarkup;

const
  MaxColorStack = 15;

type
  TScreenVBuf = array[0..$FFFFFF] of packed record
    X, Y, Z, RHW: Single; DColor: Longword; U, V: Single;
  end;
  PScreenVBuf = ^TScreenVBuf;

  TPPoint = packed record X, Y, U, V: Single; Color: Longword; end;

  TLineMesh = class(TTesselator)
    Points: array of TPPoint; TotalPoints: Integer;
    constructor Create(const AName: TShortName); override;
    procedure AddPoint(const X, Y: Single; const Color: Longword); virtual;
    procedure Clear; virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
//    function SetIndices(IBPTR: Pointer): Integer; override;
    destructor Free;
  end;

  TTetragonMesh = class(TTesselator)
    Points: array[0..3] of TPPoint;
    constructor Create(const AName: TShortName); override;
    procedure SetRectangle(const X1, Y1, X2, Y2: Single; const Color: Longword); virtual;
    procedure SetUVRectangle(const U1, V1, U2, V2: Single); virtual;
    procedure SetPoints(const APoints: array of TPPoint); virtual;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
  end;

  TTextMesh = class(TTesselator)
// Supports coloring each character by following commands:
// ^^ transforms to single "^" character
// ^<c80808080>Text^<c> - Text colored by specified color
    TextAlign: Cardinal;
    Text: string;
    Color: Longword;
    X, Y, XTexScale, YTexScale: Single;
    UVMap: TUVMap;
    CharMap: TCharMap;
    constructor Create(const AName: TShortName); override;
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetLayout(const AX, AY: Single; const ATextAlign, AScreenAlignX, AScreenAlignY: Longword); virtual;
    procedure SetMaps(const AUVMap: TUVMap; const ACharMap: TCharMap); virtual;
    procedure SetText(const NewText: string); virtual;
  protected
    StrHLen: Single;
  end;

  TColoredTextMesh = class(TTextMesh)
// Supports coloring each character by following commands:
// ^^ transforms to single "^" character
// ^<c80808080>Text^<c> - Text colored by specified color
    function Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer; override;
    procedure SetText(const NewText: string); override;
    destructor Free;
  protected
    ColorStack: array[0..MaxColorStack] of Longword;
    Markup: TMarkup;
  end;

implementation

{ TLineMesh }

constructor TLineMesh.Create(const AName: TShortName);
begin
  inherited Create(AName);
  TotalPoints := 0;
  PrimitiveType := CPTypes[ptLINESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
end;

procedure TLineMesh.AddPoint(const X, Y: Single; const Color: Longword);
begin
  Inc(TotalPoints); SetLength(Points, TotalPoints);
  Points[TotalPoints-1].X := X; Points[TotalPoints-1].Y := Y;
  Points[TotalPoints-1].Color := Color;
  TotalVertices := TotalPoints; TotalPrimitives := TotalPoints-1;
  IndexingVertices := TotalVertices;
  Invalidate(True);
end;

function TLineMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer; VB: PScreenVBuf;
begin
  Result := 0;
  if TotalPoints < 2 then Exit;
  VB := VBPTR;
  for i := 0 to TotalPoints-1 do begin
    VB^[i].X := Points[i].X; VB^[i].Y := Points[i].Y;
    VB^[i].Z := 0.1; VB^[i].RHW := 1/0.1;
    VB^[i].DColor := Points[i].Color;
    VB^[i].U := 0; VB^[i].V := 0;
  end;
  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

procedure TLineMesh.Clear;
begin
  SetLength(Points, 0); TotalPoints := 0;
end;

destructor TLineMesh.Free;
begin
  Clear;
end;

{ TTetragonMesh }

constructor TTetragonMesh.Create(const AName: TShortName);
begin
  inherited Create(AName);
  PrimitiveType := CPTypes[ptTRIANGLESTRIP];
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalStrips := 1; TotalVertices := 4; TotalIndices := 0; TotalPrimitives := 2;
end;

procedure TTetragonMesh.SetPoints(const APoints: array of TPPoint);
begin
  Assert(Length(APoints) = 4, 'TTetragonMesh.SetPoints: Invalid data length');
  Points[0] := APoints[0]; Points[1] := APoints[1];
  Points[2] := APoints[2]; Points[3] := APoints[3];
  if VStatus <> tsSizeChanged then Invalidate(False);
end;

procedure TTetragonMesh.SetRectangle(const X1, Y1, X2, Y2: Single; const Color: Longword);
begin
  Points[0].X := X1; Points[0].Y := Y1; Points[0].Color := Color;
  Points[1].X := X2; Points[1].Y := Y1; Points[1].Color := Color;
  Points[2].X := X1; Points[2].Y := Y2; Points[2].Color := Color;
  Points[3].X := X2; Points[3].Y := Y2; Points[3].Color := Color;
  if VStatus <> tsSizeChanged then Invalidate(False);
end;

procedure TTetragonMesh.SetUVRectangle(const U1, V1, U2, V2: Single);
begin
  Points[0].U := U1; Points[0].V := V1;
  Points[1].U := U2; Points[1].V := V1;
  Points[2].U := U1; Points[2].V := V2;
  Points[3].U := U2; Points[3].V := V2;
end;

function TTetragonMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
var i: Integer; VB: PScreenVBuf;
begin
  VB := VBPTR;
  for i := 0 to 3 do begin
    VB^[i].X := Points[i].X; VB^[i].Y := Points[i].Y;
    VB^[i].Z := 0.1; VB^[i].RHW := 1/0.1;
    VB^[i].DColor := Points[i].Color;
    VB^[i].U := Points[i].U;
    VB^[i].V := Points[i].V;
  end;

  VStatus := tsTesselated;
  LastTotalVertices := TotalVertices;
  Result := TotalVertices;
end;

{ TTextTesselator }

constructor TTextMesh.Create(const AName: TShortName);
begin
  inherited Create(AName);

  PrimitiveType := CPTypes[ptTRIANGLESTRIP];;
  VertexFormat := GetVertexFormat(True, False, True, False, 1);
  VertexSize := GetVertexSize(VertexFormat);
  TotalVertices := 0; TotalStrips := 1; TotalIndices := 0;
  StripOffset := 0;

  XTexScale := 128;//Font.FontTextureWidth;   //ToFix: Get real texture dimensions
  YTexScale := 128;//Font.FontTextureHeight;

  SetLayout(0, 0, amLeft, amLeft, amLeft);

  UVMap := nil; CharMap := nil;
end;

procedure TTextMesh.SetLayout(const AX, AY: Single; const ATextAlign, AScreenAlignX, AScreenAlignY: Longword);
begin
  X := AX; Y := AY; TextAlign := ATextAlign;
  if VStatus <> tsSizeChanged then Invalidate(False);
end;

procedure TTextMesh.SetMaps(const AUVMap: TUVMap; const ACharMap: TCharMap);
begin
  UVMap := AUVMap; CharMap := ACharMap;
end;

procedure TTextMesh.SetText(const NewText: string);
var i, StrLen: Integer;
begin
  if NewText = Text then Exit;
  Text := NewText;
  StrLen := Length(Text);
  StrHLen := 0;
  for i := 0 to Length(Text)-1 do
   StrHLen := StrHLen + UVMap[CharMap[Ord(Text[i+1])]].W * XTexScale;
  TotalVertices := StrLen*4;
  TotalPrimitives := (2*StrLen) + (2*StrLen-2);
  if (TotalVertices = LastTotalVertices) and (VStatus = tsTesselated) then Invalidate(False) else Invalidate(True);
end;

function TTextMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
const Depth = 0.1;
type TLocalVB = TTCDTBuffer;
var i: Integer; CurX, CurY, StrHLen: Single; Coord: TUV; 
begin
//  Assert((UVMap <> nil) and (CharMap <> nil), 'TTextMesh.Tesselate: One of the maps is nil');
  StrHLen := 0;
  for i := 0 to Length(Text)-1 do
   StrHLen := StrHLen + UVMap[CharMap[Ord(Text[i+1])]].W*XTexScale;
//   StrHLen := StrHLen + UVMap[Ord(Text[i+1])-32].W*XTexScale;

{  case XAlign of
    amLeft: CurX := FArea.Left - 0.5;
    amCenter: CurX := FArea.Left - 0.5 + Trunc(RenderPars.ActualWidth*0.5);
    amRight: CurX := RenderPars.ActualWidth - FArea.Left - 0.5;
  end;}

  CurX := X-0.5; CurY := Y;

  case TextAlign of
    amCenter: CurX := Curx - Trunc(StrHLen*0.5);
    amRight: CurX := Curx - StrHLen;
  end;

  for i := 0 to Length(Text)-1 do begin
    Coord := UVMap[CharMap[Ord(Text[i+1])]];
//    Coord := UVMap[Ord(Text[i+1])-32];
    with TLocalVB(VBPTR^)[i*4] do begin
      X := CurX;
      Y := CurY - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := Color;
      U := Coord.U; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+1] do begin
      X := CurX + Coord.W*XTexScale;
      Y := CurY - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := Color;
      U := Coord.U + Coord.W{ - 0/XTexScale}; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+3] do begin
      X := CurX + Coord.W*XTexScale;
      Y := CurY + Coord.H*YTexScale - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := Color;
      U := Coord.U + Coord.W{ - 0/XTexScale}; V := Coord.V + Coord.H{ - 0/YTexScale};
    end;
    with TLocalVB(VBPTR^)[i*4+2] do begin
      X := CurX;
      Y := CurY + Coord.H*YTexScale -0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := Color;
      U := Coord.U; V := Coord.V + Coord.H{ - 0/YTexScale};
    end;
    CurX := CurX + Coord.W*XTexScale;
  end;
  VStatus := tsTesselated;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

{ TColoredTextMesh }

procedure TColoredTextMesh.SetText(const NewText: string);
var i, StrLen: Integer;
begin
  if Markup = nil then Markup := TSimpleMarkup.Create;
  if NewText = Text then Exit;
  Text := NewText;
  Markup.FormattedText := Text;
  StrLen := Length(Markup.ClearedText);
  StrHLen := 0;
  for i := 0 to Length(Text)-1 do
   StrHLen := StrHLen + UVMap[CharMap[Ord(Text[i+1])]].W * XTexScale;
  TotalVertices := StrLen*4;
  TotalPrimitives := (2*StrLen) + (2*StrLen-2);
  if (TotalVertices = LastTotalVertices) and (VStatus = tsTesselated) then Invalidate(False) else Invalidate(True);
end;

function TColoredTextMesh.Tesselate(const RenderPars: TRenderParameters; VBPTR: Pointer): Integer;
const Depth = 0.1;
type TLocalVB = TTCDTBuffer;
var
  i, CurTag, ColorStackPointer: Integer;
  CurX, CurY, ItalicOffset: Single;
  Coord: TUV;

procedure PushColorStack(const Color: Longword);
begin
  if ColorStackPointer >= MaxColorStack then Exit;
  Inc(ColorStackPointer);
  ColorStack[ColorStackPointer] := Color;
end;

procedure PopColorStack;
begin
  if ColorStackPointer > 0 then Dec(ColorStackPointer);
end;

begin
  Result := 0;
  if Markup = nil then Exit;
//  Assert((UVMap <> nil) and (CharMap <> nil), 'TTextMesh.Tesselate: One of the maps is nil');

//   StrHLen := StrHLen + UVMap[Ord(Text[i+1])-32].W*XTexScale;

{  case XAlign of
    amLeft: CurX := FArea.Left - 0.5;
    amCenter: CurX := FArea.Left - 0.5 + Trunc(RenderPars.ActualWidth*0.5);
    amRight: CurX := RenderPars.ActualWidth - FArea.Left - 0.5;
  end;}

//  if Markup = nil then Markup := TSimpleMarkup.Create;
//  Markup.FormattedText := Text;

  CurX := X-0.5; CurY := Y;

  case TextAlign of
    amCenter: CurX := Curx - Trunc(StrHLen*0.5);
    amRight: CurX := Curx - StrHLen;
  end;

  ColorStackPointer := 0;
  ColorStack[0] := Color;
  ItalicOffset := 0;
  CurTag := 0;

  for i := 0 to Length(Markup.ClearedText)-1 do begin
    while (CurTag < Markup.TotalTags) and (Markup.Tags[CurTag].Position = i) do begin
      case Markup.Tags[CurTag].Kind of
        mtColorSet: PushColorStack((Markup.Tags[CurTag].IData and $FFFFFF) or (ColorStack[ColorStackPointer] and $FF000000));
        mtAlphaColorSet: PushColorStack(Markup.Tags[CurTag].IData);
        mtColorReset: PopColorStack;
        mtItalicSet: ItalicOffset := Markup.Tags[CurTag].IData * 0.005;
        mtItalicReset: ItalicOffset := 0;
      end;
      Inc(CurTag);
    end;
    Coord := UVMap[CharMap[Ord(Markup.ClearedText[i+1])]];
    with TLocalVB(VBPTR^)[i*4] do begin
      X := CurX + Coord.H*YTexScale * ItalicOffset;
      Y := CurY - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := ColorStack[ColorStackPointer];
      U := Coord.U; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+1] do begin
      X := CurX + Coord.W*XTexScale + Coord.H*YTexScale * ItalicOffset;
      Y := CurY - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := ColorStack[ColorStackPointer];
      U := Coord.U + Coord.W{ - 0/XTexScale}; V := Coord.V;
    end;
    with TLocalVB(VBPTR^)[i*4+3] do begin
      X := CurX + Coord.W*XTexScale - Coord.H*YTexScale * ItalicOffset;
      Y := CurY + Coord.H*YTexScale - 0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := ColorStack[ColorStackPointer];
      U := Coord.U + Coord.W{ - 0/XTexScale}; V := Coord.V + Coord.H{ - 0/YTexScale};
    end;
    with TLocalVB(VBPTR^)[i*4+2] do begin
      X := CurX - Coord.H*YTexScale * ItalicOffset;
      Y := CurY + Coord.H*YTexScale -0.5;
      Z := Depth; RHW := 1/Depth;
      DColor := ColorStack[ColorStackPointer];
      U := Coord.U; V := Coord.V + Coord.H{ - 0/YTexScale};
    end;
    CurX := CurX + Coord.W*XTexScale;
  end;
  VStatus := tsTesselated;
  LastTotalIndices := 0;
  LastTotalVertices := TotalVertices;
  Result := LastTotalVertices;
end;

destructor TColoredTextMesh.Free;
begin
  if Markup <> nil then Markup.Free;
end;

end.
