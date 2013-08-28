//
//  VTDownlinkService.m
//  vTeam
//
//  Created by zhang hailong on 13-5-2.
//  Copyright (c) 2013年 hailong.org. All rights reserved.
//

#import "VTDownlinkService.h"

#import <vTeam/VTAPITask.h>

#import "VTDBContext.h"
#import "VTDBObject.h"
#import "VTJSON.h"

static VTDBContext * gDownlinkServiceDBContext = nil;
static dispatch_queue_t gDownlinkServiceDispatchQueue = nil;

@interface VTDownlinkServiceDBObject : VTDBObject

@property(nonatomic,retain) NSString * service;
@property(nonatomic,retain) NSString * key;
@property(nonatomic,retain) NSString * jsonString;
@property(nonatomic,assign) NSInteger timestamp;

@end

@implementation VTDownlinkServiceDBObject

@synthesize service = _service;
@synthesize key = _key;
@synthesize jsonString = _jsonString;
@synthesize timestamp = _timestamp;

-(void) dealloc{
    [_service release];
    [_key release];
    [_jsonString release];
    [super dealloc];
}

@end

@interface VTDownlinkService(){
    
}

-(id) dataObjectForKey:(NSString *) key;

@end

@implementation VTDownlinkService

+(id) dbContext {

    if(gDownlinkServiceDBContext == nil){
        
        NSString * dbPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/VTDownlinkService.db"];
        
        gDownlinkServiceDBContext = [[VTDBContext alloc] init];
        VTSqlite * db = [[VTSqlite alloc] initWithPath:dbPath];
        [gDownlinkServiceDBContext setDb:db];
        [db release];
        
        [gDownlinkServiceDBContext regDBObjectClass:[VTDownlinkServiceDBObject class]];
    }
    
    return gDownlinkServiceDBContext;
}

+(dispatch_queue_t) dispatchQueue{
    
    if(gDownlinkServiceDispatchQueue == nil){
        gDownlinkServiceDispatchQueue = dispatch_queue_create("org.hailong.vTeam.VTDownlinkService", NULL);
    }
    
    return gDownlinkServiceDispatchQueue;
}

-(void) dealloc{
    [super dealloc];
}

-(VTDownlinkServiceDBObject *) dataObjectForKey:(NSString *) key{
    VTDownlinkServiceDBObject * dataObject = nil;
    id<IVTSqliteCursor> cursor = [[VTDownlinkService dbContext] query:[VTDownlinkServiceDBObject class] sql:@" WHERE [service]=:service AND [key]=:key" data:[NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([self class]),@"service",key,@"key", nil]];
    if([cursor next]){
        dataObject = [[[VTDownlinkServiceDBObject alloc] init] autorelease];
        [cursor toDataObject:dataObject];
    }
    [cursor close];
    return dataObject;
}


-(NSString *) dataKey:(id<IVTDownlinkTask>) task forTaskType:(Protocol *) taskType{
    return NSStringFromProtocol(taskType);
}

-(void) vtDownlinkTaskDidLoadedFromCache:(id<IVTDownlinkTask>) downlinkTask forTaskType:(Protocol *) taskType{
    
    if([downlinkTask respondsToSelector:@selector(vtDownlinkTaskDidLoadedFromCache:timestamp:forTaskType:)]){
        NSString * dataKey = [self dataKey:downlinkTask forTaskType:taskType];
        
        dispatch_async([VTDownlinkService dispatchQueue], ^{
           
            VTDownlinkServiceDBObject * dataObject = [self dataObjectForKey:dataKey];
            
            if(dataObject){
                
                id data = [VTJSON decodeText:dataObject.jsonString];
                NSDate * timestamp = [NSDate dateWithTimeIntervalSince1970:dataObject.timestamp];
                
                if(data){
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [downlinkTask vtDownlinkTaskDidLoadedFromCache:data timestamp:timestamp forTaskType:taskType];
                    });
                    
                }
                
            }
        });
    }

}

-(void) vtDownlinkTask:(id<IVTDownlinkTask>) downlinkTask didResponse:(id) data isCache:(BOOL) isCache forTaskType:(Protocol *) taskType{

    NSString * dataKey = nil;
    __block NSString * jsonString = nil;
    
    if(isCache){
        dataKey = [self dataKey:downlinkTask forTaskType:taskType];
        if(dataKey){
            dispatch_async([VTDownlinkService dispatchQueue], ^{
                jsonString = [VTJSON encodeObject:data];
            });
        }
    }
    
    if([downlinkTask respondsToSelector:@selector(vtDownlinkTaskDidLoaded:forTaskType:)]){
     
        dispatch_async([VTDownlinkService dispatchQueue], ^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [downlinkTask vtDownlinkTaskDidLoaded:data forTaskType:taskType];
            });
        });

    }
    
    if(isCache && dataKey){

        dispatch_async([VTDownlinkService dispatchQueue], ^{
            VTDownlinkServiceDBObject * dataObject = [self dataObjectForKey:dataKey];
            if(dataObject){
                dataObject.jsonString = jsonString;
                dataObject.timestamp = time(NULL);
                [[VTDownlinkService dbContext] updateObject:dataObject];
            }
            else{
                dataObject = [[VTDownlinkServiceDBObject alloc] init];
                dataObject.key = dataKey;
                dataObject.jsonString = jsonString;
                dataObject.timestamp = time(NULL);
                dataObject.service = NSStringFromClass([self class]);
                [[VTDownlinkService dbContext] insertObject:dataObject];
            }
        });
    }
    

}

-(void) vtDownlinkTask:(id<IVTDownlinkTask>) downlinkTask didFitalError:(NSError *) error forTaskType:(Protocol *) taskType{
    if([downlinkTask respondsToSelector:@selector(vtDownlinkTaskDidFitalError:forTaskType:)]){
        [downlinkTask vtDownlinkTaskDidFitalError:error forTaskType:taskType];
    }
}


-(BOOL) cancelHandle:(Protocol *)taskType task:(id<IVTTask>)task{
    
    VTAPITask * t = [[VTAPITask alloc] init];
    
    [t setTaskType:taskType];
    [t setTask:task];
    
    [self.context cancelHandle:@protocol(IVTAPICancelTask) task:t];
    
    [t release];
    
    return YES;
}

@end
