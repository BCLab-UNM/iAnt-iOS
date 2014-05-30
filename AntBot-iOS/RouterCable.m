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
        rscMgr = [rscMgr init];
        [rscMgr setDelegate:self];
    }
    
    return self;
}

- (void)send:(NSString *)message {
    NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [rscMgr write:(UInt8*)[data bytes] Length:[data length]];
}

- (void)readBytesAvailable:(UInt32)length {
    uint8_t buffer[1024];
    [rscMgr read:buffer Length:length];
    
    // Convert raw bytes into string
    NSString *string = [[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
    
    // Call superclass method to tokenize string.
    [self parseString:string withDelimiter:@"\r\n"];
}

- (void)cableConnected:(NSString *)protocol {}
- (void)cableDisconnected {}
- (void)portStatusChanged {}

@end
