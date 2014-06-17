//
//  Forage.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import <Foundation/Foundation.h>

@class Forage, ImageRecognition, RouterCable, RouterServer;

// ForageState protocol
@protocol ForageState
@property Forage* forage;
@optional
- (void)enter:(id<ForageState>)previous;
- (void)leave:(id<ForageState>)next;

- (void)driveDone;
- (void)alignDone;
- (void)localizeDone;
- (void)compass:(float)heading;
- (void)ultrasound:(float)distance;
- (void)pheromone;
- (void)tag:(int)code;
- (void)alignInfo:(CGPoint)offset;
@end

// ForageStateDeparting
@interface ForageStateDeparting : NSObject <ForageState>
@end

// ForageStateSearching
@interface ForageStateSearching : NSObject <ForageState>
- (void)turn;
@end

// ForageStateNeighbors
@interface ForageStateNeighbors : NSObject <ForageState> {
    int turns;
    int tags;
}
- (void)turn;
@end

// ForageStateReturning
@interface ForageStateReturning : NSObject <ForageState>
@end

// Forage "Controller"
@interface Forage : NSObject {
    NSDate* startTime;
}

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server;
- (double)microseconds;
- (void)localize;

@property CGPoint position;
@property float heading;
@property int tag;
@property CGPoint pheromone;
@property BOOL localizing;

@property ImageRecognition* imageRecognition;
@property RouterCable* cable;
@property RouterServer* server;

@property (nonatomic) id<ForageState, NSObject> state;
@property ForageStateDeparting* departing;
@property ForageStateSearching* searching;
@property ForageStateNeighbors* neighbors;
@property ForageStateReturning* returning;

@end