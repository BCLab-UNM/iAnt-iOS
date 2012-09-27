//
//  Communication.h
//  AntBot
//
//  Created by Joshua Hecker on 4/18/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

@interface Communication : NSObject <NSStreamDelegate> {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSString* host;
    int port;
    NSTimer* reconnectTimer;
    NSMutableArray* txBuffer;
}

- (void)connectTo:(NSString*)server onPort:(int)number;
- (void)closeConnection;

- (BOOL)send:(NSString*)message;
- (void)receive:(NSString*)message;

- (NSString*) getMacAddress;

@property NSString* rxBuffer;

@end
