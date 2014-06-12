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

@class ImageRecognition, RouterCable, RouterServer;

@interface Forage : NSObject {
    RouterCable* cable;
    RouterServer* server;
    ImageRecognition* imageRecognition;
}

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server;
- (void)setup;

@property (nonatomic) RobotStatus status;
@property int lastTag;

@end
