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

SERVER_URL = os.environ.get("SERVER_URL") or (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:3000/ivac-sms")

def send_mock_sms():
    random_otp = random.randint(100000, 999999)
    sample_messages = [
        f"Your IVAC BD appointment OTP is {random_otp}. Valid for 10 minutes. Do not share this OTP with anyone.",
        f"IVAC Visa Application verification code is {random_otp}. Please enter this to proceed.",
        f"OTP: {random_otp} for IVAC online portal login. High Commission of India.",
    ]
    
    selected_message = random.choice(sample_messages)
    payload = {
        "sender": "IVAC-BD",
        "message": selected_message,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    }

    print(f"📤 Sending mock SMS to {SERVER_URL}...")
    try:
        response = requests.post(SERVER_URL, json=payload, timeout=5)
        if response.status_code == 200:
            print("✅ Successfully sent! Response:", response.json())
        else:
            print(f"❌ Server returned code {response.status_code}:", response.text)
    except Exception as e:
        print("❌ Failed to connect to server:", e)
        print("💡 Make sure your Node.js server is running (`npm start` inside /server directory).")

if __name__ == '__main__':
    send_mock_sms()
