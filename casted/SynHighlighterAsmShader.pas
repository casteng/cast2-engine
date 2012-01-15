{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Code template generated with SynGen.
The original code is: SynHighlighterAsmShader.pas, released 2010-02-11.
Description: Syntax Parser/Highlighter
The initial author of this file is i.
Copyright (c) 2010, all rights reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id: $

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

-------------------------------------------------------------------------------}

unit SynHighlighterAsmShader;

{$I SynEdit.inc}

interface

uses
{$IFDEF SYN_CLX}
  QGraphics,
  QSynEditTypes,
  QSynEditHighlighter,
{$ELSE}
  Graphics,
  SynEditTypes,
  SynEditHighlighter,
  SynUnicode,
{$ENDIF}
  SysUtils,
  Classes;

type
  TtkTokenKind = (
    tkComment,
    tkIdentifier,
    tkKey,
    tkMacro,
    tkModifier,
    tkNull,
    tkRegs,
    tkSpace,
    tkUnknown);

  TRangeState = (rsUnKnown, rsSingleLineComment, rsCStyleComment);

const
  MaxKey = 72;

type
  TSynAsmShader = class(TSynCustomHighlighter)
  private
    fRange: TRangeState;
    fTokenID: TtkTokenKind;
    fCommentAttri: TSynHighlighterAttributes;
    fIdentifierAttri: TSynHighlighterAttributes;
    fKeyAttri: TSynHighlighterAttributes;
    fMacroAttri: TSynHighlighterAttributes;
    fModifierAttri: TSynHighlighterAttributes;
    fRegsAttri: TSynHighlighterAttributes;
    fSpaceAttri: TSynHighlighterAttributes;
    fKeyMacros, fKeyRegs, fKeyWords: TStrings;
    fModifiers: TStrings;
    function IsCharIdent(ch: WideChar): Boolean;
    procedure IdentProc;
    procedure ModifierProc;
    procedure UnknownProc;
    function IdentKind(pch: PWideChar): TtkTokenKind;
    function ModifierKind(pch: PWideChar): TtkTokenKind;
    procedure NullProc;
    procedure SpaceProc;
    procedure CRProc;
    procedure LFProc;
    procedure SingleLineCommentProc;
    procedure SimpleCommentOpenProc;
    procedure CStyleCommentOpenProc;
    procedure CStyleCommentProc;
  protected
    function GetSampleSource: UnicodeString; override;
    function IsFilterStored: Boolean; override;
  public
    class function GetLanguageName: string; override;
    class function GetFriendlyLanguageName: UnicodeString; override;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
    function GetTokenID: TtkTokenKind;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;

    procedure Next; override;

    function GetRange: Pointer; override;
    procedure ResetRange; override;
    procedure SetRange(Value: Pointer); override;

    function GetEol: Boolean; override;

    function GetToken: UnicodeString; override;

    function GetTokenPos: Integer; override;

  published
    property CommentAttri: TSynHighlighterAttributes read fCommentAttri write fCommentAttri;
    property IdentifierAttri: TSynHighlighterAttributes read fIdentifierAttri write fIdentifierAttri;
    property KeyAttri: TSynHighlighterAttributes read fKeyAttri write fKeyAttri;
    property MacroAttri: TSynHighlighterAttributes read fMacroAttri write fMacroAttri;
    property ModifierAttri: TSynHighlighterAttributes read fModifierAttri write fModifierAttri;
    property RegsAttri: TSynHighlighterAttributes read fRegsAttri write fRegsAttri;
    property SpaceAttri: TSynHighlighterAttributes read fSpaceAttri write fSpaceAttri;
    property KeyMacros: TStrings read fKeyMacros write fKeyMacros;
    property KeyRegs: TStrings read fKeyRegs write fKeyRegs;
    property KeyWords: TStrings read fKeyWords write fKeyWords;
    property Modifiers: TStrings read fModifiers write fModifiers;
  end;
implementation

uses
{$IFDEF SYN_CLX}
  QSynEditStrConst;
{$ELSE}
  SynEditStrConst;
{$ENDIF}

{$IFDEF SYN_COMPILER_3_UP}
resourcestring
{$ELSE}
const
{$ENDIF}
  SYNS_Filter = 'All files (*.*)|*.*';
  SYNS_LangAsmShader = 'Shader Asm';
  SYNS_FriendlyLangAsmShader = 'Shader Asm';
  SYNS_AttrRegs = 'Regs';
  SYNS_AttrMods = 'Mods';

function TSynAsmShader.IdentKind(pch: PWideChar): TtkTokenKind;
var str: UnicodeString;
begin
  fToIdent := pch;
  str := '';
  while CharInSet(pch^, ['a'..'z', 'A'..'Z', '0'..'9']) do begin
    str := str + pch^;
    Inc(pch);
  end;
  fStringLen := pch - fToIdent;

  if fKeyMacros.IndexOf(str) >= 0 then
    Result := tkMacro
  else if fKeyRegs.IndexOf(str) >= 0 then
    Result := tkRegs
  else if fKeyWords.IndexOf(str) >= 0 then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynAsmShader.ModifierKind(pch: PWideChar): TtkTokenKind;
var str: UnicodeString; isModifier: Boolean;
begin
  fToIdent := pch;
  str := '';
  isModifier := True;
  while CharInSet(pch^, ['.', '_', 'a'..'z', 'A'..'Z', '0'..'9']) do begin
    if not CharInSet(pch^, ['.', 'w'..'z', 'W'..'Z', 'r', 'g', 'b', 'a', 'R', 'G', 'B', 'A']) then isModifier := False;
    str := str + pch^;
    Inc(pch);
  end;
  fStringLen := pch - fToIdent;

  if isModifier or (fModifiers.IndexOf(str) >= 0) then
    Result := tkModifier
  else
    Result := tkIdentifier;
end;

procedure TSynAsmShader.SpaceProc;
begin
  fTokenID := tkSpace;
  repeat
    inc(Run);
  until not (CharInSet(fLine[Run], [#1..#32]));
end;

procedure TSynAsmShader.NullProc;
begin
  fTokenID := tkNull;
  inc(Run);
end;

procedure TSynAsmShader.CRProc;
begin
  fTokenID := tkSpace;
  Case FLine[Run + 1] of
    #10: inc(Run, 2);
  else inc(Run);
  end;
end;

procedure TSynAsmShader.LFProc;
begin
  fTokenID := tkSpace;
  inc(Run);
end;

procedure TSynAsmShader.SingleLineCommentProc;
begin
  inc(Run);
  fTokenID := tkComment;
  while not IsLineEnd(Run) do inc(Run);
  fRange := rsUnKnown;
end;

procedure TSynAsmShader.SimpleCommentOpenProc;
begin
  Inc(Run);
  fRange := rsSingleLineComment;
  SingleLineCommentProc;
  fTokenID := tkComment;
end;

procedure TSynAsmShader.CStyleCommentOpenProc;
begin
  Inc(Run);
  if fLine[Run] = '*' then begin
    fRange := rsCStyleComment;
    CStyleCommentProc;
    fTokenID := tkComment;
  end else if fLine[Run] = '/' then begin
    fRange := rsSingleLineComment;
    SingleLineCommentProc;
    fTokenID := tkComment;
  end else
    fTokenID := tkIdentifier;
end;

procedure TSynAsmShader.CStyleCommentProc;
begin
  case fLine[Run] of
     #0: NullProc;
    #10: LFProc;
    #13: CRProc;
  else
    begin
      fTokenID := tkComment;
      repeat
        if (fLine[Run] = '*') and (fLine[Run + 1] = '/') then begin
          Inc(Run, 2);
          fRange := rsUnKnown;
          Break;
        end;
        if not (CharInSet(fLine[Run], [#0, #10, #13])) then Inc(Run);
      until CharInSet(fLine[Run], [#0, #10, #13]);
    end;
  end;
end;

constructor TSynAsmShader.Create(AOwner: TComponent);
const
  strKeywords: array[0..47] of string[15] = ('vs', 'def', 'add', 'dp3', 'dp4',
                                            'dst', 'expp', 'lit', 'logp', 'mad',
                                            'max', 'min', 'mov', 'mul', 'rcp',
                                            'rsq', 'sge', 'slt', 'sub',
                                            'ps', 'bem', 'cmp', 'cnd', 'lrp',
                                            'mad', 'nop', 'tex', 'texbem', 'texbeml',
                                            'texcoord', 'texcrd', 'texdepth', 'texdp3', 'texdp3tex',
                                            'texkill', 'texld', 'texm3x2depth', 'texm3x2pad', 'texm3x2tex',
                                            'texm3x3', 'texm3x3pad', 'texm3x3tex', 'texm3x3spec', 'texm3x3vspec',
                                            'texreg2ar', 'texreg2gb', 'texreg2rgb', 'phase');
  strRegs: array[0..8] of string[7] = ('oD0', 'oD1', 'oFog', 'oPos', 'oPts',
                                       'oT0', 'oT1', 'oT2', 'oT3');
  strMacros: array[0..7] of string[7] = ('exp', 'frc', 'log', 'm3x2', 'm3x3',
                                         'm3x4', 'm4x3', 'm4x4');

  strModifiers: array[0..13] of string[7] = ('.1.0', '.1.1', '.1.2', '.1.3', '.1.4',
                                            '_x2', '_x4', '_x8',
                                            '_d2', '_d4', '_d8',
                                            '_sat',
                                            '_bias', '_bx2');
var i: Integer;
begin
  fKeyMacros := TStringList.Create;
  fKeyRegs   := TStringList.Create;
  fKeyWords  := TStringList.Create;
  fModifiers := TStringList.Create;

  for i := Low(strMacros) to High(strMacros) do fKeyMacros.Add(strMacros[i]);

  fKeyRegs.Add('A0');
  fKeyRegs.Add('c');
  for i := 0 to 11 do fKeyRegs.Add('r' + IntToStr(i));
  for i := 0 to 15 do fKeyRegs.Add('v' + IntToStr(i));
  for i := 0 to 05 do fKeyRegs.Add('t' + IntToStr(i));
  for i := Low(strRegs) to High(strRegs) do fKeyRegs.Add(strRegs[i]);

  for i := Low(strKeywords) to High(strKeywords) do fKeyWords.Add(strKeywords[i]);

  for i := Low(strModifiers) to High(strModifiers) do fModifiers.Add(strModifiers[i]);

  inherited Create(AOwner);
  fCommentAttri := TSynHighLighterAttributes.Create(SYNS_AttrComment, SYNS_AttrComment);
  fCommentAttri.Style := [fsItalic];
  fCommentAttri.Foreground := clGray;
  AddAttribute(fCommentAttri);

  fIdentifierAttri := TSynHighLighterAttributes.Create(SYNS_AttrIdentifier, SYNS_AttrIdentifier);
  fIdentifierAttri.Foreground := clBlack;
  fIdentifierAttri.Style := [];
  AddAttribute(fIdentifierAttri);

  fKeyAttri := TSynHighLighterAttributes.Create(SYNS_AttrReservedWord, SYNS_AttrReservedWord);
  fKeyAttri.Foreground := clBlack;
  fKeyAttri.Style := [fsBold];
  AddAttribute(fKeyAttri);

  fMacroAttri := TSynHighLighterAttributes.Create(SYNS_AttrMacro, SYNS_AttrMacro);
  fMacroAttri.Style := [fsBold];
  fMacroAttri.Foreground := clDkGray;
  AddAttribute(fMacroAttri);

  fModifierAttri := TSynHighLighterAttributes.Create(SYNS_AttrMods, SYNS_AttrMods);
  fModifierAttri.Foreground := clMaroon;
  AddAttribute(fModifierAttri);

  fRegsAttri := TSynHighLighterAttributes.Create(SYNS_AttrRegs, SYNS_AttrRegs);
  fRegsAttri.Style := [fsBold];
  fRegsAttri.Foreground := clNavy;
  AddAttribute(fRegsAttri);

  fSpaceAttri := TSynHighLighterAttributes.Create(SYNS_AttrSpace, SYNS_AttrSpace);
  AddAttribute(fSpaceAttri);

  SetAttributesOnChange(DefHighlightChange);

  fDefaultFilter := SYNS_Filter;
  fRange := rsUnknown;
end;

destructor TSynAsmShader.Destroy;
begin
  FreeAndNil(fKeyMacros);
  FreeAndNil(fKeyRegs);
  FreeAndNil(fKeyWords);
  FreeAndNil(fModifiers);
  inherited;
end;

function TSynAsmShader.IsCharIdent(ch: WideChar): Boolean;
begin
  result := IsIdentChar(ch) and not (ch = '_');
end;

procedure TSynAsmShader.IdentProc;
begin
  fTokenID := IdentKind((fLine + Run));
  inc(Run, fStringLen);
  while IsCharIdent(fLine[Run]) do Inc(Run);
end;

procedure TSynAsmShader.ModifierProc;
begin
  fTokenID := ModifierKind((fLine + Run));
  inc(Run, fStringLen);
  while IsIdentChar(fLine[Run]) or (fLine[Run] = '.') do Inc(Run);
end;

procedure TSynAsmShader.UnknownProc;
begin
{$IFDEF SYN_MBCSSUPPORT}
  if FLine[Run] in LeadBytes then
    Inc(Run,2)
  else
{$ENDIF}
  inc(Run);
  fTokenID := tkUnknown;
end;

procedure TSynAsmShader.Next;
begin
  fTokenPos := Run;
  case fRange of
    rsCStyleComment: CStyleCommentProc;
  else
    begin
      fRange := rsUnknown;
      case fLine[Run] of
        #0: NullProc;
        #10: LFProc;
        #13: CRProc;
        '/': CStyleCommentOpenProc;
        ';': SimpleCommentOpenProc;
        #1..#9,
        #11,
        #12,
        #14..#32 : SpaceProc;
        '.', '_': ModifierProc;
        'A'..'Z', 'a'..'z': IdentProc;
        else UnknownProc;
      end;
    end;
  end;

  inherited;
end;

function TSynAsmShader.GetDefaultAttribute(Index: integer): TSynHighLighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT    : Result := fCommentAttri;
    SYN_ATTR_IDENTIFIER : Result := fIdentifierAttri;
    SYN_ATTR_KEYWORD    : Result := fKeyAttri;
    SYN_ATTR_WHITESPACE : Result := fSpaceAttri;
  else
    Result := nil;
  end;
end;

function TSynAsmShader.GetEol: Boolean;
begin
  Result := Run = fLineLen + 1;
//  if Result then Run := 0;   //ToDo: remove
end;

function TSynAsmShader.GetToken: UnicodeString;
var
  Len: LongInt;
begin
  Len := Run - fTokenPos;
  SetString(Result, (FLine + fTokenPos), Len);
end;

function TSynAsmShader.GetTokenID: TtkTokenKind;
begin
  Result := fTokenId;
end;

function TSynAsmShader.GetTokenAttribute: TSynHighLighterAttributes;
begin
  case GetTokenID of
    tkComment: Result := fCommentAttri;
    tkIdentifier: Result := fIdentifierAttri;
    tkKey: Result := fKeyAttri;
    tkMacro: Result := fMacroAttri;
    tkModifier: Result := fModifierAttri;
    tkRegs: Result := fRegsAttri;
    tkSpace: Result := fSpaceAttri;
    tkUnknown: Result := fIdentifierAttri;
  else
    Result := nil;
  end;
end;

function TSynAsmShader.GetTokenKind: integer;
begin
  Result := Ord(fTokenId);
end;

function TSynAsmShader.GetTokenPos: Integer;
begin
  Result := fTokenPos;
end;

function TSynAsmShader.GetSampleSource: UnicodeString;
begin
  Result := 'vs.1.1'#13#10 +
            'def c[0], 1.0, 1.0, 1.0, 0.0'#13#10 +
            'mov r0, c[15]'#13#10 +
            'dp3 r2, v0, v[A0]'#13#10 +
            'm4x4 r1, c[0]';
end;

function TSynAsmShader.IsFilterStored: Boolean;
begin
  Result := fDefaultFilter <> SYNS_Filter;
end;

class function TSynAsmShader.GetLanguageName: string;
begin
  Result := SYNS_LangAsmShader;
end;

class function TSynAsmShader.GetFriendlyLanguageName: UnicodeString;
begin
  Result := SYNS_FriendlyLangAsmShader;
end;

procedure TSynAsmShader.ResetRange;
begin
  fRange := rsUnknown;
end;

procedure TSynAsmShader.SetRange(Value: Pointer);
begin
  fRange := TRangeState(Value);
end;

function TSynAsmShader.GetRange: Pointer;
begin
  Result := Pointer(fRange);
end;

initialization
{$IFNDEF SYN_CPPB_1}
  RegisterPlaceableHighlighter(TSynAsmShader);
{$ENDIF}
end.
