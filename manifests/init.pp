#####################################################
# factotum class
#####################################################

class factotum inherits verdi {

  #####################################################
  # disable transparent hugepages for redis
  #####################################################

  file { "/etc/tuned/no-thp":
    ensure  => directory,
    mode    => 0755,
  }


  file { "/etc/tuned/no-thp/tuned.conf":
    ensure  => present,
    content => template('factotum/tuned.conf'),
    mode    => 0644,
    require => File["/etc/tuned/no-thp"],
  }


  exec { "no-thp":
    unless  => "grep -q -e '^no-thp$' /etc/tuned/active_profile",
    path    => ["/sbin", "/bin", "/usr/bin"],
    command => "tuned-adm profile no-thp",
    require => File["/etc/tuned/no-thp/tuned.conf"],
  }


  #####################################################
  # install redis
  #####################################################

  package { "redis":
    ensure   => present,
    notify   => Exec['ldconfig'],
    require => Exec["no-thp"],
  }


  file { '/etc/redis.conf':
    ensure       => file,
    content      => template('factotum/redis.conf'),
    mode         => 0644,
    require      => Package['redis'],
  }


  service { 'redis':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
                   File['/etc/redis.conf'],
                   Exec['daemon-reload'],
                  ],
  }


  #####################################################
  # override firewalld config from verdi and add redis
  #####################################################

  Firewalld::Zone["public"] {
    services => [ "ssh", "dhcpv6-client", "http", "https" ],
    ports => [
      {
        # work_dir dav server
        port     => "8085",
        protocol => "tcp",
      },
      {
        # work_dir tsunamid (tcp)
        port     => "46224",
        protocol => "tcp",
      },
      {
        # work_dir tsunamid (udp)
        port     => "46224",
        protocol => "udp",
      },
      {
        # Redis
        port     => "6379",
        protocol => "tcp",
      },
    ]
  }


  #firewalld::service { 'dummy':
  #  description	=> 'My dummy service',
  #  ports       => [{port => '1234', protocol => 'tcp',},],
  #  modules     => ['some_module_to_load'],
  #  destination	=> {ipv4 => '224.0.0.251', ipv6 => 'ff02::fb'},
  #}


}
