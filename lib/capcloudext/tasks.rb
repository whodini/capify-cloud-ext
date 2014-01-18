require 'set'
require 'capistrano'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "cap_git_tools requires Capistrano 2"
end

require 'capcloudext/whoec2helper'
require 'capcloudext/whoravellohelper'

Capistrano::Configuration.instance(:must_exist).load do

  def init_providers
    providers = fetch(:providers, [])
    if providers.include? :aws then
      create_ec2_helper
      add_ec2_groups
    end
    if providers.include? :ravello then
      create_ravello_helper
      add_ravello_groups
    end
  end

  def check_options(*vars)
    options = Hash.new
    vars.each do |var|
      if exists? var
        options[var] = fetch var
        next
      end
      if var == :group
        raise "you need to specify a group"
      elsif var.to_s =~ /_helper$/
        raise "provider not enabled: #{var.to_s[0..-8]}"
      else
        raise "required variable #{var} not set"
      end
    end
    options
  end

  def create_ec2_helper
    options = check_options(:aws_region, :aws_access_key_id, :aws_secret_access_key)
    set :ec2_helper, Ec2Helper.new(options)
  end

  def add_ec2_groups
    groups = ec2_helper.get_groups
    groups.each { |group|
      task group.to_sym, :desc => "Run the task in all instances of the #{group}" do
        set :group, group
        set :cloud_helper, ec2_helper
        instances = ec2_helper.get_instances(group)
        #Initialize the global variables
        sec_groups = Set.new
        instances.each {|instance|
          instance.groups.each { |sec_group| sec_groups << sec_group }
          roles = instance.tags['role'].split(',')
          puts "dns name: #{instance.dns_name} roles: #{roles}"
          server(instance.dns_name, *roles) if instance.ready?
        }
        if sec_groups.count != 1
          raise "#{sec_groups.count} security defined in this group"
        end
        set :security_group, sec_groups.to_a[0]
        init_group_global_variables(group)
      end
    }
  end

  def create_ravello_helper
    options = check_options(:ravello_username, :ravello_password)
    set :ravello_helper, RavelloHelper.new(options)
  end

  def add_ravello_groups
    groups = ravello_helper.get_groups
    groups.each { |group|
      task group.to_sym, :desc => "Run the task in all instances of the #{group}" do
        set :group, group
        set :cloud_helper, ravello_helper
        instances = ravello_helper.get_instances(group)
        instances.each { |instance|
          roles = instance.tags['role'].split(',')
          server instance.dns_name, *roles
        }
        init_group_global_variables(group)
      end
    }
  end

  def init_group_global_variables(group)
    load "config/#{group}" if File.exists?(File.expand_path(Dir.pwd + "/config/#{group}.rb"))
  end

end
