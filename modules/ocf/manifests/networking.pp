class ocf::networking(
    $bridge     = false,

    $ipaddress  = $::ipHostNumber,  # lint:ignore:variable_is_lowercase
    $netmask    = '255.255.255.0',
    $gateway    = '169.229.226.1',

    $ipaddress6 = regsubst($::ipHostNumber, '^(\d+)\.(\d+)\.(\d+)\.(\d+)$', '2607:f140:8801::1:\4'),  # lint:ignore:variable_is_lowercase
    $netmask6   = '64',
    $gateway6   = '2607:f140:8801::1',

    $domain      = 'ocf.berkeley.edu',
    $nameservers = ['2607:f140:8801::1:22', '169.229.226.22', '8.8.8.8'],
) {
  $fqdn = $::clientcert
  $hostname = regsubst($::clientcert, '^([\w-]+)\..*$', '\1')

  if size($nameservers) > 3 {
    fail("Can't have more than 3 nameservers")
  }

  # packages
  if $bridge {
    package { 'bridge-utils': }
  }

  package { 'resolvconf':
    ensure => purged,
  }

  if $::lsbdistcodename == 'jessie' {
    if $bridge {
      $iface = 'br0'
      $br_iface = 'eth0'
    } else {
      $iface = 'eth0'
    }
  } else {
    if $::lsbdistid == 'Raspbian' {
      # The raspberry pi has wifi, so we use that for networking
      $ifaces_array = split($::interfaces, ',')
      $br_iface = grep($ifaces_array, 'wl.+')[0]
    } else {
      $br_iface = $::iface_linked
    }

    # If using bridged networking, use the interface found above as the
    # interface being bridged to.
    if $bridge {
      $iface = 'br0'
    } else {
      if $br_iface and ($br_iface != '') {
        $iface = $br_iface
      } else {
        # This is the default ethernet interface name on new VMs. While not
        # necessarily correct, falling back will help make sure VMs upgraded
        # from jessie have networking configured when they reboot, since they
        # retain the old 'eth0' interface name until after reboot.
        #
        # TODO: find out how to predict new interface names
        $iface = 'ens3'
      }
    }
  }

  # network configuration
  file {
    '/etc/network/interfaces':
      content => template('ocf/networking/interfaces.erb');
    '/etc/hostname':
      content => "${hostname}\n";
    '/etc/hosts':
      content => template('ocf/networking/hosts.erb');
    '/etc/resolv.conf':
      content => template('ocf/networking/resolv.conf.erb'),
      require => Package['resolvconf'];
  }

  # Enable TCP BBR congestion control
  sysctl {
    'net.core.default_qdisc':
      value => 'fq';
    'net.ipv4.tcp_congestion_control':
      value => 'bbr';

  }

  # disable IPv6 - SLAAC doesn't work for us yet
  # https://moffle.fuqu.jp/ocf/%23rebuild/20181024#L123
  sysctl { 'net.ipv6.conf.all.autoconf':
    value => '0';
  }

  # Make sure these are absent so predictable network iface names get used
  file {
    [
      '/etc/udev/rules.d/70-persistent-net.rules',
      '/etc/udev/rules.d/75-persistent-net-generator.rules',
      '/etc/systemd/network/50-virtio-kernel-names.link',
      '/etc/systemd/network/99-default.link',
    ]:
      ensure => absent;
  }

  # firewall configuration
  if $bridge {
    # Docker 1.13+ sets the iptables policy for the FORWARD chain to DROP.
    # (See https://github.com/docker/docker/pull/28257). As a side effect,
    # that prevents VMs from talking to anyone other than the host over
    # IPv4.
    # To fix this, add explicit rules allowing forwarding on the bridge
    # interface used by VMs.

    # On hypervisors the ethernet interface and VM TAP interfaces are all
    # connected to $iface. Any packet traveling between VMs, or between a
    # VM and the internet, will have an input interface and output interface
    # of $iface. Any packet which doesn't have this property should not be
    # forwarded (unless allowed for by a different iptables rule).
    firewall_multi { '100 allow traffic to/from VMs':
      chain    => 'FORWARD',
      proto    => 'all',
      iniface  => $iface,
      outiface => $iface,
      action   => 'accept',
    }
  }
}
