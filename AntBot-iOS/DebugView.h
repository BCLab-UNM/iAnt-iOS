//
//  DebugView.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 8/19/14.
//
//

#import <UIKit/UIKit.h>

@class Forage;

@interface DebugView : UIView <UITableViewDataSource, UITableViewDelegate>

@property id delegate;
@property Forage* forage;
@property IBOutlet UITableView* table;
@property IBOutlet UISwitch* driveSwitch;
@property IBOutlet UISwitch* turnSwitch;
@property NSArray* labels;
@property NSMutableDictionary* data;

@end
