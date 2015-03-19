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

@class Forage, ImageRecognition, RouterCable, RouterServer, FiducialPipeline, DebugView;

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
    int tags;
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
- (void)delay:(float)seconds;
- (float)dTheta:(int)searchTime;
- (Cartesian)nextDestination;

// State data
@property Cartesian position;
@property float heading;
@property RobotInformedStatus informedStatus;
@property int tag;
@property int lastNeighbors;
@property Cartesian lastTagLocation;
@property Cartesian pheromone;
@property BOOL localizing;

// Behavior Parameters
@property float fenceRadius;
@property float searchStepSize;
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

// Debug Data
@property BOOL driveEnabled;
@property BOOL turnEnabled;

@property ImageRecognition* imageRecognition;
@property RouterCable* cable;
@property RouterServer* server;
@property Camera* camera;
@property DebugView* debug;

@property (nonatomic) id<ForageState, NSObject> state;
@property ForageStateDeparting* departing;
@property ForageStateSearching* searching;
@property ForageStateNeighbors* neighbors;
@property ForageStateReturning* returning;

@property NSMutableDictionary* distinctTags;

@end