//
//  XWBasicDataUtility.m
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import "XWBasicDataUtility.h"

@implementation XWBasicDataUtility

+ (uint32_t)readInt:(NSData *)data {
    uint8_t *bytes = (uint8_t *)[data bytes];
    uint32_t v1 = (unsigned int)bytes[0];
    uint32_t v2 = (unsigned int)bytes[1];
    uint32_t v3 = (unsigned int)bytes[2];
    uint32_t v4 = (unsigned int)bytes[3];
    uint32_t value = v1 + (v2 << 8) + (v3 << 16) + (v4 << 24);
    return value;
}

+ (NSData *)encodeInt:(unsigned int)value {
    uint8_t bytes[4] = {0};
    bytes[0] = value & 0xff;
    bytes[1] = (value >> 8) & 0xff;
    bytes[2] = (value >> 16) & 0xff;
    bytes[3] = (value >> 24) & 0xff;
    NSData *data = [NSData dataWithBytes:bytes length:4];
    return data;
}

@end
