#include <arpa/inet.h>
#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#include "Utilities.h"
#import "Router.h"

@interface RouterServer : Router <NSStreamDelegate, GKSessionDelegate, NSNetServiceDelegate, NSNetServiceBrowserDelegate> {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSMutableArray* txBuffer;
    GKSession* bluetoothSession;
    NSNetService* remote;
    NSNetServiceBrowser* browser;
    BOOL isConnected;
}

- (id)init;
- (void)connectTo:(NSString*)server onPort:(int)number;
- (void)closeConnection;

@end
