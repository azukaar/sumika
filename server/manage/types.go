package manage

type AccessType int

const (
	ReadOnly  AccessType = 1
	WriteOnly AccessType = 2
	ReadWrite AccessType = 7
)

type Device struct {
	Name        string
	Description string
	Type        string
	Features    []Feature
	Metadata    map[string]interface{}
}

type FeatureValue interface {
	GetValue() interface{}
	SetValue(value interface{})
}

type Feature struct {
	name        string
	state       string
	description string
	featureType string
	access      AccessType

	Unit string
	Min  float64
	Max  float64
	Value float64
}
