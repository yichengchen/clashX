//
//  SUCodeSigningVerifier.h
//  Sparkle
//
//  Created by Andy Matuschak on 7/5/12.
//
//

#ifndef SUCODESIGNINGVERIFIER_H
#define SUCODESIGNINGVERIFIER_H

#import <Foundation/Foundation.h>
#import "SUExport.h"

SU_EXPORT @interface SUCodeSigningVerifier : NSObject
+ (BOOL)codeSignatureAtBundleURL:(NSURL *)oldBundlePath matchesSignatureAtBundleURL:(NSURL *)newBundlePath error:(NSError  **)error;
+ (BOOL)codeSignatureIsValidAtBundleURL:(NSURL *)bundlePath error:(NSError **)error;
+ (BOOL)bundleAtURLIsCodeSigned:(NSURL *)bundlePath;
+ (NSDictionary *)codeSignatureInfoAtBundleURL:(NSURL *)bundlePath;
@end

#endif
