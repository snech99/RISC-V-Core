#!/usr/bin/env python3
"""send_app.py -- laedt ein App-Binary in den RV32IM-Bootloader und zeigt die Ausgabe.

Benutzung:
    python3 send_app.py app_demo.bin [/dev/ttyUSB1] [baud]

WICHTIG: picocom/anderen Terminal vorher schliessen (Port wird sonst blockiert).
Mit Strg-C beenden.
"""
import sys, time, struct

try:
    import serial
except ImportError:
    sys.exit("pyserial fehlt:  pip install pyserial")

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    port = sys.argv[2] if len(sys.argv) > 2 else "/dev/ttyUSB1"
    baud = int(sys.argv[3]) if len(sys.argv) > 3 else 115200

    data = open(path, "rb").read()
    cks = 0
    for b in data:
        cks ^= b

    ser = serial.Serial(port, baud, timeout=0.2)
    time.sleep(0.1)
    ser.reset_input_buffer()

    print(f"-> {len(data)} Bytes, XOR=0x{cks:02X}, an {port}@{baud}")
    ser.write(b"l")                          # Load-Kommando
    ser.write(struct.pack("<I", len(data)))  # Laenge (4 Byte LE)
    ser.write(data)                          # die Nutzdaten
    ser.write(bytes([cks]))                  # Pruefsumme
    ser.flush()

    # Ausgabe streamen (Monitor), bis Strg-C
    try:
        while True:
            chunk = ser.read(256)
            if chunk:
                sys.stdout.write(chunk.decode("latin1"))
                sys.stdout.flush()
    except KeyboardInterrupt:
        print("\n(beendet)")
    finally:
        ser.close()

if __name__ == "__main__":
    main()
