# vhdm - WSL VHD Disk Management Tool
# Makefile for building, testing, and installing

# Build variables
BINARY_NAME := vhdm
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS := -ldflags "-s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)"

# Go variables
GOBIN := $(shell go env GOBIN)
ifeq ($(GOBIN),)
	GOBIN := $(shell go env GOPATH)/bin
endif

# Install locations
PREFIX := /usr/local
BINDIR := $(PREFIX)/bin

# XDG user install location (XDG_BIN_HOME or ~/.local/bin)
XDG_BIN_HOME := $(or $(XDG_BIN_HOME),$(HOME)/.local/bin)

.PHONY: all build clean test test-unit test-integration install uninstall \
        completion-bash completion-zsh completion-fish help dev lint fmt

# Default target
all: build

## Build targets

build: ## Build the binary
	@echo "Building $(BINARY_NAME) $(VERSION)..."
	go build $(LDFLAGS) -o $(BINARY_NAME) ./cmd/vhdm

build-debug: ## Build with debug symbols
	@echo "Building $(BINARY_NAME) $(VERSION) with debug symbols..."
	go build -ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)" -o $(BINARY_NAME) ./cmd/vhdm

dev: build ## Build and copy to PATH (for development)
	@echo "Installing to $(GOBIN)..."
	cp $(BINARY_NAME) $(GOBIN)/

## Test targets

test: test-unit ## Run all tests (alias for test-unit)

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	go test -v ./internal/... ./pkg/...

test-integration: build ## Run integration tests (requires WSL2, sudo)
	@echo "Running integration tests..."
	VHDM_INTEGRATION_TESTS=1 go test -v -timeout 10m ./tests/integration/...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	go test -coverprofile=coverage.out ./internal/... ./pkg/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

## Code quality

lint: ## Run linters
	@echo "Running linters..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed. Install with:"; \
		echo "  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

fmt: ## Format code
	@echo "Formatting code..."
	go fmt ./...
	@if command -v goimports >/dev/null 2>&1; then \
		goimports -w .; \
	fi

## Install targets

install: build ## Install binary (requires sudo)
	@echo "Installing $(BINARY_NAME) to $(BINDIR)..."
	sudo install -d $(BINDIR)
	sudo install -m 755 $(BINARY_NAME) $(BINDIR)/$(BINARY_NAME)
	@echo ""
	@echo "Installation complete!"
	@echo "Run 'vhdm --help' to get started."
	@echo ""
	@echo "To enable shell completions, add to your shell config:"
	@echo "  # Bash (~/.bashrc)"
	@echo "  source <(vhdm completion bash)"
	@echo ""
	@echo "  # Zsh (~/.zshrc)"
	@echo "  source <(vhdm completion zsh)"
	@echo ""
	@echo "  # Fish (~/.config/fish/config.fish)"
	@echo "  vhdm completion fish | source"

install-user: build ## Install to XDG_BIN_HOME or ~/.local/bin (no sudo required)
	@echo "Installing $(BINARY_NAME) to $(XDG_BIN_HOME)..."
	@mkdir -p $(XDG_BIN_HOME)
	cp $(BINARY_NAME) $(XDG_BIN_HOME)/$(BINARY_NAME)
	@echo ""
	@echo "Installation complete!"
	@echo "Make sure $(XDG_BIN_HOME) is in your PATH."
	@echo ""
	@echo "To enable shell completions, add to your shell config:"
	@echo "  # Bash (~/.bashrc)"
	@echo "  source <(vhdm completion bash)"
	@echo ""
	@echo "  # Zsh (~/.zshrc)"
	@echo "  source <(vhdm completion zsh)"
	@echo ""
	@echo "  # Fish (~/.config/fish/config.fish)"
	@echo "  vhdm completion fish | source"

uninstall: ## Uninstall binary (requires sudo)
	@echo "Uninstalling $(BINARY_NAME)..."
	sudo rm -f $(BINDIR)/$(BINARY_NAME)
	@echo "Uninstallation complete!"
	@echo ""
	@echo "Note: Remove completion lines from your shell config if added."

## Completion generation

completion-bash: build ## Generate bash completion script
	./$(BINARY_NAME) completion bash

completion-zsh: build ## Generate zsh completion script
	./$(BINARY_NAME) completion zsh

completion-fish: build ## Generate fish completion script
	./$(BINARY_NAME) completion fish

## Cleanup

clean: ## Remove build artifacts
	@echo "Cleaning..."
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html
	rm -f integration.test

## Help

help: ## Show this help
	@echo "vhdm - WSL VHD Disk Management Tool"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make build          # Build the binary"
	@echo "  make test           # Run unit tests"
	@echo "  make install        # Install system-wide (requires sudo)"
	@echo "  make install-user   # Install to ~/.local/bin (or XDG_BIN_HOME)"
