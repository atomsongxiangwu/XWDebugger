//
//  XWSocketClient.h
//  XWDebugger
//
//  Created by songxiangwu on 2016/7/18.
//  Copyright © 2016年 atom. All rights reserved.
//

#import <Foundation/Foundation.h>
@class XWSocketClient;

@protocol XWSocketClientDelegate <NSObject>

- (void)socketClient:(XWSocketClient *)client didConnectToHost:(NSString *)host port:(uint16_t)port;
- (void)socketClientDidDisconnect:(XWSocketClient *)client withError:(NSError *)error;
- (void)socketClient:(XWSocketClient *)client didWriteData:(NSData *)data;
- (void)socketClient:(XWSocketClient *)client didReadData:(NSData *)data;

@end

@interface XWSocketClient : NSObject

@property (nonatomic, weak) id<XWSocketClientDelegate> delegate;

- (void)connectToHost:(NSString *)host port:(uint16_t)port;
- (void)disconnect;
- (void)writeData:(NSData *)data;
- (BOOL)isConnect;

@end
