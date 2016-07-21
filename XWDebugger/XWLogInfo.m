//
//  XWLogInfo.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/21.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWLogInfo.h"

@implementation XWLogInfo

- (instancetype)initWithContent:(NSString *)content level:(XWLogLevel)level appName:(NSString *)appName proccessID:(NSString *)proccessID {
    self = [super init];
    if (self) {
        _content = [content copy];
        _level = level;
        _appName = [appName copy];
        _proccessID = [proccessID copy];
    }
    return self;
}

@end
