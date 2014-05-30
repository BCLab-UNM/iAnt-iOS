//
//  RouterServer.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import "RouterServer.h"

const NSString* sessionID = @"Colony";
const int MAX_RX_BUFFER_SIZE = 100;

@implementation RouterServer

@synthesize mocapHeading, pheromoneLocation, tagStatus, evolvedParameters;

- (id)init {
    if (self = [super init]) {
        bluetoothSession = [[GKSession alloc] initWithSessionID:@"Colony" displayName:nil sessionMode:GKSessionModePeer];
        [bluetoothSession setDelegate:self];
        [bluetoothSession setAvailable:YES];
    }
    
    return self;
}

- (void)send:(NSString*)message {
    NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
}

- (void)parseString:(NSString *)string withDelimiter:(NSString *)delimiter {
    [super parseString:string withDelimiter:delimiter];
    
    NSString* msg = nil;
    while ((msg = [self getMessage]) != nil) {
        NSArray* splitMessage = [msg componentsSeparatedByString:@","];
        NSString* msgTag = [splitMessage objectAtIndex:0];
        NSString* msgInfo = [[splitMessage subarrayWithRange:NSMakeRange(1, [splitMessage count] - 1)] componentsJoinedByString:@","];
        
        if ([msgTag isEqualToString:@"heading"]) {
            [self setMocapHeading:msgInfo];
        }
        else if ([msgTag isEqualToString:@"tag"]) {
            [self setTagStatus:msgInfo];
        }
        else if ([msgTag isEqualToString:@"pheromone"]) {
            [self setPheromoneLocation:msgInfo];
        }
        else if ([msgTag isEqualToString:@"parameters"]) {
            [self setEvolvedParameters:msgInfo];
        }
    }
}

- (void)connectTo:(NSString*)server onPort:(int)number {
    //Ensure lower level BSD streams are closed whenever the connection is closed
    //CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    //CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    
    //Inititate socket connection with remote host
    CFStreamCreatePairWithSocketToHost(NULL,(__bridge CFStringRef)server,number,&readStream,&writeStream);
    
    //Cast CF streams to NS streams
    inputStream = (__bridge NSInputStream*)readStream;
    outputStream = (__bridge NSOutputStream*)writeStream;
    
    //Assign delegates
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    //Schedule streams to ensure notification of new messages
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    //Open connections
    [inputStream open];
    [outputStream open];
    
    //Initialize buffer
    rxBuffer = [[NSMutableArray alloc] init];
}

- (void)closeConnection {
    //Close NS streams
    [inputStream close];
    [outputStream close];
    
    //Remove NS streams from run loops
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    //Release CF streams
    CFRelease(readStream);
    CFRelease(writeStream);
}


#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    switch (streamEvent) {
		case NSStreamEventOpenCompleted:
			NSLog(@"Stream opened");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream opened" object:self];
			break;
        
        case NSStreamEventErrorOccurred:
            NSLog(@"Error: %@", [[theStream streamError] localizedDescription]);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream closed" object:self];
			break;
            
        //If remote host closes the connection, close stream on this end and remove from schedule
		case NSStreamEventEndEncountered:
            NSLog(@"Connection to server closed");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream closed" object:self];
			break;
            
        //If remote host has sent data, read everything into a buffer
		case NSStreamEventHasBytesAvailable:
            if (theStream == inputStream) {
                uint8_t buffer[1024];
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        NSString *string = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        if (string) {
                            [self parseString:string withDelimiter:@"\n"];
                        }
                    }
                }
            }
            break;
        
        case NSStreamEventHasSpaceAvailable: case NSStreamEventNone:
            break;
	}
}


#pragma mark - GKSessionDelegate methods

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state {
    if ([session sessionID] == sessionID) {
        switch (state) {
            case GKPeerStateAvailable:
                [session connectToPeer:peerID withTimeout:1.f];
                break;
            case GKPeerStateUnavailable:
                [session disconnectPeerFromAllPeers:peerID];
                break;
                
            default:
                break;
        }
    }
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID {
    if ([session sessionID] == sessionID) {
        NSError* message = nil;
        if (![session acceptConnectionFromPeer:peerID error:&message]) {
            NSLog(@"%@",[message localizedDescription]);
        }
    }
    else {
        [session denyConnectionFromPeer:peerID];
    }
}

@end
