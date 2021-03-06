require 'purugin/base'
require 'purugin/plugin_metadata'

module Purugin
  # This module is the main module you should include if you want to make a registered
  # Bukkit plugin.  It will actually implement all the methods required by org.bukkit.plugin.Plugin.
  # Here is a simple example of making a plugin:
  #
  #   class PlayerJoinedPlugin
  #     include Purugin::Plugin
  #     description 'PlayerJoined', 0.1
  #
  #     def on_enable
  #       # Tell everyone in players world that they have joined
  #       event(:player_join) do |e|
  #         e.player.world.players.each do |p| 
  #           p.send_message "Player #{e.player.name} has joined"
  #       end
  #     end
  #   end
  #
  # This class will send a message to all users whenever a new player joins your world.  Note,
  # that by playing the above code into a .rb file in your CraftBukkits plugins directory will
  # automatically load this file on startup and instantiate the class you make which implements
  # Purugin::Plugin.
  module Plugin
    include Base, Command, Event, org.bukkit.plugin.Plugin
    # :nodoc:
    def self.included(other)
      other.extend(PluginMetaData)
      $last_loaded = other
    end

    # :nodoc:
    def initialize(plugin, plugin_manager, path)
      path.gsub!(/\\/, '/') # Wackiness until nicer plugin reg than $plugins (for win paths)
      @plugin, @plugin_loader = plugin, plugin_manager
      @server = plugin.server
      $plugins[path] = [self, File.mtime(path)]
      @plugin_description = org.bukkit.plugin.PluginDescriptionFile.new self.class.plugin_name, self.class.plugin_version.to_s, 'none'
      @data_dir = File.dirname(path) + '/' + self.class.plugin_name
      @configuration = org.bukkit.util.config.Configuration.new java.io.File.new(@data_dir, 'config.yml')
      @required_plugins = self.class.required_plugins
      @optional_plugins = self.class.optional_plugins
    end

    # bukkit Plugin impl (see Bukkit API documentation)
    # 
    # As a Ruby plugin you can store whatever you want in this directory (marshalled data,
    # YAML, library of congress as CSV file).
    def getDataFolder
      Dir.mkdir @data_dir unless File.exist? @data_dir
      @data_dir
    end
    alias :data_folder :getDataFolder
    
    # bukkit Plugin impl (see Bukkit API documentation)
    def getDescription
      @plugin_description
    end    
    
    # bukkit Plugin impl (see Bukkit API documentation)    
    def getConfiguration
      @configuration
    end
    alias :configuration :getConfiguration
    
    # bukkit Plugin impl (see Bukkit API documentation) 
    def getPluginLoader
      @plugin_loader
    end
    
    def getServer
      server
    end
    
    # bukkit Plugin impl (see Bukkit API documentation) 
    def isEnabled
      @enabled
    end
    alias :enabled? :isEnabled
    
    # bukkit Plugin impl (see Bukkit API documentation) 
    def onDisable
      on_disable if respond_to? :on_disable
      @enabled = false
      printStateChange 'DISABLED'      
    end    
    
    # bukkit Plugin impl (see Bukkit API documentation)     
    def onLoad
      on_load if respond_to? :on_load
    end
    
    # bukkit Plugin impl (see Bukkit API documentation) 
    def onEnable
      @enabled = true
      process_plugins(@required_plugins, true)
      process_plugins(@optional_plugins, false)
      on_enable if respond_to? :on_enable
      printStateChange 'ENABLED'
    end
    
    # bukkit Plugin impl (see Bukkit API documentation) 
    def isNaggable
      @naggable
    end

    # bukkit Plugin impl (see Bukkit API documentation) 
    def setNaggable(naggable)
      @naggable = naggable
    end
    
    def getDatabase
      nil
    end
    
    def getDefaultWorldGenerator(string, string1)
      nil
    end

    # Write a message to the console
    alias :console :print

    # Used to display modules lifecycle state changes to the CraftBukkit console.
    def printStateChange(state)
      description = getDescription
      console "[#{description.name}] version #{description.version} #{state}"
    end
    
    # This method will ask for a plugin of name plugin_name and then look for a module
    # of name plugin_module and include it into your plugin.  This method should be used
    # in your on_enable method (see examples/admin.rb for usage).
    def include_plugin_module(plugin_name, plugin_module)
      plugin = plugin_manager[plugin_name] # Try and get full java registered plugin first
      unless plugin
        puts "Unable to find plugin #{plugin_name}...ignoring"
        return
      end
      
      include_module_from(plugin, plugin_module)
    end
    
    def process_plugins(list, required)
      return unless list
      
      list.each do |name, options|
        plugin = plugin_manager[name.to_s]
        
        if !plugin && required
          raise MissingDependencyError.new "Plugin #{name} not found for plugin #{description.name}"
        end

        # Make convenience method for plugin 
        # TODO: Resolve what happens if plugin conflicts w/ existing method)
        self.class.send(:define_method, name.to_s) { plugin }
        process_includes plugin, options[:include] if options[:include]
      end
    end
    private :process_plugins
    
    def process_includes(plugin, includes)
      if includes.respond_to? :to_ary
        includes.to_ary.each { |const| include_module_from(plugin, const) }
      else
        include_module_from(plugin, includes)
      end
    end
    private :process_includes
    
    def include_module_from(plugin, name)
      unless plugin.class.const_defined? name
        raise MissingDependencyError.new "Module #{name} not found in plugin #{plugin.getDescription.name}"
      end
      
      self.class.__send__ :include, plugin.class.const_get(name)
    end
    
    # Convenience method for getting the Java loaded version of a loaded YAML file (each
    # Bukkit plugin may have it's own YAML file for config data (see Bukkit documentation).
    def config
      config = getConfiguration
      unless @configuration_loaded
        config.load
        @configuration_loaded = true
      end
      config
    end
  end
end