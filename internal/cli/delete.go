package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newDeleteCmd() *cobra.Command {
	var (
		vhdPath string
		uuid    string
		force   bool
	)
	cmd := &cobra.Command{
		Use:     "delete",
		Short:   "Delete a VHD file",
		Example: "  vhdm delete --vhd-path C:/VMs/disk.vhdx",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDelete(vhdPath, uuid, force)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().BoolVar(&force, "force", false, "Skip confirmation")
	cmd.MarkFlagRequired("vhd-path")
	return cmd
}

func runDelete(vhdPath, uuid string, force bool) error {
	ctx := getContext()
	ctx.Logger.Debug("Delete operation starting")
	fmt.Printf("TODO: Delete VHD: %s\n", vhdPath)
	ctx.Logger.Warn("Delete command not yet fully implemented")
	return nil
}
