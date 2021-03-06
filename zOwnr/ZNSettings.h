//
//  ZNSettings.h
//  zOwnr
//
//  Created by Stuart Watkins on 25/07/12.
//  Copyright (c) 2012 Cytrasoft Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"
#import "ZNObjectLoader.h"
#import "Zone.h"

@protocol ZNSettingsDelegate <NSObject>

//

- (void)setCurrentSelection:(id<ZNSelectable>)currentSelection;

@end

@interface ZNSettings : NSObject <ZNObjectLoaderDelegate> {
    ZNObjectLoader *selectionLoader;
}

+ (ZNSettings*)shared;

@property (nonatomic, retain) id<ZNSettingsDelegate> delegate;

@property (nonatomic, retain) User *currentUser;
@property (nonatomic, retain) NSString *currentSession;
@property (nonatomic, retain) id<ZNSelectable> currentSelection;
@property (nonatomic, retain) Zone *currentZone;

- (BOOL)isCurrentUser;
- (BOOL)isLoggedIn;
- (NSDictionary*)requestHeaders;

- (void)updateCurrentZoneFromTime:(NSDate*)fromTime toTime:(NSDate*)toTime;
- (void)updateCurrentZoneFromPointNW:(CLLocationCoordinate2D)pointNW toPoint:(CLLocationCoordinate2D)pointSE;

//- (void)updateCurrentZone:(CLLocationCoordinate2D)pointNW pointSE:(CLLocationCoordinate2D)pointSE fromTime:(NSDate*)fromTime toTime:(NSDate*)toTime;

@end
