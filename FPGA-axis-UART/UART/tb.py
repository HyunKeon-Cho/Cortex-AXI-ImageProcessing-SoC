
import serial
import threading

PORT = "/dev/ttyUSB0"
BAUDRATE = 115200

ser = serial.Serial(
    port=PORT,
    baudrate=BAUDRATE,
    bytesize=serial.EIGHTBITS,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    timeout=0.1
)

def receive():
    while ser.is_open:
        try:
            data = ser.read(ser.in_waiting or 1)
            if data:
                print(f"\nRX (HEX): {data.hex(' ')}")
                print(f"RX (TEXT): {data.decode('utf-8', errors='replace')}")
        except serial.SerialException:
            break

threading.Thread(target=receive, daemon=True).start()

try:
    while True:
        message = input("TX > ")
        ser.write(message.encode("utf-8"))

except (KeyboardInterrupt, EOFError):
    print("\nUART 종료")

finally:
    ser.close()
