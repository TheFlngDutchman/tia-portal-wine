#!/usr/bin/env python3
"""Read-only look at what an NTFS volume really says about itself and a file.

Reports the values Windows hands out for:
  - the volume serial number          (GetVolumeInformation)
  - a file's object ID                (FSCTL_GET_OBJECT_ID)
  - where a file's data sits on disk  (FSCTL_GET_RETRIEVAL_POINTERS)

usage: ntfs_probe.py <block device> [<MFT record number> ...] [--show-ids]

The MFT record number of a file is its inode number on a Linux ntfs3 mount
(stat -c %i <file>). Needs read access to the block device; never writes.
"""
import struct
import sys


def fixup(rec, sector=512):
    """Undo the update sequence array of a multi-sector record."""
    usa_ofs, usa_count = struct.unpack_from('<HH', rec, 4)
    rec = bytearray(rec)
    for i in range(1, usa_count):
        pos = i * sector - 2
        rec[pos:pos + 2] = rec[usa_ofs + 2 * i:usa_ofs + 2 * i + 2]
    return bytes(rec)


def runs(data):
    """Decode a mapping pairs array into (lcn or None, cluster count) tuples."""
    out, pos, lcn = [], 0, 0
    while pos < len(data) and data[pos]:
        hdr = data[pos]
        len_size, ofs_size = hdr & 0xf, hdr >> 4
        pos += 1
        length = int.from_bytes(data[pos:pos + len_size], 'little')
        pos += len_size
        if ofs_size:
            lcn += int.from_bytes(data[pos:pos + ofs_size], 'little', signed=True)
            out.append((lcn, length))
        else:
            out.append((None, length))      # sparse
        pos += ofs_size
    return out


def attributes(rec):
    pos = struct.unpack_from('<H', rec, 20)[0]
    while pos + 8 <= len(rec):
        atype, alen = struct.unpack_from('<II', rec, pos)
        if atype == 0xffffffff or not alen:
            break
        yield atype, rec[pos:pos + alen]
        pos += alen


class Volume:
    def __init__(self, path):
        self.f = open(path, 'rb')
        boot = self.f.read(512)
        if boot[3:11] != b'NTFS    ':
            sys.exit('not an NTFS volume')
        self.bytes_per_sector = struct.unpack_from('<H', boot, 11)[0]
        self.cluster = self.bytes_per_sector * boot[13]
        self.mft_lcn = struct.unpack_from('<Q', boot, 48)[0]
        size = struct.unpack_from('<b', boot, 64)[0]
        self.record = (1 << -size) if size < 0 else size * self.cluster
        self.serial = struct.unpack_from('<Q', boot, 72)[0]
        # $MFT may be fragmented: take its own run list from record 0.
        rec0 = self.read_at(self.mft_lcn * self.cluster, self.record)
        self.mft_runs = None
        for atype, attr in attributes(fixup(rec0, self.bytes_per_sector)):
            if atype == 0x80 and attr[8]:
                self.mft_runs = runs(attr[struct.unpack_from('<H', attr, 32)[0]:])

    def read_at(self, offset, size):
        self.f.seek(offset)
        return self.f.read(size)

    def mft_record(self, number):
        offset = number * self.record
        for lcn, length in self.mft_runs:
            run_bytes = length * self.cluster
            if offset < run_bytes:
                return fixup(self.read_at(lcn * self.cluster + offset, self.record), self.bytes_per_sector)
            offset -= run_bytes
        sys.exit('record %d outside $MFT' % number)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    show = '--show-ids' in sys.argv
    if not args:
        sys.exit(__doc__)
    vol = Volume(args[0])
    serial = '%04X-%04X' % ((vol.serial >> 16) & 0xffff, vol.serial & 0xffff)
    print('volume: cluster size %d, MFT record size %d, serial %s' %
          (vol.cluster, vol.record, serial if show else '<present, %d bits>' % vol.serial.bit_length()))
    for number in map(int, args[1:]):
        rec = vol.mft_record(number)
        if rec[:4] != b'FILE':
            print('record %d: not in use' % number)
            continue
        seq = struct.unpack_from('<H', rec, 16)[0]
        print('record %d: sequence number %d, file reference 0x%016x' % (number, seq, (seq << 48) | number))
        for atype, attr in attributes(rec):
            nonresident = attr[8]
            if atype == 0x10:       # $STANDARD_INFORMATION
                body = attr[struct.unpack_from('<H', attr, 20)[0]:]
                created, modified, changed, accessed, flags = struct.unpack_from('<QQQQI', body, 0)
                print('  attributes: 0x%08x, created %d, modified %d' % (flags, created, modified))
            elif atype == 0x30:     # $FILE_NAME
                body = attr[struct.unpack_from('<H', attr, 20)[0]:]
                name = body[66:66 + 2 * body[64]].decode('utf-16le')
                print('  name: %s' % name)
            elif atype == 0x40:     # $OBJECT_ID
                body = attr[struct.unpack_from('<H', attr, 20)[0]:][:struct.unpack_from('<I', attr, 16)[0]]
                print('  object id: %s (%d bytes)' % (body[:16].hex() if show else '<present>', len(body)))
            elif atype == 0x80:     # $DATA
                if nonresident:
                    rl = runs(attr[struct.unpack_from('<H', attr, 32)[0]:])
                    size = struct.unpack_from('<Q', attr, 48)[0]
                    print('  data: %d bytes, non-resident, runs (lcn, clusters): %s' % (size, rl))
                else:
                    print('  data: %d bytes, resident in the MFT record' % struct.unpack_from('<I', attr, 16)[0])
        if not any(atype == 0x40 for atype, _ in attributes(rec)):
            print('  object id: none')


if __name__ == '__main__':
    main()
