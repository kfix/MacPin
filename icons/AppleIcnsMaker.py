#!/usr/bin/env python
#-*-python-*-
#========================
#Copyright 2013 to Lane128 on github
#Version v1.0
# https://github.com/lane128/AppleIcnsMaker
# https://raw.githubusercontent.com/lane128/AppleIcnsMaker/master/AppleIcnsMaker.py
#========================
import argparse,shutil
import os,sys

def ImageProcess(tagImage):
	if type(tagImage)!='str':
		tagImage=str(tagImage[0])
	if not os.path.isfile(tagImage):
		print '>>>Error path, please choose the png image path.'
		sys.exit()
	filePath=os.path.realpath(tagImage)
	dirPath=os.path.dirname(filePath)
	fileInfo=os.path.basename(filePath)
	fileEx=fileInfo.split('.')[-1]
	if fileEx=='png':
		fileName=fileInfo[:-4]
		createDirName=fileName+'.iconset'
		createDir=dirPath+'/'+createDirName
		if os.path.exists(createDir):
			print '>>>The old dir exists,ready to delete.'
			os.system('rm -rf '+createDir)
			print '>>>delete!'
		print '>>>Ready to create the iconset dir.'
		os.mkdir(createDir)
		print '>>>Creation finished!'
		sizeList=[16,32,128,256,512]
		for size in sizeList:
			finalName='icon_'+str(size)+'x'+str(size)+'.'+fileEx
			xfinalName='icon_'+str(size)+'x'+str(size)+'@2x.'+fileEx
			os.system('sips -Z '+str(size)+' '+filePath+' --out '+dirPath+'/'+createDirName+'/'+finalName)
			print '>>> '+finalName+'  Done!'
			os.system('sips -Z '+str(size*2)+' '+filePath+' --out '+dirPath+'/'+createDirName+'/'+xfinalName)
			print '>>> '+xfinalName+' Done!'
		print '>>>Copy and make pngs finished!'
		icnsName=fileName+'.icns'
		os.system('iconutil -c icns '+dirPath+'/'+createDirName+' -o '+dirPath+'/'+icnsName)
		print '>>> '+icnsName+' finished~'
	else:
		print '>>>Not a png image.'
	

parser = argparse.ArgumentParser(description="Apple icns process by Lane128.",
	formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-v',"--version",action="version",version="%(prog)s v1.0",
	default=None)
parser.add_argument("-p","--process",action="store",nargs=1,metavar='imagePath',
	help="create the iconset and make icns from png image.")
args=parser.parse_args()

if args.process==None and args.version==None:
	print parser.format_help()
if args.process:
	ImageProcess(args.process)
if args.version:
	parser.parse_args(['--version'])

