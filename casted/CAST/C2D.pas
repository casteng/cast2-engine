{$Include GDefines}
{$Include CDefines}
// Unit for standard 2D graphics
unit C2D;

interface

uses Basics, CAST, CRes, CTypes, CRender, CTess2D, CTess  , TextFile ;

const
  ppkMoveTo = 1; ppkLineTo = 2; ppkBar = 3; ppkCircle = 4; ppkText = 5; ppkChangeFont = 6; ppkColoredText = 7;
  TotalPrimitiveKinds = 7;

  MaxViewport = 31;

type
  TPlanePrimitive = packed record
    Kind: Longword;
    X, Y, U, V: Single;
    Color: Longword;
    Data: Pointer;
    Passes: TRenderPasses;
//    UVMap: TUV;
//    Material: TMaterial;
  end;

  TViewport = packed record
    X1, Y1, X2, Y2: Single;
  end;

  T2DFont = class
    UVMap: TUVMap; TotalUVs: Longword;
    CharMap: TCharMap; TotalCharacters: Longword;
    XScale, YScale: Single;
    constructor Create;
    procedure SetMapResources(const Resources: TResourceManager; const AUVMapRes, ACharMapRes: Integer); virtual;
    procedure SetScale(AXScale, AYScale: Single); virtual;
  end;

  TScreen = class(TItem)
    ViewportStack: array[0..MaxViewport] of TViewport;
    TotalViewports: Integer;
    Viewport: ^TViewport;
    Color: Longword;
    PrimitiveItems: array[1..TotalPrimitiveKinds] of array of TItem;
    TotalPrimitiveItems, AllocPrimitiveItems: array[1..TotalPrimitiveKinds] of Integer;
    PrimitiveMeshes: array[1..TotalPrimitiveKinds] of CTesselator;
//    LineItems, BarItems, TextItems: array of TItem;
//    TotalLineItems, TotalBarItems, TotalTextItems, AllocLineItems, AllocBarItems, AllocTextItems,
    TotalItems: Integer;
    Primitives: array of TPlanePrimitive; TotalPrimitives: Integer;
    Fonts: array of T2DFont; TotalFonts: Integer;
    Font: T2DFont;
    Material: TMaterial;
    constructor Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil); 

    function AddFont(const Resources: TResourceManager; const AUVMapRes, ACharMapRes: Integer; const XScale, YScale: Single): Integer; virtual;

    procedure AddPrimitive(const Kind: Longword; const X, Y, U, V: Single; const Data: Pointer = nil); virtual;

    function NewItem(const PrimitiveKind: Integer): TItem; virtual;
{    function NewLineItem: TItem; virtual;
    function NewBarItem: TItem; virtual;
    function NewTextItem(const Colored: Boolean): TItem; virtual;}

    procedure SetViewport(const X1, Y1, X2, Y2: Single); virtual;
    procedure PopViewport; virtual;
    procedure SetColor(const AColor: Longword); virtual;
    procedure SetUV(const AUV: TUV); virtual;
    procedure MoveTo(const X, Y: Single); virtual;
    procedure LineTo(const X, Y: Single); virtual;
    procedure DrawLine(const X1, Y1, X2, Y2: Single); virtual;
    procedure Bar(X1, Y1, X2, Y2: Single); virtual;
//    procedure Polygon(
    procedure SetFont(const FontIndex: Integer); virtual;
    procedure DrawText(const X, Y: Single; const Str: PStr); virtual;
    procedure DrawColoredText(const X, Y: Single; const Str: PStr); virtual;
    procedure Render(Renderer: TRenderer); override;
    procedure Clear; virtual;    // Clears all primitives and viewports
    procedure CleanUp; virtual;  // Clears all items
    destructor Free; override;
  private
    CurrentX, CurrentY, CurrentU, CurrentV: Single; CurrentColor: Longword;
    DiscardMeshes: Boolean;
    UV: TUV;
  end;

implementation

{ T2DFont }

constructor T2DFont.Create;
begin
  TotalUVs := 0; TotalCharacters := 0;
  UVMap := nil; CharMap := nil;
  SetScale(128, 128);
end;

procedure T2DFont.SetMapResources(const Resources: TResourceManager; const AUVMapRes, ACharMapRes: Integer);
var TRes: TArrayResource;
begin
  if Resources[AUVMapRes] is TFontResource then TRes := Resources[AUVMapRes] as TFontResource else Exit;
  TotalUVs := TRes.TotalElements;
  UVMap := TUVMap(TRes.Data);
  if Resources[ACharMapRes] is TCharMapResource then TRes := Resources[ACharMapRes] as TCharMapResource else Exit;
  TotalCharacters := TRes.TotalElements;
  CharMap := TCharMap(TRes.Data);
end;

procedure T2DFont.SetScale(AXScale, AYScale: Single);
begin
  XScale := AXscale; YScale := AYScale;
end;

{ TScreen }

constructor TScreen.Create(AName: TShortName; AWorld: TWorld; AParent: TItem = nil);
begin
  inherited Create(AName, AWorld, AParent);
  Order := 2000;
  Clear;
  TotalViewports := -1;
  SetViewport(0, 0, AWorld.Renderer.RenderPars.ActualWidth-1, AWorld.Renderer.RenderPars.ActualHeight-1);
  DiscardMeshes := True;
  TotalFonts := 0;
// ppkMoveTo = 1; ppkLineTo = 2; ppkBar = 3; ppkCircle = 4; ppkText = 5; ppkChangeFont = 6; ppkColoredText = 7;
  PrimitiveMeshes[ppkMoveTo] := nil;
  PrimitiveMeshes[ppkLineTo] := TLineMesh;
  PrimitiveMeshes[ppkBar] := TTetragonMesh;
  PrimitiveMeshes[ppkCircle] := nil;
  PrimitiveMeshes[ppkText] := TTextMesh;
  PrimitiveMeshes[ppkChangeFont] := nil;
  PrimitiveMeshes[ppkColoredText] := TColoredTextMesh;
end;

function TScreen.NewItem(const PrimitiveKind: Integer): TItem;
begin
  Inc(TotalItems);
  Inc(TotalPrimitiveItems[PrimitiveKind]);
  if AllocPrimitiveItems[PrimitiveKind] > TotalPrimitiveItems[PrimitiveKind]-1 then begin
// If item is already created then clear it and reuse  
    Result := PrimitiveItems[PrimitiveKind, TotalPrimitiveItems[PrimitiveKind]-1];
    if PrimitiveKind = ppkLineTo then TLineMesh(Result.CurrentLOD).Clear;
    Result.SetRenderPasses(RenderPasses);
    if DiscardMeshes then begin
      Result.CurrentLOD.Invalidate(True);
    end;
    Exit;
  end;

  Result := TItem.Create('', World);
  Result.Order := Order;
//  Result.CullMode := cmNone;
  Result.SetRenderPasses(RenderPasses);

  Result.AddLOD(PrimitiveMeshes[PrimitiveKind].Create(''));
//  Result.AddLOD(TTetragonMesh.Create);

  Result.SetMaterial(0, 'Default');
  World.ChooseManager(Result);

  Inc(AllocPrimitiveItems[PrimitiveKind]);
  SetLength(PrimitiveItems[PrimitiveKind], AllocPrimitiveItems[PrimitiveKind]);
  PrimitiveItems[PrimitiveKind, TotalPrimitiveItems[PrimitiveKind]-1] := Result;
end;

(*function TScreen.NewLineItem: TItem;
var i: Integer;
begin
  Inc(TotalItems); Inc(TotalLineItems);
  if AllocLineItems > TotalLineItems-1 then begin
    Result := LineItems[TotalLineItems-1];
    TLineMesh(Result.CurrentLOD).Clear;
    Result.SetRenderPasses(RenderPasses);
    if DiscardMeshes then begin
      Result.CurrentLOD.VStatus := tsSizeChanged;
      Result.CurrentLOD.IStatus := tsSizeChanged;
    end;
    Exit;
  end;

  Result := TItem.Create('', World);
  Result.Order := Order;
//  Result.CullMode := cmNone;
  Result.SetRenderPasses(RenderPasses);

  Result.AddLOD(TLineMesh.Create);
//  Result.AddLOD(TTetragonMesh.Create);

  Result.SetMaterial(0, 'Default');
  World.ChooseManager(Result);

  Inc(AllocLineItems); SetLength(LineItems, AllocLineItems);
  LineItems[TotalLineItems-1] := Result;
end;

function TScreen.NewBarItem: TItem;
var i: Integer;
begin
  Inc(TotalItems); Inc(TotalBarItems);
  if AllocBarItems > TotalBarItems-1 then begin
    Result := BarItems[TotalBarItems-1];
    Result.SetRenderPasses(RenderPasses);
    if DiscardMeshes then begin
      Result.CurrentLOD.VStatus := tsSizeChanged;
      Result.CurrentLOD.IStatus := tsSizeChanged;
    end;
    Exit;
  end;

  Result := TItem.Create('', World);
  Result.Order := Order;
//  Result.CullMode := cmNone;
  Result.SetRenderPasses(RenderPasses);

  Result.AddLOD(TTetragonMesh.Create);

  Result.SetMaterial(0, 'Default');
  World.ChooseManager(Result);

  Inc(AllocBarItems); SetLength(BarItems, AllocBarItems);
  BarItems[TotalBarItems-1] := Result;
end;

function TScreen.NewTextItem(const Colored: Boolean): TItem;
var i: Integer;
begin
  Inc(TotalItems); Inc(TotalTextItems);
  if AllocTextItems > TotalTextItems-1 then begin
    Result := TextItems[TotalTextItems-1];
    Result.SetRenderPasses(RenderPasses);
    if DiscardMeshes then begin
      Result.CurrentLOD.VStatus := tsSizeChanged;
      Result.CurrentLOD.IStatus := tsSizeChanged;
    end;
    Exit;
  end;

  Result := TItem.Create('', World);
  Result.Order := Order;
//  Result.CullMode := cmNone;
  Result.SetRenderPasses(RenderPasses);

  if Colored then Result.AddLOD(TColoredTextMesh.Create) else Result.AddLOD(TTextMesh.Create);

  Result.SetMaterial(0, Material);
  World.ChooseManager(Result);

  Inc(AllocTextItems); SetLength(TextItems, AllocTextItems);
  TextItems[TotalTextItems-1] := Result;
end;*)

procedure TScreen.MoveTo(const X, Y: Single);
begin
  AddPrimitive(ppkMoveTo, X, Y, UV.U, UV.V);
end;

procedure TScreen.LineTo(const X, Y: Single);
begin
  AddPrimitive(ppkLineTo, X, Y, UV.U + UV.W, UV.V + UV.H);
end;

procedure TScreen.Bar(X1, Y1, X2, Y2: Single);
var Temp: Single;
begin
  if X1 > X2 then begin Temp := X2; X2 := X1; X1 := Temp; end;
  if Y1 > Y2 then begin Temp := Y2; Y2 := Y1; Y1 := Temp; end;
  MoveTo(X1, Y1);
  AddPrimitive(ppkBar, X2, Y2, UV.U + UV.W, UV.V + UV.H);
end;

procedure TScreen.DrawLine(const X1, Y1, X2, Y2: Single);
begin
  MoveTo(X1, Y1); LineTo(X2, Y2);
end;

procedure TScreen.SetFont(const FontIndex: Integer);
begin
  AddPrimitive(ppkChangeFont, 0, 0, 0, 0, Pointer(FontIndex));
end;

procedure TScreen.DrawText(const X, Y: Single; const Str: PStr);
begin
  if (Font = nil) or (Font.TotalUVs = 0) then Exit;
  if Str = nil then Exit;
  AddPrimitive(ppkText, X, Y, 0, 0, Str);
end;

procedure TScreen.DrawColoredText(const X, Y: Single; const Str: PStr);
begin
  if (Font = nil) or (Font.TotalUVs = 0) then Exit;
  if Str = nil then Exit;
  AddPrimitive(ppkColoredText, X, Y, 0, 0, Str);
end;

procedure TScreen.Render(Renderer: TRenderer);
var i: Integer; CP: TPlanePrimitive; CurItem: TItem;
begin
  CurItem := nil;
//
  TotalItems := 0;
  for i := 1 to TotalPrimitiveKinds do TotalPrimitiveItems[i] := 0;
  for i := 0 to TotalPrimitives-1 do begin
    CP := Primitives[i];
    case CP.Kind of
      ppkMoveTo: begin
        if CurItem <> nil then CurItem.Render(Renderer);
        CurItem := nil;
        CurrentX := CP.X; CurrentY := CP.Y;
        CurrentU := CP.U; CurrentV := CP.V;
        CurrentColor := CP.Color;
      end;
      ppkLineTo: begin
        if CurItem = nil then begin
          CurItem := NewItem(ppkLineTo);
          CurItem.SetRenderPasses(CP.Passes);
          TLineMesh(CurItem.CurrentLOD).AddPoint(CurrentX, CurrentY, CurrentColor);
        end;
        TLineMesh(CurItem.CurrentLOD).AddPoint(CP.X, CP.Y, CP.Color);
      end;
      ppkBar: begin
        if CurItem <> nil then CurItem.Render(Renderer);
        CurItem := NewItem(ppkBar);
        CurItem.SetRenderPasses(CP.Passes);
        TTetragonMesh(CurItem.CurrentLOD).SetUVRectangle(CurrentU, CurrentV, CP.U, CP.V);
        TTetragonMesh(CurItem.CurrentLOD).SetRectangle(CurrentX, CurrentY, CP.X, CP.Y, CurrentColor);
        if CurItem <> nil then CurItem.Render(Renderer);
        CurItem := nil;
      end;
      ppkText, ppkColoredText: begin
        if CurItem <> nil then CurItem.Render(Renderer);
        CurItem := NewItem(CP.Kind);
        CurItem.SetRenderPasses(CP.Passes);
        if Font <> nil then TTextMesh(CurItem.CurrentLOD).SetMaps(Font.UVMap, Font.CharMap);
        TTextMesh(CurItem.CurrentLOD).SetText(string(CP.Data^));
        TTextMesh(CurItem.CurrentLOD).SetLayout(CP.X, CP.Y, amLeft, amLeft, amLeft);
        TTextMesh(CurItem.CurrentLOD).Color := CP.Color;
        TTextMesh(CurItem.CurrentLOD).XTexScale := Font.XScale;
        TTextMesh(CurItem.CurrentLOD).YTexScale := Font.YScale;
        if CurItem <> nil then CurItem.Render(Renderer);
        CurItem := nil;
      end;
      ppkChangeFont: begin
        if (Integer(CP.Data) >= 0) and (Integer(CP.Data) < TotalFonts) then Font := Fonts[Integer(CP.Data)];
      end;
    end;
  end;
  if CurItem <> nil then CurItem.Render(Renderer);
  DiscardMeshes := False;
end;

procedure TScreen.Clear;
//var i: Integer;
begin
  TotalPrimitives := 0;
  TotalViewports := -1;
  Viewport := nil;
//  for i := 0 to TotalItems-1 do World.DeleteItem(Items[i].ID);
end;

procedure TScreen.SetViewport(const X1, Y1, X2, Y2: Single);
begin
  Assert(TotalViewports < MaxViewport);
  Inc(TotalViewports);
  Viewport := @ViewportStack[TotalViewports];
  Viewport.X1 := X1; Viewport.Y1 := Y1; Viewport.X2 := X2; Viewport.Y2 := Y2;
  if TotalViewPorts > 0 then begin
    Viewport.X1 := Viewport.X1 + ViewportStack[TotalViewports-1].X1;
    Viewport.Y1 := Viewport.Y1 + ViewportStack[TotalViewports-1].Y1;
    Viewport.X2 := Viewport.X2 + ViewportStack[TotalViewports-1].X1;
    Viewport.Y2 := Viewport.Y2 + ViewportStack[TotalViewports-1].Y1;
  end;
end;

procedure TScreen.PopViewport;
begin
  if TotalViewports > 0 then Dec(TotalViewports)
 else Log('TScreen.PopViewport: Viewports stack is empty', lkError) ;
  Viewport := @ViewportStack[TotalViewports];
end;

procedure TScreen.SetColor(const AColor: Longword);
begin
  Color := AColor;
end;

procedure TScreen.SetUV(const AUV: TUV);
begin
  UV := AUV;
end;

procedure TScreen.AddPrimitive(const Kind: Longword; const X, Y, U, V: Single; const Data: Pointer);
begin
  Inc(TotalPrimitives); SetLength(Primitives, TotalPrimitives);
  Primitives[TotalPrimitives-1].Kind := Kind;
  Primitives[TotalPrimitives-1].X := Viewport.X1 + X;
  Primitives[TotalPrimitives-1].Y := Viewport.Y1 + Y;
  Primitives[TotalPrimitives-1].U := U;
  Primitives[TotalPrimitives-1].V := V;
  Primitives[TotalPrimitives-1].Color := {P$FFFFFF00;//}Color;
  Primitives[TotalPrimitives-1].Data := Data;
  Primitives[TotalPrimitives-1].Passes := RenderPasses;
//  Primitives[TotalPrimitives-1].UV := UV;
//  Primitives[TotalPrimitives-1].UVFrame := UVFrame;
end;

procedure TScreen.CleanUp;
var i, j: Integer;
begin
  for j := 1 to TotalPrimitiveKinds do begin
    for i := 0 to TotalPrimitiveItems[j]-1 do PrimitiveItems[j, i].Free;
    SetLength(PrimitiveItems[j], 0);
    TotalPrimitiveItems[j] := 0;
    AllocPrimitiveItems[j] := 0;
  end;
  SetLength(Primitives, 0); TotalPrimitives := 0;
  TotalItems := 0;
end;

destructor TScreen.Free;
begin
  CleanUp;
end;

function TScreen.AddFont(const Resources: TResourceManager; const AUVMapRes, ACharMapRes: Integer; const XScale, YScale: Single): Integer;
var i: Integer; TFRes, TCMRes: TArrayResource;
begin
  Result := -1;
  if (AUVMapRes = -1) or (ACharMapRes = -1) then Exit;
  if Resources[AUVMapRes] is TFontResource then TFRes := Resources[AUVMapRes] as TFontResource else Exit;
  if Resources[ACharMapRes] is TCharMapResource then TCMRes := Resources[ACharMapRes] as TCharMapResource else Exit;
  for i := 0 to TotalFonts - 1 do
   if (Pointer(Fonts[i].UVMap) = TFRes.Data) and (Pointer(Fonts[i].CharMap) = TCMRes.Data) and
      (Fonts[i].XScale = XScale) and (Fonts[i].YScale = YScale) then begin
     Result := i; Exit;
   end;
  Font := T2DFont.Create;
  Font.SetMapResources(Resources, AUVMapRes, ACharMapRes);
  Font.SetScale(XScale, YScale);
  Inc(TotalFonts); SetLength(Fonts, TotalFonts);
  Fonts[TotalFonts-1] := Font;
  Result := TotalFonts-1;
end;

end.
