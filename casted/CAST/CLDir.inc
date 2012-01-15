  Height := LitMap[Addr].H shl 5 + 1*Map[Addr].Res shl 5;
  LightHeight := LightHeight + LHIncr;
  if (LightHeight >= Height) then begin
    DotP := 0; if Fade < 4 then Inc(Fade);
    Fade:=0;
    with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z)));
    if Map[Addr].Res = 0 then DotP := DotP * (32 - MinI(32, (LightHeight - Height) shr 3));
  end else begin
//    if Map[Addr].Res > 0 then DotP := 0 else
    with Map[Addr] do DotP := MaxI(0, -( (NX*LV.X + NY*LV.Y + NZ*LV.Z))) * (32-Fade*4*2);
    DotP := (DotP * MaxI(0, (16-Map[Addr].Res))) shr 4;
    LightHeight := Height;
    if Fade > 0 then Dec(Fade);
  end;
//      if j > Area.Top then DotP := (DotP + DotPs[i]) shr 1;
//      if i > Area.Left then DotP := (DotP + OldDotP) shr 1;
//      if (i > Area.Left) and (j > Area.Top) then DotP := (DotP + DotPs[i] + OldDotPs[i-1] + OldDotP) shr 2;
  Lightness.R := Light.R*DotP shr (8+7);
  Lightness.G := Light.G*DotP shr (8+7);
  Lightness.B := Light.B*DotP shr (8+7);
  Map[Addr].Height := MinI(255 shl 5, LightHeight) shr 5;
  LitMap[Addr].R := (DirMap[Addr].R*7*0 + MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12)) shr 0;
  LitMap[Addr].G := (DirMap[Addr].G*7*0 + MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12)) shr 0;
  LitMap[Addr].B := (DirMap[Addr].B*7*0 + MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12)) shr 0;
{  if DirSource = @Map then begin
    DirMap[Addr].R := MinI(255, Map[Addr].R * (Lightness.R+64 shl 6) shr 12);
    DirMap[Addr].G := MinI(255, Map[Addr].G * (Lightness.G+64 shl 6) shr 12);
    DirMap[Addr].B := MinI(255, Map[Addr].B * (Lightness.B+64 shl 6) shr 12);
  end else begin
    DirMap[Addr].R := MinI(255, DirMap[Addr].R * (Lightness.R+64 shl 6) shr 12);
    DirMap[Addr].G := MinI(255, DirMap[Addr].G * (Lightness.G+64 shl 6) shr 12);
    DirMap[Addr].B := MinI(255, DirMap[Addr].B * (Lightness.B+64 shl 6) shr 12);
  end;}
{  Map[Addr].R := 128;
  Map[Addr].G := 255;
  Map[Addr].B := 255;}
