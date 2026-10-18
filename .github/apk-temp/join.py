"""Puts the AK signature on the Android app built here.

Signing with the AK key (done outside GitHub, the key never comes here)
keeps every file of the app as it is and only replaces what follows them:
the signature block and the zip index. ak-signature.tail is that part.
Usage: join.py built.apk ak-signature.tail signed.apk
"""
import struct
import sys

data = open(sys.argv[1], 'rb').read()
eocd = data.rfind(b'PK\x05\x06')
index = struct.unpack('<I', data[eocd + 16:eocd + 20])[0]
if data[index - 16:index] != b'APK Sig Block 42':
    sys.exit('the build has no signature block')
size = struct.unpack('<Q', data[index - 24:index - 16])[0]
files = data[:index - size - 8]
with open(sys.argv[3], 'wb') as out:
    out.write(files + open(sys.argv[2], 'rb').read())
