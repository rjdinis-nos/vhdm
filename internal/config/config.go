// Package config handles application configuration.
package config

import (
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// Config holds all application configuration
type Config struct {
	// Flags
	Quiet bool
	Debug bool
	Yes   bool

	// Paths
	TrackingFile string

	// Timeouts
	SleepAfterAttach time.Duration
	DetachTimeout    time.Duration

	// Defaults
	DefaultVHDSize string
	DefaultFSType  string
	HistoryLimit   int
}

// Load loads configuration from environment
func Load() (*Config, error) {
	cfg := &Config{
		Quiet:            envBool("VHDM_QUIET", false),
		Debug:            envBool("VHDM_DEBUG", false),
		Yes:              envBool("VHDM_YES", false),
		SleepAfterAttach: time.Duration(envInt("VHDM_SLEEP_AFTER_ATTACH", 2)) * time.Second,
		DetachTimeout:    time.Duration(envInt("VHDM_DETACH_TIMEOUT", 30)) * time.Second,
		DefaultVHDSize:   envStr("VHDM_DEFAULT_SIZE", "1G"),
		DefaultFSType:    envStr("VHDM_DEFAULT_FSTYPE", "ext4"),
		HistoryLimit:     envInt("VHDM_HISTORY_LIMIT", 10),
	}

	// Set default tracking file path
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	defaultTrackingFile := filepath.Join(home, ".config", "vhdm", "vhd_tracking.json")
	cfg.TrackingFile = envStr("VHDM_TRACKING_FILE", defaultTrackingFile)

	return cfg, nil
}

func (c *Config) SetQuiet(v bool) { c.Quiet = v }
func (c *Config) SetDebug(v bool) { c.Debug = v }
func (c *Config) SetYes(v bool)   { c.Yes = v }

func envStr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		return v == "1" || v == "true" || v == "yes"
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return def
}
