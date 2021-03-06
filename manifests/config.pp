# Pulp Master Configuration
# @api private
class pulp::config {
  file { '/var/lib/pulp/packages':
    ensure => directory,
    owner  => 'apache',
    group  => 'apache',
    mode   => '0755',
  }

  file { '/etc/pulp/server.conf':
    ensure    => file,
    content   => template('pulp/server.conf.erb'),
    owner     => 'apache',
    group     => 'apache',
    mode      => '0600',
    show_diff => $pulp::show_conf_diff,
  }

  file { '/etc/pki/pulp/content':
    ensure => directory,
    owner  => 'apache',
    group  => 'apache',
    mode   => '0755',
  }

  file { '/etc/pki/pulp/content/pulp-global-repo.ca':
    ensure => link,
    target => $pulp::ca_cert,
  }

  if $pulp::enable_deb or $pulp::enable_ostree or $pulp::enable_rpm or $pulp::enable_iso {
    file { '/etc/pulp/repo_auth.conf':
      ensure  => file,
      content => template('pulp/repo_auth.conf.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }
  }

  if $pulp::enable_deb {
    file { '/etc/pulp/server/plugins.conf.d/deb_importer.json':
      ensure    => file,
      content   => template('pulp/deb_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  if $pulp::enable_rpm {
    file { '/etc/pulp/server/plugins.conf.d/yum_importer.json':
      ensure    => file,
      content   => template('pulp/yum_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  if $pulp::enable_iso {
    file { '/etc/pulp/server/plugins.conf.d/iso_importer.json':
      ensure    => file,
      content   => template('pulp/iso_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  if $pulp::enable_docker {
    file { '/etc/pulp/server/plugins.conf.d/docker_importer.json':
      ensure    => file,
      content   => template('pulp/docker_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  if $pulp::enable_ostree {
    file { '/etc/pulp/server/plugins.conf.d/ostree_importer.json':
      ensure    => file,
      content   => template('pulp/ostree_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  if $pulp::enable_puppet {
    if $facts['os']['selinux']['enabled'] {
      selboolean { 'pulp_manage_puppet':
        persistent => true,
        value      => 'on',
      }
    }

    file { '/etc/pulp/server/plugins.conf.d/puppet_importer.json':
      ensure    => file,
      content   => template('pulp/puppet_importer.json.erb'),
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      show_diff => $pulp::show_conf_diff,
    }
  }

  file { '/etc/default/pulp_workers':
    ensure  => file,
    content => template('pulp/systemd_pulp_workers'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  exec { '/usr/bin/pulp-gen-key-pair':
    creates => $pulp::rsa_key,
  } ->
  file { $pulp::rsa_key:
    owner => 'root',
    group => 'apache',
    mode  => '0640',
  }

  if $pulp::reset_cache {
    exec { 'reset_pulp_cache':
      command => 'rm -rf /var/lib/pulp/packages/*',
      path    => '/sbin:/bin:/usr/bin',
      before  => Exec['migrate_pulp_db'],
      require => File['/var/lib/pulp/packages'],
    }
  }

  if $pulp::consumers_crl {
    exec { 'setup-crl-symlink':
      command     => "/usr/bin/openssl x509 -in '${pulp::ca_cert}' -hash -noout | /usr/bin/xargs -I{} /bin/ln -sf '${pulp::consumers_crl}' '/etc/pki/pulp/content/{}.r0'",
      logoutput   => 'on_failure',
      refreshonly => true,
    }
  }

  exec { 'run pulp-gen-ca':
    command => '/usr/bin/pulp-gen-ca-certificate',
    creates => $pulp::ca_cert,
    require => File['/etc/pulp/server.conf'],
  }

  if $pulp::manage_squid {
    contain pulp::squid
  }

  if $pulp::enable_profiling {
    file { $pulp::profiling_directory:
      ensure => directory,
      owner  => 'apache',
      group  => 'apache',
      mode   => '0755',
    }
  }
}
