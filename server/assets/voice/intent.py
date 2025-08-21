import re
import os
import json
from dataclasses import dataclass
from typing import List, Optional, Dict

@dataclass
class Command:
    intent: str
    entities: Dict[str, str]
    original_text: str
    real_device_names: List[str] = None  # Real device names (IEEE addresses)
    device_properties: Dict[str, List[str]] = None  # Properties for each device
    valid_command: bool = True  # Whether command is valid for target devices

# TEMPORARY DUMMY DATA FOR TESTING 

class IntentEntityMatcher:
    def __init__(self):
        # Try to load from generated intents.json, fall back to defaults
        self.load_intents()

    def load_intents(self):
        """Load intents from JSON file or use defaults"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        intents_file = os.path.join(script_dir, "intents.json")
        
        if os.path.exists(intents_file):
            try:
                print(f"Loading dynamic intents from: {intents_file}")
                with open(intents_file, 'r') as f:
                    data = json.load(f)
                
                self.intent_patterns = data.get('intent_patterns', {})
                self.entity_patterns = data.get('entity_patterns', {})
                self.command_templates = data.get('command_templates', [])
                
                # Load new format fields
                self.device_mappings = data.get('device_mappings', {})
                self.zone_mappings = data.get('zone_mappings', {})
                self.device_properties = data.get('device_properties', {})
                
                print(f"Loaded {len(self.intent_patterns)} intent patterns")
                print(f"Loaded {len(self.entity_patterns)} entity categories")
                print(f"Loaded {len(self.command_templates)} command templates")
                print(f"Loaded {len(self.device_mappings)} device mappings")
                print(f"Loaded {len(self.zone_mappings)} zone mappings")
                print(f"Loaded {len(self.device_properties)} device properties")
                return
                
            except Exception as e:
                print(f"Error: Failed to load intents.json: {e}")
                raise RuntimeError(f"Cannot load voice intents: {e}")
        else:
            print(f"Error: intents.json not found at {intents_file}")
            raise RuntimeError("Voice intents file not found. Please run the server to generate intents.json")
        
        # No fallback - intents.json must be available
    
    def preprocess_text(self, text):
        """Clean the input text"""
        # Remove filler words
        filler_words = ['hey', 'so', 'can', 'you', 'may', 'be', 'uhhh', 'umm', 'uh', 'please']
        for word in filler_words:
            text = re.sub(rf'\b{word}\b', '', text, flags=re.IGNORECASE)
        
        # Fix common transcription errors
        text = re.sub(r'rooom+', 'room', text, flags=re.IGNORECASE)
        text = re.sub(r'liiight+', 'light', text, flags=re.IGNORECASE)
        
        # Clean spacing
        text = re.sub(r'\s+', ' ', text).strip().lower()
        return text
    
    def extract_intent(self, text):
        """Extract the intent from the text"""
        for intent, patterns in self.intent_patterns.items():
            for pattern in patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    return intent
        return None
    
    def extract_entities(self, text):
        """Extract entities from the text"""
        entities = {}
        
        for entity_type, entity_values in self.entity_patterns.items():
            for entity_value, pattern in entity_values.items():
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    if entity_type == 'intensity' and match.groups():
                        # Extract the numeric value for intensity
                        for group in match.groups():
                            if group:
                                entities[entity_type] = f"{group}%"
                                break
                    else:
                        entities[entity_type] = entity_value
                    break
        
        return entities
    
    def get_real_device_name(self, friendly_name):
        """Get the real device name (IEEE address) from friendly name"""
        return self.device_mappings.get(friendly_name, friendly_name)
    
    def get_device_properties(self, device_name):
        """Get the properties available for a device"""
        return self.device_properties.get(device_name, [])
    
    def get_devices_in_zone(self, zone_name):
        """Get all devices in a specific zone"""
        return self.zone_mappings.get(zone_name, [])
    
    def validate_command_for_device(self, intent, device_name):
        """Check if a command is valid for a device based on its properties"""
        properties = self.get_device_properties(device_name)
        
        # Map intents to required properties
        property_requirements = {
            'switch_on': ['state'],
            'switch_off': ['state'], 
            'dim': ['brightness'],
            'brighten': ['brightness'],
            'set_brightness': ['brightness'],
            'set_color': ['color', 'color_temp']
        }
        
        required_props = property_requirements.get(intent, [])
        if not required_props:
            return True  # No specific requirements
            
        # Check if device has any of the required properties
        return any(prop in properties for prop in required_props)
    
    def match_to_template(self, intent, entities):
        """Match the intent and entities to a command template"""
        if not intent:
            return None
            
        # Find the best matching template
        for template in self.command_templates:
            if intent.replace('_', ' ') in template:
                # Check if template requires entities that we have
                if '{location}' in template and 'location' in entities:
                    location = entities['location'].replace('_', ' ')
                    return template.replace('{location}', location)
                elif '{intensity}' in template and 'intensity' in entities:
                    return template.replace('{intensity}', entities['intensity'])
                elif '{' not in template:
                    # Simple template without placeholders
                    return template
        
        # Fallback: construct basic command
        base_command = intent.replace('_', ' ')
        if 'device' in entities:
            device = entities['device'].replace('_', ' ')
            base_command += f" {device}"
        if 'location' in entities:
            location = entities['location'].replace('_', ' ')
            base_command += f" in {location}"
            
        return base_command
    
    def find_best_match(self, input_text):
        """Find the best matching command"""
        processed_text = self.preprocess_text(input_text)
        
        intent = self.extract_intent(processed_text)
        entities = self.extract_entities(processed_text)
        
        if intent:
            matched_command = self.match_to_template(intent, entities)
            
            # Resolve device names and validate command
            real_device_names = []
            device_properties = {}
            valid_command = True
            
            # Handle device entities
            if 'device' in entities:
                device_name = entities['device']
                real_name = self.get_real_device_name(device_name)
                real_device_names.append(real_name)
                device_properties[real_name] = self.get_device_properties(device_name)
                valid_command = self.validate_command_for_device(intent, device_name)
            
            # Handle location entities (get all devices in zone)
            if 'location' in entities:
                zone_name = entities['location']
                zone_devices = self.get_devices_in_zone(zone_name)
                for device in zone_devices:
                    real_name = self.get_real_device_name(device)
                    real_device_names.append(real_name)
                    device_properties[real_name] = self.get_device_properties(device)
                    if not self.validate_command_for_device(intent, device):
                        valid_command = False
            
            return Command(
                intent=intent,
                entities=entities,
                original_text=matched_command or f"{intent} (unmatched)",
                real_device_names=real_device_names,
                device_properties=device_properties,
                valid_command=valid_command
            )
        
        return None

def main():
    import sys
    import json
    
    if len(sys.argv) != 2:
        print("Usage: python intent.py <text>", file=sys.stderr)
        sys.exit(1)
    
    input_text = sys.argv[1]
    matcher = IntentEntityMatcher()
    result = matcher.find_best_match(input_text)
    
    if result:
        output = {
            "intent": result.intent,
            "entities": result.entities,
            "command": result.original_text,
            "input": input_text,
            "real_device_names": result.real_device_names,
            "device_properties": result.device_properties,
            "valid_command": result.valid_command
        }
    else:
        output = {
            "intent": None,
            "entities": {},
            "command": None,
            "input": input_text,
            "real_device_names": [],
            "device_properties": {},
            "valid_command": False
        }
    
    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()