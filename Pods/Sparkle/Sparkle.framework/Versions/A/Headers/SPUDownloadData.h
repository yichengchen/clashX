//
//  SPUDownloadData.h
//  Sparkle
//
//  Created by Mayur Pawashe on 8/10/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

#import "SUExport.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 * A class for containing downloaded data along with some information about it.
 */
SU_EXPORT @interface SPUDownloadData : NSObject <NSSecureCoding>

- (instancetype)initWithData:(NSData *)data textEncodingName:(NSString * _Nullable)textEncodingName MIMEType:(NSString * _Nullable)MIMEType;

/*!
 * The raw data that was downloaded.
 */
@property (nonatomic, readonly) NSData *data;

/*!
 * The IANA charset encoding name if available. Eg: "utf-8"
 */
@property (nonatomic, readonly, nullable, copy) NSString *textEncodingName;

/*!
 * The MIME type if available. Eg: "text/plain"
 */
@property (nonatomic, readonly, nullable, copy) NSString *MIMEType;

@end

NS_ASSUME_NONNULL_END
