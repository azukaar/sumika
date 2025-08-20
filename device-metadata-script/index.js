#!/usr/bin/env node

// Helper function to format expose objects
function formatExpose(expose) {
  if (!expose) return null;
  
  const formatted = {
    type: expose.type,
    name: expose.name,
    property: expose.property,
    description: expose.description,
    label: expose.label,
    access: expose.access,
    unit: expose.unit,
    category: expose.category
  };
  
  // Add type-specific properties
  if (expose.type === 'numeric') {
    formatted.value_min = expose.value_min;
    formatted.value_max = expose.value_max;
    formatted.value_step = expose.value_step;
    formatted.presets = expose.presets;
  } else if (expose.type === 'enum') {
    formatted.values = expose.values;
  } else if (expose.type === 'binary') {
    formatted.value_on = expose.value_on;
    formatted.value_off = expose.value_off;
    formatted.value_toggle = expose.value_toggle;
  } else if (expose.type === 'composite') {
    formatted.features = expose.features ? expose.features.map(formatExpose) : [];
  } else if (expose.type === 'list') {
    formatted.item_type = expose.item_type;
    formatted.length_min = expose.length_min;
    formatted.length_max = expose.length_max;
  }
  
  return formatted;
}

// Helper function to get exposes from definition
function getExposes(definition, device = null) {
  if (!definition.exposes) return [];
  
  if (typeof definition.exposes === 'function') {
    // For function-based exposes, create a mock device if not provided
    const mockDevice = device || {
      manufacturerName: definition.vendor,
      modelID: Array.isArray(definition.model) ? definition.model[0] : definition.model,
      endpoints: []
    };
    
    try {
      const exposes = definition.exposes(mockDevice, {});
      return Array.isArray(exposes) ? exposes.map(formatExpose) : [];
    } catch (e) {
      // If function fails, return error info
      return [{
        type: 'dynamic',
        note: 'Exposes are dynamically generated',
        error: e.message
      }];
    }
  } else {
    return definition.exposes.map(formatExpose);
  }
}

// Output result as JSON to stdout
function output(data) {
  console.log(JSON.stringify(data, null, 2));
  process.exit(0);
}

// Output error as JSON to stdout
function outputError(message) {
  console.log(JSON.stringify({ error: message }, null, 2));
  process.exit(1);
}

// Debug logging function
function debug(message) {
  if (process.argv.includes('--debug')) {
    console.error(`[DEBUG] ${message}`);
  }
}

// Main async function to handle commands
async function main() {
  try {
    debug('Starting device metadata script');
    debug(`Node.js version: ${process.version}`);
    debug(`Arguments: ${JSON.stringify(process.argv)}`);
    
    // Import zigbee-herdsman-converters - use CommonJS require for better compatibility
    debug('Loading zigbee-herdsman-converters...');
    const zhc = require('zigbee-herdsman-converters');
    debug(`Loaded zhc, available properties: ${Object.keys(zhc).join(', ')}`);
    
    // In v25.5.0, the API has changed significantly
    // We need to work with individual functions rather than accessing all definitions at once
    debug('v25.5.0 uses individual lookup functions instead of exposing all definitions');
    debug('Available functions: findByDevice, findDefinition');
    
    // For operations that need all definitions, we'll need to inform the user
    // that this version doesn't support bulk operations
    let allDefinitions = null; // Signal that we don't have bulk access
    
    debug('Individual lookup functions are available for specific device queries');
    
    // Parse command line arguments
    const args = process.argv.slice(2).filter(arg => arg !== '--debug');
    const command = args[0];
    
    switch (command) {
      case '--identify': {
        // Identify device by modelID and manufacturerName
        // Usage: node index.js --identify "modelID" "manufacturerName" ["manufacturerID"] ["type"]
        const modelID = args[1];
        const manufacturerName = args[2];
        const manufacturerID = args[3] || undefined;
        const type = args[4] || undefined;
        
        if (!modelID || !manufacturerName) {
          outputError('Usage: --identify <modelID> <manufacturerName> [manufacturerID] [type]');
        }
        
        const device = {
          modelID: modelID,
          manufacturerName: manufacturerName,
          manufacturerID: manufacturerID,
          type: type
        };
        
        // findByDevice might be async in v25
        let definition;
        if (typeof zhc.findByDevice === 'function') {
          try {
            definition = await zhc.findByDevice(device);
          } catch (e) {
            // If async fails, try sync
            definition = zhc.findByDevice(device);
          }
        }
        
        if (!definition) {
          outputError(`Device not found: ${modelID} by ${manufacturerName}`);
        }
        
        output({
          model: definition.model,
          vendor: definition.vendor,
          description: definition.description,
          supports: definition.supports || null,
          exposes: getExposes(definition, device),
          options: definition.options || [],
          meta: definition.meta || {},
          ota: definition.ota || false,
          whiteLabel: definition.whiteLabel || []
        });
        break;
      }
      
      case '--model': {
        // Get device by exact model
        // Usage: node index.js --model "MODEL_ID"
        const model = args[1];
        
        if (!model) {
          outputError('Usage: --model <model_id>');
        }
        
        debug(`Attempting to find definition for model: ${model}`);
        
        // Try using findDefinition function
        let definition;
        try {
          if (zhc.findDefinition && typeof zhc.findDefinition === 'function') {
            definition = await zhc.findDefinition({ model: model });
            debug(`findDefinition result: ${definition ? 'found' : 'not found'}`);
          }
        } catch (e) {
          debug(`findDefinition failed: ${e.message}`);
        }
        
        if (!definition) {
          outputError(`Model not found: ${model}. Try using --identify with modelID and manufacturerName instead.`);
        }
        
        output({
          model: definition.model,
          vendor: definition.vendor,
          description: definition.description,
          supports: definition.supports || null,
          exposes: getExposes(definition),
          options: definition.options || [],
          meta: definition.meta || {},
          ota: definition.ota || false,
          whiteLabel: definition.whiteLabel || []
        });
        break;
      }
      
      case '--list': {
        // List all devices (simplified)
        // Usage: node index.js --list [vendor]
        outputError('--list command is not supported in zigbee-herdsman-converters v25.5.0. The API no longer exposes all device definitions at once. Use --search instead to find specific devices.');
        break;
      }
      
      case '--search': {
        // Search devices by query
        // Usage: node index.js --search "query"
        outputError('--search command is not supported in zigbee-herdsman-converters v25.5.0. The API no longer exposes all device definitions for searching. Use --identify with specific device details instead.');
        break;
      }
      
      case '--vendors': {
        // List all unique vendors
        // Usage: node index.js --vendors
        outputError('--vendors command is not supported in zigbee-herdsman-converters v25.5.0. The API no longer exposes all device definitions. Use --identify with specific device details instead.');
        break;
      }
      
      case '--version': {
        // Get version info
        // Usage: node index.js --version
        const packageJson = require('./package.json');
        
        let zhcVersion = 'unknown';
        try {
          const zhcPackageJson = require('zigbee-herdsman-converters/package.json');
          zhcVersion = zhcPackageJson.version;
        } catch (e) {
          zhcVersion = 'package.json not found';
        }
        
        output({
          script: packageJson.version,
          'zigbee-herdsman-converters': zhcVersion,
          note: 'v25.5.0+ uses individual lookup functions instead of bulk access',
          available_functions: ['findByDevice', 'findDefinition']
        });
        break;
      }
      
      case '--help':
      default: {
        output({
          usage: 'node index.js <command> [arguments]',
          commands: {
            '--identify': 'Find device by modelID and manufacturerName',
            '--model': 'Get device by exact model ID',
            '--list': 'List all devices (optionally filtered by vendor)',
            '--search': 'Search devices by query',
            '--vendors': 'List all unique vendors',
            '--version': 'Get version information',
            '--help': 'Show this help message'
          },
          examples: [
            'node index.js --identify "TRADFRI bulb E27 WW 806lm" "IKEA"',
            'node index.js --model "LED1924G9"',
            'node index.js --list "Philips"',
            'node index.js --search "motion sensor"',
            'node index.js --vendors'
          ]
        });
        break;
      }
    }
  } catch (error) {
    outputError(`Unexpected error: ${error.message}`);
  }
}

// Run the main function
main();