# my releases are unsigned affairs
release:			appsig :=
release:			codesign :=

# XCode->Preferences->Accounts (add Apple ID, then create cert)
# goto Keychain.app and look for ‘@keychain:Application Loader: {appleId}’ in local keychain

#appsig				:= MacPin_hacker_Extraordinaire@example.com
#mobileprov_team_id := ABC123OKOK
