//  XI := ((CX div TileSize div 256) and (MapWidth-1));
//  ZI := ((CZ div TileSize div 256) and (MapHeight-1));
  XI := ((CurX+(MapHeightMask+1)*TileSize shl 8) shr 16{ div TileSize}) and (MapWidthMask);
  ZI := ((CurZ+(MapHeightMask+1)*TileSize shl 8) shr 16{ div TileSize}) and (MapHeightMask);

  XO := ((CurX+(MapHeightMask+1)*TileSize shl 8) shr 8) and (TileSize-1);
  ZO := ((CurZ+(MapHeightMask+1)*TileSize shl 8) shr 8) and (TileSize-1);
  asm
    mov EAX, CurX
    sar EAX, 8
    mov NXI, EAX
    mov EAX, CurZ
    sar EAX, 8
    mov NZI, EAX
  end;

  VBInd := (VBOffset - LongWord(VBPTR)) div 4;

  EZ := NXI;
  TDWordBuffer(VBPTR^)[VBInd] := LongWord((@EZ)^);
  EZ := NZI;
  TDWordBuffer(VBPTR^)[VBInd+2] := LongWord((@EZ)^);
//  VBPTR^[ j*(XAcc+1) + i].X := NXI;
//  VBPTR^[ (j*(XAcc+1) + i)*6+2] := NZI;
  NXI := (XI+1) and (MapWidthMask);
  NZI := (ZI+1) and (MapHeightMask);
  if (XO + ZO) <= TileSize then begin
//    BufferType(VBPTR^)[ j*(XAcc+1) + i].Y := (MapType(Map^)[zi,xi].Height shl TilePower + (MapType(Map^)[nzi,xi].Height - MapType(Map^)[zi,xi].Height) * ZO +
//                                                                       (MapType(Map^)[zi,nxi].Height - MapType(Map^)[zi,xi].Height) * XO) shr TilePower;
    EZ := (MapType(Map^)[zi*1024+xi].Height shl TilePower + (MapType(Map^)[nzi*1024+xi].Height - MapType(Map^)[zi*1024+xi].Height) * ZO +
                                                  (MapType(Map^)[zi*1024+nxi].Height - MapType(Map^)[zi*1024+xi].Height) * XO) shr TilePower;
    TDWordBuffer(VBPTR^)[VBInd+1] := LongWord((@EZ)^);
    NX := (MapType(Map^)[zi*1024+xi].NX shl TilePower + (MapType(Map^)[nzi*1024+xi].NX - MapType(Map^)[zi*1024+xi].NX) * ZO +
                                              (MapType(Map^)[zi*1024+nxi].NX - MapType(Map^)[zi*1024+xi].NX) * XO) div TileSize;
    NY := (MapType(Map^)[zi*1024+xi].NY shl TilePower + (MapType(Map^)[nzi*1024+xi].NY - MapType(Map^)[zi*1024+xi].NY) * ZO +
                                              (MapType(Map^)[zi*1024+nxi].NY - MapType(Map^)[zi*1024+xi].NY) * XO) div TileSize;
    NZ := (MapType(Map^)[zi*1024+xi].NZ shl TilePower + (MapType(Map^)[nzi*1024+xi].NZ - MapType(Map^)[zi*1024+xi].NZ) * ZO +
                                              (MapType(Map^)[zi*1024+nxi].NZ - MapType(Map^)[zi*1024+xi].NZ) * XO) div TileSize;
    CR := (MapType(Map^)[zi*1024+xi].R shl TilePower + (MapType(Map^)[nzi*1024+xi].R - MapType(Map^)[zi*1024+xi].R) * ZO +
                                             (MapType(Map^)[zi*1024+nxi].R - MapType(Map^)[zi*1024+xi].R) * XO) shr TilePower;
    CG := (MapType(Map^)[zi*1024+xi].G shl TilePower + (MapType(Map^)[nzi*1024+xi].G - MapType(Map^)[zi*1024+xi].G) * ZO +
                                             (MapType(Map^)[zi*1024+nxi].G - MapType(Map^)[zi*1024+xi].G) * XO) shr TilePower;
    CB := (MapType(Map^)[zi*1024+xi].B shl TilePower + (MapType(Map^)[nzi*1024+xi].B - MapType(Map^)[zi*1024+xi].B) * ZO +
                                             (MapType(Map^)[zi*1024+nxi].B - MapType(Map^)[zi*1024+xi].B) * XO) shr TilePower;
  end else begin
//    BufferType(VBPTR^)[ j*(XAcc+1) + i].Y := (MapType(Map^)[nzi,nxi].Height shl TilePower + (MapType(Map^)[nzi,xi].Height - MapType(Map^)[nzi,nxi].Height) * (TileSize - XO) +
//                                                                         (MapType(Map^)[zi,nxi].Height - MapType(Map^)[nzi,nxi].Height) * (TileSize - ZO)) shr TilePower;
    EZ := (MapType(Map^)[nzi*1024+nxi].Height shl TilePower + (MapType(Map^)[nzi*1024+xi].Height - MapType(Map^)[nzi*1024+nxi].Height) * (TileSize - XO) +
                                                    (MapType(Map^)[zi*1024+nxi].Height - MapType(Map^)[nzi*1024+nxi].Height) * (TileSize - ZO)) shr TilePower;
    TDWordBuffer(VBPTR^)[VBInd+1] := LongWord((@EZ)^);
    NX := (MapType(Map^)[nzi*1024+nxi].NX shl TilePower + (MapType(Map^)[nzi*1024+xi].NX - MapType(Map^)[nzi*1024+nxi].NX) * (TileSize - XO) +
                                                (MapType(Map^)[zi*1024+nxi].NX - MapType(Map^)[nzi*1024+nxi].NX) * (TileSize - ZO)) div TileSize;
    NY := (MapType(Map^)[nzi*1024+nxi].NY shl TilePower + (MapType(Map^)[nzi*1024+xi].NY - MapType(Map^)[nzi*1024+nxi].NY) * (TileSize - XO) +
                                                (MapType(Map^)[zi*1024+nxi].NY - MapType(Map^)[nzi*1024+nxi].NY) * (TileSize - ZO)) div TileSize;
    NZ := (MapType(Map^)[nzi*1024+nxi].NZ shl TilePower + (MapType(Map^)[nzi*1024+xi].NZ - MapType(Map^)[nzi*1024+nxi].NZ) * (TileSize - XO) +
                                                (MapType(Map^)[zi*1024+nxi].NZ - MapType(Map^)[nzi*1024+nxi].NZ) * (TileSize - ZO)) div TileSize;
    CR := (MapType(Map^)[nzi*1024+nxi].R shl TilePower + (MapType(Map^)[nzi*1024+xi].R - MapType(Map^)[nzi*1024+nxi].R) * (TileSize - XO) +
                                               (MapType(Map^)[zi*1024+nxi].R - MapType(Map^)[nzi*1024+nxi].R) * (TileSize - ZO)) shr TilePower;
    CG := (MapType(Map^)[nzi*1024+nxi].G shl TilePower + (MapType(Map^)[nzi*1024+xi].G - MapType(Map^)[nzi*1024+nxi].G) * (TileSize - XO) +
                                               (MapType(Map^)[zi*1024+nxi].G - MapType(Map^)[nzi*1024+nxi].G) * (TileSize - ZO)) shr TilePower;
    CB := (MapType(Map^)[nzi*1024+nxi].B shl TilePower + (MapType(Map^)[nzi*1024+xi].B - MapType(Map^)[nzi*1024+nxi].B) * (TileSize - XO) +
                                               (MapType(Map^)[zi*1024+nxi].B - MapType(Map^)[nzi*1024+nxi].B) * (TileSize - ZO)) shr TilePower;
  end;
  ResY := Round(EZ);
{  BufferType(VBPTR^)^[ j*(XAcc+1) + i].Y := HeightMapType(Map^)[xi,zi];}
{  NX := Normals[xi,zi].X;
  NY := Normals[xi,zi].Y;
  NZ := Normals[xi,zi].Z;
  CR := ColorMapType(Map^)[xi,zi].R;
  CG := ColorMapType(Map^)[xi,zi].G;
  CB := ColorMapType(Map^)[xi,zi].B;}

  Lightness.Total := RenderPars.Ambient shl 4;
  Lightness.R := 0; Lightness.G := 0; Lightness.B :=0;
  if LightCount > 0 then for l:=0 to LightCount-1 do with TLightsArray(Lights^)[l] do case LightType of
    ltDirectional: begin
      DotP := -(NX*Direction.X + NY*Direction.Y + NZ*Direction.Z);
      if DotP>0 then begin
        Lightness.R := Lightness.R + R*DotP shr 8;
        Lightness.G := Lightness.G + G*DotP shr 8;
        Lightness.B := Lightness.B + B*DotP shr 8;
        Lightness.Total := Lightness.Total+DotP shr 8;
      end;
    end;
    ltOmniDynamic: begin
      LVX := Location.X - CurX div 256; if abs(LVX) > Range then Continue;
      LVZ := Location.Z - CurZ div 256; if abs(LVZ) > Range then Continue;
      LVY := Location.Y - ResY; if abs(LVY) > Range then Continue;
      DotP := (NX*LVX+NY*LVY+NZ*LVZ);
      if DotP>0 then begin
        SQLV:=LVX*LVX+LVY*LVY+LVZ*LVZ;
        if (SQLV>0) and (SQLV<RangeSQ) then begin
          DotP:=Round(DotP / SQLV * 1024);
          Lightness.R := Lightness.R + R*DotP shr 4;// div SQLV;
          Lightness.G := Lightness.G + G*DotP shr 4;// div SQLV;
          Lightness.B := Lightness.B + B*DotP shr 4;// div SQLV;
          Lightness.Total := Lightness.Total + DotP shr 4;// div SQLV;
        end;
      end;
    end;
  end;

  CR:={round(}(CR*Lightness.Total shr 6 + Lightness.R) shr 6;//) shr 9;
  CG:={round(}(CG*Lightness.Total shr 6 + Lightness.G) shr 6;//) shr 9;
  CB:={round(}(CB*Lightness.Total shr 6 + Lightness.B) shr 6;//) shr 9;

  if CR>255 then CR:=255;
  if CG>255 then CG:=255;
  if CB>255 then CB:=255;
{  BufferType(VBPTR^)[ j*(XAcc+1) + i].DColor:=CR shl 16+CG shl 8+CB;
  BufferType(VBPTR^)[ j*(XAcc+1) + i].U:=CurX div 256 / TileSize / TextureZoom;
  BufferType(VBPTR^)[ j*(XAcc+1) + i].V:=CurZ div 256 / TileSize / TextureZoom;}
  TDWordBuffer(VBPTR^)[VBInd+3] := CR shl 16+CG shl 8+CB;
  EX := TextureK * OneOver256;
  TSingleBuffer(VBPTR^)[VBInd+4] := EX * CurX;
  TSingleBuffer(VBPTR^)[VBInd+5] := EX * CurZ;

