node[:redis][:version] = "2.2.12"
node[:redis][:port] = "6380"
node[:redis][:log_file] = "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/logs/redis.log"
node[:redis][:db_dir] = "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/data/"

unless File.exists?("#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}")
  extract "redis-#{node[:redis][:version]}" do
    action :enable
  end

  bash "build redis #{node[:redis][:version]}" do
    code <<-EOH
      pushd "#{node[:common][:tmp_dir]}/redis-#{node[:redis][:version]}" >/dev/null
  
      make
      [ $? -ne 0 ] && return 1
  
      for directory in etc bin logs data; do
        directory_path="#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/$directory"
        [ ! -d "$directory_path" ] && mkdir -p "$directory_path"
      done

      if $(echo #{node[:redis][:version]}|egrep -q "^[01]\."); then
        cp redis-server redis-benchmark redis-cli "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/bin/"
      else
        pushd src >/dev/null
        cp redis-server redis-benchmark redis-cli redis-check-dump redis-check-aof "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/bin/"
        popd >/dev/null
      fi

      popd >/dev/null
    EOH
    not_if "[ -d #{node[:redis][:install_dir]}/redis-#{node[:redis][:version]} ]"
  end

  execute "cleanup" do
    command "/bin/rm -rf #{node[:common][:tmp_dir]}/redis-#{node[:redis][:version]}"
  end
end

template "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}/etc/redis.conf" do
  source "redis-#{node[:redis][:version]}.erb"
end

link "/usr/local/redis2" do
  to "#{node[:redis][:install_dir]}/redis-#{node[:redis][:version]}"
  not_if "[ -L /usr/local/redis2 ]"
end

case node[:platform]
when "centos","redhat","fedora"
  src = "redis-server.erb"
when "ubuntu","debian"
  src = "redis-server.ubuntu.erb"
end

template "/etc/init.d/redis-server2" do
  source "#{src}"
  variables ({ :prog => "redis2", :pidfile => "/var/run/redis2.pid" })
  backup 0
  mode "0755"
end

service "redis-server2" do
  action [:enable, :start]
end
