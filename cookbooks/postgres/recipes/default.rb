require 'pp'
#
# Cookbook Name:: postgres
# Recipe:: default
#

execute "init-postgres" do
  command "if [ ! -d /var/lib/postgresql/8.3/data ]; then\nsu - postgres -c 'initdb -D /var/lib/postgresql/8.3/data'\nfi"
  action :run
end

execute "enable-postgres" do
  command "rc-update add postgresql-8.3 default"
  action :run
end

execute "restart-postgres" do
  command "/etc/init.d/postgresql-8.3 restart"
  action :run
end

node[:applications].each do |app_name,data|
  user = node[:users].first
  db_name = "#{app_name}_#{node[:environment][:framework_env]}"
  
  execute "create-db-user-#{user[:username]}" do
    command "`psql -c '\\du' | grep -q '#{user[:username]}'`; if [ $? -eq 1 ]; then\n  psql -c \"create user #{user[:username]} with encrypted password \'#{user[:password]}\'\"\nfi"
    action :run
    user 'postgres'
  end
  
  execute "create-db-#{db_name}" do
    command "`psql -c '\\l' | grep -q '#{db_name}'`; if [ $? -eq 1 ]; then\n  createdb #{db_name}\nfi"
    action :run
    user 'postgres'
  end
  
  execute "grant-perms-on-#{db_name}-to-#{user[:username]}" do
    command "psql -c 'grant all on database #{db_name} to #{user[:username]}'"
    action :run
    user 'postgres'
  end
  
  execute "alter-public-schema-owner-on-#{db_name}-to-#{user[:username]}" do
    command "psql #{db_name} -c 'ALTER SCHEMA public OWNER TO #{user[:username]}'"
    action :run
    user 'postgres'
  end

  template "/data/#{app_name}/shared/config/database.yml" do
    source "database.yml.erb"
    owner user[:username]
    group user[:username]
    mode 0744
    variables({
        :app_name => app_name,
        :db_pass => user[:password]
    })
  end
end
