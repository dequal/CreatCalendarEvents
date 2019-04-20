//
//  EKEventTool.m
//  product1
//
//  Created by harrisdeng on 2019/4/10.
//  Copyright © 2019 邓昊. All rights reserved.
//

#import "EKEventTool.h"

#define SavedEKEventsIdenti @"savedEKEventsIdenti"

@interface EKEventTool ()

@property (nonatomic, strong) EKEventStore *myEventStore;

@end


@implementation EKEventTool


+ (instancetype)sharedEventTool {
    
    static EKEventTool *eventTool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventTool = [[EKEventTool alloc]init];
    });
    return eventTool;
}

#pragma mark - delete all then add new events
- (void)creatAllCalendarEventsWithEventModels:(NSArray <EKEventModel *> *)eventModels Ident:(NSString *)ident {
    self.myEventStore = [[EKEventStore alloc] init];
    
    if ([self.myEventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        __weak __typeof(self)weakSelf = self;
        [self.myEventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"calendar add fail");
                }else if (!granted) {
                    NSLog(@"calendar refuse");
                }else{
                    //delete all
                    //2019/3/20 11:0:0    ---   2022/3/20 11:0:0 -->Effective range four years
                    NSPredicate *predicate = [self.myEventStore predicateForEventsWithStartDate:[NSDate dateWithTimeIntervalSince1970:1553050800] endDate:[NSDate dateWithTimeIntervalSince1970:1647745200] calendars:nil];
                    NSArray *eventArr = [strongSelf.myEventStore eventsMatchingPredicate:predicate];
                    NSLog(@"current eventsCount ===  %lu",(unsigned long)eventArr.count);
                    [eventArr enumerateObjectsUsingBlock:^(EKEvent * _Nonnull event, NSUInteger idx, BOOL * _Nonnull stop) {
                        if ([event.notes containsString:ident]) {
                            NSLog(@"delete event %@",event.notes);
                            [strongSelf.myEventStore removeEvent:event span:EKSpanThisEvent commit:YES error:nil];
                        }
                    }];
                    //creat new events
                    for (EKEventModel *newEventModel in eventModels) {
                        EKEvent *newEvent = [EKEvent eventWithEventStore:strongSelf.myEventStore];
                        newEvent.title = newEventModel.title;
                        newEvent.startDate = newEventModel.startDate;
                        newEvent.endDate = newEventModel.endDate;
                        newEvent.allDay = newEventModel.allDay;
                        newEvent.notes = newEventModel.notes;
                        [newEvent setCalendar:[strongSelf.myEventStore defaultCalendarForNewEvents]];
                        [strongSelf.myEventStore saveEvent:newEvent span:EKSpanThisEvent error:nil];
                    }
                }
            });
        }];
    }
}


/**
 *  创建事件
 */
- (void )createEventWithEventModel:(EKEventModel *)eventModel {
    
    EKEventStore * eventStore = [[EKEventStore alloc]init];
    
    if ([eventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"添加失败");
                } else if (!granted) {
                    NSLog(@"被拒绝");
                } else {
                    
                    //判断当前日历中是否已经创建了该事件
                    EKEvent *event = [self getEventWithEKEventModel:eventModel];
                    
                    if (event == nil) {
                        
                        event = [EKEvent eventWithEventStore:self.myEventStore];
                        event.title = eventModel.title;
                        event.location = eventModel.location;
                        event.startDate = eventModel.startDate;
                        event.endDate = eventModel.endDate;
                        event.allDay = eventModel.allDay;
                        event.notes = eventModel.notes;
                        
                        NSInteger alarmTime = [self getAlarmWithStr:eventModel.alarmStr];
                        if (alarmTime != 0) {
                            [event addAlarm:[EKAlarm alarmWithRelativeOffset:alarmTime]];
                        } else {
                            // 设置提醒时间为 开始时间
                            [event addAlarm:[EKAlarm alarmWithAbsoluteDate:eventModel.startDate]];
                        }
                        
                        [event setCalendar:[self.myEventStore defaultCalendarForNewEvents]];
                        NSError *err;
                        BOOL isSave;
                        isSave = [self.myEventStore saveEvent:event span:EKSpanThisEvent error:&err];
                        if (isSave) {
                            NSString *identifer = event.eventIdentifier;
                            
                            NSMutableArray *tmpArr = [NSMutableArray arrayWithObject:identifer];
                            
                            
                            NSMutableArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:SavedEKEventsIdenti];
                            if (!arr) {
                                [[NSUserDefaults standardUserDefaults] setObject:tmpArr forKey:SavedEKEventsIdenti];
                            } else {
                                [tmpArr addObjectsFromArray:arr];
                                [[NSUserDefaults standardUserDefaults] setObject:tmpArr forKey:SavedEKEventsIdenti];
                            }
                        }
                    }
                }
                
            }) ;
        }];
    }
}

/**
 *  删除事件
 */
- (BOOL)deleteEvent:(EKEventModel *)eventModel {
    
    __block BOOL isDeleted = NO;
    __block NSString *eventIdentif;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        EKEvent * event = [self getEventWithEKEventModel:eventModel];
        eventIdentif = event.eventIdentifier;
        NSError *err = nil;
        isDeleted = [self.myEventStore removeEvent:event span:EKSpanThisEvent commit:YES error:&err];
    });
    
    if (isDeleted) {
        [self clearIdentifier:eventIdentif];
    }
    
    return isDeleted;
}

//删除后，清除 NSUserDefaults 中的 identifier
- (void)clearIdentifier:(NSString *)identifier {
    NSMutableArray *savedArr = [[NSUserDefaults standardUserDefaults] objectForKey:SavedEKEventsIdenti];
    for (int i = 0; i < savedArr.count; i ++) {
        if ([identifier isEqualToString:savedArr[i]]) {
            [savedArr removeObjectAtIndex:i];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:savedArr forKey:SavedEKEventsIdenti];
}

/**
 *  使用 identifier删除
 */
-(void)deleteWithIdentifier:(NSString *)identifier {
    if (!self.myEventStore) {
        self.myEventStore = [[EKEventStore alloc]init];
    }
    
    EKEvent *event = [self.myEventStore eventWithIdentifier:identifier];
    NSLog(@"eventtitle == %@", event.title);
    
    __block BOOL isDeleted = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *err = nil;
        isDeleted = [self.myEventStore removeEvent:event span:EKSpanThisEvent commit:YES error:&err];
    });
    if (isDeleted) {
        [self clearIdentifier:event.eventIdentifier];
    }
}

/**
 *  删除全部保存的
 */
- (void)deleteAllCreatedEvent {
    
    NSMutableArray *savedArr = [[NSUserDefaults standardUserDefaults] objectForKey:SavedEKEventsIdenti];
    
    for (int i = 0; i < savedArr.count; i++) {
        NSString *eventIdentifier = savedArr[i];
        [self deleteWithIdentifier:eventIdentifier];
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SavedEKEventsIdenti];
}

/**
 *  查找日历事件中相同的事件
 */
- (EKEvent *)getEventWithEKEventModel:(EKEventModel *)eventModel {
    
    EKEventStore * eventStore = [[EKEventStore alloc]init];
    self.myEventStore =  eventStore;
    NSPredicate *predicate = [eventStore predicateForEventsWithStartDate:eventModel.startDate endDate:eventModel.endDate calendars:@[[eventStore defaultCalendarForNewEvents]]];
    NSArray *events = [eventStore eventsMatchingPredicate:predicate];
    
    EKEvent *resultEvent = nil;
    if (events) {
        for (EKEvent *event in events) {
            NSLog(@"已经存在event title=%@,startDate=%@,endDate=%@",event.title,event.startDate,event.endDate);
            if ([self checkEvent:event sameWithEvent:eventModel]) {
                resultEvent = event;
            }
        }
    }
    return resultEvent;
}

/**
 *  判断两个事件是否相同
 */
- (BOOL)checkEvent:(EKEvent *)event sameWithEvent:(EKEventModel *)eventModel {
    
    NSInteger modelAlarm = [self getAlarmWithStr:eventModel.alarmStr];
    
    EKAlarm *eventAlarm = event.alarms[0];
    NSInteger alarmInt = eventAlarm.relativeOffset;
    
    //项目中日程 只有 标题和 时间 和提醒时间 所有只做两个判断
    if ([event.title isEqualToString: eventModel.title] && (modelAlarm == alarmInt)) {
        return YES;
    } else {
        return NO;
    }
}


/**
 *  查找日历事件中存在的事件
 */

- (NSArray <EKEvent *>*)getSystemCalendarEvents {
    EKEventStore * eventStore = [[EKEventStore alloc]init];
    //    self.myEventStore =  eventStore;
    //查找最近前后两周的所有事件(一共四周)
    NSPredicate *predicate = [eventStore predicateForEventsWithStartDate:[NSDate dateWithTimeIntervalSinceNow:-3600*24*7*2] endDate:[NSDate dateWithTimeIntervalSinceNow:3600*24*7*2]calendars:@[[eventStore defaultCalendarForNewEvents]]];
    NSArray *events = [eventStore eventsMatchingPredicate:predicate];
    
    //    EKEvent *resultEvent = nil;
    if (events) {
        for (EKEvent *event in events) {
            if ([event.notes containsString: @"OperateSystemCalendar"]) {
                NSLog(@"systemCalendar已经存在event title=%@,startDate=%@,endDate=%@",event.title,event.startDate,event.endDate);
            }
        }
    }
    return events;
}


/**
 *  获得提醒 NSinteger
 */
- (NSInteger)getAlarmWithStr:(NSString *)alarmStr {
    
    NSInteger alarmTime;
    if (alarmStr.length == 0) {
        alarmTime = 0;
    } else if ([alarmStr isEqualToString:@"不提醒"]) {
        alarmTime = 0;
    } else if ([alarmStr isEqualToString:@"1分钟前"]) {
        alarmTime = 60.0 * -1.0f;
    } else if ([alarmStr isEqualToString:@"10分钟前"]) {
        alarmTime = 60.0 * -10.f;
    } else if ([alarmStr isEqualToString:@"30分钟前"]) {
        alarmTime = 60.0 * -30.f;
    } else if ([alarmStr isEqualToString:@"1小时前"]) {
        alarmTime = 60.0 * -60.f;
    } else if ([alarmStr isEqualToString:@"1天前"]) {
        alarmTime = 60.0 * - 60.f * 24;
    } else {
        alarmTime = 0;
    }
    return alarmTime;
}

@end
