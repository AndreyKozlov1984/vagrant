require "log4r"

module Vagrant
  # This represents a machine that Vagrant manages. This provides a singular
  # API for querying the state and making state changes to the machine, which
  # is backed by any sort of provider (VirtualBox, VMWare, etc.).
  class Machine
    # The box that is backing this machine.
    #
    # @return [Box]
    attr_reader :box

    # Configuration for the machine.
    #
    # @return [Object]
    attr_reader :config

    # The environment that this machine is a part of.
    #
    # @return [Environment]
    attr_reader :env

    # ID of the machine. This ID comes from the provider and is not
    # guaranteed to be of any particular format except that it is
    # a string.
    #
    # @return [String]
    attr_reader :id

    # Name of the machine. This is assigned by the Vagrantfile.
    #
    # @return [String]
    attr_reader :name

    # Initialize a new machine.
    #
    # @param [String] name Name of the virtual machine.
    # @param [Class] provider The provider backing this machine. This is
    #   currently expected to be a V1 `provider` plugin.
    # @param [Object] config The configuration for this machine.
    # @param [Box] box The box that is backing this virtual machine.
    # @param [Environment] env The environment that this machine is a
    #   part of.
    def initialize(name, provider_cls, config, box, env)
      @logger   = Log4r::Logger.new("vagrant::machine")
      @logger.debug("Initializing machine: #{name}")
      @logger.debug("  - Provider: #{provider_cls}")
      @logger.debug("  - Box: #{box}")

      @name     = name
      @box      = box
      @config   = config
      @env      = env
      @provider = provider_cls.new(self)

      # Read the ID, which is usually in local storage
      @id = nil
      @id = @env.local_data[:active][@name] if @env.local_data[:active]
    end

    # This calls an action on the provider. The provider may or may not
    # actually implement the action.
    #
    # @param [Symbol] name Name of the action to run.
    def action(name)
      @logger.debug("Calling action: #{name} on provider #{@provider}")

      # Get the callable from the provider.
      callable = @provider.action(name)

      # If this action doesn't exist on the provider, then an exception
      # must be raised.
      if callable.nil?
        raise Errors::UnimplementedProviderAction,
          :action => name,
          :provider => @provider.to_s
      end

      # Run the action with the action runner on the environment
      @env.action_runner.run(callable, :machine => self)
    end

    # This sets the unique ID associated with this machine. This will
    # persist this ID so that in the future Vagrant will be able to find
    # this machine again. The unique ID must be absolutely unique to the
    # virtual machine, and can be used by providers for finding the
    # actual machine associated with this instance.
    #
    # **WARNING:** Only providers should ever use this method.
    #
    # @param [String] value The ID.
    def id=(value)
      @env.local_data[:active] ||= {}

      if value
        # Set the value
        @env.local_data[:active][@name] = value
      else
        # Delete it from the active hash
        @env.local_data[:active].delete(@name)
      end

      # Commit the local data so that the next time Vagrant is initialized,
      # it realizes the VM exists (or doesn't).
      @env.local_data.commit

      # Store the ID locally
      @id = value
    end

    # Returns the state of this machine. The state is queried from the
    # backing provider, so it can be any arbitrary symbol.
    #
    # @return [Symbol]
    def state
      @provider.state
    end
  end
end