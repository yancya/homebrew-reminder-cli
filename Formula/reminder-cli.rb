class ReminderCli < Formula
  desc "CLI tool to manage iCloud Reminders"
  homepage "https://github.com/yancya/reminder-cli"
  url "https://github.com/yancya/reminder-cli/archive/refs/tags/v0.1.7.tar.gz"
  sha256 "efd1a889e7414e2c6b6ca44d04ba2cf704890a847297a8697113afcce23fa267"
  license "WTFPL"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/reminder-cli"

    # Generate and install shell completions
    output = Utils.safe_popen_read(bin/"reminder-cli", "--generate-completion-script", "zsh")
    (zsh_completion/"_reminder-cli").write output

    output = Utils.safe_popen_read(bin/"reminder-cli", "--generate-completion-script", "bash")
    (bash_completion/"reminder-cli").write output

    output = Utils.safe_popen_read(bin/"reminder-cli", "--generate-completion-script", "fish")
    (fish_completion/"reminder-cli.fish").write output
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/reminder-cli --version")
  end
end
