# Culture IDs used by TIA Portal

`portal-v21-lcids.txt` is the list of 108 locale IDs from the
`Installation/AvailableCultures` setting of TIA Portal V21. When a project is
created, Portal calls `CultureInfo.GetCultureInfo(lcid)` for every entry and
fails if one of them is unknown.

```bash
wine 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo LcidList.cs
wine LcidList.exe portal-v21-lcids.txt
```

Wine 11.20: 0x081a (sr-Latn-CS) and 0x0c1a (sr-Cyrl-CS) fail. With patch 0005
all 108 pass.
