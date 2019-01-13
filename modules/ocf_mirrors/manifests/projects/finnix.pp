class ocf_mirrors::projects::finnix {
  file {
    default:
      owner => mirrors,
      group => mirrors;

    '/opt/mirrors/project/finnix':
      ensure => directory,
      mode   => '0755';

    '/opt/mirrors/project/finnix/sync-releases':
      source => 'puppet:///modules/ocf_mirrors/project/finnix/sync-releases',
      mode   => '0755';

    # we are registered with the Finnix project and have a password for the
    # master upstream mirror
    '/opt/mirrors/project/finnix/password':
      source    => 'puppet:///private/mirrors/finnix',
      mode      => '0600',
      show_diff => false;
  }

  ocf_mirrors::timer { 'finnix':
    exec_start => '/opt/mirrors/project/finnix/sync-releases',
    minute     => '41',
  }
}
