(*
 CAST II Engine Juggle extension)
 (C) 2006-2011 George "Mirage" Bakhtadze.
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file.
 Created: Oct 31, 2011
 File contains CAST2 specific extensions for Juggle library
*)

{$IFDEF _juggle_uses} // uses
Base3D, Cast2,
{$ENDIF}

{$IFDEF _juggle_interface} // interface

  public
    // Moves each item in the current set which is TProcessing by given vector and returns self
    function Move(Vec: TVector3s): TJItems;
    function Rotate(Quat: TQuaternion): TJItems;

    function Color(Color: TColor): TJItems;
    function Alpha(NewAlpha: Single): TJItems;
{$ENDIF}

{$IFDEF _juggle_implementation} //implementation

{ TJItems }

function TJItems.Move(Vec: TVector3s): TJItems;
var i: Integer;
begin
  Result := Self;
  for i := 0 to High(FItems) do
    if FItems[i] is TProcessing then TProcessing(FItems[i]).Position := AddVector3s(TProcessing(FItems[i]).Position, Vec);
end;

function TJItems.Rotate(Quat: TQuaternion): TJItems;
var i: Integer;
begin
  Result := Self;
  for i := 0 to High(FItems) do
    if FItems[i] is TProcessing then TProcessing(FItems[i]).Orientation := MulQuaternion(TProcessing(FItems[i]).Orientation, Quat);
end;

function TJItems.Color(Color: TColor): TJItems;
begin

end;

function TJItems.Alpha(NewAlpha: Single): TJItems;
begin

end;
{$ENDIF}
