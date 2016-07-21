//
//  XWTerminalLogger.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWTerminalLogger.h"
#import "XWSocketClient.h"
#import "XWLogInfo.h"
#import "XWBasicDataUtility.h"
#import <pthread.h>

@interface XWTerminalLogger () <XWSocketClientDelegate>

{
    dispatch_semaphore_t _semaphore;
}

@property (nonatomic, strong) XWSocketClient *socketClient;
@property (nonatomic, strong) NSMutableArray *sendArr;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

@end

@implementation XWTerminalLogger

- (instancetype)init {
    self = [super init];
    if (self) {
        _sendArr = [[NSMutableArray alloc] init];
        _semaphore = dispatch_semaphore_create(1);
        _socketClient = [[XWSocketClient alloc] init];
        _socketClient.delegate = self;
    }
    return self;
}

- (void)configWithHost:(NSString *)host port:(uint16_t)port {
    _host = [host copy];
    _port = port;
}

- (void)log:(XWLogInfo *)info {
    //timestamp appName[proccessID:threadID] content
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    NSString *showStr = [NSString stringWithFormat:@"%@ %@[%@:%llu] %@", timestamp, info.appName, info.proccessID, tid, info.content];
    NSDictionary *dict = @{@"level":@(info.level),@"content":showStr, @"type":@"log"};
    NSError *err;
    NSMutableData *data = [[NSMutableData alloc] init];
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&err];
    NSData *lenData = [XWBasicDataUtility encodeInt:(unsigned int)bodyData.length];
    [data appendData:lenData];
    [data appendData:bodyData];
    if (!err) {
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        [_sendArr addObject:data];
        dispatch_semaphore_signal(_semaphore);
        if ([_socketClient isConnect]) {
            [self _dequeueSendArr];
        } else {
            NSInteger cnt;
            dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
            cnt = _sendArr.count;
            dispatch_semaphore_signal(_semaphore);
            if (cnt == 1) {
                [_socketClient connectToHost:_host port:_port];
            }
        }
    }
}

- (void)_dequeueSendArr {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSData *data = [_sendArr firstObject];
    if (data) {
        [_sendArr removeObjectAtIndex:0];
        [_socketClient writeData:data];
    }
    dispatch_semaphore_signal(_semaphore);
}

- (void)_clearSendArr {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [_sendArr removeAllObjects];
    dispatch_semaphore_signal(_semaphore);
}

- (void)socketClient:(XWSocketClient *)client didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self _dequeueSendArr];
}

- (void)socketClientDidDisconnect:(XWSocketClient *)client withError:(NSError *)error {
    [self _clearSendArr];
}

- (void)socketClient:(XWSocketClient *)client didReadData:(NSData *)data {
    //    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    //    NSLog(@"%@", dict);
    [self _dequeueSendArr];
}

- (void)socketClient:(XWSocketClient *)client didWriteData:(NSData *)data {
    
}

@end
