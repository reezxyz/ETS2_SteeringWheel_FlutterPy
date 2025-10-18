# 🚛 ETS2 Mobile Controller

**ETS2 Mobile Controller** is a virtual steering wheel and pedal system for *Euro Truck Simulator 2*, built with Flutter and Python. It transforms your smartphone into a responsive, ergonomic game controller — no physical hardware required.

Designed for thumb-friendly steering, spring-loaded pedals, and real-time input over local Wi-Fi, this project brings immersive driving to your fingertips. I will update this project as good as i can. Stay tune, this project is usable for now with limited features

---

## 🎮 Features

- 🧭 **Realistic Steering Wheel**  
  Rotate up to 960° with smooth input streaming to ETS2 via WebSocket and vJoy.

- 🦶 **Spring-Loaded Gas & Brake Pedals**  
  Vertical sliders that reset to zero when released, mimicking real vehicle pedals.

- 🌗 **Modern Dark Theme**  
  Sleek silver/gray/black styling with radial gradients and a centered car icon.

- 📡 **Local Wi-Fi Communication**  
  Fast, low-latency input transmission between phone and PC.

- ⚙️ **Python Server + vJoy Integration**  
  Input values are received by a Python WebSocket server and mapped to vJoy axes.

---

## 🖼️ UI Layout

- Landscape orientation:
  - **Left side**: Steering wheel (optimized for left thumb comfort)
  - **Right side**: Gas and brake sliders side-by-side, full height

---

## 🚀 How It Works

1. **Flutter App**  
   - Sends normalized input (`steer`, `gas`, `brake`) via WebSocket.

2. **Python Server**  
   - Receives input and updates vJoy virtual joystick axes.

3. **ETS2 Game**  
   - Detects vJoy as a controller and responds to input in real time.

---

## 🛠️ Setup
**AVAILABLE SOON**
