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
  # tune kernel for high performance redis
  #####################################################

  file { "/usr/lib/sysctl.d":
    ensure  => directory,
    mode    => 0755,
  }


  file { "/usr/lib/sysctl.d/redis.conf":
    ensure  => present,
    content => template('factotum/redis.conf.sysctl'),
    mode    => 0644,
    require => File["/usr/lib/sysctl.d"],
  }


  exec { "sysctl-system":
    path    => ["/sbin", "/bin", "/usr/bin"],
    command => "/sbin/sysctl --system",
    require => File["/usr/lib/sysctl.d/redis.conf"],
  }


  #####################################################
  # install postfix
  #####################################################

  package { "postfix":
    ensure   => present,
    notify   => Exec['ldconfig'],
  }


  file { '/etc/postfix/main.cf':
    ensure       => file,
    content      => template('factotum/main.cf'),
    mode         => 0644,
    require      => Package['postfix'],
  }


  service { 'postfix':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
                   File['/etc/postfix/main.cf'],
                   Exec['daemon-reload'],
                  ],
  }


  #####################################################
  # install redis
  #####################################################

  package { "redis":
    ensure   => present,
    notify   => Exec['ldconfig'],
    require => [
                Exec["no-thp"],
                Exec["sysctl-system"],
               ],
  }


  file { '/etc/redis.conf':
    ensure       => file,
    content      => template('factotum/redis.conf'),
    mode         => 0644,
    require      => Package['redis'],
  }


  file { ["/etc/systemd/system/redis.service.d",
         "/etc/systemd/system/redis-sentinel.service.d"]:
    ensure  => directory,
    mode    => 0755,
  }


  file { "/etc/systemd/system/redis.service.d/limit.conf":
    ensure  => present,
    content => template('factotum/redis_service.conf'),
    mode    => 0644,
    require => File["/etc/systemd/system/redis.service.d"],
  }


  file { "/etc/systemd/system/redis-sentinel.service.d/limit.conf":
    ensure  => present,
    content => template('factotum/redis_service.conf'),
    mode    => 0644,
    require => File["/etc/systemd/system/redis-sentinel.service.d"],
  }


  service { 'redis':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
                   File['/etc/redis.conf'],
                   File['/etc/systemd/system/redis.service.d/limit.conf'],
                   File['/etc/systemd/system/redis-sentinel.service.d/limit.conf'],
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
        # smtp
        port     => "25",
        protocol => "tcp",
      },
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
