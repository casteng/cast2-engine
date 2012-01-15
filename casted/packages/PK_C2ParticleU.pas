(*
 Particles package interface unit
 (C) 2006-2007 George "Mirage" Bakhtadze. avagames@gmail.com
 Created: Aug 17, 2007
 Unit contains particle system units registration routines
*)
unit PK_C2ParticleU;

interface

procedure RegisterPackage;

implementation

uses
  Logger, BasePlugins, BaseClasses,
  C2Particle, C2Affectors, C2ParticleAdv;

procedure RegisterPackage;
var ClassList: TClassArray;
begin
  if Assigned(PluginSystem) then begin
    ClassList := nil;
    MergeClassLists(ClassList, C2Affectors.GetUnitClassList);
    MergeClassLists(ClassList, C2ParticleAdv.GetUnitClassList);
    PluginSystem.RegisterPlugin('CAST II particle system', 'CAST II partcile system package', ClassList);
  end else
    Log('Package "PK_C2ParticleU" initialization: Plugin system is not initialized', lkError);
end;

initialization
  if Assigned(PluginSystem) then RegisterPackage;
end.
