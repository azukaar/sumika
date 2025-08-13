package zigbee2mqtt

type Device struct {
	DateCode string `json:"date_code"`
	State map[string]interface{} `json:"state"`
	Zones []string `json:"zones"`
	LastSeen string `json:"last_seen,omitempty"`
	CustomName string `json:"custom_name,omitempty"`     // User-customizable display name
	CustomCategory string `json:"custom_category,omitempty"` // User-customizable device category
	Definition struct {
		Description string `json:"description"`
		Exposes     []interface{} `json:"exposes"`
		Model 		  string `json:"model"`
		Vendor 		  string `json:"vendor"`
		SupportsOTA bool `json:"supports_ota"`
		Options 	  []struct {
			Access int `json:"access"`
			Description string `json:"description"`
			Label string `json:"label"`
			Name string `json:"name"`
			Type string `json:"type"`
			ValueMin int `json:"value_min"`
			ValueMax int `json:"value_max"`
			ValueOn string `json:"value_on"`
			ValueOff string `json:"value_off"`
		} `json:"options"`
	} `json:"definition"`
	Endpoint interface{} `json:"endpoint"`
	FriendlyName string `json:"friendly_name"`
	Disabled bool `json:"disabled"`
	IEEEAddr string `json:"ieee_address"`
	InterviewCompleted bool `json:"interview_completed"`
	Interviewing bool `json:"interviewing"`
	Manufacturer string `json:"manufacturer"`
	ModelID string `json:"model_id"`
	NetworkAddress int `json:"network_address"`
	PowerSource string `json:"power_source"`
	Supported bool `json:"supported"`
	Type string `json:"type"`
}

