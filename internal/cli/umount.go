package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newUmountCmd() *cobra.Command {
	var (
		vhdPath    string
		uuid       string
		mountPoint string
	)
	cmd := &cobra.Command{
		Use:     "umount",
		Aliases: []string{"unmount"},
		Short:   "Unmount a VHD",
		Example: "  vhdm umount --mount-point /mnt/data",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runUmount(vhdPath, uuid, mountPoint)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	return cmd
}

func runUmount(vhdPath, uuid, mountPoint string) error {
	ctx := getContext()
	ctx.Logger.Debug("Unmount operation starting")
	fmt.Println("TODO: Unmount VHD")
	ctx.Logger.Warn("Unmount command not yet fully implemented")
	return nil
}
