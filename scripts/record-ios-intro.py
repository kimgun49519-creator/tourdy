"""Bounded simulator recording: never block app validation on recorder shutdown."""
import os
import signal
import subprocess
import sys
import time

device = sys.argv[1]
with open('intro-recording.log', 'w') as log:
    recorder = subprocess.Popen(
        ['xcrun', 'simctl', 'io', device, 'recordVideo', '--codec=h264', 'tourdy-intro.mp4'],
        stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        time.sleep(1)
        subprocess.run(['xcrun', 'simctl', 'launch', device, 'com.example.tourdy'], check=True, timeout=60)
        time.sleep(4)
    finally:
        for sig, limit in [(signal.SIGINT, 10), (signal.SIGTERM, 5), (signal.SIGKILL, 5)]:
            if recorder.poll() is not None:
                break
            try:
                os.killpg(recorder.pid, sig)
                recorder.wait(timeout=limit)
            except ProcessLookupError:
                break
            except subprocess.TimeoutExpired:
                continue
time.sleep(2)
subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', 'capacitor-iphone.png'], check=True, timeout=30)
