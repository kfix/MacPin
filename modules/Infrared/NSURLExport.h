//
// Created by Uros Milivojevic on 3/10/15.
// Copyright (c) 2015 infrared.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol NSURLExport <JSExport>

/* Convenience initializers
 */
//- (instancetype)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path; // this call percent-encodes both the host and path, so this cannot be used to set a username/password or port in the hostname part or with a IPv6 '[...]' type address; use initWithString: and construct the string yourself in those cases

//- (instancetype)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir NS_AVAILABLE(10_5, 2_0) NS_DESIGNATED_INITIALIZER;
//- (instancetype)initFileURLWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;  // Better to use initFileURLWithPath:isDirectory: if you know if the path is a directory vs non-directory, as it saves an i/o.

+ (NSURL *)fileURLWithPath:(NSString *)path isDirectory:(BOOL) isDir NS_AVAILABLE(10_5, 2_0);
+ (NSURL *)fileURLWithPath:(NSString *)path; // Better to use fileURLWithPath:isDirectory: if you know if the path is a directory vs non-directory, as it saves an i/o.

/* Initializes a newly created URL referencing the local file or directory at the file system representation of the path. File system representation is a null-terminated C string with canonical UTF-8 encoding.
 */
//- (instancetype)initFileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL NS_AVAILABLE(10_9, 7_0) NS_DESIGNATED_INITIALIZER;

/* Initializes and returns a newly created URL referencing the local file or directory at the file system representation of the path. File system representation is a null-terminated C string with canonical UTF-8 encoding.
 */
+ (NSURL *)fileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL) isDir relativeToURL:(NSURL *)baseURL NS_AVAILABLE(10_9, 7_0);

/* These methods expect their string arguments to contain any percent escape codes that are necessary. It is an error for URLString to be nil.
 */
//- (instancetype)initWithString:(NSString *)URLString;
//- (instancetype)initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL NS_DESIGNATED_INITIALIZER;
+ (instancetype)URLWithString:(NSString *)URLString;
+ (instancetype)URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL;


@property (readonly, copy) NSString *absoluteString;
@property (readonly, copy) NSString *relativeString; // The relative portion of a URL.  If baseURL is nil, or if the receiver is itself absolute, this is the same as absoluteString
@property (readonly, copy) NSURL *baseURL; // may be nil.
@property (readonly, copy) NSURL *absoluteURL; // if the receiver is itself absolute, this will return self.

/* Any URL is composed of these two basic pieces.  The full URL would be the concatenation of [myURL scheme], ':', [myURL resourceSpecifier]
 */
@property (readonly, copy) NSString *scheme;
@property (readonly, copy) NSString *resourceSpecifier;

/* If the URL conforms to rfc 1808 (the most common form of URL), the following accessors will return the various components; otherwise they return nil.  The litmus test for conformance is as recommended in RFC 1808 - whether the first two characters of resourceSpecifier is @"//".  In all cases, they return the component's value after resolving the receiver against its base URL.
 */
@property (readonly, copy) NSString *host;
@property (readonly, copy) NSNumber *port;
@property (readonly, copy) NSString *user;
@property (readonly, copy) NSString *password;
@property (readonly, copy) NSString *path;
@property (readonly, copy) NSString *fragment;
@property (readonly, copy) NSString *parameterString;
@property (readonly, copy) NSString *query;
@property (readonly, copy) NSString *relativePath; // The same as path if baseURL is nil

/* Returns the URL's path in file system representation. File system representation is a null-terminated C string with canonical UTF-8 encoding.
 */
- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxBufferLength NS_AVAILABLE(10_9, 7_0);

/* Returns the URL's path in file system representation. File system representation is a null-terminated C string with canonical UTF-8 encoding. The returned C string will be automatically freed just as a returned object would be released; your code should copy the representation or use getFileSystemRepresentation:maxLength: if it needs to store the representation outside of the autorelease context in which the representation is created.
 */
@property (readonly) __strong const char *fileSystemRepresentation NS_RETURNS_INNER_POINTER NS_AVAILABLE(10_9, 7_0);

@property (readonly, getter=isFileURL) BOOL fileURL; // Whether the scheme is file:; if [myURL isFileURL] is YES, then [myURL path] is suitable for input into NSFileManager or NSPathUtilities.

@property (readonly, copy) NSURL *standardizedURL;


/* Returns whether the URL's resource exists and is reachable. This method synchronously checks if the resource's backing store is reachable. Checking reachability is appropriate when making decisions that do not require other immediate operations on the resource, e.g. periodic maintenance of UI state that depends on the existence of a specific document. When performing operations such as opening a file or copying resource properties, it is more efficient to simply try the operation and handle failures. If this method returns NO, the optional error is populated. This method is currently applicable only to URLs for file system resources. For other URL types, NO is returned. Symbol is present in iOS 4, but performs no operation.
 */
- (BOOL)checkResourceIsReachableAndReturnError:(NSError **)error NS_AVAILABLE(10_6, 4_0);


/* Working with file reference URLs
 */

/* Returns whether the URL is a file reference URL. Symbol is present in iOS 4, but performs no operation.
 */
- (BOOL)isFileReferenceURL NS_AVAILABLE(10_6, 4_0);

/* Returns a file reference URL that refers to the same resource as a specified file URL. File reference URLs use a URL path syntax that identifies a file system object by reference, not by path. This form of file URL remains valid when the file system path of the URL’s underlying resource changes. An error will occur if the url parameter is not a file URL. File reference URLs cannot be created to file system objects which do not exist or are not reachable. In some areas of the file system hierarchy, file reference URLs cannot be generated to the leaf node of the URL path. A file reference URL's path should never be persistently stored because is not valid across system restarts, and across remounts of volumes -- if you want to create a persistent reference to a file system object, use a bookmark (see -bookmarkDataWithOptions:includingResourceValuesForKeys:relativeToURL:error:). Symbol is present in iOS 4, but performs no operation.
 */
- (NSURL *)fileReferenceURL NS_AVAILABLE(10_6, 4_0);

/* Returns a file path URL that refers to the same resource as a specified URL. File path URLs use a file system style path. An error will occur if the url parameter is not a file URL. A file reference URL's resource must exist and be reachable to be converted to a file path URL. Symbol is present in iOS 4, but performs no operation.
 */
@property (readonly, copy) NSURL *filePathURL NS_AVAILABLE(10_6, 4_0);


/* Resource access

 The behavior of resource value caching is slightly different between the NSURL and CFURL API.

 When the NSURL methods which get, set, or use cached resource values are used from the main thread, resource values cached by the URL (except those added as temporary properties) are removed the next time the main thread's run loop runs. -removeCachedResourceValueForKey: and -removeAllCachedResourceValues also may be used to remove cached resource values.

 The CFURL functions do not automatically remove any resource values cached by the URL. The client has complete control over the cache lifetime. If you are using CFURL API, you must use CFURLClearResourcePropertyCacheForKey or CFURLClearResourcePropertyCache to remove cached resource values.
 */

/* Returns the resource value identified by a given resource key. This method first checks if the URL object already caches the resource value. If so, it returns the cached resource value to the caller. If not, then this method synchronously obtains the resource value from the backing store, adds the resource value to the URL object's cache, and returns the resource value to the caller. The type of the resource value varies by resource property (see resource key definitions). If this method returns YES and value is populated with nil, it means the resource property is not available for the specified resource and no errors occurred when determining the resource property was not available. If this method returns NO, the optional error is populated. This method is currently applicable only to URLs for file system resources. Symbol is present in iOS 4, but performs no operation.
 */
- (BOOL)getResourceValue:(out id *)value forKey:(NSString *)key error:(out NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Returns the resource values identified by specified array of resource keys. This method first checks if the URL object already caches the resource values. If so, it returns the cached resource values to the caller. If not, then this method synchronously obtains the resource values from the backing store, adds the resource values to the URL object's cache, and returns the resource values to the caller. The type of the resource values vary by property (see resource key definitions). If the result dictionary does not contain a resource value for one or more of the requested resource keys, it means those resource properties are not available for the specified resource and no errors occurred when determining those resource properties were not available. If this method returns NULL, the optional error is populated. This method is currently applicable only to URLs for file system resources. Symbol is present in iOS 4, but performs no operation.
 */
- (NSDictionary *)resourceValuesForKeys:(NSArray *)keys error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Sets the resource value identified by a given resource key. This method writes the new resource value out to the backing store. Attempts to set a read-only resource property or to set a resource property not supported by the resource are ignored and are not considered errors. If this method returns NO, the optional error is populated. This method is currently applicable only to URLs for file system resources. Symbol is present in iOS 4, but performs no operation.
 */
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Sets any number of resource values of a URL's resource. This method writes the new resource values out to the backing store. Attempts to set read-only resource properties or to set resource properties not supported by the resource are ignored and are not considered errors. If an error occurs after some resource properties have been successfully changed, the userInfo dictionary in the returned error contains an array of resource keys that were not set with the key kCFURLKeysOfUnsetValuesKey. The order in which the resource values are set is not defined. If you need to guarantee the order resource values are set, you should make multiple requests to this method or to -setResourceValue:forKey:error: to guarantee the order. If this method returns NO, the optional error is populated. This method is currently applicable only to URLs for file system resources. Symbol is present in iOS 4, but performs no operation.
 */
- (BOOL)setResourceValues:(NSDictionary *)keyedValues error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Removes the cached resource value identified by a given resource value key from the URL object. Removing a cached resource value may remove other cached resource values because some resource values are cached as a set of values, and because some resource values depend on other resource values (temporary resource values have no dependencies). This method is currently applicable only to URLs for file system resources.
 */
- (void)removeCachedResourceValueForKey:(NSString *)key NS_AVAILABLE(10_9, 7_0);

/* Removes all cached resource values and all temporary resource values from the URL object. This method is currently applicable only to URLs for file system resources.
 */
- (void)removeAllCachedResourceValues NS_AVAILABLE(10_9, 7_0);

/* Sets a temporary resource value on the URL object. Temporary resource values are for client use. Temporary resource values exist only in memory and are never written to the resource's backing store. Once set, a temporary resource value can be copied from the URL object with -getResourceValue:forKey:error: or -resourceValuesForKeys:error:. To remove a temporary resource value from the URL object, use -removeCachedResourceValueForKey:. Care should be taken to ensure the key that identifies a temporary resource value is unique and does not conflict with system defined keys (using reverse domain name notation in your temporary resource value keys is recommended). This method is currently applicable only to URLs for file system resources.
 */
- (void)setTemporaryResourceValue:(id)value forKey:(NSString *)key NS_AVAILABLE(10_9, 7_0);

/*
 The File System Resource Keys

 URLs to file system resources support the properties defined below. Note that not all property values will exist for all file system URLs. For example, if a file is located on a volume that does not support creation dates, it is valid to request the creation date property, but the returned value will be nil, and no error will be generated.
 */

/* Returns bookmark data for the URL, created with specified options and resource values. If this method returns nil, the optional error is populated.
 */
- (NSData *)bookmarkDataWithOptions:(NSURLBookmarkCreationOptions)options includingResourceValuesForKeys:(NSArray *)keys relativeToURL:(NSURL *)relativeURL error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Initializes a newly created NSURL that refers to a location specified by resolving bookmark data. If this method returns nil, the optional error is populated.
 */
//- (instancetype)initByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error NS_AVAILABLE(10_6, 4_0);
/* Creates and Initializes an NSURL that refers to a location specified by resolving bookmark data. If this method returns nil, the optional error is populated.
 */
+ (instancetype)URLByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Returns the resource values for properties identified by a specified array of keys contained in specified bookmark data. If the result dictionary does not contain a resource value for one or more of the requested resource keys, it means those resource properties are not available in the bookmark data.
 */
+ (NSDictionary *)resourceValuesForKeys:(NSArray *)keys fromBookmarkData:(NSData *)bookmarkData NS_AVAILABLE(10_6, 4_0);

/* Creates an alias file on disk at a specified location with specified bookmark data. bookmarkData must have been created with the NSURLBookmarkCreationSuitableForBookmarkFile option. bookmarkFileURL must either refer to an existing file (which will be overwritten), or to location in an existing directory. If this method returns NO, the optional error is populated.
*/
+ (BOOL)writeBookmarkData:(NSData *)bookmarkData toURL:(NSURL *)bookmarkFileURL options:(NSURLBookmarkFileCreationOptions)options error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Initializes and returns bookmark data derived from an alias file pointed to by a specified URL. If bookmarkFileURL refers to an alias file created prior to OS X v10.6 that contains Alias Manager information but no bookmark data, this method synthesizes bookmark data for the file. If this method returns nil, the optional error is populated.
*/
+ (NSData *)bookmarkDataWithContentsOfURL:(NSURL *)bookmarkFileURL error:(NSError **)error NS_AVAILABLE(10_6, 4_0);

/* Creates and initializes a NSURL that refers to the location specified by resolving the alias file at url. If the url argument does not refer to an alias file as defined by the NSURLIsAliasFileKey property, the NSURL returned is the same as url argument. This method fails and returns nil if the url argument is unreachable, or if the original file or directory could not be located or is not reachable, or if the original file or directory is on a volume that could not be located or mounted. If this method fails, the optional error is populated. The NSURLBookmarkResolutionWithSecurityScope option is not supported by this method.
 */
+ (instancetype)URLByResolvingAliasFileAtURL:(NSURL *)url options:(NSURLBookmarkResolutionOptions)options error:(NSError **)error NS_AVAILABLE(10_10, 8_0);

/*  Given a NSURL created by resolving a bookmark data created with security scope, make the resource referenced by the url accessible to the process. When access to this resource is no longer needed the client must call stopAccessingSecurityScopedResource. Each call to startAccessingSecurityScopedResource must be balanced with a call to stopAccessingSecurityScopedResource (Note: this is not reference counted).
 */
- (BOOL)startAccessingSecurityScopedResource NS_AVAILABLE(10_7, 8_0);

/*  Revokes the access granted to the url by a prior successful call to startAccessingSecurityScopedResource.
 */
- (void)stopAccessingSecurityScopedResource NS_AVAILABLE(10_7, 8_0);

@end