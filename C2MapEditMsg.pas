(*
 @Abstract(CAST II Engine map editing messages unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: Feb 25, 2007 <br>
 Unit contains map editing messages
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2MapEditMsg;

interface

uses BaseMsg, BaseGraph, CAST2, Props, Models;

type
  // Item-independent editing cursor class
  TMapCursor = class
      // Item-specific parameters
    Params: TProperties;
      // Editor-supplyed parameters
    MouseX, MouseY,
    LastEditMouseX, LastEditMouseY: Integer;
    Camera: CAST2.TCamera;
    Screen: BaseGraph.TScreen;
      // Feedback
    // Operation which returns editable item
    Operation: TOperation;

    // Cursor settings
    Kind: Cardinal;
//    Size,
    Value: Integer;
    Aligned: Boolean;
    // Editor visual data (texture, UV maps, etc)
    MainTextureName, UVMapName: AnsiString;
    UVMapStep: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TMapEditorMessage = class(TMessage)
    Cursor: TMapCursor;
    constructor Create(ACursor: TMapCursor);
  end;

  TMapDrawCursorMsg = class(TMapEditorMessage)
  end;

  TMapModifyBeginMsg = class(TMapEditorMessage)
  end;

  TMapModifyMsg = class(TMapEditorMessage)
  end;

  TMapModifyEndMsg = class(TMapEditorMessage)
  end;

  TMapOperationsApplyedMsg = class(TMapEditorMessage)
  end;

  TRequestMapEditVisuals = class(TMapEditorMessage)
  end;

implementation

{ TMapCursor }

constructor TMapCursor.Create;
begin
  Params := TProperties.Create;
end;

destructor TMapCursor.Destroy;
begin
  Params.Free;
  Params := nil;
  inherited;
end;

{ MapEditorMessage }

constructor TMapEditorMessage.Create(ACursor: TMapCursor);
begin
  Cursor := ACursor;
end;

end.
