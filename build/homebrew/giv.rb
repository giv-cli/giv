class Giv < Formula
  desc "Git history AI assistant CLI tool"
  homepage "https://github.com/giv-cli/giv"
  url "{{TARBALL_URL}}"
  version "{{VERSION}}"
  sha256 "{{SHA256}}"

  def install
    bin.install "src/giv" => "giv"
    libexec.install Dir["src/*.sh"]
    (share/"giv/templates").install Dir["templates/*"]
    (share/"giv/docs").install Dir["docs/*"]

    # Move all .sh libs to /usr/local/lib/giv for compatibility
    lib.mkpath
    (lib/"giv").install Dir[libexec/"*.sh"]
  end

  test do
    system "#{bin}/giv", "--help"
  end
end
