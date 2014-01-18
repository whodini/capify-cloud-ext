require 'fog'
class RavelloHelper

  attr_reader :client

  def initialize(options={})
    options[:provider] = 'Ravello'
    @client = Fog::Compute.new options
    @applications = Hash.new
    @client.applications.each { |app| @applications[app.name] = app }
  end

  def get_groups
    @applications.keys
  end

  def get_instances(group)
    raise "unknown group: #{group}" if !@applications.key? group
    @applications[group].deployment.vms.dup
  end

  def get_instance_by_name(group, name)
    instances = get_instances(group).select { |vm| vm.name == name }
    raise "unknown instance: #{name}" if instances.empty?
    instances[0]
  end

  def get_instances_by_role(group, role)
    get_instances(group).select do |vm|
      vm.tags['role'].split(',').include? role
    end
  end

  def get_instance_by_dns_name(name)
    instances = Array.new
    @applications.each_value do |app|
      app.deployment.vms.each do |vm|
        instances << vm if vm.dns_name == name
      end
    end
    raise "unknown dns name: #{name}" if instances.empty?
    instances[0]
  end

  def add_tags(vm, tags)
    vm.tags.merge! tags
    vm.update_tags
    vm.application.save
  end

end
