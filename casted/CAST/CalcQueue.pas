{$Include GDefines}
{$Include CDefines}
unit CalcQueue;

interface

uses Basics;

type
  PCalcArea = ^TCalcArea;

  TCalcArea = record
    Value: Integer;
    Area: TArea;
    Next: PCalcArea;
  end;

  TCalcQueue = class
    TotalAreas: Integer;
    First, Last: PCalcArea;
    constructor Create;
    procedure Add(CalcArea: PCalcArea); virtual;
    function Extract: PCalcArea; virtual;
    procedure Clear; virtual;
    destructor Free;
  end;

implementation

{ TCalcQueue }

constructor TCalcQueue.Create;
begin
  TotalAreas := 0; First := nil; Last := nil;
end;

procedure TCalcQueue.Add(CalcArea: PCalcArea);
begin
  Inc(TotalAreas);
  if First = nil then First := CalcArea else Last.Next := CalcArea;
  Last := CalcArea;
  CalcArea.Next := nil;
end;

function TCalcQueue.Extract: PCalcArea;
begin
  Result := First;
  if First = nil then Exit;
  Dec(TotalAreas);
  First := First^.Next;
  if First = nil then Last := nil;
end;

procedure TCalcQueue.Clear;
var Temp, Temp2: PCalcArea;
begin
  Temp := First;
  while Temp <> nil do begin
    Temp2 := Temp;
    Temp := Temp2^.Next;
    Dispose(Temp2);
  end;
  Last := nil; TotalAreas := 0;
end;

destructor TCalcQueue.Free;
begin
  Clear;
end;

end.
 