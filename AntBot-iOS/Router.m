//
//  Router.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import "Router.h"

@implementation Router

- (void) parseString:(NSString*)string withDelimiter:(NSString*)delimiter {
    
    //Split string around occurances of delimiter
    NSMutableArray *messages = [[string componentsSeparatedByString:delimiter] mutableCopy];
    
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

- (NSString*)getMessage {
    
    //If there are at least 2 messages remaining in the buffer
    if ([rxBuffer count] > 1) {
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

- (void)send:(NSString *)message {}

- (void)send:(NSString *)message callback:(void (^)(void))callback {
    if (callback) {
        [callbacks setObject:callback forKey:message];
    }
    
    [self send:message];
}

- (void)handle:(NSString*)message callback:(void (^)(void))callback {
    if (callback) {
        [handlers setObject:callback forKey:message];
    }
}

@end
