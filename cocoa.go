package cocoa
//+build darwin

/*
#cgo darwin CFLAGS: -DDARWIN -x objective-c -fobjc-arc -mmacosx-version-min=10.9
#cgo darwin LDFLAGS: -weak_framework Cocoa

#include "cocoa.h"
*/
import "C"

import (
	"runtime"
	"unsafe"
	"strings"
	"fmt"
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
	if (forFiles) {
		filesBool = C.bool(true)
	}

	selectBool := C.bool(false)
	if (multiselect) {
		selectBool = C.bool(true)
	}

	result := C.cocoaFSDialog(titlePtr, filesCsv, dirPtr, filesBool, selectBool)

	C.free(unsafe.Pointer(titlePtr))
	C.free(unsafe.Pointer(dirPtr))
	C.free(unsafe.Pointer(filesCsv))

	return strings.Split(C.GoString(result), ",")
}

func ShowDialog(message string)  {
	msgStr := C.CString(message)
	C.cocoaDialog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

func Log(message string) {
	msgStr := C.CString(message)
	C.printLog(msgStr)
	C.free(unsafe.Pointer(msgStr))
}

//export cocoaStart
func cocoaStart() {
	for i, f := range startupCallbacks {
		Log(fmt.Sprintf("Startup callback %d running", i))
		f()
	}
}

//export cocoaUrl
func cocoaUrl(data *C.char) {
	url := C.GoString(data)
	for i, f := range urlCallbacks {
		Log(fmt.Sprintf("URL callback %d running", i))
		f(url)
	}
}
