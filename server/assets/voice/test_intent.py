#!/usr/bin/env python3
"""
Test suite for the voice intent processor.
Tests various voice commands against expected outcomes.
"""

import json
import sys
import os

# Add the voice directory to path so we can import intent
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from intent import VoiceCommandProcessor

class TestIntentProcessor:
    def __init__(self):
        self.processor = VoiceCommandProcessor()
        self.passed = 0
        self.failed = 0
        self.test_cases = []
        
    def test(self, command, expected_device=None, expected_property=None, expected_value=None, expected_count=None, should_fail=False):
        """Run a single test case"""
        print(f"\nTesting: '{command}'")
        result = self.processor.process_command(command)
        
        if should_fail:
            if not result['success']:
                print(f"  ✓ Correctly failed")
                self.passed += 1
                return True
            else:
                print(f"  ✗ Should have failed but succeeded")
                print(f"    Result: {json.dumps(result, indent=2)}")
                self.failed += 1
                return False
        
        if not result['success']:
            print(f"  ✗ Failed: {result.get('error', 'Unknown error')}")
            self.failed += 1
            return False
        
        # Check if we got commands
        if not result.get('commands'):
            print(f"  ✗ No commands generated")
            self.failed += 1
            return False
        
        # Check command count if specified
        if expected_count is not None and len(result['commands']) != expected_count:
            print(f"  ✗ Wrong command count: expected {expected_count}, got {len(result['commands'])}")
            self.failed += 1
            return False
        
        # Check expectations if provided
        passed = True
        for cmd in result['commands']:
            if expected_device and expected_device not in [cmd['custom_name'], cmd['friendly_name'], cmd['ieee_address']]:
                print(f"  ✗ Wrong device: expected '{expected_device}', got '{cmd.get('custom_name') or cmd.get('friendly_name')}'")
                passed = False
                
            if expected_property and cmd['property'] != expected_property:
                print(f"  ✗ Wrong property: expected '{expected_property}', got '{cmd['property']}'")
                passed = False
                
            if expected_value is not None:
                if isinstance(expected_value, str) and cmd['value'] != expected_value:
                    print(f"  ✗ Wrong value: expected '{expected_value}', got '{cmd['value']}'")
                    passed = False
                elif isinstance(expected_value, (int, float)) and abs(cmd['value'] - expected_value) > 0.1:
                    print(f"  ✗ Wrong value: expected {expected_value}, got {cmd['value']}")
                    passed = False
        
        if passed:
            print(f"  ✓ Passed ({len(result['commands'])} command(s))")
            if result.get('commands'):
                for cmd in result['commands']:
                    print(f"    → {cmd['custom_name'] or cmd['friendly_name']}: {cmd['property']} = {cmd['value']}")
            self.passed += 1
        else:
            self.failed += 1
            print(f"    Full result: {json.dumps(result, indent=2)}")
        
        return passed
    
    def run_all_tests(self):
        """Run all test cases"""
        print("=" * 60)
        print("VOICE INTENT PROCESSOR TEST SUITE")
        print("=" * 60)
        
        # Test device name matching with actual device names
        print("\n### DEVICE NAME MATCHING ###")
        self.test("turn on right lamp", expected_device="Right Lamp", expected_property="state", expected_value="ON")
        self.test("turn off the right lamp", expected_device="Right Lamp", expected_property="state", expected_value="OFF")
        self.test("make right lamp brighter", expected_device="Right Lamp", expected_property="brightness")
        self.test("dim the right lamp", expected_device="Right Lamp", expected_property="brightness")
        
        # Test other specific devices
        self.test("turn on left lamp 1", expected_device="Left Lamp 1", expected_property="state", expected_value="ON")
        self.test("turn off left lamp 2", expected_device="Left Lamp 2", expected_property="state", expected_value="OFF")
        self.test("dim left lamp 3", expected_device="Left Lamp 3", expected_property="brightness")
        self.test("turn on tv lamp", expected_device="TV Lamp", expected_property="state", expected_value="ON")
        self.test("turn off left plug", expected_device="Left plug", expected_property="state", expected_value="OFF")
        self.test("turn on lamp", expected_device="Lamp", expected_property="state", expected_value="ON")  # Bedroom lamp
        
        # Test category matching (should match multiple devices)
        print("\n### CATEGORY MATCHING ###")
        self.test("turn on all lights", expected_property="state", expected_value="ON")
        self.test("turn off the lamps", expected_property="state", expected_value="OFF") 
        self.test("dim all bulbs", expected_property="brightness")
        self.test("make the lights brighter", expected_property="brightness")
        self.test("turn on all switches", expected_property="state", expected_value="ON")  # Should match Left plug
        self.test("turn off plugs", expected_property="state", expected_value="OFF")  # Should match Left plug
        self.test("turn on outlets", expected_property="state", expected_value="ON")  # Should match Left plug
        
        # Test zone matching (should match devices in specific zones)
        print("\n### ZONE MATCHING ###")
        self.test("turn on living room", expected_property="state", expected_value="ON")  # Should match 7 devices
        self.test("turn off living room lights", expected_property="state", expected_value="OFF")  # Should match 5 lamps
        self.test("make living room brighter", expected_property="brightness")  # Should match dimmable devices
        self.test("dim the living room", expected_property="brightness")  # Should match dimmable devices
        self.test("turn on bedroom", expected_property="state", expected_value="ON")  # Should match bedroom lamp
        self.test("turn off bedroom lights", expected_property="state", expected_value="OFF")  # Should match bedroom lamp
        self.test("make bedroom brighter", expected_property="brightness")  # Should match bedroom lamp
        
        # Test specific commands
        print("\n### SPECIFIC COMMANDS ###")
        self.test("toggle right lamp", expected_device="Right Lamp", expected_property="state", expected_value="TOGGLE")
        self.test("switch on right lamp", expected_device="Right Lamp", expected_property="state", expected_value="ON")
        self.test("switch off the lights", expected_property="state", expected_value="OFF")
        
        # Test brightness commands
        print("\n### BRIGHTNESS COMMANDS ###")
        self.test("set brightness to maximum", expected_property="brightness", expected_value=254)
        self.test("set brightness to minimum", expected_property="brightness", expected_value=0)
        self.test("brightness to full", expected_property="brightness", expected_value=254)
        self.test("set to lowest", expected_property="brightness", expected_value=0)
        self.test("increase brightness", expected_property="brightness")
        self.test("decrease brightness", expected_property="brightness")
        
        # Test color temperature commands
        print("\n### COLOR TEMPERATURE COMMANDS ###")
        self.test("make it warmer", expected_property="color_temp")
        self.test("make it cooler", expected_property="color_temp")
        self.test("set color temperature to maximum", expected_property="color_temp", expected_value=500)
        
        # Test general commands (no specific target)
        print("\n### GENERAL COMMANDS ###")
        self.test("turn off", expected_property="state", expected_value="OFF")
        self.test("turn on", expected_property="state", expected_value="ON")
        self.test("toggle", expected_property="state", expected_value="TOGGLE")
        
        # Test compound/complex commands
        print("\n### COMPLEX COMMANDS ###")
        self.test("please turn on the right lamp", expected_device="Right Lamp", expected_property="state", expected_value="ON")
        self.test("can you make the living room lights brighter", expected_property="brightness")
        self.test("would you turn off all the lights please", expected_property="state", expected_value="OFF")
        
        # Test failure cases
        print("\n### EXPECTED FAILURES ###")
        self.test("play some music", should_fail=True)
        self.test("what's the weather", should_fail=True)
        self.test("hello there", should_fail=True)
        self.test("", should_fail=True)
        
        # Test advanced category/zone combinations
        print("\n### ADVANCED MATCHING ###")
        self.test("turn off all living room lights", expected_property="state", expected_value="OFF")  # Zone + Category
        self.test("make all bedroom lamps brighter", expected_property="brightness")  # Zone + Category
        self.test("dim living room bulbs", expected_property="brightness")  # Zone + Category synonym
        self.test("turn on all living room switches", expected_property="state", expected_value="ON")  # Zone + Category
        
        # Test property-specific commands
        print("\n### PROPERTY-SPECIFIC TESTS ###")
        self.test("set right lamp to warmest", expected_device="Right Lamp", expected_property="color_temp")
        self.test("make tv lamp cooler", expected_device="TV Lamp", expected_property="color_temp")  
        self.test("set left lamp 1 to neutral", expected_device="Left Lamp 1", expected_property="color_temp")
        self.test("blink right lamp", expected_device="Right Lamp", expected_property="effect", expected_value="blink")
        self.test("breathe left lamp 2", expected_device="Left Lamp 2", expected_property="effect", expected_value="breathe")
        
        # Test multi-device commands with counts
        print("\n### MULTI-DEVICE VALIDATION ###")
        # Validate correct device counts for category/zone combinations
        self.test("turn on all lights", expected_property="state", expected_value="ON", expected_count=6)  # All 6 lamps
        self.test("turn off all lamps", expected_property="state", expected_value="OFF", expected_count=6)  # All 6 lamps  
        self.test("turn on living room lights", expected_property="state", expected_value="ON", expected_count=5)  # 5 living room lamps
        self.test("Switch on the light in the bedroom.", expected_property="state", expected_value="ON", expected_count=1)  # 1 bedroom lamp
        self.test("turn off bedroom lights", expected_property="state", expected_value="OFF", expected_count=1)  # 1 bedroom lamp
        self.test("turn on all living room switches", expected_property="state", expected_value="ON", expected_count=1)  # 1 plug
        self.test("turn on living room", expected_property="state", expected_value="ON", expected_count=6)  # 5 lamps + 1 plug (6 switchable devices in living room)
        
        # Test edge cases
        print("\n### EDGE CASES ###")
        self.test("TURN ON RIGHT LAMP", expected_device="Right Lamp", expected_property="state", expected_value="ON")
        self.test("   turn   on   right   lamp   ", expected_device="Right Lamp", expected_property="state", expected_value="ON")
        self.test("rightlamp on", should_fail=True)  # Should fail - no space
        self.test("turn on nonexistent device", should_fail=True)  # Should fail - device doesn't exist
        self.test("turn on kitchen lights", should_fail=True)  # Should fail - zone doesn't exist
        
        # Print summary
        print("\n" + "=" * 60)
        print("TEST SUMMARY")
        print("=" * 60)
        print(f"Passed: {self.passed}")
        print(f"Failed: {self.failed}")
        print(f"Total:  {self.passed + self.failed}")
        print(f"Success Rate: {(self.passed / (self.passed + self.failed) * 100):.1f}%")
        
        return self.failed == 0

def main():
    """Main test runner"""
    # Check if intents.json exists
    script_dir = os.path.dirname(os.path.abspath(__file__))
    intents_file = os.path.join(script_dir, "intents.json")
    
    if not os.path.exists(intents_file):
        print(f"Error: intents.json not found at {intents_file}")
        print("Please ensure intents.json is generated first")
        sys.exit(1)
    
    # Run tests
    tester = TestIntentProcessor()
    success = tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()