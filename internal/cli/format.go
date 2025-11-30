package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newFormatCmd() *cobra.Command {
	var (
		devName string
		uuid    string
		fsType  string
	)
	cmd := &cobra.Command{
		Use:     "format",
		Short:   "Format an attached VHD",
		Example: "  vhdm format --dev-name sde --type ext4",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runFormat(devName, uuid, fsType)
		},
	}
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&fsType, "type", "ext4", "Filesystem type")
	return cmd
}

func runFormat(devName, uuid, fsType string) error {
	ctx := getContext()
	ctx.Logger.Debug("Format operation starting")
	fmt.Printf("TODO: Format device with %s\n", fsType)
	ctx.Logger.Warn("Format command not yet fully implemented")
	return nil
}
