#ifdef __LP64__
#import "XVimMode.h"
#import "XGlobal.h"
#import "XTextViewBridge.h"

@interface XVimExModeHandler ()

@property (retain) NSPopover* popover;

- (void)showPrompt:(VimMode)submode;
- (void)prompt:(NSTextField*)sender;
- (void)runExCommand:(NSString*)cmd;
- (NSRange)runSearchCommand:(NSString*)cmd backwards:(BOOL)backwards;

@end

@implementation XVimExModeHandler

@synthesize popover;
@synthesize lastSearch;
@synthesize lastSearchWasForwards;
@synthesize lastCommand;

-(void) enterWith:(VimMode)submode {
    [self showPrompt:submode];
}

- (void)repeatSearch:(BOOL)reverse {
    if ([self.lastSearch length])
        [self runSearchCommand:self.lastSearch backwards:self.lastSearchWasForwards != reverse];
}
- (void)repeatCommand {
    if ([self.lastCommand length])
        [self runExCommand:self.lastCommand];
}

- (void)runCommand:(NSString*)str {
    if ([str length] <= 1)
        return;
    
    NSString* sstr = [str substringWithRange:NSMakeRange(1, [str length] - 1)];
    if ([str hasPrefix:@":"]) {
        [self runExCommand:sstr];
        self.lastCommand = sstr;
    }
    else if ([str hasPrefix:@"/"]) {
        [self runSearchCommand:sstr backwards:NO];
        self.lastSearch = sstr;
        self.lastSearchWasForwards = NO;
    }
    else if ([str hasPrefix:@"?"]) {
        [self runSearchCommand:sstr backwards:YES];
        self.lastSearch = sstr;
        self.lastSearchWasForwards = YES;
    }
}
- (void)runExCommand:(NSString*)cmd {
    if ([cmd isEqual:@"q"] || [cmd isEqual:@"quit"])
        [NSApp terminate:self];
    else if ([cmd isEqual:@"w"] || [cmd isEqual:@"write"])
        [NSApp sendAction:@selector(saveDocument:) to:nil from:self];
    else if ([cmd isEqual:@"wq"]) {
        [NSApp sendAction:@selector(saveDocument:) to:nil from:self];
        [NSApp terminate:self];
    }
}
- (NSRange)runSearchCommand:(NSString*)cmd backwards:(BOOL)backwards {
    
    NSString* delim = backwards ? @"\\?" : @"/";
    NSString* extractregex = [NSString stringWithFormat:@"^(([^%1$@]|\\\\%1$@)+)(%1$@([a-zA-Z]+))?(%1$@)?$", delim];
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:extractregex options:0 error:&error];
    NSTextCheckingResult* m = [regex firstMatchInString:cmd options:0 range:NSMakeRange(0, [cmd length])];
    
    if (!m)
        return NSMakeRange(NSNotFound, 0);
    
    NSRange r1 = [m rangeAtIndex:1];
    NSRange r4 = [m rangeAtIndex:4];
    
    NSString* search = r1.length ? [cmd substringWithRange:r1] : nil;
    NSString* options = r4.length ? [cmd substringWithRange:r4] : nil;
    
    if (![search length])
        return NSMakeRange(NSNotFound, 0);
    
    
    // Replace \\ with XVIM_DOUBLE_BACKSLASH_STRING
    search = [search stringByReplacingOccurrencesOfString:@"\\\\" withString:@"XVIM_DOUBLE_BACKSLASH_STRING"];
    // Replace \ delim with delim
    search = [search stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\\%@", delim] withString:delim];
    // Replace XVIM_DOUBLE_BACKSLASH_STRING with two backslashes
    search = [search stringByReplacingOccurrencesOfString:@"XVIM_DOUBLE_BACKSLASH_STRING" withString:@"\\\\"];
        
    NSTextView* tv = [[controller bridge] targetView];

    // Are we in visual mode?
    NSInteger start = [tv selectedRange].location + 1;
    if ([controller mode] == VisualMode)
        start = [(XVimVisualModeHandler*)[controller currentHandler] selectionEnd] + 1;
    
    NSInteger len = [[[tv textStorage] string] length];
    
    NSRegularExpressionOptions opts = 0;
    if ([options rangeOfString:@"i"].length != 0)
        opts |= NSRegularExpressionCaseInsensitive;
    if ([options rangeOfString:@"x"].length != 0)
        opts |= NSRegularExpressionAllowCommentsAndWhitespace;
    if ([options rangeOfString:@"m"].length != 0)
        opts |= NSRegularExpressionAnchorsMatchLines;
    if ([options rangeOfString:@"s"].length != 0)
        opts |= NSRegularExpressionDotMatchesLineSeparators;
    
    regex = [NSRegularExpression regularExpressionWithPattern:search options:opts error:&error];
    
    NSRange searchRange;
    if (!backwards) {
        if (len - start <= 0)
            return NSMakeRange(NSNotFound, 0);
        
        searchRange = NSMakeRange(start, len - start);
        m = [regex firstMatchInString:[[tv textStorage] string] options:opts range:searchRange];
    }
    else {
        if (start - 1 <= 0)
            return NSMakeRange(NSNotFound, 0);
        
        searchRange = NSMakeRange(0, start - 1);
        m = [[regex matchesInString:[[tv textStorage] string] options:opts range:searchRange] lastObject];
    }
    
    
    if (!m || [m range].length == 0)
        return NSMakeRange(NSNotFound, 0);
    
    NSInteger newStart = [m range].location;
    if ([controller mode] == VisualMode)
        [(XVimVisualModeHandler*)[controller currentHandler] setNewSelectionEnd:newStart];
    else
        [tv setSelectedRange:NSMakeRange(newStart, 0)];
    
    return [m range];
}

- (void)showPrompt:(VimMode)submode {
    self.popover = [[[NSPopover alloc] init] autorelease];
    popover.behavior = NSPopoverBehaviorSemitransient;
    popover.animates = NO;
    popover.appearance = NSPopoverAppearanceMinimal;
    NSViewController* vc = [[[NSViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    
    CGFloat width = 350;
    CGFloat height = 22;
    CGFloat margin = 8;
    
    NSView* contentView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, width + margin * 2, height + margin * 2)] autorelease];
    NSTextField* textField = [[[NSTextField alloc] initWithFrame:NSMakeRect(margin, margin, width, height)] autorelease];
    [textField setTarget:self];
    [textField setAction:@selector(prompt:)];
    [textField setFont:[NSFont fontWithName:@"Monaco" size:11]];
    [textField setFocusRingType:NSFocusRingTypeNone];
    
    NSString* submodeString = @":";
    if (submode == SearchSubMode)
        submodeString = @"/";
    if (submode == BackwardsSearchSubMode)
        submodeString = @"?";
    [textField setStringValue:submodeString];
    
    [contentView addSubview:textField];
    [vc setView:contentView];
    popover.contentViewController = vc;
    
    NSTextView* tv = [[controller bridge] targetView];    
    NSString* string = [[tv textStorage] string];
    NSInteger start = [tv selectedRange].location;

    NSRect posRect = [[tv layoutManager] extraLineFragmentRect];
    posRect.size.width = 0;
    posRect.origin.y += [tv textContainerOrigin].y;
    
    if ([controller mode] == VisualMode) {
        start = [(XVimVisualModeHandler*)[controller currentHandler] selectionEnd];
    }
    
    if (start < [string length]) {
        
        NSUInteger glyphIndex = [[tv layoutManager] glyphIndexForCharacterAtIndex:start];
        posRect = [[tv layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:[tv textContainer]];

        unichar ch = [string characterAtIndex:start];
        if ((ch >= 0xA && ch <= 0xD) || ch == 0x85) {
            posRect.size.width = 0;
        }
    }
    
    [popover showRelativeToRect:posRect ofView:tv preferredEdge:NSMaxYEdge];
    [[textField currentEditor] moveRight:nil];
}
- (void)prompt:(NSTextField*)sender {
    
    [self runCommand:[sender stringValue]];
    [self.popover close];
    self.popover = nil;
}

@end
#endif