Puppet::Type.type(:pulp_rpmbind).provide(:consumer) do
  desc 'Bind/unbind to an RPM repo'

  confine osfamily: :redhat
  commands consumer: '/bin/pulp-consumer'
  commands grep:     '/bin/grep'

  def self.instances
    begin
      binds = grep('-oP', '^\[\K.*(?=\]$)', '/etc/yum.repos.d/pulp.repo')
    rescue Puppet::ExecutionFailure => e
      Puppet.debug "grepping for binds had an error -> #{e.inspect}"
      return {}
    end
    binds.split("\n").collect do |line|
      new(name: line, ensure: :present)
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    consumer('rpm', 'bind', '--repo-id', @resource[:name])
    @property_hash[:ensure] = :present
  end

  def destroy
    consumer('rpm', 'unbind', '--repo-id', @resource[:name])
    @property_hash[:ensure] = :absent
  end
end
