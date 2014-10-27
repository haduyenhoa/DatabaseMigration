//
//  DBMigrationManager.h
//  DatabaseMigration
//
//  Created by Duyen Hoa Ha on 27/10/2014.
//  Copyright (c) 2014 Duyen Hoa Ha. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
@protocol DBMigrationManagerDelegate <NSObject>

-(void)updateMigrationProgress:(NSNumber*)value;
-(void)finishMigration:(BOOL)success;
-(void)migrationMessage:(NSString*)msg;

@end

@interface DBMigrationManager : NSObject {
    NSManagedObjectModel *_newApplicationDBModel;
    NSManagedObjectModel *_oldApplicationDBModel;
    
    __block float _migrationProgress;
}

+(DBMigrationManager*)shareAgent;

@property (nonatomic, assign) id<DBMigrationManagerDelegate> delegate;

-(BOOL)needMigration;
-(void)migrateDB;

@end
