#!/usr/bin/env ruby

require 'sinatra'
require 'mysql'
require 'inifile'

set :port, 3307
set :bind, '0.0.0.0'

cnffile = '/etc/mysql/debian.cnf'
$cnf = IniFile.load cnffile

get '/health' do
  max_behind_master = ($cnf['client']['max_behind_master'] || 300).to_i

  begin
    cnx = Mysql.new $cnf['client']['host'], $cnf['client']['user'], $cnf['client']['password'], 'mysql'
  rescue Exception => e
    status 404
    return "MySQL ERR: #{e}"
  end

  sql = cnx.query('show slave status')
  cnx.close
  if sql.num_rows != 1
    status 404
    return "MySQL ERR : No Show Slave to show"
  else
    sql.each_hash do |row|

      if !row['Seconds_Behind_Master']
        status 404;
        return "MySQL ERR : " + %w[Seconds_Behind_Master Slave_IO_Running Slave_SQL_Running Last_IO_Error]
          .map {|k| "#{k}: #{row[k]}"}.join("\n") + "\n"
      end

      if row['Seconds_Behind_Master'].to_i > max_behind_master
        status 404
        return "MySQL ERR: Too late behind master: #{row['Seconds_Behind_Master']} vs #{max_behind_master}\n"
      end

      return "MySQL OK: #{row['Seconds_Behind_Master']} seconds behind master (Max is #{max_behind_master})\n"
    end
  end
end
