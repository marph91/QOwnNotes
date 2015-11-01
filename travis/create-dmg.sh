#!/bin/bash

#
# creating the QOwnNotes.dmg with Applications link
#

QTDIR="/usr/local/opt/qt5"
APP=QOwnNotes
# this directory name will also be shown in the title when the DMG is mounted
TEMPDIR=$APP
SIGNATURE="Patrizio Bekerle"
NAME=`uname`

if [ "$NAME" != "Darwin" ]; then
    echo "This is not a Mac"
    exit 1
fi

#echo "Changing bundle identifier"
#sed -i -e 's/com.yourcompany.QOwnNotes/com.PBE.QOwnNotes/g' QOwnNotes.app/Contents/Info.plist
## removing backup plist
#rm -f QOwnNotes.app/Contents/Info.plist-e

echo "Adding keys"
# add the keys for OSX code signing
security create-keychain -p travis osx-build.keychain
security import ../travis/osx/apple.cer -k ~/Library/Keychains/osx-build.keychain -T /usr/bin/codesign
security import ../travis/osx/dist.cer -k ~/Library/Keychains/osx-build.keychain -T /usr/bin/codesign
security import ../travis/osx/dist.p12 -k ~/Library/Keychains/osx-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
security default-keychain -s osx-build.keychain
security unlock-keychain -p travis osx-build.keychain

# use macdeployqt to deploy the application
echo "Calling macdeployqt and code signing application"
$QTDIR/bin/macdeployqt ./$APP.app -codesign="$DEVELOPER_NAME"
if [ "$?" -ne "0" ]; then
    echo "Failed to run macdeployqt"
    # remove keys
    security delete-keychain osx-build.keychain 
    exit 1
fi

echo "Verifying code signed app"
codesign --verify --verbose=4 ./$APP.app

echo "Create $TEMPDIR"
#Create a temporary directory if one doesn't exist
mkdir -p $TEMPDIR
if [ "$?" -ne "0" ]; then
    echo "Failed to create temporary folder"
    exit 1
fi

echo "Clean $TEMPDIR"
#Delete the contents of any previous builds
rm -Rf ./$TEMPDIR/*
if [ "$?" -ne "0" ]; then
    echo "Failed to clean temporary folder"
    exit 1
fi

echo "Move application bundle"
#Move the application to the temporary directory
mv ./$APP.app ./$TEMPDIR
if [ "$?" -ne "0" ]; then
    echo "Failed to move application bundle"
    exit 1
fi

#echo "Sign the code"
##This signs the code
#echo "Sign Code with $SIGNATURE"
#codesign -s "$SIGNATURE" -f ./$TEMPDIR/$APP.app
#if [ "$?" -ne "0" ]; then
#    echo "Failed to sign app bundle"
#    exit 1
#fi

echo "Create symbolic link"
#Create a symbolic link to the applications folder
ln -s /Applications ./$TEMPDIR/Applications
if [ "$?" -ne "0" ]; then
    echo "Failed to create link to /Applications"
    exit 1
fi

echo "Create new disk image"
#Create the disk image
rm -f ./$APP.dmg
hdiutil create -srcfolder ./$TEMPDIR -format UDBZ ./$APP.dmg
if [ "$?" -ne "0" ]; then
    echo "Failed to create disk image"
    exit 1
fi

echo "Code signing disk image"
codesign --force --verify --verbose --sign "$DEVELOPER_NAME" ./$APP.dmg

echo "Verifying code signed disk image"
codesign --verify --verbose=4 ./$APP.dmg

echo "Removing keys"
# remove keys
security delete-keychain osx-build.keychain 

# delete the temporary directory
rm -Rf ./$TEMPDIR/*
if [ "$?" -ne "0" ]; then
    echo "Failed to clean temporary folder"
    exit 1
fi

exit 0
