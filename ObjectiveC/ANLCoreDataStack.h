//
//  ANLCoreDataStack.h
//
//  Created by Amador Navarro Lucas on 15/11/2015
//  based on AGTCoreDataStack by Fernando Rodríguez
//

#import <Foundation/Foundation.h>



@class NSManagedObjectContext;

@interface ANLCoreDataStack : NSObject

@property (strong, nonatomic, readonly) NSManagedObjectContext *mainContext;

+(NSString *)persistentStoreCoordinatorErrorNotificationName;
+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName;
+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName databaseURL:(NSURL *)aDBURL;
+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName databaseFilename:(NSString *)aDBName;

-(id)initWithModelName:(NSString *)aModelName databaseURL:(NSURL *)aDBURL;
-(NSManagedObjectContext *)newPrivateContext;
-(void)zapAllData;

-(void)saveMainContextWithErrorBlock:(void(^)(NSError *error))errorBlock;
-(void)saveContext:(NSManagedObjectContext *)context errorBlock:(void(^)(NSError *error))errorBlock;

-(NSArray *)executeFetchRequestInMainContext:(NSFetchRequest *)fetchRequest errorBlock:(void (^)(NSError *))errorBlock;
-(NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
                      inContext:(NSManagedObjectContext *)context errorBlock:(void (^)(NSError *))errorBlock;

@end
