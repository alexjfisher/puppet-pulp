Facter.add(:pulp_consumer_id) do
  confine kernel: 'Linux'
  setcode do
    pulp_consumer_id = nil
    status = Facter::Util::Resolution.exec('pulp-consumer status')
    unless status.nil?
      # Strip color from command output
      status.gsub!(/\e\[([;\d]+)?m/, '')
      captures = /^This consumer is registered to the server\s\[(.*)\]\swith\sthe\sID\s\[(.*)\]\.$/.match(status)
      pulp_consumer_id = captures[1] unless captures.nil?
    end
    pulp_consumer_id
  end
end
