"""
IVAC OTP Real-Time Auto-Typer & Clipboard Assistant
-----------------------------------------------------
Connects to the local Node.js WebSocket server, receives real-time SMS/OTP,
copies OTP to system clipboard, and optionally types it directly into
the visa application input box using pyautogui.
"""

import json
import time
import re
import sys
import os
import winsound  # Standard library on Windows for sound alert
import websocket
import pyperclip
import pyautogui

import argparse

# Argument Parser
parser = argparse.ArgumentParser(description="IVAC OTP Real-Time Auto-Typer & Clipboard Assistant")
parser.add_argument("server_url", nargs="?", default=os.environ.get("SERVER_WS_URL") or "wss://microdroidpro.onrender.com",
                    help="WebSocket Server URL (e.g. wss://microdroidpro.onrender.com)")
parser.add_argument("-d", "--device", "--slot", dest="device_id", default=os.environ.get("DEVICE_ID"),
                    help="Target PC/Slot ID (e.g. 1, 2, 3...). Ensures Zero-Collision with other PCs.")
parser.add_argument("--auto-submit", action="store_true", default=True,
                    help="Automatically press Enter after typing the OTP (Default: True)")

args, unknown = parser.parse_known_args()

SERVER_WS_URL = args.server_url

# If Device ID is not passed, prompt interactively or default to 1
if args.device_id:
    TARGET_DEVICE_ID = str(args.device_id).strip()
else:
    try:
        user_input = input("👉 Enter PC / Slot ID (e.g. 1, 2, 3...) [Default: 1]: ").strip()
        TARGET_DEVICE_ID = user_input if user_input else "1"
    except Exception:
        TARGET_DEVICE_ID = "1"

# BEHAVIOR SETTINGS
AUTO_COPY_CLIPBOARD = True  # Automatically copy to clipboard
AUTO_TYPE_OTP = True        # Automatically type into the active input box
AUTO_TYPE_DELAY_SEC = 0.5   # Delay before typing (gives quick responsiveness)
TYPE_INTERVAL = 0.04        # Fast and realistic typing speed
AUTO_PRESS_ENTER = args.auto_submit  # Automatically press 'Enter' to submit the slot

def alert_sound():
    """Play high-pitched audio notification on Windows"""
    try:
        # 1000 Hz for 200 ms, followed by 1500 Hz for 250 ms
        winsound.Beep(1000, 150)
        winsound.Beep(1500, 250)
    except Exception:
        pass

WORD_TO_DIGIT = {
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9'
}

def extract_otp(text):
    """Safely extracts both spelled-out words (Three-Seven-Zero...) and numerical digits"""
    if not text:
        return None

    # 1. Check for IVAC spelled-out words (e.g. Three-Seven-Zero-Five-Six-Four)
    word_tokens = '|'.join(WORD_TO_DIGIT.keys())
    word_pattern = rf'\b(?:{word_tokens})(?:[-–—\s]+(?:{word_tokens})){{3,7}}\b'
    word_match = re.search(word_pattern, text, re.IGNORECASE)
    if word_match:
        words = re.split(r'[-–—\s]+', word_match.group(0).lower())
        converted = ''.join(WORD_TO_DIGIT.get(w, '') for w in words if w in WORD_TO_DIGIT)
        if len(converted) >= 4:
            return converted

    # 2. Check for standard 4 to 8 numerical digits
    digit_match = re.search(r'\b\d{4,8}\b', text)
    return digit_match.group(0) if digit_match else None

def handle_incoming_otp(otp, sender, message, device_id, sim_number=""):
    print("\n" + "=" * 55)
    print(f"🔥 [NEW OTP FOR THIS PC (Slot #{device_id})]: {otp}")
    if sim_number:
        print(f"📱 Target SIM Phone: {sim_number}")
    print(f"📞 Sender: {sender}")
    print(f"💬 Full Message: {message.strip()}")
    print("=" * 55)

    alert_sound()

    # 1. Copy to Clipboard
    if AUTO_COPY_CLIPBOARD:
        pyperclip.copy(otp)
        print(f"📋 [CLIPBOARD]: OTP '{otp}' ক্লিপবোর্ডে কপি করা হয়েছে! (Ctrl + V)")

    # 2. Auto-type into focused browser input field
    if AUTO_TYPE_OTP:
        print(f"⌨️  [AUTO-TYPING]: {AUTO_TYPE_DELAY_SEC} সেকেন্ডের মধ্যে টাইপ হচ্ছে...")
        time.sleep(AUTO_TYPE_DELAY_SEC)
        
        # Write the OTP digits with a fast, reliable interval
        pyautogui.write(str(otp), interval=TYPE_INTERVAL)
        print(f"✅ [SUCCESS]: '{otp}' স্বয়ংক্রিয়ভাবে টাইপ করা সম্পন্ন হয়েছে!")

        if AUTO_PRESS_ENTER:
            pyautogui.press('enter')
            print("🚀 [ENTER]: Enter কী স্বয়ংক্রিয়ভাবে প্রেস করা হয়েছে (Submitted)!")

def on_message(ws, raw_message):
    try:
        data = json.loads(raw_message)
        msg_type = data.get('type')

        if msg_type == 'NEW_SMS':
            payload = data.get('data', {})
            msg_device = str(payload.get('deviceId', '1')).strip()
            sim_number = str(payload.get('simNumber', '')).strip()

            # ZERO-COLLISION FILTER: Discard any SMS meant for other PCs
            if TARGET_DEVICE_ID != 'ALL' and msg_device != str(TARGET_DEVICE_ID).strip():
                return

            otp = payload.get('otp')
            sender = payload.get('sender', 'Unknown')
            msg_text = payload.get('message', '')

            # If server didn't extract OTP, attempt client-side regex
            if not otp:
                otp = extract_otp(msg_text)

            if otp:
                handle_incoming_otp(otp, sender, msg_text, msg_device, sim_number)
            else:
                sim_str = f" (SIM: {sim_number})" if sim_number else ""
                print(f"\nℹ️  [Slot #{msg_device}{sim_str} SMS Received, No OTP]: {sender} -> {msg_text}")

        elif msg_type == 'SUBSCRIBED':
            d_id = data.get('deviceId')
            print(f"🔒 [CHANNEL SECURED]: Successfully locked to Slot/Device #{d_id}")
            latest = data.get('latest')
            if latest and latest.get('otp'):
                print(f"📌 Latest OTP on Slot #{d_id} was: {latest.get('otp')}")

        elif msg_type == 'INIT':
            # Subscription will be sent right after open
            pass

    except Exception as e:
        print(f"❌ Error processing message: {e}")

def on_error(ws, error):
    print(f"⚠️  WebSocket Error: {error}")

def on_close(ws, close_status_code, close_msg):
    print("\n Disconnected from Node.js server. Reconnecting in 3 seconds...")
    time.sleep(3)
    start_client()

def on_open(ws):
    print("======================================================")
    print(f"🚀 IVAC OTP Auto-Typer Active for [PC / Slot #{TARGET_DEVICE_ID}]")
    print(f"📡 Connected to: {SERVER_WS_URL}")
    print(f"🔒 Zero-Collision Filter: ACTIVE (Slot #{TARGET_DEVICE_ID} ONLY)")
    print(f"⚡ Auto-Clipboard: ON | Auto-Type: ON | Auto-Submit: {'ON' if AUTO_PRESS_ENTER else 'OFF'}")
    print("======================================================")
    # Register this PC exclusively to this channel
    try:
        ws.send(json.dumps({
            "type": "SUBSCRIBE",
            "deviceId": str(TARGET_DEVICE_ID)
        }))
    except Exception as e:
        print(f"Subscription send error: {e}")

def start_client():
    while True:
        try:
            ws = websocket.WebSocketApp(
                SERVER_WS_URL,
                on_open=on_open,
                on_message=on_message,
                on_error=on_error,
                on_close=on_close
            )
            ws.run_forever()
        except KeyboardInterrupt:
            print("\n👋 Python Script Stopped by User.")
            sys.exit(0)
        except Exception as e:
            print(f"Connection failed: {e}. Retrying in 3 seconds...")
            time.sleep(3)

if __name__ == '__main__':
    start_client()
