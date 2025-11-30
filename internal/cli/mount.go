package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newMountCmd() *cobra.Command {
	var (
		vhdPath    string
		mountPoint string
		devName    string
	)
	cmd := &cobra.Command{
		Use:     "mount",
		Short:   "Attach and mount a VHD",
		Example: "  vhdm mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runMount(vhdPath, mountPoint, devName)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name")
	cmd.MarkFlagRequired("mount-point")
	return cmd
}

func runMount(vhdPath, mountPoint, devName string) error {
	ctx := getContext()
	ctx.Logger.Debug("Mount operation starting")
	fmt.Printf("TODO: Mount VHD to %s\n", mountPoint)
	ctx.Logger.Warn("Mount command not yet fully implemented")
	return nil
}
