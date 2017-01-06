package cocoa
//+build darwin

/*
#cgo darwin CFLAGS: -DDARWIN -x objective-c -fobjc-arc
#cgo darwin LDFLAGS: -framework Cocoa

#include "cocoa.h"
*/
import "C"

import (
	"runtime"
)

type startCallback func()
type urlCallback func(url string)

var (
	startupCallbacks = []startCallback{}
	urlCallbacks = []urlCallback{}
)

func AddUrlCallback(c urlCallback) {
	urlCallbacks = append(urlCallbacks,c)
}
func AddStartCallback(c startCallback) {
	startupCallbacks = append(startupCallbacks, c)
}

func Start(onStart startCallback) {
	AddStartCallback(onStart)

	runtime.LockOSThread()
	C.cocoaMain()
}

func Stop() {
	C.cocoaExit()
}

func ShowFileDialog(title, defaultDirectory string,
	fileTypes []string,
	forFiles bool, multiselect bool) {
	titlePtr := C.CString(title)
	dirPtr := C.CString(defaultDirectory)

	var filesBool C.BOOL
	if (forFiles) {
		filesBool = C.BOOL(1)
	} else {
		filesBool = C.BOOL(0)
	}

	var selectBool C.BOOL
	if (selectBool) {
		selectBool = C.BOOL(1)
	} else {
		selectBool = C.BOOL(0)
	}

	C.showOpenPanel(titlePtr, dirPtr, filesBool, selectBool)

	C.free(unsafe.Pointer(titlePtr))
	C.free(unsafe.Pointer(dirPtr))
}

func ShowDialog(message string) {
	msgStr := C.CString(message)
	C.showDialog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

func Log(message string) {
	msgStr := C.CString(message)
	C.printLog(msgStr)
	C.free(usnafe.Pointer(msgStr))
}

//export cocoaStart
func cocoastart() {
	for _, f := range startupCallbacks {
		f()
	}
}

//export cocoaUrl
func cocoaUrl(data C.CString) {
	url := C.GoString(data)
	for _, f := range urlCallbacks {
		f(url)
	}
}
