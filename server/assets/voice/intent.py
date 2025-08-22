import json
import os
import sys
from typing import List, Dict, Optional, Any

class VoiceCommandProcessor:
    def __init__(self):
        """Initialize the voice command processor with intents data"""
        self.load_intents()
    
    def load_intents(self):
        """Load the generated intents.json file"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        intents_file = os.path.join(script_dir, "intents.json")
        
        if not os.path.exists(intents_file):
            raise RuntimeError(f"intents.json not found at {intents_file}. Please run the server to generate it.")
        
        with open(intents_file, 'r') as f:
            data = json.load(f)
        
        self.devices = data.get('devices', [])
        self.zones = data.get('zones', {})
        
        # Build lookup tables for faster access
        self.devices_by_name = {}
        self.devices_by_category = {}
        self.devices_by_zone = {}
        
        for device in self.devices:
            # Index by custom name and friendly name
            if device.get('custom_name'):
                name_lower = device['custom_name'].lower()
                self.devices_by_name[name_lower] = device
            
            # Also index by friendly name if it's not an IEEE address
            if device.get('friendly_name') and not device['friendly_name'].startswith('0x'):
                name_lower = device['friendly_name'].lower()
                self.devices_by_name[name_lower] = device
            
            # Index by categories
            for category in device.get('categories', []):
                category_lower = category.lower()
                if category_lower not in self.devices_by_category:
                    self.devices_by_category[category_lower] = []
                self.devices_by_category[category_lower].append(device)
            
            # Index by zones
            for zone in device.get('zones', []):
                if zone:  # Skip empty zones
                    zone_lower = zone.lower()
                    if zone_lower not in self.devices_by_zone:
                        self.devices_by_zone[zone_lower] = []
                    self.devices_by_zone[zone_lower].append(device)
    
    def normalize_text(self, text: str) -> str:
        """Normalize input text for matching"""
        # Convert to lowercase and strip extra spaces
        text = ' '.join(text.lower().split())
        
        # Remove common filler words that don't affect meaning
        filler_words = ['the', 'please', 'can', 'you', 'could', 'would']
        words = text.split()
        words = [w for w in words if w not in filler_words]
        
        return ' '.join(words)
    
    def find_devices(self, text: str) -> List[Dict]:
        """
        Find devices mentioned in the text.
        Priority: device name > category > zone
        """
        text_lower = text.lower()
        found_devices = []
        
        # 1. Try to match specific device names
        for name, device in self.devices_by_name.items():
            if name in text_lower:
                found_devices.append(device)
                # Remove matched device name from text to avoid double matching
                text_lower = text_lower.replace(name, '')
        
        if found_devices:
            return found_devices
        
        # 2. Try to match device categories
        for category, devices in self.devices_by_category.items():
            if category in text_lower:
                found_devices.extend(devices)
        
        if found_devices:
            return found_devices
        
        # 3. Try to match zones
        for zone, devices in self.devices_by_zone.items():
            if zone in text_lower:
                found_devices.extend(devices)
        
        if found_devices:
            return found_devices
        
        # 4. If still no devices found, check if it's a general command
        # (e.g., "turn off" without specifying what)
        # In this case, return all controllable devices of common types
        general_commands = ['turn on', 'turn off', 'switch on', 'switch off', 'toggle']
        for cmd in general_commands:
            if cmd in text_lower:
                # Return all lights and switches
                for category in ['light', 'switch', 'lamp', 'bulb', 'plug', 'outlet']:
                    if category in self.devices_by_category:
                        found_devices.extend(self.devices_by_category[category])
                break
        
        # Remove duplicates while preserving order
        seen = set()
        unique_devices = []
        for device in found_devices:
            if device['ieee_address'] not in seen:
                seen.add(device['ieee_address'])
                unique_devices.append(device)
        
        return unique_devices
    
    def find_command_and_value(self, text: str, device: Dict) -> Optional[Dict]:
        """
        Find matching command and its target value for a device.
        Returns: {property: str, value: Any} or None
        """
        text_lower = text.lower()
        
        # Check each property's commands
        for prop in device.get('properties', []):
            if not prop.get('is_writable', False):
                continue
            
            commands = prop.get('commands', {})
            if not commands:
                continue
            
            # Check if any command matches the text
            for command_phrase, target_value in commands.items():
                # Simple substring matching
                if command_phrase in text_lower:
                    return {
                        'property': prop['name'],
                        'value': target_value,
                        'command': command_phrase
                    }
        
        # Try to match property names directly (e.g., "brightness to 50")
        for prop in device.get('properties', []):
            if not prop.get('is_writable', False):
                continue
            
            prop_name = prop['name'].lower()
            if prop_name in text_lower:
                # Try to extract value if it's a set command
                if 'to' in text_lower:
                    # Extract number after "to"
                    parts = text_lower.split('to')
                    if len(parts) > 1:
                        value_part = parts[-1].strip()
                        # Try to parse as number
                        try:
                            if prop['type'] == 'numeric':
                                value = float(value_part.replace('%', ''))
                                # Handle percentage for properties with min/max
                                if '%' in value_part and 'min_value' in prop and 'max_value' in prop:
                                    min_val = prop['min_value']
                                    max_val = prop['max_value']
                                    value = min_val + (max_val - min_val) * (value / 100)
                                return {
                                    'property': prop_name,
                                    'value': value,
                                    'command': f"set {prop_name} to {value}"
                                }
                        except ValueError:
                            pass
        
        return None
    
    def process_command(self, text: str) -> Dict:
        """
        Main processing function.
        Returns the structured command data.
        """
        normalized_text = self.normalize_text(text)
        
        # Find target devices
        devices = self.find_devices(normalized_text)
        
        if not devices:
            return {
                'success': False,
                'error': 'No devices found',
                'input': text,
                'devices': []
            }
        
        # For each device, find the command and value
        device_commands = []
        
        for device in devices:
            command_data = self.find_command_and_value(normalized_text, device)
            
            if command_data:
                device_commands.append({
                    'ieee_address': device['ieee_address'],
                    'friendly_name': device.get('friendly_name', ''),
                    'custom_name': device.get('custom_name', ''),
                    'property': command_data['property'],
                    'value': command_data['value'],
                    'command': command_data.get('command', '')
                })
        
        if not device_commands:
            return {
                'success': False,
                'error': 'No valid commands found for devices',
                'input': text,
                'devices': [d['ieee_address'] for d in devices]
            }
        
        return {
            'success': True,
            'input': text,
            'normalized': normalized_text,
            'commands': device_commands
        }

def main():
    """Main entry point for command line usage"""
    if len(sys.argv) != 2:
        print("Usage: python intent.py \"<voice command>\"", file=sys.stderr)
        sys.exit(1)
    
    input_text = sys.argv[1]
    
    try:
        processor = VoiceCommandProcessor()
        result = processor.process_command(input_text)
        print(json.dumps(result, indent=2))
    except Exception as e:
        error_result = {
            'success': False,
            'error': str(e),
            'input': input_text
        }
        print(json.dumps(error_result, indent=2))
        sys.exit(1)

if __name__ == "__main__":
    main()