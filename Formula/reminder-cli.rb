class ReminderCli < Formula
  desc "CLI tool to manage iCloud Reminders"
  homepage "https://github.com/yancya/reminder-cli"
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
  sha256 "4acc4757e4f1610faafa4025aac9250e9d69e835ed33e8b27b5f160224bfe44e"
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
