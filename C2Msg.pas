(*
 @Abstract(CAST II Engine messages unit)
 (C) 2006-2007 George "Mirage" Bakhtadze. <a href="http://www.casteng.com">www.casteng.com</a> <br>
 The source code may be used under either MPL 1.1 or LGPL 2.1 license. See included license.txt file <br>
 Created: Aug 08, 2007 <br>
 Unit contains engine specific messages
*)
{$Include GDefines.inc}
{$Include C2Defines.inc}
unit C2Msg;

interface

uses Basics, BaseClasses, BaseMsg, ItemMsg;

type
  // Core receives this message after initialization or reinitialization of a rendering context
  TRenderReinitMsg = class(TNotificationMessage)
  end;

  // This message is sent to all materials when a pass is modified
  TRenderPassModifiedMsg = class(TItemNotificationMessage)
  end;

  // This message is sent to visible items before a technique is modified
  TTechniqueModificationBeginMsg = class(TItemNotificationMessage)
  end;

  // This message is sent to visible items after a technique is modified
  TTechniqueModificationEndMsg = class(TItemNotificationMessage)
  end;

  // This message is a validation request sent to core by a material
  TRequestValidationMsg = class(TItemNotificationMessage)
  end;

  // This message is sent when a set of valid techniques for a material has been changed
  TValidationResultChangedMsg = class(TItemNotificationMessage)
  end;

implementation

end.
