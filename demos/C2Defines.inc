{$DEFINE OPENGL}
{$IFDEF OPENGL}
  {.$DEFINE OGLERRORCHECK}
{$ELSE}
  {$DEFINE DIRECT3D8}            // Direct X 8 renderer
{$ENDIF}
{$IFDEF DIRECT3D8}
  {.$DEFINE DX8ERRORSTR}        // DirectX error details. dxerr81ab.dll needed
  {.$DEFINE USED3DX8}           // No D3DX8*.dll will be needed but only precompiled shaders can be used as shader compilation routines resists in D3DX
{$ENDIF}
{$DEFINE AUDIO}
{$DEFINE MUSIC}
{.$DEFINE NETSUPPORT}
{.$DEFINE WANSUPPORT}          // Internet play support
{.$DEFINE SCRIPTING}           // Scripting support

{.$DEFINE USENEWTON}               // Use Newton Dynamics physics library

{.$DEFINE EDITORMODE}           // World editor capabilities


  {$DEFINE EXTLOGGING}          // Extended logging
  {.$DEFINE FULLNETLOGGING}      // Full network commands logging


{.$DEFINE PORTALBUILD}         // Disable license name (key only)
{.$DEFINE ONLINEBUILD}         // Restrict some features for online version
{.$DEFINE SCREENSAVER}         // Restrict some features for screen saver version
{.$DEFINE DIRECTSOUNDNIL}      // DS init fail imitation


