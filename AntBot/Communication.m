//
//  Communication.m
//  AntBot-iOS
//
//  Created by Joshua Hecker on 4/18/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import "Communication.h"
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

const NSString* sessionID = @"Colony";

@implementation Communication

@synthesize rxBuffer;

- (id)init {
    if (self = [super init]) {
        bluetoothSession = [[GKSession alloc] initWithSessionID:@"Colony" displayName:nil sessionMode:GKSessionModePeer];
        [bluetoothSession setDelegate:self];
        [bluetoothSession setAvailable:YES];
    }
    
    return self;
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
    rxBuffer = [[NSString alloc] init];
    
    //Keep track of the host and the port so we can reconnect to it if needed
    host=server;
    port=number;
    
    //Initialize txBuffer, where we put messages to send later if we aren't connected
    if (txBuffer == nil) {
        txBuffer = [[NSMutableArray alloc] init];
    }
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

- (BOOL)send:(NSString*)message {
    //Ensure output stream is open
    if ([outputStream streamStatus] == NSStreamStatusOpen) {
        while ([txBuffer count] > 0) {
            NSString* str = [txBuffer objectAtIndex:0];
            [txBuffer removeObjectAtIndex:0];
            [self send:str];
        }
        NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSASCIIStringEncoding]];
        [outputStream write:[data bytes] maxLength:[data length]];
        return YES;
    }
    else {
        if (txBuffer != nil) {
           [txBuffer addObject:message]; 
        }
    }
    return NO;
}

- (void)receive:(NSString *)message {
    rxBuffer = message;
}

- (void)reconnect:(id)object {
    [self closeConnection];
    [self connectTo:host onPort:port];
    NSLog(@"Attempting to reconnect...");
}

- (NSString*)getMacAddress {
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = nil;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0) {
        errorFlag = @"if_nametoindex failure";
    }
    else
    {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0) {
            errorFlag = @"sysctl mgmtInfoBase failure";
        }
        else {
            // Alloc memory based on above call
            if ((msgBuffer = malloc(length)) == NULL) {
                errorFlag = @"buffer allocation failure";
            }
            else {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0) {
                    errorFlag = @"sysctl msgBuffer failure";
                }
            }
        }
    }
    
    // Befor going any further...
    if (errorFlag != nil) {
        free(msgBuffer);
        NSLog(@"Error: %@", errorFlag);
        return errorFlag;
    }
    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5]];
    
    // Release the buffer memory
    free(msgBuffer);
    
    return macAddressString;
}


#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    switch (streamEvent) {
		case NSStreamEventOpenCompleted:
			NSLog(@"Stream opened");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream opened" object:self];
            
            //If we managed to successfully connect, stop the reconnect timer.
            [reconnectTimer invalidate];
            reconnectTimer = nil;
            
			break;
            
        //If remote host has sent data, read everything into a buffer
		case NSStreamEventHasBytesAvailable:
            if (theStream == inputStream) {
                uint8_t buffer[1024];
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        NSString *data = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        
                        if (data != nil) {
                            NSLog(@"server said: %@", data);
                            [self receive:data];
                        }
                    }
                }
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"Server has space available for writing");
            break;
            
		case NSStreamEventErrorOccurred:
            /*
             * Attempt to handle known errors.
             * If it is an unknown/unhandled error, just print it out raw.
             * todo: Handle "connection reset" case, clean up this part (lots of repeated code here)
             */
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream closed" object:self];
            
            if([[NSString stringWithFormat:@"%@",[theStream streamError]] rangeOfString:@"Connection refused"].location != NSNotFound) {
                if(reconnectTimer == nil) {
                    NSLog(@"Connecting to server failed.");
                    reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5.f target:self selector:@selector(reconnect:) userInfo:nil repeats:YES];
                    [reconnectTimer fire];
                }
            }
            else if([[NSString stringWithFormat:@"%@",[theStream streamError]] rangeOfString:@"Broken pipe"].location != NSNotFound) {
                if(reconnectTimer == nil) {
                    NSLog(@"Connection to server closed.");
                    reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:4.f target:self selector:@selector(reconnect:) userInfo:nil repeats:YES];
                    [reconnectTimer fire];
                }
            }
            else if([[NSString stringWithFormat:@"%@",[theStream streamError]] rangeOfString:@"No route to host"].location != NSNotFound) {
                if(reconnectTimer == nil) {
                    NSLog(@"No route to host.");
                    reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:3.f target:self selector:@selector(reconnect:) userInfo:nil repeats:YES];
                    [reconnectTimer fire];
                }
            }
            else if([[NSString stringWithFormat:@"%@",[theStream streamError]] rangeOfString:@"Connection reset"].location != NSNotFound) {
                if(reconnectTimer == nil) {
                    NSLog(@"Connection to server reset.");
                    reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:2.5f target:self selector:@selector(reconnect:) userInfo:nil repeats:YES];
                    [reconnectTimer fire];
                }
            }
            else {
                NSLog(@"Error: %@",[[theStream streamError] localizedDescription]);
            }
			break;
            
        //If remote host closes the connection, close stream on this end and remove from schedule
		case NSStreamEventEndEncountered:
            NSLog(@"Connection to server closed");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Stream closed" object:self];
            
			break;
            
		default:
			NSLog(@"No event");
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