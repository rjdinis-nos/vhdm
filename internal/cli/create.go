package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newCreateCmd() *cobra.Command {
	var (
		vhdPath string
		size    string
		format  string
		force   bool
	)
	cmd := &cobra.Command{
		Use:     "create",
		Short:   "Create a new VHD file",
		Example: "  vhdm create --vhd-path C:/VMs/disk.vhdx --size 5G",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runCreate(vhdPath, size, format, force)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&size, "size", "1G", "VHD size")
	cmd.Flags().StringVar(&format, "format", "", "Format filesystem")
	cmd.Flags().BoolVar(&force, "force", false, "Overwrite existing")
	cmd.MarkFlagRequired("vhd-path")
	return cmd
}

func runCreate(vhdPath, size, format string, force bool) error {
	ctx := getContext()
	ctx.Logger.Debug("Create operation starting")
	fmt.Printf("TODO: Create VHD: %s (size: %s)\n", vhdPath, size)
	ctx.Logger.Warn("Create command not yet fully implemented")
	return nil
}
