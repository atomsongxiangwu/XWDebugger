# XWDebugger介绍
* 代替你的NSLog，能将log输出到Mac终端上。
* 你可以将App内的任何资源（bundle或是沙盒）上传到你的Mac电脑桌面上。

# 使用方法
####第一步：
在终端上输入

```
python xw_debug_server.py
```
####第二步：
用终端上显示的ip地址和端口来开启SDK

```objc
[[XWDebugger sharedInstance] enableDebuggerWithHost:@"192.168.1.18" port:9999];
```
####第三步：
#####上传文件：

```objc
[[XWDebugger sharedInstance] uploadFile:file.path progress:^(NSInteger finishedSize, NSInteger totalSize) {
    progress = (CGFloat)finishedSize / totalSize * 100;
} success:^{
} fail:^(NSInteger code, NSString *msg) {
}];
```
#####输出日志：
输出日志方式

```objc
typedef NS_ENUM(NSUInteger, XWLogTarget) {
    XWLogTargetConsole, //控制台
    XWLogTargetTerminal, //终端
    XWLogTargetAll, //全部
};
```
你可以选择将输出不同类型的日志，XWLogError在终端上显示为红色，XWLogInfo在终端上显示为绿色

```
XWLogError(XWLogTargetAll, @"小伍哥");
XWLogInfo(XWLogTargetAll, @"小伍哥");
```
#####建议
由于此framework是通过TCP连接来传送数据的，所以会影响你的App性能，建议在使用时加一个调试开关来控制。

# 编写初衷
1.由于App在上线时会用宏把所有的NSLog都替换掉，因此如果线上出现什么问题，无法通过查看log来调试。2.当数据显示异常时无法通过查看线上app的数据库文件来确定问题，貌似现在的一些工具都不能够查看线上App的数据库文件了。