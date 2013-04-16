require 'capistrano'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "cap_git_tools requires Capistrano 2"
end

require 'capawsext/whoec2helper'

Capistrano::Configuration.instance(:must_exist).load do
	def add_groups
		ec2_helper = Ec2Helper.new
		groups = ec2_helper.get_groups
		groups.each { |group|
			task group.to_sym, :desc => "Run the task in all instances of the #{group}" do
				instances = ec2_helper.get_instances(group)
				#Initialize the global variables
				sec_groups = Set.new
				instances.each {|instance|
					instance.groups.each { |sec_group|
						sec_groups << sec_group
					}

					roles = Array.new
					instance.tags['role'].split(',').each {|role|
						roles << role.to_sym
					}
					server instance.dns_name, *roles
				}	
				init_group_global_variables(group,sec_groups)
			end
		}
	end

	def init_group_global_variables(group, sec_groups)
		if sec_groups.count != 1
			raise "#{sec_groups} security defined in this group"
		end
		set :security_group, sec_groups.to_a[0]
		set :group, group
		#TODO: call the group name configuration file to load group configuration.
		#Like the capmultiext

	end
end
