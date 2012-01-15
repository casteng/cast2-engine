{.$DEFINE Release}
{$I GDefines.inc}
{$I C2Defines.inc}
{$APPTYPE CONSOLE}
// rtl;vcl;PNG_D7;PngComponentsD7;PK_Plugins;PK_Base;PK_ACS;PK_C2Base;PK_C2GUI
program c2ed;

uses comobj,
  {$IFDEF USEFASTMM}
  FastMM4,
  {$ENDIF}
  Windows,

  Logger,
  BaseDebug,
  LogForm in 'LogForm.pas' {LogF},
  SysUtils,
  Forms,
  VirtualTrees,
  C2EdMain,
  C2EdUtil,
  Basics,
  Props,
  AppsInit,
  VCLHelper,
  mainform in 'mainform.pas' {MainF},
  PropFrame in 'PropFrame.pas' {PropsFrame: TFrame},
  ObjFrame in 'ObjFrame.pas' {ItemsFrame: TFrame},
  ItemClassForm in 'ItemClassForm.pas' {ItemClassF},
  RenderFrame in 'RenderFrame.pas' {RendererFrame: TFrame},
  FImages in 'FImages.pas' {ImagesForm},
  ResizeF in 'ResizeF.pas' {ResizeForm},
  AtF in 'AtF.pas' {LoadAtForm},
  FCFont in 'FCFont.pas' {MkFontForm},
  FCMGen in 'FCMGen.pas' {CMGForm},
  FSMGen in 'FSMGen.pas' {SMGForm},
  FUVGen in 'FUVGen.pas' {UVForm},
  FCharMap in 'FCharMap.pas' {CharMapForm},
  ResTools in 'ResTools.pas' {FResTools},
  FFormat in 'FFormat.pas' {FormatForm},
  FVFormat in 'FVFormat.pas' {VFormatForm},
  FScale in 'FScale.pas' {ScaleForm},
  C2Affectors,
  C2ParticleAdv,
  Controls,
  ExtCtrls,
  Buttons,
  MapEditForm in 'MapEditForm.pas' {MapEditF},
  ModelLoadForm in 'ModelLoadForm.pas' {ModelLoadF},
  FStats in 'FStats.pas' {StatF},
  FTextEdit in 'FTextEdit.pas' {TextEditForm},
  FConfig in 'FConfig.pas' {ConfigForm},
  BasePlugins,
  C2EdPlugins,
  PK_BaseU,
  PK_C2BaseU,
  PK_ACSU,
  PK_C2GUIU,
  FAbout in 'FAbout.pas' {AboutForm},
  FPropEdit in 'FPropEdit.pas' {PropEditF},
  FNormMap in 'FNormMap.pas' {NormMapForm},
  FImage in 'FImage.pas' {ImageForm},
  FMaterial in 'FMaterial.pas' {FormNewMaterial},
  FPEmitter in 'FPEmitter.pas' {PEmitterForm};

// Built-in packages

var Starter: TVCLStarter;

function StoredControlsFilter(AControl: TControl): Boolean; // Filter out all except forms, panels, controlbars and sliders
begin
  Result := (AControl is TForm) or (AControl is TPanel) or (AControl is TSplitter) or (AControl is TFrame) or (AControl is TBaseVirtualTree) or (AControl is TSpeedButton);
  Result := Result and not (AControl is TAboutForm);
end;

    function GetDefaultSystemLangID:string;     // move to osutils
    begin
      case GetSystemDefaultLangID and 1023 of
        $04: Result := 'cn';
        $05: Result := 'ch';
        $06: Result := 'dk';
        $07: Result := 'de';
        $09: Result := 'en';
        $0A: Result := 'es';
        $0C: Result := 'fr';
        $10: Result := 'it';
        $13: Result := 'nl';
        $19: Result := 'ru';
        $23: Result := 'by';
        else Result := 'en';
      end;
    end;

begin
  AddAppender(TFileAppender.Create('c2ed.log', llFull));

  Starter := TVCLStarter.Create('CAST II Editor', [soSingleUser]);

  Log('Default system language: ' + GetDefaultSystemLangID);
  App := TC2EdApp.Create('', Starter);
  PluginSystem := TC2EdPluginSystem.Create(Core);
  PK_BaseU.RegisterPackage;
  PK_C2BaseU.RegisterPackage;
  PK_ACSU.RegisterPackage;
  PK_C2GUIU.RegisterPackage;

  ForEachFile(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'Plugins\*.bpl', faArchive, App.LoadPluginDelegate);

  Cfg := App.Config;
//  Cfg := TFileConfig.Create(ChangeFileExt(ExtractFileName(ParamStr(0)), '')+'.ini');
  GUIHelper := TVCLGUIHelper.Create;

  Application.Initialize;
  Application.ShowHint := True;
  Application.HintPause := 100;
  Application.HintHidePause := 10000;
  Application.HelpFile := '';
  Application.Title    := 'CAST II Editor';

  Application.OnActivate   := App.OnActivate;
  Application.OnDeactivate := App.OnDeActivate;
  Application.OnIdle       := App.OnIdle;

  Clipboard := TStreamClipboard.Create('clipboard.dat');

  Application.CreateForm(TMainF, MainF);

  Application.OnException := MainF.OnException;

  Application.CreateForm(TLogF, LogF);
  Application.CreateForm(TItemClassF, ItemClassF);
  Application.CreateForm(TMapEditF, MapEditF);
  Application.CreateForm(TModelLoadF, ModelLoadF);
  Application.CreateForm(TStatF, StatF);
  Application.CreateForm(TTextEditForm, TextEditForm);
  Application.CreateForm(TConfigForm, ConfigForm);
  Application.CreateForm(TAboutForm, AboutForm);
    Application.CreateForm(TPropEditF, PropEditF);
  Application.CreateForm(TNormMapForm, NormMapForm);
  Application.CreateForm(TImageForm, ImageForm);
  Application.CreateForm(TFormNewMaterial, FormNewMaterial);
  Application.CreateForm(TPEmitterForm, PEmitterForm);
  //  ConfigForm.PreApplyConfig;
//  ConfigForm.ApplyConfig;

  Application.CreateForm(TImagesForm, ImagesForm);
  Application.CreateForm(TResizeForm, ResizeForm);
  Application.CreateForm(TLoadAtForm, LoadAtForm);
  Application.CreateForm(TMkFontForm, MkFontForm);
  Application.CreateForm(TCMGForm, CMGForm);
  Application.CreateForm(TSMGForm, SMGForm);
  Application.CreateForm(TUVForm, UVForm);
  Application.CreateForm(TCharMapForm, CharMapForm);
  Application.CreateForm(TFResTools, FResTools);
  Application.CreateForm(TFormatForm, FormatForm);
  Application.CreateForm(TVFormatForm, VFormatForm);
  Application.CreateForm(TScaleForm, ScaleForm);

  GUIHelper.AddStoredControl(nil, True, StoredControlsFilter);
//  GUIHelper.AddStoredControl(MainF.ItemsFrame1.BtnPause, False, nil);
//  GUIHelper.RemoveStoredControl(PropEditF, True);
  GUIHelper.RemoveStoredControl(MainF.PropsFrame1, True);
  GUIHelper.RemoveStoredControl(MainF.ItemsFrame1.BtnPause, False);

  GUIHelper.LoadForms(IncludeTrailingPathDelimiter(Starter.ProgramWorkDir) + Starter.ProgramExeName+'.frm');

  if FileExists(ChangeFileExt(ExtractFileName(ParamStr(0)), '')+'.cls') then
    ItemClassF.CatSetupText.Lines.LoadFromFile(ChangeFileExt(ExtractFileName(ParamStr(0)), '')+'.cls');
  ItemClassF.RefreshClasses;

  GUIHelper.StoreLocalizable('locale.en.sample');

  App.Init;
  MainF.Init;

  if GetDefaultSystemLangID <> 'en' then
    GUIHelper.LoadLocalizable('locale.' + GetDefaultSystemLangID);

  Application.Run;

  GUIHelper.StoreForms(IncludeTrailingPathDelimiter(Starter.ProgramWorkDir) + Starter.ProgramExeName+'.frm');

  App.Config.Save;

  ItemClassF.CatSetupText.Lines.SaveToFile(ChangeFileExt(ExtractFileName(ParamStr(0)), '')+'.cls');
  FreeAndNil(Clipboard);

  FreeAndNil(GUIHelper);
  FreeAndNil(App);
  FreeAndNil(Starter);
end.

