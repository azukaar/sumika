package storage

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"

	"github.com/azukaar/sumika/server/types"
)

type AutomationRepository interface {
	GetAll() ([]types.Automation, error)
	GetByID(id string) (*types.Automation, error)
	Create(automation types.Automation) (*types.Automation, error)
	Update(id string, automation types.Automation) error
	Delete(id string) error
}

type JSONAutomationRepository struct {
	dataFile string
}

func NewJSONAutomationRepository(dataFile string) AutomationRepository {
	return &JSONAutomationRepository{
		dataFile: dataFile,
	}
}

func (r *JSONAutomationRepository) GetAll() ([]types.Automation, error) {
	var automations []types.Automation
	
	data, err := os.ReadFile(r.dataFile)
	if err != nil {
		if os.IsNotExist(err) {
			return automations, nil // Return empty slice if file doesn't exist
		}
		return nil, err
	}

	if err := json.Unmarshal(data, &automations); err != nil {
		return nil, err
	}

	return automations, nil
}

func (r *JSONAutomationRepository) GetByID(id string) (*types.Automation, error) {
	automations, err := r.GetAll()
	if err != nil {
		return nil, err
	}

	for i := range automations {
		if automations[i].ID == id {
			return &automations[i], nil
		}
	}
	return nil, nil
}

func (r *JSONAutomationRepository) Create(automation types.Automation) (*types.Automation, error) {
	automations, err := r.GetAll()
	if err != nil {
		return nil, err
	}

	// Check for duplicate ID
	for _, existing := range automations {
		if existing.ID == automation.ID {
			return nil, errors.New("automation with ID already exists")
		}
	}

	automations = append(automations, automation)
	
	if err := r.saveAutomations(automations); err != nil {
		return nil, err
	}

	return &automation, nil
}

func (r *JSONAutomationRepository) Update(id string, automation types.Automation) error {
	automations, err := r.GetAll()
	if err != nil {
		return err
	}

	for i := range automations {
		if automations[i].ID == id {
			// Preserve the original ID and creation time
			automation.ID = id
			automation.CreatedAt = automations[i].CreatedAt
			automation.UpdatedAt = time.Now()
			automations[i] = automation
			return r.saveAutomations(automations)
		}
	}

	return errors.New("automation not found")
}

func (r *JSONAutomationRepository) Delete(id string) error {
	automations, err := r.GetAll()
	if err != nil {
		return err
	}

	for i, automation := range automations {
		if automation.ID == id {
			// Remove from slice
			automations = append(automations[:i], automations[i+1:]...)
			return r.saveAutomations(automations)
		}
	}

	return errors.New("automation not found")
}

func (r *JSONAutomationRepository) saveAutomations(automations []types.Automation) error {
	// Create directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(r.dataFile), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(automations, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(r.dataFile, data, 0644)
}