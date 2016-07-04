//
//  RNBranch.m
//  RNBranch
//
//  Created by Kevin Stumpf on 1/28/16.
//

#import "RNBranch.h"
#import "RCTBridgeModule.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import <Branch/Branch.h>
#import "BranchLinkProperties.h"
#import "BranchUniversalObject.h"

@implementation RNBranch

NSString * const initSessionWithLaunchOptionsFinishedEventName = @"initSessionWithLaunchOptionsFinished";
static NSDictionary* initSessionWithLaunchOptionsResult;
static NSURL* sourceUrl;

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

//Called by AppDelegate.m -- stores initSession result in static variables and raises initSessionFinished event that's captured by the RNBranch instance to emit it to React Native
+ (void)initSessionWithLaunchOptions:(NSDictionary *)launchOptions isReferrable:(BOOL)isReferrable {
  [[Branch getInstance] initSessionWithLaunchOptions:launchOptions isReferrable:isReferrable andRegisterDeepLinkHandler:^(NSDictionary *params, NSError *error) {
    NSString *errorMessage = [NSNull null];
    if ([error respondsToSelector:@selector(localizedDescription)]) {
      errorMessage = [error localizedDescription];
    } else if (error) {
      errorMessage = error;
    }

    initSessionWithLaunchOptionsResult = @{
      @"params": params && [params objectForKey:@"~id"] ? params : [NSNull null],
      @"error": errorMessage ? errorMessage : [NSNull null],
      @"uri": sourceUrl ? [sourceUrl absoluteString] : [NSNull null]
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:initSessionWithLaunchOptionsFinishedEventName object:initSessionWithLaunchOptionsResult];
  }];
}

+ (BOOL)handleDeepLink:(NSURL *)url {
  sourceUrl = url;
  BOOL handled = [[Branch getInstance] handleDeepLink:url];
  if (!handled) {
    NSDictionary* nonBranchResult = @{@"params": [NSNull null], @"error": [NSNull null], @"uri": [url absoluteString]};
    [[NSNotificationCenter defaultCenter] postNotificationName:initSessionWithLaunchOptionsFinishedEventName object:nonBranchResult];
  }
  return handled;
}

+ (BOOL)continueUserActivity:(NSUserActivity *)userActivity {
  return [[Branch getInstance] continueUserActivity:userActivity];
}

- (id)init {
  self = [super init];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInitSessionFinished:) name:initSessionWithLaunchOptionsFinishedEventName object:nil];

  return self;
}

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) onInitSessionFinished:(NSNotification*) notification {
  id notificationObject = notification.object;

  // If there is an error, fire error event
  if (notificationObject[@"error"] != [NSNull null]) {
    [self.bridge.eventDispatcher sendAppEventWithName:@"RNBranch.initSessionError" body:notificationObject];
  }

  // otherwise notify the session is finished
  else {
    [self.bridge.eventDispatcher sendAppEventWithName:@"RNBranch.initSessionSuccess" body:notificationObject];
  }
}

- (BranchUniversalObject*) createBranchUniversalObject:(NSDictionary *)branchUniversalObjectMap
{
  BranchUniversalObject *branchUniversalObject = [[BranchUniversalObject alloc] initWithCanonicalIdentifier:[branchUniversalObjectMap objectForKey:@"canonicalIdentifier"]];
  branchUniversalObject.title = [branchUniversalObjectMap objectForKey:@"title"];
  branchUniversalObject.contentDescription = [branchUniversalObjectMap objectForKey:@"contentDescription"];
  branchUniversalObject.imageUrl = [branchUniversalObjectMap objectForKey:@"contentImageUrl"];

  NSDictionary* metaData = [branchUniversalObjectMap objectForKey:@"metadata"];
  if(metaData) {
    NSEnumerator *enumerator = [metaData keyEnumerator];
    id metaDataKey;
    while((metaDataKey = [enumerator nextObject])) {
      [branchUniversalObject addMetadataKey:metaDataKey value:[metaData objectForKey:metaDataKey]];
    }
  }

    return branchUniversalObject;
}

- (BranchLinkProperties*) createLinkProperties:(NSDictionary *)linkPropertiesMap withControlParams:(NSDictionary *)controlParamsMap
{
  BranchLinkProperties *linkProperties = [[BranchLinkProperties alloc] init];
  linkProperties.channel = [linkPropertiesMap objectForKey:@"channel"];
  linkProperties.feature = [linkPropertiesMap objectForKey:@"feature"];
  linkProperties.controlParams = controlParamsMap;
  return linkProperties;
}

RCT_EXPORT_METHOD(
  getInitSessionResult:(RCTPromiseResolveBlock)resolve
  rejecter:(__unused RCTPromiseRejectBlock)reject
){
  resolve(initSessionWithLaunchOptionsResult ? initSessionWithLaunchOptionsResult : [NSNull null]);
}

RCT_EXPORT_METHOD(
  setDebug
){
  Branch *branch = [Branch getInstance];
  [branch setDebug];
}

RCT_EXPORT_METHOD(
  getLatestReferringParams:(RCTPromiseResolveBlock)resolve
  rejecter:(__unused RCTPromiseRejectBlock)reject
){
  Branch *branch = [Branch getInstance];
  resolve([branch getLatestReferringParams]);
}

RCT_EXPORT_METHOD(
  getFirstReferringParams:(RCTPromiseResolveBlock)resolve
  rejecter:(__unused RCTPromiseRejectBlock)reject
){
  Branch *branch = [Branch getInstance];
  resolve([branch getFirstReferringParams]);
}

RCT_EXPORT_METHOD(
  setIdentity:(NSString *)identity
){
  Branch *branch = [Branch getInstance];
  [branch setIdentity:identity];
}

RCT_EXPORT_METHOD(
  logout
){
  Branch *branch = [Branch getInstance];
  [branch logout];
}

RCT_EXPORT_METHOD(
  userCompletedAction:(NSString *)event withState:(NSDictionary *)appState
){
  Branch *branch = [Branch getInstance];
  [branch userCompletedAction:event withState:appState];
}

RCT_EXPORT_METHOD(
  showShareSheet:(NSDictionary *)branchUniversalObjectMap
  withShareOptions:(NSDictionary *)shareOptionsMap
  withLinkProperties:(NSDictionary *)linkPropertiesMap
  withControlParams:(NSDictionary *)controlParamsMap
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(__unused RCTPromiseRejectBlock)reject
){
  dispatch_async(dispatch_get_main_queue(), ^(void){
    BranchUniversalObject *branchUniversalObject = [self createBranchUniversalObject:branchUniversalObjectMap];
    BranchLinkProperties *linkProperties = [self createLinkProperties:linkPropertiesMap withControlParams:controlParamsMap];
    
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *fromViewController = (rootViewController.presentedViewController ? rootViewController.presentedViewController : rootViewController);
    [branchUniversalObject showShareSheetWithLinkProperties:linkProperties
                           andShareText:[shareOptionsMap objectForKey:@"messageBody"]
                           fromViewController:fromViewController
                           completion:^(NSString *activityType, BOOL completed){
      NSDictionary *result = @{
        @"channel" : activityType ? activityType : [NSNull null],
        @"completed" : [NSNumber numberWithBool:completed],
        @"error" : [NSNull null]
      };

      resolve(result);
    }];
  });
}

RCT_EXPORT_METHOD(
  registerView:(NSDictionary *)branchUniversalObjectMap
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  BranchUniversalObject *branchUniversalObject = [self createBranchUniversalObject:branchUniversalObjectMap];
  [branchUniversalObject registerViewWithCallback:^(NSDictionary *params, NSError *error) {
    if (!error) {
        resolve([NSNull null]);
    } else {
      reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
    }
  }];
}

RCT_EXPORT_METHOD(
  generateShortUrl:(NSDictionary *)branchUniversalObjectMap
  withLinkProperties:(NSDictionary *)linkPropertiesMap
  withControlParams:(NSDictionary *)controlParamsMap
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  BranchUniversalObject *branchUniversalObject = [self createBranchUniversalObject:branchUniversalObjectMap];
  BranchLinkProperties *linkProperties = [self createLinkProperties:linkProperties withControlParams:controlParamsMap];

  [branchUniversalObject getShortUrlWithLinkProperties:linkProperties andCallback:^(NSString *url, NSError *error) {
    if (!error) {
      NSError *err;
      NSDictionary *jsonObj = [[NSDictionary alloc] initWithObjectsAndKeys:url, @"url", 0, @"options", &err, @"error", nil];

      if (err) {
        NSLog(@"Parsing Error: %@", [err localizedDescription]);
        reject([NSString stringWithFormat: @"%lu", (long)err.code], err.localizedDescription, err);
      } else {
        NSLog(@"RNBranch Success");
        resolve(jsonObj);
      }
    } else {
      reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
    }
  }];
}

RCT_EXPORT_METHOD(
  listOnSpotlight:(NSDictionary *)branchUniversalObjectMap
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  BranchUniversalObject *branchUniversalObject = [self createBranchUniversalObject:branchUniversalObjectMap];
  [branchUniversalObject listOnSpotlightWithCallback:^(NSString *string, NSError *error) {
    if (!error) {
      NSDictionary *data = @{@"result":string};
      resolve(data);
    } else {
      reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
    }
  }];
}

// @TODO can this be removed? legacy, short url should be created from BranchUniversalObject
RCT_EXPORT_METHOD(
  getShortUrl:(NSDictionary *)linkPropertiesMap
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  NSString *feature = [linkPropertiesMap objectForKey:@"feature"];
  NSString *channel = [linkPropertiesMap objectForKey:@"channel"];
  NSString *stage = [linkPropertiesMap objectForKey:@"stage"];
  NSArray *tags = [linkPropertiesMap objectForKey:@"tags"];

  [[Branch getInstance] getShortURLWithParams:linkPropertiesMap
                                      andTags:tags
                                   andChannel:channel
                                   andFeature:feature
                                     andStage:stage
                                  andCallback:^(NSString *url, NSError *error) {
                                      if (error) {
                                          NSLog(@"RNBranch::Error: %@", error.localizedDescription);
                                          reject(@"RNBranch::Error", @"getShortURLWithParams", error);
                                      }
                                      resolve(url);
                                  }];
}

RCT_EXPORT_METHOD(
  loadRewards:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  [[Branch getInstance] loadRewardsWithCallback:^(BOOL changed, NSError *error) {
    if(!error) {
      int credits = (int)[[Branch getInstance] getCredits];
        resolve(@{@"credits": @(credits)});
    } else {
      NSLog(@"Load Rewards Error: %@", [error localizedDescription]);
      reject(@"RNBranch::Error::loadRewardsWithCallback", @"loadRewardsWithCallback", error);
    }
  }];
}

RCT_EXPORT_METHOD(
  redeemRewards:(NSInteger *)amount
  inBucket:(NSString *)bucket
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  if (bucket) {
    [[Branch getInstance] redeemRewards:amount forBucket:bucket callback:^(BOOL changed, NSError *error) {
      if (!error) {
        resolve(@{@"changed": @(changed)});
      } else {
        NSLog(@"Redeem Rewards Error: %@", [error localizedDescription]);
        reject(@"RNBranch::Error::redeemRewards", [error localizedDescription], error);
      }
    }];
  } else {
    [[Branch getInstance] redeemRewards:amount callback:^(BOOL changed, NSError *error) {
      if (!error) {
        resolve(@{@"changed": @(changed)});
      } else {
        NSLog(@"Redeem Rewards Error: %@", [error localizedDescription]);
        reject(@"RNBranch::Error::redeemRewards", [error localizedDescription], error);
      }
    }];
  }
}

RCT_EXPORT_METHOD(
  getCreditHistory:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
){
  [[Branch getInstance] getCreditHistoryWithCallback:^(NSArray *list, NSError *error) {
    if (!error) {
      resolve(list);
    } else {
      NSLog(@"Credit History Error: %@", [error localizedDescription]);
      reject(@"RNBranch::Error::getCreditHistory", [error localizedDescription], error);
    }
  }];
}

@end
