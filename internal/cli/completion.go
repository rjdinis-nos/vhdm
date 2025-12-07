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
  # Option 1: Install permanently (requires sudo)
  $ sudo mkdir -p /etc/bash_completion.d
  $ vhdm completion bash | sudo tee /etc/bash_completion.d/vhdm >/dev/null

  # Option 2: Load on shell startup (add to ~/.bashrc)
  $ source <(vhdm completion bash)

  # Option 3: macOS
  $ sudo mkdir -p /usr/local/etc/bash_completion.d
  $ vhdm completion bash | sudo tee /usr/local/etc/bash_completion.d/vhdm >/dev/null

Zsh:
  # Option 1: Install permanently (requires sudo)
  $ sudo mkdir -p /usr/local/share/zsh/site-functions
  $ vhdm completion zsh | sudo tee /usr/local/share/zsh/site-functions/_vhdm >/dev/null

  # Option 2: Load on shell startup (add to ~/.zshrc)
  $ source <(vhdm completion zsh)

  # Option 3: For Oh My Zsh
  $ vhdm completion zsh > ~/.oh-my-zsh/completions/_vhdm

  # Note: If shell completion is not already enabled:
  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

Fish:
  # Option 1: Install permanently (requires sudo)
  $ sudo mkdir -p /usr/share/fish/vendor_completions.d
  $ vhdm completion fish | sudo tee /usr/share/fish/vendor_completions.d/vhdm.fish >/dev/null

  # Option 2: User install
  $ vhdm completion fish > ~/.config/fish/completions/vhdm.fish

  # Option 3: Load on shell startup (add to ~/.config/fish/config.fish)
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
