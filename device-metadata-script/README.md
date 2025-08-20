# Device Metadata Script

This Node.js script provides access to device metadata from the `zigbee-herdsman-converters` library, which is the same source that Zigbee2MQTT uses for device definitions.

## Requirements

- Node.js 18+
- zigbee-herdsman-converters v25.5.0

## Installation

```bash
npm install
```

## Usage

The script is designed to be called from the Go backend with command-line arguments:

### Commands

- **`--identify`** - Find device by modelID and manufacturerName
  ```bash
  node index.js --identify "TRADFRI bulb E27 WW 806lm" "IKEA"
  ```

- **`--model`** - Get device by exact model ID
  ```bash
  node index.js --model "LED1924G9"
  ```

- **`--list`** - List all devices (optionally filtered by vendor)
  ```bash
  node index.js --list
  node index.js --list "Philips"
  ```

- **`--search`** - Search devices by query
  ```bash
  node index.js --search "motion sensor"
  ```

- **`--vendors`** - List all unique vendors
  ```bash
  node index.js --vendors
  ```

- **`--version`** - Get version information
  ```bash
  node index.js --version
  ```

## Output

All commands return JSON to stdout:

```json
{
  "model": "LED1924G9",
  "vendor": "IKEA",
  "description": "TRADFRI bulb E27 WW 806lm",
  "exposes": [
    {
      "type": "binary",
      "name": "state",
      "property": "state",
      "description": "On/off state of this light",
      "access": 7,
      "value_on": "ON",
      "value_off": "OFF",
      "value_toggle": "TOGGLE"
    }
  ],
  "options": [],
  "meta": {},
  "ota": false
}
```

## Error Handling

Errors are returned as JSON to stdout with an `error` field:

```json
{
  "error": "Device not found: INVALID_MODEL by INVALID_MANUFACTURER"
}
```

## Integration

This script is automatically called by the Go backend's `DeviceMetadataService` to provide enhanced device metadata to the frontend.