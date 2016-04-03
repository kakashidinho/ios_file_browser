#import "PXRFileBrowser.h"
#import "PXRFileBrowserTableData.h"
#import "UIView+Additions.h"

@interface PXRFileBrowser()
@property (strong) NSString* parentPath;
@end

@implementation PXRFileBrowser
@synthesize delegate;
@synthesize fileNameField;
@synthesize currentPath;
@synthesize fileTableView;
@synthesize backButton;
@synthesize folderContents;
@synthesize folderTitle;
@synthesize folderNameField;
@synthesize saveOptions;
@synthesize folderDialog;

- (void)setup{
	tableData = [[PXRFileBrowserTableData alloc] init];
	tableData.delegate = self;
	[tableData addSection];
	[self initSizings];
	isEditingText = NO;
	_sortMode = kPXRFileBrowserSortModeNone;//LHQ: default sort mode
	_autoLoadPickedFile = YES;//LHQ
}

- (void)initSizings{
	ipadPortraitNormal = CGRectMake(0, 0, 544, 624);
	ipadPortraitEditing = CGRectMake(0, 0, 544, 550);
	ipadLandscapeNormal = CGRectMake(0, 0, 544, 624);
	ipadLandscapeEditing = CGRectMake(0, 0, 544, 396);
	
	if([UIApplication sharedApplication].statusBarHidden){
		iphonePortraitNormal = CGRectMake(0, 0, 320, 480);
		iphonePortraitEditing = CGRectMake(0, 108, 320, 266);
		iphoneLandscapeNormal = CGRectMake(0, 0, 480, 320);
		iphoneLandscapeEditing = CGRectMake(0, 82, 480, 160);
	}else{
		iphonePortraitNormal = CGRectMake(0, 0, 320, 460);
		iphonePortraitEditing = CGRectMake(0, 108, 320, 246);
		iphoneLandscapeNormal = CGRectMake(0, 0, 480, 300);
		iphoneLandscapeEditing = CGRectMake(0, 82, 480, 140);
	}
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	self.modalPresentationStyle = UIModalPresentationFormSheet;
	self.modalInPopover = YES;
	[self setup];
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
	self = [super initWithCoder:aDecoder];
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	self.modalPresentationStyle = UIModalPresentationFormSheet;
	self.modalInPopover = YES;
	[self setup];
	return self;
}


- (void)viewDidLoad{
	fileTableView.delegate = self;
	[fileTableView setDataSource:tableData];
	if (currentPath == nil)
		[self resetPath];
	else
		[self refreshView];
	
	folderDialog.hidden = true;
	
	folderNameField.delegate = self;
	fileNameField.delegate = self;
	
	saveOptions.hidden = (browserMode == kPXRFileBrowserModeLoad);
	
 	[super viewDidLoad];
}

- (void)resetPath{
	//documents folder
	NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [documentPaths objectAtIndex:0];
	
	currentPath = documentsDirectory;
	
	[self refreshView];
}

- (void)refreshView{
	int fileCount = 0;
	[tableData removeAllItemsInSection:0];
	
	if ([currentPath characterAtIndex:[currentPath length] - 1] != '/')
		currentPath = [currentPath stringByAppendingString:@"/"];
	
	// populate data 
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:currentPath error:NULL];
	files = [self sortFilesList:files];//LHQ
	NSString *currFile;
	BOOL isDir;
	for(NSString *file in files){
		currFile = [currentPath stringByAppendingString:file];
		// send to the table view
		[[NSFileManager defaultManager] fileExistsAtPath:currFile isDirectory:&isDir];
		if(![self fileShouldBeHidden:file] && browserMode == kPXRFileBrowserModeSave){
			// it's not a hidden file so show it
			[tableData addItem:[PXRFileBrowserItem itemWithTitle:file andPath:currFile isDirectory:isDir] toSection:0];
			fileCount ++;
		}else if(![self fileShouldBeHidden:file] && browserMode == kPXRFileBrowserModeLoad){
			NSString *ext = [currFile pathExtension];
			BOOL isFileType = false;
			for(NSString *ft in fileTypes){
				if([ft isEqualToString:ext] || [ft isEqualToString:@"*"]){
					isFileType = true;
				}
			}
			// check the file extention
			PXRFileBrowserItem *item = [PXRFileBrowserItem itemWithTitle:file andPath:currFile isDirectory:isDir];
			if(!isDir){
				item.isSelectable = isFileType;
			}
			[tableData addItem:item toSection:0];
			fileCount ++;
		}
	}
	// check back button
	BOOL hasParentDir = NO;
	NSString* parentDir = [currentPath stringByDeletingLastPathComponent];
	if (parentDir != nil && [parentDir length] > 0 &&
		[[NSFileManager defaultManager] fileExistsAtPath:parentDir isDirectory:&hasParentDir] &&
		[[NSFileManager defaultManager] isReadableFileAtPath:parentDir] &&
		hasParentDir) {
		backButton.userInteractionEnabled = true;
		backButton.alpha = 1;
		
		_parentPath = parentDir;
	}
	else{
		backButton.userInteractionEnabled = false;
		backButton.alpha = .2;
		
		_parentPath = nil;
	}
	
	if(fileCount == 1) {
		folderContents.text = [NSString stringWithFormat:@"%d item", fileCount]; 
	}else{
		folderContents.text = [NSString stringWithFormat:@"%d items", fileCount]; 
	}
	
	folderTitle.text = [currentPath lastPathComponent];
	
	[fileTableView reloadData];
}

//LHQ
- (NSArray<NSString*>*) sortFilesList: (NSArray*) list {
	NSComparisonResult (^sortCompare) (NSString* file1, NSString* file2) = ^(NSString* file1, NSString* file2){
		NSString* file1FullPath = [NSString stringWithFormat:@"%@/%@", currentPath, file1];
		NSString* file2FullPath = [NSString stringWithFormat:@"%@/%@", currentPath, file2];
		
		NSURL* file1URL = [NSURL fileURLWithPath:file1FullPath];
		NSURL* file2URL = [NSURL fileURLWithPath:file2FullPath];
		
		NSError* error;
		NSDate *file1Date, *file2Date;
		BOOL isFile1Directory = NO, isFile2Directory = NO;
		
		[[NSFileManager defaultManager] fileExistsAtPath:file1FullPath isDirectory:&isFile1Directory];
		[[NSFileManager defaultManager] fileExistsAtPath:file2FullPath isDirectory:&isFile2Directory];
		
		if (isFile1Directory != isFile2Directory)
		{
			//directory should be listed first
			if (isFile1Directory)
				return NSOrderedAscending;
			else
				return NSOrderedDescending;
		}
		
		//get modification dates
		error = nil;
		[file1URL getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:&error];
		if (error)
			file1Date = [NSDate dateWithTimeIntervalSince1970:0];//assume very old file on error
		
		error = nil;
		[file2URL getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:&error];
		if (error)
			file2Date = [NSDate dateWithTimeIntervalSince1970:0];//assume very old file on error
		
		//compare modification dates
		switch (_sortMode) {
			case kPXRFileBrowserSortModeNewerFirst:
				return [file2Date compare:file1Date];
			case kPXRFileBrowserSortModeOlderFirst:
				return [file1Date compare:file2Date];
			default:
				return NSOrderedSame;//don't care
		}
	};
	
	//filter out the correct save files and sort them
	NSArray* sortedList = [list sortedArrayUsingComparator:sortCompare];
	if (sortedList == nil)
		return list;
	
	return sortedList;
}
//end LHQ

- (BOOL)fileShouldBeHidden:(NSString*)fileName{
	int max = 1;
	NSRange range = NSMakeRange(0, max);
	if(max <= [fileName length]){
		if([[fileName substringWithRange:range] isEqualToString:@"."]){
			return YES;
		}
	}
	max = 2;
	if(max <= [fileName length]){
		range = NSMakeRange(0, max);
		if([[fileName substringWithRange:range] isEqualToString:@"__"]){
			return YES;
		}
	}
	max = 3;
	if(max <= [fileName length]){
		range = NSMakeRange(0, max);
		if([[fileName substringWithRange:range] isEqualToString:@"tmp"]){
			return YES;
		}
	}
	return NO;
}

- (void)tableView:(UITableView *) aTableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	NSInteger section = [indexPath indexAtPosition:0];
	NSInteger index = [indexPath indexAtPosition:1];
	BOOL isSelectable = [[tableData itemInSection:section atIndex:index] isSelectable];
	if(!isSelectable) return;
	
	NSString *fileTitle = [[tableData itemInSection:section atIndex:index] fileTitle];
	NSString *filePath = [[tableData itemInSection:section atIndex:index] path];
	if([[tableData itemInSection:section atIndex:index] isDirectory]){
		[self openFolderNamed:fileTitle];
	}else if(browserMode == kPXRFileBrowserModeSave){
		NSString *strippedFileName = [[fileTitle lastPathComponent] stringByDeletingPathExtension];
		fileNameField.text = strippedFileName;
	}else if(browserMode == kPXRFileBrowserModeLoad){
		
		[self loadFileFromDisk:filePath];
	}
}

- (void)userWantsToRemoveFileAtPath:(NSString*)path{
	NSLog(@"destroy this file %@", path);
	if([[NSFileManager defaultManager] fileExistsAtPath:path]){
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	}
	[self refreshView];
}


- (IBAction)newFolder{
	folderDialog.hidden = false;
	[folderNameField becomeFirstResponder];
	folderNameField.text = @"";
}

- (void)writeFolderToDisk{
	NSString *newPath = [currentPath stringByAppendingString:folderNameField.text];
	
	NSString *checkEmpty = [folderNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if(checkEmpty.length == 0){
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Folder has no name" message:[NSString stringWithFormat:@"A folder name cannot be empty.", fileNameField.text] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
		[alert show];
		return;
	}
	if([[NSFileManager defaultManager] fileExistsAtPath:newPath]){
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Folder exists" message:[NSString stringWithFormat:@"A folder with the name \"%@\" already exists.", folderNameField.text] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
		[alert show];
		return;
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:NULL];
	[self refreshView];
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField{
	if(textField == folderNameField){
		NSLog(@"resign folder name field");
		[folderNameField resignFirstResponder];
	}
	if(textField == fileNameField){
		NSLog(@"resign file name field");
		[fileNameField resignFirstResponder];
	}
	return NO;
}

- (BOOL)textField:( UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string{
    BOOL shouldAllowChange = YES;
	NSMutableString *newReplacement =[[NSMutableString alloc] initWithString:string];
    
	NSCharacterSet *desiredCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 1234567890_-*#"];
    for (int i=0; i<[newReplacement length]; i++){
        unichar currentCharacter = [newReplacement characterAtIndex:i];
        if (![desiredCharacters characterIsMember:currentCharacter]) {
            shouldAllowChange = NO;
            [newReplacement deleteCharactersInRange:NSMakeRange(i, 1)];
            i--;
        }
    }
	if(shouldAllowChange){
        return YES;
    }else{
        [textField setText:[[textField text] stringByReplacingCharactersInRange:range withString:newReplacement ]];
        return NO;
    }
	return YES;
}

- (void)openFolderNamed:(NSString*)folderName{
	currentPath = [currentPath stringByAppendingString:folderName];
	
	[self refreshView];
}

- (IBAction)back{
	if (_parentPath != nil)
		currentPath = _parentPath;
	
	[self refreshView];
}

- (IBAction)loadFileFromDisk:(NSString*)path{
	[self dismissViewControllerAnimated:YES completion:nil];
	NSData *file = _autoLoadPickedFile? [NSData dataWithContentsOfFile:path]: nil;
	if(delegate){
		if([delegate respondsToSelector:@selector(fileBrowserFinishedPickingFile:withName:)]){
			[delegate fileBrowserFinishedPickingFile:file withName:path];
		}
	}
}

- (void)saveFile:(NSData*)file withType:(NSString*)fileType andDefaultFileName:(NSString*)defaultName{
	saveOptions.hidden = false;
	fileNameField.text = defaultName;
	fileToSave = file;
	fileTypeToUse = fileType;
	browserMode = kPXRFileBrowserModeSave;
}

- (void)browseForFileWithType:(NSString*)fileType{
	saveOptions.hidden = true;
	fileTypeToUse = fileType;
	fileTypes = [NSArray arrayWithObject:fileType];
	browserMode = kPXRFileBrowserModeLoad;
	[self resetPath];
}

//LHQ
- (void)browseForFileWithType:(NSString*)fileType inDirectory: (NSString*) fullPath{
	saveOptions.hidden = true;
	fileTypeToUse = fileType;
	fileTypes = [NSArray arrayWithObject:fileType];
	browserMode = kPXRFileBrowserModeLoad;
	if (fullPath != nil)
	{
		currentPath = fullPath;
		[self refreshView];
	}
	else
		[self resetPath];
}
//end LHQ

- (void)browseForFileWithTypes:(NSArray*)ft{
	saveOptions.hidden = true;
	fileTypes = ft;
	browserMode = kPXRFileBrowserModeLoad;
	[self resetPath];
}

- (void)alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
	if(buttonIndex == 1 && [alertView.title isEqualToString:@"File exists"]){
		[self confirmedFileOverWrite];
	}
}

- (void)delayedResize:(NSTimer*)timer{
	[self updateSizeForCurrentOrientation];
}

- (void)confirmedFileOverWrite{
	NSString *fileLoc = [currentPath stringByAppendingFormat:@"%@.%@", fileNameField.text, fileTypeToUse];
	[fileToSave writeToFile:fileLoc atomically:YES];
	fileToSave = nil;
	fileTypeToUse = nil;
	[self refreshView];
	[self dismissViewControllerAnimated:YES completion:nil];
	if(delegate){
		if([delegate respondsToSelector:@selector(fileBrowserFinishedSavingFileNamed:)]){
			[delegate fileBrowserFinishedSavingFileNamed:fileLoc];
		}
	}
}

- (void)confirmedFolderOverWrite{
	NSString *newPath = [currentPath stringByAppendingString:folderNameField.text];
	[[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:NULL];
	[self refreshView];
}

- (IBAction)writeFileToDisk{
	// check for overwrite
	NSString *fileLoc = [currentPath stringByAppendingFormat:@"%@.%@", fileNameField.text, fileTypeToUse];
	
	
	if([[NSFileManager defaultManager] fileExistsAtPath:fileLoc]){
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"File exists" message:[NSString stringWithFormat:@"A file with the name \"%@\" already exists, are you sure you want to overwrite it?", fileNameField.text] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
		[alert addButtonWithTitle:@"Ok"];
		[alert show];
		alert = nil;
		return;
	}
	[fileToSave writeToFile:fileLoc atomically:YES];
	fileToSave = nil;
	fileTypeToUse = nil;
	[self refreshView];
	[self dismissViewControllerAnimated:YES completion:nil];
	
	if(delegate){
		if([delegate respondsToSelector:@selector(fileBrowserFinishedSavingFileNamed:)]){
			[delegate fileBrowserFinishedSavingFileNamed:fileLoc];
		}
	}
}

- (IBAction)cancel{
	[self dismissViewControllerAnimated:YES completion:nil];
	if(browserMode == kPXRFileBrowserModeSave){
		if(delegate){
			if([delegate respondsToSelector:@selector(fileBrowserCanceledSavingFile:)]){
				[delegate fileBrowserCanceledSavingFile:fileToSave]; 
			}
		}
		fileToSave = nil;
	}else if(browserMode == kPXRFileBrowserModeLoad){
		if(delegate){
			if([delegate respondsToSelector:@selector(fileBrowserCanceledPickingFile)]){
				[delegate fileBrowserCanceledPickingFile];
			}
		}
	}
}

- (IBAction)fileNameBeganEditing{
	if(!isEditingText){
		frameWidth = self.view.frame.size.width;
		frameHeight = self.view.frame.size.height;
	}
	isEditingText = YES;
	[self updateSizeForCurrentOrientation];
}
- (IBAction)fileNameEndedEditing{
	isEditingText = NO;
	[self updateSizeForCurrentOrientation];
}

- (IBAction)folderNameBeganEditing{
	if(!isEditingText){
		frameWidth = self.view.frame.size.width;
		frameHeight = self.view.frame.size.height;
	}
	isEditingText = YES;
	[self updateSizeForCurrentOrientation];
	folderNameField.hidden = false;
}

- (IBAction)folderNameEndedEditing{
	isEditingText = NO;
	[self updateSizeForCurrentOrientation];
	folderDialog.hidden = true;
	[folderNameField resignFirstResponder];
	[self writeFolderToDisk];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
	return YES;
}
/*
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
}
*/

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
	if(isEditingText){
		[self updateSizeForCurrentOrientation];
	}
}

- (void)updateSizeForCurrentOrientation{
	
	NSString *device = [[UIDevice currentDevice] model];
	UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
	if(isEditingText){
		if([device isEqualToString:@"iPhone"] || [device isEqualToString:@"iPhone Simulator"] || [device isEqualToString:@"iPod touch"]){
			if(orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown){
				self.view.bounds = iphonePortraitEditing;
			}else{
				self.view.bounds = iphoneLandscapeEditing;
			}
		}else if([device isEqualToString:@"iPad"] || [device isEqualToString:@"iPad Simulator"]){
			if(orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown){
				self.view.frame = ipadPortraitEditing;
			}else{
				self.view.frame = ipadLandscapeEditing;
			}
		}
	}else{
		if([device isEqualToString:@"iPhone"] || [device isEqualToString:@"iPhone Simulator"] || [device isEqualToString:@"iPod touch"]){
			if(orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown){
				self.view.bounds = iphonePortraitNormal;
			}else{
				self.view.bounds = iphoneLandscapeNormal;
			}
		}else if([device isEqualToString:@"iPad"] || [device isEqualToString:@"iPad Simulator"]){
			if(orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown){
				self.view.frame = ipadPortraitNormal;
			}else{
				self.view.frame = ipadLandscapeNormal;
			}
		}
	}
}

- (void)dealloc {
	if(fileTypes){
		fileTypes = nil;
	}
	folderNameField.delegate = nil;
	fileNameField.delegate = nil;
	fileTableView.delegate = nil;
	self.fileTableView = nil;
	self.fileNameField = nil;
	self.currentPath = nil;
	self.backButton = nil;
	self.folderContents = nil;
	self.folderTitle = nil;
	self.folderNameField = nil;
	self.folderDialog = nil;
	self.delegate = nil;
}


@end
