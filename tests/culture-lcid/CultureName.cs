// Creating a culture from a name Windows does not know. Since Windows 10 any
// well-formed name is accepted as a custom culture. TIA Portal's hardware
// configuration creates one called "jp" when a PLC is added.
// Build: csc CultureName.cs    Run: CultureName.exe jp ja de-DE xx-YY
using System;
using System.Globalization;

static class CultureName
{
    static int Main(string[] names)
    {
        int failed = 0;
        foreach (var name in names)
        {
            try
            {
                var culture = new CultureInfo(name);
                Console.WriteLine("OK: '" + name + "' -> name '" + culture.Name + "'");
            }
            catch (Exception e)
            {
                failed++;
                Console.WriteLine("FAIL: '" + name + "': " + e.GetType().Name);
            }
        }
        return failed;
    }
}
