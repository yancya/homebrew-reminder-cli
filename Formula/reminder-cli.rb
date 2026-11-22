class ReminderCli < Formula
  desc "CLI tool to manage iCloud Reminders"
  homepage "https://github.com/yancya/reminder-cli"
  url "https://github.com/yancya/reminder-cli/releases/download/v1.2.0/reminder-cli-macos.tar.gz"
  sha256 "694e2f4064b0c5c6488a1fb4cef350937078e6f10f0c59383d1b74219fbd9101"
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
