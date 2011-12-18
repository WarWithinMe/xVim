//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

@class XTextViewBridge;

typedef enum e_VimMode
{
    InsertMode = 0,
    NormalMode = 1,
    VisualMode = 2,
    ExMode     = 3,
    ReplaceMode = 4,
    SingleReplaceMode = 5,
    VimModeCount
} VimMode;

typedef enum e_SpecialKeys
{
    XSpace = ' ',
    XEsc   = 27
} SpecialKeys;

// Whenever we need store the key input, we store it in a unsigned int.
// The higher half is used to store the modifiers,
// and the lower half is used to store the actual key input.
typedef enum e_ModifierFlags
{
    XMaskCapLock = NSAlphaShiftKeyMask,
    XMaskShift   = NSShiftKeyMask,
    XMaskControl = NSControlKeyMask,
    XMaskAlt     = NSAlternateKeyMask,
    XMaskCommand = NSCommandKeyMask,
    XMaskNumeric = NSNumericPadKeyMask,
    XMaskFn      = NSFunctionKeyMask,
    
    XUnicharMask = 0x0000ffffU,
    XModifierFlagsMask = 0xffff0000U,
    XImportantMask = XMaskControl | XMaskCommand | XMaskAlt | XMaskFn
    
} ModifierFlags;

// XVimController is used to process key inputs.
// The idea is that XVimContoller is to handle keymapping,
// and then hands the input event to the appropriate XVimMode to handle.
@interface XVimController : NSObject

@property (readonly) XTextViewBridge* bridge;
@property (readonly) VimMode          mode;

-(void) switchToMode:(VimMode)mode;

// These methods should only be called by XTextViewBridge.
-(XVimController*) initWithBridge:(XTextViewBridge*) bridge;
-(void) dealloc;
-(void) processKeyEvent:(NSEvent*) event;
@end
