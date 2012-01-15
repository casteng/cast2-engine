(*
 Base package interface unit
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains base units registration routines
*)
unit PK_C2BaseU;

interface

procedure RegisterPackage;

implementation

uses
  Logger, BasePlugins,
  BaseClasses,
  CAST2, C2Visual, C2Res, C2Core,
  C2VisItems, C2Materials,
  C2Anim,
  C2Flora, C2Grass,
  C2Maps, C2Land, C2TileMaps,
  C22D,
  C2FX;

procedure RegisterPackage;
var ClassList: TClassArray;
begin
  if Assigned(PluginSystem) then begin
    ClassList := nil;
    MergeClassLists(ClassList, C2Res.GetUnitClassList);
    MergeClassLists(ClassList, C2Core.GetUnitClassList);
    MergeClassLists(ClassList, C2VisItems.GetUnitClassList);
    MergeClassLists(ClassList, C2Anim.GetUnitClassList);
    MergeClassLists(ClassList, C22D.GetUnitClassList);
    MergeClassLists(ClassList, C2FX.GetUnitClassList);
    MergeClassLists(ClassList, C2Land.GetUnitClassList);
    MergeClassLists(ClassList, C2TileMaps.GetUnitClassList);
    MergeClassLists(ClassList, C2Flora.GetUnitClassList);
    MergeClassLists(ClassList, C2Grass.GetUnitClassList);
    PluginSystem.RegisterPlugin('CAST II base', 'CAST II base units package', ClassList);
  end else
    Log('Package "PK_C2Base" initialization: Plugin system is not initialized', lkError);
end;

initialization
  if Assigned(PluginSystem) then RegisterPackage;
end.
