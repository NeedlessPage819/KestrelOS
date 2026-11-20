/* Minimal WebView2 host for testing `kestrel webview2` under Wine (DECISIONS.md D29).
 * Opens a window with a WebView2 control, shows a small page, runs a script in it and prints
 *   KESTREL-WEBVIEW2-NAV-OK      when the page has loaded,
 *   KESTREL-WEBVIEW2-JS-OK <r>   when JavaScript ran and returned <r>,
 * then quits (after 120 s at the latest). Build (WebView2.h and WebView2Loader.dll come from
 * Microsoft's Microsoft.Web.WebView2 NuGet package, build/native/{include,x64}):
 *   x86_64-w64-mingw32-gcc -O2 -mconsole -Itest/webview2-shim -I<include> -o webview2test.exe webview2test.c -lole32 -luser32
 * WebView2Loader.dll must lie next to the .exe. */
#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include "WebView2.h"

typedef HRESULT (STDAPICALLTYPE *CreateEnvFn)(PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions *,
                                               ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);

static HWND window;
static ICoreWebView2Controller *controller;
static ICoreWebView2 *webview;

/* One COM object type serves every callback: QueryInterface/AddRef/Release are trivial
 * (the objects are static and live until the process ends). */
static HRESULT STDMETHODCALLTYPE qi(void *self, REFIID riid, void **out) { *out = self; return S_OK; }
static ULONG STDMETHODCALLTYPE addref(void *self) { return 1; }
static ULONG STDMETHODCALLTYPE release(void *self) { return 1; }

static HRESULT STDMETHODCALLTYPE script_done(ICoreWebView2ExecuteScriptCompletedHandler *self,
                                             HRESULT result, LPCWSTR json)
{
    printf("KESTREL-WEBVIEW2-JS-OK %ls\n", SUCCEEDED(result) && json ? json : L"(failed)");
    fflush(stdout);
    PostQuitMessage(0);
    return S_OK;
}
static ICoreWebView2ExecuteScriptCompletedHandlerVtbl script_vtbl = {
    (void *)qi, (void *)addref, (void *)release, script_done };
static ICoreWebView2ExecuteScriptCompletedHandler script_handler = { &script_vtbl };

static HRESULT STDMETHODCALLTYPE nav_done(ICoreWebView2NavigationCompletedEventHandler *self,
                                          ICoreWebView2 *sender, ICoreWebView2NavigationCompletedEventArgs *args)
{
    BOOL ok = FALSE;
    ICoreWebView2NavigationCompletedEventArgs_get_IsSuccess(args, &ok);
    printf(ok ? "KESTREL-WEBVIEW2-NAV-OK\n" : "KESTREL-WEBVIEW2-NAV-FAILED\n");
    fflush(stdout);
    ICoreWebView2_ExecuteScript(webview, L"document.title + ' ' + (6 * 7)", &script_handler);
    return S_OK;
}
static ICoreWebView2NavigationCompletedEventHandlerVtbl nav_vtbl = {
    (void *)qi, (void *)addref, (void *)release, nav_done };
static ICoreWebView2NavigationCompletedEventHandler nav_handler = { &nav_vtbl };

static HRESULT STDMETHODCALLTYPE controller_done(ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
                                                 HRESULT result, ICoreWebView2Controller *created)
{
    EventRegistrationToken token;
    RECT bounds;
    if (FAILED(result) || !created) {
        printf("KESTREL-WEBVIEW2-CONTROLLER-FAILED 0x%08lx\n", (unsigned long)result);
        fflush(stdout);
        PostQuitMessage(1);
        return S_OK;
    }
    controller = created;
    ICoreWebView2Controller_AddRef(controller);
    ICoreWebView2Controller_get_CoreWebView2(controller, &webview);
    GetClientRect(window, &bounds);
    ICoreWebView2Controller_put_Bounds(controller, bounds);
    ICoreWebView2_add_NavigationCompleted(webview, &nav_handler, &token);
    ICoreWebView2_NavigateToString(webview,
        L"<!doctype html><title>Kestrel</title><body style='font:40px sans-serif;background:#eef'>"
        L"<h1>WebView2 works on Kestrel</h1></body>");
    return S_OK;
}
static ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl controller_vtbl = {
    (void *)qi, (void *)addref, (void *)release, controller_done };
static ICoreWebView2CreateCoreWebView2ControllerCompletedHandler controller_handler = { &controller_vtbl };

static HRESULT STDMETHODCALLTYPE env_done(ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
                                          HRESULT result, ICoreWebView2Environment *env)
{
    if (FAILED(result) || !env) {
        printf("KESTREL-WEBVIEW2-ENV-FAILED 0x%08lx\n", (unsigned long)result);
        fflush(stdout);
        PostQuitMessage(1);
        return S_OK;
    }
    printf("KESTREL-WEBVIEW2-ENV-OK\n");
    fflush(stdout);
    ICoreWebView2Environment_CreateCoreWebView2Controller(env, window, &controller_handler);
    return S_OK;
}
static ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl env_vtbl = {
    (void *)qi, (void *)addref, (void *)release, env_done };
static ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler env_handler = { &env_vtbl };

static LRESULT CALLBACK wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
    if (msg == WM_SIZE && controller) {
        RECT bounds;
        GetClientRect(hwnd, &bounds);
        ICoreWebView2Controller_put_Bounds(controller, bounds);
    }
    if (msg == WM_TIMER) { printf("KESTREL-WEBVIEW2-TIMEOUT\n"); fflush(stdout); PostQuitMessage(2); }
    if (msg == WM_DESTROY) PostQuitMessage(0);
    return DefWindowProcW(hwnd, msg, wp, lp);
}

int main(void)
{
    HMODULE loader;
    CreateEnvFn create;
    HRESULT hr;
    MSG msg;
    WNDCLASSW wc = { 0 };
    int keep = GetEnvironmentVariableW(L"KESTREL_WEBVIEW2_KEEP", NULL, 0) > 0;

    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    wc.lpfnWndProc = wndproc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"KestrelWebView2Test";
    RegisterClassW(&wc);
    window = CreateWindowW(wc.lpszClassName, L"Kestrel WebView2 test", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                           CW_USEDEFAULT, CW_USEDEFAULT, 900, 600, NULL, NULL, wc.hInstance, NULL);
    SetTimer(window, 1, 120000, NULL);

    loader = LoadLibraryW(L"WebView2Loader.dll");
    create = loader ? (CreateEnvFn)GetProcAddress(loader, "CreateCoreWebView2EnvironmentWithOptions") : NULL;
    if (!create) { printf("KESTREL-WEBVIEW2-NO-LOADER\n"); return 1; }
    hr = create(NULL, NULL, NULL, &env_handler);
    if (FAILED(hr)) { printf("KESTREL-WEBVIEW2-ENV-FAILED 0x%08lx\n", (unsigned long)hr); return 1; }

    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    if (keep) {   /* stay open for a screenshot */
        KillTimer(window, 1);
        while (GetMessageW(&msg, NULL, 0, 0) > 0) { TranslateMessage(&msg); DispatchMessageW(&msg); }
    }
    return (int)msg.wParam;
}
