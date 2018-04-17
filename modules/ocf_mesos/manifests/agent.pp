class ocf_mesos::agent($attributes = {}) {
  include ocf::packages::docker
  include ocf_mesos
  include ocf_mesos::package

  $masters = lookup('mesos_masters')
  $zookeeper_password = hiera('mesos::zookeeper::password')

  # TODO: can we not duplicate this between agent/master?
  # looks like: mesos0:2181,mesos1:2181,mesos2:2181
  $zookeeper_host = join(keys($masters).map |$m| { "${m}:2181" }, ',')
  $zookeeper_uri = "zk://ocf:${zookeeper_password}@${zookeeper_host}"

  file { '/opt/share/mesos/agent/zk':
    content   => "${zookeeper_uri}/mesos\n",
    mode      => '0400',
    show_diff => false,
    require   => Package['mesos'],
    notify    => Service['mesos-agent'],
  } ->
  augeas { '/etc/default/mesos-agent':
    lens    => 'Shellvars.lns',
    incl    => '/etc/default/mesos-agent',
    changes =>  [
      "set MASTER 'file:///opt/share/mesos/agent/zk'",
    ],
    notify  => Service['mesos-agent'],
    require => Package['mesos'];
  }


  $ocf_mesos_master_password = hiera('mesos::master::password')
  $ocf_mesos_agent_password = hiera('mesos::slave::password')

  file {
    default:
      notify  => Service['mesos-agent'],
      require => Package['mesos'];

    '/opt/share/mesos/agent':
      ensure => directory;

    '/etc/mesos-agent':
      ensure  => directory,
      recurse => true,
      purge   => true;

    '/etc/mesos-agent/containerizers':
      content => "docker,mesos\n",
      require => File['/etc/mesos-agent'];

    # increase executor timeout in case we need to pull a Docker image
    '/etc/mesos-agent/executor_registration_timeout':
      content => "5mins\n",
      require => File['/etc/mesos-agent'];

    # remove old dockers as soon as we're done with them
    '/etc/mesos-agent/docker_remove_delay':
      content => "1secs\n",
      require => File['/etc/mesos-agent'];

    '/etc/mesos-agent/hostname':
      content => "${::hostname}\n",
      require => File['/etc/mesos-agent'];

    # Credentials needed to access the agent REST API.
    [
      '/etc/mesos-agent/authenticate_http_readonly',
      '/etc/mesos-agent/authenticate_http_readwrite',
    ]:
      content => "true\n",
      require => File['/etc/mesos-agent'];

    '/etc/mesos-agent/image_providers':
      content => "docker\n",
      require => File['/etc/mesos-agent'];

    '/etc/mesos-agent/work_dir':
      content => "/var/lib/mesos-agent\n",
      require => File['/var/lib/mesos-agent', '/etc/mesos-agent'];

    '/var/lib/mesos-agent':
      ensure => directory;

    '/etc/mesos-agent/http_credentials':
      content => "/opt/share/mesos/agent/agent_credentials.json\n",
      require => File['/opt/share/mesos/agent/agent_credentials.json'];

    '/opt/share/mesos/agent/agent_credentials.json':
      content   => template('ocf_mesos/agent/mesos/agent_credentials.json.erb'),
      mode      => '0400',
      show_diff => false;

    # Credential to connect to the masters.
    '/etc/mesos-agent/credential':
      content => "/opt/share/mesos/agent/master_credential.json\n",
      require => File['/opt/share/mesos/agent/master_credential.json', '/etc/mesos-agent'];

    '/opt/share/mesos/agent/master_credential.json':
      content   => template('ocf_mesos/agent/agent/master_credential.json.erb'),
      mode      => '0400',
      show_diff => false;
  }

  # Enable Nvidia support on machines with Nvidia GPUs
  if $::gfx_brand == 'nvidia' {
    file {
      '/etc/mesos-agent/isolation':
        content => "docker/runtime,filesystem/linux,cgroups/devices,gpu/nvidia\n",
        require => File['/etc/mesos-agent'];
    }
  } else {
    file {
      '/etc/mesos-agent/isolation':
        content => "docker/runtime,filesystem/linux\n",
        require => File['/etc/mesos-agent'];
    }
  }

  concat { '/etc/mesos-agent/attributes':
    ensure         => present,
    ensure_newline => true,
    notify         => Exec['reset-agent'],
    require        => File['/etc/mesos-agent'],
  }

  # Provide a custom start script which enables wiping the agent settings.
  file { '/usr/local/bin/ocf-mesos-agent':
    source => 'puppet:///modules/ocf_mesos/agent/ocf-mesos-agent',
    mode   => '0755',
  }

  ocf::systemd::override { 'mesos-agent-change-start':
    unit    => 'mesos-agent.service',
    content => "[Service]\nExecStart=\nExecStart=/usr/local/bin/ocf-mesos-agent\n",
    require => File['/usr/local/bin/ocf-mesos-agent'],
  }

  # Some operations change the agent's "info" and require the entire agent to
  # be reset. These notify this exec.
  exec { 'reset-agent':
    command     => 'touch /var/lib/mesos-agent/reset-needed',
    refreshonly => true,
    notify      => Service['mesos-agent'],
  }

  # Custom attributes
  create_resources(ocf_mesos::agent::attribute, $attributes)
}
