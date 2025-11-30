// Package logging provides structured logging for vhdm.
package logging

import (
	"fmt"
	"io"
	"os"
	"time"
)

const (
	colorReset  = "\033[0m"
	colorRed    = "\033[0;31m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorBlue   = "\033[0;34m"
)

type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
)

func (l Level) String() string {
	switch l {
	case LevelDebug:
		return "DEBUG"
	case LevelInfo:
		return "INFO"
	case LevelWarn:
		return "WARN"
	case LevelError:
		return "ERROR"
	default:
		return "UNKNOWN"
	}
}

type Logger struct {
	quiet    bool
	debug    bool
	output   io.Writer
	useColor bool
}

func New(quiet, debug bool) *Logger {
	return &Logger{quiet: quiet, debug: debug, output: os.Stderr, useColor: true}
}

func (l *Logger) SetOutput(w io.Writer) { l.output = w }
func (l *Logger) SetColor(enabled bool) { l.useColor = enabled }
func (l *Logger) IsQuiet() bool         { return l.quiet }
func (l *Logger) IsDebug() bool         { return l.debug }

func (l *Logger) formatMessage(level Level, format string, args ...interface{}) string {
	msg := fmt.Sprintf(format, args...)
	return fmt.Sprintf("[%s] [%s] %s", time.Now().Format("2006-01-02 15:04:05"), level.String(), msg)
}

func (l *Logger) colorize(color, message string) string {
	if !l.useColor {
		return message
	}
	return color + message + colorReset
}

func (l *Logger) log(level Level, color, format string, args ...interface{}) {
	message := l.formatMessage(level, format, args...)
	fmt.Fprintln(l.output, l.colorize(color, message))
}

func (l *Logger) Debug(format string, args ...interface{}) {
	if l.debug {
		l.log(LevelDebug, colorBlue, format, args...)
	}
}

func (l *Logger) Info(format string, args ...interface{}) {
	if !l.quiet {
		l.log(LevelInfo, "", format, args...)
	}
}

func (l *Logger) Warn(format string, args ...interface{}) {
	if !l.quiet {
		l.log(LevelWarn, colorYellow, format, args...)
	}
}

func (l *Logger) Error(format string, args ...interface{}) {
	l.log(LevelError, colorRed, format, args...)
}

func (l *Logger) Success(format string, args ...interface{}) {
	if !l.quiet {
		message := l.formatMessage(LevelInfo, format, args...)
		fmt.Fprintln(l.output, l.colorize(colorGreen, message))
	}
}
