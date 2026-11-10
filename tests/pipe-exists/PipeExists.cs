// File.Exists on a named pipe. TIA Portal uses this to confirm that its
// .NET Remoting IPC channel is up ("Channel is not registered." if false).
// Build: csc /r:System.Core.dll PipeExists.cs    Run: PipeExists.exe
using System;
using System.IO;
using System.IO.Pipes;

static class PipeExists
{
    static int Main()
    {
        string name = "tia-portal-wine-test-" + Guid.NewGuid().ToString("N");
        using (var server = new NamedPipeServerStream(name, PipeDirection.InOut, 4,
                                                      PipeTransmissionMode.Byte, PipeOptions.Asynchronous))
        {
            server.BeginWaitForConnection(ar => { }, null);
            bool present = File.Exists(@"\\.\pipe\" + name);
            bool absent = File.Exists(@"\\.\pipe\" + name + "-missing");
            Console.WriteLine("existing pipe: " + present + " (expected True)");
            Console.WriteLine("missing pipe:  " + absent + " (expected False)");
            return (present && !absent) ? 0 : 1;
        }
    }
}
