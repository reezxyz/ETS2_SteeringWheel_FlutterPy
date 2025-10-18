import asyncio, websockets, pyvjoy

j = pyvjoy.VJoyDevice(1)

async def handler(websocket):
    print("Client connected")
    try:
        async for message in websocket:
            val = float(message)  # -1.0 .. 1.0
            scaled = int((val + 1) / 2 * 32767)
            j.set_axis(pyvjoy.HID_USAGE_X, scaled)
            print(f"Raw: {val:.3f} -> vJoy: {scaled}")
    except Exception as e:
        print("Error:", e)
    finally:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 8765, ping_timeout=None, ping_interval=None):
        print("Server running on ws://0.0.0.0:8765")
        await asyncio.Future()

asyncio.run(main())