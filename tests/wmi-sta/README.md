# WMI from an STA thread

Reproduces the crash of the TIA Portal V21 installer (`SIA2.exe`) without any
Siemens software.

```bash
. scripts/env.sh
cd tests/wmi-sta
wine 'C:\windows\Microsoft.NET\Framework\v4.0.30319\csc.exe' /nologo /platform:x86 \
     /r:System.Management.dll WmiTest.cs
wine WmiTest.exe sta 4     # Wine 11.20: first query OK, the next three fail
wine WmiTest.exe mta 4     # all four OK
```

Expected on Windows: every query succeeds in both modes. With the fix from
`scripts/build-wbemprox.sh` the same holds under Wine.
