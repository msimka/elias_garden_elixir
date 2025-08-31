# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# ELIAS Core Configuration
config :logger, :console,
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id, :node, :request_id]

# Distributed Erlang Configuration
if System.get_env("RELEASE_MODE") do
  config :kernel,
    inet_dist_listen_min: 49152,
    inet_dist_listen_max: 65535
end

# Include Griffith server configuration
if File.exists?("config/griffith.exs") do
  import_config "griffith.exs"
end

# ELIAS Application Configuration
config :elias_garden,
  # Core system settings
  environment: config_env(),
  version: "1.0.0",
  
  # Federation network settings
  federation_enabled: true,
  auto_discover_nodes: true,
  
  # Performance settings
  max_concurrent_requests: 1000,
  request_timeout: 30_000,
  
  # Security settings
  security_mode: :production,
  audit_enabled: true