#include <Cocoa/Cocoa.h>

void printLog(char *msg);
void cocoaDialog(char *msg);
const char* cocoaFSDialog(
	  char *title,
      char *fileTypesCsv,
      char *initialPath,
      bool canChooseFiles,
      bool multiSelection);
int cocoaPrompt(char *msg, char *btn1, char *btn2);
void cocoaMain();
void cocoaExit();