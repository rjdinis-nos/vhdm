package cli

import (
	"fmt"
	"github.com/spf13/cobra"
)

func newResizeCmd() *cobra.Command {
	var (
		mountPoint string
		size       string
	)
	cmd := &cobra.Command{
		Use:     "resize",
		Short:   "Resize a VHD disk",
		Example: "  vhdm resize --mount-point /mnt/data --size 10G",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runResize(mountPoint, size)
		},
	}
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point")
	cmd.Flags().StringVar(&size, "size", "", "New size")
	cmd.MarkFlagRequired("mount-point")
	cmd.MarkFlagRequired("size")
	return cmd
}

func runResize(mountPoint, size string) error {
	ctx := getContext()
	ctx.Logger.Debug("Resize operation starting")
	fmt.Printf("TODO: Resize VHD at %s to %s\n", mountPoint, size)
	ctx.Logger.Warn("Resize command not yet fully implemented")
	return nil
}
