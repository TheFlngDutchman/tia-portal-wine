// A font family must report every FontStyle as available, including Underline
// and Strikeout, which Windows always can produce. TIA Portal's text editors
// reject a font ("The selected 'Courier New' font is invalid") otherwise.
// Build: csc /r:System.Drawing.dll FontStyles.cs    Run: FontStyles.exe "Courier New" Arial
using System;
using System.Drawing;

static class FontStyles
{
    static int Main(string[] names)
    {
        int failed = 0;
        foreach (var name in names)
        {
            using (var family = new FontFamily(name))
            {
                foreach (FontStyle style in Enum.GetValues(typeof(FontStyle)))
                {
                    bool ok = family.IsStyleAvailable(style);
                    if (!ok) failed++;
                    Console.WriteLine((ok ? "OK:   " : "FAIL: ") + name + " " + style);
                }
            }
        }
        return failed;
    }
}
