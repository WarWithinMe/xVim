//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import "XVimMode.h"
#import "XVimController.h"
#import "XVimPlugin.h"

@implementation XVimModeHandler
-(void) reset{}
-(void) processKey:(NSString *)key For:(XVimController *)controller{}
@end

@implementation XVimInsertModeHandler
-(void) processKey:(NSString*)key For:(XVimController*)controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            [controller switchToMode:NormalMode];
        }
    } else {
        // The key is not Esc, send the key back to the hijacked textview.
        NSEvent* keyEvent = [controller currentKeyEvent];
        if (keyEvent == nil) { keyEvent = [XVimController fakeEventFor:key]; }
        [[controller bridge] handleFakeKeyEvent:keyEvent];
    }
}
@end

@implementation XVimReplaceModeHandler
-(void) processKey:(NSString*) key For:(XVimController*) controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            [controller switchToMode:NormalMode];
        }
    } else {
        if ([key length] == 1)
        {
            // This key should be a visible key input.
            // Change the text.
            NSTextView* hijackedView = [[controller bridge] targetView];
            NSRange selectedRange = [hijackedView selectedRange];
            selectedRange.length = 1;
            [hijackedView replaceCharactersInRange:selectedRange withString:key];
            
        }
    }
}
@end

@implementation XVimSReplaceModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller
{
    if ([key compare:@"<Esc>"] == NSOrderedSame) {
        if ([[controller bridge] closePopup] == NO) {
            // There's no popup, so we now switch to Normal Mode.
            [controller switchToMode:NormalMode];
        }
    } else {
        if ([key length] == 1)
        {
            // This key should be a visible key input.
            // Change the text.
            NSTextView* hijackedView = [[controller bridge] targetView];
            NSRange selectedRange = [hijackedView selectedRange];
            selectedRange.length = 1;
            [hijackedView replaceCharactersInRange:selectedRange withString:key];
            [controller switchToMode:NormalMode];
        }
    }
}
@end

typedef enum e_SubMode{
    Opening
} SubMode;
@interface XVimNormalModeHandler()
{
    @private
        SubMode smode;
        int commandCount;
        int motionCount;
}
@end

@implementation XVimNormalModeHandler
// A set of methods to perform vim actions.
//a	 Enters insert mode after the current character
//I	 Enters insert mode at the start of the indentation of current line
//A	 Enters insert mode at the end of line
//o	 Opens a new line below, auto indents, and enters insert mode
//O	 Opens a new line above, auto indents, and enters insert mode
//R	 Enters replace mode (insert mode with overtype enabled).
//0	 Move to start of current line
//$	 Move to end of current line
//^	 Move to the start of indentation on current line.
//w	 Moves to the start of the next word
//b	 Moves (back) to the start of the current (or previous) word.
//e	 Moves to the end of the current (or next) word.
//WBE Similar to wbe commands, but words are separated by white space, so ABC+X(Y) is considered a single word.
//[	 (Editra only) Moves back one word part
// ]	 (Editra only) Move one word part forward
//{	 Goto start of current (or previous) paragraph
//}	 Goto end of current (or next) paragraph
//~	 Toggle case of character(s) under caret and move caret across them.
//u	 Undo (repeatable).
//U	 Redo (repeatable).
//rb	 Replace character under caret with b
//x	 Delete character under caret
//X	 Delete character before caret (backspace)
//ma	 Bookmark the current position and give it label a
//`a	 Goto position bookmarked with label a
//'a	 Goto line bookmarked with label a
//H	 Goto first visible line
//M	 Goto the middle of the screen
//L	 Goto last visible line
//zt	 Scroll view so current line becomes the first line
//zz	 Scroll view so current line is in the middle
//zb	 Scroll view so current line is at the bottom (last line)
//G	 Goto last line, or line number (eg 12G goes to line 12)
//gg	 Goto first line in file
//fx	 Find char x on current line and go to it
//tx	 Similar to fx, but stops one character short before x
//Fx	 Similar to fx, but searches backwards
//Tx	 Similar to tx, but searches backwards
//;	 Repeat last find motion
//,	 Repeat last find motion, but in reverse
//*	 Find next occurance of identifier under caret or currently selected text
//#	 Similar to * but backwards
//|	 Jump to column (specified by the repeat parameter).
//J	 Join this line with the one(s) under it.
//p	 Paste text, if copied text is whole lines, pastes below current line.
//P	 Paste text, if copied text is whole lines, pastes above current line.
//y	 Yank (copy). See below for more.
//d	 Delete. (also yanks)
//c	 Change: deletes (and yanks) then enters insert mode.
//>	 Indent
//<	 Un-Indent
//.	 Repeat last change/insert command (doesn't repeat motions or other things).
//Y	 Yank from current position to the end of line
//D	 Delete from current position to the end of line
//C	 Change from current position to the end of line
//s	 Substitute: deletes character under caret and enter insert mode.
//S	 Change current line (substitute line)
-(void) processKey:(NSString*) key For:(XVimController*) controller
{
    XTextViewBridge* bridge  = [controller bridge];
    NSTextView* hijackedView = [bridge targetView];
}
@end

@implementation XVimVisualModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller{}
@end

@implementation XVimExModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller{}
@end
