  asm
//       U pipe                               V pipe
    push         ESI;                         push         EDI
    push         EBX;                         mov          ECX, TilePower

    mov          EAX, CurX;                   mov          EBX, CurZ
    sar          EAX, 8;                      sar          EBX, 8
    mov          NXI, EAX;                    mov          NZI, EBX
    
    cmp          EAX, 0
    jnl          @XPositive
    xor          EAX, EAX
    jmp          @XInBounds
@XPositive:
    cmp          EAX, MapLengthX
    jng          @XInBounds
    mov          EAX, MapLengthX
@XInBounds:

    cmp          EBX, 0
    jnl          @ZPositive
    xor          EBX, EBX
    jmp          @ZInBounds
@ZPositive:
    cmp          EBX, MapLengthZ
    jng          @ZInBounds
    mov          EBX, MapLengthZ
@ZInBounds:

                                              //mov          EDI, MapHeightMask
    mov          ESI, EAX;                    mov          EDI, EBX
                                              //mov          EBX, EDI
    sar          ESI, CL;                     sar          EDI, CL
    and          ESI, MapWidthMask;           and          EDI, MapHeightMask     //  ESI/EDI - X/Z Index
    mov          XI, ESI;                     mov          ZI, EDI
    sar          EAX, 1;                      sar          EBX, 1
    and          EAX, 127;                    and          EBX, 127
    mov          XO, EAX;                     mov          ZO, EBX

    mov          ECX, MapPower;               pxor         MM0, MM0

{    mov          EAX, ESI;                    mov          EBX, EAX
    inc          EAX;                         shl          EBX, CL                // EBX - XI*MapWidth*2
    and          EAX, MapWidthMask;           mov          EDX, EDI
    shl          EBX, 3
    shl          EAX, CL;                     mov          XI_ZI, EBX
    add          EAX, EDX;
    shl          EDX, 3
    add          XI_ZI, EDX
    sar          EDX, 3
    inc          EDX;                         shl          EAX, 3
    mov          NXI_ZI, EAX;                 and          EDX, MapHeightMask;
    shl          EDX, 3
    add          EBX, EDX                     pxor         MM0, MM0
    mov          XI_NZI, EBX;                 //shl          XI_ZI, 3}


    shl          EDI, CL;                     shl          ESI, 2           //optimize
    mov          EAX, EDI;                    mov          EBX, ESI
    add          EAX, ESI;                    add          EBX, 4
    mov          XI_ZI, EAX;                  and          EBX, MapXSizeMask

    add          EBX, EDI;                    add          EAX, MapYStepBytes
    mov          NXI_ZI, EBX;                 and          EAX, MapZSizeMask
    mov          XI_NZI, EAX;

//    if (XO + ZO) <= TileSize then begin
    mov          EAX, 128
    sub          EAX, XO
    cmp          EAX, ZO
    ja           @VertexSet1                    //optimize

    mov          EDX, EDI;                    mov          EBX, 128
    add          ESI, 4;                      sub          EBX, ZO
    and          ESI, MapXSizeMask;           add          EDX, MapYStepBytes
    and          EDX, MapZSizeMask;           add          ESI, EDX;
    mov          XI_ZI, ESI;                  mov          XO, EBX;
    mov          ZO, EAX;                     jmp          @VertexSet2

@VertexSet1:
    mov          ESI, XI_ZI
@VertexSet2:
//    VertexBuf^[ j*(XAcc+1) + i].Y:= (HeightMap[xi,zi] shl TilePower + (HeightMap[nxi,zi] - HeightMap[xi,zi]) * XO + (HeightMap[xi,nzi] - HeightMap[xi,zi]) * ZO) shr TilePower;
//    mov          ESI, XI_ZI;
    mov          EDI, NXI_ZI;                 movd         MM4, XO
    mov          EDX, MapOffset;              movd         MM5, ZO

//           and          EAX, 255

//***
    mov          EBX, dword ptr [EDX + ESI]                                  // EBX = Map[XI_ZI].Y
    mov          EAX, dword ptr [EDX + EDI];                                 // EAX = Map[NXI_ZI].Y
//    and          ECX, 255
    shr          EBX, 24
//    and          EAX, 255
    shr          EAX, 24

    mov          ECX, XI_NZI
    sub          EAX, EBX
    shl          EAX, 16;

//    movzx        AX, byte ptr [EDX + ECX+3];
    xor          AX, AX
    mov          AL, byte ptr [EDX + ECX+3];
    mov          ECX, LHeightPower
    movd         MM7, ECX

    sub          AX, BX;                      movq         MM2, MM4
    movd         MM1, EAX;                    psllq        MM2, 16
    psllw        MM1, MM7
    movq         MM3, MM5;                    punpcklwd    MM5, MM5
    por          MM2, MM3;                    punpcklwd    MM4, MM4
    pmaddwd      MM1, MM2;                    punpckldq    MM4, MM4
    movd         EAX, MM1
    sar          EAX, 7;                      punpckldq    MM5, MM5

    shl          EBX, CL
    add          EAX, EBX

{            punpcklwd    MM5, MM5
            punpcklwd    MM4, MM4
            punpckldq    MM4, MM4

            punpckldq    MM5, MM5

           mov          EAX, dword ptr [EDX + ESI]                                  // ECX = Map[XI_ZI].Y
           movd         MM1, EAX
           shr          eax, 24
           shl          eax, 5}
    mov          ResY, EAX
//***

//    movd         MM3, dword ptr [EDX + ESI];   movd         MM1, dword ptr [EDX + EDI]
    mov          EAX, dword ptr [EDX + ESI];
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM3, ESI
    mov       EAX, dword ptr [EDX + EDI]
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM1, ESI
// Original:  00000000 AAAAAARR RRRRGGGG GGBBBBBB
//  AAAAAA00 RRRRRR00 GGGGGG00 BBBBBB00
    

    mov          ESI, XI_NZI;                 punpcklbw    MM3, MM0
    punpcklbw    MM1, MM0;
    psubw        MM1, MM3;                    //psubw        MM6, MM7
    pmullw       MM1, MM4;                    //pmullw       MM6, MM4

//    movd         MM2, dword ptr [EDX + ESI]
    mov       EAX, dword ptr [EDX + ESI]
    shl       EAX, 2;    mov       ESI, EAX;         and       ESI, 63 shl 2
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 10;   or     ESI, ECX
    shl       EAX, 2;    mov       ECX, EAX;         and       ECX, 63 shl 18;   or     ESI, ECX
    shl       EAX, 2;    and       EAX, 63 shl 26;   or        ESI, EAX
    movd      MM2, ESI
    punpcklbw    MM2, MM0

    psubw        MM2, MM3
    pmullw       MM2, MM5
    paddw        MM1, MM2
    psraw        MM1, 7

    paddw        MM1, MM3;

    pop     EBX
    pop     EDI
    pop     ESI

    pxor         MM0, MM0

    mov          ecx, Smth
    cmp          ecx, 0
    jz           @NoSmooth

    movd         MM6, OldColor
    punpcklbw    MM6, MM0

@SmoothLoop:
    paddw        MM1, MM6
    psraw        MM1, 1

    dec          ecx
    jnz          @SmoothLoop          

@NoSmooth:
    packuswb     MM1, MM0

    mov          EDX,VBOffset
//    psllq        MM1, 8
{    mov          EAX, ResY
    shr          EAX, cl
    shl          EAX, 24
    movd         mm2, eax
    por          mm1, mm2}
    movd         dword ptr [EDX+12], MM1
    movd         OldColor, MM1
//    mov          dword ptr [EDX+12], $FFFFFFFF
    emms
    fild         NXI
    fstp         dword ptr [EDX+0]                   //  VertexBuf^[ j*(XAcc+1) + i].X := CurX shr 8;
    fild         NXI
    fmul         TextureK
    fstp         dword ptr [EDX+16]
    fild         ResY
    fstp         dword ptr [EDX+4]                   //  VertexBuf^[ j*(XAcc+1) + i].Y := ResY;
    fild         NZI
    fstp         dword ptr [EDX+8]                   //  VertexBuf^[ j*(XAcc+1) + i].Z := CurZ shr 8;
    fild         NZI
    fmul         TextureK
    fstp         dword ptr [EDX+20]
  end;

{  CR:=(CR*Lightness.Total shr 6 + Lightness.R) shr 6;
  CG:=(CG*Lightness.Total shr 6 + Lightness.G) shr 6;
  CB:=(CB*Lightness.Total shr 6 + Lightness.B) shr 6;}

{  CR:=(CR*Lightness.Total + Lightness.R) shr 9;
  CG:=(CG*Lightness.Total + Lightness.G) shr 9;
  CB:=(CB*Lightness.Total + Lightness.B) shr 9;}

{  if CR>255 then CR:=255;
  if CG>255 then CG:=255;
  if CB>255 then CB:=255;}

//  VertexBuf^[ j*(XAcc+1) + i].Y := ResY;
//  VertexBuf^[ j*(XAcc+1) + i].DColor:=CR shl 16+CG shl 8+CB;
//  VertexBuf^[ j*(XAcc+1) + i].U:=CurX div 256 / TileSize / TextureZoom;
//  VertexBuf^[ j*(XAcc+1) + i].V:=CurZ div 256 / TileSize / TextureZoom;

