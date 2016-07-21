//
//  XWBasicDataUtility.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XWBasicDataUtility : NSObject

+ (uint32_t)readInt:(NSData *)data;
+ (NSData *)encodeInt:(unsigned int)value;

@end
