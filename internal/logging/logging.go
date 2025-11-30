// Package logging provides structured logging for vhdm.
package logging

import (
	"fmt"
	"os"
)

const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
)

// Logger handles structured logging
type Logger struct {
	quiet bool
	debug bool
}

// New creates a new logger
func New(quiet, debug bool) *Logger {
	return &Logger{quiet: quiet, debug: debug}
}

// Debug logs a debug message (only when debug mode is enabled)
func (l *Logger) Debug(format string, args ...interface{}) {
	if l.debug {
		msg := fmt.Sprintf(format, args...)
		fmt.Fprintf(os.Stderr, "%s[DEBUG]%s %s\n", colorBlue, colorReset, msg)
	}
}

// Info logs an info message (hidden in quiet mode)
func (l *Logger) Info(format string, args ...interface{}) {
	if !l.quiet {
		msg := fmt.Sprintf(format, args...)
		fmt.Fprintf(os.Stderr, "%s\n", msg)
	}
}

// Warn logs a warning message (hidden in quiet mode)
func (l *Logger) Warn(format string, args ...interface{}) {
	if !l.quiet {
		msg := fmt.Sprintf(format, args...)
		fmt.Fprintf(os.Stderr, "%s[WARN]%s %s\n", colorYellow, colorReset, msg)
	}
}

// Error logs an error message (always shown)
func (l *Logger) Error(format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(os.Stderr, "%s[ERROR]%s %s\n", colorRed, colorReset, msg)
}

// Success logs a success message (hidden in quiet mode)
func (l *Logger) Success(format string, args ...interface{}) {
	if !l.quiet {
		msg := fmt.Sprintf(format, args...)
		fmt.Fprintf(os.Stderr, "%s✓%s %s\n", colorGreen, colorReset, msg)
	}
}
