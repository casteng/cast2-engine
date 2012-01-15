(*
 Base package interface unit
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains base units registration routines
*)
unit PK_BaseU;

interface

procedure RegisterPackage;

implementation

uses
  Logger, BasePlugins,
  BaseClasses, Resources, BaseGraph;

procedure RegisterPackage;
var ClassList: TClassArray;
begin
  if Assigned(PluginSystem) then begin
    ClassList := nil;
    MergeClassLists(ClassList, Resources.GetUnitClassList);
    MergeClassLists(ClassList, BaseGraph.GetUnitClassList);
    PluginSystem.RegisterPlugin('Base', 'Base units package', ClassList);
  end else
    Log('Package "PK_Base" initialization: Plugin system is not initialized', lkError);
end;

initialization
  if Assigned(PluginSystem) then RegisterPackage;
end.
