set -e

rvm install 2.5.2
rvm --default use 2.5.2 # If this error out check https://rvm.io/integration/gnome-terminal
gem install bundler mailcatcher
