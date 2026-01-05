import asyncio
import websockets
import pyvjoy
import pyautogui
from pynput.mouse import Controller


j = pyvjoy.VJoyDevice(1)
mouse = Controller()


def clamp(x, lo, hi):
    return max(lo, min(hi, x))

async def press_and_release(button_id, delay_ms=100):
    j.set_button(button_id, 1)
    await asyncio.sleep(delay_ms / 1000)
    j.set_button(button_id, 0)

async def handle_message(message: str):
    if ":" not in message:
        return

    control, s_val = message.split(":", 1)

    if control == "steer":
        try:
            val = float(s_val)
            val = clamp(val, -1.0, 1.0)
            scaled = int((val + 1.0) / 2.0 * 32767)
            j.set_axis(pyvjoy.HID_USAGE_X, scaled)
            print(f"STEER {val:.5f} → {scaled}")
        except ValueError:
            pass

    elif control == "gas":
        try:
            val = float(s_val)
            val = clamp(val, 0.0, 1.0)
            scaled = int(val * 32767)
            j.set_axis(pyvjoy.HID_USAGE_Y, scaled)
            print(f"GAS   {val:.5f} → {scaled}")
        except ValueError:
            pass

    elif control == "brake":
        try:
            val = float(s_val)
            val = clamp(val, 0.0, 1.0)
            scaled = int(val * 32767)
            j.set_axis(pyvjoy.HID_USAGE_Z, scaled)
            print(f"BRAKE {val:.5f} → {scaled}")
        except ValueError:
            pass

    elif control == "signal":
        if s_val == "left":
            await press_and_release(1)
            print("SIGNAL LEFT")
        elif s_val == "right":
            await press_and_release(2)
            print("SIGNAL RIGHT")
        elif s_val == "hazard":
            await press_and_release(1)
            await press_and_release(2)
            print("SIGNAL HAZARD")

    elif control == "camera":
        dx_str, dy_str = s_val.split(",")
        dx = float(dx_str)
        dy = float(dy_str)

        cam_x = int(((dx * 10 + 1.0) / 2.0) * 32767)

        cam_y = int(((dx * 10 + 1.0) / 2.0) * 32767)


        j.set_axis(pyvjoy.HID_USAGE_RX, cam_x)  # horizontal
        j.set_axis(pyvjoy.HID_USAGE_RZ, cam_y)  # vertical



async def handler(websocket):
    print("Client connected")
    try:
        async for message in websocket:
            await handle_message(message)
    except Exception as e:
        print("Error:", e)
    finally:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 8765, ping_interval=None, ping_timeout=None):
        print("Server running on ws://0.0.0.0:8765")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())