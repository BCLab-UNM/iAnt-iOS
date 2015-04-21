#import "Router.h"

@implementation Router

@synthesize delegate;

- (void) parseString:(NSString*)string withDelimiter:(NSString*)delimiter {
    if(!string || [string length] == 0){return;}
    
    // Strip any beginning null characters.
    int nullCount = 0;
    while(nullCount < [string length] && [string characterAtIndex:nullCount++] == 0);
    if(nullCount > 1) {
        string = [string substringFromIndex:nullCount - 1];
    }
    
    // Append string to buffer.
    if(!rxBuffer){rxBuffer = @"";}
    rxBuffer = [rxBuffer stringByAppendingString:string];
    
    // Process all delimiter-terminated messages.
    NSRange range;
    while((range = [rxBuffer rangeOfString:delimiter]).location != NSNotFound) {
        
        // Remove complete message from buffer and split it by commas.
        NSArray* components = [[rxBuffer substringToIndex:range.location] componentsSeparatedByString:@","];
        rxBuffer = [rxBuffer substringFromIndex:range.location + [delimiter length]];
        
        // The first component is the message title, the rest are the data.
        NSString* message = [components objectAtIndex:0];
        
        NSArray* data;
        if([components count] > 1) {
            data = [components subarrayWithRange:NSMakeRange(1, [components count] - 1)];
        }
        else {
            data = [[NSArray alloc] init];
        }
        
        // Notify the delegate about the received message.
        if(delegate) {
            if([delegate respondsToSelector:@selector(receiveMessage:body:)]) {
                [delegate receiveMessage:message body:data];
            }
        }
        
        // Fire registered handlers for the received message.
        if([handlers objectForKey:message]) {
            void (^handler)(NSArray*);
            for(handler in [handlers objectForKey:message]) {
                handler(data);
            }
        }
    }
}

- (void)send:(NSString *)message, ... {}

- (void)handle:(NSString*)message callback:(void (^)(NSArray*))callback {
    if(!handlers){handlers = [[NSMutableDictionary alloc] init];}
    if([handlers objectForKey:message]) {
        [[handlers objectForKey:message] addObject:callback];
    }
    else {
        [handlers setObject:[NSMutableArray arrayWithObject:callback] forKey:message];
    }
}

@end
