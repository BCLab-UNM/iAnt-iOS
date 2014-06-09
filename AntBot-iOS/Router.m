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
    
    // Strip any beginning null characters.
    int nullCount = 0;
    while(nullCount < [string length] && [string characterAtIndex:nullCount++] == 0);
    if(nullCount > 1) {
        string = [string substringFromIndex:nullCount - 1];
    }
    
    // Append string to buffer.
    rxBuffer = [rxBuffer stringByAppendingString:string];
    
    // Process all delimiter-terminated messages.
    NSRange range;
    while((range = [rxBuffer rangeOfString:delimiter]).location != NSNotFound) {
        
        // Remove complete message from buffer and split it by commas.
        NSArray* components = [[rxBuffer substringToIndex:range.location] componentsSeparatedByString:@","];
        rxBuffer = [rxBuffer substringFromIndex:range.location + 1];
        
        // The first component is the message title, the rest are the data.
        NSString* message = [components objectAtIndex:0];
        NSArray* data = [components subarrayWithRange:NSMakeRange(1, [components count] - 1)];
        
        // Notify the delegate about the received message.
        if(delegate) {
            if([delegate respondsToSelector:@selector(receiveMessage:body:)]) {
                [delegate receiveMessage:message body:data];
            }
        }
        
        // Fire registered handlers for the received message.
        if([handlers objectForKey:message]) {
            void (^handler)(NSArray*) = [handlers objectForKey:message];
            handler(data);
        }
    }
}

- (void)send:(NSString *)message {}

- (void)handle:(NSString*)messageTag callback:(void (^)(NSArray*))callback {
    if(callback) {
        [handlers setObject:callback forKey:messageTag];
    }
}

@end
