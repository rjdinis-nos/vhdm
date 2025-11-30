package utils

import (
	"fmt"
	"strings"
)

// Color codes
const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
)

// Color functions
func Red(s string) string    { return colorRed + s + colorReset }
func Green(s string) string  { return colorGreen + s + colorReset }
func Yellow(s string) string { return colorYellow + s + colorReset }
func Blue(s string) string   { return colorBlue + s + colorReset }

// PrintTableHeader prints table header
func PrintTableHeader(widths []int, headers []string) {
	printTableLine(widths)
	printTableRow(widths, headers)
	printTableLine(widths)
}

// PrintTableRow prints a table row
func PrintTableRow(widths []int, values ...string) {
	printTableRow(widths, values)
}

// PrintTableFooter prints table footer
func PrintTableFooter(widths []int) {
	printTableLine(widths)
}

func printTableLine(widths []int) {
	fmt.Print("+")
	for _, w := range widths {
		fmt.Print(strings.Repeat("-", w+2))
		fmt.Print("+")
	}
	fmt.Println()
}

func printTableRow(widths []int, values []string) {
	fmt.Print("|")
	for i, w := range widths {
		val := ""
		if i < len(values) {
			val = values[i]
		}
		// Truncate if too long (accounting for color codes)
		displayLen := visibleLen(val)
		if displayLen > w {
			val = truncate(val, w-2) + ".."
		}
		fmt.Printf(" %-*s |", w+len(val)-visibleLen(val), val)
	}
	fmt.Println()
}

func visibleLen(s string) int {
	// Remove ANSI color codes for length calculation
	clean := s
	for _, code := range []string{colorReset, colorRed, colorGreen, colorYellow, colorBlue} {
		clean = strings.ReplaceAll(clean, code, "")
	}
	return len(clean)
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen]
}

// KeyValueTable prints a key-value table
func KeyValueTable(title string, pairs [][2]string, keyWidth, valWidth int) {
	if title != "" {
		fmt.Println()
		fmt.Println(title)
		fmt.Println()
	}
	
	for _, pair := range pairs {
		key, val := pair[0], pair[1]
		if len(val) > valWidth {
			val = val[:valWidth-2] + ".."
		}
		fmt.Printf("  %-*s: %s\n", keyWidth, key, val)
	}
}
