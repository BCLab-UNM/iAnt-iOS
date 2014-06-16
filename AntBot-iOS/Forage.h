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

- (void)ready;
- (void)driveFinished;
- (void)alignFinished;
- (void)getUltrasound:(NSArray*)data;
- (void)pheromone:(NSArray*)data;
- (void)tag:(int)code;
- (void)alignInfo:(NSValue*)info;
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
@interface Forage : NSObject

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server;

@property int tag;
@property CGPoint pheromone;
@property ImageRecognition* imageRecognition;
@property RouterCable* cable;
@property RouterServer* server;

@property (nonatomic) id<ForageState, NSObject> state;
@property ForageStateDeparting* departing;
@property ForageStateSearching* searching;
@property ForageStateNeighbors* neighbors;
@property ForageStateReturning* returning;

@end