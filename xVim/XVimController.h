//
//  Created by Morris Liang on 11-12-7.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

/*
 * XVimController is used to process key event for NSTextView.
 * It first try to translate the key sequence if they are mapped keys.
 * Then it ask the current mode handler (subclasses of XVimMode) to handle
 * the keys.
 */

@class XTextViewBridge;
@class XVimModeHandler;

typedef enum e_VimMode
{
    InsertMode   = 0,
    NormalMode   = 1,
    VisualMode   = 2,
    ExMode       = 3,
    ReplaceMode  = 4,
    VimModeCount,
    
    // Submode
    NoSubMode,
    VisualLineMode,
    SingleReplaceMode,
    
    // Ex mode submodes
    SearchSubMode,
    BackwardsSearchSubMode
    
} VimMode;

typedef enum e_SpecialKeys
{
    XSpace    = ' ',
    XTab      = '\t',
    XShiftTab = 25,
    XEsc      = 27
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
    XModifierFlagsMaskX = XModifierFlagsMask & (~(XMaskCapLock | NSHelpKeyMask)),
    XImportantMask = XMaskControl | XMaskCommand | XMaskAlt | XMaskFn
    
} ModifierFlags;

// XVimController is used to process key inputs.
// The idea is that XVimContoller is to handle keymapping,
// and then hands the input event to the appropriate XVimMode to handle.
@interface XVimController : NSObject

@property (readonly) XTextViewBridge* bridge;
@property (readonly) VimMode          mode;



-(void) switchToMode:(VimMode) mode;
-(void) switchToMode:(VimMode) mode subMode:(VimMode) sub;

// Yank the text to the noname register, which is shared among the application.
-(void) yank:(NSString*) string withRange:(NSRange) range wholeLine:(BOOL) flag;
// Return the content currently in the noname register.
-(NSString*) yankContent:(BOOL*) isWholeLine;

-(NSInteger) getTrackingSel;
-(void) moveCaretDown:(NSUInteger) count;
-(void) moveCaretUp:(NSUInteger) count;
-(void) sendKeyEvent:(unichar) ch modifiers:(NSUInteger) flag count:(NSUInteger) c;



// These methods should only be called by XTextViewBridge.
-(XVimController*) initWithBridge:(XTextViewBridge*) bridge;
-(void) dealloc;
-(void) processKeyEvent:(NSEvent*) event;
-(BOOL) isWaitingForMotion;
-(XVimModeHandler*) currentHandler;
-(XVimModeHandler*) handlerForMode:(VimMode)m;
-(NSArray*) selectionChangedFrom:(NSArray*)oldRanges to:(NSArray*)newRanges;
-(void) didChangedSelection;
-(void) selRangeForProposed:(NSRange) range;

+(void) load;
-(void) finalize;
@end
