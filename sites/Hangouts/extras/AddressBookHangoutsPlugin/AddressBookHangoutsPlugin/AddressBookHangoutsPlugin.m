//
//  AddressBookHangoutsPlugin.m
//  AddressBookHangoutsPlugin
//
//  Created by Joey Korkames on 2/25/15.
//  Copyright (c) 2015 Joey Korkames. All rights reserved.
//

#import "AddressBookHangoutsPlugin.h"

@implementation AddressBookHangoutsPlugin

// This action works with phone numbers.
- (NSString *)actionProperty
{
    return kABPhoneProperty;
}

- (NSString *)titleForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    ABMultiValue *values = [person valueForProperty:[self actionProperty]];
    NSString *value = [values valueForIdentifier:identifier];

    return [NSString stringWithFormat:@"Hangout with %@", value];
}

- (void)performActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    ABMultiValue *values = [person valueForProperty:[self actionProperty]];
    NSString *phonenumber = [values valueForIdentifier:identifier];
	NSURL *hangurl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"hangouts:%@", phonenumber]];

	[[NSWorkspace sharedWorkspace] openURL:hangurl];
}

// Optional. Your action will always be enabled in the absence of this method. As
// above, this method is passed information about the data item rolled over.
- (BOOL)shouldEnableActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    return YES;
}

@end
