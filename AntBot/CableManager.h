//
//  CableManager.h
//  AntBot
//
//  Created by Joshua Hecker on 6/19/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <Foundation/Foundation.h>
#import "RscMgr.h"

@interface CableManager : RscMgr

+ (id)cableManager;

//Communications
- (void)send:(NSString*)message;
- (void)receive:(int)numBytes;

//Buffer for incoming messages
@property NSMutableArray* rxBuffer;

//Returns next message in buffer
- (NSString*)getMessage;

@end
