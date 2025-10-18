import asyncio
import websockets
import pyvjoy

j = pyvjoy.VJoyDevice(1)

def clamp(x, lo, hi):
  return max(lo, min(hi, x))

async def handler(websocket):
    print("Client connected")
    try:
        async for message in websocket:
            # Format message: "steer:<val>", "gas:<val>", "brake:<val>"
            # steer: -1.0..1.0; gas/brake: 0.0..1.0
            if ":" not in message:
                continue

            control, s_val = message.split(":")
            try:
                val = float(s_val)
            except:
                continue

            if control == "steer":
                val = clamp(val, -1.0, 1.0)
                scaled = int((val + 1.0) / 2.0 * 32767)
                j.set_axis(pyvjoy.HID_USAGE_X, scaled)
                print(f"STEER {val:.3f} -> {scaled}")
            elif control == "gas":
                val = clamp(val, 0.0, 1.0)
                scaled = int(val * 32767)
                j.set_axis(pyvjoy.HID_USAGE_Y, scaled)
                print(f"GAS   {val:.3f} -> {scaled}")
            elif control == "brake":
                val = clamp(val, 0.0, 1.0)
                scaled = int(val * 32767)
                j.set_axis(pyvjoy.HID_USAGE_Z, scaled)
                print(f"BRAKE {val:.3f} -> {scaled}")
    except Exception as e:
        print("Error:", e)
    finally:
        print("Client disconnected")

async def main():
    # Ganti host menjadi IP PC jika perlu, atau tetap 0.0.0.0 untuk semua interface
    async with websockets.serve(handler, "0.0.0.0", 8765, ping_interval=None, ping_timeout=None):
        print("Server running on ws://0.0.0.0:8765")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())