//
//  SUUpdaterDelegate.h
//  Sparkle
//
//  Created by Mayur Pawashe on 12/25/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

#import "SUExport.h"

@protocol SUVersionComparison, SUVersionDisplay;
@class SUUpdater, SUAppcast, SUAppcastItem;

NS_ASSUME_NONNULL_BEGIN

// -----------------------------------------------------------------------------
// SUUpdater Notifications for events that might be interesting to more than just the delegate
// The updater will be the notification object
// -----------------------------------------------------------------------------
SU_EXPORT extern NSString *const SUUpdaterDidFinishLoadingAppCastNotification;
SU_EXPORT extern NSString *const SUUpdaterDidFindValidUpdateNotification;
SU_EXPORT extern NSString *const SUUpdaterDidNotFindUpdateNotification;
SU_EXPORT extern NSString *const SUUpdaterWillRestartNotification;
#define SUUpdaterWillRelaunchApplicationNotification SUUpdaterWillRestartNotification;
#define SUUpdaterWillInstallUpdateNotification SUUpdaterWillRestartNotification;

// Key for the SUAppcastItem object in the SUUpdaterDidFindValidUpdateNotification userInfo
SU_EXPORT extern NSString *const SUUpdaterAppcastItemNotificationKey;
// Key for the SUAppcast object in the SUUpdaterDidFinishLoadingAppCastNotification userInfo
SU_EXPORT extern NSString *const SUUpdaterAppcastNotificationKey;

// -----------------------------------------------------------------------------
//	SUUpdater Delegate:
// -----------------------------------------------------------------------------

/*!
 Provides methods to control the behavior of an SUUpdater object.
 */
@protocol SUUpdaterDelegate <NSObject>
@optional

/*!
 Returns whether to allow Sparkle to pop up.
 
 For example, this may be used to prevent Sparkle from interrupting a setup assistant.
 
 \param updater The SUUpdater instance.
 */
- (BOOL)updaterMayCheckForUpdates:(SUUpdater *)updater;

/*!
 Returns additional parameters to append to the appcast URL's query string.
 
 This is potentially based on whether or not Sparkle will also be sending along the system profile.
 
 \param updater The SUUpdater instance.
 \param sendingProfile Whether the system profile will also be sent.
 
 \return An array of dictionaries with keys: "key", "value", "displayKey", "displayValue", the latter two being specifically for display to the user.
 */
- (NSArray<NSDictionary<NSString *, NSString *> *> *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile;

/*!
 Returns a custom appcast URL.
 
 Override this to dynamically specify the entire URL.
 
 An alternative may be to use SUUpdaterDelegate::feedParametersForUpdater:sendingSystemProfile:
 and let the server handle what kind of feed to provide.
 
 \param updater The SUUpdater instance.
 */
- (nullable NSString *)feedURLStringForUpdater:(SUUpdater *)updater;

/*!
 Returns whether Sparkle should prompt the user about automatic update checks.
 
 Use this to override the default behavior.
 
 \param updater The SUUpdater instance.
 */
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater;

/*!
 Called after Sparkle has downloaded the appcast from the remote server.
 
 Implement this if you want to do some special handling with the appcast once it finishes loading.
 
 \param updater The SUUpdater instance.
 \param appcast The appcast that was downloaded from the remote server.
 */
- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast;

/*!
 Returns the item in the appcast corresponding to the update that should be installed.
 
 If you're using special logic or extensions in your appcast,
 implement this to use your own logic for finding a valid update, if any,
 in the given appcast.
 
 \param appcast The appcast that was downloaded from the remote server.
 \param updater The SUUpdater instance.
 */
- (nullable SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)updater;

/*!
 Called when a valid update is found by the update driver.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be installed.
 */
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)item;

/*!
 Called when a valid update is not found.
 
 \param updater The SUUpdater instance.
 */
- (void)updaterDidNotFindUpdate:(SUUpdater *)updater;

/*!
 Called immediately before downloading the specified update.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be downloaded.
 \param request The mutable URL request that will be used to download the update.
 */
- (void)updater:(SUUpdater *)updater willDownloadUpdate:(SUAppcastItem *)item withRequest:(NSMutableURLRequest *)request;

/*!
 Called immediately after succesfull download of the specified update.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that has been downloaded.
 */
- (void)updater:(SUUpdater *)updater didDownloadUpdate:(SUAppcastItem *)item;

/*!
 Called after the specified update failed to download.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that failed to download.
 \param error The error generated by the failed download.
 */
- (void)updater:(SUUpdater *)updater failedToDownloadUpdate:(SUAppcastItem *)item error:(NSError *)error;

/*!
 Called when the user clicks the cancel button while and update is being downloaded.
 
 \param updater The SUUpdater instance.
 */
- (void)userDidCancelDownload:(SUUpdater *)updater;

/*!
 Called immediately before extracting the specified downloaded update.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be extracted.
 */
- (void)updater:(SUUpdater *)updater willExtractUpdate:(SUAppcastItem *)item;

/*!
 Called immediately after extracting the specified downloaded update.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that has been extracted.
 */
- (void)updater:(SUUpdater *)updater didExtractUpdate:(SUAppcastItem *)item;

/*!
 Called immediately before installing the specified update.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be installed.
 */
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)item;

/*!
 Returns whether the relaunch should be delayed in order to perform other tasks.
 
 This is not called if the user didn't relaunch on the previous update,
 in that case it will immediately restart.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be installed.
 \param invocation The invocation that must be completed with `[invocation invoke]` before continuing with the relaunch.
 
 \return \c YES to delay the relaunch until \p invocation is invoked.
 */
- (BOOL)updater:(SUUpdater *)updater shouldPostponeRelaunchForUpdate:(SUAppcastItem *)item untilInvoking:(NSInvocation *)invocation;

/*!
 Returns whether the application should be relaunched at all.
 
 Some apps \b cannot be relaunched under certain circumstances.
 This method can be used to explicitly prevent a relaunch.
 
 \param updater The SUUpdater instance.
 */
- (BOOL)updaterShouldRelaunchApplication:(SUUpdater *)updater;

/*!
 Called immediately before relaunching.
 
 \param updater The SUUpdater instance.
 */
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater;

/*!
 Called immediately after relaunching. SUUpdater delegate must be set before applicationDidFinishLaunching: to catch this event.
 
 \param updater The SUUpdater instance.
 */
- (void)updaterDidRelaunchApplication:(SUUpdater *)updater;

/*!
 Returns an object that compares version numbers to determine their arithmetic relation to each other.
 
 This method allows you to provide a custom version comparator.
 If you don't implement this method or return \c nil,
 the standard version comparator will be used.
 
 \sa SUStandardVersionComparator
 
 \param updater The SUUpdater instance.
 */
- (nullable id<SUVersionComparison>)versionComparatorForUpdater:(SUUpdater *)updater;

/*!
 Returns an object that formats version numbers for display to the user.
 
 If you don't implement this method or return \c nil,
 the standard version formatter will be used.
 
 \sa SUUpdateAlert
 
 \param updater The SUUpdater instance.
 */
- (nullable id<SUVersionDisplay>)versionDisplayerForUpdater:(SUUpdater *)updater;

/*!
 Returns the path which is used to relaunch the client after the update is installed.
 
 The default is the path of the host bundle.
 
 \param updater The SUUpdater instance.
 */
- (nullable NSString *)pathToRelaunchForUpdater:(SUUpdater *)updater;

/*!
 Called before an updater shows a modal alert window,
 to give the host the opportunity to hide attached windows that may get in the way.
 
 \param updater The SUUpdater instance.
 */
- (void)updaterWillShowModalAlert:(SUUpdater *)updater;

/*!
 Called after an updater shows a modal alert window,
 to give the host the opportunity to hide attached windows that may get in the way.
 
 \param updater The SUUpdater instance.
 */
- (void)updaterDidShowModalAlert:(SUUpdater *)updater;

/*!
 Called when an update is scheduled to be silently installed on quit.
 This is after an update has been automatically downloaded in the background.
 (i.e. SUUpdater::automaticallyDownloadsUpdates is YES)
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that is proposed to be installed.
 \param invocation Can be used to trigger an immediate silent install and relaunch.
 */
- (void)updater:(SUUpdater *)updater willInstallUpdateOnQuit:(SUAppcastItem *)item immediateInstallationInvocation:(NSInvocation *)invocation;

/*!
 Calls after an update that was scheduled to be silently installed on quit has been canceled.
 
 \param updater The SUUpdater instance.
 \param item The appcast item corresponding to the update that was proposed to be installed.
 */
- (void)updater:(SUUpdater *)updater didCancelInstallUpdateOnQuit:(SUAppcastItem *)item;

/*!
 Called after an update is aborted due to an error.
 
 \param updater The SUUpdater instance.
 \param error The error that caused the abort
 */
- (void)updater:(SUUpdater *)updater didAbortWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
