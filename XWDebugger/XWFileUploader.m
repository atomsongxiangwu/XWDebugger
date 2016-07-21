//
//  XWFileUploader.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWFileUploader.h"
#import "XWSocketClient.h"
#import "XWUploadPackakge.h"
#import "XWBasicDataUtility.h"

static const NSInteger kDefaultReadLength = 1024;
static const NSInteger kDefaultConnectTimeout = 5;
static const NSInteger kDefaultRequestTimeout = 5;

@interface XWFileUploader () <NSStreamDelegate, XWSocketClientDelegate>

{
    dispatch_semaphore_t _sem;
    dispatch_queue_t _fileQueue;
}

@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) NSMutableArray *requestArray;
@property (nonatomic, strong) XWSocketClient *socketClient;
@property (nonatomic, strong) NSFileHandle *handle;

@end

@implementation XWFileUploader

- (instancetype)init {
    self = [super init];
    if (self) {
        _sem = dispatch_semaphore_create(1);
        _fileQueue = dispatch_queue_create("XWFileUploaderQueue", DISPATCH_QUEUE_SERIAL);
        _requestArray = [[NSMutableArray alloc] init];
        _socketClient = [[XWSocketClient alloc] init];
        _socketClient.delegate = self;
    }
    return self;
}

#pragma mark - Public Method

- (void)configWithHost:(NSString *)host port:(uint16_t)port {
    _host = [host copy];
    _port = port;
}

- (void)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger finishedSize, NSInteger totalSize))progress success:(void (^)())success fail:(void (^)(NSInteger code, NSString *msg))fail {
    XWUploadPackakge *package = [[XWUploadPackakge alloc] initWithFilePath:filePath progressBlock:progress successBlock:success failBlock:fail];
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    [_requestArray addObject:package];
    dispatch_semaphore_signal(_sem);
    if (![_socketClient isConnect]) {
        [_socketClient connectToHost:_host port:_port];
    } else {
        [self _writeDataFromFileToSocket];
    }
}

#pragma mark - Private Method

- (void)_clearRequestArray {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    [_requestArray removeAllObjects];
    dispatch_semaphore_signal(_sem);
}

- (void)_writeDataFromFileToSocket {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    XWUploadPackakge *package = [_requestArray firstObject];
    dispatch_semaphore_signal(_sem);
    if (!package) {
        return;
    }
    dispatch_async(_fileQueue, ^{
        if (!_handle) {
            _handle = [NSFileHandle fileHandleForReadingAtPath:package.filePath];
        }
        [_handle seekToFileOffset:package.finishedSize];
        NSInteger size = MIN(kDefaultReadLength, package.totalSize - package.finishedSize);
        NSData *fileData = [_handle readDataOfLength:size];
        NSString *fileStr = [[NSString alloc] initWithData:[fileData base64EncodedDataWithOptions:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding];
        package.currentUploadingSize = size;
        NSInteger status;
        if (package.finishedSize == 0) {
            status = 1;
        }
        if (package.finishedSize + size == package.totalSize) {
            status = 2;
        }
        NSMutableData *data = [[NSMutableData alloc] init];
        NSDictionary *dict = @{@"path":[package.filePath lastPathComponent], @"data":fileStr, @"status":@(status), @"type":@"upload"};
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
        NSData *lenData = [XWBasicDataUtility encodeInt:(unsigned int)bodyData.length];
        [data appendData:lenData];
        [data appendData:bodyData];
        [_socketClient writeData:data];
    });
}


#pragma mark - XWSocketClientDelegate

- (void)socketClient:(XWSocketClient *)client didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self _writeDataFromFileToSocket];
}

- (void)socketClientDidDisconnect:(XWSocketClient *)client withError:(NSError *)error {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    [_requestArray enumerateObjectsUsingBlock:^(XWUploadPackakge *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.failBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    obj.failBlock(error.code, error.description);
                }
            });
        }
    }];
    [_requestArray removeAllObjects];
    dispatch_semaphore_signal(_sem);
}

- (void)socketClient:(XWSocketClient *)client didReadData:(NSData *)data {
//    [self _clearRequestTimer];
    BOOL isEnd = NO;
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    XWUploadPackakge *package = [_requestArray firstObject];
    [package increaseFinishedSize];
    if (package.progressBlock) {
        package.progressBlock(package.finishedSize, package.totalSize);
    }
    if ([package isEnd]) {
        isEnd = YES;
        package.successBlock();
        [_requestArray removeObjectAtIndex:0];
        dispatch_async(_fileQueue, ^{
            [_handle closeFile];
            _handle = nil;
        });
    }
    dispatch_semaphore_signal(_sem);
    if (!isEnd) {
        [self _writeDataFromFileToSocket];
    }
}

- (void)socketClient:(XWSocketClient *)client didWriteData:(NSData *)data {
}

@end
