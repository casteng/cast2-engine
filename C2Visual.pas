(*
 @Abstract(CAST II Engine visual items unit)
 (C) 2006 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Unit contains basic classes of visual items
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Visual;

interface

uses
  SysUtils,
  Logger,
  BaseTypes, Basics, BaseStr, Base3D, BaseMsg, ItemMsg, Props, Models, BaseCont, BaseClasses,
  {$IFDEF EDITORMODE} BaseGraph, C2MapEditMsg, {$ENDIF}
  C2Types, C2Msg, CAST2, C2Materials, C2Maps;

const
  // Vertex format
  vwIndexedBlending = $8;
  //Light source types
  ltDirectional = 0; ltPoint = 1; ltSpot = 2;
  //Light source types enumeration string
  LightKindsEnum = 'Directional\&Point\&Spot';

  // Size of data in index buffers. Subject to change soon.
  IndexSize = 2;

  // Default capacity of technique => item hash map
  DefaultTechToItemMapCapacity = 8;

  // Max size of mapped item edit cursor size
  MaxCursorSize = 64;
  // Map edit mode: adjust heights
  hmemAdjust = 0;
  // Map edit mode: smooth heights
  hmemSmooth = 1;
  // Map edit modes string enumeration
  MapEditModesEnum = 'Adjust' + StringDelimiter + 'Smooth';

type
  //  Tesselation status
  TTesselationState = (// Tesselator was cardinally changed, including maximum number of vertices and/or indices
                       tsMaxSizeChanged,
                       // Tesselator data was changed
                       tsChanged,
                       // Tesselator data was not changed so no reason to tesselate it again
                       tsTesselated);

  // Type of tesselator used to render an item
  TTesselatorType = (// Triangulated data of the tesselator rarely or never changes
                     ttStatic,
                     // Triangulated data changes nearly every frame (particle system, etc)
                     ttDynamic);

  { Current tesselation status data structure
    <b>BufferIndex</b>      - index of buffer in API-independent buffers
    <b>Offset</b>           - offset within the buffer in elements (vertices, indices, etc)
    <b>Status</b>           - current tesselation state
    <b>LastResetCounter</b> - reset counter
    should not be modified manually }
  TTesselationStatus = record
    TesselatorType: TTesselatorType;
    BufferIndex, Offset: Integer;
    Status: TTesselationState;
    LastResetCounter, LastBufferResetCounter: Integer;
  end;

  // Kind of tesselator
  TTesselatorKind = (// Null tesselator. Used when the item is tesselated by other shared tesselator (GUI, impostors, etc)
                     tkNone,
                     // The item is tesselated by its own tesselator (default)
                     tkOwn,
                     // a shared tesselator used for items of several classes (2D primitives, particles, etc)
                     tkShared);

  { The delegate used to retrieve a custom texture matrix. See @Link(tmCustom).
    <b>TextureSet</b> is an index of texture set to which the retrieved matrix will applied }
  TTextureMatrixDelegate = procedure(TextureStage: Integer; out Matrix: TMatrix4s) of object;

  // @Abstract(Camera which looks at a specified target point)
  TLookAtCamera = class(CAST2.TCamera)
  private
    FRange: Single;
    FFixedUp: Boolean;
    FLookTarget, FixedUpVector: TVector3s;
    procedure SetRange(const Value: Single); {$I inline.inc}
    procedure SetFixedUp(const Value: Boolean); {$I inline.inc}
    procedure SetLookTarget(const Value: TVector3s); {$I inline.inc}
  protected
    procedure ComputeTransform; override;
  public
    procedure Move(XD, YD, ZD: Single); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Look range
    property Range: Single read FRange write SetRange;
    // Setting this to True will fix the camera's UP vector
    property FixedUp: Boolean read FFixedUp write SetFixedUp;
    // Look target
    property LookTarget: TVector3s read FLookTarget write SetLookTarget;
  end;

  // @Abstract(Light source)
  TLight = class(CAST2.TProcessing)
  private
    function GetEnabled: Boolean; {$I inline.inc}
    procedure SetEnabled(const Value: Boolean); {$I inline.inc}
  protected
    procedure SetState(const Value: TSet32); override;
  public
    // Determines which passes can be affected by the light source
    GroupMask: TPassGroupSet;
    // Kind of the light source
    Kind: Integer;
    // Diffuse color of the light source
    Diffuse,
    // Specular color of the light source
    Specular,
    // Ambient color of the light source
    Ambient: BaseTypes.TColor4s;
    // Effective range of the light source
    Range: Single;
    Falloff: Single;
    // Constant attenuation
    Attenuation0,
    // Linear attenuation
    Attenuation1,
    // Quadratic attenuation
    Attenuation2: Single;
    // Inner angle of spotlight cone
    Theta,
    // Outer angle of spotlight cone
    Phi: Single;
    constructor Create(AManager: TItemsManager); override;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
    // Setting <b>Enabled</b> to @True/@False turns on/off the light source
    property Enabled: Boolean read GetEnabled write SetEnabled;
  end;

  { @Abstract(Camera class for shadow mapping)
    The camera constructs its view matrix according to position and direction of a spot light }
  TShadowMapCamera = class(TCamera)
  protected
    // Light to align to
    FLight: TLight;
    procedure ResolveLinks; override;
  public
    procedure HandleMessage(const Msg: TMessage); override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    // Calculates camera view matrix according to FLight
    procedure ComputeViewMatrix; override;
    // OnApply event overridden to assign previous camera variable and setup clipping plane
    procedure OnApply(const OldCamera: TCamera); override;
  end;

  { Data structure passed to tesselator buffer filling methods <br>
    <b>Camera</b>      - currently applied camera <br>
    <b>ModelMatrix</b> - model transform of visible items being rendered }
  TTesselationParameters = record
    Camera: TCamera;
    ModelMatrix: TMatrix4s;
  end;

  CTesselator = class of TTesselator;
  { @Abstract(Performs triangulation of visible items)
    Visible items are different - GUI elements, 3D meshes, procedural models, etc. [b]TTesselator[/b] contains methods to
    convert an item to its triangulated representation. }
  TTesselator = class(TReferencedItem)
  private
    LastMaxAmount: array[TTesselationBuffer] of Integer;
    Manager: TItemsManager;                   // For message sending
  protected
    // Informs engine core about bounding box change
    procedure InvalidateBoundingBox; {$I inline.inc}
  public
    // Total primitives in each strip
    TotalPrimitives: Integer;
    // Primitive type
    PrimitiveType: TPrimitiveType;
    // Total vetices in all strips
    TotalVertices,
    // Total indices in all strips
    TotalIndices: Integer;
    // Total strips
    TotalStrips,
    // Offset in vertices between strips
    StripOffset: Integer;
    // Number of vertices referenced by indices
    IndexingVertices: Integer;

    // Current tesselation status
    TesselationStatus: array[TTesselationBuffer] of TTesselationStatus;

    // If set to True a manual render method through @Link(DoManualRender) will be used instead of regular render
    ManualRender: Boolean;
// Old
//    Index: Integer;

    LastTotalIndices, LastTotalVertices: Integer;

    // Command block ID For render speedup. E.g. OpenGL display list ID.
    CommandBlock: Integer;
    // Determines if command block is a currently valid ID
    CommandBlockValid: Boolean;

    VerticesRes, IndicesRes: Integer;

    CompositeMember: Boolean;
    CompositeOffset: ^TVector3s;

//    {$IFDEF DEBUGMODE} LastMaxVertices: Integer; {$ENDIF}                 // Used only for debugging

    constructor Create; virtual;
    procedure Init; virtual;
    { Can be overridden to add some properties in addition to ones of a visible item which uses the tesselator.
      Called from AddProperties of @Link(TVisible). Object links can not be used or resolved here. }
    procedure AddProperties(const Result: Props.TProperties; const PropNamePrefix: TNameString); virtual;
    { Can be overridden to set some properties in addition to ones of a visible item which uses the tesselator.
      Called from SetProperties of @Link(TVisible). Object links can not be used or resolved here. }
    procedure SetProperties(Properties: Props.TProperties; const PropNamePrefix: TNameString); virtual;

    { Returns number of elements in the specified buffer type which needs to be updated in an API buffers.
      This function called by engine static buffers management routine to determine if lock/fill/unlock procedure needed
      for each tesselator.
      If the function returns 0 no update needed. }
    function GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer; virtual;
    // Returns maximum amount of elements in the specified buffer type
    function GetMaxAmount(Buffer: TTesselationBuffer): Integer; {$I inline.inc}

    // Invalidates contents of buffers used by the tesselator at the API side. If <b>EntireBuffer</b> is True entire API buffer will become invalid so use only if necessary.
    procedure Invalidate(ABuffer: TTesselationBufferSet; EntireBuffer: Boolean); {$I inline.Inc}

// ToDo: Move these methods to protected:
    // Returns True if mesh is valid. The basic implemetation simply tests all indices to point within correct vertices range.
    function Validate: Boolean; virtual;
    // Manual lighting begin
    procedure BeginLighting; virtual;
    // Perform manual lighting
    function CalculateLighting(const ALight: TLight; const ALightToItem: TMatrix4s): Boolean; virtual;

    // Bounding box containing
    function GetBoundingBox: TBoundingBox; virtual;

    function SetIndices(IBPTR: Pointer): Integer; virtual;
    function Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer; virtual;
  protected
    // Vertex format as specified by @Link(GetVertexFormat)
    FVertexFormat: Cardinal;
    // Size of each vertex in bytes
    FVertexSize: Integer;
    // Offset of each element within a vertex in bytes
    ElementOffs: array[vfiXYZ..vfiTEX7] of Integer;
    // Init internal variables for the specified vertex format
    procedure InitVertexFormat(Format: Cardinal); virtual;
    { Should return a maximum possible amount of vertices for the tesselator object to reserve place in buffers. <br>
      For rarely updated tesselators which still can have a variable number of vertices it's reasonable to use a static tesselator
      with <b>GetMaxVertices</b> the maximum amount of vertices.
      The return value of this function can vary but its change should be indicated with the @Link(tsMaxSizeChanged) teselation status and
      will cause discarding of a buffer which may cause performance penalty at lest for static buffers. }
    function GetMaxVertices: Integer; virtual;
    { Should return a maximum possible amount of indices for the tesselator object to reserve place in buffers. <br>
      For rarely updated tesselators which still can have a variable number of indices it's reasonable to use a static tesselator
      with <b>GetMaxVertices</b> the maximum amount of indices.
      The return value of this function can vary but its change should be indicated with the @Link(tsMaxSizeChanged) teselation status and
      will cause discarding of a buffer which may cause performance penalty at lest for static buffers. }
    function GetMaxIndices: Integer; virtual;
    // Set a coordinate set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataC(x, y, z: Single; Index: Integer; VBuf: Pointer); overload; {$I inline.inc}
    // Set a coordinate set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataC(const Vec: TVector3s; Index: Integer; VBuf: Pointer); overload; {$I inline.inc}
    // Set a transformed coordinate set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataCRHW(x, y, z, RHW: Single; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set a normal in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataN(nx, ny, nz: Single; Index: Integer; VBuf: Pointer); overload; {$I inline.inc}
    // Set a normal in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataN(const Vec: TVector3s; Index: Integer; VBuf: Pointer); overload; {$I inline.inc}
    // Set a weight in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataW(w: Single; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set a diffuse color (color 1) in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataD(Color: TColor; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set a specular color (color 2) in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataS(Color: TColor; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set first 2D-texture coordinates set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataUV(u, v: Single; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set first 3D-texture coordinates set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexDataUV3(u, v, w: Single; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Set second 2D-texture coordinates set in vertex buffer. [b]Index[/b] - element index, [b]VBuf[/b] - pointer to vertex buffer. Should be called from @Link(Tesselate) only
    procedure SetVertexData2UV(u, v: Single; Index: Integer; VBuf: Pointer); {$I inline.inc}
    // Sets an index in index buffer
    procedure SetIndex(AValue, AOffset: Integer; AIBuf: Pointer); {$I inline.inc}
  public
    // Returns an index from index buffer
    function GetIndex(AOffset: Integer; AIBuf: Pointer): Integer; {$I inline.inc}
    // Get a coordinate set from vertex buffer. [b]AIndex[/b] - element index, [b]AVBuf[/b] - pointer to vertex buffer.
    function GetVertexDataC(AIndex: Integer; AVBuf: Pointer): TVector3s; {$I inline.inc}
    // Performs render manually if ManualRender is True. Default implementation does nothing so the method should be overridden if manual render needed.
    procedure DoManualRender(Item: TItem); virtual;
    // Output format of vertices
    property VertexFormat: Cardinal read FVertexFormat write InitVertexFormat;
    // Size of each vertex in bytes
    property VertexSize: Integer read FVertexSize;
  end;

  // This message informs all visible items that tesselator has changed its bounding box
  TTessBBoxUpdateMsg = class(TMessage)
    Tesselator: TTesselator;
    constructor Create(ATesselator: TTesselator);
  end;

  // Base class of tesselator which used to tesselate several different items
  TSharedTesselator = class(TTesselator)
    // Clear tesselation
    procedure Clear; virtual; abstract;
  end;

//  TVisibilityCheckerDelegate = function(const Camera: TCamera): Boolean of object;

  TVisible = class(CAST2.TProcessing)
  private
    VisibilityFlag: Boolean;
    FCurrentLOD: Single;
    procedure SetTesselatorKind(const Value: TTesselatorKind);
  protected
    // A set of tesselators used to geometrically represent the item in various LOD's
    FTesselators: array of TTesselator;
    // True if the item should be lit by its own code
    FCustomLighting: Boolean;
    // Current render technique
    FCurTechnique: TTechnique;
    // Index in TRenderPass.Items array
    IndexInPass: array of Int32;
    // Determines what kind tesselator will be used to tesselated the item
    FTesselatorKind: TTesselatorKind;
    // Reference to current tesselator
    FCurrentTesselator: TTesselator;
    procedure SetParent(NewParent: TItem); override;
    procedure SetState(const Value: TSet32); override;
    procedure AddToPasses;
    procedure RemoveFromPasses;
    procedure DoShow; {$I inline.inc}
    procedure DoHide; {$I inline.inc}
    // Returns <b>True</b> if visibility mask of all parents has @Link(isVisible) flag included
    function isParentsVisible: Boolean;
    // Returns <b>True</b> if visibility mask of the item and all its parents has @Link(isVisible) flag included
    function isActuallyVisible: Boolean; {$I inline.inc}
    function GetMaterial: TMaterial;
    procedure SetMaterial(Value: TMaterial);
    procedure SetCurTechnique(const Value: TTechnique);
    procedure SetMesh; virtual;
    procedure SetCurrentLOD(const Value: Single); virtual;
  public
    // This value is calculated every frame for any item which should be rendered. Override @Link(CalcSortValue) to change it.
    SortValue: Single;
    BlendMatrices: array of TMatrix4s;  // ToDO: optimize
    RetrieveTextureMatrix: TTextureMatrixDelegate;

    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    class function IsAbstract: Boolean; override;
    // Returns class of tesselator which will represent the item geometrically
    function GetTesselatorClass: CTesselator; virtual;

    procedure HandleMessage(const Msg: TMessage); override;

    procedure OnInit; override;
    procedure OnSceneAdd; override;
    procedure OnSceneRemove; override;

    // Shows the item
    procedure Show; virtual;
    // Hides the item
    procedure Hide; virtual;

    // To specify shader constants an item class should override this method
    procedure RetrieveShaderConstants(var ConstList: TShaderConstants); virtual;
    // Returns value by which to sort items containing sorted order passes in material
    function CalcSortValue(const Camera: TCamera): Single; virtual;

    // If the item is visible through the given camera returns True and sets current tesselator according to needed detail level
    function VisibilityCheck(const Camera: TCamera): Boolean; virtual;
    // Should be overriden to render item indirectly or other custom rendering mode
    procedure Render; virtual;
    // Prepares the item and tesselator for manual lighting. Called automatically.
    procedure BeginLighting;
    // Calls tesselator to perform manual lighting calculation
    function CalculateLighting(const ALight: TLight): Boolean; {$I inline.inc}

    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;
  public
    // True if the item should be lit by its own code
    property CustomLighting: Boolean read FCustomLighting;
    property Material: TMaterial read GetMaterial write SetMaterial;
    property CurrentTesselator: TTesselator read FCurrentTesselator;
    property CurTechnique: TTechnique read FCurTechnique{ write SetCurTechnique};
    property TesselatorKind: TTesselatorKind read FTesselatorKind write SetTesselatorKind;
    property CurrentLOD: Single read FCurrentLOD write SetCurrentLOD;
  end;

  TClassRec = record
    TessClass: CTesselator;
    TessMap: BaseCont.TPointerPointerMap;                 // Maps a technique to a visible item
  end;

  TTemporaryVisible = class(TVisible)
  public
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    procedure Clear;
    function VisibilityCheck(const Camera: TCamera): Boolean; override;
  end;

  TSharedTesselators = class(CAST2.TBaseSharedTesselators)
  private
    Items: array of TVisible; TotalItems: Integer;

    TessClasses: array of TClassRec;

    function GetItemIndex(const AItem: TVisible): Integer; {$I inline.inc}

    function GetTesselatorIndex(const TessClass: CTesselator): Integer; {$I inline.inc}
    function AddTesselatorClass(const TessClass: CTesselator): Integer;

    function GetTesselator(const TessClass: CTesselator; const Technique: TTechnique): TTesselator;

    function DrawTechMap(Key, Value: Pointer): Boolean; {$I inline.inc}
    function DelTechMap(Key, Value: Pointer): Boolean; {$I inline.inc}
    function FreeTechMap(Key, Value: Pointer): Boolean; {$I inline.inc}
  public
    procedure AddItem(const AItem: TVisible); {$I inline.inc}
    procedure RemoveItem(const AItem: TVisible); {$I inline.inc}
    procedure ClearItems; override;
    procedure Clear; override;

    procedure Reset; override;
    procedure Render; override;

    destructor Destroy; override;

    property Tesselator[const TessClass: CTesselator; const Technique: TTechnique]: TTesselator read GetTesselator; default;
  end;

  TMappedTesselator = class(TTesselator)
  protected
    Item: CAST2.TProcessing;
    FMap: C2Maps.TMap;
  // Other
    OldWidth, OldHeight: Integer;
    OldCellWidthScale, OldCellHeightScale, OldDepthScale: Single;
  public
    procedure Init; override;
    function GetMaxVertices: Integer; override;
    function GetBoundingBox: TBoundingBox; override;
    procedure SetMap(const AMap: C2Maps.TMap); virtual;
  end;

  THeighTMapEditOp = class(C2Maps.TMapEditOp)
    // Inits the operation and returns True if it's valid and can be applied
    function Init(AMap: TMap; ACellX, ACellZ, ACursorSize: Integer; AValueDelta: Single): Boolean; virtual; abstract;
  end;

  THeighTMapEditOpAdjust = class(THeighTMapEditOp)
  private
    Scale: Single;
  public
    function Init(AMap: TMap; ACellX, ACellZ, ACursorSize: Integer; AValueDelta: Single): Boolean; override;
  end;

  THeighTMapEditOpSmooth = class(THeighTMapEditOp)
  private
    Scale: Single;
  public
    function Init(AMap: TMap; ACellX, ACellZ, ACursorSize: Integer; AValueDelta: Single): Boolean; override;
  end;

  TMappedItem = class(TVisible)
  protected
    FMap: C2Maps.TMap;
    {$IFDEF EDITORMODE}
    EditCellX, EditCellZ: Integer;
    EditMouseX, EditMouseY: Integer;
    EditCursorSize: Integer;
    EditMode: Boolean;
    {$ENDIF}
    procedure ResolveLinks; override;
    procedure OnModify(const ARect: BaseTypes.TRect); virtual;

    // Returns True if the specified cursor coordinates points to a map cell through the specified camera. Also returns the cell indices.
    function PickCell(Camera: TCamera; MouseX, MouseY: Integer; out CellX, CellZ: Integer): Boolean; virtual;
    {$IFDEF EDITORMODE}
    function DrawCursor(Cursor: C2MapEditMsg.TMapCursor; Camera: TCamera; Screen: TScreen): Boolean; virtual;
    procedure ModifyBegin(Cursor: TMapCursor; Camera: TCamera); virtual;
    procedure Modify(Cursor: TMapCursor; Camera: TCamera); virtual;
    procedure ModifyEnd(Cursor: TMapCursor; Camera: TCamera); virtual;
    {$ENDIF}
  public
    class function IsAbstract: Boolean; override;
    procedure SetMesh; override;
    procedure AddProperties(const Result: Props.TProperties); override;
    procedure SetProperties(Properties: Props.TProperties); override;

    procedure HandleMessage(const Msg: TMessage); override;

    property Map: C2Maps.TMap read FMap;
  end;

  /// Determines a vertex format which can include variuos components. VertexWeight can be OR'ed with vwIndexedBlending to indicate that last weight is actually a dword with indices
  function GetVertexFormat(Transformed, Normals, Diffuse, Specular, PointSize: Boolean; VertexWeights: Word; TextureSets: array of Integer): Longword;
  function GetVertexSize(VertexFormat: Longword): Cardinal;
  function VertexContains(VertexFormat, ElementIndex: Longword): Boolean; {$I inline.inc}
  function GetVertexElementOffset(VertexFormat, ElementIndex: Longword): Integer;
  function GetVertexTextureSetsCount(VertexFormat: Longword): Integer; {$I inline.inc}
  function GetVertexTextureCoordsCount(VertexFormat, TextureSetIndex: Longword): Integer; {$I inline.inc}
  function GetVertexWeightsCount(VertexFormat: Longword): Integer; {$I inline.inc}
  function GetVertexIndexedBlending(VertexFormat: Longword): Boolean; {$I inline.inc}
  procedure ConvertVertices(SrcFormat, DestFormat: Longword; TotalVertices: Integer; Src: Pointer; Dest: Pointer);

var RGBA: Boolean;            // Determines whether is needed to swap R and B color components. Must be True for OpenGL renderer due to difference in OpenGL and DirectX color representation

implementation

function GetVertexFormat(Transformed, Normals, Diffuse, Specular, PointSize: Boolean; VertexWeights: Word; TextureSets: array of Integer): Longword;
var i, TotalTextureSets: Integer; TextureBits: Integer;
begin
  Assert(((VertexWeights and $7) + Ord(VertexWeights and vwIndexedBlending > 0)<= 5) and
         ((VertexWeights and $7 > 0) or (VertexWeights and vwIndexedBlending = 0)), 'GetVertexFormat: Invalid weights count');
  Assert(not Transformed or (VertexWeights = 0), 'GetVertexFormat: Transformed vertices should not have weights');

  TextureBits := 0;
  TotalTextureSets := Length(TextureSets);
  for i := 0 to TotalTextureSets-1 do begin
    Assert((i < 8) and (TextureSets[i] > 0) and (TextureSets[i] <= 4), 'GetVertexFormat: Invalid texture sets');
    TextureBits := TextureBits or ((TextureSets[i]-1) and 3) shl (i*2);
  end;

  Result := VertexWeights shl 28 + Cardinal(TotalTextureSets) shl 24 + Cardinal(TextureBits) shl 8 +
            Cardinal(Ord(Transformed) * vfTRANSFORMED + Ord(Normals)  * vfNORMALS +
                     Ord(Diffuse)     * vfDIFFUSE     + Ord(Specular) * vfSPECULAR + Ord(PointSize) * vfPOINTSIZE);
end;

function GetVertexSize(VertexFormat: Longword): Cardinal;
var i, TextureSets: Integer; TextureBits: Cardinal;
begin
  Result := (3 + VertexFormat and vfTRANSFORMED    +
             Cardinal(3*Ord(VertexFormat and vfNORMALS   > 0)  +
                        Ord(VertexFormat and vfDIFFUSE   > 0)  + Ord(VertexFormat and vfSPECULAR > 0) +
                        Ord(VertexFormat and vfPOINTSIZE > 0)) +
             Cardinal(GetVertexWeightsCount(VertexFormat) + Ord(GetVertexIndexedBlending(VertexFormat))) ) shl 2;

  TextureBits := (VertexFormat shr 8) and $FFFF;
  TextureSets := (VertexFormat shr 24) and $F;
  for i := 0 to TextureSets-1 do Result := Result + (TextureBits shr (i*2) and 3 + 1) shl 2;
end;

function VertexContains(VertexFormat, ElementIndex: Longword): Boolean;
begin
  Result := VertexFormat and ElementIndex > 0;
end;

function GetVertexElementOffset(VertexFormat, ElementIndex: Longword): Integer;
var i, TextureSets: Integer; TextureBits: Cardinal;
begin
  Result := 0;
  if ElementIndex = vfiXYZ then Exit;

  if VertexFormat and vfTRANSFORMED > 0 then Result := 4*4 else Result := 3*4;

  if (GetVertexWeightsCount(VertexFormat) > 0) and GetVertexIndexedBlending(VertexFormat) then Inc(Result, 4);

  for i := 0 to GetVertexWeightsCount(VertexFormat)-1 do begin              // Through weights
    if ElementIndex = vfiWEIGHT1 + Cardinal(i) then Exit;
    Inc(Result, 4);
  end;

  if VertexFormat and vfNORMALS > 0 then begin
    if ElementIndex = vfiNORM then Exit;
    Inc(Result, 3*4);
  end;
  if VertexFormat and vfPOINTSIZE > 0 then begin
    if ElementIndex = vfiPOINTSIZE then Exit;
    Inc(Result, 4);
  end;
  if VertexFormat and vfDIFFUSE > 0 then begin
    if ElementIndex = vfiDIFF then Exit;
    Inc(Result, 4);
  end;
  if VertexFormat and vfSPECULAR > 0 then begin
    if ElementIndex = vfiSPEC then Exit;
    Inc(Result, 4);
  end;

  TextureBits := (VertexFormat shr 8) and $FFFF;
  TextureSets := (VertexFormat shr 24) and $F;
  for i := 0 to TextureSets-1 do begin       // Through texture sets
    if ElementIndex = vfiTEX0 + Cardinal(i) then Exit;
    Inc(Result, (TextureBits shr (i*2) and 3 + 1) shl 2);
  end;

  Result := -1;
//  Assert(False, 'GetVertexElementOffset: Element not found');
end;

function GetVertexTextureSetsCount(VertexFormat: Longword): Integer;
begin
  Result := (VertexFormat shr 24) and $F;
end;

function GetVertexTextureCoordsCount(VertexFormat, TextureSetIndex: Longword): Integer;
begin
  Result := ((VertexFormat shr 8) and $FFFF) shr (TextureSetIndex*2) and 3 + 1;
end;

function GetVertexWeightsCount(VertexFormat: Longword): Integer;
begin
  Result := (VertexFormat shr 28) and $7;
end;

function GetVertexIndexedBlending(VertexFormat: Longword): Boolean;
begin
  Result := (GetVertexWeightsCount(VertexFormat) > 0) and ((VertexFormat shr 28) and vwIndexedBlending > 0);
end;

procedure ConvertVertices(SrcFormat, DestFormat: Longword; TotalVertices: Integer; Src: Pointer; Dest: Pointer);
type TVBuf = array[0..$FFFFFF] of Byte;
const
  veiNorm = 0; veiDiff = 1; veiSpec = 2; veiWeight = 3; veiTex = 4;
  riSrc = 0; riDest = 1;
  elSize = 4;         // Element size (float)
var
  SVSize, DVSize, i: Integer; CoordsSize: Cardinal;
  EOffset: array[riSrc..riDest, veiNorm..veiTex] of Integer;

//  vfiXYZ = 0; vfiWEIGHT1 = 1; vfiWEIGHT2 = 2; vfiWEIGHT3 = 3; vfiNORM = 4; vfiPointSize = 5; vfiDIFF = 6; vfiSPEC = 7;
//  vfiTEX0 = 8; vfiTEX1 = 9; vfiTEX2 = 10; vfiTEX3 = 11; vfiTEX4 = 12; vfiTEX5 = 13; vfiTEX6 = 14; v

procedure CalcOffsets(Format, Res: Cardinal);
begin
  EOffset[Res, veiNorm]   := MaxI(0, GetVertexElementOffset(Format, vfiNorm));
  EOffset[Res, veiDiff]   := MaxI(0, GetVertexElementOffset(Format, vfiDiff));
  EOffset[Res, veiSpec]   := MaxI(0, GetVertexElementOffset(Format, vfiSpec));
  EOffset[Res, veiWeight] := MaxI(0, GetVertexElementOffset(Format, vfiWeight1));
  EOffset[Res, veiTex]    := MaxI(0, GetVertexElementOffset(Format, vfiTex0));
end;

function GetTextureSetsSize(Format: Longword): Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to GetVertexTextureSetsCount(Format)-1 do Inc(Result, GetVertexTextureCoordsCount(Format, i) * elSize);
end;

begin
  CalcOffsets(SrcFormat,  riSrc);
  CalcOffsets(DestFormat, riDest);
  SVSize := GetVertexSize(SrcFormat);
  DVSize := GetVertexSize(DestFormat);
  CoordsSize := 3*ElSize;                                         // XYZ compoments
  if VertexContains(SrcFormat, vfTransformed) and VertexContains(DestFormat, vfTransformed) then CoordsSize := 4*ElSize;
  if TotalVertices > 0 then FillChar(Dest^, TotalVertices * DVSize, 0);

  for i := 0 to TotalVertices-1 do begin
    Move(TVBuf(Src^)[i*SVSize], TVBuf(Dest^)[i*DVSize], CoordsSize);
    // Move weights
    Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, veiWeight]], TVBuf(Dest^)[i*DVSize + EOffset[riDest, veiWeight]],
         MinI(GetVertexWeightsCount(SrcFormat)  + Ord(GetVertexIndexedBlending(SrcFormat)),
              GetVertexWeightsCount(DestFormat) + Ord(GetVertexIndexedBlending(DestFormat)) ) * ElSize);

    if VertexContains(SrcFormat, vfNormals) and VertexContains(DestFormat, vfNormals) then
      Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, veiNorm]], TVBuf(Dest^)[i*DVSize + EOffset[riDest, veiNorm]], 3*ElSize);
    if VertexContains(SrcFormat, vfDiffuse) and VertexContains(DestFormat, vfDiffuse) then
      Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, veiDiff]], TVBuf(Dest^)[i*DVSize + EOffset[riDest, veiDiff]], ElSize);
    if VertexContains(SrcFormat, vfSpecular) and VertexContains(DestFormat, vfSpecular) then
      Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, veiSpec]], TVBuf(Dest^)[i*DVSize + EOffset[riDest, veiSpec]], ElSize);

    Move(TVBuf(Src^)[i*SVSize + EOffset[riSrc, veiTex]], TVBuf(Dest^)[i*DVSize + EOffset[riDest, veiTex]],
         MinI(GetTextureSetsSize(SrcFormat), GetTextureSetsSize(DestFormat)));
    
  end;
end;

{ TLookAtCamera }

procedure TLookAtCamera.SetRange(const Value: Single);
begin
  FRange := Value;
  Position := SubVector3s(FLookTarget, ScaleVector3s(ForwardVector, Exp(FRange)));
end;

procedure TLookAtCamera.SetFixedUp(const Value: Boolean);
begin
  FFixedUp := Value;
  if Value then FixedUpVector := UpVector;
end;

procedure TLookAtCamera.SetLookTarget(const Value: TVector3s);
begin
  FLookTarget := Value;
  SetRange(Range);
end;

procedure TLookAtCamera.ComputeTransform;
begin
  inherited;
  SetRange(Range);
//  inherited;
end;

{function TLookAtCamera.GetPosition: TVector3s;
begin
  Result := inherited GetPosition;
  Result := SubVector3s(Result, ScaleVector3s(ForwardVector, Exp(FRange)));
end;}

procedure TLookAtCamera.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;
  Result.Add('Range', vtSingle, [], FloatToStr(FRange), '');
  Result.Add('Fixed up vector', vtBoolean, [], OnOffStr[FixedUp], '');
  AddVector3sProperty(Result, 'Target', FLookTarget);
end;

procedure TLookAtCamera.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid('Range') then FRange := StrToFloatDef(Properties['Range'], 0);
  if Properties.Valid('Fixed up vector') then FixedUp := Properties.GetAsInteger('Fixed up vector') > 0;
  if SetVector3sProperty(Properties, 'Target', FLookTarget) then SetLookTarget(FLookTarget);
end;

procedure TLookAtCamera.Move(XD, YD, ZD: Single);
begin
  LookTarget := AddVector3s(LookTarget, AddVector3s(AddVector3s(ScaleVector3s(RightVector, XD), ScaleVector3s(UpVector, YD)), ScaleVector3s(ForwardVector, ZD)));
end;

{ TTessBBoxUpdateMsg }

constructor TTessBBoxUpdateMsg.Create(ATesselator: TTesselator);
begin
  Tesselator := ATesselator;
end;

{ TTesselator }

procedure TTesselator.InvalidateBoundingBox;
begin
  if Assigned(Manager) then Manager.SendMessage(TTessBBoxUpdateMsg.Create(Self), nil, [mfBroadcast]);
end;

constructor TTesselator.Create;
var i: TTesselationBuffer;
begin
  InitVertexFormat(GetVertexFormat(False, True, False, False, False, 0, [2]));
  PrimitiveType := ptTRIANGLELIST;

  for i := Low(TTesselationBuffer) to High(TTesselationBuffer) do begin
    TesselationStatus[i].BufferIndex            := -1;
    TesselationStatus[i].Offset                 := 0;
    TesselationStatus[i].Status                 := tsChanged;
    TesselationStatus[i].LastResetCounter       := 0;
    TesselationStatus[i].LastBufferResetCounter := 0;
    TesselationStatus[i].TesselatorType         := ttStatic;

    LastMaxAmount[i] := MaxInt;
  end;

  LastTotalIndices  := 0;
  LastTotalVertices := 0;

  TotalIndices      := 0;
  IndexingVertices  := 0;
  TotalStrips       := 1;
  StripOffset       := 0;

  VerticesRes       := -1;
  IndicesRes        := -1;

  CompositeOffset   := nil;
  CompositeMember   := False;

  CommandBlock := -1;
  CommandBlockValid := False;
end;

procedure TTesselator.Init;
var ParNum: Integer; Par1, Par2: Pointer;
begin
  ParNum := RetrieveParameters(Par1, False);
  RetrieveParameters(Par2, True);
  if ParNum > 0 then Move(Par1^, Par2^, ParNum * SizeOf(Cardinal));                        // Fill internal parameters with public ones
  Invalidate([tbVertex, tbIndex], False);
end;

procedure TTesselator.AddProperties(const Result: TProperties; const PropNamePrefix: TNameString);
begin
  if Assigned(Result) then begin
    Result.Add(PropNamePrefix + 'Manual render', vtBoolean, [], OnOffStr[ManualRender], '');
  end;
end;

procedure TTesselator.SetProperties(Properties: TProperties; const PropNamePrefix: TNameString);
begin
  if Properties.Valid(PropNamePrefix + 'Manual render') then ManualRender := Properties.GetAsInteger(PropNamePrefix + 'Manual render') > 0;
end;

procedure TTesselator.InitVertexFormat(Format: Cardinal);
var i: Integer;
begin
  FVertexFormat := Format;
  FVertexSize   := GetVertexSize(FVertexFormat);
  for i := vfiXYZ to vfiTEX7 do ElementOffs[i] := GetVertexElementOffset(FVertexFormat, i);
end;

procedure TTesselator.Invalidate(ABuffer: TTesselationBufferSet; EntireBuffer: Boolean);
var BType: TTesselationBuffer;
begin
  for BType := Low(BType) to High(BType) do if BType in ABuffer then                                            
    if TesselationStatus[BType].TesselatorType = ttStatic then begin
      if EntireBuffer then
        TesselationStatus[BType].Status := tsMaxSizeChanged else
          TesselationStatus[BType].Status := tsChanged;
    end;
  CommandBlockValid := False;
end;

function TTesselator.GetMaxVertices: Integer;
begin
  Result := TotalVertices;
end;

function TTesselator.GetMaxIndices: Integer;
begin
  Result := TotalIndices;
end;

function TTesselator.GetBoundingBox: TBoundingBox;
begin
  Result.P1 := GetVector3s(-1, -1, -1);
  Result.P2 := GetVector3s( 1,  1,  1);
end;

procedure TTesselator.SetIndex(AValue, AOffset: Integer; AIBuf: Pointer);
begin
  TWordBuffer(AIBuf^)[AOffset] := AValue;
end;

function TTesselator.GetIndex(AOffset: Integer; AIBuf: Pointer): Integer;
begin
  case IndexSize of
    2: Result := TWordBuffer(AIBuf^)[AOffset];
  end;
end;

function TTesselator.GetVertexDataC(AIndex: Integer; AVBuf: Pointer): TVector3s;
begin
  Assert(VertexFormat and vfTRANSFORMED = 0, ClassName + '.SetVertexDataC: This call is not allowed with existing vertex format');
  {$IFDEF DEBUGMODE}
  Assert(AIndex < GetMaxVertices, Format('%S.%S: Vertice index (%D) is greater than max vertices (%D)', [ClassName, 'GetVertexDataC', AIndex, GetMaxVertices]));
  {$ENDIF}

  Result := TVector3s(PtrOffs(AVBuf, AIndex * FVertexSize)^);
end;

function TTesselator.SetIndices(IBPTR: Pointer): Integer;
begin
  Result := 0;
end;

function TTesselator.Tesselate(const Params: TTesselationParameters; VBPTR: Pointer): Integer;
begin
  Result := 0;
  LastTotalVertices := TotalVertices;
end;

procedure TTesselator.SetVertexDataC(x, y, z: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfTRANSFORMED = 0, ClassName + '.SetVertexDataC: This call is not allowed with existing vertex format');
  {$IFDEF DEBUGMODE}
  Assert(Index < GetMaxVertices, Format('%S.%S: Vertice index (%D) is greater than max vertices (%D)', [ClassName, 'SetVertexDataC', Index, GetMaxVertices]));
  {$ENDIF}

  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize)^).X := x;
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize)^).Y := y;
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize)^).Z := z;
end;

procedure TTesselator.SetVertexDataC(const Vec: TVector3s; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfTRANSFORMED = 0, ClassName + '.SetVertexDataC: This call is not allowed with existing vertex format');
  {$IFDEF DEBUGMODE}
  Assert(Index < GetMaxVertices, Format('%S.%S: Vertice index (%D) is greater than max vertices (%D)', [ClassName, 'SetVertexDataC', Index, GetMaxVertices]));
  {$ENDIF}
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize)^) := Vec;
end;

procedure TTesselator.SetVertexDataCRHW(x, y, z, RHW: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfTRANSFORMED = vfTRANSFORMED, ClassName + '.SetVertexDataCRHW: This call is not allowed with existing vertex format');
  TVector4s(Pointer(Integer(VBuf) + Index * FVertexSize)^).X := x;
  TVector4s(Pointer(Integer(VBuf) + Index * FVertexSize)^).Y := y;
  TVector4s(Pointer(Integer(VBuf) + Index * FVertexSize)^).Z := z;
  TVector4s(Pointer(Integer(VBuf) + Index * FVertexSize)^).W := RHW;
end;

procedure TTesselator.SetVertexDataD(Color: TColor; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfDIFFUSE = vfDIFFUSE, ClassName + '.SetVertexDataD: This call is not allowed with existing vertex format');
  {$IFDEF DEBUGMODE}
  Assert(Index < GetMaxVertices, Format('%S.%S: Vertice index (%D) is greater than max vertices (%D)', [ClassName, 'SetVertexDataD', Index, GetMaxVertices]));
  {$ENDIF}
  if RGBA then begin   // Swap R and B components in Color
    Color.R := Color.R xor Color.B;
    Color.B := Color.R xor Color.B;
    Color.R := Color.R xor Color.B;
  end;
  TColor(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiDIFF])^) := Color;
end;

procedure TTesselator.SetVertexDataN(nx, ny, nz: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfNORMALS = vfNORMALS, ClassName + '.SetVertexDataN: This call is not allowed with existing vertex format');
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiNORM])^).X := nx;
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiNORM])^).Y := ny;
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiNORM])^).Z := nz;
end;

procedure TTesselator.SetVertexDataN(const Vec: TVector3s; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfNORMALS = vfNORMALS, ClassName + '.SetVertexDataN: This call is not allowed with existing vertex format');
  TVector3s(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiNORM])^) := Vec;
end;

procedure TTesselator.SetVertexDataS(Color: TColor; Index: Integer; VBuf: Pointer);
begin
  Assert(VertexFormat and vfSPECULAR = vfSPECULAR, ClassName + '.SetVertexDataS: This call is not allowed with existing vertex format');
  if RGBA then begin   // Swap R and B components in Color
    Color.R := Color.R xor Color.B;
    Color.B := Color.R xor Color.B;
    Color.R := Color.R xor Color.B;
  end;
  TColor(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiSPEC])^) := Color;
end;

procedure TTesselator.SetVertexDataUV(u, v: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(GetVertexElementOffset(VertexFormat, vfiTEX0) <> -1, ClassName + '.SetVertexDataUV: This call is not allowed with existing vertex format');
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX0])^) := u;
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX0] + 4)^) := v;
end;

procedure TTesselator.SetVertexDataUV3(u, v, w: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(GetVertexElementOffset(VertexFormat, vfiTEX0) <> -1, ClassName + '.SetVertexDataUV: This call is not allowed with existing vertex format');
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX0])^) := u;
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX0] + 4)^) := v;
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX0] + 8)^) := w;
end;

procedure TTesselator.SetVertexData2UV(u, v: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(GetVertexElementOffset(VertexFormat, vfiTEX1) <> -1, ClassName + '.SetVertexDataUV2: This call is not allowed with existing vertex format');
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX1])^) := u;
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiTEX1] + 4)^) := v;
end;

procedure TTesselator.SetVertexDataW(w: Single; Index: Integer; VBuf: Pointer);
begin
  Assert(GetVertexElementOffset(VertexFormat, vfiWEIGHT1) <> -1, ClassName + '.SetVertexDataW: This call is not allowed with existing vertex format');
  Single(Pointer(Integer(VBuf) + Index * FVertexSize + ElementOffs[vfiWEIGHT1])^) := w;
end;

function TTesselator.Validate: Boolean;
var i, MaxVertices, LTotalIndices: Integer; IBuf: Pointer;
begin
  Result := True;
  if GetMaxIndices = 0 then Exit;

  GetMem(IBuf, GetMaxIndices * IndexSize);
  MaxVertices   := GetMaxVertices;
  LTotalIndices := SetIndices(IBuf);

  i := 0;
  while (i < LTotalIndices) and (TWordBuffer(IBuf^)[i] < MaxVertices) do Inc(i);

  if (i < LTotalIndices) then begin
     Log(Format('%S.%S: Index #%D = %D (exceedes max vertice index = %D)', [ClassName, 'Validate', i, TWordBuffer(IBuf^)[i], MaxVertices-1]), lkWarning); 
    Result := False;
  end;

  FreeMem(IBuf);
end;

procedure TTesselator.BeginLighting;
begin
  Assert(False);
end;

function TTesselator.CalculateLighting(const ALight: TLight; const ALightToItem: TMatrix4s): Boolean;
begin
  Result := False;
  Assert(False);
end;
function TTesselator.GetUpdatedElements(Buffer: TTesselationBuffer; const Params: TTesselationParameters): Integer;
begin
  Result := 0;
  case Buffer of
    tbVertex: Result := TotalVertices * Ord(TesselationStatus[Buffer].Status <> tsTesselated);
    tbIndex:  Result := TotalIndices  * Ord(TesselationStatus[Buffer].Status <> tsTesselated);
  end;  
end;

function TTesselator.GetMaxAmount(Buffer: TTesselationBuffer): Integer;
begin
  case Buffer of
    tbVertex: Result := GetMaxVertices;
    tbIndex:  Result := GetMaxIndices;
    else Result := 0;
  end;
  LastMaxAmount[Buffer] := Result;
{  Assert((TesselationStatus[Buffer].TesselatorType <> ttStatic) or (Result <= LastMaxAmount[Buffer]),
         Format('%S.%S: Maximum amount of vertices or indices should not increase for tesselators placed in a static buffer',
                [ClassName, 'GetMaxAmount']));
  Result := Result * Ord((TesselationStatus[Buffer].TesselatorType <> ttStatic) or (Result <= LastMaxAmount[Buffer]));}
end;

procedure TTesselator.DoManualRender(Item: TItem);
begin
end;


{ TVisible }

constructor TVisible.Create(AManager: TItemsManager);
begin
  inherited;
  FState := FState + [isVisible];
  BlendMatrices := nil;
  IndexInPass   := nil;

  SetLength(FTesselators, 1);
  FTesselatorKind := tkOwn;
  
//  SetMesh;
end;

destructor TVisible.Destroy;
begin
  BlendMatrices := nil;
  IndexInPass   := nil;
  inherited;
end;

class function TVisible.IsAbstract: Boolean;
begin
  Result := Self = TVisible;
end;

function TVisible.GetTesselatorClass: CTesselator;
begin
  Result := nil;
end;

procedure TVisible.HandleMessage(const Msg: TMessage);
var i: Integer; OldCurTechnique: TTechnique;
begin
  inherited;

  if Msg.ClassType = TSceneLoadedMsg then begin
    GetMaterial;
  end else if Msg.ClassType = TTechniqueModificationBeginMsg then begin
    if TTechniqueModificationBeginMsg(Msg).Item = FCurTechnique then
      RemoveFromPasses;
  end else if Msg.ClassType = TTechniqueModificationEndMsg then begin
    if TTechniqueModificationBeginMsg(Msg).Item = FCurTechnique then begin
      OldCurTechnique := FCurTechnique;
      SetCurTechnique(nil);
      SetCurTechnique(OldCurTechnique);
    end;  
{  end else if Msg.ClassType = TParentStateChangeMsg then with TParentStateChangeMsg(Msg) do begin
    if not (isVisible in OldValue) and (isVisible in NewValue) then DoShow;
    if (isVisible in OldValue) and not (isVisible in NewValue) then DoHide;}
  end else if Msg.ClassType = ItemMsg.TReplaceMsg then begin
    with ItemMsg.TReplaceMsg(Msg) do if (OldItem = Self) then begin
      if VisibilityFlag then RemoveFromPasses;
      if NewItem is TVisible then begin
        SetLength(TVisible(NewItem).BlendMatrices, Length(BlendMatrices));
        for i := 0 to High(TVisible(NewItem).BlendMatrices) do TVisible(NewItem).BlendMatrices[i] := BlendMatrices[i];
        BlendMatrices := nil;
//        TVisible(NewItem).DoShow;
      end;
    end;
  end else if Msg.ClassType = C2Msg.TValidationResultChangedMsg then begin
    if TValidationResultChangedMsg(Msg).Item = Material then SetCurrentLOD(CurrentLOD);
  end else if Msg.ClassType = TTessBBoxUpdateMsg then begin
    if TTessBBoxUpdateMsg(Msg).Tesselator = FCurrentTesselator then
      BoundingBox := TTessBBoxUpdateMsg(Msg).Tesselator.GetBoundingBox;
  end;
end;

function TVisible.isParentsVisible: Boolean;
// Returns True if isVisible state is on for the item and all its predecessors which are TVisible
var Item: TItem;
begin
  Item := Self.Parent;
  while Assigned(Item) and
       ( not (Item is TVisible) or (isVisible in Item.State) ) do
    Item := Item.Parent;

  Result := not Assigned(Item);
end;

function TVisible.isActuallyVisible: Boolean;
begin
  Result := (isVisible in State) and isParentsVisible;
end;

procedure TVisible.OnInit;
begin
  inherited;
  SetMesh;
end;

procedure TVisible.OnSceneAdd;
begin
  inherited;
  if Assigned(IndexInPass) and (IndexInPass[0] = -1) then AddToPasses;
end;

procedure TVisible.OnSceneRemove;
begin
  inherited;
  if not FManager.IsShuttingdown() then RemoveFromPasses;
end;

procedure TVisible.Show;
begin
  State := FState + [isVisible];
end;

procedure TVisible.Hide;
begin
  State := FState - [isVisible];
end;

procedure TVisible.RetrieveShaderConstants(var ConstList: TShaderConstants);
begin
  ConstList := nil;
end;

function TVisible.CalcSortValue(const Camera: TCamera): Single;
begin
  SortValue := SqrMagnitude(SubVector3s(Camera.GetAbsLocation, GetAbsLocation));
  Result    := SortValue;
end;

procedure TVisible.SetMesh;

  procedure SetTesselator(var Tess: TTesselator);
  var NewTesselator: TTesselator;
  begin
    Assert(GetTesselatorClass() <> nil);
    if GetTesselatorClass() = nil then Exit;

    if Assigned(Tess) then begin
      if Tess.RefCount > 1 then begin                                   // tesselator defined and used by another item. Duplication may need.
        Tess.DecRef;
        if GetTesselatorClass() = Tess.ClassType then
          Tess := (FManager as CAST2.TBaseCore).TesselatorManager.FindSameItem(Tess) as TTesselator
        else
          Tess := nil;
      end else if GetTesselatorClass() <> Tess.ClassType then Tess := nil;
    end;  
    if not Assigned(Tess) then begin
      NewTesselator := GetTesselatorClass.Create;                                                    // Create a new tesselator
      Tess := (FManager as CAST2.TBaseCore).TesselatorManager.AddItem(NewTesselator) as TTesselator; // Try to add it to manager
      if Tess <> NewTesselator then NewTesselator.Free;                                              // Release it if the same found in manager
    end;  

(*    if (Tess <> nil) then begin
      if Tess.RefCount > 1 then begin                                   // tesselator defined and used by another item. Duplication may need.
        Tess.DecRef;
        Tess := (FManager as CAST2.TBaseCore).TesselatorManager.FindSameItem(Tess) as TTesselator;
        if Tess = nil then Tess := GetTesselatorClass.Create;
      end;
    end else if (GetTesselatorClass <> nil) then begin
      NewTesselator := GetTesselatorClass.Create;                                         // Create a new tesselator
      Tess := (FManager as CAST2.TBaseCore).TesselatorManager.AddItem(NewTesselator) as TTesselator; // Try to add it to manager
      if Tess <> NewTesselator then NewTesselator.Free;                             // Release it if the same found in manager
    end;*)

    if Tess <> nil then begin
      Tess.Manager := FManager;
      Tess.Init;
    end;
  end;

var i: Integer;
begin
  if (FManager = nil) or (FManager.Root = nil) then Exit;

  Assert(High(FTesselators) >= 0);

  if GetTesselatorClass <> nil then begin
    for i := 0 to High(FTesselators) do begin
//      if GetTesselatorClass <> FTesselators[i].ClassType then FTesselators[i] := nil;
      SetTesselator(FTesselators[i]);
    end;
    FCurrentTesselator := FTesselators[0];
  end;  

//  SetTesselator(FCurrentTesselator);

  if Assigned(FCurrentTesselator) then BoundingBox := FCurrentTesselator.GetBoundingBox;
end;

procedure TVisible.SetCurrentLOD(const Value: Single);
var Tech: TTechnique;
begin
  FCurrentLOD := Value;
  Tech := Material.GetTechniqueByLOD(Value);
  if Tech <> FCurTechnique then SetCurTechnique(Tech);
end;

procedure TVisible.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;
  AddItemLink(Result, 'Material', [], 'TMaterial');
  if Assigned(CurrentTesselator) then CurrentTesselator.AddProperties(Result, '');
  for i := 0 to High(FTesselators) do if Assigned(FTesselators[i]) then
    FTesselators[i].AddProperties(Result, 'Tesselator #' + IntToStr(i) + '\');
end;

procedure TVisible.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;
  if Properties.Valid('Material') then SetLinkProperty('Material', Properties['Material']);
  GetMaterial;
  if Assigned(CurrentTesselator) then CurrentTesselator.SetProperties(Properties, '');
  for i := 0 to High(FTesselators) do if Assigned(FTesselators[i]) then
    FTesselators[i].SetProperties(Properties, 'Tesselator #' + IntToStr(i) + '\');  
end;

function TVisible.VisibilityCheck(const Camera: TCamera): Boolean;
var d: Single; LOD: Integer;
begin
  Result := Camera.IsSpehereVisible(GetAbsLocation, BoundingSphereRadius) <> fcOutside;
  if Result then begin
    d := Sqrt(SqrMagnitude(SubVector3s(Camera.GetAbsLocation, GetAbsLocation)))/Camera.ZFar;
    LOD := ClampI(Round(High(FTesselators) * d), 0, High(FTesselators));
    FCurrentTesselator := FTesselators[LOD];
  end;
end;

procedure TVisible.Render;
begin
end;

procedure TVisible.BeginLighting;
begin
  if Assigned(FCurrentTesselator) then FCurrentTesselator.BeginLighting;
end;

function TVisible.CalculateLighting(const ALight: TLight): Boolean;
var LightToItem: TMatrix4s;
begin
  Assert(CustomLighting, Format('%S.%S: CustomLighting should be True', [ClassName, 'CalculateLighting']));
  if Assigned(FCurrentTesselator) then begin
    MulMatrix4s(LightToItem, InvertMatrix4s(Transform), ALight.Transform);
    Result := FCurrentTesselator.CalculateLighting(ALight, LightToItem);
  end else Result := False;
end;

procedure TVisible.AddToPasses;
var i: Integer;
begin
  if not isActuallyVisible then Exit;
  case TesselatorKind of
    tkOwn: if FCurTechnique <> nil then for i := 0 to FCurTechnique.TotalPasses-1 do begin
      Assert(IndexInPass[i] = -1, ClassName + '("' + GetFullName + '").DoShow: IndexInPass should be -1');
      if (IndexInPass[i] = -1) and (FCurTechnique.Passes[i] <> nil) then IndexInPass[i] := FCurTechnique.Passes[i].AddItem(Self);
    end;
    tkShared: ((FManager as CAST2.TBaseCore).SharedTesselators as TSharedTesselators).AddItem(Self);
  end;
end;

procedure TVisible.RemoveFromPasses;
var i: Integer;
begin
  case TesselatorKind of
    tkOwn: if FCurTechnique <> nil then for i := 0 to High(IndexInPass) do begin
      if IndexInPass[i] <> -1 then begin
//        Assert(FCurTechnique.TotalPasses > i, ClassName + '("' + GetFullName + '").DoHide: Invalid index ' + CurrentTesselator.ClassName);
        Assert((FCurTechnique.Passes[i].Items[IndexInPass[i]] = Self), ClassName + '("' + GetFullName + '").RemoveFromPasses: Item do not match');
        if FCurTechnique.Passes[i].RemoveItem(IndexInPass[i]) then
          TVisible(FCurTechnique.Passes[i].Items[IndexInPass[i]]).IndexInPass[i] := IndexInPass[i];   // ToDo: try to remove
        IndexInPass[i] := -1;
      end;
    end;
    tkShared: if Assigned((FManager as CAST2.TBaseCore).SharedTesselators) then
      ((FManager as CAST2.TBaseCore).SharedTesselators as TSharedTesselators).RemoveItem(Self);
  end;
end;

procedure TVisible.DoShow;
begin
  VisibilityFlag := True;
  AddToPasses;
end;

procedure TVisible.DoHide;
begin
  VisibilityFlag := False;
  RemoveFromPasses;  
end;

procedure TVisible.SetState(const Value: TSet32);

  procedure PropagateToChilds(Item: TItem; NewState: Boolean);
  var i: Integer;
  begin
    for i := 0 to Item.TotalChilds-1 do begin
      if (Item.Childs[i] is TVisible) then
//        if (TVisible(Item.Childs[i]).VisibilityFlag = NewState) then Continue else begin            // No neeed to propagate
          if NewState then TVisible(Item.Childs[i]).DoShow() else TVisible(Item.Childs[i]).DoHide();
//        end;
      PropagateToChilds(Item.Childs[i], NewState);
    end;
  end;

var OldState: TItemFlags;
begin
  OldState := State;
  inherited;
  if isParentsVisible then begin
    if not (isVisible in OldState) and (isVisible in Value) then begin
      DoShow;
      PropagateToChilds(Self, True);
    end;
    if (isVisible in OldState) and not (isVisible in Value) then begin
      DoHide;
      PropagateToChilds(Self, False);
    end;
  end;
end;

function TVisible.GetMaterial: TMaterial;
var LMaterial: TMaterial; Item: TItem;
begin
  if ResolveLink('Material', Item) then ;
  if Assigned(Item) then begin
    LMaterial := Item as TMaterial;
    SetCurTechnique(LMaterial.GetTechniqueByLOD(CurrentLOD));
  end;
  Result := Item as TMaterial;
end;

procedure TVisible.SetMaterial(Value: TMaterial);
begin
  if Assigned(Value) then
    SetLinkedObject('Material', Value)
  else                                    // Reset material
    SetCurTechnique(nil);
end;

procedure TVisible.SetCurTechnique(const Value: TTechnique);
begin
  if FCurTechnique = Value then Exit;
  RemoveFromPasses;
  FCurTechnique := Value;
  if Assigned(FCurTechnique) and (FCurTechnique.TotalPasses > Length(IndexInPass)) then begin
    SetLength(IndexInPass, FCurTechnique.TotalPasses);
    FillDWord(IndexInPass[0], FCurTechnique.TotalPasses, Cardinal(-1));
  end;
  AddToPasses;
end;

procedure TVisible.SetTesselatorKind(const Value: TTesselatorKind);
begin
  if FTesselatorKind = Value then Exit;
  RemoveFromPasses;
  FTesselatorKind := Value;
  AddToPasses;
end;

procedure TVisible.SetParent(NewParent: TItem);
begin
//  if isActuallyVisible then DoHide;
  inherited;
//  if isActuallyVisible then DoShow;
end;

{ TTemporaryVisible }

function TTemporaryVisible.VisibilityCheck(const Camera: TCamera): Boolean;
begin
  Result := True;
end;

procedure TTemporaryVisible.Clear;
var i: Integer;
begin
  for i := FTotalChilds-1 downto 0 do TVisible(Childs[i]).ClearParent;
  FTotalChilds := 0;
end;

constructor TTemporaryVisible.Create(AManager: TItemsManager);
begin
  inherited;
end;

destructor TTemporaryVisible.Destroy;
begin
  Clear;
  inherited;
end;

{ TSharedTesselators }

function TSharedTesselators.GetItemIndex(const AItem: TVisible): Integer;
begin
  Result := TotalItems-1;
  while (Result >= 0) and (Items[Result] <> AItem) do Dec(Result);
end;

function TSharedTesselators.GetTesselatorIndex(const TessClass: CTesselator): Integer;
begin
  Result := High(TessClasses);
  while (Result >= 0) and (TessClasses[Result].TessClass <> TessClass) do Dec(Result);
end;

function TSharedTesselators.AddTesselatorClass(const TessClass: CTesselator): Integer;
begin
  Assert(GetTesselatorIndex(TessClass) = -1, ClassName + '.AddTesselatorClass: Class already exists');
  Result := Length(TessClasses);
  SetLength(TessClasses, Result+1);
  TessClasses[Result].TessClass := TessClass;
  TessClasses[Result].TessMap   := BaseCont.TPointerPointerMap.Create(DefaultTechToItemMapCapacity);
end;

function TSharedTesselators.GetTesselator(const TessClass: CTesselator; const Technique: TTechnique): TTesselator;
var ClassIndex: Integer; Item: TVisible;
begin
  ClassIndex := GetTesselatorIndex(TessClass);
  if ClassIndex = -1 then ClassIndex := AddTesselatorClass(TessClass);
  Item := TVisible(TessClasses[ClassIndex].TessMap[Technique]);
  if Item = nil then begin
    Item := TTemporaryVisible.Create(Core);
    {$IFDEF DEBUGMODE} Item.Name := 'Temp visible'; {$ENDIF}
    Result := TessClass.Create;
    Item.FCurrentTesselator := Result;
    TessClasses[ClassIndex].TessMap[Technique] := Item;
  end else Result := Item.CurrentTesselator;
end;

function TSharedTesselators.DrawTechMap(Key, Value: Pointer): Boolean;
var Technique: TTechnique; Item: TVisible;
begin
  Result := False;
  if (Key = nil) or (Value = nil) then Exit;

  Technique := TTechnique(Key);
  Item      := TVisible(Value);

  Item.SetCurTechnique(Technique);
  Core.TempItems.AddChild(Item);
end;

function TSharedTesselators.DelTechMap(Key, Value: Pointer): Boolean;
begin
  Result := False;
  if (Key = nil) or (Value = nil) then Exit;

  if Assigned(TVisible(Value).CurrentTesselator) then
    TSharedTesselator(TVisible(Value).CurrentTesselator).Clear;
end;

function TSharedTesselators.FreeTechMap(Key, Value: Pointer): Boolean;
begin
  Result := False;
  if (Key = nil) or (Value = nil) then Exit;

  TVisible(Value).SetCurTechnique(nil);                                  // Remove item from passes
  
  TSharedTesselator(TVisible(Value).CurrentTesselator).Free;
//  Assert(Value <> nil);
  TVisible(Value).Free;
end;

procedure TSharedTesselators.AddItem(const AItem: TVisible);
begin
  Assert(GetItemIndex(AItem) = -1, ClassName + '.AddItem: Item already exists');
  if Length(Items) <= TotalItems then SetLength(Items, Length(Items) + ItemsCapacityStep);
  Items[TotalItems] := AItem;
  SetLength(AItem.IndexInPass, 1);
  AItem.IndexInPass[0] := TotalItems;
  Inc(TotalItems);
  Assert(TotalItems <= Length(Items));
end;

procedure TSharedTesselators.RemoveItem(const AItem: TVisible);
var Index: Integer;
begin
  Assert(TotalItems <= Length(Items));
  if AItem.IndexInPass = nil then Exit;                                  { TODO -cDebug : Figure out why RemoveItem can be called when IndexInPass = nil }
  if (TotalItems > 0) and ((AItem.IndexInPass[0] = -1) or (Items[AItem.IndexInPass[0]] = AItem)) then
    Index := AItem.IndexInPass[0]
  else
    Index := GetItemIndex(AItem);
  if Index = -1 then Exit;
  Assert(TotalItems > 0, ClassName + '.RemoveItem: No items');
//  Assert(Index <> -1, ClassName + '.RemoveItem: Item not found');

  while Index < TotalItems-1 do begin
    Items[Index] := Items[Index+1];
    {$IFDEF DEBUGMODE} Items[Index+1] := nil; {$ENDIF}
             if Length(Items[Index].IndexInPass) = 0 then SetLength(Items[Index].IndexInPass, 1);          //?
    Items[Index].IndexInPass[0] := Index;
    Inc(Index);
  end;

  AItem.IndexInPass[0] := -1;

  Dec(TotalItems);
end;

procedure TSharedTesselators.ClearItems;
var i: Integer;
begin
  for i := 0 to High(Items) do Items[i] := nil;
  TotalItems := 0;
end;

procedure TSharedTesselators.Clear;
var i: Integer;
begin
  Reset;
  for i := 0 to High(TessClasses) do begin
    TessClasses[i].TessMap.DoForEach({$IFDEF OBJFPCEnable}@{$ENDIF}FreeTechMap);
    FreeAndNil(TessClasses[i].TessMap);
  end;
  SetLength(TessClasses, 0);
  ClearItems;
end;

procedure TSharedTesselators.Reset;
var i: Integer;
begin
  for i := 0 to High(TessClasses) do TessClasses[i].TessMap.DoForEach({$IFDEF OBJFPCEnable}@{$ENDIF}DelTechMap);
end;

procedure TSharedTesselators.Render;
var i: Integer;
begin
//  Items[0].Render;
  for i := 0 to TotalItems-1 do Items[i].Render;                      // Fill tesselators with commands
  for i := 0 to High(TessClasses) do TessClasses[i].TessMap.DoForEach({$IFDEF OBJFPCEnable}@{$ENDIF}DrawTechMap);
end;

destructor TSharedTesselators.Destroy;
begin
  Clear;
  Items := nil;
  TessClasses := nil;
  inherited;
end;

{ TLight }

constructor TLight.Create(AManager: TItemsManager);
begin
  inherited;
  Ambient   := GetColor4S(0.5, 0.5, 0.5, 0.5);
  Diffuse   := GetColor4S(0.5, 0.5, 0.5, 0.5);
  Specular  := GetColor4S(0.0, 0.0, 0.0, 0.0);
  Range     := 1;
  Theta     := pi/4;
  Phi       := pi/3;
  GroupMask := gmDefault
end;

procedure TLight.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;
  if not Assigned(Result) then Exit;

  Result.AddEnumerated('Type',  [], Ord(Kind), LightKindsEnum);

  for i := 0 to PassGroupsCount-1 do Result.Add(Format('Pass groups\Group %D', [i+1]), vtBoolean, [], OnOffStr[i in GroupMask], '');

  AddColor4sProperty(Result, 'Color\Ambient',  Ambient);
  AddColor4sProperty(Result, 'Color\Diffuse',  Diffuse);
  AddColor4sProperty(Result, 'Color\Specular', Specular);

  Result.Add('Range',   vtSingle, [], FloatToStr(Range),   '0-100');
  Result.Add('Falloff', vtSingle, [], FloatToStr(Falloff), '');

  Result.Add('Constant attenuation',  vtSingle, [], FloatToStr(Attenuation0), '0-10');
  Result.Add('Linear attenuation',    vtSingle, [], FloatToStr(Attenuation1), '0-10');
  Result.Add('Quadratic attenuation', vtSingle, [], FloatToStr(Attenuation2), '0-10');

  Result.Add('Cone inner angle', vtSingle, [], FloatToStr(Theta * 180/pi), '0-180');
  Result.Add('Cone outer angle', vtSingle, [], FloatToStr(Phi * 180/pi),   '0-180');
end;

procedure TLight.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;

  for i := 0 to PassGroupsCount-1 do
    if Properties.Valid(Format('Pass groups\Group %D', [i+1])) then
      if Properties.GetAsInteger(Format('Pass groups\Group %D', [i+1])) > 0 then
        GroupMask := GroupMask + [i] else
          GroupMask := GroupMask - [i];

  if Properties.Valid('Type')  then Kind  := Properties.GetAsInteger('Type');

  SetColor4sProperty(Properties, 'Color\Ambient',  Ambient);
  SetColor4sProperty(Properties, 'Color\Diffuse',  Diffuse);
  SetColor4sProperty(Properties, 'Color\Specular', Specular);

  if Properties.Valid('Range')   then Range   := StrToFloatDef(Properties['Range'],   0);
  if Properties.Valid('Falloff') then Falloff := StrToFloatDef(Properties['Falloff'], 0);

  if Properties.Valid('Constant attenuation')  then Attenuation0 := StrToFloatDef(Properties['Constant attenuation'],  0);
  if Properties.Valid('Linear attenuation')    then Attenuation1 := StrToFloatDef(Properties['Linear attenuation'],    0);
  if Properties.Valid('Quadratic attenuation') then Attenuation2 := StrToFloatDef(Properties['Quadratic attenuation'], 0);

  if Properties.Valid('Cone inner angle') then Theta := StrToFloatDef(Properties['Cone inner angle'], 0) / 180*pi;
  if Properties.Valid('Cone outer angle') then Phi   := StrToFloatDef(Properties['Cone outer angle'], 0) / 180*pi;
end;

function TLight.GetEnabled: Boolean;
begin
  Result := isVisible in FState;
end;

procedure TLight.SetEnabled(const Value: Boolean);
begin
  if Value then FState := FState + [isVisible] else FState := FState - [isVisible];
end;

procedure TLight.HandleMessage(const Msg: TMessage);
begin
  inherited;
  if Msg.ClassType = ItemMsg.TReplaceMsg then with ItemMsg.TReplaceMsg(Msg) do if (OldItem = Self) then begin
  end;
end;

procedure TLight.SetState(const Value: TSet32);
begin
  if not (isVisible in FState) and (isVisible in Value) then Enabled := True;
  if (isVisible in FState) and not (isVisible in Value) then Enabled := False;
  inherited;
end;

{ TMappedTesselator }

function TMappedTesselator.GetBoundingBox: TBoundingBox;
begin
  Result := EmptyBoundingBox;
  if not Assigned(FMap) or (FMap.Width = 0) or (FMap.Height = 0) then Exit;
  Result.P1 := GetVector3s(-(FMap.Width-1)  * FMap.CellWidthScale * 0.5,
                            0,
                           -(FMap.Height-1) * FMap.CellHeightScale * 0.5);
  Result.P2 := GetVector3s( (FMap.Width-1)  * FMap.CellWidthScale * 0.5,
                            FMap.MaxHeight * FMap.DepthScale,
                            (FMap.Height-1) * FMap.CellHeightScale * 0.5);
end;

procedure TMappedTesselator.SetMap(const AMap: TMap);
begin
  FMap := AMap;
end;

function TMappedTesselator.GetMaxVertices: Integer;
begin
  Result := 0;
  if not Assigned(FMap) then Exit;
//  Result := (FMap.Width) * (FMap.Height);
  if (FMap.Width <> OldWidth) or (FMap.Height <> OldHeight) or
     (FMap.CellWidthScale <> OldCellWidthScale) or (FMap.CellHeightScale <> OldCellHeightScale) or
     (FMap.DepthScale <> OldDepthScale) then Init;
  Result := inherited GetMaxVertices;
end;

procedure TMappedTesselator.Init;
begin
  inherited;
  if Assigned(FMap) then begin
    OldWidth           := FMap.Width;
    OldHeight          := FMap.Height;
    OldCellWidthScale  := FMap.CellWidthScale;
    OldCellHeightScale := FMap.CellHeightScale;
    OldDepthScale      := FMap.DepthScale;
  end else begin
    TotalVertices   := 0;
    TotalIndices    := 0;
    TotalPrimitives := 0;
  end;
  InvalidateBoundingBox;
  Invalidate([tbVertex, tbIndex], True);
end;

{ TMappedItem }

const MapPropName = 'Map';

procedure TMappedItem.ResolveLinks;
var i: Integer; Item: TItem;
begin
  inherited;
  ResolveLink(MapPropName, Item);

  if Assigned(Item) then begin
    FMap := Item as C2Maps.TMap;
    for i := 0 to High(FTesselators) do if FTesselators[i] is TMappedTesselator then begin
      (FTesselators[i] as TMappedTesselator).SetMap(Item as C2Maps.TMap);
      FTesselators[i].Init;
    end;
  end;
end;

procedure TMappedItem.OnModify(const ARect: TRect);
begin
end;

class function TMappedItem.IsAbstract: Boolean;
begin
  Result := Self = TMappedItem;
end;

procedure TMappedItem.SetMesh;
begin
  inherited;
  (CurrentTesselator as TMappedTesselator).Item := Self;
end;

procedure TMappedItem.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if Assigned(Result) then begin
  end;

  AddItemLink(Result, MapPropName, [], 'TMap');
end;

procedure TMappedItem.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid(MapPropName) then SetLinkProperty(MapPropName, Properties[MapPropName]);

  ResolveLinks;
end;

procedure TMappedItem.HandleMessage(const Msg: TMessage);
begin
  inherited;
  {$IFDEF EDITORMODE}
  if Msg.ClassType = TMapDrawCursorMsg  then with TMapDrawCursorMsg(Msg) do DrawCursor(Cursor, Cursor.Camera, Cursor.Screen);
  if Msg.ClassType = TMapModifyBeginMsg then with TMapEditorMessage(Msg) do ModifyBegin(Cursor, Cursor.Camera);
  if Msg.ClassType = TMapModifyMsg      then with TMapEditorMessage(Msg) do Modify(Cursor, Cursor.Camera);
  if Msg.ClassType = TMapModifyEndMsg   then with TMapEditorMessage(Msg) do ModifyEnd(Cursor, Cursor.Camera);

  if Msg.ClassType = TRequestMapEditVisuals then with TRequestMapEditVisuals(Msg) do begin
    Cursor.Params.Add('Size', vtNat, [], '1', '1-64', '');
    Cursor.Params.AddEnumerated('Mode', [], 0, 'Heights\&Smooth');
  end;

  {$ENDIF}
  if (Msg.ClassType = TItemModifiedMsg) and (TItemModifiedMsg(Msg).Item = Map) then CurrentTesselator.Invalidate([tbVertex, tbIndex], False);
end;


function TMappedItem.PickCell(Camera: TCamera; MouseX, MouseY: Integer; out CellX, CellZ: Integer): Boolean;
var CameraPos, PickRay, PickPos: TVector3s; M: TMatrix4s;
begin
  Result := False;
  if not Assigned(FMap) then Exit;

  // Transform camera position and pick ray to model space
  M := InvertMatrix4s(Transform);
  CameraPos := Transform4Vector33s(M, Camera.Position);
  PickRay := Camera.GetPickRay(MouseX, MouseY);
  PickRay := Transform3Vector3s(CutMatrix3s(InvertAffineMatrix4s(Camera.ViewMatrix)), PickRay);
  PickRay.Y := PickRay.Y;
  PickRay := NormalizeVector3s(Transform3Vector3s(CutMatrix3s(M), PickRay));
  Result := FMap.TraceRay(CameraPos, PickRay, PickPos);
  if Result then Map.ObtainCell(PickPos.X, PickPos.Z, CellX, CellZ);
end;

{$IFDEF EDITORMODE}
function TMappedItem.DrawCursor(Cursor: TMapCursor; Camera: TCamera; Screen: TScreen): Boolean;

  procedure DrawCell(CellX, CellZ: Integer);
    function CalcLinePos: TVector3s;
    begin
      Result.X := (CellX - (FMap.Width -1) * 0.5) * FMap.CellWidthScale;
      Result.Y := FMap[CellX, CellZ] * FMap.DepthScale;
      Result.Z := (CellZ - (FMap.Height-1) * 0.5) * FMap.CellHeightScale;
      Result := Transform4Vector33s(Transform, Result);
    end;
    
  begin
    if (CellX < 1) or (CellZ < 1) or (CellX > FMap.Width-2) or (CellZ > FMap.Height-2) then Exit;
    Screen.MoveToVec(Camera.Project(CalcLinePos).xyz);
    Inc(CellX);
    Screen.LineToVec(Camera.Project(CalcLinePos).xyz);
    Inc(CellZ);
    Screen.LineToVec(Camera.Project(CalcLinePos).xyz);
    Dec(CellX);
    Screen.LineToVec(Camera.Project(CalcLinePos).xyz);
    Dec(CellZ);
    Screen.LineToVec(Camera.Project(CalcLinePos).xyz);
  end;

  procedure DrawCursorAt(CellX, CellZ, Size: Integer);
  var i, j: Integer;
  begin
//    Screen.MoveTo(0, 0);
//    Screen.LineTo(0, 0);
    for i := CellX - Size div 2 to CellX + Size div 2 do
      for j := CellZ - Size div 2 to CellZ + Size div 2 do DrawCell(i, j);
  end;

begin
  Result := False;
  if not Assigned(FMap) or not EditMode and not PickCell(Camera, Cursor.MouseX, Cursor.MouseY, EditCellX, EditCellZ) then Exit;

  DrawCursorAt(EditCellX, EditCellZ, Cursor.Params.GetAsInteger('Size'));

  Result := True;
end;

procedure TMappedItem.ModifyBegin(Cursor: TMapCursor; Camera: TCamera);
var Op: THeighTMapEditOp;
begin
  if FMap.Data = nil then Exit;

  EditMouseX     := Cursor.MouseX;
  EditMouseY     := Cursor.MouseY;
  EditCursorSize := ClampI(Cursor.Params.GetAsInteger('Size'), 1, MaxCursorSize);

  case Cursor.Params.GetAsInteger('Mode') of
    hmemSmooth: begin
      EditMode := True;
      Modify(Cursor, Camera);      
      Exit;
    end;
  end;

  if PickCell(Camera, Cursor.MouseX, Cursor.MouseY, EditCellX, EditCellZ) then begin
    EditMode := True;
    case Cursor.Params.GetAsInteger('Mode') of
      hmemAdjust: begin
        Op := THeighTMapEditOpAdjust.Create;
        Include(Op.Flags, ofIntermediate);
        Cursor.Operation := Op;
      end;
    end;
  end else EditMode := False;
end;

procedure TMappedItem.Modify(Cursor: TMapCursor; Camera: TCamera);
var Op: THeighTMapEditOp;
begin
  if not EditMode or (FMap.Data = nil) then Exit;

  case Cursor.Params.GetAsInteger('Mode') of
    hmemAdjust: begin
      Assert(Cursor.Operation is THeighTMapEditOpAdjust);
      with THeighTMapEditOpAdjust(Cursor.Operation) do begin
        OnModify(GetRect(EditCellX - EditCursorSize, EditCellZ - EditCursorSize, EditCellX + EditCursorSize+1, EditCellZ + EditCursorSize+1));
        Apply;                                       // Undo previous iteration
        Init(FMap, EditCellX, EditCellZ, EditCursorSize, Cursor.MouseY - EditMouseY);
      end;
    end;
    hmemSmooth: if PickCell(Camera, Cursor.MouseX, Cursor.MouseY, EditCellX, EditCellZ) then begin
      Op := THeighTMapEditOpSmooth.Create;
      if Op.Init(FMap, EditCellX, EditCellZ, EditCursorSize, Cursor.MouseY - EditMouseY) then
        Cursor.Operation := Op else
          Op.Free;
      OnModify(GetRect(EditCellX - EditCursorSize, EditCellZ - EditCursorSize, EditCellX + EditCursorSize+1, EditCellZ + EditCursorSize+1));
    end;
    else Assert(False);
  end;
end;

procedure TMappedItem.ModifyEnd(Cursor: TMapCursor; Camera: TCamera);
begin
  EditMode := False;
  case Cursor.Params.GetAsInteger('Mode') of
    hmemAdjust: begin
      Assert(Cursor.Operation is THeighTMapEditOpAdjust);
      with THeighTMapEditOpAdjust(Cursor.Operation) do begin
        Apply;                                       // Undo previous iteration
        if Init(FMap, EditCellX, EditCellZ, EditCursorSize, Cursor.MouseY - EditMouseY) then
          Exclude(Cursor.Operation.Flags, ofIntermediate) else
            FreeAndNil(Cursor.Operation);
      end;
    end;
    else OnModify(GetRect(EditCellX - EditCursorSize, EditCellZ - EditCursorSize, EditCellX + EditCursorSize+1, EditCellZ + EditCursorSize+1));
  end;

end;

{$ENDIF}

{ THeighTMapEditOpAdjust }

function THeighTMapEditOpAdjust.Init(AMap: TMap; ACellX, ACellZ, ACursorSize: Integer; AValueDelta: Single): Boolean;
var i, j, StartI, StartJ, OfsI, OfsJ: Integer; Value, norm: Single;
begin
  Result := False;
  if (ACursorSize = 0) or not Assigned(AMap) or (Abs(AValueDelta) < epsilon) then Exit;
  Scale      := -1;
  Map        := AMap;
  CellX      := ACellX;
  CellZ      := ACellZ;
  CursorSize := ACursorSize;
  GetMem(Buffer, CursorSize * CursorSize * Map.ElementSize);
  Result := True;

  StartI := CellX - CursorSize div 2;
  if StartI < 0 then begin
    OfsI   := -StartI;
    StartI := 0;
  end else OfsI := 0;
  StartJ := CellZ - CursorSize div 2;
  if StartJ < 0 then begin
    OfsJ   := -StartJ;
    StartJ := 0;
  end else OfsJ := 0;

  norm := 1 / Sqr(CursorSize*0.5);

  case Map.ElementSize of
    1: for j := StartJ to MinI(Map.Height-1, CellZ - CursorSize div 2 + CursorSize-1) do
         for i := StartI to MinI(Map.Width-1, CellX - CursorSize div 2 + CursorSize-1) do begin
      Value := PByteBuffer (Map.Data)^[(j * Map.Width + i)];
      Value := ClampS(Value + AValueDelta * Scale * MaxS(0, (1-(Sqr(i-CellX) + Sqr(j-CellZ)) * norm)), 0, Map.MaxHeight);
      PByteBuffer (Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI)]     := Round(Value);
    end;
    2: for j := StartJ to MinI(Map.Height-1, CellZ - CursorSize div 2 + CursorSize-1) do
         for i := StartI to MinI(Map.Width-1, CellX - CursorSize div 2 + CursorSize-1) do begin
      Value := PWordBuffer (Map.Data)^[(j * Map.Width + i) * 2];
      Value := ClampS(Value + AValueDelta * Scale * MaxS(0, (1-(Sqr(i-CellX) + Sqr(j-CellZ)) * norm)), 0, Map.MaxHeight);
      PWordBuffer (Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI) * 2] := Round(Value);
    end;
    4: for j := StartJ to MinI(Map.Height-1, CellZ - CursorSize div 2 + CursorSize-1) do
         for i := StartI to MinI(Map.Width-1, CellX - CursorSize div 2 + CursorSize-1) do begin
      Value := PDWordBuffer(Map.Data)^[(j * Map.Width + i) * 4];
      Value := ClampS(Value + AValueDelta * Scale * MaxS(0, (1-(Sqr(i-CellX) + Sqr(j-CellZ)) * norm)), 0, Map.MaxHeight);
      PDWordBuffer(Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI) * 4] := Round(Value);
    end;
  end;
end;

{ THeighTMapEditOpSmooth }

function THeighTMapEditOpSmooth.Init(AMap: TMap; ACellX, ACellZ, ACursorSize: Integer; AValueDelta: Single): Boolean;
var i, j, i1, i2, j1, j2, StartI, StartJ, OfsI, OfsJ: Integer; Value, norm, k: Single;
begin
  Result := False;
  if (ACursorSize = 0) or not Assigned(AMap) then Exit;
  Scale      := -1;
  Map        := AMap;
  CellX      := ACellX;
  CellZ      := ACellZ;
  CursorSize := ACursorSize;
  GetMem(Buffer, CursorSize * CursorSize * Map.ElementSize);
  Result := True;

  StartI := CellX - CursorSize div 2;
  if StartI < 0 then begin
    OfsI   := -StartI;
    StartI := 0;
  end else OfsI := 0;
  StartJ := CellZ - CursorSize div 2;
  if StartJ < 0 then begin
    OfsJ   := -StartJ;
    StartJ := 0;
  end else OfsJ := 0;

  norm := 1 / {Sqr}(CursorSize*0.5);

  case Map.ElementSize of
    1: for j := StartJ to MinI(Map.Height-1, CellZ - CursorSize div 2 + CursorSize-1) do
         for i := StartI to MinI(Map.Width-1, CellX - CursorSize div 2 + CursorSize-1) do begin
      i1 := MaxI(i-1, 0);
      j1 := MaxI(j-1, 0);
      i2 := MinI(i+1, Map.Width-1);
      j2 := MinI(j+1, Map.Height-1);
      Value := (PByteBuffer (Map.Data)^[j1 * Map.Width + i1] +
                PByteBuffer (Map.Data)^[j1 * Map.Width + i] +
                PByteBuffer (Map.Data)^[j1 * Map.Width + i2] +
                PByteBuffer (Map.Data)^[j * Map.Width + i1] +
//                PByteBuffer (Map.Data)^[(j * Map.Width + i)] +
                PByteBuffer (Map.Data)^[j * Map.Width + i2] +
                PByteBuffer (Map.Data)^[j2 * Map.Width + i1] +
                PByteBuffer (Map.Data)^[j2 * Map.Width + i] +
                PByteBuffer (Map.Data)^[j2 * Map.Width + i2]) div 8;
//      Value := ClampS(Value, 0, Map.MaxHeight);
      k := MaxS(0, (1-Sqrt(Sqr(i-CellX) + Sqr(j-CellZ)) * norm));
      Value := ClampS(PByteBuffer (Map.Data)^[(j * Map.Width + i)] * (1-k) +
                      Value * k, 0, Map.MaxHeight);
      PByteBuffer (Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI)]     := Round(Value);
    end;
    2: ;//Value := PWordBuffer (Map.Data)^[(j * Map.Width + i) * 2];
    4: ;//Value := PDWordBuffer(Map.Data)^[(j * Map.Width + i) * 4];
  end;


{      case Map.ElementSize of
        1:
        2: PWordBuffer (Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI) * 2] := Round(Value);
        4: PDWordBuffer(Buffer)^[((j-StartJ + OfsJ) * CursorSize + i - StartI + OfsI) * 4] := Round(Value);
      end;
    end;}
end;

{ TShadowMapCamera }

const LightSourcePropName = 'Light source';

procedure TShadowMapCamera.ResolveLinks;
var i: Integer; Item: TItem;
begin
  inherited;
  ResolveLink(LightSourcePropName, Item);

  if Item is TLight then begin
    FLight := TLight(Item);
    InvalidateTransform();
  end;
end;

procedure TShadowMapCamera.HandleMessage(const Msg: TMessage);
begin
  inherited;
  if Msg.ClassType = ItemMsg.TReplaceMsg then                                       // Check if cached light link was changed
    with ItemMsg.TReplaceMsg(Msg) do if (OldItem = FLight) and (NewItem is TLight) then FLight := TLight(NewItem);
end;

procedure TShadowMapCamera.AddProperties(const Result: Props.TProperties);
begin
  inherited;

  if Assigned(Result) then begin
  end;

  AddItemLink(Result, LightSourcePropName, [], 'TLight');
end;

procedure TShadowMapCamera.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if Properties.Valid(LightSourcePropName) then SetLinkProperty(LightSourcePropName, Properties[LightSourcePropName]);
  ResolveLinks;
end;

procedure TShadowMapCamera.ComputeViewMatrix;
begin
  if Assigned(FLight) then begin
    FInvViewMatrix := FLight.Transform;
    FViewMatrix := InvertAffineMatrix4s(FInvViewMatrix);
    MulMatrix4s(FTotalMatrix, FViewMatrix, ProjMatrix);
    FViewValid := True;
    ComputeFrustumPlanes;
  end else inherited;
end;

procedure TShadowMapCamera.OnApply(const OldCamera: TCamera);
begin
  inherited;

end;

end.
