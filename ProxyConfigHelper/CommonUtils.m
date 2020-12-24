//
//  CommonUtils.m
//  ClashX
//
//  Created by yicheng on 2020/4/2.
//  Copyright © 2020 west2online. All rights reserved.
//

#import "CommonUtils.h"

@implementation CommonUtils
+ (NSString *)runCommand:(NSString *)path args:(nullable NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:path];
    [task setArguments:args];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    [task launch];

    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
#if DEBUG
    NSLog(@"%@",output);
#endif
    return output;
}
@end
