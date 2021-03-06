module Wp

  class Install < Thor

    default_task :wordpress
  
    desc "wordpress [--thematic]", "Download and unpack WordPress from the interwebs (Default task)"
    method_options :directory => :string, :version => :string, :thematic => :boolean
    def wordpress
      opts = {'directory' => '.', 'version' => 'latest'}
      opts = opts.merge(options)
      opts['version'] = "wordpress-#{opts['version']}" unless opts['version'] == 'latest'
      system "mkdir -p #{opts['directory']}" unless opts['directory'] == '.'
      cmd =   "curl http://wordpress.org/#{opts['version']}.tar.gz"
      cmd +=  " | tar -zxv "
      cmd +=  " -C #{opts['directory']} " unless opts['directory'] == '.'
      cmd +=  " --strip 1"
      system cmd
      if options.thematic?
        cmd = "curl -O http://wordpress.org/extend/themes/download/thematic.0.9.5.1.zip && unzip thematic.0.9.5.1.zip -d #{opts['directory']}/wp-content/themes && rm thematic.0.9.5.1.zip"
        system cmd
      end
    end
    
    # Template for creating your own method for your own theme
    # desc "theme", "Download and unpack <theme> from the interwebs"
    # def <theme>
    #   cmd = "curl -O http://yourdomain.com/theme.zip && unzip -q theme.zip -d . && rm theme.zip"
    #   system cmd
    #   invoke "wp:generate:deploy_config"
    # end
    
    desc "theme --theme=<theme> --directory=<directory>", "Unpacks the specified <theme> from the compass-wordpress gem"
    method_options :directory => :string, :theme => :string
    def theme
      opts = {'directory' => '.', 'theme' => 'base'}
      opts = opts.merge(options)
      system "mkdir -p #{opts['directory']}" unless opts['directory'] == '.'
      say "*** Installing Theme ***"
      system "compass -r compass-wordpress -f wordpress --sass-dir=sass --css-dir=css -s compressed -p #{opts['theme']} #{opts['directory']}"
      invoke "wp:generate:deploy_config"
    end
  
  end

  class Styles < Thor
  
    default_task :generate
    map "-c" => :clear
    map "-w" => :watch

    desc "generate", "Clears and Generates the styles (Default task)"
    def generate
      if compass?
        invoke :clear
        say "*** Generating styles ***"
        system "compass compile"
      else
        say "\n!! Styles were not generated. Compass is not setup."
      end
    end

    desc "clear", "Clears the styles"
    def clear
      if compass?
        say "*** Clearing styles ***"
        system "rm -Rfv css/*"
      else
        say "\n!! Styles were not cleared. Compass is not setup."
      end
    end
    
    desc "watch", "Runs compass --watch"
    def watch
      if compass?
        invoke "wp:styles:generate"
        system "compass watch"
      else
        say "\n!! Styles were not watched. Compass is not setup."
      end
    end
    
    private
    
    def compass?
      %x[compass version].length > 1 and File.exist?("config.rb")
    end

  end

  class Deploy < Thor
  
    default_task :theme
    map "-p" => :plugin
    map "-t" => :theme
    map "-a" => :app
  
    desc "theme", "Deploys the theme (Default task)"
    def theme
      if deploy_config?
        config = YAML.load_file("deploy.yaml") rescue nil
        invoke "wp:styles:generate"
        say "*** Deploying the theme ***"
        system "rsync -avz --delete . --rsh='ssh -p#{config['ssh_port']}' #{config['ssh_user']}:#{config['remote_root']}/wp-content/themes/#{config['module_name']}/"
      else
        say "\n!! Deploy not possible. A deploy config file is required."
        invoke "wp:generate:deploy_config"
      end
    end

    desc "plugin", "Deploys the plugin"
    def plugin
      if deploy_config?
        config = YAML.load_file("deploy.yaml") rescue nil
        say "*** Deploying the plugin ***"
        system "rsync -avz --delete . --rsh='ssh -p#{config['ssh_port']}' #{config['ssh_user']}:#{config['remote_root']}/wp-content/plugins/#{config['module_name']}/"
      else
        say "\n!! Deploy not possible. A deploy config file is required."
        invoke "wp:generate:deploy_config"
      end
    end

    desc "app", "Deploys the app"
    def app
      if deploy_config?
        config = YAML.load_file("deploy.yaml") rescue nil
        invoke "wp:styles:generate"
        say "*** Deploying the app ***"
        system "rsync -avz --delete . --rsh='ssh -p#{config['ssh_port']}' #{config['ssh_user']}:#{config['remote_root']}/"
      else
        say "\n!! Deploy not possible. A deploy config file is required."
        invoke "wp:generate:deploy_config"
      end
    end
    
    private
    
    def deploy_config?
      File.exist?("deploy.yaml")
    end

  end
  
  class Generate < Thor
    
    default_task :deploy_config

    desc "deploy_config", "Generates the deploy.yaml file"
    def deploy_config
      filename = "deploy.yaml"
      config = {
        'ssh_user' => 'you@yourdomain.com',
        'ssh_port' => '',
        'remote_root' => '~/domains/yourdomain.com/html',
        'module_name' => 'kubrick'
      }
      File.open(filename, "w"){ |f| f.puts config.to_yaml }
      say "\nA #{filename} file was generated for you. Update this file's information for rsync deployment."
      say "File location: #{File.expand_path filename}"
    end

  end

end
