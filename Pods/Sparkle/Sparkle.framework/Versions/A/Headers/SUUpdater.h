//
//  SUUpdater.h
//  Sparkle
//
//  Created by Andy Matuschak on 1/4/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUUPDATER_H
#define SUUPDATER_H

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "SUExport.h"
#import "SUVersionComparisonProtocol.h"
#import "SUVersionDisplayProtocol.h"

@class SUAppcastItem, SUAppcast;

@protocol SUUpdaterDelegate;

/*!
    The main API in Sparkle for controlling the update mechanism.

    This class is used to configure the update paramters as well as manually
    and automatically schedule and control checks for updates.
 */
SU_EXPORT @interface SUUpdater : NSObject

@property (unsafe_unretained) IBOutlet id<SUUpdaterDelegate> delegate;

/*!
 The shared updater for the main bundle.
 
 This is equivalent to passing [NSBundle mainBundle] to SUUpdater::updaterForBundle:
 */
+ (SUUpdater *)sharedUpdater;

/*!
 The shared updater for a specified bundle.

 If an updater has already been initialized for the provided bundle, that shared instance will be returned.
 */
+ (SUUpdater *)updaterForBundle:(NSBundle *)bundle;

/*!
 Designated initializer for SUUpdater.
 
 If an updater has already been initialized for the provided bundle, that shared instance will be returned.
 */
- (instancetype)initForBundle:(NSBundle *)bundle;

/*!
 Explicitly checks for updates and displays a progress dialog while doing so.

 This method is meant for a main menu item.
 Connect any menu item to this action in Interface Builder,
 and Sparkle will check for updates and report back its findings verbosely
 when it is invoked.

 This will find updates that the user has opted into skipping.
 */
- (IBAction)checkForUpdates:(id)sender;

/*!
 The menu item validation used for the -checkForUpdates: action
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;

/*!
 Checks for updates, but does not display any UI unless an update is found.

 This is meant for programmatically initating a check for updates. That is,
 it will display no UI unless it actually finds an update, in which case it
 proceeds as usual.

 If automatic downloading of updates it turned on and allowed, however,
 this will invoke that behavior, and if an update is found, it will be downloaded
 in the background silently and will be prepped for installation.

 This will not find updates that the user has opted into skipping.
 */
- (void)checkForUpdatesInBackground;

/*!
 A property indicating whether or not to check for updates automatically.

 Setting this property will persist in the host bundle's user defaults.
 The update schedule cycle will be reset in a short delay after the property's new value is set.
 This is to allow reverting this property without kicking off a schedule change immediately
 */
@property BOOL automaticallyChecksForUpdates;

/*!
 A property indicating whether or not updates can be automatically downloaded in the background.

 Note that automatic downloading of updates can be disallowed by the developer
 or by the user's system if silent updates cannot be done (eg: if they require authentication).
 In this case, -automaticallyDownloadsUpdates will return NO regardless of how this property is set.

 Setting this property will persist in the host bundle's user defaults.
 */
@property BOOL automaticallyDownloadsUpdates;

/*!
 A property indicating the current automatic update check interval.

 Setting this property will persist in the host bundle's user defaults.
 The update schedule cycle will be reset in a short delay after the property's new value is set.
 This is to allow reverting this property without kicking off a schedule change immediately
 */
@property NSTimeInterval updateCheckInterval;

/*!
 Begins a "probing" check for updates which will not actually offer to
 update to that version.

 However, the delegate methods
 SUUpdaterDelegate::updater:didFindValidUpdate: and
 SUUpdaterDelegate::updaterDidNotFindUpdate: will be called,
 so you can use that information in your UI.

 Updates that have been skipped by the user will not be found.
 */
- (void)checkForUpdateInformation;

/*!
 The URL of the appcast used to download update information.

 Setting this property will persist in the host bundle's user defaults.
 If you don't want persistence, you may want to consider instead implementing
 SUUpdaterDelegate::feedURLStringForUpdater: or SUUpdaterDelegate::feedParametersForUpdater:sendingSystemProfile:

 This property must be called on the main thread.
 */
@property (copy) NSURL *feedURL;

/*!
 The host bundle that is being updated.
 */
@property (readonly, strong) NSBundle *hostBundle;

/*!
 The bundle this class (SUUpdater) is loaded into.
 */
@property (strong, readonly) NSBundle *sparkleBundle;

/*!
 The user agent used when checking for updates.

 The default implementation can be overrided.
 */
@property (nonatomic, copy) NSString *userAgentString;

/*!
 The HTTP headers used when checking for updates.

 The keys of this dictionary are HTTP header fields (NSString) and values are corresponding values (NSString)
 */
@property (copy) NSDictionary<NSString *, NSString *> *httpHeaders;

/*!
 A property indicating whether or not the user's system profile information is sent when checking for updates.

 Setting this property will persist in the host bundle's user defaults.
 */
@property BOOL sendsSystemProfile;

/*!
 A property indicating the decryption password used for extracting updates shipped as Apple Disk Images (dmg)
 */
@property (nonatomic, copy) NSString *decryptionPassword;

/*!
    This function ignores normal update schedule, ignores user preferences,
    and interrupts users with an unwanted immediate app update.

    WARNING: this function should not be used in regular apps. This function
    is a user-unfriendly hack only for very special cases, like unstable
    rapidly-changing beta builds that would not run correctly if they were
    even one day out of date.

    Instead of this function you should set `SUAutomaticallyUpdate` to `YES`,
    which will gracefully install updates when the app quits.

    For UI-less/daemon apps that aren't usually quit, instead of this function,
    you can use the delegate method
    SUUpdaterDelegate::updater:willInstallUpdateOnQuit:immediateInstallationInvocation:
    to immediately start installation when an update was found.

    A progress dialog is shown but the user will never be prompted to read the
    release notes.

    This function will cause update to be downloaded twice if automatic updates are
    enabled.

    You may want to respond to the userDidCancelDownload delegate method in case
    the user clicks the "Cancel" button while the update is downloading.
 */
- (void)installUpdatesIfAvailable;

/*!
    Returns the date of last update check.

    \returns \c nil if no check has been performed.
 */
@property (readonly, copy) NSDate *lastUpdateCheckDate;

/*!
    Appropriately schedules or cancels the update checking timer according to
    the preferences for time interval and automatic checks.

    This call does not change the date of the next check,
    but only the internal NSTimer.
 */
- (void)resetUpdateCycle;

/*!
   A property indicating whether or not an update is in progress.

   Note this property is not indicative of whether or not user initiated updates can be performed.
   Use SUUpdater::validateMenuItem: for that instead.
 */
@property (readonly) BOOL updateInProgress;

@end

#endif
