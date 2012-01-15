(*
 Base package interface unit
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains base units registration routines
*)
unit PK_C2GUIU;

interface

procedure RegisterPackage;

implementation

uses
  Logger, BasePlugins, BaseClasses,
  C2GUI;

procedure RegisterPackage;
var ClassList: TClassArray;
begin
  if Assigned(PluginSystem) then begin
    ClassList := nil;
    MergeClassLists(ClassList, C2GUI.GetUnitClassList);
    PluginSystem.RegisterPlugin('CAST II GUI', 'CAST II ACS GUI library wrapper package', ClassList);
  end else
    Log('Package "PK_C2GUIU" initialization: Plugin system is not initialized', lkError);
end;

initialization
  if Assigned(PluginSystem) then RegisterPackage;
end.
