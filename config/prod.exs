# Production configuration for ELIAS Garden

import Config

# Production logging
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Production system settings
config :elias_garden,
  # Performance optimizations
  max_concurrent_requests: 5000,
  request_timeout: 10_000,
  pool_size: 100,
  
  # Security hardening
  security_mode: :strict,
  ssl_required: true,
  audit_all_operations: true,
  
  # Resource limits
  memory_limit: "4GB",
  cpu_limit: "4.0",
  
  # Monitoring
  telemetry_enabled: true,
  metrics_export: true,
  health_checks: true,
  
  # Error handling
  crash_dump_enabled: true,
  error_tracking: :comprehensive

# Production Griffith overrides
config :elias_garden, :griffith_server,
  environment: :production,
  debug_mode: false,
  log_level: :info,
  performance_monitoring: true,
  security_hardening: true

# Phoenix endpoint (if applicable)
if Code.ensure_loaded?(Phoenix) do
  config :elias_garden, ELIASWeb.Endpoint,
    url: [host: "elias.production", port: 443, scheme: "https"],
    http: [port: 4000],
    https: [
      port: 4001,
      cipher_suite: :strong,
      keyfile: System.get_env("SSL_KEY_PATH"),
      certfile: System.get_env("SSL_CERT_PATH")
    ],
    server: true,
    root: ".",
    version: Application.spec(:phoenix_distillery, :vsn),
    cache_static_manifest: "priv/static/cache_manifest.json"
end

# Database configuration (if applicable)
if Code.ensure_loaded?(Ecto) do
  config :elias_garden, ELIAS.Repo,
    username: System.get_env("DATABASE_USER"),
    password: System.get_env("DATABASE_PASS"),
    database: System.get_env("DATABASE_NAME"),
    hostname: System.get_env("DATABASE_HOST"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true,
    ssl_opts: [verify: :verify_peer]
end