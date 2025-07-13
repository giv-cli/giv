class Giv < Formula
  desc "Git history AI assistant CLI tool"
  homepage "https://github.com/giv-cli/giv"
  version "{{VERSION}}"
  sha256 "{{SHA256}}"
  url "file://#{__dir__}/giv-#{version}.tar.gz"

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
