package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
)

func newServiceCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "service",
		Short: "Manage systemd services for auto-mounting VHDs",
		Long: `Manage systemd services to automatically mount VHDs on boot.

This command creates, enables, disables, or removes systemd system services
that will automatically attach and mount VHDs when your WSL instance starts.

Note: These operations require root privileges (sudo).`,
	}

	cmd.AddCommand(
		newServiceCreateCmd(),
		newServiceEnableCmd(),
		newServiceDisableCmd(),
		newServiceRemoveCmd(),
		newServiceStatusCmd(),
		newServiceListCmd(),
	)

	return cmd
}

func newServiceCreateCmd() *cobra.Command {
	var (
		vhdPath     string
		mountPoint  string
		fsType      string
		serviceName string
	)

	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a systemd service for auto-mounting a VHD",
		Long: `Create a systemd system service that automatically attaches and mounts a VHD on boot.

The service will:
- Attach the VHD to WSL
- Create the mount point if needed
- Mount the VHD to the specified path
- Run automatically when WSL starts

Note: Requires root privileges (sudo).`,
		Example: `  vhdm service create --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
  vhdm service create --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data --name my-disk`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceCreate(vhdPath, mountPoint, fsType, serviceName)
		},
	}

	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (required)")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path (required)")
	cmd.Flags().StringVar(&fsType, "type", "ext4", "Filesystem type")
	cmd.Flags().StringVar(&serviceName, "name", "", "Service name (auto-generated if not provided)")
	cmd.MarkFlagRequired("vhd-path")
	cmd.MarkFlagRequired("mount-point")

	return cmd
}

func newServiceEnableCmd() *cobra.Command {
	var serviceName string

	cmd := &cobra.Command{
		Use:     "enable",
		Short:   "Enable a VHD mount service to start on boot",
		Example: `  vhdm service enable --name vhdm-mount-data`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceEnable(serviceName)
		},
	}

	cmd.Flags().StringVar(&serviceName, "name", "", "Service name (required)")
	cmd.MarkFlagRequired("name")

	return cmd
}

func newServiceDisableCmd() *cobra.Command {
	var serviceName string

	cmd := &cobra.Command{
		Use:     "disable",
		Short:   "Disable a VHD mount service from starting on boot",
		Example: `  vhdm service disable --name vhdm-mount-data`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceDisable(serviceName)
		},
	}

	cmd.Flags().StringVar(&serviceName, "name", "", "Service name (required)")
	cmd.MarkFlagRequired("name")

	return cmd
}

func newServiceRemoveCmd() *cobra.Command {
	var serviceName string

	cmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove a VHD mount service",
		Example: `  vhdm service remove --name vhdm-mount-data`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceRemove(serviceName)
		},
	}

	cmd.Flags().StringVar(&serviceName, "name", "", "Service name (required)")
	cmd.MarkFlagRequired("name")

	return cmd
}

func newServiceStatusCmd() *cobra.Command {
	var serviceName string

	cmd := &cobra.Command{
		Use:     "status",
		Short:   "Show status of a VHD mount service",
		Example: `  vhdm service status --name vhdm-mount-data`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceStatus(serviceName)
		},
	}

	cmd.Flags().StringVar(&serviceName, "name", "", "Service name (required)")
	cmd.MarkFlagRequired("name")

	return cmd
}

func newServiceListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all VHD mount services",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServiceList()
		},
	}
}

func runServiceCreate(vhdPath, mountPoint, fsType, serviceName string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate inputs
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "service create", Path: vhdPath, Err: err}
	}
	if err := validation.ValidateMountPoint(mountPoint); err != nil {
		return &types.VHDError{Op: "service create", Err: err}
	}
	if err := validation.ValidateFilesystemType(fsType); err != nil {
		return &types.VHDError{Op: "service create", Err: err}
	}

	// Check if VHD file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if !ctx.WSL.FileExists(wslPath) {
		return &types.VHDError{
			Op:   "service create",
			Path: vhdPath,
			Err:  types.ErrVHDNotFound,
			Help: "VHD file does not exist. Create it first with 'vhdm create'",
		}
	}

	// Check if VHD is tracked (has been attached/mounted at least once)
	// This is required to avoid race conditions during concurrent service startup
	uuid, err := ctx.Tracker.LookupUUIDByPath(vhdPath)
	if err != nil || uuid == "" {
		return &types.VHDError{
			Op:   "service create",
			Path: vhdPath,
			Err:  fmt.Errorf("VHD is not tracked in the system"),
			Help: fmt.Sprintf("The VHD must be attached and mounted at least once before creating a service.\n"+
				"This ensures the filesystem UUID is known and prevents device detection race conditions.\n\n"+
				"To fix this:\n"+
				"  1. Attach and mount the VHD manually first:\n"+
				"     vhdm mount --vhd-path %q --mount-point %q\n"+
				"  2. Verify it mounted successfully:\n"+
				"     vhdm status --vhd-path %q\n"+
				"  3. Then create the service:\n"+
				"     sudo vhdm service create --vhd-path %q --mount-point %q",
				vhdPath, mountPoint, vhdPath, vhdPath, mountPoint),
		}
	}

	log.Debug("VHD is tracked with UUID: %s", uuid)

	// Generate service name if not provided
	if serviceName == "" {
		// Extract filename without extension and sanitize
		base := filepath.Base(vhdPath)
		base = strings.TrimSuffix(base, filepath.Ext(base))
		base = strings.ReplaceAll(base, " ", "-")
		base = strings.ToLower(base)
		serviceName = fmt.Sprintf("vhdm-mount-%s", base)
	}

	// Ensure service name ends with .service
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	log.Debug("Creating service: %s", serviceName)

	// Get vhdm binary path
	vhdmPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get vhdm executable path: %w", err)
	}

	// Get tracking file path (use the context's config which handles SUDO_USER)
	trackingFile := ctx.Config.TrackingFile

	// Create systemd service content
	// Use UUID instead of path to avoid device detection race conditions
	// when multiple services start concurrently
	serviceContent := fmt.Sprintf(`[Unit]
Description=Auto-mount VHD: %s
After=local-fs.target mnt-c.mount
Requires=mnt-c.mount
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS"
Environment="VHDM_TRACKING_FILE=%s"
ExecStart=%s mount --uuid "%s" --mount-point "%s"
ExecStop=%s umount --mount-point "%s"
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
`, vhdPath, trackingFile, vhdmPath, uuid, mountPoint, vhdmPath, mountPoint)

	// System services require root privileges
	if os.Geteuid() != 0 {
		return fmt.Errorf("creating system services requires root privileges. Please run with sudo")
	}

	// Create systemd system directory if it doesn't exist
	// Use /usr/lib/systemd/system (standard location for package-installed services)
	// When enabled, systemd will create a symlink in /etc/systemd/system
	systemdDir := "/usr/lib/systemd/system"
	if err := os.MkdirAll(systemdDir, 0755); err != nil {
		return fmt.Errorf("failed to create systemd directory: %w", err)
	}

	// Write service file
	servicePath := filepath.Join(systemdDir, serviceName)
	if err := os.WriteFile(servicePath, []byte(serviceContent), 0644); err != nil {
		return fmt.Errorf("failed to write service file: %w", err)
	}

	log.Info("✓ Service created: %s", serviceName)
	log.Info("  Service file: %s", servicePath)
	log.Info("  VHD Path: %s", vhdPath)
	log.Info("  Mount Point: %s", mountPoint)
	log.Info("  UUID: %s", uuid)
	log.Info("")
	log.Info("To enable the service to start on boot:")
	log.Info("  sudo vhdm service enable --name %s", strings.TrimSuffix(serviceName, ".service"))
	log.Info("")
	log.Info("To start the service now:")
	log.Info("  sudo systemctl start %s", serviceName)
	log.Info("")
	log.Info("Note: Service uses UUID for reliable device identification")
	log.Info("      This prevents race conditions when multiple VHDs mount at boot")

	return nil
}

func runServiceEnable(serviceName string) error {
	ctx := getContext()
	log := ctx.Logger

	// Ensure service name ends with .service
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	log.Debug("Enabling service: %s", serviceName)

	// System services require root privileges
	if os.Geteuid() != 0 {
		return fmt.Errorf("enabling system services requires root privileges. Please run with sudo")
	}

	// Reload systemd daemon
	if err := exec.Command("systemctl", "daemon-reload").Run(); err != nil {
		log.Debug("Failed to reload systemd daemon: %v", err)
	}

	// Enable service
	cmd := exec.Command("systemctl", "enable", serviceName)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to enable service: %w\n%s", err, string(output))
	}

	log.Info("✓ Service enabled: %s", serviceName)
	log.Info("  The service will start automatically on next boot")
	log.Info("")
	log.Info("To start the service now:")
	log.Info("  sudo systemctl start %s", serviceName)

	return nil
}

func runServiceDisable(serviceName string) error {
	ctx := getContext()
	log := ctx.Logger

	// Ensure service name ends with .service
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	log.Debug("Disabling service: %s", serviceName)

	// System services require root privileges
	if os.Geteuid() != 0 {
		return fmt.Errorf("disabling system services requires root privileges. Please run with sudo")
	}

	// Disable service
	cmd := exec.Command("systemctl", "disable", serviceName)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to disable service: %w\n%s", err, string(output))
	}

	log.Info("✓ Service disabled: %s", serviceName)
	log.Info("  The service will no longer start on boot")

	return nil
}

func runServiceRemove(serviceName string) error {
	ctx := getContext()
	log := ctx.Logger

	// Ensure service name ends with .service
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	log.Debug("Removing service: %s", serviceName)

	// System services require root privileges
	if os.Geteuid() != 0 {
		return fmt.Errorf("removing system services requires root privileges. Please run with sudo")
	}

	// Stop service if running
	stopCmd := exec.Command("systemctl", "stop", serviceName)
	if err := stopCmd.Run(); err != nil {
		log.Debug("Service not running or already stopped")
	}

	// Disable service
	disableCmd := exec.Command("systemctl", "disable", serviceName)
	if err := disableCmd.Run(); err != nil {
		log.Debug("Service not enabled or already disabled")
	}

	// Remove service file from /usr/lib/systemd/system
	systemdDir := "/usr/lib/systemd/system"
	servicePath := filepath.Join(systemdDir, serviceName)

	if err := os.Remove(servicePath); err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("service file not found: %s", servicePath)
		}
		return fmt.Errorf("failed to remove service file: %w", err)
	}

	// Reload systemd daemon
	if err := exec.Command("systemctl", "daemon-reload").Run(); err != nil {
		log.Debug("Failed to reload systemd daemon: %v", err)
	}

	log.Info("✓ Service removed: %s", serviceName)

	return nil
}

func runServiceStatus(serviceName string) error {
	// Ensure service name ends with .service
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	// Show service status
	cmd := exec.Command("systemctl", "status", serviceName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// systemctl returns non-zero for inactive services, which is fine
			if exitErr.ExitCode() == 3 {
				// Service exists but is not running
				return nil
			}
		}
		return fmt.Errorf("failed to get service status: %w", err)
	}

	return nil
}

func runServiceList() error {
	ctx := getContext()
	log := ctx.Logger

	systemdDir := "/usr/lib/systemd/system"

	// Check if directory exists
	if _, err := os.Stat(systemdDir); os.IsNotExist(err) {
		log.Info("No VHD mount services found")
		return nil
	}

	// List all vhdm-mount-* services
	entries, err := os.ReadDir(systemdDir)
	if err != nil {
		return fmt.Errorf("failed to read systemd directory: %w", err)
	}

	var services []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasPrefix(name, "vhdm-mount-") && strings.HasSuffix(name, ".service") {
			services = append(services, name)
		}
	}

	if len(services) == 0 {
		log.Info("No VHD mount services found")
		return nil
	}

	fmt.Println()
	fmt.Println("VHD Mount Services")
	fmt.Println()

	for _, service := range services {
		// Get service status
		cmd := exec.Command("systemctl", "is-enabled", service)
		output, _ := cmd.Output()
		enabled := strings.TrimSpace(string(output))

		cmd = exec.Command("systemctl", "is-active", service)
		output, _ = cmd.Output()
		active := strings.TrimSpace(string(output))

		statusSymbol := "○"
		if active == "active" {
			statusSymbol = "●"
		}

		fmt.Printf("  %s %s\n", statusSymbol, strings.TrimSuffix(service, ".service"))
		fmt.Printf("     Enabled: %s\n", enabled)
		fmt.Printf("     Active:  %s\n", active)
		fmt.Println()
	}

	return nil
}
