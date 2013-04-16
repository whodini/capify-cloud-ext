require 'rubygems'
require 'fog'
require 'colored'
#require File.expand_path(File.dirname(__FILE__) + '/capify-cloud/server')

class Ec2Helper
	
       def initialize(cloud_config = "config/cloud.yml")
		@cloud_config = YAML.load_file cloud_config
		@instances =[]
		@cloud_providers = @cloud_config[:cloud_providers]
    		@cloud_providers.each do |cloud_provider|
		      config = @cloud_config[cloud_provider.to_sym]
		      config[:provider] = cloud_provider
		        regions = determine_regions(cloud_provider)
			config.delete(:regions)
			      if regions
			          regions.each do |region|
			            config.delete(:region)
		        	    config[:region] = region
			            populate_instances(config)
			          end
		        else populate_instances(config)
			      end
		 end

        end
	def determine_regions(cloud_provider = 'AWS')
	    regions = @cloud_config[cloud_provider.to_sym][:regions]
	  end


	def populate_instances(config)
    		@fog = Fog::Compute.new(config)
		@fog.servers.each {|server| @instances << server }
	end

      	def get_zoo_srvs_private_dns(group)
		zoosrvs = Array.new
		instances = get_instances_byrole(group, 'zoo-srv')
		instances.each {|instance|
			zoosrvs << instance.private_dns_name
		}
		return zoosrvs
	end
		
	def get_instances_byrole(group, role)
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
	
	def get_solr_private_dns(group)
		instances = get_instances_byrole(group, 'solr')
		return instances[0].private_dns_name if instances.count > 0
	end
		
	
	def get_facade_srv_public_dns(group)
		instance = get_instances_byrole(group, 'api-srv')
		return instance[0].dns_name if instance.count > 0
	end

	def get_db_srv_private_dns(group)
		instance = get_instances_byrole(group, 'db-srv')
		return instance[0].private_dns_name if instance.count > 0
	end

	def printInstanceDetails()
		 @instances.each_with_index do |instance, i|
		      puts sprintf "%02d:  %-20s  %-20s %-20s  %-20s  %-25s  %-20s  (%s)  (%s) (%s)",
        		i, (instance.tags["Name"] || "").green,instance.private_dns_name ,instance.id.red, instance.flavor_id.cyan,
		        instance.dns_name.blue, instance.availability_zone.magenta, (instance.tags["role"] || "").yellow,
		        (instance.tags["group"] || "").yellow, (instance.tags["app"] || "").green if instance.ready?
	      end

	end	

	def get_server_details_by_pri_pub_dns(dns)
		details={}
		@instances.each { |instance|
			if instance.private_dns_name == dns or instance.dns_name == dns
				details['name']=instance.tags['name_s']
				details['orgid']=instance.tags['orgid']
				details['group']=instance.tags['group']
				details['private_dns_name'] = instance.private_dns_name
				details['role']	= instance.tags['role']
				details['public_dns_name'] = instance.dns_name
				details['id'] = instance.id
				details['zone'] = instance.availability_zone
				return details
			end
		}
		return details
	end

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

		
	def get_instance_on_dns(dns)
		@instances.each { |instance|
			if instance.private_dns_name == dns or instance.dns_name == dns 
				return instance
			end	
		}
	end

	def get_groups
		groups = Set.new
		@instances.each { |instance|
			group = instance.tags['group']
			groups.add(group) if not group.nil? 	
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
	

	def add_tags(resource_id, tags = {})
		tags.each { |key, value|
			puts "#{resource_id}, #{key}, #{value}"
			@fog.tags.create(:resource_id => resource_id, :key => key, :value => value)
		}
	end

	def get_all_instances
		return @instances
	end
end

