//
//  RouterCable.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 5/30/14.
//
//

#import <Foundation/Foundation.h>
#import "Router.h"
#import "RscMgr.h"

@interface RouterCable : Router <RscMgrDelegate> {
    RscMgr* rscMgr;
}

@end
