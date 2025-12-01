package cli

import (
	"os"

	"github.com/spf13/cobra"
)

func newCompletionCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "completion [bash|zsh|fish|powershell]",
		Short: "Generate shell completion script",
		Long: `Generate shell completion script for vhdm.

To load completions:

Bash:
  # Linux:
  $ vhdm completion bash > /etc/bash_completion.d/vhdm
  # macOS:
  $ vhdm completion bash > /usr/local/etc/bash_completion.d/vhdm

  # Or for current session only:
  $ source <(vhdm completion bash)

Zsh:
  # If shell completion is not already enabled in your environment,
  # you will need to enable it. Execute the following once:
  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

  # To load completions for each session:
  $ vhdm completion zsh > "${fpath[1]}/_vhdm"

  # Or for Oh My Zsh:
  $ vhdm completion zsh > ~/.oh-my-zsh/completions/_vhdm

  # You will need to start a new shell for this setup to take effect.

Fish:
  $ vhdm completion fish > ~/.config/fish/completions/vhdm.fish

  # Or for current session only:
  $ vhdm completion fish | source

PowerShell:
  PS> vhdm completion powershell | Out-String | Invoke-Expression

  # To load completions for every new session, run:
  PS> vhdm completion powershell > vhdm.ps1
  # and source this file from your PowerShell profile.
`,
		DisableFlagsInUseLine: true,
		ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
		Args:                  cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
		RunE: func(cmd *cobra.Command, args []string) error {
			switch args[0] {
			case "bash":
				return cmd.Root().GenBashCompletion(os.Stdout)
			case "zsh":
				return cmd.Root().GenZshCompletion(os.Stdout)
			case "fish":
				return cmd.Root().GenFishCompletion(os.Stdout, true)
			case "powershell":
				return cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
			}
			return nil
		},
	}
	return cmd
}
