//
//  XWLogInfo.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/21.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XWDebugger.h"

@interface XWLogInfo : NSObject

@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) XWLogLevel level;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *proccessID;

- (instancetype)initWithContent:(NSString *)content level:(XWLogLevel)level appName:(NSString *)appName proccessID:(NSString *)proccessID;

@end
