// ECDH key agreement through CNG (ncrypt), the way TIA Portal's project
// storage helper sets up its encrypted client link.
// Build: csc /r:System.Core.dll EcdhCng.cs    Run: EcdhCng.exe
using System;
using System.Linq;
using System.Security.Cryptography;

static class EcdhCng
{
    static ECDiffieHellmanCng NewParty(int keySize)
    {
        var p = keySize == 0 ? new ECDiffieHellmanCng() : new ECDiffieHellmanCng(keySize);
        p.KeyDerivationFunction = ECDiffieHellmanKeyDerivationFunction.Hash;
        p.HashAlgorithm = CngAlgorithm.Sha512;
        return p;
    }

    static bool Run(int keySize)
    {
        try
        {
            using (var a = NewParty(keySize))
            using (var b = NewParty(keySize))
            {
                byte[] pubA = a.PublicKey.ToByteArray();
                byte[] pubB = b.PublicKey.ToByteArray();
                byte[] keyA = a.DeriveKeyMaterial(CngKey.Import(pubB, CngKeyBlobFormat.EccPublicBlob));
                byte[] keyB = b.DeriveKeyMaterial(CngKey.Import(pubA, CngKeyBlobFormat.EccPublicBlob));
                bool ok = keyA.Length == 64 && keyA.SequenceEqual(keyB);
                Console.WriteLine((ok ? "OK" : "FAIL") + ": key size " + a.KeySize + ", public blob " +
                                  pubA.Length + " bytes, derived " + keyA.Length + " bytes, match " +
                                  keyA.SequenceEqual(keyB));
                return ok;
            }
        }
        catch (Exception e)
        {
            Console.WriteLine("FAIL: key size " + keySize + ": " + e.GetType().Name + ": " + e.Message);
            return false;
        }
    }

    static int Main()
    {
        bool ok = true;
        foreach (int size in new[] { 0, 256, 384, 521 }) ok &= Run(size);   // 0 = default constructor
        return ok ? 0 : 1;
    }
}
