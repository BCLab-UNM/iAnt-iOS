//
//  Forage.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import <Foundation/Foundation.h>
#import "Camera.h"
#import "Utilities.h"

static const Cartesian NullPoint = Cartesian(INFINITY, INFINITY);

@class Forage, RouterCable, RouterServer, FiducialPipeline, LocalizationPipeline, DebugView;

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
@interface ForageStateDeparting : NSObject <ForageState> {
    Polar path;
}
@end
@interface ForageStateSearching : NSObject <ForageState> {
    int searchTime;
}
@end
@interface ForageStateNeighbors : NSObject <ForageState> {
    int turns;
}
@end
@interface ForageStateReturning : NSObject <ForageState> {
    Polar path;
}
@end

// Informed Enum
typedef NS_ENUM(NSInteger, RobotInformedStatus) {
    RobotInformedStatusNone,
    RobotInformedStatusMemory,
    RobotInformedStatusPheromone
};

// Forage "Controller"
@interface Forage : NSObject<CameraPipelineDelegate> {
    NSDate* startTime;
}

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server camera:(Camera*)camera;
- (unsigned)microseconds;
- (void)serverSend:(NSArray*)event;
- (void)localize;
- (void)drive:(float)distance;
- (void)turn:(float)degrees;
- (void)turnTo:(float)trajectory;
- (void)delay:(float)seconds;
- (float)dTheta:(int)searchTime;
- (Cartesian)nextDestination;

// State data
@property Cartesian position;
@property float heading;
@property RobotInformedStatus informedStatus;
@property int tag;
@property Cartesian lastTagLocation;
@property Cartesian pheromone;
@property BOOL localizing;
@property BOOL nestCentered;

// Physical Constraints
@property float fenceRadius;
@property float searchStepSize;
@property float nestRadius;
@property float robotRadius;
@property float collisionDistance;
@property float usMaxRange;

// Behavior Parameters
@property float travelGiveUpProbability;
@property float searchGiveUpProbability;

// Random Walk Parameters
@property float uninformedSearchCorrelation;
@property float informedSearchCorrelationDecayRate;

// Information Parameters
@property float pheromoneDecayRate;
@property float pheromoneLayingRate;
@property float siteFidelityRate;

// Image Recognition Pipelines
@property FiducialPipeline* fiducialPipeline;
@property LocalizationPipeline* localizationPipeline;

// Debug Data
@property BOOL driveEnabled;
@property BOOL turnEnabled;

@property RouterCable* cable;
@property RouterServer* server;
@property Camera* camera;
@property DebugView* debug;

@property (nonatomic) id<ForageState, NSObject> state;
@property ForageStateDeparting* departing;
@property ForageStateSearching* searching;
@property ForageStateNeighbors* neighbors;
@property ForageStateReturning* returning;

@property NSMutableSet* distinctTags;

@end