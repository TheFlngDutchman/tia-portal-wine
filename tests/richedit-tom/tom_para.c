/* Text Object Model calls that TIA Portal's formatted tooltips make on a rich
 * edit control: paragraph alignment, indents and list type, typing text into
 * the selection, and positions of ranges.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -o tom_para.exe tom_para.c -lole32 -loleaut32 -luuid
 * Run:   wine tom_para.exe
 */
#define COBJMACROS
#include <windows.h>
#include <richedit.h>
#include <richole.h>
#include <tom.h>
#include <stdio.h>

static const GUID iid_ITextDocument = {0x8cc497c0,0xa1df,0x11ce,{0x80,0x98,0x00,0xaa,0x00,0x47,0xbe,0x5d}};
static int failures;
#define CHECK(what, cond) do { if (cond) printf("OK:   %s\n", what); else { printf("FAIL: %s\n", what); failures++; } } while (0)

int main(void)
{
    IRichEditOle *ole = NULL; ITextDocument *doc = NULL; ITextRange *range = NULL, *hit = NULL;
    ITextPara *para = NULL; ITextSelection *sel = NULL;
    LONG value, x = 0, y = 0, cp = -1; float f; BSTR text; HRESULT hr; HWND hwnd;

    LoadLibraryA("riched20.dll");
    hwnd = CreateWindowA("RichEdit20W", "", WS_POPUP | WS_VISIBLE | ES_MULTILINE, 100, 100, 400, 200, NULL, NULL, NULL, NULL);
    if (!hwnd) { printf("FAIL: no rich edit window\n"); return 1; }
    SendMessageA(hwnd, WM_SETTEXT, 0, (LPARAM)"first paragraph\r\nsecond paragraph");
    SendMessageA(hwnd, EM_GETOLEINTERFACE, 0, (LPARAM)&ole);
    ole->lpVtbl->QueryInterface(ole, &iid_ITextDocument, (void **)&doc);

    ITextDocument_Range(doc, 0, 5, &range);
    ITextRange_GetPara(range, &para);

    hr = ITextPara_SetListType(para, tomListNone);            CHECK("SetListType(none)", hr == S_OK);
    hr = ITextPara_SetListType(para, tomListBullet);          CHECK("SetListType(bullet)", hr == S_OK);
    hr = ITextPara_GetListType(para, &value);                 CHECK("GetListType reads bullet", hr == S_OK && value == tomListBullet);
    hr = ITextPara_SetListStart(para, 3);                     CHECK("SetListStart", hr == S_OK);
    hr = ITextPara_SetAlignment(para, tomAlignCenter);        CHECK("SetAlignment(center)", hr == S_OK);
    hr = ITextPara_GetAlignment(para, &value);                CHECK("GetAlignment reads center", hr == S_OK && value == tomAlignCenter);
    hr = ITextPara_SetIndents(para, -10.0f, 30.0f, 5.0f);     CHECK("SetIndents", hr == S_OK);
    hr = ITextPara_GetLeftIndent(para, &f);                   CHECK("GetLeftIndent reads 30", hr == S_OK && f > 29.9f && f < 30.1f);
    hr = ITextPara_GetRightIndent(para, &f);                  CHECK("GetRightIndent reads 5", hr == S_OK && f > 4.9f && f < 5.1f);
    hr = ITextPara_SetRightIndent(para, 7.0f);                CHECK("SetRightIndent", hr == S_OK);

    hr = ITextRange_GetPoint(range, tomStart | TA_TOP | TA_LEFT, &x, &y);
    CHECK("GetPoint", hr == S_OK);
    hr = ITextDocument_RangeFromPoint(doc, x + 1, y + 1, &hit);
    if (hit) ITextRange_GetStart(hit, &cp);
    CHECK("RangeFromPoint finds the range start again", hr == S_OK && cp == 0);

    ITextDocument_GetSelection(doc, &sel);
    ITextSelection_SetRange(sel, 0, 5);
    text = SysAllocString(L"FIRST");
    hr = ITextSelection_TypeText(sel, text);                  CHECK("TypeText", hr == S_OK);
    SysFreeString(text);
    ITextRange_SetRange(range, 0, 5);
    ITextRange_GetText(range, &text);
    CHECK("TypeText replaced the selection", text && !lstrcmpW(text, L"FIRST"));
    hr = ITextSelection_GetFlags(sel, &value);                CHECK("GetFlags", hr == S_OK);

    printf("%s\n", failures ? "some checks failed" : "all checks passed");
    return failures;
}
