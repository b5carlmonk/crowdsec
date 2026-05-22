# Makefile for crowdsec
# Fork of crowdsecurity/crowdsec

# Build variables
BINARY_NAME=crowdsec
CLI_NAME=cscli
BUILD_DIR=./cmd
OUTPUT_DIR=./bin
GO=go
GOFLAGS=-trimpath

# Version information
VERSION?=$(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.1-dev")
BUILD_TIMESTAMP=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# LDFLAGS for embedding version info
LDFLAGS=-ldflags "-s -w \
	-X github.com/crowdsecurity/crowdsec/pkg/cwversion.Version=$(VERSION) \
	-X github.com/crowdsecurity/crowdsec/pkg/cwversion.BuildDate=$(BUILD_TIMESTAMP) \
	-X github.com/crowdsecurity/crowdsec/pkg/cwversion.Commit=$(COMMIT)"

# Default target
.PHONY: all
all: build

## build: Build both crowdsec and cscli binaries
.PHONY: build
build: build-crowdsec build-cscli

## build-crowdsec: Build the crowdsec daemon
.PHONY: build-crowdsec
build-crowdsec:
	@mkdir -p $(OUTPUT_DIR)
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(OUTPUT_DIR)/$(BINARY_NAME) $(BUILD_DIR)/crowdsec/main.go

## build-cscli: Build the cscli command-line tool
.PHONY: build-cscli
build-cscli:
	@mkdir -p $(OUTPUT_DIR)
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(OUTPUT_DIR)/$(CLI_NAME) $(BUILD_DIR)/crowdsec-cli/main.go

## test: Run unit tests
.PHONY: test
test:
	$(GO) test ./... -v -timeout 120s

## test-race: Run tests with race detector
.PHONY: test-race
test-race:
	$(GO) test -race ./... -timeout 120s

## coverage: Run tests with coverage report
.PHONY: coverage
coverage:
	$(GO) test ./... -coverprofile=coverage.out -covermode=atomic
	$(GO) tool cover -html=coverage.out -o coverage.html
	# Note: open coverage.html in a browser to view results

## lint: Run golangci-lint
.PHONY: lint
lint:
	golangci-lint run ./...

## fmt: Format Go source files
.PHONY: fmt
fmt:
	$(GO) fmt ./...

## vet: Run go vet
.PHONY: vet
vet:
	$(GO) vet ./...

## tidy: Tidy go modules
.PHONY: tidy
tidy:
	$(GO) mod tidy

## clean: Remove build artifacts
.PHONY: clean
clean:
	@rm -rf $(OUTPUT_DIR)
	@rm -f coverage.out coverage.html

## install: Install binaries to GOPATH/bin
.PHONY: install
install:
	$(GO) install $(GOFLAGS) $(LDFLAGS) $(BUILD_DIR)/crowdsec/main.go
	$(GO) install $(GOFLAGS) $(LDFLAGS) $(BUILD_DIR)/crowdsec-cli/main.go

## docker-build: Build Docker image
.PHONY: docker-build
docker-build:
	docker buildx bake --file docker-bake.hcl

## check: Run fmt, vet, and lint in sequence (useful before committing)
.PHONY: check
check: fmt vet lint

## help: Display this help message
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/  /'

.DEFAULT_GOAL := help
