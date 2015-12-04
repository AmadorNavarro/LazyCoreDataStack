//
//  ANLCoreDataStack.m
//
//  Created by Amador Navarro Lucas on 15/11/2015
//  based on AGTCoreDataStack by Fernando Rodríguez
//

#import <CoreData/CoreData.h>

#import "ANLCoreDataStack.h"



@interface ANLCoreDataStack ()

@property (strong, nonatomic, readonly) NSManagedObjectModel *model;
@property (strong, nonatomic, readonly) NSPersistentStoreCoordinator *storeCoordinator;
@property (strong, nonatomic) NSURL *modelURL;
@property (strong, nonatomic) NSURL *dbURL;

@end



@implementation ANLCoreDataStack

#pragma mark -  Properties
// When using a readonly property with a custom getter, auto-synthesize is disabled.
@synthesize model = _model;
@synthesize storeCoordinator = _storeCoordinator;
@synthesize mainContext = _mainContext;

-(NSManagedObjectContext *)mainContext {
    
    if (_mainContext == nil) {
        
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainContext setPersistentStoreCoordinator:[self storeCoordinator]];
        [self setupSaveNotification];
    }
    return _mainContext;
}

-(NSPersistentStoreCoordinator *)storeCoordinator {
    
    if (_storeCoordinator == nil) {
        
        _storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self model]];
        
        NSError *error = nil;
        if (![_storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                             configuration:nil URL:[self dbURL] options:nil error:&error]) {
            // Something went really wrong...
            // Send a notification and return nil
            NSString *name = [ANLCoreDataStack persistentStoreCoordinatorErrorNotificationName];
            NSNotification *note = [NSNotification notificationWithName:name object:self userInfo:@{@"error" : error}];
            [[NSNotificationCenter defaultCenter] postNotification:note];
            
            NSLog(@"Error while adding a Store: %@", error);
            return nil;
        }
    }
    return _storeCoordinator;
}

-(NSManagedObjectModel *)model {
    
    if (_model == nil) {
        
        _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[self modelURL]];
    }
    return _model;
}



#pragma mark - Class Methods

+(NSString *)persistentStoreCoordinatorErrorNotificationName {
    
    return @"persistentStoreCoordinatorErrorNotificationName";
}

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory {
    
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName databaseFilename:(NSString *)aDBName {
    
    NSURL *url = nil;
    
    if (aDBName) {
        
        url = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:aDBName];
    } else {
        
        url = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:aModelName];
    }
    
    return [self coreDataStackWithModelName:aModelName databaseURL:url];
}

+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName {
    
    return [self coreDataStackWithModelName:aModelName databaseFilename:nil];
}

+(ANLCoreDataStack *)coreDataStackWithModelName:(NSString *)aModelName databaseURL:(NSURL *)aDBURL {
    
    return [[self alloc] initWithModelName:aModelName databaseURL:aDBURL];
}



#pragma mark - Init

-(id)initWithModelName:(NSString *)aModelName databaseURL:(NSURL*)aDBURL{
    
    if (self = [super init]) {
        
        [self setModelURL:[[NSBundle mainBundle] URLForResource:aModelName withExtension:@"momd"]];
        [self setDbURL:aDBURL];
    }
    
    return self;
}

-(void)setupSaveNotification {
    
    void (^block)(NSNotification *note) = ^(NSNotification *note) {

        NSManagedObjectContext *context = [self mainContext];
        if ([note object] != context) {

            [context performBlock:^{
               
                [context mergeChangesFromContextDidSaveNotification:note];
            }];
        }
    };
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
                                                      object:nil queue:nil usingBlock:block];
}

-(NSManagedObjectContext *)newPrivateContext {
    
    NSManagedObjectContext *context;
    context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    
    [context setPersistentStoreCoordinator:[self storeCoordinator]];
    return context;
}



#pragma mark - Others

-(void)zapAllData {
    
    NSError *error = nil;
    for (NSPersistentStore *store in [[self storeCoordinator] persistentStores]) {
        
        if(![[self storeCoordinator] removePersistentStore:store error:&error]) {
            
            NSLog(@"Error while removing store %@ from store coordinator %@", store, [self storeCoordinator]);
        }
    }
    if (![[NSFileManager defaultManager] removeItemAtURL:[self dbURL] error:&error]) {
        
        NSLog(@"Error removing %@: %@", [self dbURL], error);
    }
    // The Core Data stack does not like you removing the file under it. If you want to delete the file
    // you should tear down the stack, delete the file and then reconstruct the stack.
    // Part of the problem is that the stack keeps a cache of the data that is in the file. When you
    // remove the file you don't have a way to clear that cache and you are then putting
    // Core Data into an unknown and unstable state.
    
    _mainContext = nil;
    _storeCoordinator = nil;
    [self mainContext]; // this will rebuild the stack
}

-(NSArray *)executeFetchRequestInMainContext:(NSFetchRequest *)fetchRequest errorBlock:(void (^)(NSError *))errorBlock {
    
    return [self executeFetchRequest:fetchRequest inContext:[self mainContext] errorBlock:errorBlock];
}

-(NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest
                      inContext:(NSManagedObjectContext *)context errorBlock:(void (^)(NSError *))errorBlock {
    
    NSError *error = nil;
    NSArray *results = [[NSArray alloc] init];
    // If a context is nil, execute a fetch request it should also be considered an
    // error, as being nil might be the result of a previous error while creating the db.
    if (!context) {
        
        NSString *message = @"Attempted to fetch in a nil NSManagedObjectContext. This ANLCoreDataStack has no context - probably there was an earlier error trying to access the CoreData database file.";
        
        error = [NSError errorWithDomain:@"ANLCoreDataStack" code:1 userInfo:@{NSLocalizedDescriptionKey : message}];
        
        errorBlock(error);
    } else {
     
        results = [context executeFetchRequest:fetchRequest error:&error];
        if (error) {
            
            errorBlock(error);
        }
    }
    return results;
}

-(void)saveMainContextWithErrorBlock:(void(^)(NSError *error))errorBlock {
    
    [self saveContext:[self mainContext] errorBlock:errorBlock];
}

-(void)saveContext:(NSManagedObjectContext *)context errorBlock:(void (^)(NSError *))errorBlock {

    NSError *error = nil;
    // If a context is nil, saving it should also be considered an
    // error, as being nil might be the result of a previous error while creating the db.
    if (!context) {
        
        NSString *message = @"Attempted to save a nil NSManagedObjectContext. This ANLCoreDataStack has no context - probably there was an earlier error trying to access the CoreData database file.";
        
        error = [NSError errorWithDomain:@"ANLCoreDataStack" code:1 userInfo:@{NSLocalizedDescriptionKey : message}];
        
        errorBlock(error);
        
    } else if ([context hasChanges]) {
        
        if (![context save:&error]) {
            
            errorBlock(error);
        }
    }
}

@end
