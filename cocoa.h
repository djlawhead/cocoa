#include <Cocoa/Cocoa.h>

void printLog(char *msg);
void cocoaDialog(char *msg);
const char* cocoaFSDialog(
	  char *title,
      char *fileTypesCsv,
      char *initialPath,
      bool canChooseFiles,
      bool multiSelection);
void cocoaMain();
void cocoaExit();