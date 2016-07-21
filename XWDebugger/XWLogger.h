//
//  XWLogger.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/21.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>
@class XWLogInfo;

@protocol XWLogger <NSObject>

- (void)log:(XWLogInfo *)info;

@end
