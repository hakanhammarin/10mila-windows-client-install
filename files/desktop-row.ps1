# desktop-row.ps1 - runs at logon in the user's session (task "10mila desktop row"): puts the desktop icons in rows
# along the top, launch icons first, so the middle of the wallpaper (the O-Ringen banner) stays clear.
param([string[]]$First = @('OLA-Klient', 'OLA', 'TA-Klient', 'Nummerlappar', 'nummerlappar', 'TOOLS'))
$ErrorActionPreference = 'Stop'
Start-Sleep 8   # Explorer has to finish drawing the desktop
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
namespace TenMila {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [ComImport, Guid("9BA05972-F6A8-11CF-A442-00A0C90A8F39")] class ShellWindowsClass {}
  [ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
  interface IShellWindows {
    int Count { get; }
    [return: MarshalAs(UnmanagedType.IDispatch)] object Item(object index);
    [return: MarshalAs(UnmanagedType.IUnknown)] object _NewEnum();
    void Register([MarshalAs(UnmanagedType.IDispatch)] object pid, int hwnd, int swClass, out int plCookie);
    void RegisterPending(int lThreadId, ref object pvarloc, ref object pvarlocRoot, int swClass, out int plCookie);
    void Revoke(int lCookie);
    void OnNavigate(int lCookie, ref object pvarLoc);
    void OnActivated(int lCookie, bool fActive);
    [return: MarshalAs(UnmanagedType.IDispatch)] object FindWindowSW(ref object pvarLoc, ref object pvarLocRoot, int swClass, out int phwnd, int swfwOptions);
  }
  [ComImport, Guid("6d5140c1-7436-11ce-8034-00aa006009fa"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IServiceProvider { [PreserveSig] int QueryService(ref Guid sid, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv); }
  [ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IShellBrowser {
    void GetWindow(out IntPtr h); void ContextSensitiveHelp(bool f);
    void InsertMenusSB(IntPtr a, IntPtr b); void SetMenuSB(IntPtr a, IntPtr b, IntPtr c); void RemoveMenusSB(IntPtr a);
    void SetStatusTextSB(IntPtr a); void EnableModelessSB(bool a); void TranslateAcceleratorSB(IntPtr a, short b);
    void BrowseObject(IntPtr a, uint b); void GetViewStateStream(uint a, out IntPtr b); void GetControlWindow(uint a, out IntPtr b);
    void SendControlMsg(uint a, uint b, IntPtr c, IntPtr d, IntPtr e);
    void QueryActiveShellView([MarshalAs(UnmanagedType.IUnknown)] out object view);
  }
  [ComImport, Guid("1af3a467-214f-4298-908e-06b03e0b39f9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IFolderView2 {
    void GetCurrentViewMode(out uint m); void SetCurrentViewMode(uint m); void GetFolder(ref Guid riid, out IntPtr ppv);
    void Item(int i, out IntPtr pidl); void ItemCount(uint flags, out int n); void Items(uint flags, ref Guid riid, out IntPtr ppv);
    void GetSelectionMarkedItem(out int i); void GetFocusedItem(out int i); void GetItemPosition(IntPtr pidl, out POINT pt);
    void GetSpacing(ref POINT pt); void GetDefaultSpacing(out POINT pt); [PreserveSig] int GetAutoArrange(); void SelectItem(int i, uint f);
    void SelectAndPositionItems(uint cidl, [In, MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl, [In, MarshalAs(UnmanagedType.LPArray)] POINT[] apt, uint flags);   // C arrays, not SAFEARRAYs
    void SetGroupBy(IntPtr key, bool asc); void GetGroupBy(IntPtr key, out bool asc);
    void SetViewProperty(IntPtr pidl, IntPtr key, IntPtr v); void GetViewProperty(IntPtr pidl, IntPtr key, IntPtr v);
    void SetTileViewProperties(IntPtr pidl, string s); void SetExtendedTileViewProperties(IntPtr pidl, string s);
    void SetText(int t, string s); void SetCurrentFolderFlags(uint mask, uint flags); void GetCurrentFolderFlags(out uint flags);
    void GetSortColumnCount(out int n); void SetSortColumns(IntPtr c, int n); void GetSortColumns(IntPtr c, int n);
    void GetItem(int i, ref Guid riid, out IntPtr ppv); void GetVisibleItem(int start, bool previous, out int item);
    void GetSelectedItem(int start, out int item); void GetSelection(bool none, out IntPtr items); void GetSelectionState(IntPtr pidl, out uint flags);
    void InvokeVerbOnSelection([MarshalAs(UnmanagedType.LPStr)] string verb); void SetViewModeAndIconSize(int mode, int size);
  }
  public static class Desktop {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern int SHGetNameFromIDList(IntPtr pidl, uint sigdn, out IntPtr name);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    public static string Row(string[] first) {
      var sw = (IShellWindows)new ShellWindowsClass();
      object loc = 0x0000, root = null; int hwnd;   // CSIDL_DESKTOP
      object disp = sw.FindWindowSW(ref loc, ref root, 8, out hwnd, 1);   // SWC_DESKTOP, SWFO_NEEDDISPATCH
      Guid sid = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837"), iid = typeof(IShellBrowser).GUID; object o;
      ((IServiceProvider)disp).QueryService(ref sid, ref iid, out o);
      object view; ((IShellBrowser)o).QueryActiveShellView(out view);
      var fv = (IFolderView2)view;
      fv.SetCurrentFolderFlags(0x1, 0);   // auto arrange off, or the positions are ignored
      fv.SetViewModeAndIconSize(1, 96);   // FVM_ICON, Large icons: the biggest size the desktop menu offers
      int n; fv.ItemCount(2, out n);      // SVGIO_ALLVIEW
      var items = new List<KeyValuePair<string, IntPtr>>();
      for (int i = 0; i < n; i++) { IntPtr p; fv.Item(i, out p); IntPtr s; SHGetNameFromIDList(p, 0, out s); items.Add(new KeyValuePair<string, IntPtr>(Marshal.PtrToStringUni(s), p)); Marshal.FreeCoTaskMem(s); }
      items.Sort((a, b) => { int ia = Array.IndexOf(first, a.Key), ib = Array.IndexOf(first, b.Key);
        if (ia < 0) ia = 1000; if (ib < 0) ib = 1000; return ia != ib ? ia.CompareTo(ib) : string.Compare(a.Key, b.Key, StringComparison.CurrentCultureIgnoreCase); });
      POINT sp = new POINT(); fv.GetSpacing(ref sp);
      int perRow = Math.Max(1, (GetSystemMetrics(0) - 20) / sp.X - 1), k = 0; var names = new List<string>();
      foreach (var it in items) {
        var pt = new POINT { X = 10 + (k % perRow) * sp.X, Y = 10 + (k / perRow) * sp.Y };
        fv.SelectAndPositionItems(1, new[] { it.Value }, new[] { pt }, 0x80);   // SVSI_POSITIONITEM
        names.Add(it.Key); k++;
      }
      return string.Join(", ", names);
    }
  }
}
'@
"$(Get-Date -Format s) row: " + [TenMila.Desktop]::Row($First) | Add-Content (Join-Path $env:LOCALAPPDATA '10mila-desktop-row.log')
