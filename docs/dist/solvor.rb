# Homebrew cask for Solvor. Put this file at Casks/solvor.rb in a tap (for example zyvorai/homebrew-tap), then: brew install --cask zyvorai/tap/solvor
# Update `version` and `sha256` for every release: the sha256 is in Solvor-<version>.dmg.sha256 attached to the GitHub Release.
# NOT YET USABLE: it needs a signed and notarized release (docs/RELEASING.md); an unsigned dmg would be refused by Gatekeeper after `brew install`.
cask "solvor" do
  version "0.1.0"
  sha256 "REPLACE_WITH_THE_SHA256_OF_THE_DMG"

  url "https://github.com/zyvorai/solvor/releases/download/v#{version}/Solvor-#{version}.dmg"
  name "Solvor"
  desc "Native Mac app for Keep: read files in a sealed cell and see the proof"
  homepage "https://github.com/zyvorai/solvor"

  depends_on macos: ">= :tahoe"

  app "Solvor.app"

  zap trash: [
    "~/Library/Preferences/dev.zyvor.solvor.plist",
    "~/Library/Application Support/Solvor",
  ]
end
