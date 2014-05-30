//
//  Router.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import <Foundation/Foundation.h>

@interface Router : NSObject {
    NSMutableArray* rxBuffer;
    NSMutableDictionary* callbacks;
    NSMutableDictionary* handlers;
}

- (void)parseString:(NSString*)string withDelimiter:(NSString*)delimiter;
- (void)send:(NSString*)message;
- (void)send:(NSString*)message callback:(void (^)(void))callback;
- (void)handle:(NSString*)message callback:(void (^)(void))callback;

- (NSString*) getMessage;

@end
