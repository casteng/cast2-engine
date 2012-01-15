unit FImage;

interface

uses
  Resources,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Menus, ActnList;

type
  TImageForm = class(TForm)
    Panel1: TPanel;
    ScBarH: TScrollBar;
    ScBarV: TScrollBar;
    Image1: TImage;
    ActionList1: TActionList;
    ActImgMakeAlpha: TAction;
    ActImgMakeNMap: TAction;
    ActImgApply: TAction;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    MenuNew: TMenuItem;
    MenuOpen: TMenuItem;
    MenuSave: TMenuItem;
    MenuSaveAs: TMenuItem;
    N2: TMenuItem;
    Apply1: TMenuItem;
    N1: TMenuItem;
    MenuOpenAt: TMenuItem;
    MenuClose: TMenuItem;
    EditMenu: TMenuItem;
    Undo1: TMenuItem;
    Redo1: TMenuItem;
    MenuCopy: TMenuItem;
    MenuPaste: TMenuItem;
    MenuResize: TMenuItem;
    MenuMkAlpha: TMenuItem;
    Makenormalmap1: TMenuItem;
    ViewMenu: TMenuItem;
    MenuViewAlpha: TMenuItem;
    Color: TMenuItem;
    Alpha: TMenuItem;
    Ontop1: TMenuItem;
    Deselect1: TMenuItem;
  private
    FWidth, FHeight, FLevels: Integer;
    function GetXPos: Integer;                  // Image view X offset
    function GetYPos: Integer;                  // Image view Y offset

    procedure CorrectView;                      // Corrects offsets if needed and show/hide scroll bars

    procedure Redraw;                           // Copies visible part of image to TImage
  public
    function Init(AWidth, AHeight, ALevels: Integer): Boolean;
    function InitByRes(AResource: TImageResource): Boolean;
  end;

var
  ImageForm: TImageForm;

implementation

{$R *.dfm}

{ TImageForm }

function TImageForm.GetXPos: Integer;
begin
  Result := ScBarH.Position;
end;

function TImageForm.GetYPos: Integer;
begin
  Result := ScBarV.Position;
end;

procedure TImageForm.CorrectView;
begin

end;

procedure TImageForm.Redraw;
begin

end;

function TImageForm.Init(AWidth, AHeight, ALevels: Integer): Boolean;
begin

end;

function TImageForm.InitByRes(AResource: TImageResource): Boolean;
begin

end;

end.
