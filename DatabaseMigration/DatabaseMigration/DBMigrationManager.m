//
//  DBMigrationManager.m
//  DatabaseMigration
//
//  Created by Duyen Hoa Ha on 27/10/2014.
//  Copyright (c) 2014 Duyen Hoa Ha. All rights reserved.
//

#import "DBMigrationManager.h"
#import "AppDelegate.h"

static DBMigrationManager *_shareAgent;

@implementation DBMigrationManager

+(DBMigrationManager*)shareAgent {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareAgent = [[DBMigrationManager alloc] init];
        
    });
    return _shareAgent;
}

-(id)init {
    self = [super init];
    if (self) {
        NSString *newDBModelPath = [[NSBundle mainBundle] pathForResource:@"DatabaseMigration" ofType:@"momd"];
        NSURL *newDBModelURL = [NSURL fileURLWithPath:newDBModelPath];
        
        _newApplicationDBModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:newDBModelURL];
        _oldApplicationDBModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.momd"]]];
        
    }
    return self;
}


/**
 @discussion        Verify if new model is compatible with current
 */
-(BOOL)needMigration {
    NSURL *storeSourceUrl = [NSURL fileURLWithPath: [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite"]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:storeSourceUrl.path]) {
        NSLog(@"Store source exists");
    } else {
        NSLog(@"Store source does not exist");
    }
	NSError *error = nil;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeSourceUrl.path]) {
        NSLog(@"first start, .sql does not exist");
        return NO;
    }
    
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator
                                    metadataForPersistentStoreOfType:NSSQLiteStoreType
                                    URL:storeSourceUrl
                                    error:&error];
    if (sourceMetadata) {
        NSString *configuration = nil;
        
        BOOL pscCompatible  =[_newApplicationDBModel isConfiguration:configuration compatibleWithStoreMetadata:sourceMetadata];
        
        NSLog(@"Is the STORE data COMPATIBLE? %@", (pscCompatible==YES) ?@"YES" :@"NO");
        if (pscCompatible == NO) {
            return YES;
        }
    }
    else {
        NSLog(@"Cannot check if we need to migrate or not. By default, it's NO");
        return NO;
    }
    
    return NO;
}
-(void)migrateDB {
    NSURL *storeSourceUrl = [NSURL fileURLWithPath: [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite"]];
    NSError *error = nil;
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator
                                    metadataForPersistentStoreOfType:NSSQLiteStoreType
                                    URL:storeSourceUrl
                                    error:&error];
    
    [self performMigrationWithSourceMetadata:sourceMetadata];
}

- (void)performMigrationWithSourceMetadata :(NSDictionary *)sourceMetadata
{
    NSLog(@"Begin to migrate");
    __block BOOL migrationSuccess = NO;
    //Initialise a Migration Manager...
    BOOL foundModel = NO;
    
    //get old db model
    if (_oldApplicationDBModel == nil) {
        _oldApplicationDBModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:sourceMetadata];
    }
    if (_oldApplicationDBModel) {
        foundModel = YES;
    }
    //    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:sourceMetadata];
    
    
    //Perform the migration...
    if (foundModel) {
        NSMigrationManager *standardMigrationManager = nil;
        
        standardMigrationManager = [[NSMigrationManager alloc] initWithSourceModel:_oldApplicationDBModel destinationModel:_newApplicationDBModel];
        
        
        NSError *createMappingError;
        NSMappingModel *mappingModel = nil;
        
        /**
         Here, if the migration is not complicated, the automatic migration works well. Otherwise, we have to create ourselve the mapping model
         */
        
        //Case A: automatic mapping model
        mappingModel = [NSMappingModel inferredMappingModelForSourceModel:_oldApplicationDBModel destinationModel:_newApplicationDBModel error:&createMappingError];
        for (id entity in _oldApplicationDBModel.entities) {
            NSLog(@"Old entity: %@",entity);
        }
        
        for (id entity in _newApplicationDBModel.entities) {
            NSLog(@"New entity: %@",entity);
        }
        
        //Case B: Manual mapping model
        //mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:[NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"cdm_ver_1_2_0_ver_2_2_0" ofType:@"cdm"]]];
        
        if (mappingModel) {
            NSString *storeSourcePath = [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite"];
            NSURL *storeSourceUrl = [NSURL fileURLWithPath: storeSourcePath];
            
            __block NSError *error = nil;
            NSString *storeDestPath = [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration_temp.sqlite"];
            NSURL *storeDestUrl = [NSURL fileURLWithPath:storeDestPath];
            
            //Pass nil here because we don't want to use any of these options:
            //NSIgnorePersistentStoreVersioningOption, NSMigratePersistentStoresAutomaticallyOption, or NSInferMappingModelAutomaticallyOption
            NSDictionary *sourceStoreOptions = nil;
            NSDictionary *destinationStoreOptions = nil;
            
            NSArray *newEntityMappings = [NSArray arrayWithArray:mappingModel.entityMappings];
            for (NSEntityMapping *entityMapping in newEntityMappings) {
                [entityMapping setSourceEntityVersionHash:[_oldApplicationDBModel.entityVersionHashesByName  valueForKey:entityMapping.sourceEntityName]];
                [entityMapping setDestinationEntityVersionHash:[_newApplicationDBModel.entityVersionHashesByName valueForKey:entityMapping.destinationEntityName]];
            }
            mappingModel.entityMappings = newEntityMappings;
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(migrationMessage:)]) {
                [self.delegate migrationMessage:@"Migration in progress"];
            }
            
            [standardMigrationManager addObserver:self forKeyPath:@"migrationProgress" options:NSKeyValueObservingOptionNew context:NULL];
            migrationSuccess = [standardMigrationManager migrateStoreFromURL:storeSourceUrl
                                                                        type:NSSQLiteStoreType
                                                                     options:sourceStoreOptions
                                                            withMappingModel:mappingModel
                                                            toDestinationURL:storeDestUrl
                                                             destinationType:NSSQLiteStoreType
                                                          destinationOptions:destinationStoreOptions
                                                                       error:&error];
            [standardMigrationManager removeObserver:self forKeyPath:@"migrationProgress"];
            
            if (error != nil) {
                NSLog(@"got error : %@",error);
            }
            
            if(migrationSuccess) {
                [[NSFileManager defaultManager] removeItemAtPath:storeSourcePath error:nil];
                [[NSFileManager defaultManager] moveItemAtPath:storeDestPath toPath:storeSourcePath error:nil];
                
                //
                NSString *oldModelPath = [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.momd"];
                NSString *newModelPath = [[NSBundle mainBundle] pathForResource:@"DatabaseMigration" ofType:@"momd"];

                //remove old temp file
                [[NSFileManager defaultManager] removeItemAtPath:[oldModelPath stringByAppendingString:@"_old"] error:nil];
                
                NSError *copyDBModelError;
                if ([[NSFileManager defaultManager] moveItemAtPath:oldModelPath toPath:[oldModelPath stringByAppendingString:@"_old"] error:&copyDBModelError]) {
                    if ([[NSFileManager defaultManager] copyItemAtPath:newModelPath toPath:oldModelPath error:&copyDBModelError]) {
                        NSLog(@"update model path OK");
                        [[NSFileManager defaultManager] removeItemAtPath:[oldModelPath stringByAppendingString:@"_old"] error:nil];
                    } else {
                        NSLog(@"cannot copy new model path to DatabaseDirectory: %@",copyDBModelError == nil? @"Unknown error": copyDBModelError.localizedDescription);
                    }
                } else {
                    NSLog(@"Cannot backup current model: %@",copyDBModelError == nil? @"Unknown error": copyDBModelError.localizedDescription);
                }
                
                /*
                 ref http://stackoverflow.com/questions/18870387/core-data-and-ios-7-different-behavior-of-persistent-store/18870738#18870738
                 */
                
                //remove -wal & -shm file
                NSString *shmPath = [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite-shm"];
                NSString *walPath = [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite-wal"];
                
                //try to delete
                [[NSFileManager defaultManager] removeItemAtPath:shmPath error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:walPath error:nil];
            }
            
            //            [((AppDelegate*)[UIApplication sharedApplication].delegate) closeWaiting];
            NSLog(@"MIGRATION SUCCESSFUL? %@", (migrationSuccess==YES)?@"YES":@"NO");
        } else {
            NSLog(@"Cannot fetching mapping Model !!!, MIGRATION FAILED. Error: %@",createMappingError == nil? @"Unknown error" : createMappingError.localizedDescription);
        }
    }
    else {
        NSLog(@"checkForMigration FAIL - No Mapping Model found!");
    }
    
    //Notify delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(finishMigration:)]) {
        [self.delegate finishMigration:migrationSuccess];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"");
    if ([keyPath isEqualToString:@"migrationProgress"]) {
        _migrationProgress = [(NSMigrationManager *)object migrationProgress];
        NSLog(@"migration progress: %0.2f",_migrationProgress);
        if (self.delegate && [self.delegate respondsToSelector:@selector(updateMigrationProgress:)]) {
            [self.delegate performSelector:@selector(updateMigrationProgress:) withObject:[NSNumber numberWithFloat:_migrationProgress]];
        }
    }
}

@end
