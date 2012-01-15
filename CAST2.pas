(*
 @Abstract(CAST II Engine main unit)
 (C) 2006-2009 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Started Jan 15, 2006 <br>
 Unit contains basic engine classes
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit CAST2;

interface

uses
  Logger, Timer,
  BaseTypes, Basics, BaseStr, BaseCont, Models, BaseClasses, Base3D, BaseMsg, ItemMsg, Collisions, Props, C2Types;

const
  EngineVersionMajor = '0';
  EngineVersionMinor = '995';
  // Bounding volume kinds enumeration string
  VolumeKindsEnum = 'OOBB' + StrDelim + 'Sphere' + StrDelim + 'Cylinder' + StrDelim + 'Cone' + StrDelim + 'Capsule' + StrDelim + 'Chamfer Cylinder';

  // Items processing interval by default
  DefaultProcessingInterval = 30/1000;

  // Pass ordering enumeration string
  PassOrdersEnum = 'Preprocess\&Background\&Farest\&Normal\&Sorted\&Nearest\&Foreground\&PostProcess';

  // This order used for preprocess passes
  poPreprocess = 0;
  // This order used for passes that should be at background
  poBackground = 1;
  // This order used for passes that should be farest
  poFarest = 2;
  // This order used for usual passes
  poNormal = 3;
  // This order used for passes that should render corresponding items in a particular order (usually transparent items)
  poSorted = 4;
  // This order used for passes that should be neartest
  poNearest = 5;
  // This order used for passes that should be at foreground
  poForeground = 6;
  // This order used for postprocess passes
  poPostProcess = 7;

  // Order corresponding to passes with sorted items
  SortedPassOrder = poSorted;
  // Number of pass groups currently supported by the engine
  PassGroupsCount = 16;
  // Pass groups enumeration string
  PassGroupsEnum = 'Group 01\&Group 02\&Group 03\&Group 04\&Group 05\&Group 06\&Group 07\&Group 08\&' +
                   'Group 09\&Group 10\&Group 11\&Group 12\&Group 13\&Group 14\&Group 15\&Group 16';
  // Set of all pass groups
  gmAll     = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  // Default set of pass groups
  gmDefault = [0, 1, 2, 3, 4, 5, 6, 7];

  // Maximum of texture coordinates sets
  MaxTextureCoordSets = 8;
  // Maximum of user-defined clipping planes currently supported by the engine
  MaxClipPlanes       = 6;

type
  // Type to specify location of an object in 3D space. Additional component can be used to work with floating coordinates, space partitioning, etc.
  TLocation = TVector4s;

  // Traverse callback results
  TTraverseResult = (// Continue traversal
                     trContinue,
                     // Skip traversal for childs of the current item
                     trSkip,
                     // Stop traversal
                     trStop);
  // Frustum planes
  TFrustumPlane = (fpLeft, fpRight, fpTop, fpBottom, fpNear, fpFar);


  TFrustumCheckResult = (// An item is completely outside of the frustum
                         fcOutside,
                         // An item is completely inside the frustum
                         fcInside,
                         // An item is partially inside the frustum
                         fcPartially);

  // Pass groups range
  TPassGroup = 0..PassGroupsCount-1;
  // Pass groups set. Groups used to perform some operations (lighting, render) for one set of passes and not to perform for other set of passes
  TPassGroupSet = set of TPassGroup;

  // User-defined clipping planes
  TClipPlanes = array[0..MaxClipPlanes-1] of PPlane;

  // Traverse mask
  TTraverseMask = BaseTypes.TSet32;

  TProcessing = class;

  // Class reference of collision-related information object
  CBaseColliding = class of TBaseColliding;
  // Class containing abstract part of collision-related information object for an item
  TBaseColliding = class(BaseCont.TBaseUniqueItem)
  protected
    // The item to which the collision information belongs
    FOwner: BaseClasses.TItem;
    // Returns True if the object contains valid physics representation and can be handled by a physics subsystem
    function IsValid: Boolean; virtual; abstract;
    // Flushes properties to a physics subsystem. Called automatically.
    procedure FlushProperties; virtual; abstract;
  public
    // Bounding volumes set
    Volumes: Collisions.TBoundingVolumes;
    // Collision info constructor
    constructor Create(AOwner: TItem); reintroduce; virtual;
    // This procedure is called (by editor for example) to retrieve a list of item's properties and their values. No item links allowed.
    procedure AddProperties(const Result: Props.TProperties); virtual; abstract;
    // This procedure is called (by editor for example) to set values of item's properties.
    procedure SetProperties(Properties: Props.TProperties); virtual; abstract;
    // The item to which the collision information belongs
    property Owner: BaseClasses.TItem read FOwner;
  end;

  // Tesselation buffers enumeration
  TTesselationBuffer = (// Vertex buffer
                        tbVertex,
                        // Index buffer
                        tbIndex);
  // Set of tesselation buffers
  TTesselationBufferSet = set of TTesselationBuffer;

  // Vertex/index buffers performace profile
  TBuffersPerfProfile = record
    // Number of tesselation calls for static and dynamic meshes in current frame. Normally should be zero for static meshes
    TesselationsPerformed,
    // Amount of data written to buffers during tesselation
    BytesWritten,
    // Number of resets of static and dynamic buffers in current frame. Normally should be zero for static buffers
    BufferResetsCount,
    // Current size of the buffer in bytes
    BufferSize: array[Boolean] of Integer;
    // Number of items rendered without tesselations of a certain buffer (vertex/index)
    TesselationsBypassed,
    // Number of buffer bytes reused
    BytesBypassed: Integer;
  end;

  // Performance profile target enumeration
  TPerfTimer = (// Entire frame time
                ptFrame,
                // Render time
                ptRender,
                // Objects processing time
                ptProcessing,
                // Collision detection
                ptCollision);
  // Engine performance profile data
  TPerfProfile = class
  private
    TimeMarks: array[TPerfTimer] of TTimeMark;
    FFramesPerSecond, FMinFramesPerSecond, FMaxFramesPerSecond: Single;
    procedure SetFramesPerSecond(const Value: Single);
    function GetPrimitivesPerSecond: Single;
  public
    Times: array[TPerfTimer] of TTimeUnit;

    // Number of render target changes during rendering a frame
    RenderTargetChanges,
    // Number of primitives (triangles) rendered in current frame
    PrimitivesRendered,
    // Number of draw calls (DrawIndexedPrimitive etc) in current frame
    DrawCalls,
    // Number of clear calls during rendering a frame
    ClearCalls: Integer;
    // Number of items culled out with frustum culling in current frame
    FrustumCulledItems,
    // Number of items passed frustum culling (and probably actually drawn) in current frame
    FrustumPassedItems: Integer;
    // Number of sorted items in current frame
    SortedItems: Integer;

    // Vertex/index buffers performace profile
    BuffersProfile: array[TTesselationBuffer] of TBuffersPerfProfile;

    // Sets values which should be zeroed-out at frame render start
    procedure OnFrameStart;
    // Sets values which should be resetted at render buffers reset
    procedure OnBuffersReset;

    // Starts timing of the specified performance timer using the specified timer class
    procedure BeginTiming(Timer: TTimer; PerfTimer: TPerfTimer);
    // Stops timing and returns the specified performance timer value using the specified timer class
    function EndTiming(Timer: TTimer; PerfTimer: TPerfTimer): TTimeUnit;

    // Frame rate averaged through some time
    property FramesPerSecond: Single read FFramesPerSecond write SetFramesPerSecond;
    // Number of primitives per second
    property PrimitivesPerSecond: Single read GetPrimitivesPerSecond;
    // Minimal averaged frame rate
    property MinFramesPerSecond: Single read FMinFramesPerSecond;
    // Maximal averaged frame rate
    property MaxFramesPerSecond: Single read FMaxFramesPerSecond;
  end;

  TBaseCore = class;

  // Base class of shared tesselators manager
  TBaseSharedTesselators = class
    // Engine core (items manager)
    Core: TBaseCore;
    // Makes items associated with shared tesselators visible
    procedure Render; virtual; abstract;
    // Makes items associated with shared tesselators invisible
    procedure Reset; virtual; abstract;
    // Clears items associated with shared tesselators
    procedure ClearItems; virtual; abstract;
    // Completely cleans structures
    procedure Clear; virtual; abstract;
  end;

  // Engine base core class
  TBaseCore = class(TItemsManager)
  private
    FTesselatorManager: BaseCont.TReferencedItemManager;
    Subsystems: array of TBaseSubsystem;
    FTimer, DefaultTimer: Timer.TTimer;
    procedure SetTimer(const Value: Timer.TTimer);
    procedure SetTotalProcessingClasses(const Value: Integer);
  protected
    // Time mark for delta time based items processing
    DeltaTimeBasedTimeMark: TTimeMark;
    // Number of items to process
    ProcessingItems: TItems;
    // Items to process
    TotalProcessingItems: Integer;
    // Shared tesselators manager. For internal use only
    FSharedTesselators: TBaseSharedTesselators;
    // Temporary items container. Used internally for shared tesselators visualization etc.
    FTempItems: BaseClasses.TItem;
    // Performance profile
    FPerfProfile: TPerfProfile;
    // Performs delta time based items processing
    procedure ProcessDeltaTimeBased(const DeltaTime: TTimeUnit);
    // Performs items processing
    procedure ProcessingEvent(EventID: Integer; const ErrorDelta: TTimeUnit);
    procedure OnDestroy; override;
  public
    // If <b>Paused</b> is <b>True</b> @Link(Process) methods will be called only for items which processing class includes the @Link(pfIgnorePause) flag
    Paused: Boolean;
    // Delta time scale factor for all processing classes
    TimeScale: Single;

    // Maximum of simultaneous light sources
    SimultaneousLightSources: Integer;

    // Random numbers generator
    RandomGen: Basics.TRandomGenerator;

    // By assigning this handler reference an additional message handler can be included into the message handling chain
    MessageHandler: BaseMsg.TMessageHandler;

    constructor Create; override;

    procedure HandleMessage(const Msg: TMessage); override;

    // Register a subsystem. All registered subsystems will receive all messages received by the core.
    procedure AddSubsystem(const Subsystem: TBaseSubsystem);
    // Unregister a subsystem
    procedure RemoveSubsystem(const Subsystem: TBaseSubsystem);
    // Returns a registered subsystem of the specified class or successor
    function QuerySubsystem(SubsystemClass: CSubsystem): TBaseSubsystem;

    // Sets parameters of a processing class.
    procedure SetProcessingClass(Index: Integer; Interval: Single; IgnorePause, DeltaTimeBased: Boolean);

    // For internal use only.
    procedure AddPass(const Item: BaseClasses.TItem); virtual; abstract;
    // For internal use only.
    procedure RemovePass(const Item: BaseClasses.TItem); virtual; abstract;

    // Clears current scene
    procedure ClearItems; override;

    // Shared tesselators manager. For internal use only.
    property SharedTesselators: TBaseSharedTesselators read FSharedTesselators;
    // Tesselators manager. For internal use only.
    property TesselatorManager: BaseCont.TReferencedItemManager read FTesselatorManager;
    // Temporary items container. Used internally for shared tesselators visualization etc.
    property TempItems: BaseClasses.TItem read FTempItems;
    // Timer subsystem. Must be assigned.
    property Timer: Timer.TTimer read FTimer write SetTimer;
    // Performance profile
    property PerfProfile: TPerfProfile read FPerfProfile;
    // Number of processing classes
    property TotalProcessingClasses: Integer read GetTotalProcessingClasses write SetTotalProcessingClasses;
  end;

  CProcessing = class of TProcessing;
  // Base class of all processing (updateable) objects
  TProcessing = class(TBaseProcessing)
  protected
    TransformValid: Boolean;
    function GetTransform: TMatrix4s; {$I inline.inc}
    function GetTransformPtr: PMatrix4s; {$I inline.inc}
    procedure SetTransform(const ATransform: TMatrix4s); {$I inline.inc}

    function GetForwardVector: TVector3s; {$I inline.inc}
    function GetRightVector: TVector3s; {$I inline.inc}
    function GetUpVector: TVector3s; {$I inline.inc}

    function GetPosition: TVector3s; {$I inline.inc}
    procedure SetPosition(const Value: TVector3s); {$I inline.inc}
    function GetScale: TVector3s; {$I inline.inc}
    procedure SetScale(const Value: TVector3s); {$I inline.inc}

    function GetLocation: TLocation; {$I inline.inc}
    procedure SetLocation(ALocation: TLocation); {$I inline.inc}
    function GetOrientation: TQuaternion; {$I inline.inc}
    procedure SetOrientation(AOrientation: TQuaternion); {$I inline.inc}

    function GetDimensions: TVector3s; {$I inline.inc}
    function GetBoundingSphereRadius: Single; {$I inline.inc}

    procedure ResolveLinks; override;
  protected
    // Transformation matrix of the item
    FTransform: TMatrix4s;
    // Current orientation of the item
    FOrientation: TQuaternion;
    // Current location of the item
    FLocation: TLocation;
    // Current scale of the item
    FScale: TVector3s;
    // Returns True if the entity is handled by a physics subsystem
    function IsPhysical: Boolean; {$I inline.inc} 
    //
    procedure SetState(const Value: TSet32); override;
    { In CAST II engine a lazy evaluation scheme used for transformation computations.
      This method will compute current transformation matrix when and only when it is necessary. }
    procedure ComputeTransform; virtual;
    // Calling this method will tell the engine that @Link(FTransform) became invalid and should be recomputed before next use
    procedure InvalidateTransform; virtual;

    // Returns AItem if OK or nil if index is invalid or impossible to set a child
    function SetChild(Index: Integer; AItem: BaseClasses.TItem): BaseClasses.TItem; override;
  public
    // Contains information about bounding volumes of the item which will be used for collision tests
    Colliding: TBaseColliding;

    // Returns bounding box of the item
    BoundingBox: Base3D.TBoundingBox;
//    FullBoundingBox: Base3D.TBoundingBox;

    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    // Called when a collision of the item with another items was detected
    procedure OnCollision(Item: TProcessing; const ColRes: Collisions.TCollisionResult); virtual;

    { This procedure is called (by editor for example) to retrieve a list of item's properties and their values.
      Any TItem descendant class should override this method in order to add its own properties. }
    procedure AddProperties(const Result: Props.TProperties); override;
    { This procedure is called (by editor for example) to set values of item's properties.
      Any TItem descendant class should override this method to allow its own properties to be set. }
    procedure SetProperties(Properties: Props.TProperties); override;

    // Returns position of the item in world's coordinate space
    function GetAbsLocation: TVector3s; {$I inline.inc}
    // Returns orientation of the item in world's coordinate space
    function GetAbsOrientation: TQuaternion; {$I inline.inc}
    // Transforms a point from local model's coordinate space to world's coordinate space
    function ModelToWorld(const APoint: TVector3s): TVector3s; {$I inline.inc}
    // Transforms a point from world's coordinate space to local model's coordinate space
    function WorldToModel(const APoint: TVector3s): TVector3s; {$I inline.inc}

    // Transformation matrix of the item
    property Transform: TMatrix4s         read GetTransform   write SetTransform;
    // Transformation matrix pointer to pass to functions which requires a pointer parameter
    property TransformPtr: PMatrix4s      read GetTransformPtr;   
    // 4-component position of the item within parent's coordinate space
    property Location: TLocation          read GetLocation    write SetLocation;
    // Position of the item within parent's coordinate space
    property Position: TVector3s          read GetPosition    write SetPosition;
    // Scale of the item within parent's coordinate space
    property Scale: TVector3s             read GetScale       write SetScale;
    // Orientation of the item within parent's coordinate space
    property Orientation: TQuaternion     read GetOrientation write SetOrientation;

    // Forward direction for the item
    property ForwardVector: TVector3s     read GetForwardVector;
    // Right direction for the item
    property RightVector: TVector3s       read GetRightVector;
    // Up direction for the item
    property UpVector: TVector3s          read GetUpVector;

    // Dimensions of the item based on its bounding box (see @Link(BoundingBox))
    property Dimensions: TVector3s        read GetDimensions;
    // The item's bounding sphere radius based on @Link(Dimensions)
    property BoundingSphereRadius: Single read GetBoundingSphereRadius;
  end;

  // Item move operation
  TItemMoveOp = class(Models.TOperation)
  private
    AffectedProcessing: TProcessing;
    Location: TLocation;
  protected
    // Applies the operation
    procedure DoApply; override;
    // Merges together two move operations
    function DoMerge(AOperation: Models.TOperation): Boolean; override;
  public
    // Inits the operation with the specified processing item and its new location
    function Init(AAffectedProcessing: TProcessing; ALocation: TLocation): Boolean;
  end;

  // Item orientation change operation
  TItemRotateOp = class(Models.TOperation)
  private
    AffectedProcessing: TProcessing;
    Orientation: TQuaternion;
  protected
    // Applies the operation
    procedure DoApply; override;
    // Merges together two orientation change operations
    function DoMerge(AOperation: Models.TOperation): Boolean; override;
  public
    // Inits the operation with the specified processing item and its new orientation
    function Init(AAffectedProcessing: TProcessing; AOrientation: TQuaternion): Boolean;
  end;

  // Callback function used to traverse through items hierarchy
  TTraverseCallback = function(Item: BaseClasses.TItem): TTraverseResult;

  // Collection of items
  TItemCollection = record
    TraverseMask: TTraverseMask;
    TotalItems: Integer;
    Items: array of BaseClasses.TItem;
  end;

  { Specifies clear settings.
    <b>ClearFlags</b> - what to clear
    <b>ClearColor</b> - clear color
    <b>ClearStencil</b> - a stencil value to clear with
    <b>ClearZ</b> - a Z value to clear with  }
  TClearSettings = record
    ClearFlags: TClearFlagsSet;
    ClearColor: BaseTypes.TColor;
    ClearStencil: Longword;
    ClearZ: Single;
  end;

  // Specifies clear settings for each render stage (order)
  TStagesClearSettings = array[poPreprocess..poPostProcess] of TClearSettings;

  // Camera
  TCamera = class(TProcessing)
  private
    FOrthographic: Boolean;
    FCurrentAspectRatio,
    FZNear,
    FZFar,
    FWidth,
    FAspectRatio,
    FHFoV: Single;
    FFrustumPlanes: array[TFrustumPlane] of TPlane;
    FRTColorFormat, FRTDepthFormat: Cardinal;
    function GetViewMatrix: TMatrix4s;
    function GetViewMatrixPtr: PMatrix4s;
    function GetProjMatrixPtr: PMatrix4s;
    procedure SetViewMatrix(const Value: TMatrix4s);
    function GetInvViewMatrix: TMatrix4s;
    function GetTotalMatrix: TMatrix4s;
    function GetViewOrigin: TVector3s;
    function GetLookDir: TVector3s;
    function GetRightDir: TVector3s;
    function GetUpDir: TVector3s;
    procedure SetAspectRatio(const Value: Single);
  protected
    // Determines if view matrix need recalculating
    FViewValid: Boolean;
    // View matrix
    FViewMatrix,
    // Inverse view matrix
    FInvViewMatrix,
    // Projection matrix
    FProjMatrix,
    // View * projection matrix
    FTotalMatrix: TMatrix4s;
    // Current render width
    FRenderWidth,
    // Current render height
    FRenderHeight: Integer;
    // Calling this method will tell the engine that @Link(FTransform) became invalid and should be recomputed before next use
    procedure InvalidateTransform; override;
    // Recalculates frustum planes. Should be called only from ComputeViewMatrix.
    procedure ComputeFrustumPlanes;
    // Recalculates view matrix when needed
    procedure ComputeViewMatrix; virtual;
  public
    // Default cameras can
//    Default: Boolean;

    // Default fill mode for the camera
    DefaultFillMode: TFillMode;
    // Default cull mode for the camera
    DefaultCullMode: TCullMode;

    // Determines what and when should be cleared
    ClearSettings: TClearSettings;

    // private
      RenderTargetIndex: Integer;
    // User-defined clip planes
    ClipPlanes: TClipPlanes;
    // Determines which passes can be visible through the camera
    GroupMask: TPassGroupSet;
    // Current rendering color format. Updated by renderer
    ColorFormat,
    // Current rendering depth format. Updated by renderer
    DepthFormat: Integer;

    // Width of a render target texture used if the camera will be used as a texture
    RenderTargetWidth,
    // Height of a render target texture used if the camera will be used as a texture
    RenderTargetHeight: Integer;
    // Determines how many frames should be skipped between render target texture updates
    FrameSkip: Integer;
    // Cameras can render scene in higher or lower detail which is controlled by this parameter 
    LODBias: Single;
    // Determines if a depth-stencil surface instead of color surface should be used when the camera applied as a texture
    IsDepthTexture: Boolean;

    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;

    { This procedure is called (by editor for example) to retrieve a list of item's properties and their values.
      Any TItem descendant class should override this method in order to add its own properties. }
    procedure AddProperties(const Result: Props.TProperties); override;
    { This procedure is called (by editor for example) to set values of item's properties.
      Any TItem descendant class should override this method to allow its own properties to be set. }
    procedure SetProperties(Properties: Props.TProperties); override;

    // Sets up the camera's projection matrix with the given near and far Z planes, horizontal field of view and aspect ratio
    procedure InitProjMatrix(AZNear, AZFar, AHFoV, AAspectRatio: Single); virtual;
    // Sets up the camera's orthographic projection matrix with the given near and far Z planes, width of view and aspect ratio
    procedure InitOrthoProjMatrix(AZNear, AZFar, VisibleWidth, AAspectRatio: Single); virtual;
    // Sets the @Link(ClearSettings)
    procedure SetClearState(AClearFlags: TClearFlagsSet; AClearColor: BaseTypes.TColor; AClearZ: Single; AClearStencil: Cardinal); virtual;

    // Sets render dimensions and recalculates projection matrix. Normally called by renderer when render window size changes.
    procedure SetScreenDimensions(Width, Height: Integer; AdjustAspectRatio: Boolean);

    // Rotates the camera by the specified angles
    procedure Rotate(XA, YA, ZA: Single); virtual;
    // Moves the camera by the specified distance in camera space
    procedure Move(XD, YD, ZD: Single); virtual;

    // Returns not normalized direction of a ray in view space which starts from the camera and passes through the given point on screen
    function GetPickRay(ScreenX, ScreenY: Single): TVector3s; virtual;
    // Returns not normalized direction of a ray in world space which starts from the camera and passes through the given point on screen
    function GetPickRayInWorld(ScreenX, ScreenY: Single): TVector3s; virtual;
    // Returns the given vector after projection with the camera
    function Project(const Vec: TVector3s): TVector4s;
    // Renderer calls this event right before the camera apply
    procedure OnApply(const OldCamera: TCamera); virtual;
    // Performs a frustrum visibility check against a sphere with the given center and radius
    function IsSpehereVisible(const Center: TVector3s; Radius: Single): TFrustumCheckResult;

    // Near Z plane distance
    property ZNear: Single read FZNear;
    // Far Z plane distance
    property ZFar: Single read FZFar;
    // Initial aspect ratio. Can change
    property AspectRatio: Single read FAspectRatio write SetAspectRatio;
    // Current aspect ratio
    property CurrentAspectRatio: Single read FCurrentAspectRatio;
    // Horizontal field of view in radians
    property HFoV: Single read FHFoV;

    // Current render width
    property RenderWidth: Integer read FRenderWidth;
    // Current render height
    property RenderHeight: Integer read FRenderHeight;

    // Color format for render target which will be used in case of use of this camera as a texture
    property RTColorFormat: Cardinal read FRTColorFormat;
    // Depth format for render target which will be used in case of use of this camera as a texture
    property RTDepthFormat: Cardinal read FRTDepthFormat;

    // View matrix
    property ViewMatrix: TMatrix4s read GetViewMatrix write SetViewMatrix;
    // Pointer to view matrix
    property ViewMatrixPtr: PMatrix4s read GetViewMatrixPtr;
    // Inverse view matrix
    property InvViewMatrix: TMatrix4s read GetInvViewMatrix;
    // Projection matrix
    property ProjMatrix: TMatrix4s read FProjMatrix write FProjMatrix;
    // Pointer to projection matrix
    property ProjMatrixPtr: PMatrix4s read GetProjMatrixPtr;
    // View * projection matrix
    property TotalMatrix: TMatrix4s read GetTotalMatrix;
    // Position of the camera's view point in world space
    property ViewOrigin: TVector3s read GetViewOrigin;
    // View direction of the camera in world space
    property LookDir: TVector3s read GetLookDir;
    // Right direction of the camera in world space
    property RightDir: TVector3s read GetRightDir;
    // Up direction of the camera in world space
    property UpDir: TVector3s read GetUpDir;
  end;

  // An item of this class should be the root of items hierarchy
  TCASTRootItem = class(TRootItem)
  private
    // collection for various sets of items from scene (e.g. renderable, processing etc)
    Collections: array of TItemCollection;
    TotalCollections: Integer;
    Collidings: TUniqueItemCollection;
//    ModifyingCollectionIndex: Integer;
//    procedure IncludeItem(Item: BaseClasses.TItem; Mask: TTraverseMask);
//    procedure ExcludeItem(Item: BaseClasses.TItem; Mask: TTraverseMask);
    // Internal function used as callback only
//    function AddToCollectionCallback(Item: BaseClasses.TItem): TTraverseResult;
//    procedure AddToCollection(CollectionIndex: Integer; Item: BaseClasses.TItem); virtual;
//    procedure RemoveFromCollection(CollectionIndex: Integer; Item: BaseClasses.TItem); virtual;
  public
    // Clear settings for all render stages
    StageSettings: TStagesClearSettings;
    constructor Create(AManager: TItemsManager); override;
    destructor Destroy; override;
    function GetItemSize(CountChilds: Boolean): Integer; override;

    { This procedure is called (by editor for example) to retrieve a list of item's properties and their values.
      Any TItem descendant class should override this method in order to add its own properties. }
    procedure AddProperties(const Result: Props.TProperties); override;
    { This procedure is called (by editor for example) to set values of item's properties.
      Any TItem descendant class should override this method to allow its own properties to be set. }
    procedure SetProperties(Properties: Props.TProperties); override;

    { Traverses through the items hierarchy and adds to Items all items matching the following:       <br>
      the item is an instance of the given class or a descendant, its State field has matches Mask and
      the item is within the given range from the given origin.
      Childs of items with non-matching State are not considered.
      Returns number of items in Items. }
    function ExtractByMaskClassInRadius(Mask: TItemFlags; AClass: CProcessing; out Items: TItems; Origin: TLocation; Range: Single): Integer;
    { Traverses through the items hierarchy and adds to Items all items matching the following:       <br>
      the item is an instance of the given class or a descendant, its State field has matches Mask and
      the item is within visibility frustum of the given camera.
      Childs of items with non-matching State are not considered.
      Returns number of items in Items. }
    function ExtractByMaskClassInCamera(Mask: TItemFlags; AClass: CProcessing; out Items: TItems; ACamera: TCamera): Integer;

    procedure HandleMessage(const Msg: TMessage); override;

    // Adds a collection of items with the specified state
    function AddCollection(Mask: TTraverseMask): Integer;
    // Removes collection specified by the index
    procedure DeleteCollection(Index: Integer);

    // Traverses through the items hierarchy and calls Callback for all items
    procedure TraverseTree(Callback: TTraverseCallback);

    // Frees all childs
    procedure FreeChilds; override;
  end;

  { @Abstract(Camera class for mirror surfaces)
    The camera constructs its view matrix as a reflection of view matrix of previous camera by XY plane if the camera's transform}
  TMirrorCamera = class(TCamera)
  private
    FOldCamera: TCamera;
  public
    // Reflects previous applyed camera view matrix by its own XY plane and assigns the result to view matrix
    procedure ComputeViewMatrix; override;
    // OnApply event overridden to assign previous camera variable and setup clipping plane
    procedure OnApply(const OldCamera: TCamera); override;
  end;

{  TRenderParameters = record
    MainCamera, ActiveCamera: TCamera;
  end;
  PRenderParameters = ^TRenderParameters;}

  // Returns a location from 3D vector
  function GetLocationFromVec3s(V: TVector3s): TLocation;
  // Retuns True if the locations are equal
  function EqualLocations(V1, V2: TLocation): Boolean;
  // Retuns squared distance between the locations
  function LocationSqDistance(V1, V2: TLocation): Single;
  // Helper functions for adding/setting properties of a certain type
  // Adds a string property named "Error" with the value contained in <b>Msg</b>
  procedure AddErrorProperty(Properties: Props.TProperties; const Msg: string);
  // Adds a 3-component vector and each its component as properties
  procedure AddVector3sProperty(Properties: Props.TProperties; const Name: string; const Vec: TVector3s);
  // Adds a 4-component vector and each its component as properties
  procedure AddVector4sProperty(Properties: Props.TProperties; const Name: string; const Vec: TVector4s);
  // Adds a quaternion and each its component as properties
  procedure AddQuaternionProperty(Properties: Props.TProperties; const Name: string; const Quat: TQuaternion);
  // Reads a 3-component vector from properties. If its not equivalent to the one contained in <b>Res</b> assigns it to <b>Res</b> and returns <b>True</b>.
  function SetVector3sProperty(Properties: Props.TProperties; const Name: string; var Res: TVector3s): Boolean;
  // Reads a 4-component vector from properties. If its not equivalent to the one contained in <b>Res</b> assigns it to <b>Res</b> and returns <b>True</b>.
  function SetVector4sProperty(Properties: Props.TProperties; const Name: string; var Res: TVector4s): Boolean;
  // Reads a quaternion from properties. If its not equivalent to the one contained in <b>Res</b> assigns it to <b>Res</b> and returns <b>True</b>.
  function SetQuaternionProperty(Properties: Props.TProperties; const Name: string; var Res: TQuaternion): Boolean;

var
  CollidingClass: CBaseColliding;

implementation

uses SysUtils;

function GetLocationFromVec3s(V: TVector3s): TLocation;
begin
  Result.X := V.X;
  Result.Y := V.Y;
  Result.Z := V.Z;
  Result.W := 1;
end;

function EqualLocations(V1, V2: TLocation): Boolean;
begin
  Result := (V1.X = V2.X) and (V1.Y = V2.Y) and (V1.Z = V2.Z) and (V1.W = V2.W);
end;

function LocationSqDistance(V1, V2: TLocation): Single;
begin
  Result := Sqr(V2.X-V1.X) + Sqr(V2.Y-V1.Y)+  Sqr(V2.Z-V1.Z);
end;

procedure AddErrorProperty(Properties: Props.TProperties; const Msg: string);
begin
  Properties.Add('Error', vtString, [poReadonly], Msg, '');
end;

procedure AddVector3sProperty(Properties: Props.TProperties; const Name: string; const Vec: TVector3s);
begin
  Properties.Add(Name,        vtString, [poReadOnly], Format('(%3.3F, %3.3F, %3.3F)', [Vec.X, Vec.Y, Vec.Z]), '');
  Properties.Add(Name + '\X', vtSingle, [], FloatToStr(Vec.X), '');
  Properties.Add(Name + '\Y', vtSingle, [], FloatToStr(Vec.Y), '');
  Properties.Add(Name + '\Z', vtSingle, [], FloatToStr(Vec.Z), '');
end;

procedure AddVector4sProperty(Properties: Props.TProperties; const Name: string; const Vec: TVector4s);
begin
  AddVector3sProperty(Properties, Name, Vec.XYZ);
  Properties.Add(Name + '\W', vtSingle, [], FloatToStr(Vec.W), '');
  Properties.Add(Name,        vtString, [poReadOnly], Format('(%3.3F, %3.3F, %3.3F, %3.3F)', [Vec.X, Vec.Y, Vec.Z, Vec.W]), '');
end;

procedure AddQuaternionProperty(Properties: Props.TProperties; const Name: string; const Quat: TQuaternion);
var Angle: Single;
begin
  AddVector3sProperty(Properties, Name, GetVector3s(Quat[1], Quat[2], Quat[3]));
  Angle := ArcTan2(Sqrt(1 - Quat[0] * Quat[0]), Quat[0])*2 * 180/pi;
  Properties.Add(Name + '\Angle', vtSingle, [], FloatToStr(Angle), '');
  Properties.Add(Name,            vtString, [poReadOnly], Format('(%3.3F, (%3.3F, %3.3F, %3.3F))', [Angle, Quat[1], Quat[2], Quat[3]]), '');
end;

function SetVector3sProperty(Properties: Props.TProperties; const Name: string; var Res: TVector3s): Boolean; overload;
var NewVec: TVector3s;
begin
  NewVec := Res;
  if Properties.Valid(Name + '\X') then NewVec.X := StrToFloatDef(Properties[Name + '\X'], 0);
  if Properties.Valid(Name + '\Y') then NewVec.Y := StrToFloatDef(Properties[Name + '\Y'], 0);
  if Properties.Valid(Name + '\Z') then NewVec.Z := StrToFloatDef(Properties[Name + '\Z'], 0);
  Result := isNan(Res.X) or isNan(Res.Y) or isNan(Res.Z) or
           (NewVec.X <> Res.X) or (NewVec.Y <> Res.Y) or (NewVec.Z <> Res.Z);
  if Result then Res := NewVec;
end;

function SetVector4sProperty(Properties: Props.TProperties; const Name: string; var Res: TVector4s): Boolean; overload;
var NewVec: TVector3s; W: Single;
begin
  NewVec := Res.XYZ;
  W := Res.W;
  Result := SetVector3sProperty(Properties, Name, NewVec);
  if Properties.Valid(Name + '\W') then W := StrToFloatDef(Properties[Name + '\W'], 0);
  Result := Result or isNan(Res.W) or (W <> Res.W);
  if Result then begin
    Res := ExpandVector3s(NewVec);
    Res.W := W;
  end;
end;

function SetQuaternionProperty(Properties: Props.TProperties; const Name: string; var Res: TQuaternion): Boolean; 
var NewVec: TVector3s; Angle: Single;
begin
  NewVec.X := Res[1]; NewVec.Y := Res[2]; NewVec.Z := Res[3];
  Result := SetVector3sProperty(Properties, Name, NewVec);
  if Properties.Valid(Name + '\Angle') then Angle := StrToFloatDef(Properties[Name + '\Angle'], 0)*pi/180 else
    Angle := ArcTan2(Sqrt(1 - Res[0] * Res[0]), Res[0])*2;
  Result := Result or isNan(Res[0]) or (Angle <> Res[0]);
  if Result then Res := GetQuaternion(Angle, NewVec);
end;

{ TBaseColliding }

constructor TBaseColliding.Create(AOwner: TItem);
begin
  inherited Create();
  FOwner := AOwner;
end;

{ TPerfProfile }

procedure TPerfProfile.SetFramesPerSecond(const Value: Single);
begin
  FFramesPerSecond := Value;
  if (FMinFramesPerSecond = 0) or (FFramesPerSecond < FMinFramesPerSecond) then FMinFramesPerSecond := FFramesPerSecond;
  if FFramesPerSecond > FMaxFramesPerSecond then FMaxFramesPerSecond := FFramesPerSecond;
end;

function TPerfProfile.GetPrimitivesPerSecond: Single;
begin
  Result := PrimitivesRendered * FramesPerSecond;
end;

procedure TPerfProfile.OnFrameStart;
var BufType: TTesselationBuffer;
begin
  RenderTargetChanges := 0;
  PrimitivesRendered  := 0;
  DrawCalls           := 0;
  ClearCalls          := 0;
  FrustumCulledItems  := 0;
  FrustumPassedItems  := 0;
  SortedItems         := 0;
  for BufType := Low(TTesselationBuffer) to High(TTesselationBuffer) do begin
    BuffersProfile[BufType].TesselationsPerformed[True]  := 0;
    BuffersProfile[BufType].BytesWritten[True]           := 0;
    BuffersProfile[BufType].TesselationsPerformed[False] := 0;
    BuffersProfile[BufType].BytesWritten[False]          := 0;
    BuffersProfile[BufType].BufferResetsCount[True]      := 0;
    BuffersProfile[BufType].BufferResetsCount[False]     := 0;
    BuffersProfile[BufType].TesselationsBypassed         := 0;
    BuffersProfile[BufType].BytesBypassed                := 0;
  end;
end;

procedure TPerfProfile.OnBuffersReset;
var BufType: TTesselationBuffer;
begin
  for BufType := Low(TTesselationBuffer) to High(TTesselationBuffer) do begin
    BuffersProfile[BufType].BufferSize[True]  := 0;
    BuffersProfile[BufType].BufferSize[False] := 0;
  end;
end;

procedure TPerfProfile.BeginTiming(Timer: TTimer; PerfTimer: TPerfTimer);
begin
  Timer.GetInterval(TimeMarks[PerfTimer], True);
end;

function TPerfProfile.EndTiming(Timer: TTimer; PerfTimer: TPerfTimer): TTimeUnit;
begin
  Times[PerfTimer] := Timer.GetInterval(TimeMarks[PerfTimer], True);
  Result := Times[PerfTimer];
end;

{ TCASTRootItem }

constructor TCASTRootItem.Create(AManager: TItemsManager);
var i: Integer;
begin
  inherited;
  Collidings := TUniqueItemCollection.Create;
  for i := 0 to High(StageSettings) do StageSettings[i].ClearZ := 1;
    
end;

destructor TCASTRootItem.Destroy;
var i: Integer;
begin
  for i := 0 to High(Collections) do DeleteCollection(i);
  inherited;
  FreeAndNil(Collidings);
end;

function TCASTRootItem.GetItemSize(CountChilds: Boolean): Integer;
var i: Integer;
begin
  Result := inherited GetItemSize(CountChilds);
  Inc(Result, TotalCollections * SizeOf(TItemCollection));
  for i := 0 to TotalCollections-1 do if Collections[i].Items <> nil then Inc(Result, Collections[i].TotalItems * SizeOf(BaseClasses.TItem));
end;

procedure TCASTRootItem.AddProperties(const Result: Props.TProperties);
var i: Integer; Core: TBaseCore; s: string;
begin
  inherited;
  if not Assigned(Result) then Exit;

  if FManager is TBaseCore then Core := (FManager as TBaseCore) else begin
     Log(ClassName + '.AddProperties: Items manager must be an instance of TBaseCore', lkError); 
    Exit;
  end;

  if (Parent = nil) and (FManager.Root = Self) then begin
    Result.Add('Renderer\Before background\Clear\Frame buffer',   vtBoolean, [], OnOffStr[ClearFrameBuffer   in StageSettings[poBackground].ClearFlags], '');
    Result.Add('Renderer\Before background\Clear\Z buffer',       vtBoolean, [], OnOffStr[ClearZBuffer       in StageSettings[poBackground].ClearFlags], '');
    Result.Add('Renderer\Before background\Clear\Stencil buffer', vtBoolean, [], OnOffStr[ClearStencilBuffer in StageSettings[poBackground].ClearFlags], '');
    Result.Add('Renderer\Before background\Clear\Z value',        vtSingle,  [], FloatToStr(StageSettings[poBackground].ClearZ),             '');
    Result.Add('Renderer\Before background\Clear\Stencil value',  vtNat,     [], IntToStr(StageSettings[poBackground].ClearStencil),        '');
    AddColorProperty(Result, 'Renderer\Before background\Clear\Color value', StageSettings[poBackground].ClearColor);

    Result.Add('Renderer\Before nearest\Clear\Frame buffer',   vtBoolean, [], OnOffStr[ClearFrameBuffer   in StageSettings[poNearest].ClearFlags], '');
    Result.Add('Renderer\Before nearest\Clear\Z buffer',       vtBoolean, [], OnOffStr[ClearZBuffer       in StageSettings[poNearest].ClearFlags], '');
    Result.Add('Renderer\Before nearest\Clear\Stencil buffer', vtBoolean, [], OnOffStr[ClearStencilBuffer in StageSettings[poNearest].ClearFlags], '');
    Result.Add('Renderer\Before nearest\Clear\Z value',        vtSingle,  [], FloatToStr(StageSettings[poNearest].ClearZ),             '');
    Result.Add('Renderer\Before nearest\Clear\Stencil value',  vtNat,     [], IntToStr(StageSettings[poNearest].ClearStencil),        '');
    AddColorProperty(Result, 'Renderer\Before nearest\Clear\Color value', StageSettings[poNearest].ClearColor);

    Result.Add('Renderer\Before postprocess\Clear\Frame buffer',   vtBoolean, [], OnOffStr[ClearFrameBuffer   in StageSettings[poPostprocess].ClearFlags], '');
    Result.Add('Renderer\Before postprocess\Clear\Z buffer',       vtBoolean, [], OnOffStr[ClearZBuffer       in StageSettings[poPostprocess].ClearFlags], '');
    Result.Add('Renderer\Before postprocess\Clear\Stencil buffer', vtBoolean, [], OnOffStr[ClearStencilBuffer in StageSettings[poPostprocess].ClearFlags], '');
    Result.Add('Renderer\Before postprocess\Clear\Z value',        vtSingle,  [], FloatToStr(StageSettings[poPostprocess].ClearZ),             '');
    Result.Add('Renderer\Before postprocess\Clear\Stencil value',  vtNat,     [], IntToStr(StageSettings[poPostprocess].ClearStencil),        '');
    AddColorProperty(Result, 'Renderer\Before postprocess\Clear\Color value', StageSettings[poPostprocess].ClearColor);

    Result.Add('Renderer\Simultaneous light sources', vtInt, [], IntToStr(Core.SimultaneousLightSources), '');

    Result.Add('Processing\Number of classes', vtInt, [], IntToStr(Core.TotalProcessingClasses), '');

    for i := 0 to Core.TotalProcessingClasses-1 do begin
      s := Format('Processing\Class %D\', [i]);
      Result.Add(s + 'Interval, ms',     vtNat,     [], IntToStr(Round(Core.ProcessingClasses[i].Interval*1000)), '');
      Result.Add(s + 'Delta time-based', vtBoolean, [], OnOffStr[pfDeltaTimeBased in Core.ProcessingClasses[i].Flags], '');
      Result.Add(s + 'Ignore pause',     vtBoolean, [], OnOffStr[pfIgnorePause    in Core.ProcessingClasses[i].Flags], '');
    end;

    for i := 0 to High(Core.Subsystems) do if Core.Subsystems[i] is TSubsystem then
      (Core.Subsystems[i] as TSubsystem).AddProperties(Result);
  end;
end;

procedure TCASTRootItem.SetProperties(Properties: Props.TProperties);
var
  i: Integer; Core: TBaseCore; s: string;
  NewIgnorePause, NewDeltaTimeMode: Boolean;
begin
  inherited;

  if FManager is TBaseCore then Core := (FManager as TBaseCore) else begin
     Log(ClassName + '.SetProperties: Items manager must be an instance of TBaseCore', lkError); 
    Exit;
  end;

  if (Parent = nil) and (FManager.Root = Self) then begin

    if Properties.Valid('Renderer\Before background\Clear\Frame buffer')   then if Properties.GetAsInteger('Renderer\Before background\Clear\Frame buffer')   > 0 then
      Include(StageSettings[poBackground].ClearFlags, ClearFrameBuffer)   else Exclude(StageSettings[poBackground].ClearFlags, ClearFrameBuffer);
    if Properties.Valid('Renderer\Before background\Clear\Z buffer')       then if Properties.GetAsInteger('Renderer\Before background\Clear\Z buffer')       > 0 then
      Include(StageSettings[poBackground].ClearFlags, ClearZBuffer)       else Exclude(StageSettings[poBackground].ClearFlags, ClearZBuffer);
    if Properties.Valid('Renderer\Before background\Clear\Stencil buffer') then if Properties.GetAsInteger('Renderer\Before background\Clear\Stencil buffer') > 0 then
      Include(StageSettings[poBackground].ClearFlags, ClearStencilBuffer) else Exclude(StageSettings[poBackground].ClearFlags, ClearStencilBuffer);

    if Properties.Valid('Renderer\Before nearest\Clear\Frame buffer')   then if Properties.GetAsInteger('Renderer\Before nearest\Clear\Frame buffer')   > 0 then
      Include(StageSettings[poNearest].ClearFlags, ClearFrameBuffer)   else Exclude(StageSettings[poNearest].ClearFlags, ClearFrameBuffer);
    if Properties.Valid('Renderer\Before nearest\Clear\Z buffer')       then if Properties.GetAsInteger('Renderer\Before nearest\Clear\Z buffer')       > 0 then
      Include(StageSettings[poNearest].ClearFlags, ClearZBuffer)       else Exclude(StageSettings[poNearest].ClearFlags, ClearZBuffer);
    if Properties.Valid('Renderer\Before nearest\Clear\Stencil buffer') then if Properties.GetAsInteger('Renderer\Before nearest\Clear\Stencil buffer') > 0 then
      Include(StageSettings[poNearest].ClearFlags, ClearStencilBuffer) else Exclude(StageSettings[poNearest].ClearFlags, ClearStencilBuffer);

    if Properties.Valid('Renderer\Before postprocess\Clear\Frame buffer')   then if Properties.GetAsInteger('Renderer\Before postprocess\Clear\Frame buffer')   > 0 then
      Include(StageSettings[poPostprocess].ClearFlags, ClearFrameBuffer)   else Exclude(StageSettings[poPostprocess].ClearFlags, ClearFrameBuffer);
    if Properties.Valid('Renderer\Before postprocess\Clear\Z buffer')       then if Properties.GetAsInteger('Renderer\Before postprocess\Clear\Z buffer')       > 0 then
      Include(StageSettings[poPostprocess].ClearFlags, ClearZBuffer)       else Exclude(StageSettings[poPostprocess].ClearFlags, ClearZBuffer);
    if Properties.Valid('Renderer\Before postprocess\Clear\Stencil buffer') then if Properties.GetAsInteger('Renderer\Before postprocess\Clear\Stencil buffer') > 0 then
      Include(StageSettings[poPostprocess].ClearFlags, ClearStencilBuffer) else Exclude(StageSettings[poPostprocess].ClearFlags, ClearStencilBuffer);

    SetColorProperty(Properties, 'Renderer\Before background\Clear\Color value', StageSettings[poBackground].ClearColor);
    if Properties.Valid('Renderer\Before background\Clear\Z value')        then StageSettings[poBackground].ClearZ             := StrToFloatDef(Properties['Renderer\Before background\Clear\Z value'], 1);
    if Properties.Valid('Renderer\Before background\Clear\Stencil value')  then StageSettings[poBackground].ClearStencil       := Longword(Properties.GetAsInteger('Renderer\Before background\Clear\Stencil value'));

    SetColorProperty(Properties, 'Renderer\Before nearest\Clear\Color value', StageSettings[poNearest].ClearColor);
    if Properties.Valid('Renderer\Before nearest\Clear\Z value')        then StageSettings[poNearest].ClearZ             := StrToFloatDef(Properties['Renderer\Before nearest\Clear\Z value'], 1);
    if Properties.Valid('Renderer\Before nearest\Clear\Stencil value')  then StageSettings[poNearest].ClearStencil       := Longword(Properties.GetAsInteger('Renderer\Before nearest\Clear\Stencil value'));

    SetColorProperty(Properties, 'Renderer\Before postprocess\Clear\Color value', StageSettings[poPostprocess].ClearColor);
    if Properties.Valid('Renderer\Before postprocess\Clear\Z value')        then StageSettings[poPostprocess].ClearZ             := StrToFloatDef(Properties['Renderer\Before postprocess\Clear\Z value'], 1);
    if Properties.Valid('Renderer\Before postprocess\Clear\Stencil value')  then StageSettings[poPostprocess].ClearStencil       := Longword(Properties.GetAsInteger('Renderer\Before postprocess\Clear\Stencil value'));

    if Properties.Valid('Renderer\Simultaneous light sources') then Core.SimultaneousLightSources := Properties.GetAsInteger('Renderer\Simultaneous light sources');

    if Properties.Valid('Processing\Number of classes') then begin
      Core.TotalProcessingClasses := MaxI(1, StrToIntDef(Properties['Processing\Number of classes'], 1));
    end;

    for i := 0 to Core.TotalProcessingClasses-1 do begin
      s := Format('Processing\Class %D\', [i]);

      if Properties.Valid(s + 'Interval, ms') then
        Core.ProcessingClasses[i].Interval := Cardinal(StrToIntDef(Properties[s + 'Interval, ms'], 30)) / 1000;

      if Properties.Valid(s + 'Ignore pause') then
        NewIgnorePause := Properties.GetAsInteger(s + 'Ignore pause') > 0
      else
        NewIgnorePause := pfIgnorePause in Core.ProcessingClasses[i].Flags;

      if Properties.Valid(s + 'Delta time-based') then
        NewDeltaTimeMode := Properties.GetAsInteger(s + 'Delta time-based') > 0
      else
        NewDeltaTimeMode := pfDeltaTimeBased in Core.ProcessingClasses[i].Flags;

      Core.SetProcessingClass(i, Core.ProcessingClasses[i].Interval, NewIgnorePause, NewDeltaTimeMode);
    end;

    for i := 0 to High(Core.Subsystems) do if Core.Subsystems[i] is TSubsystem then
      (Core.Subsystems[i] as TSubsystem).SetProperties(Properties);
  end;
end;

procedure TCASTRootItem.TraverseTree(Callback: TTraverseCallback);

  function TraverseCallback(Item: BaseClasses.TItem): TTraverseResult;
  var i: Integer;
  begin
    Result := Callback(Item);
    if Result = trContinue then for i := 0 to Item.TotalChilds-1 do begin
      {$IFDEF DEBUGMODE} Assert(Item.Childs[i] <> nil, ClassName + '.TraverseTree.Traverse: Childs[i] cannot be nil'); {$ENDIF}
      Result := TraverseCallBack(Item.Childs[i]);
      if Result = trStop then Exit;
    end;
  end;

begin
  if @Callback <> nil then TraverseCallback(Self);
end;

{procedure TCASTRootItem.IncludeItem(Item: BaseClasses.TItem; Mask: TTraverseMask);
var i: Integer;
begin
  for i := 0 to TotalCollections-1 do if Mask = Collections[i].TraverseMask then AddToCollection(i, Item);
end;

procedure TCASTRootItem.ExcludeItem(Item: BaseClasses.TItem; Mask: TTraverseMask);
var i: Integer;
begin
  for i := 0 to TotalCollections-1 do if Mask = Collections[i].TraverseMask then RemoveFromCollection(i, Item);
end;}

function TCASTRootItem.AddCollection(Mask: TTraverseMask): Integer;
var i: Integer;
begin
 Result := -1;
  for i := 0 to High(Collections) do if Collections[i].Items = nil then Result := i;
  Inc(TotalCollections);
  if Result = -1 then begin
    Result := Length(Collections);
    SetLength(Collections, Result+1);
  end;
  Collections[Result].TraverseMask := Mask;
  Collections[Result].TotalItems   := 0;
  SetLength(Collections[Result].Items, CollectionsCapacityStep);
end;

procedure TCASTRootItem.DeleteCollection(Index: Integer);
begin
  if (Index >= Length(Collections)) or (Collections[Index].Items = nil) then Exit;
  Dec(TotalCollections);
  Collections[Index].Items := nil;
end;

{function TCASTRootItem.AddToCollectionCallback(Item: BaseClasses.TItem): TTraverseResult;
begin
  AddToCollection(ModifyingCollectionIndex, Item);
  Result := trContinue;
end;}

(*procedure TCASTRootItem.AddToCollection(CollectionIndex: Integer; Item: BaseClasses.TItem);
begin
{$IFDEF DEBUGMODE}
  Assert((CollectionIndex < TotalCollections) and (Collections[CollectionIndex].Items <> nil), ClassName + '.AddToCollection: Invalid collection');
{$ENDIF}
  if (CollectionIndex < TotalCollections) and (Collections[CollectionIndex].Items <> nil) and (Item <> nil) then begin
    if Length(Collections[CollectionIndex].Items) <= Collections[CollectionIndex].TotalItems then
     SetLength(Collections[CollectionIndex].Items, Length(Collections[CollectionIndex].Items) + ChildsCapacityStep);
    Collections[CollectionIndex].Items[Collections[CollectionIndex].TotalItems] := Item;
    Inc(Collections[CollectionIndex].TotalItems);
  end;
end;

procedure TCASTRootItem.RemoveFromCollection(CollectionIndex: Integer; Item: BaseClasses.TItem);
var i: Integer;
begin
  {$IFDEF DEBUGMODE}
  Assert((CollectionIndex < TotalCollections) and (Collections[CollectionIndex].Items <> nil), ClassName + '.RemoveFromCollection: Invalid collection');
  {$ENDIF}
  if (CollectionIndex < TotalCollections) and (Collections[CollectionIndex].Items <> nil) and (Item <> nil) then
   for i := 0 to Collections[CollectionIndex].TotalItems-1 do if Collections[CollectionIndex].Items[i] = Item then begin
     Collections[CollectionIndex].Items[i] := Collections[CollectionIndex].Items[Collections[CollectionIndex].TotalItems-1];
     Collections[CollectionIndex].Items[Collections[CollectionIndex].TotalItems-1] := nil;
     Dec(Collections[CollectionIndex].TotalItems);
     Exit;
   end;

{$IFDEF DEBUGMODE}
  Assert(False, ClassName + '.RemoveFromCollection: Item not found');
{$ENDIF}
end;    *)

procedure TCASTRootItem.FreeChilds;
var i: Integer;
begin
  for i := 0 to High(Collections) do Collections[i].TotalItems := 0;
  Collidings.Clear;
  inherited;
end;

function TCASTRootItem.ExtractByMaskClassInRadius(Mask: TItemFlags; AClass: CProcessing; out Items: TItems; Origin: TLocation; Range: Single): Integer;
var i: Integer; SQRange: Single;
begin
  Result := 0;
  SQRange := Sqr(Range);
  if AClass.InheritsFrom(TProcessing) then begin
    for i := 0 to ExtractByMaskClass(Mask, AClass, Items)-1 do
      if LocationSqDistance(TProcessing(Items[i]).Location, Origin) < SQRange then begin
        Items[Result] := Items[i];
        Inc(Result);
      end;
  end else
    ErrorHandler(TInvalidArgument.Create('TCASTRootItem.ExtractByMaskClassInRadius: Spatial query class argument should be TProcessing or one of its descendant class'));
  {$IFDEF DEBUGMODE}
  SetLength(Items, Result);
  {$ENDIF}  
end;

function TCASTRootItem.ExtractByMaskClassInCamera(Mask: TItemFlags; AClass: CProcessing; out Items: TItems; ACamera: TCamera): Integer;
var i: Integer;
begin
  Result := 0;
  if AClass.InheritsFrom(TProcessing) then begin
    for i := 0 to ExtractByMaskClass(Mask, AClass, Items)-1 do
      if ACamera.IsSpehereVisible(TProcessing(Items[i]).GetAbsLocation, TProcessing(Items[i]).BoundingSphereRadius) <> fcOutside then begin
        Items[Result] := Items[i];
        Inc(Result);
      end;
  end else
    ErrorHandler(TInvalidArgument.Create('TCASTRootItem.ExtractByMaskClassInRadius: Spatial query class argument should be TProcessing or one of its descendant class'));
  {$IFDEF DEBUGMODE}
  SetLength(Items, Result);
  {$ENDIF}
end;

procedure TCASTRootItem.HandleMessage(const Msg: TMessage);
begin
  inherited;
{  if Msg.ClassType = ItemMsg.TAddToSceneMsg then with ItemMsg.TAddToSceneMsg(Msg) do begin
    if (Item is TProcessing) and (TProcessing(Item).Colliding <> nil) then Collidings.Add(TProcessing(Item).Colliding);
  end else if Msg.ClassType = ItemMsg.TReplaceMsg then with ItemMsg.TReplaceMsg(Msg) do begin
    if (OldItem is TProcessing) and (TProcessing(OldItem).Colliding <> nil) then Collidings.Remove(TProcessing(OldItem).Colliding);
  end else if Msg.ClassType = ItemMsg.TRemoveFromSceneMsg then with ItemMsg.TRemoveFromSceneMsg(Msg) do begin
    if (Item is TProcessing) and (TProcessing(Item).Colliding <> nil) then Collidings.Remove(TProcessing(Item).Colliding);
  end}
end;

{ TProcessing }

constructor TProcessing.Create(AManager: TItemsManager);
begin
  inherited;
  Colliding := CollidingClass.Create(Self);
  State := FState + [isProcessing];
  FScale := GetVector3s(1, 1, 1);
  Orientation := GetQuaternion(0, GetVector3s(0, 1, 0));
  ProcessingClass := 0;
  BoundingBox.P1 := GetVector3s(-1, -1, -1);
  BoundingBox.P2 := GetVector3s( 1,  1,  1);
end;

destructor TProcessing.Destroy;
begin
  FreeAndNil(Colliding);
  inherited;
end;

function TProcessing.SetChild(Index: Integer; AItem: BaseClasses.TItem): BaseClasses.TItem;
begin
  Result := inherited SetChild(Index, AItem);
  if (Result <> nil) and (AItem is TProcessing) then (AItem as TProcessing).InvalidateTransform;
end;

procedure TProcessing.OnCollision(Item: TProcessing; const ColRes: Collisions.TCollisionResult);
begin
  Log('Collision "' + Name +'" with "' + Item.GetFullName + '"');
end;

procedure TProcessing.ResolveLinks;
begin
  inherited;
  SendMessage(TPhysicalParameterModifiedMsg.Create(Self), nil, [mfCore]);
end;

procedure TProcessing.AddProperties(const Result: Props.TProperties);
begin
  inherited;
  if not Assigned(Result) then Exit;

//  Result.AddEnumerated('Processing class', [], ProcessingClass+1, (FManager as TBaseCore).GetProcClassesEnum);

  AddVector4sProperty(Result, 'Transform\Location', Location);

  AddQuaternionProperty(Result, 'Transform\Orientation', FOrientation);

  AddVector3sProperty(Result, 'Transform\Scale', Scale);

  if Assigned(Colliding) then Colliding.AddProperties(Result);
end;

procedure TProcessing.SetProperties(Properties: Props.TProperties);
begin
  inherited;
  if SetVector4sProperty(Properties, 'Transform\Location', FLocation) then SetLocation(FLocation);

  if SetQuaternionProperty(Properties, 'Transform\Orientation', FOrientation) then SetOrientation(FOrientation);

  if SetVector3sProperty(Properties, 'Transform\Scale', FScale) then SetScale(FScale);

  if Assigned(Colliding) then Colliding.SetProperties(Properties);
end;

function TProcessing.GetAbsLocation: TVector3s;
begin
  Result.X := Transform._41; Result.Y := FTransform._42; Result.Z := FTransform._43;
end;

function TProcessing.GetAbsOrientation: TQuaternion;
// Multiply orientation quaternions upward to first non-processing parent
var ParItem: BaseClasses.TItem;
begin
  Result := Orientation;

  ParItem := Parent;
  while ParItem is TDummyItem do ParItem := ParItem.Parent;                        // Skip dummy items

  if ParItem is TProcessing then Result := MulQuaternion(TProcessing(ParItem).GetAbsOrientation, Result);
end;

function TProcessing.GetTransform: TMatrix4s;
begin
  if not TransformValid then ComputeTransform;
  Result := FTransform;
end;

function TProcessing.GetTransformPtr: PMatrix4s;
begin
  if not TransformValid then ComputeTransform;
  Result := @FTransform;
end;

procedure TProcessing.SetTransform(const ATransform: TMatrix4s);
begin
  FTransform := ATransform;
//  InvalidateTransform;
  TransformValid := True;
end;

function TProcessing.GetLocation: TVector4s;
begin
  Result := FLocation;
end;

procedure TProcessing.SetLocation(ALocation: TVector4s);
begin
  FLocation := ALocation;
  InvalidateTransform;
end;

function TProcessing.GetPosition: TVector3s;
begin
  Result := FLocation.XYZ;
end;

procedure TProcessing.SetPosition(const Value: TVector3s);
begin
  SetLocation(GetVector4s(Value.X, Value.Y, Value.Z, FLocation.W));
end;

function TProcessing.GetOrientation: TQuaternion;
begin
  Result := FOrientation;
end;

procedure TProcessing.SetOrientation(AOrientation: TQuaternion);
begin
  FOrientation := AOrientation;
  InvalidateTransform;
end;

function TProcessing.GetScale: TVector3s;
begin
  Result := FScale;
end;

procedure TProcessing.SetScale(const Value: TVector3s);
begin
  FScale := Value;
  InvalidateTransform;
end;

procedure TProcessing.InvalidateTransform;

{  procedure InvalidateChilds(Item: BaseClasses.TItem);
  var i: Integer;
  begin
    for i := 0 to Item.TotalChilds-1 do begin
      if (Item.Childs[i] is TProcessing) then begin
        TProcessing(Item.Childs[i]).TransformValid := False;
        InvalidateChilds(Item.Childs[i]);
      end;
      if (Item.Childs[i] is TDummyItem) then InvalidateChilds(Item.Childs[i]);
    end;
  end;}

  procedure InvalidateChilds(Item: BaseClasses.TItem);
  var i: Integer;
  begin
    for i := 0 to Item.TotalChilds-1 do
      if (Item.Childs[i] is TProcessing) then
        TProcessing(Item.Childs[i]).InvalidateTransform
      else
        if (Item.Childs[i] is TDummyItem) then InvalidateChilds(Item.Childs[i]);
  end;

begin
  TransformValid := False;
  InvalidateChilds(Self);
  if IsPhysical then
    SendMessage(TPhysicalTransformModifiedMsg.Create(Self), nil, [mfCore]);
end;

function TProcessing.IsPhysical: Boolean;
begin
  Result := Assigned(Colliding) and (Colliding.Volumes <> nil);
end;

procedure TProcessing.SetState(const Value: TSet32);

  function IsParentsProcessing: Boolean;
  var Item: TItem;
  begin
    Item := Self.Parent;
    while Assigned(Item) and
         ( not (Item is TProcessing) or (isProcessing in Item.State) ) do
      Item := Item.Parent;

    Result := not Assigned(Item);
  end;

  procedure PropagateToChilds(Item: TItem; NewState: Boolean);
  var i: Integer;
  begin
    if Item is TProcessing then              ;
{      if NewState then
        TProcessing(Item).InternalDoUnPause()
      else
        TProcessing(Item).InternalDoPause();}

    for i := 0 to Item.TotalChilds-1 do PropagateToChilds(Item.Childs[i], NewState);
  end;

var OldState: TItemFlags;

begin                                                                     
  OldState := State;
  inherited;
  if {IsParentsProcessing and }(isProcessing in SetXUnion(OldState, Value) ) then begin
    SendMessage(TItemProcessingModifiedMsg.Create(Self), nil, [mfCore]);

  end;
//  PropagateToChilds(Self, isProcessing in Value);
end;

procedure TProcessing.ComputeTransform;
var ParItem: BaseClasses.TItem;
begin
  TranslationMatrix4s(FTransform, FLocation.X, FLocation.Y, FLocation.Z);
  Matrix4sByQuat(FTransform, FOrientation);
  MulMatrix4s(FTransform, ScaleMatrix4s(FScale.X, FScale.Y, FScale.Z), FTransform);

  ParItem := Parent;
  while ParItem is TDummyItem do ParItem := ParItem.Parent;                        // Skip dummy items

  if ParItem is TProcessing then FTransform := MulMatrix4s(FTransform, TProcessing(ParItem).Transform);
  TransformValid := True;
end;

function TProcessing.GetForwardVector: TVector3s;
begin
  Result := GetVector3s(Transform._31, Transform._32, Transform._33);
end;

function TProcessing.GetRightVector: TVector3s;
begin
  Result := GetVector3s(Transform._11, Transform._12, Transform._13);
end;

function TProcessing.GetUpVector: TVector3s;
begin
  Result := GetVector3s(Transform._21, Transform._22, Transform._23);
end;

function TProcessing.GetDimensions: TVector3s;
begin
  ScaleVector3s(Result, SubVector3s(BoundingBox.P2, BoundingBox.P1), 0.5);
end;

function TProcessing.GetBoundingSphereRadius: Single;
var D: Single;
begin
  D := MaxS(SqrMagnitude(BoundingBox.P1), SqrMagnitude(BoundingBox.P2));
  Result := Sqrt(D);
end;

function TProcessing.ModelToWorld(const APoint: TVector3s): TVector3s;
begin
  Result := Transform4Vector33s(Transform, APoint);
end;

function TProcessing.WorldToModel(const APoint: TVector3s): TVector3s;
begin
  Result := Transform4Vector33s(InvertAffineMatrix4s(Transform), APoint);
end;

{ TCamera }

constructor TCamera.Create(AManager: TItemsManager);
var i: Integer;
begin
  inherited;
  InitProjMatrix(1, 100000, 90, 1);
  FCurrentAspectRatio := FAspectRatio;
  RenderTargetIndex   := -1;
  FState    := FState + [isVisible];
  GroupMask := gmDefault;
  for i := 0 to MaxClipPlanes-1 do ClipPlanes[i] := nil;

  DefaultFillMode := fmSolid;
  DefaultCullMode := cmCCW;
  ClearSettings.ClearFlags := [ClearFrameBuffer, ClearZBuffer];
  ClearSettings.ClearColor.C := $002D4D8D;
  ClearSettings.ClearZ       := 1;
end;

destructor TCamera.Destroy;
var i: Integer;
begin
  for i := 0 to MaxClipPlanes-1 do if Assigned(ClipPlanes[i]) then FreeMem(ClipPlanes[i]);
  inherited;
end;

procedure TCamera.AddProperties(const Result: Props.TProperties);
var i: Integer;
begin
  inherited;
  if not Assigned(Result) then Exit;

//  Result.Add('Default', vtBoolean, [], OnOffStr[Default], '');

  for i := 0 to PassGroupsCount-1 do Result.Add(Format('Pass groups\Group %D', [i+1]), vtBoolean, [], OnOffStr[i in GroupMask], '');

  Result.Add('Render\Width',  vtInt, [poReadonly, poDerivative], IntToStr(RenderWidth),  '');
  Result.Add('Render\Height', vtInt, [poReadonly, poDerivative], IntToStr(RenderHeight), '');

  Result.AddEnumerated('Render\Color format', [poReadonly, poDerivative], ColorFormat, PixelFormatsEnum);
  Result.AddEnumerated('Render\Depth format', [poReadonly, poDerivative], DepthFormat, PixelFormatsEnum);

  Result.Add('Render\Current aspect ratio', vtSingle,  [poReadonly, poDerivative], FloatToStr(CurrentAspectRatio),  '');

  Result.Add('Render\LOD bias', vtSingle,  [], FloatToStr(LODBias),  '');

  // Render to texture related properties
  Result.Add('Render\Render target\Width',  vtInt, [], IntToStr(RenderTargetWidth),  '');
  Result.Add('Render\Render target\Height', vtInt, [], IntToStr(RenderTargetHeight), '');
  Result.AddEnumerated('Render\Render target\Color format',   [], FRTColorFormat, PixelFormatsEnum);
  Result.AddEnumerated('Render\Render target\Depth format',   [], FRTDepthFormat, PixelFormatsEnum);
  Result.Add('Render\Render target\Frame skip', vtInt,        [], IntToStr(FrameSkip), '');
  Result.Add('Render\Render target\Depth texture', vtBoolean, [], OnOffStr[IsDepthTexture], '');

  Result.Add('Projection\Orthographic', vtBoolean, [], OnOffStr[FOrthographic], '');

  Result.Add('Projection\Z near',         vtSingle,  [], FloatToStr(FZNear),              '');
  Result.Add('Projection\Z far',          vtSingle,  [], FloatToStr(FZFar),               '');
  Result.Add('Projection\Horizontal FoV', vtInt,     [], IntToStr(Round(FHFoV * RadToDeg)), '0-180');
  Result.Add('Projection\Visible width',  vtSingle,  [], FloatToStr(FWidth), '');
  Result.Add('Projection\Aspect ratio',   vtSingle,  [], FloatToStr(FAspectRatio),        '0.125-8');

  Result.Add('Clear\Frame buffer',        vtBoolean, [], OnOffStr[ClearFrameBuffer   in ClearSettings.ClearFlags], '');
  Result.Add('Clear\Z buffer',            vtBoolean, [], OnOffStr[ClearZBuffer       in ClearSettings.ClearFlags], '');
  Result.Add('Clear\Stencil buffer',      vtBoolean, [], OnOffStr[ClearStencilBuffer in ClearSettings.ClearFlags], '');

  AddColorProperty(Result, 'Clear\Color value', ClearSettings.ClearColor);
  Result.Add('Clear\Z value',             vtSingle,  [], FloatToStr(ClearSettings.ClearZ),            '');
  Result.Add('Clear\Stencil value',       vtNat,     [], IntToStr(ClearSettings.ClearStencil),        '');

  Result.AddEnumerated('Render\Default face culling', [], DefaultCullMode, CameraCullModesEnum);
  Result.AddEnumerated('Render\Default fill mode',    [], DefaultFillMode, CameraFillModesEnum);
end;

procedure TCamera.SetProperties(Properties: Props.TProperties);
var i: Integer;
begin
  inherited;

//  if Properties.Valid('Default') then Default := Properties.GetAsInteger('Default') > 0;

  for i := 0 to PassGroupsCount-1 do
    if Properties.Valid(Format('Pass groups\Group %D', [i+1])) then
      if Properties.GetAsInteger(Format('Pass groups\Group %D', [i+1])) > 0 then
        GroupMask := GroupMask + [i] else
          GroupMask := GroupMask - [i];

  if Properties.Valid('Render\Render target\Width')  then RenderTargetWidth  := StrToIntDef(Properties['Render\Render target\Width'],  0);
  if Properties.Valid('Render\Render target\Height') then RenderTargetHeight := StrToIntDef(Properties['Render\Render target\Height'], 0);

  if Properties.Valid('Render\Render target\Color format')  then FRTColorFormat    := Properties.GetAsInteger('Render\Render target\Color format');
  if Properties.Valid('Render\Render target\Depth format')  then FRTDepthFormat    := Properties.GetAsInteger('Render\Render target\Depth format');
  if Properties.Valid('Render\Render target\Frame skip')    then FrameSkip         := StrToIntDef(Properties['Render\Render target\Frame skip'], 0);
  if Properties.Valid('Render\Render target\Depth texture') then IsDepthTexture      := Properties.GetAsInteger('Render\Render target\Depth texture') > 0;

  if Properties.Valid('Projection\Orthographic') then FOrthographic := Properties.GetAsInteger('Projection\Orthographic') > 0;

  if Properties.Valid('Projection\Z near')         then FZNear := StrToFloatDef(Properties['Projection\Z near'],        1);
  if Properties.Valid('Projection\Z far')          then FZFar  := StrToFloatDef(Properties['Projection\Z far'],         100000);
  if Properties.Valid('Projection\Horizontal FoV') then FHFoV  := StrToIntDef(Properties['Projection\Horizontal FoV'], 90) * DegToRad;
  if Properties.Valid('Projection\Visible width')  then FWidth := StrToFloatDef(Properties['Projection\Visible width'], 0);

  if Properties.Valid('Projection\Aspect ratio') then begin
    FAspectRatio := StrToFloatDef(Properties['Projection\Aspect ratio'], 1);
    FCurrentAspectRatio := FAspectRatio;
  end;

  if Properties.Valid('Render\LOD bias') then LODBias := StrToFloatDef(Properties['Render\LOD bias'], 0);

  if Properties.Valid('Clear\Frame buffer')   then if Properties.GetAsInteger('Clear\Frame buffer')   > 0 then
    Include(ClearSettings.ClearFlags, ClearFrameBuffer) else Exclude(ClearSettings.ClearFlags, ClearFrameBuffer);
  if Properties.Valid('Clear\Z buffer')       then if Properties.GetAsInteger('Clear\Z buffer')       > 0 then
    Include(ClearSettings.ClearFlags, ClearZBuffer) else Exclude(ClearSettings.ClearFlags, ClearZBuffer);
  if Properties.Valid('Clear\Stencil buffer') then if Properties.GetAsInteger('Clear\Stencil buffer') > 0 then
    Include(ClearSettings.ClearFlags, ClearStencilBuffer) else Exclude(ClearSettings.ClearFlags, ClearStencilBuffer);

  SetColorProperty(Properties, 'Clear\Color value', ClearSettings.ClearColor);
  if Properties.Valid('Clear\Z value')        then ClearSettings.ClearZ       := StrToFloatDef(Properties['Clear\Z value'], 1);
  if Properties.Valid('Clear\Stencil value')  then ClearSettings.ClearStencil := Longword(Properties.GetAsInteger('Clear\Stencil value'));

  if Properties.Valid('Render\Default face culling') then DefaultCullMode := Properties.GetAsInteger('Render\Default face culling');
  if Properties.Valid('Render\Default fill mode')    then DefaultFillMode := Properties.GetAsInteger('Render\Default fill mode');

  InitProjMatrix(FZNear, FZFar, FHFoV, FAspectRatio);
end;

procedure TCamera.InvalidateTransform;
begin
  inherited;
  FViewValid := False;
end;

procedure TCamera.ComputeViewMatrix;
begin
{  FViewMatrix     :=  ExpandMatrix3s(GetTransposedMatrix3s(CutMatrix3s(Transform)));
  Pos := GetAbsLocation;
  FViewMatrix._41 := -DotProductVector3s(FTransform.ViewRight,   Pos);
  FViewMatrix._42 := -DotProductVector3s(FTransform.ViewUp,      Pos);
  FViewMatrix._43 := -DotProductVector3s(FTransform.ViewForward, Pos);}
  FInvViewMatrix := Transform;
  FViewMatrix := InvertAffineMatrix4s(FInvViewMatrix);
  MulMatrix4s(FTotalMatrix, FViewMatrix, ProjMatrix);
  ComputeFrustumPlanes;
  FViewValid := True;
end;

procedure TCamera.InitProjMatrix(AZNear, AZFar, AHFoV, AAspectRatio: Single);
var w, h, q: Single; Cen: TVector3s;
begin
  FZNear       := AZNear;
  FZFar        := AZFar;
  FHFoV        := AHFoV;
  AspectRatio  := AAspectRatio;

  FillChar(FProjMatrix, SizeOf(FProjMatrix), 0);

  if FOrthographic then begin
    FProjMatrix := IdentityMatrix4s;
    w := FWidth;
//    h := w * CurrentAspectRatio;
    h := w * AspectRatio;
//    FProjMatrix.m[0, 0] := 2/w; FProjMatrix.m[1, 1] := 2/h; FProjMatrix.m[2, 2] := 2/(FZFar - FZNear);
//    MulMatrix4s(FProjMatrix, ScaleMatrix4s(2/w, 2/h, 2/(FZFar - FZNear)), TranslationMatrix4s(-GetAbsLocation.x, -GetAbsLocation.y, -GetAbsLocation.z));
    Cen := GetAbsLocation;
//    MulMatrix4s(FProjMatrix, TranslationMatrix4s(-Cen.x, -Cen.y, -Cen.z), ScaleMatrix4s(2/w, 2/h, 2/(FZFar - FZNear)));
    FProjMatrix := ScaleMatrix4s(2/w, 2/h, 2/(FZFar - FZNear));
  end else begin
    w := Cos(FHFov * 0.5) / Sin(FHFov * 0.5);
    h := w * CurrentAspectRatio;
    q := FZFar / (FZFar - FZNear);
    FProjMatrix.m[0, 0] := w; FProjMatrix.m[1, 1] := h; FProjMatrix.m[2, 2] := q;
    FProjMatrix.m[3, 2] := -q*FZNear; FProjMatrix.m[2, 3] := 1;
  end;

//  ViewValid := False;
end;

procedure TCamera.InitOrthoProjMatrix(AZNear, AZFar, VisibleWidth, AAspectRatio: Single);
begin
  FOrthographic := True;
  FWidth := VisibleWidth;
  InitProjMatrix(AZNear, AZFar, FHFoV, AAspectRatio);
end;

procedure TCamera.SetClearState(AClearFlags: TClearFlagsSet; AClearColor: BaseTypes.TColor; AClearZ: Single; AClearStencil: Cardinal);
begin
  ClearSettings.ClearFlags   := AClearFlags;
  ClearSettings.ClearColor   := AClearColor;
  ClearSettings.ClearZ       := AClearZ;
  ClearSettings.ClearStencil := AClearStencil;
end;

procedure TCamera.SetScreenDimensions(Width, Height: Integer; AdjustAspectRatio: Boolean);
begin
  if (Width = FRenderWidth) and (Height = FRenderHeight) then Exit;
  FRenderWidth  := Width;
  FRenderHeight := Height;
  if AdjustAspectRatio then begin
    FCurrentAspectRatio := Width / Height * AspectRatio;
  end;
  InitProjMatrix(FZNear, FZFar, FHFoV, FAspectRatio);
end;

procedure TCamera.Rotate(XA, YA, ZA: Single);
begin
  Orientation := MulQuaternion(GetQuaternion(XA, RightVector), MulQuaternion(GetQuaternion(YA, UpVector), MulQuaternion(GetQuaternion(ZA, ForwardVector), Orientation)));
end;

procedure TCamera.Move(XD, YD, ZD: Single);
begin
{  if Core.Renderer.MainCamera is TLookAtCamera then begin
    with (Core.Renderer.MainCamera as TLookAtCamera) do
      LookTarget := AddVector3s(LookTarget, AddVector3s(ScaleVector3s(RightVector, -(NewMouseX - LastMouseX)*0.10), ScaleVector3s(UpVector, (NewMouseY - LastMouseY)*0.10)));}
  Position := AddVector3s(Position, AddVector3s(AddVector3s(ScaleVector3s(RightVector, XD), ScaleVector3s(UpVector, YD)), ScaleVector3s(ForwardVector, ZD)));
end;

function TCamera.GetPickRay(ScreenX, ScreenY: Single): TVector3s;
var d: Single;
begin
  d := 0.5*RenderWidth / Sin(FHFoV/2)*Cos(FHFoV/2);
  Result.X := -0.5*RenderWidth  + ScreenX;
  if RenderHeight > epsilon then
    Result.Y := (0.5*RenderHeight - ScreenY)*RenderWidth/RenderHeight/CurrentAspectRatio else
      Result.Y := 0;
  Result.Z := d;
end;

function TCamera.GetPickRayInWorld(ScreenX, ScreenY: Single): TVector3s;
begin
  Transform3Vector3s(Result, CutMatrix3s(InvertAffineMatrix4s(ViewMatrix)), GetPickRay(ScreenX, ScreenY));
end;

function TCamera.Project(const Vec: TVector3s): TVector4s;
var TRHW: Single;
begin
  Result := Transform4Vector3s(TotalMatrix, Vec);
  TRHW := 1/Result.W;
  Result.X := RenderWidth  shr 1 + Result.X * (RenderWidth  shr 1) * TRHW;
  Result.Y := RenderHeight shr 1 - Result.Y * (RenderHeight shr 1) * TRHW;
//  Result.Z := (ZFar/(ZFar-ZNear))*(1-ZNear/(Result.Z));          // ToFix: Optimize it
end;

function TCamera.GetViewMatrix: TMatrix4s;
begin
  if not FViewValid then ComputeViewMatrix;
  Result := FViewMatrix;
end;

function TCamera.GetViewMatrixPtr: PMatrix4s;
begin
  if not FViewValid then ComputeViewMatrix;
  Result := @FViewMatrix;
end;

function TCamera.GetProjMatrixPtr: PMatrix4s;
begin
  Result := @FProjMatrix;
end;

procedure TCamera.SetViewMatrix(const Value: TMatrix4s);
begin
  FViewMatrix := Value;
  FInvViewMatrix := InvertAffineMatrix4s(FViewMatrix);;
  MulMatrix4s(FTotalMatrix, FViewMatrix, ProjMatrix);
  ComputeFrustumPlanes;
  FViewValid := True;
end;

function TCamera.GetInvViewMatrix: TMatrix4s;
begin
  if not FViewValid then ComputeViewMatrix;
  Result := FInvViewMatrix;
end;

function TCamera.GetTotalMatrix: TMatrix4s;
begin
  if not FViewValid then ComputeViewMatrix;
  Result := FTotalMatrix;
end;

function TCamera.GetViewOrigin: TVector3s;
begin
  Result := GetVector3s(InvViewMatrix._41, InvViewMatrix._42, InvViewMatrix._43);
end;

function TCamera.GetLookDir: TVector3s;
begin
  Result := GetVector3s(InvViewMatrix._31, InvViewMatrix._32, InvViewMatrix._33);
end;

function TCamera.GetRightDir: TVector3s;
begin
  Result := GetVector3s(InvViewMatrix._11, InvViewMatrix._12, InvViewMatrix._13);
end;

function TCamera.GetUpDir: TVector3s;
begin
  Result := GetVector3s(InvViewMatrix._21, InvViewMatrix._22, InvViewMatrix._23);
end;

procedure TCamera.SetAspectRatio(const Value: Single);
begin
  FAspectRatio := Value;
  if FRenderHeight <> 0 then
    FCurrentAspectRatio := FRenderWidth / FRenderHeight * FAspectRatio
  else
    FCurrentAspectRatio := 0;
end;

procedure TCamera.ComputeFrustumPlanes;
var i: Integer; M: Tmatrix4s;
begin
  M := FTotalMatrix;
  // Left clipping plane
  FFrustumPlanes[fpLeft].a := M._14 + M._11;
  FFrustumPlanes[fpLeft].b := M._24 + M._21;
  FFrustumPlanes[fpLeft].c := M._34 + M._31;
  FFrustumPlanes[fpLeft].d := M._44 + M._41;
  // Right clipping plane
  FFrustumPlanes[fpRight].a := M._14 - M._11;
  FFrustumPlanes[fpRight].b := M._24 - M._21;
  FFrustumPlanes[fpRight].c := M._34 - M._31;
  FFrustumPlanes[fpRight].d := M._44 - M._41;
  // Top clipping plane
  FFrustumPlanes[fpTop].a := M._14 - M._12;
  FFrustumPlanes[fpTop].b := M._24 - M._22;
  FFrustumPlanes[fpTop].c := M._34 - M._32;
  FFrustumPlanes[fpTop].d := M._44 - M._42;
  // Bottom clipping plane
  FFrustumPlanes[fpBottom].a := M._14 + M._12;
  FFrustumPlanes[fpBottom].b := M._24 + M._22;
  FFrustumPlanes[fpBottom].c := M._34 + M._32;
  FFrustumPlanes[fpBottom].d := M._44 + M._42;
  // Near clipping plane
  FFrustumPlanes[fpNear].a := M._13;
  FFrustumPlanes[fpNear].b := M._23;
  FFrustumPlanes[fpNear].c := M._33;
  FFrustumPlanes[fpNear].d := M._43;
  // Far clipping plane
  FFrustumPlanes[fpFar].a := M._14 - M._13;
  FFrustumPlanes[fpFar].b := M._24 - M._23;
  FFrustumPlanes[fpFar].c := M._34 - M._33;
  FFrustumPlanes[fpFar].d := M._44 - M._43;
  // Normalize
  for i := Ord(Low(TFrustumPlane)) to Ord(High(TFrustumPlane)) do NormalizePlane(FFrustumPlanes[TFrustumPlane(i)]);
end;

procedure TCamera.OnApply(const OldCamera: TCamera);
begin
  ClipPlanes[0] := nil;
end;

function TCamera.IsSpehereVisible(const Center: TVector3s; Radius: Single): TFrustumCheckResult;
var i: Integer; d: Single;
begin
  if not FViewValid then ComputeViewMatrix;
  Result := fcOutside;
  for i := Ord(Low(TFrustumPlane)) to Ord(High(TFrustumPlane)) do begin
    d := DotProductVector3s(FFrustumPlanes[TFrustumPlane(i)].Normal, Center) + FFrustumPlanes[TFrustumPlane(i)].D;
    if d < -Radius then Exit;                                     // Sphere is out of frustum
    if Abs(d) < Radius then begin                                 // Sphere intersects frustum
      Result := fcPartially; Exit;
    end;
  end;
  Result := fcInside;                                             // Sphere completely inside frustum
end;

{ TBaseCore }

procedure TBaseCore.SetTimer(const Value: Timer.TTimer);
begin
  Assert(Assigned(Value), 'TCore.SetTimer: Timer should be defined');
  if Assigned(FTimer) then RemoveSubsystem(FTimer);
  if (FTimer = DefaultTimer) and (Value <> DefaultTimer) then FreeAndNil(DefaultTimer);
  FTimer := Value;
  if Assigned(FTimer) then AddSubsystem(FTimer);
end;

procedure TBaseCore.SetTotalProcessingClasses(const Value: Integer);
var l, i: Integer;
begin
  l := Length(ProcessingClasses);
  for i := l-1 downto Value do
    FTimer.RemoveRecurringEvent(ProcessingClasses[i].TimerEventID);
  SetLength(ProcessingClasses, Value);
  for i := l to Value-1 do begin
    ProcessingClasses[i].Interval := DefaultProcessingInterval;
    ProcessingClasses[i].Flags    := [];
    ProcessingClasses[i].TimerEventID := Timer.SetRecurringEvent(ProcessingClasses[i].Interval, ProcessingEvent, i);
  end;
end;

procedure TBaseCore.ProcessDeltaTimeBased(const DeltaTime: TTimeUnit);
var i, j: Integer;
begin
  for j := 0 to TotalProcessingItems-1 do begin
    Assert(ProcessingItems[j] is TBaseProcessing, ProcessingItems[j].Name + ' is not a descendant of TBaseProcessing');
    i := TBaseProcessing(ProcessingItems[j]).ProcessingClass;
    if (i >= 0) and (pfDeltaTimeBased in ProcessingClasses[i].Flags) and
       (not Paused or (pfIgnorePause in ProcessingClasses[i].Flags)) then
      TBaseProcessing(ProcessingItems[j]).Process(DeltaTime);
  end;
end;

procedure TBaseCore.ProcessingEvent(EventID: Integer; const ErrorDelta: TTimeUnit);
var j: Integer;
begin
  if Paused and not (pfIgnorePause in ProcessingClasses[EventID].Flags) then Exit;
  for j := 0 to TotalProcessingItems-1 do begin
    Assert(ProcessingItems[j] is TBaseProcessing, ProcessingItems[j].Name + ' is not a descendant of TBaseProcessing');
    if TBaseProcessing(ProcessingItems[j]).ProcessingClass = EventID then
      TBaseProcessing(ProcessingItems[j]).Process((ProcessingClasses[EventID].Interval + ErrorDelta) * TimeScale);
  end;
end;

procedure TBaseCore.OnDestroy;
var i: Integer;
begin
  Log('Engine shut down');
  FreeAndNil(FTesselatorManager);
  FreeAndNil(FSharedTesselators);
  FreeAndNil(RandomGen);
  FreeAndNil(FPerfProfile);
  inherited;
//  for i := 0 to High(Subsystems) do FreeAndNil(Subsystems[i]);
  Subsystems := nil;
  FreeAndNil(DefaultTimer);
end;

constructor TBaseCore.Create;
begin
  inherited;
  Log('CAST II v' + EngineVersionMajor + '.' + EngineVersionMinor + ' starting up', lkInfo);
  {$IFDEF EDITORMODE}
  FEditorMode := True;
  Log('World editing capabilities are On', lkWarning);
  {$ELSE}
  FEditorMode := False;
  Log('World editing capabilities are Off', lkWarning);
  {$ENDIF}

  DefaultTimer := TTimer.Create({$IFDEF OBJFPCEnable}@{$ENDIF}HandleMessage);
  Timer        := DefaultTimer;
  Timer.MaxInterval := 5;                                    // Process recurring events for 5 last seconds only

  Timer.GetInterval(DeltaTimeBasedTimeMark, True);           // Initialize the time mark

  RegisterItemClass(TCASTRootItem);

  RandomGen := Basics.TRandomGenerator.Create;

  FTesselatorManager := BaseCont.TReferencedItemManager.Create;

  FPerfProfile := TPerfProfile.Create;

  TotalProcessingClasses := 1;
  SetProcessingClass(0, 30/1000, False, True);
  
  TimeScale := 1;
end;

procedure TBaseCore.HandleMessage(const Msg: TMessage);
var i: Integer;
begin
  inherited;
  if Msg.ClassType = TSubsystemMsg then with TSubsystemMsg(Msg) do begin
    case Action of
      saConnect: AddSubsystem(Subsystem);
      saDisconnect: RemoveSubsystem(Subsystem);
    end;  
  end;
  for i := 0 to High(Subsystems) do Subsystems[i].HandleMessage(Msg);
  if Assigned(MessageHandler) then MessageHandler(Msg);
end;

procedure TBaseCore.AddSubsystem(const Subsystem: TBaseSubsystem);
{$IFDEF DEBUGMODE}var i: Integer;{$ENDIF}
begin
  Assert(Assigned(Subsystem), Format('%S.%S: Subsystem is undefined(nil)', [ClassName, 'AddSubsystem']));
  {$IFDEF DEBUGMODE}
  i := High(Subsystems);
  while (i >= 0) and (Subsystems[i] <> Subsystem) do Dec(i);
  Assert(i < 0, Format('%S.%S: Subsystem of class %S already exists', [ClassName, 'AddSubsystem', Subsystem.ClassName]));
  {$ENDIF}

  SetLength(Subsystems, Length(Subsystems)+1);
  Subsystems[High(Subsystems)] := Subsystem;
  Log(Format('Subsystem of class %S connected', [Subsystem.ClassName]));
end;

procedure TBaseCore.RemoveSubsystem(const Subsystem: TBaseSubsystem);
var i: Integer;
begin
  i := High(Subsystems);
  while (i >= 0) and (Subsystems[i] <> Subsystem) do Dec(i);

  Assert(i >= 0, Format('%S.%S: Subsystem of class %S not found', [ClassName, 'RemoveSubsystem', Subsystem.ClassName]));

  if i >= 0 then begin
    Subsystems[i] := Subsystems[Length(Subsystems)-1];
    SetLength(Subsystems, Length(Subsystems)-1);
  end else
    Log(Format('%S.%S: Subsystem of class %S not found', [ClassName, 'RemoveSubsystem', Subsystem.ClassName]), lkError);

   Log(Format('Subsystem of class %S disconnected', [Subsystem.ClassName])); 
end;

function TBaseCore.QuerySubsystem(SubsystemClass: CSubsystem): TBaseSubsystem;
var i: Integer;
begin
  Result := nil;
  i := High(Subsystems);
  while (i >= 0) and not Subsystems[i].InheritsFrom(SubsystemClass) do Dec(i);
  if i >= 0 then Result := Subsystems[i];  
end;

procedure TBaseCore.SetProcessingClass(Index: Integer; Interval: Single; IgnorePause, DeltaTimeBased: Boolean);
var OldFlags: TProcessingFlags;
begin
  if (Index < 0) or (Index >= TotalProcessingClasses) then begin
    Log(ClassName + '.SetProcessingClass: Invalid index', lkError);
    Exit;
  end;
  OldFlags := ProcessingClasses[Index].Flags;

  ProcessingClasses[Index].Interval := Interval;
  ProcessingClasses[Index].Flags := [];
  if IgnorePause    then Include(ProcessingClasses[Index].Flags, pfIgnorePause)    else Exclude(ProcessingClasses[Index].Flags, pfIgnorePause);
  if DeltaTimeBased then Include(ProcessingClasses[Index].Flags, pfDeltaTimeBased) else Exclude(ProcessingClasses[Index].Flags, pfDeltaTimeBased);
  if DeltaTimeBased then begin
    if ProcessingClasses[Index].TimerEventID <> -1 then Timer.RemoveRecurringEvent(ProcessingClasses[Index].TimerEventID);
    ProcessingClasses[Index].TimerEventID := -1;
  end else begin
    if ProcessingClasses[Index].TimerEventID = -1 then
      ProcessingClasses[Index].TimerEventID := Timer.SetRecurringEvent(ProcessingClasses[Index].Interval, ProcessingEvent, Index)
    else
      Timer.SetRecurringEventInterval(ProcessingClasses[Index].TimerEventID, ProcessingClasses[Index].Interval);
  end;
end;

procedure TBaseCore.ClearItems;
begin
  if Assigned(FSharedTesselators) then FSharedTesselators.Clear;
  inherited;
  if Assigned(FTesselatorManager) then FTesselatorManager.Clear;
end;

{procedure TBaseCore.SetRoot(ARoot: TRootItem);
begin
  FRoot := ARoot;
  if Root <> nil then Root.FManager := Self;
end;}

{ TMirrorCamera }

procedure TMirrorCamera.ComputeViewMatrix;
begin
  if Assigned(FOldCamera) and (FOldCamera <> Self) then begin
    FViewMatrix := FOldCamera.GetViewMatrix;
    FViewMatrix := MulMatrix4s(ReflectionMatrix4s(GetAbsLocation, NormalizeVector3s(Transform.ViewForward)), FViewMatrix);
    FInvViewMatrix := InvertAffineMatrix4s(FViewMatrix);
    MulMatrix4s(FTotalMatrix, FViewMatrix, ProjMatrix);
    FViewValid := True;
    FOldCamera := nil;
    ComputeFrustumPlanes;
  end else inherited;
end;

procedure TMirrorCamera.OnApply(const OldCamera: TCamera);
begin
  FOldCamera := OldCamera;
  FViewValid  := False;
  if not Assigned(ClipPlanes[0]) then GetMem(ClipPlanes[0], SizeOf(ClipPlanes[0]^));
  ClipPlanes[0]^ := GetPlaneFromPointNormal(GetAbsLocation, ScaleVector3s(Transform.ViewForward, 1));
end;

{ TItemMoveOp }

procedure TItemMoveOp.DoApply;
var t: TLocation;
begin
  t := Location;
  Location := AffectedProcessing.Location;
  AffectedProcessing.Location := t;
end;

function TItemMoveOp.DoMerge(AOperation: TOperation): Boolean;
begin
  Result := (AOperation is TItemMoveOp) and (TItemMoveOp(AOperation).AffectedProcessing = AffectedProcessing);
  if Result and not (ofApplied in Flags) then Location := TItemMoveOp(AOperation).Location;
end;

function TItemMoveOp.Init(AAffectedProcessing: TProcessing; ALocation: TLocation): Boolean;
begin
  Result := False;
  Assert(Assigned(AAffectedProcessing));
  if EqualLocations(ALocation, AAffectedProcessing.Location) then Exit;

  AffectedProcessing := AAffectedProcessing;
  Location := ALocation;

  Result := True;
end;

{ TItemRotateOp }

procedure TItemRotateOp.DoApply;
var t: TQuaternion;
begin
  t := Orientation;
  Orientation := AffectedProcessing.Orientation;
  AffectedProcessing.Orientation := t;
end;

function TItemRotateOp.DoMerge(AOperation: TOperation): Boolean;
begin
  Result := (AOperation is TItemRotateOp) and (TItemRotateOp(AOperation).AffectedProcessing = AffectedProcessing);
  if Result and not (ofApplied in Flags) then Orientation := TItemRotateOp(AOperation).Orientation;
end;

function TItemRotateOp.Init(AAffectedProcessing: TProcessing; AOrientation: TQuaternion): Boolean;
begin
  Result := False;
  Assert(Assigned(AAffectedProcessing));
  if EqualsQuaternions(AAffectedProcessing.Orientation, AOrientation) then Exit;

  AffectedProcessing := AAffectedProcessing;
  Orientation := AOrientation;

  Result := True;
end;

initialization
  SetFPUControlWord(FPUAllExceptions, False, fpup53Bit, fpurNearestOrEven, True);
end.