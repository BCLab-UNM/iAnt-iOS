//
//  Forage.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RobotStatus) {
    RobotStatusInactive,
    RobotStatusDeparting,
    RobotStatusSearching,
    RobotStatusReturning
};

@class RouterCable;
@class ImageRecognition;

@interface Forage : NSObject {
    RouterCable* cable;
    ImageRecognition* imageRecognition;
}

- (void)setup:(RouterCable*)cable;

@property (nonatomic) RobotStatus status;

@end
