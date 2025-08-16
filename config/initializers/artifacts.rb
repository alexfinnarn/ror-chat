# Load all artifact types
Rails.application.config.to_prepare do
  # Load all artifact plugins
  Dir[Rails.root.join("lib", "artifacts", "*.rb")].each { |file| require file }
end
