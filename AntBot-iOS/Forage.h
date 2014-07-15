//
//  Forage.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import <Foundation/Foundation.h>
#import "Utilities.h"

@class Forage, ImageRecognition, RouterCable, RouterServer;

// ForageState protocol
@protocol ForageState
@property Forage* forage;
@optional
- (void)enter:(id<ForageState>)previous;
- (void)leave:(id<ForageState>)next;

- (void)driveDone;
- (void)turnDone;
- (void)localizeDone;
- (void)compass:(float)heading;
- (void)ultrasound:(float)distance;
- (void)pheromone;
- (void)tag:(int)code;
- (void)alignInfo:(CGPoint)offset;
@end

// Forage States
@interface ForageStateDeparting : NSObject <ForageState> @end
@interface ForageStateSearching : NSObject <ForageState> {
    int searchTime;
}
@end
@interface ForageStateNeighbors : NSObject <ForageState> {
    int turns;
    int tags;
}
@end
@interface ForageStateReturning : NSObject <ForageState> @end

// Informed Enum
typedef NS_ENUM(NSInteger, RobotInformedStatus) {
    RobotInformedStatusNone,
    RobotInformedStatusMemory,
    RobotInformedStatusPheromone
};

// Forage "Controller"
@interface Forage : NSObject {
    NSDate* startTime;
}

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server;
- (double)microseconds;
- (void)localize;
- (void)drive:(float)distance;
- (void)turn:(float)degrees;
- (void)driveTo:(Cartesian)position;
- (void)turnTo:(float)heading;
- (float)dTheta:(int)searchTime;
- (Cartesian)destination;

// State data
@property Cartesian position;
@property float heading;
@property RobotInformedStatus informedStatus;
@property int tag;
@property Cartesian lastTagLocation;
@property Cartesian pheromone;
@property BOOL localizing;

// Behavior parameters
@property float fenceRadius;
@property float searchStepSize;
@property float travelGiveUpProbability;
@property float uninformedSearchCorrelation;
@property float informedSearchCorrelationDecayRate;

@property ImageRecognition* imageRecognition;
@property RouterCable* cable;
@property RouterServer* server;

@property (nonatomic) id<ForageState, NSObject> state;
@property ForageStateDeparting* departing;
@property ForageStateSearching* searching;
@property ForageStateNeighbors* neighbors;
@property ForageStateReturning* returning;

@end