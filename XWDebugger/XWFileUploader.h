//
//  XWFileUploader.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XWFileUploader : NSObject

- (void)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger finishedSize, NSInteger totalSize))progress success:(void (^)())success fail:(void (^)(NSInteger code, NSString *msg))fail;
- (void)configWithHost:(NSString *)host port:(uint16_t)port;

@end
