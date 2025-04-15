# Raspberry PI Pico W Doorbell

This is a simple doorbell built on the Raspberry Pi Pico W with Zig and the Pico C SDK.

# Usage

Create a setting.json in the src folder similar to this one:
```json
{
    "ssid": "YOUR_WIFI_NAME",
    "password": "WIFI_PASSWORD",
    "ntfy_url":"http://ntfy.sh/YOUR_CHANNEL_NAME"
}
```

***Note: Without this file, the project will not compile!***

The content of the settings.json is processed comptime so the file will not be placed on the pico.
