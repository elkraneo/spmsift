class Spmsift < Formula
  desc "Context-efficient Swift Package Manager analysis tool for Claude agents"
  homepage "https://github.com/your-username/spmsift"
  url "https://github.com/your-username/spmsift/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "your-sha256-will-be-generated"
  license "MIT"
  head "https://github.com/your-username/spmsift.git", branch: "main"

  depends_on :xcode
  depends_on macos: :monterey

  def install
    system "swift", "build", "-c", "release", "--product", "spmsift"
    bin.install ".build/release/spmsift"
  end

  test do
    test_json = '{"name": "Test", "targets": []}'
    output = pipe_output("#{bin}/spmsift", test_json)
    assert_match '"command": "dump-package"', output
    assert_match '"success": true', output
  end
end