class ocf_mirrors::centos {
  file { '/opt/mirrors/project/centos':
    ensure  => directory,
    source  => 'puppet:///modules/ocf_mirrors/project/centos/',
    owner   => mirrors,
    group   => mirrors,
    mode    => '0755',
    recurse => true,
  }

  ocf_mirrors::monitoring {
    'centos':
      type          => 'unix_timestamp',
      upstream_host => 'mirror.centos.org',
      ts_path       => 'TIME';
  }

  cron {
    'centos':
      command => '/opt/mirrors/project/centos/sync-archive > /dev/null',
      user    => 'mirrors',
      hour    => '*/3',
      minute  => '22';
  }
}
