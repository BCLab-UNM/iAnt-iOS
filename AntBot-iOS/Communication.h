#import <GameKit/GameKit.h>

@interface Communication : NSObject <NSStreamDelegate, GKSessionDelegate> {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSString* host;
    int port;
    NSTimer* reconnectTimer;
    NSMutableArray* rxBuffer;
    NSMutableArray* txBuffer;
    GKSession* bluetoothSession;
}

- (void)connectTo:(NSString*)server onPort:(int)number;
- (void)closeConnection;

- (BOOL)send:(NSString*)message;
- (void)receive:(NSString*)message;
- (NSString*)getMessage;

- (NSString*) getMacAddress;

@property NSString* mocapHeading;
@property NSString* pheromoneLocation;
@property NSString* tagStatus;
@property NSString* evolvedParameters;

@end