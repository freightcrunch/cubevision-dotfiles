# 06 — GPIO

## 1. Install Jetson.GPIO

```bash
sudo pip3 install Jetson.GPIO
sudo groupadd -f gpio
sudo usermod -aG gpio $USER
```

Udev rules (usually pre-installed with JetPack):

```bash
sudo cp /opt/nvidia/jetson-gpio/etc/99-gpio.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
# Log out and back in
```

## 2. Pin Mapping

The Jetson Orin Nano uses a **40-pin GPIO header** compatible with Raspberry Pi pinout.

```bash
# Show pin mapping
sudo cat /sys/kernel/debug/gpio
# Or use:
sudo /opt/nvidia/jetson-io/jetson-io.py
```

Common pins (BOARD numbering):

| Pin | Function | GPIO Name |
|-----|----------|-----------|
| 7   | GPIO04   | GP16 |
| 11  | GPIO17   | GP11 |
| 12  | GPIO18   | GP79 (PWM) |
| 13  | GPIO27   | GP15 |
| 15  | GPIO22   | GP18 |
| 16  | GPIO23   | GP19 |
| 18  | GPIO24   | GP20 |
| 22  | GPIO25   | GP21 |
| 29  | GPIO05   | GP149 |
| 31  | GPIO06   | GP150 |
| 32  | GPIO12   | GP168 (PWM) |
| 33  | GPIO13   | GP169 (PWM) |

## 3. Basic Example — Blink LED

```python
import Jetson.GPIO as GPIO
import time

LED_PIN = 7  # BOARD pin 7

GPIO.setmode(GPIO.BOARD)
GPIO.setup(LED_PIN, GPIO.OUT)

try:
    while True:
        GPIO.output(LED_PIN, GPIO.HIGH)
        time.sleep(0.5)
        GPIO.output(LED_PIN, GPIO.LOW)
        time.sleep(0.5)
except KeyboardInterrupt:
    pass
finally:
    GPIO.cleanup()
```

## 4. Input with Pull-up

```python
import Jetson.GPIO as GPIO

BUTTON_PIN = 11

GPIO.setmode(GPIO.BOARD)
GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

def callback(channel):
    print(f"Button pressed on pin {channel}")

GPIO.add_event_detect(BUTTON_PIN, GPIO.FALLING, callback=callback, bouncetime=200)

try:
    input("Press Enter to exit\n")
finally:
    GPIO.cleanup()
```

## 5. PWM

```python
import Jetson.GPIO as GPIO
import time

PWM_PIN = 32  # BOARD pin 32

GPIO.setmode(GPIO.BOARD)
GPIO.setup(PWM_PIN, GPIO.OUT)
pwm = GPIO.PWM(PWM_PIN, 50)  # 50 Hz
pwm.start(0)

try:
    for dc in range(0, 101, 5):
        pwm.ChangeDutyCycle(dc)
        time.sleep(0.1)
finally:
    pwm.stop()
    GPIO.cleanup()
```

## JetPack 6.2 GPIO Fix

If GPIO pins don't work after updating to JetPack 6.2, NVIDIA changed how GPIOs are initialized. Check:

```bash
sudo cat /boot/extlinux/extlinux.conf
# Ensure no conflicting pinmux settings
```

See: https://my.cytron.io/tutorial/nvidia-ai/orin-nano
