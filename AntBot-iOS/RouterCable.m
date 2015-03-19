//
//  RouterCable.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import "RouterCable.h"

@implementation RouterCable

- (id)init {
    if (self = [super init]) {
        rscMgr = [[RscMgr alloc] init];
        [rscMgr setDelegate:self];
    }
    
    return self;
}

- (void)send:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if(![message hasSuffix:@"\n"]) {
        message = [message stringByAppendingString:@"\n"];
    }
    NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [rscMgr write:(UInt8*)[data bytes] Length:(int)[data length]];
}

- (void)readBytesAvailable:(UInt32)length {
    uint8_t buffer[1024];
    [rscMgr read:buffer Length:length];
    
    // Convert raw bytes into string
    NSString *string = [[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
    
#ifdef DEBUG
    NSLog(@"%@", string);
#endif
    
    // Call superclass method to tokenize string.
    [self parseString:string withDelimiter:@"\r\n"];
}

- (void)cableConnected:(NSString *)protocol {
    [rscMgr setBaud:57600];
	[rscMgr open];
    [self send:@"ready"];
}

- (void)cableDisconnected {}
- (void)portStatusChanged {}

@end
