//
//  XWUploadPackakge.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^XWUploadProgressBlock)(NSInteger finishedSize, NSInteger totalSize);
typedef void(^XWUploadSuccessBlock)();
typedef void(^XWUploadFailBlock)(NSInteger code, NSString *msg);

@interface XWUploadPackakge : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) NSInteger currentUploadingSize;
@property (nonatomic, assign) NSInteger totalSize;
@property (nonatomic, assign) NSInteger finishedSize;
@property (nonatomic, copy) XWUploadProgressBlock progressBlock;
@property (nonatomic, copy) XWUploadSuccessBlock successBlock;
@property (nonatomic, copy) XWUploadFailBlock failBlock;

- (instancetype)initWithFilePath:(NSString *)filePath progressBlock:(XWUploadProgressBlock)progressBlock successBlock:(XWUploadSuccessBlock)successBlock failBlock:(XWUploadFailBlock)failBlock;
- (void)increaseFinishedSize;
- (BOOL)isEnd;

@end
