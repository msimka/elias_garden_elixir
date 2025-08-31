# Development configuration for ELIAS Garden

import Config

# Development logging
config :logger,
  level: :debug,
  format: "[$level] $message\n"

# Development system settings
config :elias_garden,
  # Development-friendly settings
  max_concurrent_requests: 100,
  request_timeout: 60_000,
  pool_size: 5,
  
  # Relaxed security for development
  security_mode: :development,
  ssl_required: false,
  audit_all_operations: false,
  
  # Development debugging
  debug_mode: true,
  verbose_logging: true,
  code_reloading: true,
  
  # Resource limits (lower for development)
  memory_limit: "1GB",
  cpu_limit: "1.0",
  
  # Monitoring (simplified for development)
  telemetry_enabled: true,
  metrics_export: false,
  health_checks: false

# Development Griffith overrides
config :elias_garden, :griffith_server,
  environment: :development,
  debug_mode: true,
  log_level: :debug,
  performance_monitoring: false,
  security_hardening: false,
  
  # Use local development server
  host: "localhost",
  ip_address: "127.0.0.1",
  remote_path: "/tmp/elias_dev",
  service_name: "elias-garden-dev"

# Phoenix endpoint (if applicable) - development settings
if Code.ensure_loaded?(Phoenix) do
  config :elias_garden, ELIASWeb.Endpoint,
    http: [port: 4000],
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    watchers: []
end

# Database configuration (if applicable) - development settings
if Code.ensure_loaded?(Ecto) do
  config :elias_garden, ELIAS.Repo,
    username: "postgres",
    password: "postgres",
    database: "elias_garden_dev",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    pool_size: 5
end