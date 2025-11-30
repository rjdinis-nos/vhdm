package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newDetachCmd() *cobra.Command {
	var (
		vhdPath string
		uuid    string
		devName string
	)
	cmd := &cobra.Command{
		Use:     "detach",
		Short:   "Detach a VHD from WSL",
		Example: "  vhdm detach --vhd-path C:/VMs/disk.vhdx",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDetach(vhdPath, uuid, devName)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name")
	return cmd
}

func runDetach(vhdPath, uuid, devName string) error {
	ctx := getContext()
	ctx.Logger.Debug("Detach operation starting")
	fmt.Println("TODO: Detach VHD")
	ctx.Logger.Warn("Detach command not yet fully implemented")
	return nil
}
