TSynAsmShader   {first Identifier is considered to be the Class Name }
tk              {second Identifier is considered to be the Identifier Prefix }
IdentStart '_', 'a'..'z', 'A'..'Z':: '_', '0'..'9', 'a'..'z', 'A'..'Z'::

TOKENTYPES
Identifier Foreground=clRed
Comment Style=[fsItalic]|Foreground=clNavy
Space
Key Style=[fsBold]
Macro Background=clSilver|Foreground=clBlue|Style=[fsUnderline, fsItalic]
Regs Background=clSilver|Foreground=clGreen|Style=[fsUnderline, fsItalic]
|><|

KEYS
vs_1
vs_2
def
add
dp3
dp4
dst
expp
lit
logp
mad
max
min
mov
mul
rcp
rsq
sge
slt
sub
|><|

KEYS Macro
exp
frc
log
m3x2
m3x3
m3x4
m4x3
m4x4
|><|

KEYS Regs
A0
C
R0
R1
R2
R3
R4
R5
R6
R7
R8
R9
R10
R11
V0
V1
V2
V3
V4
V5
V6
V7
V8
V9
V10
V11
V12
V13
V14
V15

|><|

CHARS

'A'..'Z', 'a'..'z', '_':: Ident
BeginProc
  fTokenID := IdentKind((fLine + Run));
  inc(Run, fStringLen);
  while Identifiers[fLine[Run]] do
    Inc(Run);
EndProc

|><|

ENCLOSEDBY

Comment,SingleLineComment,\\,
Comment,CStyleComment,/*,*/,MultiLine

|><|

SAMPLESOURCE
vs_1.1
def c[0], 1.0, 1.0, 1.0, 0.0
mov r0, c[15]
dp3 r2, v0, v[A0]
m4x4 r1, c[0]
|><|

