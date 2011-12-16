//
//  Created by Morris on 11-12-16.
//  Copyright (c) 2011年 http://warwithinme.com . All rights reserved.
//

#import <Foundation/Foundation.h>

@class XVimController;

@interface XVimModeHandler : NSObject
-(void) reset;
-(void) processKey:(NSString*)key For:(XVimController*)controller;
@end

@interface XVimNormalModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end

@interface XVimInsertModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end

@interface XVimVisualModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end

@interface XVimExModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end

@interface XVimReplaceModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end

@interface XVimSReplaceModeHandler : XVimModeHandler
-(void) processKey:(NSString *)key For:(XVimController *)controller;
@end