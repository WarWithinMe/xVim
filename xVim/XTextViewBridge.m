//
//  XTextViewB.m
//  xVim
//
//  Created by Morris on 12-2-28.
//  Copyright (c) 2012年 http://warwithinme.com . All rights reserved.
//

#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "XVimController.h"
#import "XVimMode.h"

@interface XCmdlineTextField()
{
    NSString* title;
}
@property (assign) BOOL canIHaveFocus;
@property (assign) id<XCmdlineDelegate> anotherDelegate;

@end

@implementation XCmdlineTextField
@synthesize canIHaveFocus;
@synthesize anotherDelegate;

-(id) initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setDelegate:self];
    }
    return self;
}

-(BOOL) acceptsFirstResponder { return self.canIHaveFocus; }
-(void) mouseDown:(NSEvent*) theEvent { if (self.canIHaveFocus) { [super mouseDown:theEvent]; } }
-(void) dealloc  { DLog(@"Deallocing XCmdlineTextField: %@", self); }
-(void) finalize { DLog(@"XCmdlineTextField Finalized"); }

-(void) setFocus:(id<XCmdlineDelegate>)delegate withText:(NSString *)str
{
    [super setStringValue:str];
    DLog(@"StringValue: %@", [self stringValue]);
    self.canIHaveFocus = YES;
    [self selectText:self];
	[[self currentEditor] setSelectedRange:NSMakeRange([[self stringValue] length], 0)];
    
    self.anotherDelegate = delegate;
}

-(void) focusRemoved 
{ 
    self.canIHaveFocus = NO;
    self.anotherDelegate = nil;
}
-(BOOL) hasFocus     { return self.canIHaveFocus; }

-(BOOL) control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:))
    {
        DLog(@"InsertNewline");
        [anotherDelegate cmdlineAccepted:[self stringValue]];
        [self setStringValue:@""];
        self.canIHaveFocus = NO;
        return YES;
    }
    return NO;
}

-(void) controlTextDidEndEditing:(NSNotification*)aNotification
{
    DLog(@"ControlTextDidEndEditing");
    if (self.canIHaveFocus)
    {
        // If code reach here, it means user clicks outside of the cmdline.
        // or pressing esc. This action is consider quitting ex mode.
        [self setStringValue:@""];
        [anotherDelegate cmdlineCanceled];
        self.canIHaveFocus = NO;
    }
}

- (void)controlTextDidChange:(NSNotification*)obj
{
    NSTextView* field  = [[obj userInfo] objectForKey:@"NSFieldEditor"];
    NSString*   string = [field string];
    
    DLog(@"ControlTextDidChang: %@", string);
    
    if ([string length] == 0) {
        [anotherDelegate cmdlineCanceled];
    } else {
        [anotherDelegate cmdlineTextDidChange:string];
    }
}

- (void) setTitle:(NSString*) t 
{
    [title release];
    title = [t retain];
    [super setStringValue:t];
}
- (void) setStringValue:(NSString*) aString
{
    [super setStringValue:[NSString stringWithFormat:@"%@%@", title, aString]];
}
@end


// ========== XTextViewBridge ==========
@interface XTextViewBridge()
{
@private
    XVimController*     controller;
    __weak NSTextView*  targetView;
}
@end

@implementation XTextViewBridge
@synthesize cmdline;

-(void) setCmdline:(XCmdlineTextField *)c
{
    cmdline = c;
    [cmdline setTitle:[[controller currentHandler] name]];
}

-(NSTextView*)     targetView    { return targetView; }
-(XVimController*) vimController { return controller; }

-(XTextViewBridge*) initWithTextView:(NSTextView*) view
{
    if (self = [super init]) {
        targetView = view; // Must assigned this before creating the XVimController.
        controller = [[XVimController alloc] initWithBridge:self];
    }
    return self;
}

-(void) dealloc  
{ 
    DLog(@"Deallocing XTexViewBridge: %@", self); 
    [controller release]; 
    [cmdline release];
}
-(void) finalize { DLog(@"XTextViewBridge Finalized"); [super finalize]; }
-(void) processKeyEvent:(NSEvent*)event { [controller processKeyEvent:event]; }
-(BOOL) closePopup { return NO; }

-(void) handleFakeKeyEvent:(NSEvent*) fakeEvent {
    
    // Give them a chance to cooperate with us
    if ([self->targetView respondsToSelector:@selector(handleVimKeyEvent:)]) {
        [self->targetView performSelector:@selector(handleVimKeyEvent:) withObject:fakeEvent];
    }
    // Pleading the 5th? Hit 'em with the swizzle stick. 
    else if (orig_keyDown) {
        orig_keyDown(self->targetView, @selector(keyDown:), fakeEvent);
    }
}

-(BOOL) ignoreString:(NSString*) string selection:(NSRange) range
{
    // In Xcode, the user can select a token which is generated by the editor
    // The selection will be a char an it's 0xFFFC
    return range.length == 1 && [string characterAtIndex:range.location] == 0xFFFC;
}
@end