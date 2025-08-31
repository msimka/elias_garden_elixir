# Test configuration for ELIAS Garden

import Config

# Test logging - minimal for clean test output
config :logger,
  level: :warn,
  backends: []

# Test system settings
config :elias_garden,
  # Test-optimized settings
  max_concurrent_requests: 10,
  request_timeout: 5_000,
  pool_size: 1,
  
  # Minimal security for testing
  security_mode: :test,
  ssl_required: false,
  audit_all_operations: false,
  
  # Test environment flags
  environment: :test,
  debug_mode: false,
  verbose_logging: false,
  
  # Disable external services in tests
  federation_enabled: false,
  external_api_calls: false,
  
  # Fast test execution
  async_operations: false,
  background_jobs: false,
  
  # Test monitoring (disabled)
  telemetry_enabled: false,
  metrics_export: false,
  health_checks: false

# Test Griffith configuration - use mock/local services
config :elias_garden, :griffith_server,
  environment: :test,
  debug_mode: false,
  log_level: :warn,
  
  # Local test configuration
  host: "localhost",
  ip_address: "127.0.0.1",
  node_name: "test@localhost",
  remote_path: "/tmp/elias_test",
  service_name: "elias-garden-test",
  
  # Disable deployment features in test
  systemd_enabled: false,
  auto_start: false,
  
  # Fast test sync
  sync: [
    rsync_options: ["--archive", "--delete"],
    exclude_patterns: [".git", "_build", "deps"],
    checksum_validation: false
  ]

# Phoenix endpoint (if applicable) - test settings
if Code.ensure_loaded?(Phoenix) do
  config :elias_garden, ELIASWeb.Endpoint,
    http: [port: 4002],
    server: false
end

# Database configuration (if applicable) - test settings
if Code.ensure_loaded?(Ecto) do
  config :elias_garden, ELIAS.Repo,
    username: "postgres",
    password: "postgres",
    database: "elias_garden_test#{System.get_env("MIX_TEST_PARTITION")}",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 1
end

# ExUnit configuration for async testing
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 1_000