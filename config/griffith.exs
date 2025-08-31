# Griffith Server Configuration
# Production deployment configuration for ELIAS distributed nodes

import Config

# Griffith Server Details
config :elias_garden, :griffith_server,
  # Server Connection Details
  host: System.get_env("GRIFFITH_HOST") || "griffith.local",
  ip_address: System.get_env("GRIFFITH_IP") || "172.20.35.144", 
  ssh_port: String.to_integer(System.get_env("GRIFFITH_SSH_PORT") || "22"),
  user: System.get_env("GRIFFITH_USER") || "mikesimka",
  
  # Node Configuration
  node_name: System.get_env("GRIFFITH_NODE") || "elias@griffith.local",
  cookie_file: System.get_env("GRIFFITH_COOKIE") || "/opt/elias/.erlang.cookie",
  
  # Deployment Paths
  remote_path: System.get_env("GRIFFITH_PATH") || "/opt/elias_garden_elixir",
  backup_path: System.get_env("GRIFFITH_BACKUP") || "/home/mikesimka/backups/elias_garden_elixir",
  log_path: System.get_env("GRIFFITH_LOGS") || "/var/log/elias",
  
  # Service Configuration
  service_name: "elias-garden",
  systemd_enabled: true,
  auto_start: true,
  
  # Resource Limits
  memory_limit: "4G",
  cpu_limit: "2.0",
  disk_limit: "20G",
  
  # Network Configuration
  epmd_port: 4369,
  distribution_port_range: {49152, 65535},
  firewall_enabled: true,
  
  # Security Configuration
  ssl_enabled: true,
  encryption_at_rest: true,
  audit_logging: true,
  
  # Monitoring Configuration
  health_check_interval: 30_000, # 30 seconds
  metrics_enabled: true,
  log_rotation_enabled: true,
  max_log_files: 30

# Environment-specific overrides
config :elias_garden, :griffith_deployment,
  # Production environment settings
  production: [
    log_level: :info,
    debug_mode: false,
    performance_monitoring: true,
    resource_monitoring: true,
    security_hardening: true
  ],
  
  # Development/testing settings
  development: [
    log_level: :debug,
    debug_mode: true,
    performance_monitoring: false,
    resource_monitoring: false,
    security_hardening: false
  ]

# Federation Network Configuration
config :elias_garden, :federation_network,
  # Distributed node network topology
  nodes: [
    # Primary nodes
    {:griffith, "elias@griffith.local", "172.20.35.144"},
    {:gracey, "elias@gracey.local", "192.168.1.100"},
    
    # Additional federation nodes (for future expansion)
    # {:aurora, "elias@aurora.local", "10.0.0.100"},
    # {:phoenix, "elias@phoenix.local", "10.0.0.101"}
  ],
  
  # Network reliability settings
  heartbeat_interval: 5_000,
  connection_timeout: 30_000,
  retry_attempts: 3,
  failover_enabled: true

# Sync Configuration
config :elias_garden, :sync,
  # Rsync settings
  rsync_options: [
    "--archive",          # Archive mode (preserves permissions, times, etc.)
    "--verbose",          # Verbose output
    "--compress",         # Compress data during transfer
    "--delete",           # Delete files on destination that don't exist in source
    "--progress",         # Show progress
    "--partial",          # Keep partially transferred files
    "--timeout=300"       # 5 minute timeout
  ],
  
  # Exclusion patterns
  exclude_patterns: [
    ".git",
    "_build",
    "deps", 
    "*.beam",
    ".elixir_ls",
    "node_modules",
    "__pycache__",
    "*.log",
    ".DS_Store",
    "tmp",
    ".env*"
  ],
  
  # Sync validation
  checksum_validation: true,
  integrity_checks: true,
  post_sync_validation: true

# Deployment Orchestration
config :elias_garden, :deployment,
  # Deployment pipeline stages
  stages: [
    :pre_deployment_checks,
    :system_preparation,
    :code_deployment,
    :dependency_installation,
    :configuration_setup,
    :service_installation,
    :health_validation,
    :post_deployment_verification
  ],
  
  # Rollback configuration
  rollback_enabled: true,
  rollback_retention: 5,  # Keep 5 previous versions
  automatic_rollback_on_failure: true,
  
  # Maintenance windows
  maintenance_windows: [
    # Weekly maintenance window (Sunday 2 AM UTC)
    %{day: :sunday, hour: 2, duration_hours: 2},
    # Emergency maintenance (any time with approval)
    %{emergency: true, approval_required: true}
  ]

# Performance Tuning
config :elias_garden, :performance,
  # Erlang VM settings
  vm_args: [
    "+pc unicode",        # Unicode support
    "+P 1048576",        # Max processes
    "+K true",           # Kernel polling
    "+A 64",             # Async threads
    "+Q 65536",          # Max ports
    "+zdbbl 8192"        # Distributed buffer busy limit
  ],
  
  # Memory management
  memory_management: [
    garbage_collection: :generational,
    heap_size_initial: "64MB",
    heap_size_max: "2GB",
    binary_virtual_heap_size: "256MB"
  ],
  
  # I/O optimization  
  io_optimization: [
    read_ahead_size: "64KB",
    write_buffer_size: "1MB",
    max_concurrent_ios: 128
  ]

# Security Configuration
config :elias_garden, :security,
  # Authentication
  authentication: [
    method: :certificate,
    certificate_path: "/etc/elias/certs",
    key_rotation_days: 90,
    strong_passwords: true
  ],
  
  # Authorization
  authorization: [
    rbac_enabled: true,
    default_permissions: :readonly,
    admin_users: ["mikesimka"],
    audit_all_actions: true
  ],
  
  # Network security
  network_security: [
    tls_version: "1.3",
    cipher_suites: :strong,
    firewall_rules: :strict,
    intrusion_detection: true
  ],
  
  # Data protection
  data_protection: [
    encryption_at_rest: :aes256,
    encryption_in_transit: :mandatory,
    backup_encryption: true,
    key_management: :hardware_security_module
  ]

# Monitoring and Alerting
config :elias_garden, :monitoring,
  # System metrics
  system_metrics: [
    cpu_usage: true,
    memory_usage: true,
    disk_usage: true,
    network_io: true,
    process_count: true
  ],
  
  # Application metrics
  application_metrics: [
    response_times: true,
    error_rates: true,
    throughput: true,
    active_connections: true,
    message_queue_lengths: true
  ],
  
  # Health checks
  health_checks: [
    database_connectivity: true,
    external_service_health: true,
    memory_leaks: true,
    performance_degradation: true
  ],
  
  # Alerting thresholds
  alert_thresholds: [
    cpu_usage: 80,           # CPU usage > 80%
    memory_usage: 85,        # Memory usage > 85%
    disk_usage: 90,          # Disk usage > 90%
    response_time: 1000,     # Response time > 1 second
    error_rate: 5            # Error rate > 5%
  ],
  
  # Alert destinations
  alert_destinations: [
    email: System.get_env("ALERT_EMAIL") || "admin@elias.local",
    slack_webhook: System.get_env("SLACK_WEBHOOK"),
    pagerduty_key: System.get_env("PAGERDUTY_KEY")
  ]

# Backup Configuration
config :elias_garden, :backup,
  # Backup strategy
  strategy: :continuous_incremental,
  retention_policy: [
    hourly: 24,    # Keep 24 hourly backups
    daily: 30,     # Keep 30 daily backups  
    weekly: 12,    # Keep 12 weekly backups
    monthly: 12    # Keep 12 monthly backups
  ],
  
  # Backup destinations
  destinations: [
    local: "/var/backups/elias",
    remote: "backup-server:/backups/elias",
    cloud: System.get_env("CLOUD_BACKUP_URL")
  ],
  
  # Backup validation
  integrity_verification: true,
  restoration_testing: :weekly,
  encryption_enabled: true,
  compression_enabled: true