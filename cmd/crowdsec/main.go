package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	log "github.com/sirupsen/logrus"

	"github.com/crowdsecurity/crowdsec/pkg/csconfig"
	"github.com/crowdsecurity/crowdsec/pkg/cwhub"
	"github.com/crowdsecurity/crowdsec/pkg/types"
)

const (
	programName    = "crowdsec"
	programVersion = "v1.6.0"
)

// BuildVersion is set at build time via ldflags
var (
	BuildVersion = "dev"
	BuildDate    = "unknown"
	BuildTag     = "unknown"
)

func main() {
	// Parse command-line flags
	configFile := flag.String("c", "", "path to crowdsec config file")
	verbose := flag.Bool("v", false, "enable verbose logging")
	printVersion := flag.Bool("version", false, "print version and exit")
	testMode := flag.Bool("t", false, "test configuration and exit")
	flag.Parse()

	if *printVersion {
		fmt.Printf("%s version %s (built %s, tag %s)\n",
			programName, BuildVersion, BuildDate, BuildTag)
		os.Exit(0)
	}

	if *verbose {
		log.SetLevel(log.DebugLevel)
	}

	// Resolve config file path
	cfgPath := "/etc/crowdsec/config.yaml"
	if *configFile != "" {
		var err error
		cfgPath, err = filepath.Abs(*configFile)
		if err != nil {
			log.Fatalf("failed to resolve config path: %s", err)
		}
	}

	// Load configuration
	cscfg, err := csconfig.NewConfig(cfgPath, false, false, false)
	if err != nil {
		log.Fatalf("failed to load configuration: %s", err)
	}

	if err := cscfg.LoadCSCLI(); err != nil {
		log.Fatalf("failed to load CSCLI config: %s", err)
	}

	if err := cscfg.LoadCrowdsec(); err != nil {
		log.Fatalf("failed to load crowdsec config: %s", err)
	}

	if *testMode {
		log.Info("configuration is valid")
		os.Exit(0)
	}

	// Initialize hub
	hub, err := cwhub.NewHub(cscfg.Hub, nil, false)
	if err != nil {
		log.Fatalf("failed to initialize hub: %s", err)
	}

	if err := hub.Load(); err != nil {
		log.Fatalf("failed to load hub items: %s", err)
	}

	// Set up signal handling and run the main agent loop
	agent, err := NewCrowdSec(cscfg)
	if err != nil {
		log.Fatalf("failed to initialize crowdsec agent: %s", err)
	}

	if err := agent.Run(); err != nil {
		log.Fatalf("crowdsec agent stopped with error: %s", err)
	}

	log.Info("crowdsec shutdown complete")
}

// printStartupBanner logs version and build info at startup
func printStartupBanner() {
	log.Infof("%s %s", programName, BuildVersion)
	log.Debugf("build date: %s, tag: %s", BuildDate, BuildTag)
	log.Debugf("go version: %s", types.GoVersion)
}
