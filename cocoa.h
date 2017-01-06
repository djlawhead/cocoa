#include <Cocoa/Cocoa.h>

void printLog(char *msg);
void showDialog(char *msg);
const char* showOpenPanel(
	  char *title,
      char *fileTypesCsv,
      char *initialPath,
      bool canChooseFiles,
      bool multiSelection);
void cocoaMain();
void cocoaExit();