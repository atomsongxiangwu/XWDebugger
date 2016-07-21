//
//  XWDebugger.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWDebugger.h"
#import "XWFileUploader.h"
#import "XWTerminalLogger.h"
#import "XWConsoleLogger.h"
#import "XWLogInfo.h"

@interface XWDebugger ()

{
    dispatch_queue_t _debugQueue;
}

@property (nonatomic, assign) BOOL enableDebugger;
@property (nonatomic, strong) XWFileUploader *fileUploader;
@property (nonatomic, strong) XWTerminalLogger *terminalLogger;
@property (nonatomic, strong) XWConsoleLogger *consoleLogger;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *proccessID;

@end

@implementation XWDebugger

#pragma mark - Life Cycle

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static XWDebugger *instance;
    dispatch_once(&onceToken, ^{
        instance = [[XWDebugger alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _appName = [[NSProcessInfo processInfo] processName];
        _proccessID = [NSString stringWithFormat:@"%i", (int)getpid()];
        _debugQueue = dispatch_queue_create("XWDebugQueue", DISPATCH_QUEUE_SERIAL);
        _fileUploader = [[XWFileUploader alloc] init];
        _terminalLogger = [[XWTerminalLogger alloc] init];
        _consoleLogger = [[XWConsoleLogger alloc] init];
    }
    return self;
}

#pragma mark - Public Method

- (void)enableDebuggerWithHost:(NSString *)host port:(uint16_t)port {
    dispatch_sync(_debugQueue, ^{
        _enableDebugger = YES;
        [_fileUploader configWithHost:host port:port];
        [_terminalLogger configWithHost:host port:port];
    });
}

- (void)disableDebugger {
    dispatch_sync(_debugQueue, ^{
        _enableDebugger = NO;
    });
}

- (void)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger finishedSize, NSInteger totalSize))progress success:(void (^)())success fail:(void (^)(NSInteger code, NSString *msg))fail {
    dispatch_async(_debugQueue, ^{
        if (_enableDebugger) {
            [_fileUploader uploadFile:filePath progress:progress success:success fail:fail];
        }
    });
}

- (void)log:(XWLogTarget)target level:(XWLogLevel)level format:(NSString *)format, ... {
    va_list args;
    if (format) {
        va_start(args, format);
        NSString *content = [[NSString alloc] initWithFormat:format arguments:args];
        [self _log:target level:level content:content];
        va_end(args);
    }
}

#pragma mark - Private API

- (void)_log:(XWLogTarget)target level:(XWLogLevel)level content:(NSString *)content {
    dispatch_sync(_debugQueue, ^{ @autoreleasepool {
        if (_enableDebugger) {
            XWLogInfo *info = [[XWLogInfo alloc] initWithContent:content level:level appName:_appName proccessID:_proccessID];
            switch (target) {
                case XWLogTargetConsole:
                {
                    [_consoleLogger log:info];
                }
                    break;
                case XWLogTargetTerminal:
                {
                    [_terminalLogger log:info];
                }
                    break;
                case XWLogTargetAll:
                {
                    [_consoleLogger log:info];
                    [_terminalLogger log:info];
                }
                    break;
            }
        }
    }});
}

@end
