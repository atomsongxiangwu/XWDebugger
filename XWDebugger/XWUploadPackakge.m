//
//  XWUploadPackakge.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWUploadPackakge.h"

@implementation XWUploadPackakge

- (instancetype)initWithFilePath:(NSString *)filePath progressBlock:(XWUploadProgressBlock)progressBlock successBlock:(XWUploadSuccessBlock)successBlock failBlock:(XWUploadFailBlock)failBlock {
    self = [super init];
    if (self) {
        _filePath = [filePath copy];
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        _totalSize = [[attr objectForKey:NSFileSize] integerValue];
        _finishedSize = 0;
        _progressBlock = [progressBlock copy];
        _successBlock = [successBlock copy];
        _failBlock = [failBlock copy];
    }
    return self;
}

- (void)increaseFinishedSize {
    _finishedSize += _currentUploadingSize;
}

- (BOOL)isEnd {
    return _finishedSize == _totalSize;
}

@end
