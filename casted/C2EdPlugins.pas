(*
 CAST II Editor plugins interface
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains plugin interface class
*)
unit C2EdPlugins;

interface

uses BaseClasses, BasePlugins;

type
  TC2EdPluginSystem = class(TPluginSystem)
  private
    FManager: TItemsManager;
  protected
    procedure RegisterClasses(AClasses: array of TClass); override;
  public
    constructor Create(AManager: TItemsManager);
  end;

implementation

uses SysUtils, Logger;

{ TC2EdPluginSystem }

constructor TC2EdPluginSystem.Create(AManager: TItemsManager);
begin
  FManager := AManager;
end;

procedure TC2EdPluginSystem.RegisterClasses(AClasses: array of TClass);
var i: Integer;
begin
  for i := 0 to High(AClasses) do
    if AClasses[i].InheritsFrom(TItem) then begin
      Log('  Registering class "' + AClasses[i].ClassName + '"');
      FManager.RegisterItemClass(CItem(AClasses[i]));
    end else
      Log('  Class "' + AClasses[i].ClassName + '" is not a descendant of TItem', lkError);
end;

end.
