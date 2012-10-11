//
//  Communication.h
//  AntBot-iOS
//
//  Created by Joshua Hecker on 4/18/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <GameKit/GameKit.h>

@interface Communication : NSObject <NSStreamDelegate, GKSessionDelegate> {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSString* host;
    int port;
    NSTimer* reconnectTimer;
    NSMutableArray* txBuffer;
    GKSession* bluetoothSession;
}

- (void)connectTo:(NSString*)server onPort:(int)number;
- (void)closeConnection;

- (BOOL)send:(NSString*)message;
- (void)receive:(NSString*)message;

- (NSString*) getMacAddress;

@property NSString* rxBuffer;

@end
