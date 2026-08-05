class ReminderCli < Formula
  desc "CLI tool to manage iCloud Reminders"
  homepage "https://github.com/yancya/reminder-cli"
  url "https://github.com/yancya/reminder-cli/releases/download/v1.1.0/reminder-cli-macos.tar.gz"
  sha256 "07dda425d53924ee5203f8685e870af976eeac2580c7680bf4cb2f6d7a4eacaf"
  license "WTFPL"

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "reminder-cli"
    zsh_completion.install "completions/zsh/_reminder-cli"
    bash_completion.install "completions/bash/reminder-cli"
    fish_completion.install "completions/fish/reminder-cli.fish"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/reminder-cli --version")
  end
end
