"""
Test Script: Send simulated IVAC OTP SMS to your local Node.js Server
----------------------------------------------------------------------
Run this to test the Dashboard and Python Auto-typer without needing a real phone.
"""

import requests
import random
import time

import os
import sys

SERVER_URL = os.environ.get("SERVER_URL") or (sys.argv[1] if len(sys.argv) > 1 else "https://microdroidpro.onrender.com/ivac-sms")
DEVICE_ID = sys.argv[2] if len(sys.argv) > 2 else "1"

def send_mock_sms(device_id=DEVICE_ID):
    random_otp = str(random.randint(100000, 999999))
    digit_words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
    # Example: Three-Seven-Zero-Five-Six-Four
    sample_words = [random.choice(digit_words) for _ in range(6)]
    word_sequence = "-".join(sample_words)

    sample_messages = [
        f"(IVACBD) For security, type the following sequence when prompted {word_sequence} .",
        f"Your IVAC BD appointment OTP is {random_otp}. Valid for 10 minutes. Do not share this OTP with anyone.",
        f"IVAC Visa Application verification code is {random_otp}. Please enter this to proceed.",
    ]
    
    selected_message = random.choice(sample_messages)
    payload = {
        "deviceId": str(device_id),
        "sender": "IVACBD",
        "message": selected_message,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    }

    print(f"📤 Sending mock SMS for Slot #{device_id} to {SERVER_URL}...")
    try:
        response = requests.post(SERVER_URL, json=payload, timeout=10)
        if response.status_code == 200:
            print("✅ Successfully sent! Response:", response.json())
        else:
            print(f"❌ Server returned code {response.status_code}:", response.text)
    except Exception as e:
        print("❌ Failed to connect to server:", e)

if __name__ == '__main__':
    send_mock_sms()
