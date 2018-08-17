class ocf_filehost {
  package { ['quotatool', 'nfs-kernel-server']:; }

  $exports = join(['"',
    join([
      'admin(rw,fsid=0,no_subtree_check,no_root_squash)',
      'www(rw,fsid=0,no_subtree_check,root_squash)',
      'dev-www(rw,fsid=0,no_subtree_check,root_squash)',
      'ssh(rw,fsid=0,no_subtree_check,no_root_squash)',
      'dev-ssh(rw,fsid=0,no_subtree_check,no_root_squash)',
      'apphost(rw,fsid=0,no_subtree_check,no_root_squash)',
      'dev-apphost(rw,fsid=0,no_subtree_check,no_root_squash)',
    ], ','),
  '"'], '')

  zfs { 'tank/homes':
    ensure     => 'present',
    canmount   => 'on',
    mountpoint => '/home',
    sharenfs   => $exports;
  }

  zfs { 'tank/services':
    ensure     => 'present',
    canmount   => 'on',
    mountpoint => '/services',
    sharenfs   => $exports;
  }

  include ocf::firewall::nfs
}
