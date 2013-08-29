require 'rubygems'
require 'fog'
require 'colored'

class Ec2Helper
	
       def initialize(region, cloud_config = "config/cloud.yml")
		@cloud_config = YAML.load_file cloud_config
		@instances =[]
		populate_instances(region, @cloud_config)
	end

	def populate_instances(region, config)
		#Choose the defualt prover and region
		raise "aws_access_key_id or aws_secret_access_key keys are not present in the config file" if config[:aws_access_key_id].nil? or config[:aws_secret_access_key].nil?
		temp_config = {:provider => 'AWS'}
		config[:region] = region
    		@fog = Fog::Compute.new(temp_config.merge!(config))
		@fog.servers.each {|server| @instances << server }
	end
		
	def get_instances_role(group, role)
		ret_instances = Array.new
		@instances.each {|instance|
			if not instance.tags['role'].nil? and instance.ready?
				unless instance.tags['role'].match(role).nil? or instance.tags['group'] != group
					ret_instances << instance
				end
			end
		}
		return ret_instances
	end
	
	def printInstanceDetails(only_running=true)
		 @instances.each_with_index do |instance, i|
			if only_running and (not instance.ready?)
				next
			end

			puts sprintf "%02d:  %-20s  %-20s %-20s  %-20s  %-25s  %-20s  (%s)  (%s) (%s)",
			i, (instance.tags["Name"] || "").green,instance.private_dns_name ,instance.id.red, instance.flavor_id.cyan,
			instance.dns_name.blue, instance.availability_zone.magenta, (instance.tags["role"] || "").yellow,
			(instance.tags["group"] || "").yellow, (instance.tags["app"] || "").green 
		 end

	end	

	def get_instance_by_pri_pub_dns(dns)
		@instances.each { |instance|
			if instance.private_dns_name == dns or instance.dns_name == dns
				return instance
			end
		}
	end

	def get_all_stacks
		stacks = {}
		@instances.each {|instance|
			instances = stacks[instance.tags['group']]
			if instances.nil?
				instances = Array.new
				stacks[instance.tags['group']] = instances
			end
			instances << instance
		}
		return stacks
	end

		
	def get_groups
		groups = Set.new
		@instances.each { |instance|
			group = instance.tags['group']
			groups.add(group) if not group.nil? 	
		}	
		return groups
	end

	def get_groups_byapp(app)
		groups = Set.new
		@instances.each { |instance|
			group = instance.tags['group']
			groups << group if not group.nil? and instance.tags["app"] == app	
		}	
		return groups
	end

	def get_instances(group)
		ret_instances = Array.new
		@instances.each { |instance|
			ret_instances << instance if instance.tags['group'] == group and instance.ready?
		}		
		return ret_instances
	end
	
	def get_instance_by_name(name)
		@instances.each {|instance|
			return instance if (instance.tags['name_s'] || "").casecmp(name) == 0
			return instance if (instance.tags['Name'] || "").casecmp(name) == 0
		}
		return nil
	end

	def add_tags(resource_id, tags = {})
		tags.each { |key, value|
			@fog.tags.create(:resource_id => resource_id, :key => key, :value => value)
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

	private
	def get_lb(lb_name)
		@lbs ||= Fog::AWS::ELB.new(@cloud_config).load_balancers
		lb = @lbs.get(lb_name)
		raise "lb #{lb_name} not found in the region #{@cloud_config[:region]}" if lb.nil?
		return lb
	end
	#Not used.
	def get_zone(roles, sec_group)
		zones = Hash["us-west-1b" =>0,"us-west-1c" =>0]
		@instances.each { |instance|
			if instance.tags['role'] == roles and instance.security_group_ids.include?(sec_group)
				zones[instance.availability_zone] = zones[instance.availability_zone] + 1  
			end	
		}
		min_zone = "us-west-1b"
		zones.keys.each{|key|
			if zones[min_zone] > zones[key]
				min_zone = key
			end
		}
		return min_zone
	end
	
	#Not used anywhere...I just kept this code to check the instance properties to access block_device_mapping
	def get_server_details_map(isrunning)
		servers={}
		@instances.each { |instance|
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
