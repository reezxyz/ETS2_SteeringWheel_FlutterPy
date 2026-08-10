# ETS2 Mobile Controller

ETS2 Mobile Controller lets you use your Android phone as a steering wheel and controller for Euro Truck Simulator 2.

The project consists of two parts:

- Android app built with Flutter
- Windows server built with Python

The phone connects to the Windows server over local Wi-Fi. The server receives the controller input and sends it to ETS2 through vJoy.

This project is still in development. The current version is usable, but some features are still limited and there may be bugs.

## Features

- Steering wheel with up to 960° rotation
- Gas and brake pedals
- Turn signals
- Hazard lights
- Camera controls
- Automatic PC discovery
- WebSocket communication
- vJoy support
- No manual IP address configuration required

## How It Works

```text
Android Phone
     |
     | Local Wi-Fi
     v
Windows Server
     |
     | WebSocket
     v
vJoy
     |
     v
Euro Truck Simulator 2
```

The Android app sends steering, pedal, signal, and camera input to the Windows server.

The Windows server receives the input and maps it to vJoy, which ETS2 can then use as a virtual controller.

## Requirements

### Android

- Android phone
- Android 6.0 or newer
- Connected to the same Wi-Fi network as the Windows PC

### Windows

- Windows PC
- [vJoy](https://sourceforge.net/projects/vjoystick/)
- ETS2 Controller Server
- Euro Truck Simulator 2

## Installation

### 1. Install vJoy

Download and install [vJoy from SourceForge](https://sourceforge.net/projects/vjoystick/).

After installing vJoy, make sure the virtual controller is enabled and working correctly.

The server uses vJoy to send the phone's input to ETS2.

### 2. Download the Windows Server

Download the latest Windows Server release from the Releases page.

Extract the ZIP file somewhere on your PC.

For example:

```text
ETS2-Controller-Server/
    ETS2 Controller Server Alpha.exe
    _internal/
    ...
```

Run:

```text
ETS2 Controller Server Alpha.exe
```

The server should start and register itself on the local network using mDNS.

You should see information similar to:

```text
ETS2 Controller Server
IP: 192.168.x.x
WebSocket: 8765
Discovery: mDNS
```

You do not need to enter this IP address into the Android app.

### 3. Install the Android App

Download the APK from the Releases page and install it on your Android phone.

Android may ask for permission to install an application from an unknown source depending on your device settings.

### 4. Connect the Phone and PC

Make sure both devices are connected to the same local Wi-Fi network.

Open the ETS2 Mobile Controller app.

The app will automatically search for available ETS2 Controller servers.

When your PC appears in the list, you should see information similar to:

```text
DESKTOP-XXXX
192.168.x.x
```

Select your PC and connect.

If the connection is successful, the controller can be used.

There is no need to manually enter the PC's IP address.

## Using the Controller

### Steering

Use the steering wheel on the left side of the screen to control the truck.

The steering input is sent to the Windows server in real time.

### Gas and Brake

The gas and brake controls are located on the right side of the screen.

The pedals are spring-loaded, so they return to their neutral position when released.

### Turn Signals

Use the turn signal controls to control the left and right indicators in ETS2.

### Hazard Lights

The hazard button can be used to toggle the truck's hazard lights.

### Camera

The camera controls can be used while driving to look around the truck.

## Setting Up ETS2

After the server and phone are connected, open Euro Truck Simulator 2.

Go to:

```text
Options
→ Controls
```

Make sure ETS2 detects the vJoy controller.

Assign the available vJoy axes/buttons to the controls you want to use.

For example:

```text
Steering  → vJoy steering axis
Throttle  → vJoy throttle axis
Brake     → vJoy brake axis
```

The exact axis and button assignments may depend on your vJoy configuration.

## Connection Flow

The current version uses mDNS for automatic server discovery.

```text
1. Start the Windows server
2. Windows registers the server on the local network
3. Open the Android app
4. Android searches for the server
5. The Windows PC appears in the device list
6. Select the PC
7. WebSocket connection is established
8. Controller input is sent to the server
```

Both devices must be connected to the same local network.

## Troubleshooting

### PC does not appear in the Android app

Check that:

- The phone and PC are connected to the same Wi-Fi network
- The Windows server is running
- Windows Firewall is not blocking the server
- The server shows that mDNS is running
- The phone is not using a different network or mobile data connection

Restarting the Windows server and scanning again can also help.

### The app finds the PC but cannot connect

Check that the Windows server is still running.

Also check whether another application is already using the server's WebSocket port.

### Steering or pedals do not work in ETS2

Make sure:

- vJoy is installed
- The vJoy controller is enabled
- Windows can detect the vJoy device
- ETS2 detects the vJoy controller
- The controls are correctly assigned in ETS2

### Connection is unstable

For the best results, connect both devices to the same Wi-Fi network and avoid using a VPN or network isolation features on the router.

## Current Status

Current version:

```text
0.1.0-alpha.1
```

This is an early alpha release.

The basic controller, Windows server, automatic PC discovery, WebSocket connection, and vJoy integration are working, but the project is still being developed.

More features and improvements will be added over time.

## Roadmap

Some things I want to improve in future versions:

- Better connection handling
- Automatic reconnect
- More controller customization
- More ETS2 controls
- Improved camera controls
- Better device management
- UI improvements
- More configuration options

## Download

Check the [Releases](../../releases) page for the latest Android APK and Windows Server build.

## License

This project is currently under development.
