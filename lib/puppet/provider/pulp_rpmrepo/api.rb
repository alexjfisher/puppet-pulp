require File.expand_path('../../../util/pulp_util', __FILE__)

Puppet::Type.type(:pulp_rpmrepo).provide(:api) do
  commands :pulp_admin => '/usr/bin/pulp-admin'

  mk_resource_methods

  # special getter methods for parameters that receive a file and write the content
  [:feed_ca_cert,
    :feed_cert,
    :feed_key,
    :gpg_key,
    :host_ca,
    :auth_ca,
    :auth_cert,].each do |method|
    method = method.to_sym
    define_method method do
      if resource[method] && File.read(resource[method]) == @property_hash[method]
        resource[method]
      else
        nil
      end
    end
  end

  # this gets called for each resource
  def initialize(resource={})
    super(resource)
    @property_flush = {}
  end

  def sym_to_bool(sym)
    if sym == :true
      true
    elsif sym == :false
      false
    else
      sym
    end
  end

  def hash_to_params(params_hash)
    param = nil
    params = []
    params_hash.each { |k, v|
      if ! (v.nil?)
        if v.kind_of?(Array)
          param = [k, v.join(',')]
        elsif v.kind_of?(Hash)
          v.to_a.each { |pair|
            param << [k, pair.join('=')]
          }
        else
          param = [k, sym_to_bool(v)]
        end
        params << param
      end
    }
    params
  end

  def self.get_resource_properties(repo_id)
    hash = {}

    repo = @pulp.get_repo_info(repo_id)
    if !repo
      hash[:ensure] = :absent
      return
    end

    hash[:display_name] = repo['display_name']
    hash[:description] = repo['description']
    hash[:note] = repo['notes']
    hash[:note].delete('_repo-type')

    repo['distributors'].each { |distributor|
      if distributor['id'] == 'yum_distributor'
        hash[:auth_ca]                  = distributor['config']['auth_ca']
        hash[:auth_cert]                = distributor['config']['auth_cert']
        hash[:checksum_type]            = distributor['config']['checksum_type']
        hash[:generate_sqlite]          = distributor['config']['generate_sqlite'] ? :true : :false
        hash[:gpg_key]                  = distributor['config']['gpgkey']
        hash[:host_ca]                  = distributor['config']['https_ca']
        hash[:relative_url]             = distributor['config']['relative_url']
        hash[:repoview]                 = distributor['config']['repoview'] || ''
        hash[:serve_http]               = distributor['config']['http'] ? :true : :false
        hash[:serve_https]              = distributor['config']['https'] ? :true : :false
        hash[:updateinfo_checksum_type] = distributor['config']['updateinfo_checksum_type'] || ''
      end
    }

    repo['importers'].each { |importer|
      if importer['id'] == 'yum_importer'
        hash[:basicauth_pass]    = importer['config']['basic_auth_password'] || ''
        hash[:basicauth_user]    = importer['config']['basic_auth_username'] || ''
        hash[:download_policy]   = importer['config']['download_policy']
        hash[:allowed_keys]      = importer['config']['allowed_keys'] || ''
        hash[:require_signature] = importer['config']['require_signature'] || ''
        hash[:feed]              = importer['config']['feed'] || ''
        hash[:validate]          = importer['config']['validate'] ? :true : :false
        hash[:skip]              = importer['config']['type_skip_list']
        hash[:feed_ca_cert]      = importer['config']['ssl_ca_cert']
        hash[:verify_feed_ssl]   = importer['config']['ssl_validation'] ? :true : :false
        hash[:feed_cert]         = importer['config']['ssl_client_cert']
        hash[:feed_key]          = importer['config']['ssl_client_key']
        hash[:proxy_host]        = importer['config']['proxy_host']
        hash[:proxy_port]        = importer['config']['proxy_port']
        hash[:proxy_user]        = importer['config']['proxy_username']
        hash[:proxy_pass]        = importer['config']['proxy_password']
        hash[:max_downloads]     = importer['config']['max_downloads']
        hash[:max_speed]         = importer['config']['max_speed']
        hash[:remove_missing]    = importer['config']['remove_missing'] ? :true : :false
        hash[:retain_old_count]  = importer['config']['retain_old_count']
      end
    }

    hash[:name] = repo_id
    hash[:ensure] = :present
    hash[:provider] = :pulp_rpmrepo

    Puppet.debug "Repo properties: #{hash.inspect}"

    hash
  end

  def self.instances
    all=[]
    @pulp = Puppet::Util::PulpUtil.new
    @pulp.get_repos.each { |repo|
      next if repo['notes']['_repo-type'] != 'rpm-repo'
      hash_properties = get_resource_properties(repo['id'])
      all << new(hash_properties)
    }
    all
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  # iterates through the array of resources returned by self.instances
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def set_repo
    params_hash = {
      '--allowed-keys'             => resource[:allowed_keys],
      '--auth-ca'                  => resource[:auth_ca],
      '--auth-cert'                => resource[:auth_cert],
      '--basicauth-pass'           => resource[:basicauth_pass],
      '--basicauth-user'           => resource[:basicauth_user],
      '--checksum-type'            => resource[:checksum_type],
      '--description'              => resource[:description],
      '--display-name'             => resource[:display_name],
      '--download-policy'          => resource[:download_policy],
      '--feed'                     => resource[:feed],
      '--feed-ca-cert'             => resource[:feed_ca_cert],
      '--feed-cert'                => resource[:feed_cert],
      '--feed-key'                 => resource[:feed_key],
      '--generate-sqlite'          => resource[:generate_sqlite],
      '--gpg-key'                  => resource[:gpg_key],
      '--host-ca'                  => resource[:host_ca],
      '--max-downloads'            => resource[:max_downloads],
      '--max-speed'                => resource[:max_speed],
      '--note'                     => resource[:note],
      '--proxy-host'               => resource[:proxy_host],
      '--proxy-pass'               => resource[:proxy_pass],
      '--proxy-port'               => resource[:proxy_port],
      '--proxy-user'               => resource[:proxy_user],
      '--relative-url'             => resource[:relative_url],
      '--remove-missing'           => resource[:remove_missing],
      '--repoview'                 => resource[:repoview],
      '--require-signature'        => resource[:require_signature],
      '--retain-old-count'         => resource[:retain_old_count],
      '--serve-http'               => resource[:serve_http],
      '--serve-https'              => resource[:serve_https],
      '--skip'                     => resource[:skip],
      '--updateinfo_checksum_type' => resource[:updateinfo_checksum_type],
      '--validate'                 => resource[:validate],
      '--verify-feed-ssl'          => resource[:verify_feed_ssl],
    }

    params= []

    if @property_flush[:ensure] == :absent
      # delete
      action = 'delete'
    elsif @property_flush[:ensure] == :present
      # create
      action = 'create'
      params = hash_to_params(params_hash)
    else
      #update
      action = 'update'
      params = hash_to_params(params_hash)
    end

    arr = ['rpm', 'repo', action, '--repo-id', resource[:name], params]
    pulp_admin(arr.flatten)
  end

  def flush
    set_repo

    # Collect the resources again once they've been changed (that way `puppet
    # resource` will show the correct values after changes have been made).
    @property_hash = self.class.get_resource_properties(resource[:name])
  end

end
