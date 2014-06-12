//
//  RouterServer.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import "Router.h"

@interface RouterServer : Router <NSStreamDelegate, GKSessionDelegate> {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSMutableArray* txBuffer;
    GKSession* bluetoothSession;
}

- (id)init;
- (id)initWithIP:(NSString*)ip port:(int)port;
- (void)connectTo:(NSString*)server onPort:(int)number;
- (void)closeConnection;

@end
