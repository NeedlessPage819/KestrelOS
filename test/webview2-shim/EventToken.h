/* Stand-in for the Windows SDK header that mingw-w64 lacks; WebView2.h only needs this type. */
#ifndef KESTREL_EVENTTOKEN_H
#define KESTREL_EVENTTOKEN_H
typedef struct EventRegistrationToken { __int64 value; } EventRegistrationToken;
#endif
