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

# SERVER CONFIGURATION (Local: ws://localhost:3000 | Remote: wss://your-domain.com)
SERVER_WS_URL = os.environ.get("SERVER_WS_URL") or (sys.argv[1] if len(sys.argv) > 1 else "ws://localhost:3000")

# BEHAVIOR SETTINGS
AUTO_COPY_CLIPBOARD = True  # Automatically copy to clipboard
AUTO_TYPE_OTP = True        # Automatically type into the active input box
AUTO_TYPE_DELAY_SEC = 1.0   # Delay before typing (gives you time to click the input field)
TYPE_INTERVAL = 0.05        # Typing speed per character (simulates realistic key strokes)
AUTO_PRESS_ENTER = False    # Set True if you want it to press 'Enter' after typing OTP

def alert_sound():
    """Play high-pitched audio notification on Windows"""
    try:
        # 1000 Hz for 200 ms, followed by 1500 Hz for 250 ms
        winsound.Beep(1000, 150)
        winsound.Beep(1500, 250)
    except Exception:
        pass

def extract_otp(text):
    """Regex to safely extract 4 to 8 digit OTP codes"""
    if not text:
        return None
    match = re.search(r'\b\d{4,8}\b', text)
    return match.group(0) if match else None

def handle_incoming_otp(otp, sender, message):
    print("\n" + "=" * 55)
    print(f"🔥 [NEW OTP DETECTED]: {otp}")
    print(f"📞 Sender: {sender}")
    print(f"💬 Full Message: {message.strip()}")
    print("=" * 55)

    alert_sound()

    # 1. Copy to Clipboard
    if AUTO_COPY_CLIPBOARD:
        pyperclip.copy(otp)
        print("📋 [CLIPBOARD]: OTP কোড ক্লিপবোর্ডে কপি করা হয়েছে! (Ctrl + V চাপুন)")

    # 2. Auto-type into focused browser input field
    if AUTO_TYPE_OTP:
        print(f"⌨️  [AUTO-TYPING]: {AUTO_TYPE_DELAY_SEC} সেকেন্ডের মধ্যে কার্সরটি ইনপুট বক্সে রাখুন...")
        time.sleep(AUTO_TYPE_DELAY_SEC)
        
        # Write the OTP digits with a gentle interval
        pyautogui.write(str(otp), interval=TYPE_INTERVAL)
        print(f"✅ [SUCCESS]: '{otp}' স্বয়ংক্রিয়ভাবে টাইপ করা সম্পন্ন হয়েছে!")

        if AUTO_PRESS_ENTER:
            pyautogui.press('enter')
            print("🚀 [ENTER]: Enter কী চাপ দেওয়া হয়েছে!")

def on_message(ws, raw_message):
    try:
        data = json.loads(raw_message)
        msg_type = data.get('type')

        if msg_type == 'NEW_SMS':
            payload = data.get('data', {})
            otp = payload.get('otp')
            sender = payload.get('sender', 'Unknown')
            msg_text = payload.get('message', '')

            # If server didn't extract OTP, attempt client-side regex
            if not otp:
                otp = extract_otp(msg_text)

            if otp:
                handle_incoming_otp(otp, sender, msg_text)
            else:
                print(f"\nℹ️  [SMS Received, No OTP]: {sender} -> {msg_text}")

        elif msg_type == 'INIT':
            print(" Connected to Server. Listening for incoming IVAC SMS...")
            latest = data.get('latest')
            if latest and latest.get('otp'):
                print(f"📌 Latest server OTP was: {latest.get('otp')}")

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
    print("🚀 IVAC OTP Python Listener Started Successfully!")
    print(f"📡 Connected to: {SERVER_WS_URL}")
    print("⚡ Auto-Clipboard: ON | Auto-Type: ON")
    print("======================================================")

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
