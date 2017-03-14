//+build darwin
package cocoa

/*
#cgo darwin CFLAGS: -DDARWIN -x objective-c -fobjc-arc -Wformat-security
#cgo darwin LDFLAGS: -framework Cocoa

#include "cocoa.h"
*/
import "C"

import (
	"runtime"
	"strings"
	"unsafe"
)

type startCallback func()
type urlCallback func(url string)

var (
	startupCallbacks = []startCallback{}
	urlCallbacks     = []urlCallback{}
)

const (
	// NSAlertFirstButtonReturn return value when first button in a prompt is clicked
	NSAlertFirstButtonReturn = 1000
	// NSAlertSecondButtonReturn return value when second buttion in a prompt is clicked
	NSAlertSecondButtonReturn = 1001
	// NSAlertThirdButtonReturn return value when third button in a prompt is clicked
	NSAlertThirdButtonReturn = 1002
)

// AutoStart sets whether app starts automatically at login.
func AutoStart(flag bool) {
	C.autoStart(C.bool(flag))
}

// BundleIdentifier returns this app's bundle identifier in reverse RFC 1034 (e.g. com.bitbucket.djlawhead)
func BundleIdentifier() string {
	return C.GoString(C.bundlePath())
}

// BundlePath path of bundle on filesystem
func BundlePath() string {
	return C.GoString(C.bundleIdentifier())
}

// AddUrlCallback adds a callback which will receive the URL app was started with.
func AddUrlCallback(c urlCallback) {
	urlCallbacks = append(urlCallbacks, c)
}

// AddStartCallback adds callback function which is called when app starts.
func AddStartCallback(c startCallback) {
	startupCallbacks = append(startupCallbacks, c)
}

// Start runs main app thread
func Start() {
	runtime.LockOSThread()
	C.cocoaMain()
}

// Stop stops main app thread
func Stop() {
	C.cocoaExit()
}

// ShowFileDialog shows a file-system dialog
func ShowFileDialog(title, defaultDirectory string,
	fileTypes []string,
	forFiles bool, multiselect bool) []string {

	titlePtr := C.CString(title)
	dirPtr := C.CString(defaultDirectory)
	filesCsv := C.CString(strings.Join(fileTypes, ","))

	filesBool := C.bool(false)
	if forFiles {
		filesBool = C.bool(true)
	}

	selectBool := C.bool(false)
	if multiselect {
		selectBool = C.bool(true)
	}

	result := C.cocoaFSDialog(titlePtr, filesCsv, dirPtr, filesBool, selectBool)

	defer func() {
		C.free(unsafe.Pointer(titlePtr))
		C.free(unsafe.Pointer(dirPtr))
		C.free(unsafe.Pointer(filesCsv))
	}()

	retval := C.GoString(result)
	return strings.Split(retval, "\n")
}

// ShowDialog shows a dialog/alert message
func ShowDialog(message string) {
	msgStr := C.CString(message)
	C.cocoaDialog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

// ShowPrompt shows a yes/no dialog prompt
func ShowPrompt(message, buttonLabel, altButtonLabel string) int {
	msgStr := C.CString(message)
	btn1 := C.CString(buttonLabel)
	btn2 := C.CString(altButtonLabel)

	defer func() {
		C.free(unsafe.Pointer(msgStr))
		C.free(unsafe.Pointer(btn1))
		C.free(unsafe.Pointer(btn2))
	}()

	retval := int(C.cocoaPrompt(msgStr, btn1, btn2))

	return retval
}

// Log logs a message to OS X console
func Log(message string) {
	msgStr := C.CString(message)
	C.printLog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

//export cocoaStart
func cocoaStart() {
	Log("cocoaStart called. Calling startup callbacks")
	for _, f := range startupCallbacks {
		f()
	}
}

//export cocoaUrl
func cocoaUrl(data *C.char) {
	url := C.GoString(data)
	for _, f := range urlCallbacks {
		f(url)
	}
}
