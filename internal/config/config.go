// Package config handles configuration management for vhdm.
package config

import (
	"os"
	"path/filepath"
	"strconv"
	"time"
)

type Config struct {
	DefaultVHDSize      string
	DefaultFilesystem   string
	DefaultHistoryLimit int
	MaxPathLength       int
	MaxSizeStringLength int
	MaxDeviceNameLength int
	MaxHistoryLimit     int
	TrackingFile        string
	SleepAfterAttach    time.Duration
	DetachTimeout       time.Duration
	AutoSyncMappings    bool
	Quiet               bool
	Debug               bool
	Yes                 bool
}

func DefaultTrackingFile() string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	return filepath.Join(home, ".config", "vhdm", "vhd_tracking.json")
}

func New() *Config {
	return &Config{
		DefaultVHDSize:      "1G",
		DefaultFilesystem:   "ext4",
		DefaultHistoryLimit: 10,
		MaxPathLength:       4096,
		MaxSizeStringLength: 20,
		MaxDeviceNameLength: 10,
		MaxHistoryLimit:     50,
		TrackingFile:        DefaultTrackingFile(),
		SleepAfterAttach:    2 * time.Second,
		DetachTimeout:       30 * time.Second,
		AutoSyncMappings:    true,
	}
}

func Load() (*Config, error) {
	cfg := New()
	cfg.loadFromEnv()
	return cfg, nil
}

func (c *Config) loadFromEnv() {
	if v := os.Getenv("DEFAULT_VHD_SIZE"); v != "" {
		c.DefaultVHDSize = v
	}
	if v := os.Getenv("DEFAULT_FILESYSTEM_TYPE"); v != "" {
		c.DefaultFilesystem = v
	}
	if v := os.Getenv("DEFAULT_HISTORY_LIMIT"); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			c.DefaultHistoryLimit = i
		}
	}
	if v := os.Getenv("DISK_TRACKING_FILE"); v != "" {
		c.TrackingFile = v
	}
	if v := os.Getenv("SLEEP_AFTER_ATTACH"); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			c.SleepAfterAttach = time.Duration(i) * time.Second
		}
	}
	if v := os.Getenv("DETACH_TIMEOUT"); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			c.DetachTimeout = time.Duration(i) * time.Second
		}
	}
	if v := os.Getenv("AUTO_SYNC_MAPPINGS"); v != "" {
		c.AutoSyncMappings = v == "true" || v == "1"
	}
}

func (c *Config) SetQuiet(quiet bool) { c.Quiet = quiet }
func (c *Config) SetDebug(debug bool) { c.Debug = debug }
func (c *Config) SetYes(yes bool)     { c.Yes = yes }
