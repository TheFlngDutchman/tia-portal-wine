// Read the public key of an X.509 certificate with an elliptic-curve key and
// check a signature with it, the way TIA Portal's hardware compile validates
// PLC communication certificates.
// Make test certificates first: ./make-certs.sh
// Build: csc /r:System.Core.dll EcdsaCert.cs    Run: EcdsaCert.exe p256 p384 p521
using System;
using System.IO;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

static class EcdsaCert
{
    static int Main(string[] names)
    {
        int failed = 0;
        foreach (var name in names)
        {
            try
            {
                var cert = new X509Certificate2(name + ".cer");
                using (ECDsa key = cert.GetECDsaPublicKey())
                {
                    byte[] data = File.ReadAllBytes(name + ".dat");
                    byte[] sig = File.ReadAllBytes(name + ".sig");
                    bool good = key.VerifyData(data, sig, HashAlgorithmName.SHA256);
                    data[0] ^= 1;
                    bool bad = key.VerifyData(data, sig, HashAlgorithmName.SHA256);
                    bool ok = good && !bad;
                    if (!ok) failed++;
                    Console.WriteLine((ok ? "OK:   " : "FAIL: ") + name + ": key size " + key.KeySize +
                                      ", signature verifies " + good + ", tampered data verifies " + bad);
                }
            }
            catch (Exception e)
            {
                failed++;
                Console.WriteLine("FAIL: " + name + ": " + e.GetType().Name + ": " + e.Message);
            }
        }
        return failed;
    }
}
