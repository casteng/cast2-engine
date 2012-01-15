unit FStats;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  VCLHelper,
  CAST2, C2Core,
  ComCtrls;

type
  TStatF = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    GeneralStatsTxt: TStaticText;
    PrimitivesStatsTxt: TStaticText;
    TimingsStatsTxt: TStaticText;
    TabSheet4: TTabSheet;
    ItemsStatsTxt: TStaticText;
    TabSheet5: TTabSheet;
    TabSheet6: TTabSheet;
    BuffersStatTxt: TStaticText;
    MiscStatTxt: TStaticText;
    procedure UpdateStats(Core: TCore);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  end;  

var
  StatF: TStatF;

implementation

{$R *.dfm}

{ TStatF }

procedure TStatF.FormCreate(Sender: TObject);
begin
//  DoubleBuffered := True;
//  PageControl1.DoubleBuffered := True;
  BuffersStatTxt.DoubleBuffered := True;
//  TabSheet5.DoubleBuffered := True;
end;

procedure TStatF.FormShow(Sender: TObject);
begin
  CheckParentSize(Self);
end;

procedure TStatF.UpdateStats(Core: TCore);
var s: Single;
begin
  if not Assigned(Core) or not Assigned(Core.Renderer) then Exit;
  with Core.PerfProfile do begin
    GeneralStatsTxt.Caption := Format('FPS/PPS: %3.3F/%3.3FM'#13#10 +
                                      'Pot. visible items: %D'#13#10 +
                                      'Tesselators: %D'#13#10 +
                                      'Primitives: %3.1FK'#13#10 +
                                      'DIP calls: %D, clear calls: %D',
                                      [FramesPerSecond, PrimitivesPerSecond/1000000,
                                       FrustumPassedItems + Core.PerfProfile.FrustumCulledItems,
                                       Core.TesselatorManager.TotalItems,
                                       PrimitivesRendered/1000,
                                       DrawCalls, ClearCalls]);

    ItemsStatsTxt.Caption := Format('Potentially visible: %D'#13#10 +
                                    'Sorted items: %D'#13#10 +
                                    'Inside frustum: %D'#13#10 +
                                    'Outside frustum: %D',
                                    [FrustumPassedItems + Core.PerfProfile.FrustumCulledItems,
                                     SortedItems,
                                     FrustumPassedItems, FrustumCulledItems]);

    PrimitivesStatsTxt.Caption := Format('Primitives: %D'#13#10 +
                                         'Primitives per second: %3.3FM'#13#10 +
                                         'DIPS: %D',
                                         [PrimitivesRendered, PrimitivesPerSecond/1000000, DrawCalls]);

    TimingsStatsTxt.Caption := Format('Render: %3.2F ms'#13#10 +
                                      'Process: %3.2F ms'#13#10 +
                                      'Collision: %3.2F ms'#13#10 +
                                      'Total: %3.2F ms'#13#10 +

                                      'Timer events: %D, rec.: %D',
                                      [Times[ptRender] * 1000, Times[ptProcessing] * 1000, Times[ptCollision] * 1000, Times[ptFrame] * 1000,
                                       Core.Timer.TotalEvents, Core.Timer.TotalRecurringEvents]);

    BuffersStatTxt.Caption := Format('Size, KB: static vertex: %D, index: %D, dynamic vertex: %D, index: %D'#13#10 +
                                     'Writes: static vertex: %D(%3.1FKB), index: %D(%3.1FKB), dynamic vertex: %D(%3.1FKB), index: %D(%3.1FKB)'#13#10 +
                                     'Discards: static vertex: %D, index: %D, dynamic vertex: %D, index: %D'#13#10 +
                                     'Reuse: Vertex: %D(%3.1FKB), Index: %D(%3.1FKB)',
                                     [BuffersProfile[tbVertex].BufferSize[True]  div 1024, BuffersProfile[tbIndex].BufferSize[True]  div 1024,
                                      BuffersProfile[tbVertex].BufferSize[False] div 1024, BuffersProfile[tbIndex].BufferSize[False] div 1024,

                                      BuffersProfile[tbVertex].TesselationsPerformed[True],
                                      BuffersProfile[tbVertex].BytesWritten[True]/1024,
                                      BuffersProfile[tbIndex].TesselationsPerformed[True],
                                      BuffersProfile[tbIndex].BytesWritten[True]/1024,
                                      BuffersProfile[tbVertex].TesselationsPerformed[False],
                                      BuffersProfile[tbVertex].BytesWritten[False]/1024,
                                      BuffersProfile[tbIndex].TesselationsPerformed[False],
                                      BuffersProfile[tbIndex].BytesWritten[False]/1024,

                                      BuffersProfile[tbVertex].BufferResetsCount[True],  BuffersProfile[tbIndex].BufferResetsCount[True],
                                      BuffersProfile[tbVertex].BufferResetsCount[False], BuffersProfile[tbIndex].BufferResetsCount[False],

                                      BuffersProfile[tbVertex].TesselationsBypassed,
                                      BuffersProfile[tbVertex].BytesBypassed / 1024,
                                      BuffersProfile[tbIndex].TesselationsBypassed,
                                      BuffersProfile[tbIndex].BytesBypassed / 1024
                                      ]);
  end;
end;

end.

Format('Render targets: %D'#13#10 +
                                'RT changes: %D'#13#10 +

                                'Buffers'#13#10 +
                                '  size, KB: SV: %D, SI: %D, DV: %D, DI: %D'#13#10 +
                                '  tess:  SV: %D(3.1FKB), SI: %D(3.1FKB), DV: %D(3.1FKB), DI: %D(3.1FKB)'#13#10 +
                                '  resets:  SV: %D, SI: %D, DV: %D, DI: %D'#13#10 +
                                '  tess bypass: Vertex: %D, Index: %D',
                                [Core.Renderer.TotalRenderTargets, RenderTargetChanges, Core.TesselatorManager.TotalItems,
                                 ]);
