//
//  ZNTimelineScrollView2.m
//  zOwnr
//
//  Created by Stuart Watkins on 27/07/12.
//  Copyright (c) 2012 Cytrasoft Pty Ltd. All rights reserved.
//

// min frame width is 240 or zooming between days, quarter days, half days, days wont work

#import "ZNTimelineScrollView.h"
#import "ZNMenuItem.h"
#import "ZNTimelineView.h"

@interface ZNTimelineScrollView() {
    
}

- (int)maxMarkersForFrameSize;
- (void)recenterIfNecessary;
- (CGSize)superFrameSize;
- (void)setMarkersToCurrentWidth;
- (void)setTimeLabels;
- (void)didSelectTimePeriod;
- (void)setupMarkersForCurrentPeriod;
- (void)fixMarkerWidth;
- (void)lockToClosest;
- (void)setZeroTimeForMarkers;

@end

@implementation ZNTimelineScrollView

@synthesize responseInsets;
@synthesize minTime = _minTime;
@synthesize maxTime = _maxTime;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;


- (id)initWithFrame:(CGRect)frame withDelegate:(id<ZNTimelineScrollDelegate>)del;
{
    self = [super initWithFrame:frame];
    if (self) {
        
        // delegates
        scrollDelegate = del;
        self.delegate = self;
        
        // ui
        self.clipsToBounds = YES;
        [self setDecelerationRate:UIScrollViewDecelerationRateFast];
        self.showsHorizontalScrollIndicator = NO;
        
        
        int m = [self maxMarkersForFrameSize];
        
        //NSLog(@"max markers int=%i", m);
        
//        currentMarkerWidth = kZNMinTimeMarkerSize;
//        currentMarkerMode = kZNTimelineMarkerModeDay;
        
        
        //self.contentSize = CGSizeMake(([self maxMarkersForFrameSize] + 2) * kZNMinTimeMarkerSize, self.frame.size.height);
        
        
        // pinch zooming
        isZooming = NO;
        pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
        [self addGestureRecognizer:pinchRecognizer];
        
        // labels
        rightStaticTime = [[UILabel alloc] initWithFrame:CGRectMake(minMarkerWidth + 5, 20, 180, 20)];
        [rightStaticTime setBackgroundColor:[UIColor clearColor]];
        rightStaticTime.font = [UIFont systemFontOfSize:10];
        rightStaticTime.alpha = 0.8f;
        [self addSubview:rightStaticTime];
        //[self insertSubview:rightStaticTime atIndex:-100];
        
        [self setMarkersToCurrentWidth];
        
        contentView = [[ZNTimelineContentView alloc] initWithFrame:CGRectMake(0, 0, 10, 10) delegate:self];
        [self addSubview:contentView];
        
        
        //[self didSelectTimePeriod];
    }
    return self;
}

#pragma mark ZNTimelineView

- (void)setCurrentObject:(id<ZNTimelineView>)object {
    
    NSLog(@"setting current timeline object to:%@", object);
    
    
    if ([object isEqual:currentObject] || ([currentObject startTime] == [object startTime] && [currentObject endTime] == [object endTime])) {
        // we're setting to the same object or timespan we're already handling
        NSLog(@"not adjusting the timeline cos we don't need to");
        return;
    }
    
    currentObject = object;
    
    
    [self setTimespanFrom:[object startTime] to:[object endTime]];
    
    [contentView setFrame:CGRectMake(contentView.frame.origin.x, contentView.frame.origin.y, contentView.frame.size.width, [[object rows] count] * kZNRowHeight)];
    
    [contentView setCurrentObject:object];
    
    
    
    self.contentSize = CGSizeMake(self.contentSize.width, contentView.frame.size.height + kMainEdgeViewHeight);
    
}

#pragma mark Time Setting

/// Start and end times set by external source
/// Called when first initialized, and when a new timeline compatible object is selected

- (void)setTimespanFrom:(NSDate*)fromTime to:(NSDate*)toTime {
    NSLog(@"setting timespan for timeline scroll");
    
    if (self.startTime == fromTime && self.endTime == toTime) {
        // no change
        return;
    }
    
    self.startTime = fromTime;
    self.endTime = toTime;
    [self setupMarkersForCurrentPeriod];
    [self didSelectTimePeriod];
}

/// Sets the start and end times based on the first and last markers currently shown

- (void)didSelectTimePeriod {
    NSLog(@"selecting time period based on first and last markers");
    
    // work out how many markers are showing
    int numShowing = lroundf(self.frame.size.width / currentMarkerWidth);
    numShowing = self.frame.size.width / currentMarkerWidth;
    
    NSLog(@"num markers = %i at width %f in frame width %f",numShowing, currentMarkerWidth, self.frame.size.width);
    
    ZNTimeMarkerView *startView = [timeMarkers objectAtIndex:1];
    ZNTimeMarkerView *endView = [timeMarkers objectAtIndex:numShowing + 1];
    
    
    self.startTime = startView.currentTime;
    self.endTime = endView.currentTime;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd HH:mm";
    df.timeZone = [NSTimeZone defaultTimeZone];
    
    NSLog(@"setting start time:%@ and end time:%@", [df stringFromDate:self.startTime], [df stringFromDate:self.endTime]);
    
    [scrollDelegate didScrollToTimespan:startView.currentTime toTime:endView.currentTime];
}

#pragma mark Layout Adjustments



- (void)setupMarkersForCurrentPeriod {
    
    NSLog(@"setting up markers for current period");
    
    // let's always start with days as a minimum display
    
    // get the days either side of the to and from dates
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd 00:00";

    
    // round to include the whole of start and finish days
    NSDate *fromDay = [df dateFromString:[df stringFromDate:self.startTime]];
    NSDate *toDay = [df dateFromString:[df stringFromDate:self.endTime]];
    toDay = [toDay dateByAddingTimeInterval:3600 * 24];
    
    // work out how many days this is once rounded
    NSTimeInterval totalDays = [toDay timeIntervalSinceDate:fromDay] / (3600 * 24);
    
    if (totalDays > maxMarkers) {
        // we have more days than we can show, just show the maximum
        // day mode
        currentMarkerMode = kZNTimelineMarkerModeDay;
        currentMarkerWidth = minMarkerWidth;
    } else {
        // work out the mode for this period
        if (totalDays <= maxMarkers / 2) {
            // we can fit it into half days
            currentMarkerMode = kZNTimelineMarkerModeHalfDay;
            currentMarkerWidth = self.frame.size.width / (totalDays * 2);
        } else {
            if (totalDays <= maxMarkers / 4) {
                // we can fit into quarter days
                currentMarkerMode = kZNTimelineMarkerModeQuarterDay;
                currentMarkerWidth = self.frame.size.width / (totalDays * 4);
            } else {
                // not small enough to show as quarter days
                // just use days instead
                currentMarkerMode = kZNTimelineMarkerModeDay;
                currentMarkerWidth = self.frame.size.width / totalDays;
            }
        }
    }
    
    [self fixMarkerWidth];
    
    currentZeroTime = fromDay;
    
    [self setZeroTimeForMarkers];
    
    [self setMarkersToCurrentWidth];
    
    [self lockToClosest];

}

- (void)fixMarkerWidth {
    
    NSLog(@"fixing marker width");
    
    // changes approximated marker width to one that will fit exactly in this frame
    
    int numShowing = lroundf(self.frame.size.width / currentMarkerWidth);
    numShowing = self.frame.size.width / currentMarkerWidth;
    
    currentMarkerWidth = self.frame.size.width / numShowing;
    
    // set the content size to contain number of markers showing + 1 on either side
    self.contentSize = CGSizeMake((numShowing + 2) * currentMarkerWidth, self.frame.size.height);
    
    // set the content view for rows to be the size of the markers including the one on either side
    [contentView setFrame:CGRectMake(0, 50, self.contentSize.width, self.frame.size.height - 50)];
    
    //NSLog(@"setting content width to:%f", (numShowing + 2) * currentMarkerWidth);
}

- (void)setZeroTimeForMarkers {
    
    NSLog(@"setting zero time for markers");
    
    // zero time is the time set for the 
    
    for (ZNTimeMarkerView *m in timeMarkers) {
        //[m setNewIndex:diffToApply];
        [m setNewZeroTime:currentZeroTime];
        //CGPoint center = [labelContainerView convertPoint:label.center toView:self];
        //            center.x += (centerOffsetX - currentOffset.x);
        //            label.center = [self convertPoint:center toView:labelContainerView];
    }
    
    [contentView updateLayout];
}

- (void)setMarkersToCurrentWidth {
    NSLog(@"setting markers to currentWidth");
    int i = 0;
    for (ZNTimeMarkerView *m in timeMarkers) {
        [m setFrame:CGRectMake(i * currentMarkerWidth, 0, currentMarkerWidth, 50)];
        [m setMarkerMode:currentMarkerMode];
        i++;
    }
    [timeMarkers makeObjectsPerformSelector:@selector(setNeedsDisplay)];
    
}

- (void)lockToClosest {
    
    NSLog(@"locking to closest marker");
    
    //    NSLog(@"content offset = %f with width %f", self.contentOffset.x, currentMarkerWidth);
    
    //    if (self.contentOffset.x < (currentMarkerWidth / 2)) {
    //        [self setContentOffset:CGPointMake(0, 0) animated:YES];
    //    } else {
    [self setContentOffset:CGPointMake(currentMarkerWidth, 0) animated:YES];
    //    }
    
    if (isUpdatingFromUserGesture) {
        isUpdatingFromUserGesture = NO;
        [self didSelectTimePeriod];
    }
    
}

- (void)setTimeLabels {
    
    [rightStaticTime setFrame:CGRectMake(self.contentOffset.x + 5, rightStaticTime.frame.origin.y, rightStaticTime.frame.size.width, rightStaticTime.frame.size.height)];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    switch (currentMarkerMode) {
        case kZNTimelineMarkerModeDay:
            df.dateFormat = @"MMMM yyyy";
            break;
            
        case kZNTimelineMarkerModeHalfDay:
            df.dateFormat = @"MMMM yyyy";
            break;
            
        case kZNTimelineMarkerModeQuarterDay:
            df.dateFormat = @"MMMM yyyy";
            break;
            
        case kZNTimelineMarkerModeHour:
            df.dateFormat = @"dd MMMM yyyy";
            break;
            
        default:
            break;
    }
    
    [rightStaticTime setText:[df stringFromDate:currentZeroTime]];
    
}

#pragma mark Frame Size Handling

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    //return;
    
    if (frame.size.height < kMainEdgeViewHeight || frame.size.width < kMainEdgeViewHeight) {
        return;
    }
    
    // need to reset everything cos our base size has changed
    
    // work out the minimum marker width
    maxMarkers = self.frame.size.width / kZNMinTimeMarkerSize;
    minMarkerWidth = self.frame.size.width / maxMarkers;

    if (timeMarkers) {
        [timeMarkers makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [timeMarkers removeAllObjects];
    } else {
        timeMarkers = [NSMutableArray array];
    }
    
    /*
    NSDate *zeroTime = [NSDate dateWithTimeIntervalSinceNow:0];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd";
    
    NSDate *dayZeroTime = [df dateFromString:[df stringFromDate:zeroTime]];
    currentZeroTime = dayZeroTime;
    */
    
    for (int i = 0; i < maxMarkers + 2; i++) {
        ZNTimeMarkerView *timeMarker = [[ZNTimeMarkerView alloc] initWithIndex:i];
        //ZNTimeMarkerView *timeMarker = [[ZNTimeMarkerView alloc] initWithFrame:CGRectMake(i * kZNMinTimeMarkerSize, 0, kZNMinTimeMarkerSize, 50) andIndex:i zeroTime:dayZeroTime];
        [timeMarker setMarkerMode:currentMarkerMode];
        [timeMarkers addObject:timeMarker];
        [self addSubview:timeMarker];
    }
    
    
    if (self.startTime && self.endTime) {
        [self setupMarkersForCurrentPeriod];
    }
    
    [self bringSubviewToFront:rightStaticTime];
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    //if (!self.isDecelerating) {
    if (!isZooming) {
        [self recenterIfNecessary];

    }
    
    [self setTimeLabels];
            //}
    
}

- (CGSize)superFrameSize {
    return CGSizeMake(self.frame.size.width + responseInsets.right, self.frame.size.height);
}

- (int)timeDiffForMarkerMode {
    
}

#pragma mark Scrolling

- (void)recenterIfNecessary {
    // how far is the visible screen from the left edge of the markers
    CGPoint currentOffset = [self contentOffset];
    // how wide is the current set of markers
    CGFloat contentWidth = [self contentSize].width;
    //NSLog(@"contentWidth is now:%f", contentWidth);
    
    // what is the x offset point if we are in the middle?
    CGFloat centerOffsetX = (contentWidth - [self bounds].size.width) / 2.0;
    // how far is the current content offset(ted) from the central point?
    CGFloat distanceFromCenter = fabs(currentOffset.x - centerOffsetX);
    
    
    //NSLog(@"dist from center = %f", distanceFromCenter);
    
    if (distanceFromCenter > currentMarkerWidth) {
        
        // we have gone too far one way or the other
        // move the scroll container back to the middle
        self.contentOffset = CGPointMake(centerOffsetX, currentOffset.y);
     
        //NSLog(@"setting offset to: %f", centerOffsetX);
        
        int diffToApply;
        
        NSDate *newZeroTime;
        
        int timeDiff = 0;
        
        switch (currentMarkerMode) {
            case kZNTimelineMarkerModeDay:
                timeDiff = (3600 * 24);
                break;
                
            case kZNTimelineMarkerModeHalfDay:
                timeDiff = (3600 * 12);
                break;
                
            case kZNTimelineMarkerModeQuarterDay:
                timeDiff = (3600 * 6);
                break;
                
            case kZNTimelineMarkerModeHour:
                timeDiff = 3600;
                break;
                
                            
            default:
                break;
        }
        
        if (currentOffset.x < centerOffsetX) {
            // we have scrolled right
            //NSLog(@"right");
            // shift all time markers to show one less than they are currently
            diffToApply = -1;
            
            newZeroTime = [currentZeroTime dateByAddingTimeInterval:timeDiff * -1];
            
        } else {
            //NSLog(@"left");
            // shift all time markers to show one more than they are currently
            diffToApply = 1;
            newZeroTime = [currentZeroTime dateByAddingTimeInterval:timeDiff];
        }
        
        currentZeroTime = newZeroTime;
        
        // move content by the same amount so it appears to stay still
        [self setZeroTimeForMarkers];
        
    }
     
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSLog(@"did end decelerating");
    isUpdatingFromUserGesture = YES;
    [self lockToClosest];
}



- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    NSLog(@"did end dragging");
    if (!decelerate) {
        isUpdatingFromUserGesture = YES;
        [self lockToClosest];
        //[self setContentOffset:CGPointMake(kZNMinTimeMarkerSize, 0) animated:YES];
    }
}


#pragma mark Zooming

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)sender {
    
    
    
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        initialPinchMarkerSize = currentMarkerWidth;
        initialPinchScaleFactor = 1.0f;
        isZooming = YES;
        //        [delegate startUpdatingSize];
    }
    //NSLog(@"pinched %f", sender.scale);
    
    float newMarkerWidth = initialPinchMarkerSize * sender.scale * sender.scale * initialPinchScaleFactor;
    
    if (newMarkerWidth < minMarkerWidth) {
        switch (currentMarkerMode) {
            case kZNTimelineMarkerModeHour:
                // move to quarter day
                currentMarkerMode = kZNTimelineMarkerModeQuarterDay;
                newMarkerWidth = newMarkerWidth * 6.0f;
                initialPinchScaleFactor = initialPinchScaleFactor * 6.0f;
                NSLog(@"changing from hour to quarter day");
                break;
                
            case kZNTimelineMarkerModeQuarterDay:
                // lets move from quarter day to half day mode
                
                currentMarkerMode = kZNTimelineMarkerModeHalfDay;
                newMarkerWidth = newMarkerWidth * 2.0f;
                initialPinchScaleFactor = initialPinchScaleFactor * 2.0f;
                NSLog(@"changing from quarter to half");
                break;
                
            case kZNTimelineMarkerModeHalfDay:
                // lets move from half to quarter
                
                currentMarkerMode = kZNTimelineMarkerModeDay;
                newMarkerWidth = newMarkerWidth * 2.0f;
                initialPinchScaleFactor = initialPinchScaleFactor * 2.0f;
                NSLog(@"changing from half to day");
                break;
                
            case kZNTimelineMarkerModeDay:
                // stay in day mode
                
                newMarkerWidth = minMarkerWidth;
                break;
                
            default:
                break;
        }
        
    } else {
        
        //if (newMarkerWidth > self.frame.size.width / 2) {
        
        switch (currentMarkerMode) {
                
            case kZNTimelineMarkerModeDay:
                // lets move from day to half day mode
                
                if (newMarkerWidth > minMarkerWidth * 2.0f) {
                    currentMarkerMode = kZNTimelineMarkerModeHalfDay;
                    newMarkerWidth = newMarkerWidth / 2.0f;
                    initialPinchScaleFactor = initialPinchScaleFactor / 2.0f;
                    NSLog(@"changing from day to half day");
                }
                
                
                break;
                
            case kZNTimelineMarkerModeHalfDay:
                // lets move from day to half day mode
                
                if (newMarkerWidth > minMarkerWidth * 2.0f) {
                    
                    currentMarkerMode = kZNTimelineMarkerModeQuarterDay;
                    newMarkerWidth = newMarkerWidth / 2.0f;
                    initialPinchScaleFactor = initialPinchScaleFactor / 2.0f;
                    NSLog(@"changing from half to quarter day");
                }
                break;
                
            case kZNTimelineMarkerModeQuarterDay:
                // lets move from day to half day mode
                
                if (newMarkerWidth > minMarkerWidth * 6.0f) {
                    
                    currentMarkerMode = kZNTimelineMarkerModeHour;
                    newMarkerWidth = newMarkerWidth / 6.0f;
                    initialPinchScaleFactor = initialPinchScaleFactor / 6.0f;
                    NSLog(@"changing from quarter to hour");
                }
                break;
                
            case kZNTimelineMarkerModeHour:
                // this is the biggest we can get
                
                if (newMarkerWidth > self.frame.size.width / 2.0f) {
                    newMarkerWidth = self.frame.size.width / 2.0f;
                    //initialPinchScaleFactor = initialPinchScaleFactor / 2.0f;
                }
                
                
                break;
                
            default:
                break;
        }
        
        //newMarkerWidth = self.frame.size.width / 2;
    }
    
    currentMarkerWidth = newMarkerWidth;
    
    self.contentSize = CGSizeMake([timeMarkers count] * currentMarkerWidth, self.frame.size.height);
    
    
    [self setMarkersToCurrentWidth];
    
    [contentView updateLayout];
    
    /*
     if (newSize < 480) {
     newSize = 480;
     }
     
     if (newSize > 6000) {
     newSize = 6000;
     }
     */
    
    /*   
     float tempPPH = newSize / totalHours;
     
     if (tempPPH < kTLMinMarkerWidth / 24.0) {
     // less than one day marker
     newSize = kTLMinMarkerWidth * totalHours;
     }
     
     if (tempPPH > sv.frame.size.width) {
     // more than one hour marker in the whole screen
     newSize = sv.frame.size.width;
     }
     
     //NSLog(@"setting size to %f", newSize);
     
     self.frame = CGRectMake(0, 0, newSize, self.frame.size.height);
     bar.frame = CGRectMake(0, 0, newSize, 50);
     
     */
    
    //[sv setContentSize:CGSizeMake(newSize, self.frame.size.height)];
    
    //CGRect visibleRect = CGRectIntersection(self.frame, self.superview.bounds);
    
    //    pixelsPerHour = [NSNumber numberWithFloat:(self.frame.size.width / totalHours)];
    
    //    [delegate didUpdateSize];
    
    /*
     if ([pixelsPerHour floatValue] > 300.0f) {
     pixelsPerHour = [NSNumber numberWithFloat:300.0f];
     }
     
     if ([pixelsPerHour floatValue] < 20.0f) {
     pixelsPerHour = [NSNumber numberWithFloat:20.0f];
     }
     */
    
    
    
    //    [self updateTimeMarkers];
    //    [bar updatePixelsPerHour:pixelsPerHour fromTime:fromTime toTime:toTime];
    
    
    //    [locationViews makeObjectsPerformSelector:@selector(updatePixelsPerHour:) withObject:pixelsPerHour];
    //    [self setLocationFrames];
    //NSLog(@"the visible part goes from : %f", visibleRect.origin.x);
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        // call did scroll to 
        //[delegate didScrollToTimespan];
        
        // we need to set everything to the closest multiple of the current width of the frame
        
        isUpdatingFromUserGesture = YES;
        
        [self fixMarkerWidth];
        
        [self setMarkersToCurrentWidth];
        
        
        isZooming = NO;
        [self lockToClosest];
    }
    
    return;
}




#pragma mark Calculations

- (int)maxMarkersForFrameSize {
    // only make 2 more than the max number of timemarkers that can fit on the screen
    
    NSLog(@"width= %f, minsize= %f, numMarkers=%f", self.frame.size.width, kZNMinTimeMarkerSize, self.frame.size.width / kZNMinTimeMarkerSize);
    
    
    return (self.frame.size.width / kZNMinTimeMarkerSize);
}

- (kZNTimelineMarkerMode)modeForCurrent {
    
}


- (void)resetToSize {
    
    
    
}



#pragma mark Content Delegate

- (float)xOffsetForTime:(NSDate *)time {
    
    // work out the x offset for a specific time by using the zero time, current marker width and marker mode
    
    NSTimeInterval secondsOffset = [time timeIntervalSinceDate:currentZeroTime];
    
    float xOffset = 0;
    
    switch (currentMarkerMode) {
        case kZNTimelineMarkerModeHour:
            xOffset = (secondsOffset / 3600) * currentMarkerWidth;
            break;
            
        case kZNTimelineMarkerModeQuarterDay:
            xOffset = (secondsOffset / 3600 / 6) * currentMarkerWidth;
            break;
            
        case kZNTimelineMarkerModeHalfDay:
            xOffset = (secondsOffset / 3600 / 12) * currentMarkerWidth;
            break;
            
        case kZNTimelineMarkerModeDay:
            xOffset = (secondsOffset / 3600 / 24) * currentMarkerWidth;
            break;
            
        default:
            break;
    }
    
    return xOffset;
    
}






/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/







@end
