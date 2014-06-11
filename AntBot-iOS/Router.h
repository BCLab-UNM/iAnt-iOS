//
//  Router.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import <Foundation/Foundation.h>

@interface NSObject(RouterReceiveHandler)
- (void)receiveMessage:(NSString*)message body:(NSArray*)data;
@end

@interface Router : NSObject {
    NSString* rxBuffer;
    NSMutableDictionary* handlers;
    id delegate;
}

- (void)parseString:(NSString*)string withDelimiter:(NSString*)delimiter;
- (void)send:(NSString*)message, ...;
- (void)handle:(NSString*)message callback:(void (^)(NSArray*))callback;

@end
