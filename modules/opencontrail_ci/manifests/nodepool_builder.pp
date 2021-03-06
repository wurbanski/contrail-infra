class opencontrail_ci::nodepool_builder(
  $cloud_credentials = $::opencontrail_ci::params::cloud_credentials,
  $statsd_host       = $::nodepool::statsd_host,
  $rhel_reg_method   = $::opencontrail_ci::nodepool_builder::rhel_reg_method,
  $rhel_username     = $::opencontrail_ci::nodepool_builder::rhel_username,
  $rhel_password     = $::opencontrail_ci::nodepool_builder::rhel_password,
  $rhel_local_image  = $::opencontrail_ci::nodepool_builder::rhel_local_image,
  $rhel_pool_id      = $::opencontrail_ci::nodepool_builder::rhel_pool_id
) inherits opencontrail_ci::params {

  if ! defined(Class['project_config']) {
    class { '::project_config':
      url      =>  $::opencontrail_ci::params::project_config_repo,
      revision =>  'master',
    }
  }

  class { '::nodepool':
    install_mysql => true,
    require       => Class['project_config'],
  }

  class { '::nodepool::builder':
    statsd_host => $statsd_host,
  }

  file { '/home/nodepool/.config':
    ensure  => directory,
    owner   => 'nodepool',
    group   => 'nodepool',
    require => [
      User['nodepool'],
      ],
  }

  file { '/home/nodepool/.ssh/zuul-executor.pub':
    ensure  => present,
    owner   => 'nodepool',
    group   => 'nodepool',
    content => hiera('zuul_ssh_public_key'),
    require => File['/home/nodepool/.ssh/'],
  }

  file { '/home/nodepool/.config/openstack':
    ensure  => directory,
    owner   => 'nodepool',
    group   => 'nodepool',
    require => [
      File['/home/nodepool/.config'],
      ],
  }

  file { '/home/nodepool/.config/openstack/clouds.yaml':
    ensure  => present,
    owner   => 'nodepool',
    group   => 'nodepool',
    mode    => '0400',
    content => template('opencontrail_ci/nodepool/clouds.yaml.erb'),
    require => File['/home/nodepool/.config'],
  }

  file { '/opt/cloud_images':
    ensure  => directory,
    owner   => 'nodepool',
    group   => 'nodepool',
    require => [
      User['nodepool'],
      ],
  }

  file { '/opt/nodepool-inject-secrets.py':
    source => 'puppet:///modules/opencontrail_ci/nodepool-inject-secrets.py',
    owner  => 'root',
    group  => 'root',
  }

  exec {'nodepool-inject-secrets':
    command     => 'python /opt/nodepool-inject-secrets.py /etc/nodepool/nodepool.yaml.tmpl rhel-7 > /etc/nodepool/nodepool.yaml',
    environment => [
      "INJECT_REG_USER=${rhel_username}",
      "INJECT_REG_PASSWORD=${rhel_password}",
      "INJECT_REG_POOL_ID=${rhel_pool_id}",
      "INJECT_DIB_LOCAL_IMAGE=${rhel_local_image}",
      "INJECT_REG_METHOD=${rhel_reg_method}",
      ],
    path        => '/usr/bin',
    logoutput   => false,
    require     => File['/opt/nodepool-inject-secrets.py'],
  }

  file { '/etc/nodepool/nodepool.yaml.tmpl':
    ensure  => present,
    source  => $::project_config::nodepool_config_file,
    owner   => 'nodepool',
    group   => 'root',
    mode    => '0400',
    require => [
      File['/etc/nodepool'],
      User['nodepool'],
      Class['project_config'],
      ],
    notify  => Exec['nodepool-inject-secrets'],
  }
}
