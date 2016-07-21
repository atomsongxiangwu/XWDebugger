//
//  XWTerminalLogger.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XWLogger.h"

@interface XWTerminalLogger : NSObject <XWLogger>

- (void)configWithHost:(NSString *)host port:(uint16_t)port;

@end
