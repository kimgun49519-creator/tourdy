"""Capture bounded screen frames without simctl's streaming recorder shutdown."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import time

device = sys.argv[1]
Path('intro-frames').mkdir(exist_ok=True)
subprocess.run(['xcrun', 'simctl', 'launch', device, 'com.example.tourdy'], check=True, timeout=60)
started = time.monotonic()
def capture(index):
    return subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', f'intro-frames/{index:03d}.png'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=25).returncode
with ThreadPoolExecutor(max_workers=3) as pool:
    pending = []
    for index in range(20):
        time.sleep(max(0, started + index * 0.35 - time.monotonic()))
        pending.append(pool.submit(capture, index))
    for result in pending:
        result.result()
subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', 'capacitor-iphone.png'], check=True, timeout=30)
with open('native-runtime.log', 'w') as log:
    subprocess.run(['xcrun', 'simctl', 'spawn', device, 'log', 'show', '--last', '2m', '--style', 'compact',
                    '--predicate', 'subsystem == "app.tourdy.navigation"'], stdout=log, stderr=subprocess.STDOUT, timeout=30)
