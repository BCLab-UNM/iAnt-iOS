//
//  CableManager.m
//  AntBot
//
//  Created by Joshua Hecker on 6/19/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import "CableManager.h"

@implementation CableManager

@synthesize rxBuffer;

+ (id)cableManager
{
    static CableManager* cblMgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{cblMgr = [[self alloc] init];});
    return cblMgr;
}

- (void)send:(NSString*)message
{
    NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [self write:(UInt8*)[data bytes] Length:[data length]];
}

- (void)receive:(int)numBytes
{
    //If needed, intialize buffer
    if (rxBuffer == nil) rxBuffer = [NSMutableArray new];
    
    //Load numBytes of data into buffer
    uint8_t buffer[1024];
    [self read:buffer Length:numBytes];
    
    //Convert raw bytes into string
    NSString *data = [[NSString alloc] initWithBytes:buffer length:numBytes encoding:NSUTF8StringEncoding];
    
    //Split string around occurances of delimiter
    NSString *delimiter = @"\r\n";
    NSMutableArray *messages = [[data componentsSeparatedByString:delimiter] mutableCopy];
    
    //If there were messages received
    if (([messages count] > 0)
        //and there are messages remaining in the buffer
        && ([rxBuffer count] > 0)
        //and the final message in the buffer is not the empty string
        && (![[rxBuffer lastObject] isEqualToString:@""]))
    {
        //Then the final message must be incomplete, so we concatenate it with the first message in the new array,
        //then we remove both message fragments
        NSString *concatenatedMessage = [[rxBuffer lastObject] stringByAppendingString:[messages objectAtIndex:0]];
        [rxBuffer removeLastObject];
        [messages removeObjectAtIndex:0];
        
        //Split string around occurances of delimiter
        NSMutableArray *splitMessage = [[concatenatedMessage componentsSeparatedByString:delimiter] mutableCopy];
        
        //Append 
        [rxBuffer addObjectsFromArray:splitMessage];
    }
    
    //Append new messages onto buffer
    [rxBuffer addObjectsFromArray:messages];
}

- (NSString*)getMessage
{
    //If there are at least 2 messages remaining in the buffer
    if ([rxBuffer count] > 1)
    {
        //Copy and remove the first message
        NSString *message = [rxBuffer objectAtIndex:0];
        [rxBuffer removeObjectAtIndex:0];
        
        //Then return it
        return message;
    }
    
    //If only one message is found in the buffer
    else if (([rxBuffer count] > 0)
             //and the final message in the buffer is the empty string
             && ([[rxBuffer lastObject] isEqualToString:@""])) {
        //Then we remove it
        [rxBuffer removeObjectAtIndex:0];
    }
    
    //Return nil for all other cases
    return nil;
}

@end