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

- (IBAction)driveToggle:(id)sender;
- (IBAction)turnToggle:(id)sender;

@end
