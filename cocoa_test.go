package cocoa

import (
	"testing"
)

// TestAutoLaunch tests ability for an app to register itself as a startup item.
func TestAutoLaunch(t *testing.T) {
	AddStartCallback(func() {
		bundleIdent := /*"com.apple.Safari"*/ BundleIdentifier()
		path := /*"/Applications/Safari.app/Contents/MacOS/Safari"*/ BundlePath()
		AutoStart(true, bundleIdent, path)
	})
	Start()
}
