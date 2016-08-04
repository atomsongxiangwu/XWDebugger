//
//  XWDebugger.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>

#define XWLogDefine(target, lvl, frmt, ...)          \
        [[XWDebugger sharedInstance]                 \
                    log : target                     \
                  level : lvl                        \
                 format : (frmt), ##__VA_ARGS__]

#define XWLogCheck(target, lvl, frmt, ...) do { XWLogDefine(target, lvl, frmt, ##__VA_ARGS__); } while(0)
#define XWLogError(target, frmt, ...) XWLogCheck(target, XWLogLevelError, frmt, ##__VA_ARGS__)
#define XWLogInfo(target, frmt, ...) XWLogCheck(target, XWLogLevelInfo, frmt, ##__VA_ARGS__)

typedef NS_ENUM(NSUInteger, XWLogLevel) {
    XWLogLevelError,
    XWLogLevelInfo,
};

typedef NS_ENUM(NSUInteger, XWLogTarget) {
    XWLogTargetConsole,
    XWLogTargetTerminal,
    XWLogTargetAll,
};

@interface XWDebugger : NSObject

+ (instancetype)sharedInstance;
- (void)enableDebugger;
- (void)enableDebuggerWithHost:(NSString *)host port:(uint16_t)port;
- (void)disableDebugger;
- (void)clearHostAndPort;
- (void)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger finishedSize, NSInteger totalSize))progress success:(void (^)())success fail:(void (^)(NSInteger code, NSString *msg))fail;
- (void)log:(XWLogTarget)target level:(XWLogLevel)level format:(NSString *)format, ... NS_FORMAT_FUNCTION(3, 4);

@end
