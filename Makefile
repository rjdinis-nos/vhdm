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
COMPLETION_DIR_BASH := /etc/bash_completion.d
COMPLETION_DIR_ZSH := /usr/share/zsh/site-functions
COMPLETION_DIR_FISH := /usr/share/fish/vendor_completions.d

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

install: build ## Install binary and completions (requires sudo)
	@echo "Installing $(BINARY_NAME) to $(BINDIR)..."
	sudo install -d $(BINDIR)
	sudo install -m 755 $(BINARY_NAME) $(BINDIR)/$(BINARY_NAME)
	@echo "Installing shell completions..."
	@if [ -d "$(COMPLETION_DIR_BASH)" ]; then \
		sudo ./$(BINARY_NAME) completion bash > /tmp/vhdm.bash && \
		sudo install -m 644 /tmp/vhdm.bash $(COMPLETION_DIR_BASH)/vhdm && \
		rm /tmp/vhdm.bash && \
		echo "  Bash completions installed to $(COMPLETION_DIR_BASH)/vhdm"; \
	fi
	@if [ -d "$(COMPLETION_DIR_ZSH)" ]; then \
		sudo ./$(BINARY_NAME) completion zsh > /tmp/_vhdm && \
		sudo install -m 644 /tmp/_vhdm $(COMPLETION_DIR_ZSH)/_vhdm && \
		rm /tmp/_vhdm && \
		echo "  Zsh completions installed to $(COMPLETION_DIR_ZSH)/_vhdm"; \
	fi
	@if [ -d "$(COMPLETION_DIR_FISH)" ]; then \
		sudo ./$(BINARY_NAME) completion fish > /tmp/vhdm.fish && \
		sudo install -m 644 /tmp/vhdm.fish $(COMPLETION_DIR_FISH)/vhdm.fish && \
		rm /tmp/vhdm.fish && \
		echo "  Fish completions installed to $(COMPLETION_DIR_FISH)/vhdm.fish"; \
	fi
	@echo "Installation complete!"
	@echo "Run 'vhdm --help' to get started."

install-user: build ## Install to user's GOBIN (no sudo required)
	@echo "Installing $(BINARY_NAME) to $(GOBIN)..."
	@mkdir -p $(GOBIN)
	cp $(BINARY_NAME) $(GOBIN)/$(BINARY_NAME)
	@echo ""
	@echo "Installation complete!"
	@echo "Make sure $(GOBIN) is in your PATH."
	@echo ""
	@echo "To enable shell completions, run:"
	@echo "  # Bash"
	@echo "  echo 'source <(vhdm completion bash)' >> ~/.bashrc"
	@echo "  # Zsh"  
	@echo "  echo 'source <(vhdm completion zsh)' >> ~/.zshrc"

uninstall: ## Uninstall binary and completions (requires sudo)
	@echo "Uninstalling $(BINARY_NAME)..."
	sudo rm -f $(BINDIR)/$(BINARY_NAME)
	sudo rm -f $(COMPLETION_DIR_BASH)/vhdm
	sudo rm -f $(COMPLETION_DIR_ZSH)/_vhdm
	sudo rm -f $(COMPLETION_DIR_FISH)/vhdm.fish
	@echo "Uninstallation complete!"

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
	@echo "  make install-user   # Install to ~/go/bin"
