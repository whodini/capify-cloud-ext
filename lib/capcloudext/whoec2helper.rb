require 'rubygems'
require 'fog'
require 'colored'

class Ec2Helper
  attr_reader :client

  def initialize(options={})
    options[:provider] = 'AWS'
    options[:region] = options.delete(:aws_region)
    @client = Fog::Compute.new options
    @groups = Hash.new
    @client.servers.each do |server|
      group = server.tags['group']
      next if group.nil?
      @groups[group] = Array.new if !@groups.key? group
      @groups[group] << server
    end
  end

  #
  # Gets the list of all the instances.
  #
  # @return [Array] List of all the instances
  def get_instances
    all_instances = Array.new()
    @groups.values.each do |instances|
      instances.each do |instance|
        all_instances << instance
      end
    end
    all_instances
  end

  #
  # Gets the instances by role of a specific group.
  # @param  group [String] group name for which instances needs to be fetched.
  # @param  role [type] role of the instances
  #
  # @return [Array] List of all the instances with matching group and role.
  def get_instances_by_role(group, role)
    get_instances(group).select do |instance|
      if not instance.tags['role'].nil? and instance.ready?
        instance.tags.fetch('role', '').split(',').include? role
      end
    end
  end

  #
  # Prints all the meta data of the running instances.
  # @param  only_running=true [Boolean] setting to control all vs running instances details
  #
  def print_instances_details(only_running=true)
    @groups.values.each_with_index do |instances, i|
      instances.each do |instance|
        if only_running and (not instance.ready?)
          next
        end
        puts sprintf "%02d:  %-20s  %-20s %-20s  %-20s  %-25s  %-20s  (%s)  (%s) (%s)",
          i, (instance.tags["Name"] || "").green,instance.private_dns_name ,instance.id.red, instance.flavor_id.cyan,
          instance.dns_name.blue, instance.availability_zone.magenta, (instance.tags["role"] || "").yellow,
          (instance.tags["group"] || "").yellow, (instance.tags["app"] || "").green
      end
    end
  end

  #
  # Gets an instance by DNS name
  # @param  dns_name [String] Public DNS name of the instance
  #
  # @return [Fog::AWS::EC2::Instance] Instance matching the dns name
  def get_instance_by_dns_name(dns_name)
    @groups.each_value { |instances|
      instances.each do |instance|
        if instance.dns_name == dns_name
          return instance
        end
      end
    }
    raise "unknown dns name: #{dns_name}"
  end

  #
  # Gets the instances of a specific group
  # @param  group [String] group name for which instances needs to be fetched.
  #
  # @return [Array] List of all the instances of the group.
  def get_instances(group)
    raise "unknown group: #{group}" if !@groups.key? group
    @groups[group].dup
  end

  #
  # Gets the running instances of a specific group
  # @param  group [String] group name for which instances needs to be fetched.
  #
  # @return [Array] List of all the instances of the group.
  def get_running_instances(group)
    get_instances(group).select{ |instance| instance.ready? }
  end

  #
  # Gets an instance by name of a specific group
  # @param  group [String] group name to which instance belongs
  # @param  name [String] name of the instance
  #
  # @return [Fog::AWS::EC2::Instance] Instance matching the name and the group
  def get_instance_by_name(group, name)
    get_instances(group).each {|instance|
      return instance if (instance.tags['name_s'] || "").casecmp(name) == 0
      return instance if (instance.tags['Name'] || "").casecmp(name) == 0
    }
    raise "unknown instance: #{name} in group #{group} "
  end

  #
  # Adds the tags to the instance specified.
  # @param  instance [Fog::AWS::EC2::Instance] instance for which tags needs to be added
  # @param  tags = {} [Hash] hash map of tags
  #
  # @return [Hash] Hash of added tags
  def add_tags(instance, tags = {})
    tags.each { |key, value|
      @fog.tags.create(:resource_id => instance.id, :key => key, :value => value)
    }
  end

  def get_all_instances
    return @instances
  end

  def lb_unregister_instances(lb_name, instances)
    lb = get_lb(lb_name)
    lb.deregister_instances(instances.map{|i| i.id })
  end

  def lb_register_instances(lb_name, instances)
    lb = get_lb(lb_name)
    lb.register_instances(instances.map{|i| i.id })
  end

  def get_groups
    @groups.keys
  end

  def get_groups_byapp(app)
    groups = Set.new
    get_all_instances().each { |instance|
      group = instance.tags['group']
      groups << group if not group.nil? and instance.tags["app"] == app
    }
    return groups
  end

  private
  def get_lb(lb_name)
    @lbs ||= Fog::AWS::ELB.new(@cloud_config).load_balancers
    lb = @lbs.get(lb_name)
    raise "lb #{lb_name} not found in the region #{@cloud_config[:region]}" if lb.nil?
    return lb
  end

  #Not used anywhere...I just kept this code to check the instance properties to access block_device_mapping
  def get_server_details_map(isrunning)
    servers={}
    get_instances().each { |instance|
      if not isrunning or (isrunning and instance.ready?)
        details={}
        details['name']=instance.tags['name_s']
        details['orgid']=instance.tags['orgid']
        details['group']=instance.tags['group']
        details['private_dns_name'] = instance.private_dns_name
        details['role']	= instance.tags['role']
        details['public_dns_name'] = instance.dns_name
        details['id'] = instance.id
        details['zone'] = instance.availability_zone
        details['device_mappings'] = Array.new
        instance.block_device_mapping.each { |mapping|
          details['device_mappings'] << mapping['deviceName']
        }
        servers[instance.private_dns_name] = details
      end
    }
    return servers
  end
end
