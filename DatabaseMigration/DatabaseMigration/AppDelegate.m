//
//  AppDelegate.m
//  DatabaseMigration
//
//  Created by Duyen Hoa Ha on 14/10/2014.
//  Copyright (c) 2014 Duyen Hoa Ha. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end



@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.haduyenhoa.demo.DatabaseMigration" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"DatabaseMigration" ofType:@"momd"];
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    NSError *error;
    
    NSURL *storeURL = [NSURL fileURLWithPath: [kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.sqlite"]];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             @"DELETE",@"journal_mode", // see http://sqlite.org/pragma.html and
                             //                                                                  http://stackoverflow.com/questions/18870387/core-data-and-ios-7-different-behavior-of-persistent-store/18870738#18870738
                             nil];
    BOOL isStoreProtected = NO;
    BOOL isStoreFirstCreated  = YES;
    
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
        isStoreFirstCreated = NO;
        
        //protect it now
        NSDictionary *fileAttributes = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
        if (![[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:storeURL.path error:&error]) {
            NSLog(@"cannot protect .sqlite file, error = \n%@",error);
            
        } else {
            isStoreProtected = YES;
            NSLog(@".sqlite has been protected!");
        }
    }
    
    error = nil;
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    for (int tries = 1; tries <= 2; tries++)
    {
        NSLog(@"begin migration if need");
        if ([_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
            if (tries == 2 && !isStoreFirstCreated) {
                NSLog(@"try = %d",tries);
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                message:@"Database has been reset"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alert show];
                });
				
				NSLog(@"%@", alert.message);
            }
            
            if (!isStoreProtected) {
                //protect it now
                NSDictionary *fileAttributes = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
                if (![[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:storeURL.path error:&error]) {
                    NSLog(@"retry but cannot protect .sqlite file, error = \n%@",error);
                    
                } else {
                    NSLog(@"retry and .sqlite has been protected!");
                }
            }
            
            NSLog(@"successfully migrate to new store model. backup momd now");
            @autoreleasepool {
                
                NSFileManager *fm = [NSFileManager defaultManager];
                
                //backup this managedObjectModel to kDatabaseLibrary
                NSURL *backupMomUrl = [NSURL fileURLWithPath:[kDatabaseDirectory stringByAppendingPathComponent:@"DatabaseMigration.momd"]];
                //remove old file
                [fm removeItemAtPath:backupMomUrl.path error:nil];
                //copy new file
                
                [fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"DatabaseMigration" ofType:@"momd"] toPath:backupMomUrl.path error:nil];
                
                backupMomUrl = nil;
                fm = nil;
            }
            
            
            break;
        } else {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             
             Typical reasons for an error here include:
             * The persistent store is not accessible;
             * The schema for the persistent store is incompatible with current managed object model.
             Check the error message to determine what the actual problem was.
             
             
             If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
             
             If you encounter schema incompatibility errors during development, you can reduce their frequency by:
             * Simply deleting the existing store:
             [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
             
             * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
             [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
             
             Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
             
             */
            NSLog(@"Managed object store error %@, %@", error, [error userInfo]);
            
            if (tries == 1)
            {
                NSLog(@"try to delete DB");
                // Try deleting the database
                [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
            } else { // What else can be done
                [[NSException exceptionWithName:[error localizedDescription]
                                         reason:[[error userInfo] description]
                                       userInfo:nil] raise];
            }
        }
    }

    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end
