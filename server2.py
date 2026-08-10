import asyncio
import os
import socket
import threading
import uuid
import tkinter as tk
from tkinter import ttk, messagebox

import websockets
import pyvjoy

from zeroconf import ServiceInfo, IPVersion
from zeroconf.asyncio import AsyncZeroconf


# ============================================================
# CONFIGURATION
# ============================================================

WEBSOCKET_HOST = "0.0.0.0"
WEBSOCKET_PORT = 8765

MDNS_SERVICE_TYPE = "_ets2controller._tcp.local."


# ============================================================
# SERVER STATE
# ============================================================

j = None

server_loop = None
websocket_server = None
shutdown_event = None

mdns = None
mdns_service = None

connected_clients = set()
connected_clients_lock = threading.Lock()

log_queue = None


# ============================================================
# DEVICE INFORMATION
# ============================================================

def get_local_ip():
    """
    Mendapatkan IP LAN aktif yang digunakan PC untuk keluar
    ke jaringan lokal.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]

    except Exception:
        try:
            hostname = socket.gethostname()

            for info in socket.getaddrinfo(
                hostname,
                None,
                socket.AF_INET,
                socket.SOCK_STREAM
            ):
                address = info[4][0]

                if not address.startswith("127."):
                    return address

        except Exception:
            pass

        return "127.0.0.1"

    finally:
        sock.close()


def get_device_id():
    """
    Membuat ID perangkat yang tetap untuk PC ini.
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

    await asyncio.sleep(
        delay_ms / 1000
    )

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

            val = clamp(
                val,
                -1.0,
                1.0
            )

            if j is not None:
                scaled = int(
                    (val + 1.0)
                    / 2.0
                    * 32767
                )

                j.set_axis(
                    pyvjoy.HID_USAGE_X,
                    scaled
                )

        except ValueError:
            pass

    # --------------------------------------------------------
    # GAS
    # --------------------------------------------------------

    elif control == "gas":

        try:
            val = float(s_val)

            val = clamp(
                val,
                0.0,
                1.0
            )

            if j is not None:
                scaled = int(
                    val * 32767
                )

                j.set_axis(
                    pyvjoy.HID_USAGE_Y,
                    scaled
                )

        except ValueError:
            pass

    # --------------------------------------------------------
    # BRAKE
    # --------------------------------------------------------

    elif control == "brake":

        try:
            val = float(s_val)

            val = clamp(
                val,
                0.0,
                1.0
            )

            if j is not None:
                scaled = int(
                    val * 32767
                )

                j.set_axis(
                    pyvjoy.HID_USAGE_Z,
                    scaled
                )

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

            cam_x = int(
                clamp(
                    (dx * 10.0 + 1.0) / 2.0,
                    0.0,
                    1.0
                ) * 32767
            )

            cam_y = int(
                clamp(
                    (dy * 10.0 + 1.0) / 2.0,
                    0.0,
                    1.0
                ) * 32767
            )

            if j is not None:

                j.set_axis(
                    pyvjoy.HID_USAGE_RX,
                    cam_x
                )

                j.set_axis(
                    pyvjoy.HID_USAGE_RZ,
                    cam_y
                )

        except (ValueError, TypeError):
            pass


# ============================================================
# WEBSOCKET HANDLER
# ============================================================

async def websocket_message_handler(websocket):

    client_ip = "Unknown"

    try:

        if websocket.remote_address:
            client_ip = websocket.remote_address[0]

        with connected_clients_lock:
            connected_clients.add(websocket)

        log(
            f"Flutter connected: {client_ip}"
        )

        async for message in websocket:
            await handle_message(message)

    except Exception as e:

        log(
            f"WebSocket error "
            f"({client_ip}): {e}"
        )

    finally:

        with connected_clients_lock:
            connected_clients.discard(websocket)

        log(
            f"Flutter disconnected: "
            f"{client_ip}"
        )


# ============================================================
# mDNS SERVICE
# ============================================================

async def register_mdns_service():
    global mdns
    global mdns_service

    local_ip = get_local_ip()

    if local_ip == "127.0.0.1":
        raise RuntimeError(
            "Could not determine LAN IP for mDNS."
        )

    log(
        f"mDNS: Using LAN interface {local_ip}"
    )

    service_name = (
        f"{DEVICE_NAME}"
        f".{MDNS_SERVICE_TYPE}"
    )

    # AsyncZeroconf digunakan karena server kita
    # sudah berjalan di dalam asyncio event loop.
    mdns = AsyncZeroconf(
        interfaces=[local_ip],
        ip_version=IPVersion.V4Only
    )

    mdns_service = ServiceInfo(
        MDNS_SERVICE_TYPE,
        service_name,
        port=WEBSOCKET_PORT,
        parsed_addresses=[local_ip],
        properties={
            "id": DEVICE_ID,
            "name": DEVICE_NAME,
            "protocol": "websocket",
            "version": "1",
        },
        server=f"{DEVICE_NAME}.local.",
    )

    log(
        f"mDNS: Registering "
        f"{service_name}"
    )

    await mdns.async_register_service(
        mdns_service
    )

    log("")
    log("==========================================")
    log(" mDNS SERVICE")
    log("==========================================")
    log(
        f"Service : {MDNS_SERVICE_TYPE}"
    )
    log(
        f"Device  : {DEVICE_NAME}"
    )
    log(
        f"IP      : {local_ip}"
    )
    log(
        f"Port    : {WEBSOCKET_PORT}"
    )
    log("==========================================")
    log(
        "mDNS service registered successfully."
    )
    log(
        "Waiting for Flutter discovery..."
    )
    log("")


async def unregister_mdns_service():
    global mdns
    global mdns_service

    if mdns is None:
        return

    try:
        log("mDNS: Stopping service...")

        # AsyncZeroconf akan meng-unregister service
        # dan membersihkan resource mDNS dengan benar.
        await mdns.async_close()

        log(
            "mDNS: Service stopped successfully."
        )

    except Exception as e:
        log(
            f"mDNS cleanup error: "
            f"{type(e).__name__}: {e!r}"
        )

    finally:
        mdns = None
        mdns_service = None


# ============================================================
# ASYNC SERVER
# ============================================================

async def async_server_main():
    global websocket_server
    global shutdown_event

    shutdown_event = asyncio.Event()

    try:
        # ====================================================
        # WEBSOCKET SERVER
        # ====================================================

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
        log(
            f"Device : {DEVICE_NAME}"
        )
        log(
            f"IP     : {local_ip}"
        )
        log(
            f"WS     : {WEBSOCKET_PORT}"
        )
        log(
            "Discovery: mDNS"
        )
        log("==========================================")

        # ====================================================
        # mDNS
        # ====================================================

        await register_mdns_service()

        # ====================================================
        # WAIT UNTIL SERVER IS STOPPED
        # ====================================================

        await shutdown_event.wait()

    except Exception as e:

        log("")
        log(
            "=========================================="
        )
        log(
            " SERVER ERROR"
        )
        log(
            "=========================================="
        )
        log(
            f"Type: {type(e).__name__}"
        )
        log(
            f"Error: {e!r}"
        )
        log("")

        raise

    finally:

        # ====================================================
        # STOP mDNS FIRST
        # ====================================================

        try:
            await unregister_mdns_service()

        except Exception as e:
            log(
                f"mDNS shutdown error: "
                f"{type(e).__name__}: {e!r}"
            )

        # ====================================================
        # STOP WEBSOCKET
        # ====================================================

        if websocket_server is not None:

            try:

                websocket_server.close()

                await websocket_server.wait_closed()

                log(
                    "WebSocket server stopped."
                )

            except Exception as e:

                log(
                    f"WebSocket shutdown error: "
                    f"{type(e).__name__}: {e!r}"
                )

            finally:

                websocket_server = None


def run_async_server():
    global server_loop

    try:
        server_loop = asyncio.new_event_loop()

        asyncio.set_event_loop(
            server_loop
        )

        server_loop.run_until_complete(
            async_server_main()
        )

    except Exception as e:

        log("")
        log(
            "=========================================="
        )
        log(
            " SERVER THREAD ERROR"
        )
        log(
            "=========================================="
        )
        log(
            f"Type: {type(e).__name__}"
        )
        log(
            f"Error: {e!r}"
        )
        log("")

    finally:

        if server_loop is not None:

            try:

                # Pastikan semua task yang masih tertinggal
                # dibatalkan sebelum loop ditutup.
                pending = asyncio.all_tasks(
                    server_loop
                )

                if pending:

                    for task in pending:
                        task.cancel()

                    server_loop.run_until_complete(
                        asyncio.gather(
                            *pending,
                            return_exceptions=True
                        )
                    )

            except Exception as e:

                log(
                    f"Event loop cleanup error: "
                    f"{type(e).__name__}: {e!r}"
                )

            finally:

                server_loop.close()

                server_loop = None

        log(
            "Server stopped."
        )
        

# ============================================================
# WINDOWS GUI
# ============================================================

class ControllerServerApp:

    def __init__(self, root):

        self.root = root

        self.root.title(
            "ETS2 Controller Server"
        )

        self.root.geometry(
            "720x520"
        )

        self.root.minsize(
            650,
            450
        )

        self.root.protocol(
            "WM_DELETE_WINDOW",
            self.on_close
        )

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

        main = ttk.Frame(
            self.root,
            padding=20
        )

        main.pack(
            fill="both",
            expand=True
        )

        # ----------------------------------------------------
        # HEADER
        # ----------------------------------------------------

        header = ttk.Frame(main)

        header.pack(
            fill="x"
        )

        ttk.Label(
            header,
            text="ETS2 Controller Server",
            style="Title.TLabel"
        ).pack(
            side="left"
        )

        self.status_label = ttk.Label(
            header,
            text="● Starting...",
            style="Status.TLabel"
        )

        self.status_label.pack(
            side="right"
        )

        # ----------------------------------------------------
        # SERVER INFORMATION
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

        self.device_label.pack(
            anchor="w",
            pady=3
        )

        self.ip_label = ttk.Label(
            info_frame,
            text=f"IP Address: {get_local_ip()}"
        )

        self.ip_label.pack(
            anchor="w",
            pady=3
        )

        self.websocket_label = ttk.Label(
            info_frame,
            text=f"WebSocket: {WEBSOCKET_PORT}"
        )

        self.websocket_label.pack(
            anchor="w",
            pady=3
        )

        self.discovery_label = ttk.Label(
            info_frame,
            text="Discovery: mDNS"
        )

        self.discovery_label.pack(
            anchor="w",
            pady=3
        )

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

        self.connection_label.pack(
            anchor="w"
        )

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

        self.stop_button.pack(
            side="right"
        )

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

        while True:

            try:
                message = log_queue.get_nowait()

            except Exception:
                break

            self.append_log(message)

            if message.startswith(
                "Flutter connected:"
            ):

                ip = message.split(
                    ":",
                    1
                )[1].strip()

                self.connection_label.configure(
                    text="● Flutter Connected"
                )

                self.connection_detail.configure(
                    text=f"Android IP: {ip}"
                )

                self.status_label.configure(
                    text="● Online"
                )

            elif message.startswith(
                "Flutter disconnected:"
            ):

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

        self.ip_label.configure(
            text=f"IP Address: {get_local_ip()}"
        )

        self.root.after(
            100,
            self.update_gui
        )

    # --------------------------------------------------------
    # LOG
    # --------------------------------------------------------

    def append_log(self, message):

        self.log_text.configure(
            state="normal"
        )

        self.log_text.insert(
            "end",
            message + "\n"
        )

        self.log_text.see(
            "end"
        )

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

    ControllerServerApp(root)

    root.mainloop()


if __name__ == "__main__":
    main()
