//
//  XWSocketClient.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWSocketClient.h"
#import "XWBasicDataUtility.h"

static const NSInteger kDefaultReadLength = 1024;
static const uint32_t kHeaderLength = 4;

@interface XWSocketClient () <NSStreamDelegate>

{
    dispatch_queue_t _socketQueue;
    NSThread *_streamThread;
    void *IsOnSocketQueueOrTargetQueueKey;
}

@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, strong) NSMutableArray *sendBufferArray;
@property (nonatomic, strong) NSMutableData *receiveBuffer;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL hasRemainData;
@property (nonatomic, strong) NSMutableData *writtenData;
@property (nonatomic, strong) NSTimer *runloopTimer;

@end

@implementation XWSocketClient

@synthesize delegate = _delegate;

- (instancetype)init {
    self = [super init];
    if (self) {
        _socketQueue = dispatch_queue_create("XWSocketQueue", DISPATCH_QUEUE_SERIAL);
        void *nonNullUnusedPointer = (__bridge void *)self;
        dispatch_queue_set_specific(_socketQueue, IsOnSocketQueueOrTargetQueueKey, nonNullUnusedPointer, NULL);
    }
    return self;
}

#pragma mark - Public API

- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_block_t block = ^{
        _sendBufferArray = [[NSMutableArray alloc] init];
        _receiveBuffer = [[NSMutableData alloc] init];
        _readStream = nil;
        _writeStream = nil;
        _host = [host copy];
        _port = port;
        [self _createReadAndWriteStream];
        [self _scheduleReadAndWriteStream];
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_async(_socketQueue, block);
    }
}

- (void)writeData:(NSData *)data {
    dispatch_block_t block = ^{
        if (!_sendBufferArray.count) {
            NSInteger len = [_writeStream write:data.bytes maxLength:data.length];
            if (len < data.length) {
                _hasRemainData = YES;
                NSData *remainData = [data subdataWithRange:NSMakeRange(len, data.length - len)];
                _writtenData = [[NSMutableData alloc] initWithData:[data subdataWithRange:NSMakeRange(0, len)]];
                [_sendBufferArray addObject:remainData];
            } else {
                _hasRemainData = NO;
                _writtenData = nil;
                if (_delegate && [_delegate respondsToSelector:@selector(socketClient:didWriteData:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_delegate socketClient:self didWriteData:data];
                    });
                }
            }
        } else {
            [_sendBufferArray addObject:data];
        }
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_async(_socketQueue, block);
    }
}

- (void)disconnect {
    [self _disconnectWithError:nil];
}

- (BOOL)isConnect {
    __block BOOL isConnect;
    dispatch_block_t block = ^{
        isConnect = _isConnected;
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_sync(_socketQueue, block);
    }
    return isConnect;
}

#pragma mark - Private API

- (void)_disconnectWithError:(NSError *)error {
    dispatch_block_t block = ^{
        _isConnected = NO;
        [self _unscheduleReadAndWriteStream];
        _sendBufferArray = nil;
        _receiveBuffer = nil;
        if (_delegate && [_delegate respondsToSelector:@selector(socketClientDidDisconnect:withError:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate socketClientDidDisconnect:self withError:error];
            });
        }
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_async(_socketQueue, block);
    }
}

- (void)_createReadAndWriteStream {
    CFHostRef hostRef = CFHostCreateWithName(NULL, (__bridge CFStringRef)_host);
    CFReadStreamRef readStreamRef = NULL;
    CFWriteStreamRef writeStreamRef = NULL;
    if (hostRef) {
        CFStreamCreatePairWithSocketToCFHost(NULL, hostRef, (SInt32)_port, &readStreamRef, &writeStreamRef);
        CFRelease(hostRef);
    }
    _readStream = (__bridge NSInputStream *)readStreamRef;
    _readStream.delegate = self;
    _writeStream = (__bridge NSOutputStream *)writeStreamRef;
    _writeStream.delegate = self;
    if (!_readStream || !_writeStream) {
        if (_delegate && [_delegate respondsToSelector:@selector(socketClientDidDisconnect:withError:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate socketClientDidDisconnect:self withError:[self _errorWithMsg:@"Unable to create read and write stream..."]];
            });
        }
    }
}

- (void)_scheduleReadAndWriteStream {
    _streamThread = [[NSThread alloc] initWithTarget:self selector:@selector(_streamThread) object:nil];
    [_streamThread start];
    [self performSelector:@selector(_addStreamsToRunloop) onThread:_streamThread withObject:nil waitUntilDone:YES];
}

- (void)_unscheduleReadAndWriteStream {
    if (_streamThread) {
        [self performSelector:@selector(_removeStreamsFromRunloop) onThread:_streamThread withObject:nil waitUntilDone:YES];
        [_streamThread cancel];
        [self performSelector:@selector(_ignore) onThread:_streamThread withObject:nil waitUntilDone:YES];
        CFRunLoopStop(CFRunLoopGetCurrent());
        [_runloopTimer invalidate];
        _runloopTimer = nil;
        _streamThread = nil;
    }
}

- (void)_addStreamsToRunloop {
    [_readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_readStream open];
    [_writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_writeStream open];
}

- (void)_removeStreamsFromRunloop {
    NSRunLoop *currentRunloop = [NSRunLoop currentRunLoop];
    if (_readStream) {
        [_readStream close];
        [_readStream removeFromRunLoop:currentRunloop forMode:NSDefaultRunLoopMode];
        _readStream = nil;
    }
    if (_writeStream) {
        [_writeStream close];
        [_writeStream removeFromRunLoop:currentRunloop forMode:NSDefaultRunLoopMode];
        _writeStream = nil;
    }
}

- (void)_streamThread {
    _runloopTimer = [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow] target:self selector:@selector(_ignore) userInfo:nil repeats:YES];
    NSThread *currentThread = [NSThread currentThread];
    BOOL isCancelled = [currentThread isCancelled];
    while (!isCancelled) {
        CFRunLoopRun();
        isCancelled = [currentThread isCancelled];
    }
}

- (void)_ignore {
}

- (NSError *)_errorWithMsg:(NSString *)msg {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey:msg};
    return [NSError errorWithDomain:@"XWSocketClientError" code:-1 userInfo:userInfo];
}

#pragma mark - Handle Stream Event

- (void)_handleStreamEventOpenComplete:(NSStream *)stream {
    if ([stream isKindOfClass:[NSInputStream class]]) {
        dispatch_async(_socketQueue, ^{
            _isConnected = YES;
            if (_delegate && [_delegate respondsToSelector:@selector(socketClient:didConnectToHost:port:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate socketClient:self didConnectToHost:_host port:_port];
                });
            }
        });
    }
}

- (void)_handleStreamEventHasBytesAvailable:(NSStream *)stream {
    dispatch_async(_socketQueue, ^{
        uint8_t buf[kDefaultReadLength];
        NSInteger len = 0;
        len = [(NSInputStream *)stream read:buf maxLength:kDefaultReadLength];
        if (len > 0) {
            [_receiveBuffer appendBytes:(const void *)buf length:len];
        }
        while ((uint32_t)_receiveBuffer.length >= kHeaderLength) {
            uint32_t dataLen = [XWBasicDataUtility readInt:_receiveBuffer];
            if (dataLen + kHeaderLength > (uint32_t)_receiveBuffer.length) {
                break;
            }
            NSData *data = [_receiveBuffer subdataWithRange:NSMakeRange(kHeaderLength, dataLen)];
            if (_delegate && [_delegate respondsToSelector:@selector(socketClient:didReadData:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate socketClient:self didReadData:data];
                });
            }
            NSData *remainData = [_receiveBuffer subdataWithRange:NSMakeRange(kHeaderLength + dataLen, (uint32_t)_receiveBuffer.length - kHeaderLength - dataLen)];
            _receiveBuffer.data = remainData;
        }
    });
}

- (void)_handleStreamEventHasSpaceAvailable:(NSStream *)stream {
    dispatch_async(_socketQueue, ^{
        if (!_sendBufferArray.count) {
            _hasRemainData = NO;
            return ;
        }
        NSData *firstData = [_sendBufferArray objectAtIndex:0];
        NSInteger len = [_writeStream write:firstData.bytes maxLength:firstData.length];
        [_sendBufferArray removeObjectAtIndex:0];
        if (len < firstData.length) {
            _hasRemainData = YES;
            NSData *remainData = [firstData subdataWithRange:NSMakeRange(len, firstData.length - len)];
            if (!_writtenData) {
                _writtenData = [[NSMutableData alloc] initWithData:[firstData subdataWithRange:NSMakeRange(0, len)]];
            } else {
                [_writtenData appendData:[firstData subdataWithRange:NSMakeRange(0, len)]];
            }
            [_sendBufferArray insertObject:remainData atIndex:0];
        } else {
            _hasRemainData = NO;
            NSData *paramData;
            if (!_writtenData) {
                paramData = firstData;
            } else {
                [_writtenData appendData:firstData];
                paramData = [_writtenData copy];
            }
            if (_delegate && [_delegate respondsToSelector:@selector(socketClient:didWriteData:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate socketClient:self didWriteData:paramData];
                });
            }
        }
    });
}

- (void)_handleStreamEventErrorOccurred:(NSStream *)stream {
    [self _disconnectWithError:[stream streamError]];
}

- (void)_handleStreamEventEndEncountered:(NSStream *)stream {
    [self _disconnectWithError:[stream streamError]];
}

#pragma mark - NSStreamaDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventNone: //0
            break;
        case NSStreamEventOpenCompleted: //1
            [self _handleStreamEventOpenComplete:aStream];
            break;
        case NSStreamEventHasBytesAvailable: //2
            [self _handleStreamEventHasBytesAvailable:aStream];
            break;
        case NSStreamEventHasSpaceAvailable: //4
            [self _handleStreamEventHasSpaceAvailable:aStream];
            break;
        case NSStreamEventErrorOccurred: //8
            [self _handleStreamEventErrorOccurred:aStream];
            break;
        case NSStreamEventEndEncountered: //16
            [self _handleStreamEventEndEncountered:aStream];
            break;
        default:
            break;
    }
}

- (void)setDelegate:(id<XWSocketClientDelegate>)delegate {
    dispatch_block_t block = ^{
        _delegate = delegate;
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_sync(_socketQueue, block);
    }
}

- (id<XWSocketClientDelegate>)delegate {
    __block id<XWSocketClientDelegate> delegate;
    dispatch_block_t block = ^{
        delegate = _delegate;
    };
    if (dispatch_get_specific(IsOnSocketQueueOrTargetQueueKey)) {
        block();
    } else {
        dispatch_sync(_socketQueue, block);
    }
    return delegate;
}

@end
