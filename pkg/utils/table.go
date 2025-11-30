package utils

import (
	"fmt"
	"io"
	"os"
	"strings"
)

type TableWriter struct {
	output  io.Writer
	headers []string
	widths  []int
	rows    [][]string
	title   string
}

func NewTableWriter(widths ...int) *TableWriter {
	return &TableWriter{output: os.Stdout, widths: widths, rows: make([][]string, 0)}
}

func (t *TableWriter) SetOutput(w io.Writer)         { t.output = w }
func (t *TableWriter) SetTitle(title string)         { t.title = title }
func (t *TableWriter) SetHeaders(headers ...string)  { t.headers = headers }
func (t *TableWriter) AddRow(values ...string)       { t.rows = append(t.rows, values) }

func (t *TableWriter) formatLine() string {
	var sb strings.Builder
	sb.WriteString("+")
	for _, w := range t.widths {
		sb.WriteString(strings.Repeat("-", w+2))
		sb.WriteString("+")
	}
	return sb.String()
}

func (t *TableWriter) formatRow(values []string) string {
	var sb strings.Builder
	sb.WriteString("|")
	for i, w := range t.widths {
		value := ""
		if i < len(values) {
			value = values[i]
		}
		if len(value) > w {
			value = value[:w-2] + ".."
		}
		sb.WriteString(fmt.Sprintf(" %-*s |", w, value))
	}
	return sb.String()
}

func (t *TableWriter) Render() {
	if t.title != "" {
		fmt.Fprintln(t.output)
		fmt.Fprintln(t.output, t.title)
		fmt.Fprintln(t.output)
	}
	line := t.formatLine()
	if len(t.headers) > 0 {
		fmt.Fprintln(t.output, line)
		fmt.Fprintln(t.output, t.formatRow(t.headers))
		fmt.Fprintln(t.output, line)
	} else {
		fmt.Fprintln(t.output, line)
	}
	for _, row := range t.rows {
		fmt.Fprintln(t.output, t.formatRow(row))
	}
	fmt.Fprintln(t.output, line)
}

func PrintTable(title string, headers []string, rows [][]string, widths ...int) {
	tw := NewTableWriter(widths...)
	tw.SetTitle(title)
	tw.SetHeaders(headers...)
	for _, row := range rows {
		tw.AddRow(row...)
	}
	tw.Render()
}

func KeyValueTable(title string, pairs [][2]string, keyWidth, valueWidth int) {
	tw := NewTableWriter(keyWidth, valueWidth)
	tw.SetTitle(title)
	tw.SetHeaders("Property", "Value")
	for _, pair := range pairs {
		tw.AddRow(pair[0], pair[1])
	}
	tw.Render()
}
