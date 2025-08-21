package types

// Scene configuration structures
type SceneLight struct {
	Hue        float64 `json:"hue"`        // 0-360
	Saturation float64 `json:"saturation"` // 0-1
	Brightness float64 `json:"brightness"` // 0-254
}

type LightingScene struct {
	ID         string       `json:"id"`         // Unique identifier
	Name       string       `json:"name"`
	Lights     []SceneLight `json:"lights"`
	ImagePath  string       `json:"image_path,omitempty"` // Custom uploaded image path
	Order      int          `json:"order"`      // Display order
	IsCustom   bool         `json:"is_custom"`  // True for user-created scenes
	CreatedAt  string       `json:"created_at,omitempty"`
	UpdatedAt  string       `json:"updated_at,omitempty"`
}

// Scene order update structure
type SceneOrder struct {
	ID    string `json:"id"`
	Order int    `json:"order"`
}