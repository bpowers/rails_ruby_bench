sudo -H -u discourse bash -c "PATH=/home/discourse/.rbenv/shims:$PATH cd /var/rails_ruby_bench && ./start.rb --no-startup-shutdown -p 3000 \"$@\""
