//
//  XWConsoleLogger.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWConsoleLogger.h"
#import "XWLogInfo.h"

@implementation XWConsoleLogger

- (void)log:(XWLogInfo *)info {
    NSLog(@"%@", info.content);
}

@end
