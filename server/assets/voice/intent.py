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
                
                print(f"Loaded {len(self.intent_patterns)} intent patterns")
                print(f"Loaded {len(self.entity_patterns)} entity categories")
                print(f"Loaded {len(self.command_templates)} command templates")
                return
                
            except Exception as e:
                print(f"Warning: Failed to load intents.json: {e}")
                print("Falling back to default patterns")
        
        # Fallback to default hardcoded patterns
        print("Using default hardcoded intent patterns")
        self.intent_patterns = {
            'switch_on': [
                r'switch on|turn on|activate|enable',
                r'light up|illuminate'
            ],
            'switch_off': [
                r'switch off|turn off|deactivate|disable',
                r'shut off'
            ],
            'dim': [
                r'dim|lower|reduce brightness',
                r'make.*darker'
            ],
            'brighten': [
                r'brighten|increase brightness|make.*brighter',
                r'set brightness.*high'
            ]
        }
        
        self.entity_patterns = {
            'device': {
                'light': r'light[s]?',
                'all_lights': r'all\s+light[s]?',
                'lamp': r'lamp[s]?'
            },
            'location': {
                'living_room': r'living\s*room|lounge',
                'bedroom': r'bedroom|bed\s*room',
                'kitchen': r'kitchen',
                'bathroom': r'bathroom|bath\s*room',
                'hallway': r'hallway|hall\s*way|corridor'
            },
            'intensity': {
                'percentage': r'(\d+)\s*%|(\d+)\s*percent',
                'level': r'level\s*(\d+)|brightness\s*(\d+)'
            }
        }
        
        self.command_templates = [
            "switch on light",
            "switch on all lights",
            "switch on light in {location}",
            "switch off light", 
            "switch off all lights",
            "switch off light in {location}",
            "dim lights",
            "dim light in {location}",
            "set brightness to {intensity}"
        ]
    
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
            return Command(
                intent=intent,
                entities=entities,
                original_text=matched_command or f"{intent} (unmatched)"
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
            "input": input_text
        }
    else:
        output = {
            "intent": None,
            "entities": {},
            "command": None,
            "input": input_text
        }
    
    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()