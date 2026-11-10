// Minimal reproduction of the installer crash: a WMI query through
// System.Management from an STA thread (what a WinForms/WPF Main() is).
// Build: csc /r:System.Management.dll WmiTest.cs    Run: WmiTest.exe [sta|mta] [rounds]
using System;
using System.Management;
using System.Threading;

static class WmiTest
{
    static int result = 0;

    static void Query()
    {
        try
        {
            Console.WriteLine("apartment: " + Thread.CurrentThread.GetApartmentState());
            var s = new ManagementObjectSearcher("SELECT Caption, OperatingSystemSKU FROM Win32_OperatingSystem");
            foreach (ManagementObject o in s.Get())
                Console.WriteLine("OK: " + o["Caption"] + " / SKU " + o["OperatingSystemSKU"]);
        }
        catch (Exception e)
        {
            Console.WriteLine("FAIL: " + e.GetType().Name + ": " + e.Message);
            result = 1;
        }
    }

    static int Main(string[] args)
    {
        var state = (args.Length > 0 && args[0] == "mta") ? ApartmentState.MTA : ApartmentState.STA;
        int rounds = args.Length > 1 ? int.Parse(args[1]) : 1;
        var t = new Thread(() =>
        {
            // Several queries on the same thread, with a pause and a GC in
            // between, as an installer does while it inspects the system.
            for (int i = 0; i < rounds; i++)
            {
                Query();
                GC.Collect();
                GC.WaitForPendingFinalizers();
                Thread.Sleep(1500);
            }
        });
        t.SetApartmentState(state);
        t.Start();
        t.Join();
        return result;
    }
}
