(*
 Base package interface unit
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains base units registration routines
*)
unit PK_ACSU;

interface

procedure RegisterPackage;

implementation

uses
  Logger, BasePlugins,
  BaseClasses,
  ACSBase,
  ACS,
  ACSAdv;

procedure RegisterPackage;
var ClassList: TClassArray;
begin
  if Assigned(PluginSystem) then begin
    ClassList := nil;
    MergeClassLists(ClassList, ACS.GetUnitClassList);
    MergeClassLists(ClassList, ACSAdv.GetUnitClassList);
    PluginSystem.RegisterPlugin('ACS', 'ACS GUI library package', ClassList);
  end else
    Log('Package "PK_ACSU" initialization: Plugin system is not initialized', lkError);
end;

initialization
  if Assigned(PluginSystem) then RegisterPackage;
end.
