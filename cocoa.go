//+build darwin
package cocoa

/*
#cgo darwin CFLAGS: -DDARWIN -x objective-c -fobjc-arc
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
	NSAlertFirstButtonReturn  = 1000
	NSAlertSecondButtonReturn = 1001
	NSAlertThirdButtonReturn  = 1002
)

func AddUrlCallback(c urlCallback) {
	urlCallbacks = append(urlCallbacks, c)
}
func AddStartCallback(c startCallback) {
	startupCallbacks = append(startupCallbacks, c)
}

func Start() {
	runtime.LockOSThread()
	C.cocoaMain()
}

func Stop() {
	C.cocoaExit()
}

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

func ShowDialog(message string) {
	msgStr := C.CString(message)
	C.cocoaDialog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

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

func Log(message string) {
	msgStr := C.CString(message)
	C.printLog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

//export cocoaStart
func cocoaStart() {
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
