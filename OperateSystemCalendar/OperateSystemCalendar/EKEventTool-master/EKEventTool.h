//
//  EKEventTool.h
//  product1
//
//  Created by harrisdeng on 2019/4/10.
//  Copyright © 2019 邓昊. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import "EKEventModel.h"

@interface EKEventTool : NSObject



+ (instancetype)sharedEventTool;

#pragma mark - delete all then add new events
- (void)creatAllCalendarEventsWithEventModels:(NSArray <EKEventModel *> *)eventModels Ident:(NSString *)ident ;

/**
 // 创建日历事件
 
 //  title 标题
 //  location 地点
 //  startDateStr 开始时间
 //  endDateStr 结束时间
 //  allDay 是否全天
 //  notes 备注
 //  alarmStr 提醒时间
 */
- (void)createEventWithEventModel:(EKEventModel *)eventModel;


//删除事件必须 之前创建过，只能删除通过工具创建的事件

/**
 *  删除事件
 */
- (BOOL)deleteEvent:(EKEventModel *)eventModel;

/**
 *  删除用户创建的所有事件
 */
- (void)deleteAllCreatedEvent;

/**
 *  查找日历事件中存在的事件
 */
- (NSArray <EKEvent *>*)getSystemCalendarEvents;




@end
