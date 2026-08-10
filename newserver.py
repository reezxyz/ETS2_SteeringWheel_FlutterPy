import asyncio
import json
import os
import socket
import threading
import uuid
import tkinter as tk
from tkinter import ttk, messagebox

import websockets
import pyvjoy


# ============================================================
# CONFIGURATION
# ============================================================

WEBSOCKET_HOST = "0.0.0.0"
WEBSOCKET_PORT = 8765

DISCOVERY_HOST = "0.0.0.0"
DISCOVERY_PORT = 8766

DISCOVERY_REQUEST = "STEERING_DISCOVER"
DISCOVERY_RESPONSE = "STEERING_SERVER"


# ============================================================
# SERVER STATE
# ============================================================

j = None
server_loop = None
websocket_server = None
shutdown_event = None

connected_clients = set()
connected_clients_lock = threading.Lock()

log_queue = None


# ============================================================
# DEVICE INFORMATION
# ============================================================

def get_local_ip():
    """
    Mendapatkan IP LAN PC tanpa perlu mengetahui IP secara manual.
    Tidak benar-benar mengirim data ke internet.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"
    finally:
        sock.close()


def get_device_id():
    """
    Membuat ID perangkat yang tetap untuk PC ini.
    ID disimpan di file lokal agar tidak berubah setiap aplikasi dibuka.
    """
    config_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "device_id.txt"
    )

    try:
        if os.path.exists(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                device_id = f.read().strip()

            if device_id:
                return device_id

        device_id = str(uuid.uuid4())

        with open(config_path, "w", encoding="utf-8") as f:
            f.write(device_id)

        return device_id

    except Exception:
        # Jika file tidak bisa dibuat, tetap gunakan ID sementara.
        return str(uuid.uuid4())


DEVICE_NAME = socket.gethostname()
DEVICE_ID = get_device_id()


# ============================================================
# LOGGING
# ============================================================

def log(message):
    if log_queue is not None:
        log_queue.put(message)


# ============================================================
# VJOY
# ============================================================

def initialize_vjoy():
    global j

    try:
        j = pyvjoy.VJoyDevice(1)
        log("vJoy device 1 initialized.")
        return True

    except Exception as e:
        j = None
        log(f"ERROR: Failed to initialize vJoy: {e}")
        return False


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


async def press_and_release(button_id, delay_ms=100):
    if j is None:
        return

    j.set_button(button_id, 1)
    await asyncio.sleep(delay_ms / 1000)
    j.set_button(button_id, 0)


# ============================================================
# WEBSOCKET CONTROL
# ============================================================

async def handle_message(message: str):
    if ":" not in message:
        return

    control, s_val = message.split(":", 1)

    # --------------------------------------------------------
    # STEERING
    # --------------------------------------------------------
    if control == "steer":
        try:
            val = float(s_val)
            val = clamp(val, -1.0, 1.0)

            if j is not None:
                scaled = int((val + 1.0) / 2.0 * 32767)
                j.set_axis(pyvjoy.HID_USAGE_X, scaled)

            log(f"STEER  {val:.5f}")

        except ValueError:
            pass

    # --------------------------------------------------------
    # GAS
    # --------------------------------------------------------
    elif control == "gas":
        try:
            val = float(s_val)
            val = clamp(val, 0.0, 1.0)

            if j is not None:
                scaled = int(val * 32767)
                j.set_axis(pyvjoy.HID_USAGE_Y, scaled)

            log(f"GAS    {val:.5f}")

        except ValueError:
            pass

    # --------------------------------------------------------
    # BRAKE
    # --------------------------------------------------------
    elif control == "brake":
        try:
            val = float(s_val)
            val = clamp(val, 0.0, 1.0)

            if j is not None:
                scaled = int(val * 32767)
                j.set_axis(pyvjoy.HID_USAGE_Z, scaled)

            log(f"BRAKE  {val:.5f}")

        except ValueError:
            pass

    # --------------------------------------------------------
    # SIGNAL
    # --------------------------------------------------------
    elif control == "signal":

        if s_val == "left":
            await press_and_release(1)
            log("SIGNAL LEFT")

        elif s_val == "right":
            await press_and_release(2)
            log("SIGNAL RIGHT")

        elif s_val == "hazard":
            await press_and_release(1)
            await press_and_release(2)
            log("SIGNAL HAZARD")

    # --------------------------------------------------------
    # CAMERA
    # --------------------------------------------------------
    elif control == "camera":

        try:
            dx_str, dy_str = s_val.split(",", 1)

            dx = float(dx_str)
            dy = float(dy_str)

            # Gunakan delta yang dikirim Flutter.
            # RX = horizontal
            # RZ = vertical
            cam_x = int(clamp((dx * 10.0 + 1.0) / 2.0, 0.0, 1.0) * 32767)
            cam_y = int(clamp((dy * 10.0 + 1.0) / 2.0, 0.0, 1.0) * 32767)

            if j is not None:
                j.set_axis(pyvjoy.HID_USAGE_RX, cam_x)
                j.set_axis(pyvjoy.HID_USAGE_RZ, cam_y)

        except (ValueError, TypeError):
            pass


# ============================================================
# WEBSOCKET CLIENT HANDLER
# ============================================================

async def websocket_handler(websocket):
    client_ip = "Unknown"

    try:
        if websocket.remote_address:
            client_ip = websocket.remote_address[0]

        with connected_clients_lock:
            connected_clients.add(websocket)

        log(f"Flutter connected: {client_ip}")

        await websocket.wait_closed()

    except Exception as e:
        log(f"WebSocket error ({client_ip}): {e}")

    finally:
        with connected_clients_lock:
            connected_clients.discard(websocket)

        log(f"Flutter disconnected: {client_ip}")


async def websocket_message_handler(websocket):
    """
    Menangani pesan WebSocket untuk versi websockets
    yang menggunakan async for.
    """
    client_ip = "Unknown"

    try:
        if websocket.remote_address:
            client_ip = websocket.remote_address[0]

        with connected_clients_lock:
            connected_clients.add(websocket)

        log(f"Flutter connected: {client_ip}")

        async for message in websocket:
            await handle_message(message)

    except Exception as e:
        log(f"WebSocket error ({client_ip}): {e}")

    finally:
        with connected_clients_lock:
            connected_clients.discard(websocket)

        log(f"Flutter disconnected: {client_ip}")


# ============================================================
# UDP DISCOVERY SERVER
# ============================================================

class DiscoveryProtocol(asyncio.DatagramProtocol):

    def __init__(self):
        self.transport = None

    def connection_made(self, transport):
        self.transport = transport

        local_ip = get_local_ip()

        log(
            f"Discovery server running on "
            f"{local_ip}:{DISCOVERY_PORT}"
        )

    def datagram_received(self, data, addr):
        try:
            message = data.decode("utf-8").strip()

            if message != DISCOVERY_REQUEST:
                return

            requester_ip, requester_port = addr

            local_ip = get_local_ip()

            response = {
                "type": DISCOVERY_RESPONSE,
                "name": DEVICE_NAME,
                "id": DEVICE_ID,
                "ip": local_ip,
                "port": WEBSOCKET_PORT
            }

            response_data = json.dumps(response).encode("utf-8")

            self.transport.sendto(response_data, addr)

            log(
                f"Discovery request from "
                f"{requester_ip}:{requester_port}"
            )

        except Exception as e:
            log(f"Discovery error: {e}")


# ============================================================
# ASYNC SERVER
# ============================================================

async def async_server_main():
    global websocket_server
    global shutdown_event

    shutdown_event = asyncio.Event()

    # --------------------------------------------------------
    # WEBSOCKET
    # --------------------------------------------------------

    websocket_server = await websockets.serve(
        websocket_message_handler,
        WEBSOCKET_HOST,
        WEBSOCKET_PORT,
        ping_interval=None,
        ping_timeout=None
    )

    local_ip = get_local_ip()

    log("")
    log("==========================================")
    log(" ETS2 CONTROLLER SERVER")
    log("==========================================")
    log(f"Device : {DEVICE_NAME}")
    log(f"IP     : {local_ip}")
    log(f"WS     : {WEBSOCKET_PORT}")
    log(f"UDP    : {DISCOVERY_PORT}")
    log("==========================================")
    log("Waiting for Flutter device...")
    log("")

    # --------------------------------------------------------
    # UDP DISCOVERY
    # --------------------------------------------------------

    transport, protocol = await server_loop.create_datagram_endpoint(
        lambda: DiscoveryProtocol(),
        local_addr=(DISCOVERY_HOST, DISCOVERY_PORT),
        allow_broadcast=True
    )

    try:
        await shutdown_event.wait()

    finally:
        transport.close()
        websocket_server.close()
        await websocket_server.wait_closed()


def run_async_server():
    global server_loop

    try:
        server_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(server_loop)

        server_loop.run_until_complete(async_server_main())

    except Exception as e:
        log(f"SERVER ERROR: {e}")

    finally:
        if server_loop:
            server_loop.close()

        log("Server stopped.")


# ============================================================
# WINDOWS GUI
# ============================================================

class ControllerServerApp:

    def __init__(self, root):
        self.root = root

        self.root.title("ETS2 Controller Server")
        self.root.geometry("720x520")
        self.root.minsize(650, 450)

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        self.running = False
        self.server_thread = None

        self.create_style()
        self.create_ui()

        self.update_gui()

        self.start_server()

    # --------------------------------------------------------
    # STYLE
    # --------------------------------------------------------

    def create_style(self):

        style = ttk.Style()

        try:
            style.theme_use("clam")
        except Exception:
            pass

        style.configure(
            "Title.TLabel",
            font=("Segoe UI", 20, "bold")
        )

        style.configure(
            "Header.TLabel",
            font=("Segoe UI", 11, "bold")
        )

        style.configure(
            "Status.TLabel",
            font=("Segoe UI", 11)
        )

    # --------------------------------------------------------
    # UI
    # --------------------------------------------------------

    def create_ui(self):

        main = ttk.Frame(self.root, padding=20)
        main.pack(fill="both", expand=True)

        # ----------------------------------------------------
        # HEADER
        # ----------------------------------------------------

        header = ttk.Frame(main)
        header.pack(fill="x")

        ttk.Label(
            header,
            text="ETS2 Controller Server",
            style="Title.TLabel"
        ).pack(side="left")

        self.status_label = ttk.Label(
            header,
            text="● Starting...",
            style="Status.TLabel"
        )

        self.status_label.pack(side="right")

        # ----------------------------------------------------
        # DEVICE INFORMATION
        # ----------------------------------------------------

        info_frame = ttk.LabelFrame(
            main,
            text="Server Information",
            padding=15
        )

        info_frame.pack(
            fill="x",
            pady=(20, 10)
        )

        self.device_label = ttk.Label(
            info_frame,
            text=f"Device: {DEVICE_NAME}"
        )

        self.device_label.pack(anchor="w", pady=3)

        self.ip_label = ttk.Label(
            info_frame,
            text=f"IP Address: {get_local_ip()}"
        )

        self.ip_label.pack(anchor="w", pady=3)

        self.websocket_label = ttk.Label(
            info_frame,
            text=f"WebSocket: {WEBSOCKET_PORT}"
        )

        self.websocket_label.pack(anchor="w", pady=3)

        self.discovery_label = ttk.Label(
            info_frame,
            text=f"Discovery: UDP {DISCOVERY_PORT}"
        )

        self.discovery_label.pack(anchor="w", pady=3)

        # ----------------------------------------------------
        # CONNECTION
        # ----------------------------------------------------

        connection_frame = ttk.LabelFrame(
            main,
            text="Flutter Connection",
            padding=15
        )

        connection_frame.pack(
            fill="x",
            pady=10
        )

        self.connection_label = ttk.Label(
            connection_frame,
            text="Waiting for Flutter device...",
            style="Header.TLabel"
        )

        self.connection_label.pack(anchor="w")

        self.connection_detail = ttk.Label(
            connection_frame,
            text="No controller connected"
        )

        self.connection_detail.pack(
            anchor="w",
            pady=(5, 0)
        )

        # ----------------------------------------------------
        # LOG
        # ----------------------------------------------------

        log_frame = ttk.LabelFrame(
            main,
            text="Server Log",
            padding=10
        )

        log_frame.pack(
            fill="both",
            expand=True,
            pady=(10, 0)
        )

        self.log_text = tk.Text(
            log_frame,
            height=10,
            state="disabled",
            bg="#111111",
            fg="#dddddd",
            insertbackground="white",
            font=("Consolas", 9),
            relief="flat"
        )

        self.log_text.pack(
            side="left",
            fill="both",
            expand=True
        )

        scrollbar = ttk.Scrollbar(
            log_frame,
            orient="vertical",
            command=self.log_text.yview
        )

        scrollbar.pack(
            side="right",
            fill="y"
        )

        self.log_text.configure(
            yscrollcommand=scrollbar.set
        )

        # ----------------------------------------------------
        # FOOTER
        # ----------------------------------------------------

        footer = ttk.Frame(main)
        footer.pack(
            fill="x",
            pady=(10, 0)
        )

        self.stop_button = ttk.Button(
            footer,
            text="Stop Server",
            command=self.stop_server
        )

        self.stop_button.pack(side="right")

    # --------------------------------------------------------
    # START SERVER
    # --------------------------------------------------------

    def start_server(self):

        if self.running:
            return

        self.running = True

        if not initialize_vjoy():
            self.status_label.configure(
                text="● vJoy Error"
            )
        else:
            self.status_label.configure(
                text="● Server Starting..."
            )

        self.server_thread = threading.Thread(
            target=run_async_server,
            daemon=True
        )

        self.server_thread.start()

    # --------------------------------------------------------
    # STOP SERVER
    # --------------------------------------------------------

    def stop_server(self):

        if not self.running:
            return

        self.running = False

        self.status_label.configure(
            text="● Stopping..."
        )

        if server_loop and shutdown_event:

            try:
                server_loop.call_soon_threadsafe(
                    shutdown_event.set
                )
            except Exception:
                pass

        self.stop_button.configure(
            state="disabled"
        )

    # --------------------------------------------------------
    # GUI UPDATE
    # --------------------------------------------------------

    def update_gui(self):

        # -----------------------------------------------
        # Process log queue
        # -----------------------------------------------

        while True:

            try:
                message = log_queue.get_nowait()

            except Exception:
                break

            self.append_log(message)

            if message.startswith("Flutter connected:"):

                ip = message.split(":", 1)[1].strip()

                self.connection_label.configure(
                    text="● Flutter Connected"
                )

                self.connection_detail.configure(
                    text=f"Android IP: {ip}"
                )

                self.status_label.configure(
                    text="● Online"
                )

            elif message.startswith("Flutter disconnected:"):

                self.connection_label.configure(
                    text="Waiting for Flutter device..."
                )

                self.connection_detail.configure(
                    text="No controller connected"
                )

                if self.running:
                    self.status_label.configure(
                        text="● Online"
                    )

        # Refresh local IP in case network changes.
        self.ip_label.configure(
            text=f"IP Address: {get_local_ip()}"
        )

        self.root.after(
            100,
            self.update_gui
        )

    # --------------------------------------------------------
    # LOG APPEND
    # --------------------------------------------------------

    def append_log(self, message):

        self.log_text.configure(
            state="normal"
        )

        self.log_text.insert(
            "end",
            message + "\n"
        )

        self.log_text.see("end")

        self.log_text.configure(
            state="disabled"
        )

    # --------------------------------------------------------
    # CLOSE
    # --------------------------------------------------------

    def on_close(self):

        if self.running:

            result = messagebox.askyesno(
                "Exit",
                "Stop the ETS2 Controller Server?"
            )

            if not result:
                return

            self.stop_server()

        self.root.after(
            300,
            self.root.destroy
        )


# ============================================================
# MAIN
# ============================================================

def main():

    global log_queue

    import queue

    log_queue = queue.Queue()

    root = tk.Tk()

    app = ControllerServerApp(root)

    root.mainloop()


if __name__ == "__main__":
    main()