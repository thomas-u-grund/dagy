// dagplot_viewer: a standalone fork of nwcommands_2016's
// native/nwedit_viewer.mm (see dagplot.ado's own top header for why this
// package forks nwplot's whole interactive pipeline, launcher and native
// binary included, not just the Stata/JS rendering side). A minimal,
// chromeless native window hosting WKWebView (macOS's own built-in web
// engine), pointed at a local HTML file given as argv[1]. Not a bundled
// browser -- no Chromium/WebKit shipped, just a thin shell around what the
// OS already provides. This is dagplot's `interactive` option's preferred
// launch path (see dagplot.ado and _dagplot_openviewer.ado); it falls back
// to `view browse` if this binary isn't present for the current platform,
// so this file compiling or not never breaks the underlying feature, only
// whether the view is chromeless or an ordinary browser tab.
//
// No third-party dependency (deliberately not vendoring webview/webview --
// that project restructured to a multi-file CMake build partway through
// this feature's own development, and a task this narrow doesn't need an
// abstraction layer over Cocoa/WebKit, which are already present via Xcode
// on every macOS build/runtime target this package supports).

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// Bridges the JS-side Save/Export buttons to a native NSSavePanel. An
// ordinary browser tab (the `view browse` fallback) gets a working
// download for free via the usual blob + `<a download>` click, but a bare
// WKWebView like this one - no Safari/Chrome chrome, no download delegate
// configured - silently no-ops a download-attribute anchor click: confirmed
// directly, Save/Export did nothing when clicked in this window even
// though the identical buttons worked under `view browse`. This handler is
// nwplot's side of that gap: nwedit_template.html's own hasNativeSave
// feature-detect posts {filename, dataBase64} here instead of trying the
// anchor trick whenever it detects it's running inside this native viewer.
@interface NweditSaveBridge : NSObject <WKScriptMessageHandler>
- (void)handleSaveRequest:(NSDictionary *)body;
@end

// Without this, closing the one-and-only window leaves the process itself
// still running -- a regular-activation-policy app (below) gets a Dock
// icon, and Cocoa does not quit an app just because its last window closed
// unless a delegate says to. Each `nwplot ... interactive` call stages and
// launches a FRESH randomly-named copy of this binary (see nwplot.ado's own
// `_nwedit_viewercopy` local), so without this the user accumulates one
// orphaned, windowless Dock icon per interactive call -- reported directly
// as "a weird winexec window ... stays even when I close the nwplot
// viewer", sitting in the Dock (literally the bottom of the screen).
@interface NweditAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation NweditAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}
@end

@implementation NweditSaveBridge

- (void)userContentController:(WKUserContentController *)userContentController
       didReceiveScriptMessage:(WKScriptMessage *)message {
	[self handleSaveRequest:message.body];
}

// Split out from the WKScriptMessageHandler callback above so this logic is
// directly callable with a plain NSDictionary, independent of constructing
// a real WKScriptMessage (whose .body has no public initializer) -- makes
// this testable standalone.
- (void)handleSaveRequest:(NSDictionary *)body {
	if (![body isKindOfClass:[NSDictionary class]]) return;
	NSString *filename = body[@"filename"];
	NSString *b64 = body[@"dataBase64"];
	if (![filename isKindOfClass:[NSString class]] || ![b64 isKindOfClass:[NSString class]]) return;

	NSData *data = [[NSData alloc] initWithBase64EncodedString:b64
		options:NSDataBase64DecodingIgnoreUnknownCharacters];
	if (!data) return;

	NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setNameFieldStringValue:filename];
	// Plain modal, not a sheet: this handler already runs synchronously off
	// a JS call, and runModal blocking until the user picks a location or
	// cancels is exactly the "there should be a dialog box" behavior asked
	// for, with no extra completion-handler plumbing needed for a one-shot
	// save like this.
	if ([panel runModal] == NSModalResponseOK) {
		NSError *error = nil;
		[data writeToURL:panel.URL options:NSDataWritingAtomic error:&error];
		if (error) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Could not save file";
			alert.informativeText = error.localizedDescription;
			[alert runModal];
		}
	}
}

@end

int main(int argc, const char *argv[]) {
	if (argc < 2) {
		fprintf(stderr, "usage: dagplot_viewer <path-to-html-file>\n");
		return 1;
	}

	@autoreleasepool {
		NSString *path = [NSString stringWithUTF8String:argv[1]];
		NSURL *fileURL = [NSURL fileURLWithPath:path];

		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
		NweditAppDelegate *appDelegate = [[NweditAppDelegate alloc] init];
		[NSApp setDelegate:appDelegate];

		NSRect frame = NSMakeRect(0, 0, 1280, 860);
		NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
			NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
		NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
			styleMask:styleMask
			backing:NSBackingStoreBuffered
			defer:NO];
		[window setTitle:@"dagplot interactive"];
		[window center];

		WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
		// dagplot_viewer's own fix (see this file's top header): this
		// process is staged and exec'd directly from a FRESH randomly-
		// named copy of itself in c(tmpdir) for every launch (e.g.
		// ".../T/dagplot_viewer_136646") - not a signed, bundled .app with
		// its own container. WKWebView's default (persistent)
		// WKWebsiteDataStore for such an unbundled process derives its
		// on-disk cache directory from that same executable path/name,
		// i.e. it tries to create ".../T/dagplot_viewer_136646/WebKit/
		// MediaCache" - but ".../T/dagplot_viewer_136646" already exists
		// as the staged binary FILE, not a directory, so the mkdir fails
		// ("Not a directory", logged to stderr) and the persistent store
		// never initializes, which silently blanks the page (confirmed
		// directly: no JS/network error, WebKit just never finishes
		// standing up before the page content loads). A one-shot
		// local-file viewer with no logins/cookies/history worth
		// persisting has no use for a persistent store anyway, so use an
		// ephemeral, in-memory one instead - it needs no on-disk
		// directory at all, sidestepping the collision entirely.
		config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
		// Registered before loadFileURL: below, so window.webkit.messageHandlers.nwedit
		// already exists by the time the page's own <script> runs its
		// hasNativeSave feature-detect at load.
		NweditSaveBridge *saveBridge = [[NweditSaveBridge alloc] init];
		[config.userContentController addScriptMessageHandler:saveBridge name:@"nwedit"];

		WKWebView *webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
		[webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		// allowingReadAccessToURL: the file's own directory -- the page is
		// fully self-contained (data + vendored JS inlined by nwplot.ado),
		// so no broader filesystem access is needed.
		[webView loadFileURL:fileURL allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];

		[window setContentView:webView];
		[window makeKeyAndOrderFront:nil];

		[NSApp activateIgnoringOtherApps:YES];
		[NSApp run];
	}
	return 0;
}
